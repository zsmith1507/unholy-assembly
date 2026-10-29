extends RefCounted
## Suspicion: noise muffled by earth (stone more than soil), decay while quiet, witnesses, culling, hunger.

func run(t) -> void:
	var world: SandWorld = t.flat_world(256, 200, 60)
	Sim.world = world
	Threats.auto_tick = false
	var town := {"name": "Ashby", "rect": Rect2(0, 80, 120, 40), "side": -1, "homes": []}
	Threats.begin_run({"surface_y_px": 120.0, "towns": [town]})

	# noise: deeper is quieter
	var shallow: Dictionary = Threats.noise_cost(Vector2(256, 140), 3.0)
	var deep: Dictionary = Threats.noise_cost(Vector2(256, 300), 3.0)
	t.check(shallow.amount > deep.amount, "deeper noise costs less (%.4f > %.4f)" % [shallow.amount, deep.amount])
	# stone muffles more than soil at the same depth
	var soil: Dictionary = Threats.noise_cost(Vector2(400, 200), 3.0)
	world.fill_rect(180, 60, 40, 40, SandWorld.M_STONE)
	var stone: Dictionary = Threats.noise_cost(Vector2(400, 200), 3.0)
	t.check(stone.amount < soil.amount, "stone muffles more than soil (%.4f < %.4f)" % [stone.amount, soil.amount])
	t.check(String(stone.earth.what).contains("stone"), "earth reads as stone: %s" % stone.earth.what)

	# a noise event raises Suspicion and lands in the ledger
	var before := GameState.suspicion
	Events.noise_made.emit(Vector2(100, 130), 10.0, "explosion")
	t.check(GameState.suspicion > before, "explosion near town raised Suspicion")
	t.check(Threats.ledger.size() > 0 and String(Threats.ledger[-1].text).contains("explosion"), "ledger explains the noise")
	t.check(not Threats.is_quiet(), "not quiet right after a noise")

	# decay after quiet_after_s
	GameState.suspicion = 20.0
	Threats.simulate(Threats.SUSPICION.quiet_after_s + 61.0, 1.0)
	t.check(GameState.suspicion < 20.0, "Suspicion fades while quiet (%.2f)" % GameState.suspicion)

	# witness killed before reaching home does not report
	var w1 := Node2D.new()
	w1.position = Vector2(400, 110)
	t.root.add_child(w1)
	Threats.start_report(w1, "a ghoul", w1.position)
	t.check(Threats.pending_reports.size() == 1, "report pending")
	var s0 := GameState.suspicion
	Events.actor_died.emit(w1, null, w1.position)
	Threats.simulate(1.0)
	t.check(Threats.pending_reports.is_empty(), "silenced witness's report stopped")
	# a witness who reaches town reports
	var w2 := Node2D.new()
	w2.position = Vector2(400, 110)
	t.root.add_child(w2)
	Threats.start_report(w2, "a ghoul", w2.position)
	w2.position = Vector2(50, 100)
	s0 = GameState.suspicion
	Threats.simulate(1.0)
	t.check(GameState.suspicion > s0 + 2.0, "witness who got home raised Suspicion")

	# culling: fast shrinking spikes more than the base cost
	GameState.suspicion = 0.0
	for i in 5:
		var v := Node2D.new()
		v.add_to_group("humans")
		t.root.add_child(v)
		Events.actor_died.emit(v, null, Vector2(60, 100))
	var per_death: float = Threats.SUSPICION.missing_resident
	t.check(GameState.suspicion > per_death * 5.0 + 1.0, "town shrinking fast spikes Suspicion (%.1f)" % GameState.suspicion)

	# hunger: human soul yes, fragments no
	var h0 := GameState.hunger
	Events.soul_collected.emit(1.0, "fragments", Vector2.ZERO)
	t.check(is_equal_approx(GameState.hunger, h0), "fragments don't feed Hunger")
	Events.soul_collected.emit(1.0, "farmer", Vector2.ZERO)
	t.check(GameState.hunger > h0, "a human soul raises Hunger")

	# patrol sizing scales with Suspicion
	t.check(Threats.patrol_size(90.0) > Threats.patrol_size(0.0), "bigger patrols at high Suspicion")
	t.check(Threats.patrol_interval(90.0) < Threats.patrol_interval(0.0), "more frequent patrols at high Suspicion")
	Threats.auto_tick = true
	Threats.reset()
