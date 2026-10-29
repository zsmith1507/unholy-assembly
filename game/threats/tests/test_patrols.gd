extends RefCounted
## Patrols: leave town, grow with Suspicion, investigate noises, flee by fear, search for the heart.

func run(t) -> void:
	var world: SandWorld = t.flat_world(400, 160, 60)
	Sim.world = world
	Threats.auto_tick = false
	var surface := 120.0
	var town := {"name": "Ashby", "rect": Rect2(0, 60, 120, 60), "side": -1, "homes": []}
	var route := PackedVector2Array([Vector2(60, surface), Vector2(700, surface)])
	Threats.begin_run({"surface_y_px": surface, "towns": [town], "patrol_routes": [route]})
	var patrols = load("res://threats/patrols.gd").new()
	t.root.add_child(patrols)

	# the first patrol leaves on schedule
	GameState.hour = 12.0
	GameState.suspicion = 0.0
	Threats.simulate(Threats.PATROL.first_after_s + 1.0, 0.5)
	t.check(patrols.out.size() == 1, "first patrol left town")
	t.check(patrols.members_out().size() == Threats.patrol_size(0.0), "patrol size matches low Suspicion")
	var m: Node2D = patrols.members_out()[0]
	t.check(m.get("route") != null and (m.get("route") as PackedVector2Array).size() == 2, "member got World's route")

	# a loud noise near a member: they go to look
	var noise_at := m.global_position + Vector2(60, 40)
	Events.noise_made.emit(noise_at, 8.0, "grinder")
	t.check(m.get("_target") != Vector2.INF, "member investigates the noise")

	# fear decides fight or flee
	m.set("fear", 0.9)
	patrols._fight_or_flee(m, noise_at)
	t.check(m.get("mode") == &"flee", "frightened farmer flees")
	var m2: Node2D = patrols.send(0).members[0]
	m2.set("fear", 0.1)
	patrols._fight_or_flee(m2, noise_at)
	t.check(m2.get("mode") == &"attack", "brave farmer attacks")

	# high Suspicion: bigger patrol, headed for the heart
	var heart := Node2D.new()
	heart.position = Vector2(600, 240)
	t.root.add_child(heart)
	GameState.set_heart(heart, 80.0)
	GameState.suspicion = 70.0
	var p: Dictionary = patrols.send(0)
	t.check(p.members.size() == Threats.patrol_size(70.0), "patrol grows with Suspicion (%d)" % p.members.size())
	var end: Vector2 = (p.route as PackedVector2Array)[-1]
	t.check(absf(end.x - 600.0) <= 500.0, "search party heads near the heart (%.0f)" % end.x)
	GameState.suspicion = 90.0
	var raid: Dictionary = patrols.send(0)
	t.check(raid.raid, "at raid_at a patrol becomes a raid")

	# night: rarer patrols
	GameState.hour = 23.0
	var night := Threats.patrol_interval(30.0)
	GameState.hour = 12.0
	t.check(night > Threats.patrol_interval(30.0), "fewer patrols at night")

	# patrol member silenced before reaching town: no report
	var w := patrols.members_out()[0] as Node2D
	Threats.start_report(w, "a ghoul", w.global_position)
	var n := Threats.pending_reports.size()
	w.call("die")
	t.check(Threats.pending_reports.size() == n - 1, "killed witness's report dropped")

	Threats.auto_tick = true
	Threats.reset()
	GameState.reset()
