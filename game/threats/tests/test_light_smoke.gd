extends RefCounted
## Light leaking up an open shaft at night raises Suspicion; covered light and daytime light don't. Smoke does.

func run(t) -> void:
	var world: SandWorld = t.flat_world(256, 200, 60)
	Sim.world = world
	Threats.auto_tick = false
	Threats.begin_run({"surface_y_px": 120.0, "towns": []})
	var lamp := PointLight2D.new()
	lamp.position = Vector2(200, 220) # 50 cells down, buried
	t.root.add_child(lamp)
	GameState.hour = 23.0
	t.check(Threats.sky_exposure(lamp.position) == 0.0, "buried lamp can't see the sky")
	var s0 := GameState.suspicion
	Threats.simulate(10.0, 1.0)
	var buried_gain := GameState.suspicion - s0
	world.fill_rect(96, 0, 12, 112, SandWorld.M_EMPTY) # open a shaft to the sky
	t.check(Threats.sky_exposure(lamp.position) > 0.0, "shaft lets the lamp see the sky")
	s0 = GameState.suspicion
	Threats.simulate(10.0, 1.0)
	t.check(GameState.suspicion - s0 > buried_gain + 0.05, "light up the shaft at night raises Suspicion")
	GameState.hour = 12.0
	s0 = GameState.suspicion
	Threats.simulate(10.0, 1.0)
	t.check(GameState.suspicion - s0 <= 0.0001, "light doesn't matter by day")
	lamp.queue_free()
	# smoke over the surface
	world.fill_rect(150, 40, 10, 10, SandWorld.M_SMOKE)
	s0 = GameState.suspicion
	Threats.simulate(2.0, 1.0)
	t.check(GameState.suspicion > s0, "smoke over the surface raises Suspicion")
	Threats.auto_tick = true
	Threats.reset()
	GameState.reset()
