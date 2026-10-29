extends RefCounted
## The hidden-start checklist played through with the other departments' real code: the Necromancer's
## Dig and Harvest spells, the Lair's builder, heart, grinder, stitching table and altar, a graveyard
## corpse from Bodies and Souls, a critter's fragment orb, and the Threats patrols list.
## Skips itself when those departments aren't merged in (on dept/eyegor alone); runs in integration.

const NEEDS := ["res://necro/necromancer.gd", "res://lair/builder.gd", "res://flesh/corpse.gd",
	"res://flesh/soul_orb.gd", "res://threats/patrols.gd"]


func run(t) -> void:
	for p in NEEDS:
		if not ResourceLoader.exists(p):
			print("    skipped: %s is not in this build" % p)
			return
	seed(7)
	Jobs.reset()
	var w: SandWorld = t.flat_world(256, 160, 100)
	w.fill_rect(0, 0, 256, 100, SandWorld.M_EARTH) # buried...
	w.fill_rect(75, 60, 171, 40, SandWorld.M_EMPTY) # ...but for a dug hall, x 150-492 px, floor at y = 200 px
	var fy := 200.0
	var n = load("res://necro/necromancer.gd").new()
	n.scripted = true
	n.position = Vector2(180, fy)
	t.root.add_child(n)
	var o := EyegorObjectives.new()
	t.root.add_child(o)
	var patrols: Node = load("res://threats/patrols.gd").new()
	t.root.add_child(patrols)
	patrols.set_physics_process(false) # its list only; no towns in this little world
	o.patrols_node = patrols
	o.start()
	await t.ticks(2)

	var b = load("res://lair/builder.gd").new()
	b.parent_layer = t.root
	t.root.add_child(b)
	var heart = b.place(&"heart", Vector2(256, fy))
	await t.ticks(2)
	t.check(o.is_done(&"place_heart"), "place_heart: the Lair's builder placed the heart")

	GameState.add_souls(3.0, "test")
	GameState.spend_mana(0.5)
	heart.interact(n)
	t.check(o.is_done(&"refill_mana"), "refill_mana: the heart's interact refilled mana")

	# dig a chamber with the real Dig spell, into the earth under the floor
	n.select_spell_id(&"dig")
	# he hovers at the hall's west end and digs into the earth beyond it: a new room, away from the heart
	var ticks := 0
	while not o.is_done(&"dig_chamber") and ticks < 900:
		GameState.mana = GameState.max_mana
		n.global_position = Vector2(maxf(160.0 - ticks * 0.3, 70.0), fy - 10)
		n.velocity = Vector2.ZERO
		var a := PI * (1.0 + 0.3 * sin(ticks * 0.05))
		n.script_input = {"cast": true, "aim": n.get_hand_pos() + Vector2(cos(a), sin(a)) * 100.0}
		await t.ticks(1)
		ticks += 1
	n.script_input = {}
	n.global_position = Vector2(170, fy - 2)
	n.velocity = Vector2.ZERO
	t.check(o.is_done(&"dig_chamber"), "dig_chamber: the Dig spell removed %d cells in %.1f s of digging" % [o._dug_since_heart(), ticks / 60.0])
	print("    chamber: %d cells took %.1f s of Dig" % [EyegorObjectives.OBJ.cells_for_chamber, ticks / 60.0])

	# a graveyard corpse lying in the hall; the real Harvest spell draws it to his hand
	var corpse = load("res://flesh/corpse.gd").new()
	corpse.setup_grave("villager", Vector2(240, fy - 8))
	t.root.add_child(corpse)
	t.check(corpse.fresh == false, "a graveyard corpse is not fresh")
	n.select_spell_id(&"harvest")
	ticks = 0
	while not o.is_done(&"rob_grave") and ticks < 400:
		GameState.mana = GameState.max_mana
		n.script_input = {"cast": true, "aim": corpse.get_box().get_center()}
		await t.ticks(1)
		ticks += 1
	n.script_input = {}
	t.check(o.is_done(&"rob_grave"), "rob_grave: Harvest drew a graveyard corpse to his hand (%d ticks; corpse at %s, hand at %s)" % [ticks, corpse.get_box().get_center() if is_instance_valid(corpse) else "-", n.get_hand_pos()])

	var grinder = _place(t, b, &"grinder", Vector2(320, fy))
	await t.ticks(1)
	# the grinder spills blood across the floor, so the rest of the line goes in now (ahead of its turn;
	# each completes when it comes up)
	var table = _place(t, b, &"stitching_table", Vector2(395, fy))
	var altar = _place(t, b, &"altar", Vector2(460, fy))
	t.check(not o.is_done(&"build_stitching_table"), "the table built early waits its turn")
	t.check(o.is_done(&"build_grinder"), "build_grinder: the builder placed a grinder")
	# carry what was harvested (the corpse, and any part that tore off) to the grinder's hopper
	for g in [&"corpses", &"body_parts"]:
		for it in t.tree.get_nodes_in_group(g):
			it.drop(grinder.global_position + Vector2(0, -20))
	await t.ticks(int(load("res://lair/machine.gd").MACHINES[&"grinder"].seconds * 60) + 40)
	t.check(o.is_done(&"grind_corpse"), "grind_corpse: the grinder produced gibs and bones")

	t.check(o.is_done(&"build_stitching_table"), "build_stitching_table: the builder placed a table")
	for k in [&"item_gibs", &"item_bones"]:
		for it in t.tree.get_nodes_in_group(k):
			it.global_position = table.global_position + Vector2(0, -10)
	await t.ticks(int(load("res://lair/machine.gd").MACHINES[&"stitching_table"].seconds * 60) + 40)
	t.check(o.is_done(&"stitch_body"), "stitch_body: the table produced a stitched body")

	t.check(o.is_done(&"build_altar"), "build_altar: the builder placed an altar")
	for it in t.tree.get_nodes_in_group(&"item_stitched_body"):
		it.global_position = altar.global_position + Vector2(0, -10)
	await t.ticks(10)
	GameState.add_souls(1.0, "test")
	GameState.mana = GameState.max_mana
	altar.interact(n)
	await t.ticks(int(load("res://lair/machine.gd").MACHINES[&"altar"].seconds * 60) + 40)
	t.check(o.is_done(&"raise_ghoul"), "raise_ghoul: the altar raised a minion")

	Jobs.mark_dig(Rect2i(150, 100, 6, 4))
	t.check(o.is_done(&"mark_dig"), "mark_dig: Jobs.mark_dig (the Dig Order) marked ground")

	var orb = load("res://flesh/soul_orb.gd").new()
	orb.fragment = true
	orb.source = "rabbit"
	orb.amount = 1.0
	orb.position = heart.global_position + Vector2(30, -10)
	t.root.add_child(orb)
	await t.ticks(120)
	t.check(o.is_done(&"harvest_fragments"), "harvest_fragments: a critter's fragment orb reached the heart")

	var pat := {"id": 7, "town": 0, "members": [], "t": 0.0, "home_t": -1.0}
	patrols.out.append(pat)
	patrols.patrol_left.emit(pat)
	await t.ticks(20)
	t.check(not o.is_done(&"survive_patrol"), "the patrol is still out")
	patrols.out.clear()
	patrols.patrol_returned.emit(pat)
	await t.ticks(20)
	t.check(o.is_done(&"survive_patrol"), "survive_patrol: the patrol left the Threats list with the heart intact (heart %s, current %s)" % [GameState.has_heart, o.current_id()])
	t.check(o.all_done(), "the whole hidden start completes from real department code")


## Place a machine at `at`, or the nearest spot along the floor the builder accepts.
func _place(t, b, kind: StringName, at: Vector2) -> Node2D:
	for dx in [0, -16, 16, -32, 32, -48, 48, -64, 64, -96, 96, -128, 128]:
		for dy in [0, -4, 4, -8]:
			var p := at + Vector2(dx, dy)
			if b.can_place(kind, p):
				return b.place(kind, p)
	t.check(false, "%s could not be placed near %s: %s" % [kind, at, b.why_not(kind, at)])
	return null
