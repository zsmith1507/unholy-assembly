extends RefCounted
## World generation: info keys, reproducibility, towns, graves, settlements hook, clock.


func run(t) -> void:
	var main := _fake_main(t)
	Sim.create(1536, 768, 1)
	var info: Dictionary = load("res://world/install.gd").new().install(main, {})
	for k in ["necro_spawn", "surface_y_px", "surface_at", "graveyard", "graves", "towns", "critter_zones", "patrol_routes"]:
		t.check(info.has(k), "info has " + k)
	var w := Sim.world
	var spawn: Vector2 = info.necro_spawn
	var sc := Sim.to_cell(spawn)
	t.check(w.is_solid(sc.x, sc.y) and not w.is_solid(sc.x, sc.y - 2), "necromancer stands on the surface")
	t.check(absf(info.surface_at.call(spawn.x) - spawn.y) < 1.0, "surface_at matches the spawn")
	t.check(info.towns.size() == 2, "two towns")
	t.check(info.towns[0].side == -1 and info.towns[1].side == 1, "towns left and right")
	for town in info.towns:
		t.check(town.homes.size() >= 3, "%s has homes" % town.name)
		for h in town.homes:
			t.check(h.residents >= 1 and h.alive == h.residents, "home %d is lived in" % h.id)
	t.check(info.graves.size() >= 6, "graves listed")
	var g0: Vector2 = info.graves[0]
	var gc := Sim.to_cell(g0)
	t.check(w.get_mat(gc.x, gc.y) == SandWorld.M_EMPTY, "coffin is hollow")
	t.check((info.graveyard as Rect2).has_point(Vector2(g0.x, info.graveyard.position.y + 1)), "grave under the graveyard")
	t.check(info.critter_zones.size() >= 1 and info.patrol_routes.size() >= 2, "critter zones and patrol routes")
	# Holy water and bedrock exist.
	var counts: Dictionary = w.count_rect(0, 0, w.get_width(), w.get_height())
	t.check(counts.get(SandWorld.M_HOLY, 0) > 50, "holy water under the chapel")
	t.check(counts.get(SandWorld.M_BEDROCK, 0) > 1536 * 4, "bedrock floor")
	t.check(counts.get(SandWorld.M_LEAVES, 0) > 1000, "trees have canopies")
	# Reproducible.
	var a := w.get_cells()
	Sim.create(1536, 768, 1)
	load("res://world/install.gd").new().install(main, {})
	t.check(a == Sim.world.get_cells(), "same seed, same world")

	# Settlements hook.
	var s: Node = t.tree.get_first_node_in_group("settlements")
	t.check(s != null, "settlements node in group")
	var home: Dictionary = s.homes()[0]
	var centre: Vector2 = (home.rect as Rect2).get_center()
	t.check(s.home_at(centre).get("id", -1) == home.id, "home_at finds the home")
	var planks_before: int = Sim.world.count_rect(home.rect.position.x / 2, home.rect.position.y / 2, home.rect.size.x / 2, home.rect.size.y / 2).get(SandWorld.M_PLANK, 0)
	for i in home.residents:
		s.resident_died(home.id)
	t.check(s.home_at(centre).alive == 0, "home emptied")
	var planks_after: int = Sim.world.count_rect(home.rect.position.x / 2, home.rect.position.y / 2, home.rect.size.x / 2, home.rect.size.y / 2).get(SandWorld.M_PLANK, 0)
	t.check(planks_after < planks_before, "empty home decays (%d -> %d planks)" % [planks_before, planks_after])
	s.advance_hours(48.0)
	t.check(s.home_at(centre).alive == home.residents, "home refills")

	# Clock: dusk start, dawn after 10 hours.
	GameState.reset()
	var clock: Node = main.get_node("DayClock")
	var got := []
	Events.day_started.connect(func(d): got.append(d))
	clock.advance(10.5)
	t.check(got.size() == 1 and not GameState.is_night(), "day starts at dawn")


func _fake_main(t) -> Node:
	var main := Node2D.new()
	main.name = "FakeMain"
	var b := Node2D.new()
	b.name = "Buildings"
	main.add_child(b)
	t.root.add_child(main)
	return main
