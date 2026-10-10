extends RefCounted
## The installer: residents from info.towns[*].homes, an old corpse in every grave, critters in the forest.
## Robbing a grave: the old body lies still and hidden until Harvest reaches it down a dug shaft, then
## comes up (bloodless, no soul). Homes that refill get new residents.


## A coffin like World's: grave dirt above a hollow wooden box. Returns the coffin centre in pixels.
func _grave(w: SandWorld, gx: int, gy: int, depth: int) -> Vector2:
	w.fill_rect(gx, gy, 8, depth, SandWorld.M_DIRT)
	var cr := Rect2i(gx - 1, gy + depth, 10, 6)
	w.fill_rect(cr.position.x, cr.position.y, cr.size.x, cr.size.y, SandWorld.M_WOOD)
	w.fill_rect(cr.position.x + 1, cr.position.y + 1, cr.size.x - 2, cr.size.y - 2, SandWorld.M_EMPTY)
	return Sim.cell_center(Vector2i(cr.position.x + cr.size.x / 2, cr.position.y + cr.size.y / 2))


func run(t) -> void:
	var w: SandWorld = t.flat_world(512, 200, 100)
	var ground := 200.0
	GameState.hour = 21.0
	var graves: Array[Vector2] = [_grave(w, 60, 100, 15), _grave(w, 80, 100, 12)]
	var home_a := {"id": 1, "rect": Rect2(560, 160, 40, 40), "residents": 2, "alive": 2}
	var home_b := {"id": 2, "rect": Rect2(620, 160, 40, 40), "residents": 1, "alive": 1}
	var info := {
		"towns": [{"name": "Ashby", "rect": Rect2(540, 140, 140, 60), "side": 1, "homes": [home_a, home_b]}],
		"graves": graves,
		"critter_zones": [Rect2(300, 100, 160, 100)],
	}
	var inst = load("res://flesh/install.gd").new()
	var out: Dictionary = inst.install(t.root, info)
	var sp: FleshSpawner = out.get("flesh_spawner")
	t.check(sp != null and sp.is_in_group(&"flesh_spawner"), "install returns the flesh spawner")
	await t.ticks(30)

	var people: Array = t.root.get_children().filter(func(n): return n is Human)
	t.check(people.size() == 3, "one human per living resident (%d)" % people.size())
	t.check(people.filter(func(h): return h.home_id == 1).size() == 2 and people.filter(func(h): return h.home_id == 2).size() == 1, "each knows their home")
	t.check(people.any(func(h): return h.kind == &"farmer") and people.any(func(h): return h.kind == &"villager"), "farmers and villagers")
	t.check(people.all(func(h): return absf(h.global_position.y - ground) < 4.0), "standing on the ground")
	var critters: Array = t.root.get_children().filter(func(n): return n is Critter)
	t.check(critters.size() == FleshSpawner.SPAWN.critters_per_zone, "the forest is stocked (%d critters)" % critters.size())

	# --- grave corpses lie still and hidden
	var dead: Array = t.root.get_children().filter(func(n): return n is Corpse)
	t.check(dead.size() == 2, "a corpse in every grave")
	var g: Corpse = dead[0]
	var g0 := g.global_position
	t.check(g.interred and not g.visible and not g.fresh and g.blood == 0.0, "buried bodies are old, bloodless and hidden")
	t.check(not g.is_in_group(&"item_corpse") and g.is_in_group(&"pullable"), "they don't smell or get hauled until dug up, but Harvest can reach them")
	t.check(g.siphon(0.1) == 0.0, "nothing to siphon through the earth")
	await t.ticks(60)
	t.check(g.global_position == g0, "they stay put in the coffin")

	# --- rob it: open a shaft, pull it up (as Harvest does: capped near 4 px per tick)
	var gc := Sim.to_cell(graves[0])
	w.fill_rect(gc.x - 4, 60, 8, gc.y - 60 + 1, SandWorld.M_EMPTY)
	var hand := Vector2(graves[0].x + 20.0, ground - 50.0)
	var pieces: Array = [g]
	var on_child := func(n): if n is BodyPart: pieces.append(n)
	t.root.child_entered_tree.connect(on_child)
	var got: Node2D = null
	for i in 300:
		for n in pieces:
			if not is_instance_valid(n) or n.is_queued_for_deletion():
				continue
			var to: Vector2 = hand - n.global_position
			if to.length() < 14.0:
				got = n
				break
			var dir := to.normalized()
			var v: Vector2 = n.velocity
			var along := v.dot(dir)
			var f := dir * 0.6 * clampf(4.0 - along, 0.0, 1.0) - (v - dir * along) * 0.12
			n.apply_pull(f)
		if got != null:
			break
		await t.ticks(1)
	t.root.child_entered_tree.disconnect(on_child)
	t.note("pieces %d, reached the hand: %s" % [pieces.size(), got])
	t.check(is_instance_valid(g) == false or (not g.interred and g.visible and g.is_in_group(&"item_corpse")), "Harvest's first touch exhumes the body")
	t.check(got != null, "the body (or a piece of it) is drawn up out of the grave to the hand")
	t.check(pieces.all(func(n): return not is_instance_valid(n) or not n.data.get("fresh", true)), "what comes up is old meat: no blood")
	var orbs: Array = t.root.get_children().filter(func(n): return n is SoulOrb)
	t.check(orbs.is_empty(), "and no soul")
	t.check(is_instance_valid(dead[1]) and dead[1].interred, "the other grave is untouched")

	# --- a home refills: a new family moves in
	for h in people:
		if is_instance_valid(h) and h.home_id == 2:
			home_b.alive = 0
			h.queue_free()
	await t.ticks(2)
	t.check(sp.census() == 0, "no new residents while the home stands empty")
	home_b.alive = 1
	t.check(sp.census() == 1, "a refilled home gets a new resident")
