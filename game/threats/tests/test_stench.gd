extends RefCounted
## Stench: bodies left too long smell, worse near the surface; stench_sources() lists them.

func run(t) -> void:
	var world: SandWorld = t.flat_world(256, 200, 60)
	Sim.world = world
	Threats.auto_tick = false
	Threats.begin_run({"surface_y_px": 120.0, "towns": []})
	var shallow := Node2D.new()
	shallow.position = Vector2(100, 140)
	shallow.add_to_group("item_corpse")
	t.root.add_child(shallow)
	var deep := Node2D.new()
	deep.position = Vector2(400, 360)
	deep.add_to_group("item_corpse")
	t.root.add_child(deep)
	Threats.simulate(Threats.STENCH.grace_s - 5.0, 1.0)
	t.check(Threats.stench_sources().is_empty(), "fresh bodies don't smell yet")
	var s0 := GameState.suspicion
	Threats.simulate(Threats.STENCH.ramp_s + 10.0, 1.0)
	var src: Array = Threats.stench_sources()
	t.check(src.size() == 2, "two ripe bodies listed (%d)" % src.size())
	if src.size() == 2:
		var a: Dictionary = src[0] if src[0].pos.y < src[1].pos.y else src[1]
		var b: Dictionary = src[1] if a == src[0] else src[0]
		t.check(a.surface_strength > b.surface_strength, "the shallow body smells worse at the surface")
	t.check(GameState.suspicion > s0, "stench raised Suspicion")
	var found := false
	for e in Threats.ledger:
		if e.key == "stench":
			found = true
	t.check(found, "ledger explains the stench")
	shallow.queue_free()
	deep.queue_free()
	await t.ticks(1)
	Threats.simulate(2.0, 1.0)
	t.check(Threats.stench_sources().is_empty(), "removed bodies stop smelling")
	Threats.auto_tick = true
	Threats.reset()
