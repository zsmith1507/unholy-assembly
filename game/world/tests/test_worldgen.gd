extends RefCounted
## World generation: info keys and their types, reproducibility, a walkable forest, towns with homes
## adults fit in, graves with body-sized coffins, the settlements hook, and the day clock.


func run(t) -> void:
	var main := _fake_main(t)
	Sim.create(1536, 768, 1)
	var inst = load("res://world/install.gd").new()
	var info: Dictionary = inst.install(main, {})
	var gen: WorldGen = inst.gen
	var w := Sim.world
	var c := float(Sim.CELL)

	# --- info keys, with the types docs/ARCHITECTURE.md promises.
	t.check(info.get("necro_spawn") is Vector2, "necro_spawn is a Vector2")
	t.check(info.get("surface_y_px") is float, "surface_y_px is a float")
	t.check(info.get("surface_at") is Callable, "surface_at is a Callable")
	t.check(info.get("graveyard") is Rect2, "graveyard is a Rect2")
	t.check(info.get("graves") is Array and info.graves.size() >= 6 and info.graves[0] is Vector2, "graves are Vector2s")
	t.check(info.get("towns") is Array and info.towns.size() == 2, "two towns")
	t.check(info.get("critter_zones") is Array and info.critter_zones.size() >= 1 and info.critter_zones[0] is Rect2, "critter zones are Rect2s")
	t.check(info.get("patrol_routes") is Array and info.patrol_routes.size() >= 3, "patrol routes")
	for r in info.patrol_routes:
		t.check(r is PackedVector2Array and r.size() >= 2, "a route is a PackedVector2Array")
		for p in r:
			if absf(p.y - info.surface_at.call(p.x)) > 0.5:
				t.check(false, "patrol point on the surface at x=%d" % p.x)

	# --- the necromancer starts on the surface with open air above.
	var spawn: Vector2 = info.necro_spawn
	var sc := Sim.to_cell(spawn)
	var air := true
	for dy in range(1, 34):
		air = air and not w.is_solid(sc.x, sc.y - dy)
	t.check(w.is_solid(sc.x, sc.y) and air, "necromancer stands on the surface with 33 cells of air above")
	t.check(absf(info.surface_at.call(spawn.x) - spawn.y) < 1.0, "surface_at matches the spawn")

	# --- the forest between the graveyard and the right town is walkable (trees are scenery).
	var x0 := gen.graveyard.end.x + 2
	var x1: int = gen.towns[1].rect.position.x - 2
	var blocked := 0
	var steep := 0
	for x in range(x0, x1):
		var gy := gen.heights[x]
		for dy in range(1, 30):
			if w.is_solid(x, gy - dy):
				blocked += 1
				break
		if absi(gen.heights[x + 1] - gy) > 3:
			steep += 1
	t.check(blocked == 0, "nothing in the forest blocks a walker (%d columns blocked)" % blocked)
	t.check(steep == 0, "no surface step taller than an actor's 6 px step (%d)" % steep)
	t.check(gen.scenery.get_used_rect().has_area(), "trees drawn as scenery")

	# --- towns: left and right of the start, homes an adult fits in, with a door toward the forest.
	t.check(info.towns[0].side == -1 and info.towns[1].side == 1, "towns left and right")
	t.check(info.towns[0].rect.end.x < spawn.x and info.towns[1].rect.position.x > spawn.x, "towns either side of the start")
	var world_px := Rect2(Vector2.ZERO, Sim.world_size_px())
	for town in info.towns:
		var fr: Rect2 = town.get("fields", Rect2())
		t.check(fr.has_area() and world_px.encloses(fr), "%s has fields inside the world" % town.name)
		t.check(fr.get_center().x < town.rect.position.x if town.side < 0 else fr.get_center().x > town.rect.end.x, "%s fields lie away from the forest" % town.name)
		t.check(town.rect.position.x - 220.0 >= 0.0 and town.rect.end.x + 220.0 <= world_px.end.x, "room for farmers' fields (220 px) beyond %s" % town.name)
	for town in info.towns:
		t.check(town.homes.size() >= 3, "%s has %d homes" % [town.name, town.homes.size()])
		t.check(town.rect is Rect2 and town.homes[0].rect is Rect2, "town and home rects are Rect2")
		for h in town.homes:
			t.check(h.residents >= 1 and h.alive == h.residents and h.alive is int, "home %d is lived in" % h.id)
			var r := Rect2i(Vector2i(h.rect.position / c), Vector2i(h.rect.size / c))
			var mid := r.position.x + r.size.x / 2
			var room := 0
			while room < 40 and not w.is_solid(mid, r.end.y - 1 - room):
				room += 1
			t.check(room >= 31, "home %d has %d cells of headroom (adults are 29)" % [h.id, room])
			var door_x := r.end.x - 1 if town.side < 0 else r.position.x
			var door := 0
			while door < 40 and not w.is_solid(door_x, r.end.y - 1 - door):
				door += 1
			t.check(door >= 30, "home %d door faces the forest and is %d cells tall" % [h.id, door])
			t.check(w.is_solid(mid, r.end.y), "home %d has a floor" % h.id)

	# --- graveyard: graves under it, coffins hollow and long enough for a laid-out adult.
	var yard: Rect2 = info.graveyard
	for g in info.graves:
		t.check(yard.has_point(g), "grave at %s inside the graveyard" % g)
		var gc := Sim.to_cell(g)
		var span := 0
		for dx in range(-20, 21):
			if w.get_mat(gc.x + dx, gc.y) == SandWorld.M_EMPTY:
				span += 1
		t.check(span >= 30, "coffin is hollow and %d cells long" % span)
		t.check(w.get_mat(gc.x, gc.y - 4) == SandWorld.M_WOOD and w.get_mat(gc.x, gc.y - 6) == SandWorld.M_DIRT, "coffin lid under grave dirt")
	t.check(gen.tombstones.size() == info.graves.size(), "a headstone per grave")

	# --- materials: holy water held in stone, bedrock floor, deep liquid pockets.
	var counts: Dictionary = w.count_rect(0, 0, w.get_width(), w.get_height())
	t.check(counts.get(SandWorld.M_HOLY, 0) > 100, "holy water under the chapel")
	var ch: Rect2i = gen.towns[0].chapel
	var hx := ch.position.x + ch.size.x / 2
	var hy := ch.end.y + 1
	while hy < ch.end.y + 60 and w.get_mat(hx, hy) != SandWorld.M_HOLY:
		hy += 1
	t.check(w.get_mat(hx, hy) == SandWorld.M_HOLY, "holy water directly under the chapel")
	t.check(w.get_mat(hx - 15, hy + 2) == SandWorld.M_STONE, "the cistern is stone")
	t.check(counts.get(SandWorld.M_BEDROCK, 0) > 1536 * 4, "bedrock floor")
	t.check(counts.get(SandWorld.M_DIRT, 0) > 2000 and counts.get(SandWorld.M_CLAY, 0) > 50000, "loose dirt and clay layers")
	t.check(counts.get(SandWorld.M_BLOOD, 0) + counts.get(SandWorld.M_ICHOR, 0) > 20, "a few deep liquid pockets")

	# --- same seed, same world.
	var a := w.get_cells()
	var scen := gen.scenery.get_data()
	main.queue_free()
	main = _fake_main(t)
	Sim.create(1536, 768, 1)
	var inst2 = load("res://world/install.gd").new()
	info = inst2.install(main, {})
	t.check(a == Sim.world.get_cells(), "same seed, same world")
	t.check(scen == inst2.gen.scenery.get_data(), "same seed, same scenery")
	w = Sim.world

	# --- settlements hook.
	await t.tree.process_frame
	var s: Settlements = main.get_node("Settlements")
	t.check(s.is_in_group("settlements"), "settlements node in group")
	var home: Dictionary = s.homes()[0]
	var centre: Vector2 = (home.rect as Rect2).get_center()
	t.check(s.home_at(centre).get("id", -1) == home.id, "home_at finds the home")
	t.check(s.home_at(Vector2(-50, -50)).is_empty(), "home_at elsewhere is empty")
	var emptied := []
	var arrived := []
	s.home_emptied.connect(func(h): emptied.append(h.id))
	s.resident_arrived.connect(func(h): arrived.append(h.id))
	var hr := Rect2i(Vector2i(home.rect.position / c), Vector2i(home.rect.size / c))
	var planks := func() -> int:
		var n := 0
		for x in range(hr.position.x, hr.end.x):
			for y in range(hr.position.y, hr.end.y):
				if w.is_solid(x, y):
					n += 1
		return n
	var p0: int = planks.call()
	for i in home.residents:
		s.resident_died(home.id)
	t.check(s.home_at(centre).alive == 0 and emptied == [home.id], "home emptied, signal fired")
	var p1: int = planks.call()
	t.check(p1 < p0 and s.decay_of(home.id) == 1, "empty home runs down (%d -> %d solid cells)" % [p0, p1])
	t.check(info.towns[0].homes[0].alive == 0, "info.towns sees the empty home")
	s.advance_hours(13.0)
	var p2: int = planks.call()
	t.check(p2 < p1 and s.decay_of(home.id) == 2, "then it is a ruin (%d solid cells)" % p2)
	s.advance_hours(11.0)
	t.check(s.home_at(centre).alive == 1 and arrived == [home.id] and s.decay_of(home.id) == 0, "a newcomer moves in and rebuilds")
	t.check(planks.call() == p0, "rebuilt home matches the original")
	s.advance_hours(24.0 * home.residents)
	t.check(s.home_at(centre).alive == home.residents and arrived.size() == home.residents, "home slowly refills")

	# --- day clock: opens at dusk; ~12 real minutes a day; dawn and dusk signals.
	GameState.reset()
	t.check(GameState.hour == 20.0 and GameState.is_night(), "the run opens at dusk")
	var clock: DayClock = main.get_node("DayClock")
	var days := []
	var nights := []
	var ticks := [0]
	Events.day_started.connect(func(d): days.append(d))
	Events.night_started.connect(func(d): nights.append(d))
	Events.time_of_day_changed.connect(func(_h, _n): ticks[0] += 1)
	var h0 := GameState.hour
	for i in 60:
		clock._physics_process(1.0 / 60.0)
	var per_sec := GameState.hour - h0
	t.check(absf(per_sec * 60.0 * 12.0 - 24.0) < 0.01, "one day takes 12 real minutes")
	clock.advance(10.5)
	t.check(days.size() == 1 and not GameState.is_night(), "day starts at dawn")
	clock.advance(14.0)
	t.check(nights.size() == 1 and GameState.is_night(), "night falls at dusk")
	t.check(ticks[0] >= 2, "time_of_day_changed fires (%d)" % ticks[0])
	main.queue_free()


func _fake_main(t) -> Node:
	var main := Node2D.new()
	main.name = "FakeMain"
	for n in ["Buildings", "Terrain"]:
		var b := Node2D.new()
		b.name = n
		main.add_child(b)
	t.root.add_child(main)
	return main
