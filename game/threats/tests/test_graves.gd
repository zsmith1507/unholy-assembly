extends RefCounted
## Robbed graves by body (the `grave_corpses` group) and by wood; residents dying away from home still shrink
## their town; a heart rebuilt far away starts with less Suspicion.

class FakeHuman extends Node2D:
	var home_id := -1


class FakeSettlements extends Node:
	var list: Array[Dictionary] = []
	func _ready() -> void:
		add_to_group("settlements")
	func homes() -> Array[Dictionary]:
		return list


func run(t) -> void:
	var world: SandWorld = t.flat_world(256, 200, 60)
	Sim.world = world
	Threats.auto_tick = false
	var town := {"name": "Ashby", "rect": Rect2(0, 80, 120, 40), "side": -1, "homes": []}
	var grave_a := Vector2(300, 140) # has a body node
	var grave_b := Vector2(400, 140) # only coffin wood
	world.fill_rect(195, 68, 10, 3, SandWorld.M_WOOD)
	Threats.begin_run({"surface_y_px": 120.0, "towns": [town], "graves": [grave_a, grave_b],
		"graveyard": Rect2(280, 100, 160, 40)})

	# a body in the ground, then Harvest's first touch takes it out of the group (coffin wood untouched)
	var body := Node2D.new()
	body.position = grave_a
	body.add_to_group(&"grave_corpses")
	t.root.add_child(body)
	Threats.simulate(5.0, 1.0)
	t.check(Threats.graves_waiting_to_be_found() == 0, "an untouched grave is not robbed")
	body.remove_from_group(&"grave_corpses")
	Threats.simulate(5.0, 1.0)
	t.check(Threats.graves_waiting_to_be_found() == 1, "a body leaving grave_corpses is a robbed grave")
	# wood check for a grave with no body node
	world.fill_rect(195, 68, 10, 3, SandWorld.M_EMPTY)
	Threats.simulate(5.0, 1.0)
	t.check(Threats.graves_waiting_to_be_found() == 2, "a grave with its coffin gone is robbed (wood fallback)")
	var found := []
	Threats.grave_found.connect(func(at): found.append(at))
	var s0 := GameState.suspicion
	Threats.simulate(Threats.SUSPICION.grave_discover_s + 5.0, 1.0)
	t.check(found.size() == 2 and GameState.suspicion > s0, "both robbed graves are found later and raise Suspicion")
	body.queue_free()

	# a resident of Ashby killed out in the forest still shrinks Ashby
	var st := FakeSettlements.new()
	st.list = [{"id": 1, "rect": Rect2(10, 90, 40, 30), "residents": 4, "alive": 4, "town": "Ashby"},
		{"id": 2, "rect": Rect2(60, 90, 40, 30), "residents": 2, "alive": 2, "town": "Ashby"}]
	t.root.add_child(st)
	t.check(Threats.town_population(0) == 6, "population comes from World's homes by town name (%d)" % Threats.town_population(0))
	var shrank := false
	for i in 4:
		var h := FakeHuman.new()
		h.add_to_group("humans")
		h.home_id = 1
		t.root.add_child(h)
		Events.actor_died.emit(h, null, Vector2(480, 118)) # far from town
		h.queue_free()
	for e in Threats.ledger:
		if e.key == "cull":
			shrank = true
	t.check(shrank, "four of six Ashby residents dying in the forest is 'shrinking fast'")
	st.queue_free()

	# moving house
	var heart := Node2D.new()
	heart.position = Vector2(200, 300)
	t.root.add_child(heart)
	GameState.set_heart(heart, 100.0)
	GameState.suspicion = 60.0
	GameState.clear_heart()
	heart.position = Vector2(2200, 300)
	GameState.set_heart(heart, 100.0)
	t.check(GameState.suspicion < 60.0 * (1.0 - 0.4), "a heart rebuilt 2000 px away starts lower (%.1f)" % GameState.suspicion)
	GameState.clear_heart()
	heart.queue_free()
	Threats.auto_tick = true
	Threats.reset()
	GameState.reset()
