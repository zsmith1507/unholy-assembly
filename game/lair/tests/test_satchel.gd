extends RefCounted
## Round 5 (playtest notes 6, 7, 14): the first heart is free and the second isn't; describe() for every kind;
## the stitching table takes satchel components and refuses with too few; a stitched body goes into the
## satchel and the altar raises it; the opening raises its first ghoul with no soul to spare; outputs never
## land in solid ground; machines play "work" while running.


func run(t) -> void:
	Jobs.reset()
	var w: SandWorld = t.flat_world(256, 160, 100)
	w.fill_rect(10, 60, 236, 40, SandWorld.M_EMPTY) # a dug hall, floor at cell 100 (y = 200 px)
	var b := LairBuilder.new()
	b.parent_layer = t.root
	t.root.add_child(b)
	var fy := 200.0

	# --- note 7: the first heart is free, later ones cost as before
	t.check(b.cost(&"heart").is_empty(), "the first heart costs nothing")
	t.check(not b.cost(&"grinder").is_empty(), "machines still cost")
	var heart = b.place(&"heart", Vector2(256, fy))
	t.check(heart != null, "heart placed")
	t.check(b.cost(&"heart").is_empty(), "still free on the frame it was placed (caller pays after place)")
	await t.ticks(2)
	t.check(not b.cost(&"heart").is_empty(), "the second heart costs mana")
	GameState.reset()
	t.check(b.cost(&"heart").is_empty(), "a new run's first heart is free again")
	GameState.count("built_heart") # put the run back the way it was
	GameState.set_heart(heart, heart.radius)

	# --- note 6: describe() for every kind
	for k in b.kinds():
		var d: Dictionary = b.describe(k)
		var ok: bool = d.get("name", "") is String and d.name != "" and d.name != "build_" + String(k) \
			and d.get("blurb", "") is String and d.blurb != "" and d.blurb != "desc_" + String(k) \
			and d.get("cost") is Dictionary and d.get("footprint") is Vector2 and d.footprint.x > 0.0 \
			and d.get("unlocked") is bool
		t.check(ok, "describe(%s) is complete: %s" % [k, d])
	t.check(b.describe(&"grinder").unlocked, "the grinder is unlocked from the start")

	# --- note 14: the stitching table takes from the satchel
	var table: LairMachine = b.place(&"stitching_table", Vector2(380, fy))
	var altar: LairMachine = b.place(&"altar", Vector2(450, fy))
	t.check(table != null and altar != null, "table and altar placed")
	var recipe: Dictionary = LairMachine.MACHINES[&"stitching_table"].satchel
	GameState.add_item(&"flesh", float(recipe[&"flesh"]))
	GameState.add_item(&"bones", float(recipe[&"bones"]) - 2.0)
	var hint := table.interact_hint()
	t.check(hint.contains("2 more bones"), "the hint says what's missing: '%s'" % hint)
	table.interact(null)
	t.check(not table.working and GameState.item_count(&"flesh") == float(recipe[&"flesh"]), "refuses with too few, takes nothing")
	GameState.add_item(&"bones", 2.0)
	table.interact(null)
	t.check(table.working, "stitching from the satchel")
	t.check(GameState.item_count(&"flesh") < 0.01 and GameState.item_count(&"bones") < 0.01, "took the components")
	await t.ticks(10)
	t.check(table.sprite == null or table.sprite.animation == &"work", "table plays work while running")
	await t.ticks(int(LairMachine.MACHINES[&"stitching_table"].seconds * 60) + 10)
	t.check(table.sprite == null or table.sprite.animation == &"idle", "table back to idle")
	var bodies: Array = t.tree.get_nodes_in_group(&"item_stitched_body")
	t.check(bodies.size() == 1, "the table made a stitched body")
	if bodies.is_empty():
		return
	var body = bodies[0]
	t.check(LairMachine._open(body.global_position - Vector2(0, 1), Vector2(20, 6)), "the body came out in open air")

	# --- the body into the satchel, then the altar raises it with no soul to spare
	t.check(body.is_in_group(&"interactable") and body.interact_hint() != "", "a stitched body can be picked up")
	body.interact(null)
	await t.ticks(1)
	t.check(GameState.item_count(&"stitched_body") >= 1.0, "the stitched body is in the satchel")
	GameState.souls = 0.0 # the opening: the starting soul went on a mana refill
	GameState.mana = 1.0
	t.check(altar.interact_hint().contains("first"), "the altar says the first raising is spared: '%s'" % altar.interact_hint())
	altar.interact(null)
	t.check(altar.touched and GameState.item_count(&"stitched_body") < 0.01, "touching lays the carried body on the altar")
	await t.ticks(int(LairMachine.MACHINES[&"altar"].seconds * 60) + 20)
	t.check(t.tree.get_nodes_in_group(&"lair_ghoul").size() == 1, "the opening raised a ghoul without a soul")
	# the second raising needs its soul
	GameState.add_item(&"stitched_body", 1.0)
	t.check(altar.soul_cost() >= 1.0, "later raisings cost a soul")
	altar.interact(null)
	t.check(not altar.touched and GameState.item_count(&"stitched_body") >= 1.0, "no soul: nothing taken")
	t.check(altar.interact_hint().contains("soul"), "hint says it needs a soul: '%s'" % altar.interact_hint())

	# --- outputs never land in solid ground: a grinder built hard against a wall on both sides
	var w2: SandWorld = t.flat_world(256, 160, 100)
	w2.fill_rect(100, 70, 30, 30, SandWorld.M_EMPTY) # a pocket 60 px wide, 60 px tall; floor at 200 px
	var g := LairMachine.make(&"grinder")
	t.root.add_child(g)
	g.global_position = Vector2(230, fy) # 48 px wide: 6 px of air each side
	var all_open := true
	for i in 6:
		var at := g.output_spot(&"gibs", -1.0 if i % 2 == 0 else 1.0, i)
		if not LairMachine._open(at, LairItem.SIZES[&"gibs"]):
			all_open = false
			t.note("output %d at %s is in the ground" % [i, at])
	t.check(all_open, "every output spot is open air")
	var spot := g.output_spot(&"gibs", -1.0)
	t.check(spot.y < g.global_position.y - 1.0 or absf(spot.x - g.global_position.x) > 24.0, "squeezed outputs go on top: %s" % spot)
	# the real thing: grind a corpse and check where the outputs are
	var corpse := Lair.spawn_item(t.tree, &"corpse", g.global_position + Vector2(0, -20), t.root)
	await t.ticks(int(LairMachine.MACHINES[&"grinder"].seconds * 60) + 30)
	var stuck := 0
	var made := 0
	for k in [&"item_gibs", &"item_bones"]:
		for it in t.tree.get_nodes_in_group(k):
			made += 1
			var c := Sim.to_cell((it as Node2D).global_position - Vector2(0, 2))
			if w2.is_solid(c.x, c.y):
				stuck += 1
	t.check(made == 3 and stuck == 0, "grinder outputs (%d) are not in the ground (%d stuck)" % [made, stuck])
	t.check(not is_instance_valid(corpse) or corpse.is_queued_for_deletion(), "corpse ground")

	# --- the spike trap shows "work" once sprung
	var trap := LairSpikeTrap.new()
	t.root.add_child(trap)
	trap.armed = false
	trap._rearm = 5.0
	await t.ticks(2)
	t.check(trap.sprite == null or trap.sprite.animation == &"work", "sprung trap plays work")
