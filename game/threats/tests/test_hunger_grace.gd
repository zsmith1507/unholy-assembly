extends RefCounted
## Playtest note 3: Hunger only builds once the lair goes deep, and a grace period opens each run.
## Also note 1: house interiors (sightings through walls, witnesses going in at their door, depth).

func run(t) -> void:
	GameState.reset()
	GameState.hour = 12.0
	# 400 cells tall, ground at row 60 (120 px): room to dig 300+ cells down
	var world: SandWorld = t.flat_world(256, 400, 60)
	Sim.world = world
	Threats.auto_tick = false
	var door := Vector2(300, 120)
	# World keeps interiors wherever it likes; this one sits at coordinates 240 cells "deep"
	var interior := Rect2(200, 600, 120, 60)
	var home := {"id": 7, "rect": Rect2(280, 80, 40, 40), "residents": 1, "alive": 1, "door": door,
		"interior": interior, "door_inside": Vector2(210, 658), "town": "Ashby"}
	var town := {"name": "Ashby", "rect": Rect2(0, 60, 340, 60), "side": -1, "homes": [home]}
	Threats.begin_run({"surface_y_px": 120.0, "towns": [town]})

	var heart := Node2D.new()
	heart.position = Vector2(400, 300)
	t.root.add_child(heart)
	GameState.set_heart(heart, 80.0)
	var necro := Node2D.new()
	necro.add_to_group(&"necro")
	necro.position = Vector2(400, 120 + 20 * Sim.CELL) # 20 cells down
	t.root.add_child(necro)

	# ---- the grace period: nothing rises, whatever he does
	var g0 := Threats.grace_left()
	t.check(is_equal_approx(g0, Threats.GRACE.seconds), "grace starts full (%.0f s)" % g0)
	var ended := []
	Threats.grace_ended.connect(func(): ended.append(1))
	for i in 60:
		Events.noise_made.emit(Vector2(100, 130), 3.0, "grinder") # loud, right by town
		Threats.simulate(1.0, 0.5)
	GameState.add_souls(2.0, "farmer")
	Events.soul_collected.emit(1.0, "farmer", Vector2.ZERO)
	GameState.spend_souls(1.0)
	necro.position.y = 120 + 200 * Sim.CELL # even deep
	Threats.simulate(2.0, 0.5)
	t.check(GameState.suspicion == 0.0, "no Suspicion during the grace period (%.2f)" % GameState.suspicion)
	t.check(GameState.hunger == 0.0, "no Hunger during the grace period (%.2f)" % GameState.hunger)
	t.check(Threats.grace_held.suspicion > 0.5, "the overlay knows what grace held off (%.2f)" % Threats.grace_held.suspicion)
	var gl := Threats.grace_left()
	t.check(absf(gl - (g0 - 62.0)) < 0.6, "grace_left counts down (%.1f s left after 62 s)" % gl)
	t.check(Threats.in_grace() and ended.is_empty(), "still in grace")
	Threats.simulate(gl + 1.0, 1.0)
	t.check(Threats.grace_left() == 0.0 and not Threats.in_grace(), "grace runs out")
	t.check(ended.size() == 1, "grace_ended fired once")
	Events.noise_made.emit(Vector2(100, 130), 3.0, "grinder")
	t.check(GameState.suspicion > 0.0, "after grace, noise raises Suspicion (%.2f)" % GameState.suspicion)

	# ---- Hunger sleeps at the surface and at a normal lair depth for a long time
	Threats.begin_run({"surface_y_px": 120.0, "towns": [town]})
	Threats.end_grace()
	GameState.suspicion = 0.0
	GameState.hunger = 0.0
	necro.position.y = 120 + 95 * Sim.CELL # the opening lair hall's depth
	var minion := Node2D.new()
	minion.add_to_group(&"minions")
	minion.position = Vector2(420, 120 + 120 * Sim.CELL) # a ghoul digging a bit deeper
	t.root.add_child(minion)
	for i in 30: # 30 minutes with a heart, souls coming in and going out, the Dig spell at 100 cells
		GameState.add_souls(1.0, "farmer")
		Events.soul_collected.emit(1.0, "farmer", Vector2.ZERO)
		GameState.spend_souls(0.5)
		Events.noise_made.emit(Vector2(380, 120 + 100 * Sim.CELL), 0.6, "dig")
		Threats.simulate(60.0, 1.0)
	t.check(not Threats.hunger_woken, "Hunger still asleep after 30 min at %d cells (start %d)" % [
		roundi(Threats.max_depth_cells), Threats.HUNGER.start_depth_cells])
	t.check(GameState.hunger == 0.0, "no Hunger from a shallow lair, its heart or its souls (%.2f)" % GameState.hunger)
	t.check(GameState.suspicion > 0.0, "Suspicion still works meanwhile (%.2f)" % GameState.suspicion)

	# a house interior is never "deep", wherever World keeps it
	necro.position = interior.get_center()
	Threats.simulate(2.0, 1.0)
	t.check(not Threats.hunger_woken, "standing in a house interior doesn't wake Hunger")
	necro.position = Vector2(400, 120 + 95 * Sim.CELL)

	# ---- below the threshold, Hunger wakes and builds
	var woke := []
	Threats.hunger_woke.connect(func(d): woke.append(d))
	minion.position.y = 120 + (Threats.HUNGER.start_depth_cells + 5) * Sim.CELL
	Threats.simulate(2.0, 1.0)
	t.check(Threats.hunger_woken and woke.size() == 1, "a ghoul below %d cells woke Hunger" % Threats.HUNGER.start_depth_cells)
	var h1 := GameState.hunger
	t.check(h1 > 0.0, "Hunger jumped when it woke (%.2f)" % h1)
	Threats.simulate(120.0, 1.0)
	t.check(GameState.hunger > h1, "and keeps humming while the lair is deep (%.2f > %.2f)" % [GameState.hunger, h1])
	var h2 := GameState.hunger
	Events.soul_collected.emit(1.0, "farmer", Vector2.ZERO)
	t.check(GameState.hunger > h2, "human souls feed it now that it's awake")
	minion.position.y = 120 + 10 * Sim.CELL
	var h3 := GameState.hunger
	Threats.simulate(60.0, 1.0)
	t.check(Threats.hunger_woken and GameState.hunger > h3, "climbing back up doesn't put it back to sleep")

	# the Dig spell biting deep wakes it too
	Threats.begin_run({"surface_y_px": 120.0, "towns": [town]})
	Threats.end_grace()
	minion.queue_free()
	Events.noise_made.emit(Vector2(380, 120 + 170 * Sim.CELL), 0.8, "dig")
	t.check(Threats.hunger_woken, "the Dig spell 170 cells down wakes Hunger")

	# ---- interiors: noise inside a house is heard at its door, at the surface
	var c: Dictionary = Threats.noise_cost(interior.get_center(), 1.0)
	t.check(c.earth.cells == 0 and c.near, "a noise indoors counts at the front door, by town (%d cells over it)" % c.earth.cells)
	t.check(Threats.outside_point(interior.get_center()) == door, "outside_point maps the interior to its door")

	# sightings only count when they share a space
	GameState.suspicion = 0.0
	necro.position = Vector2(150, 118) # out in the street
	var inside := Node2D.new()
	inside.position = interior.get_center()
	t.root.add_child(inside)
	Events.sighting.emit(inside, necro)
	t.check(Threats.pending_reports.is_empty(), "someone indoors can't see him in the street")
	var street := Node2D.new()
	street.position = Vector2(500, 118)
	t.root.add_child(street)
	necro.position = interior.get_center() + Vector2(20, 0)
	Events.sighting.emit(street, necro)
	t.check(Threats.pending_reports.is_empty(), "someone in the street can't see him indoors")
	Events.sighting.emit(inside, necro)
	t.check(Threats.pending_reports.size() == 1, "a witness in the same room sees him")
	Threats.simulate(1.0, 0.5)
	t.check(Threats.pending_reports.size() == 1, "...and has to get out before anyone hears of it")
	inside.position = door + Vector2(-30, -2) # out of the front door, in town
	Threats.simulate(1.0, 0.5)
	t.check(Threats.pending_reports.is_empty() and GameState.suspicion > 0.0, "out in town, they tell everyone")

	# a resident outdoors runs for their own front door and goes in
	var d := _Door.new()
	d.position = door
	d.inside = home.door_inside
	t.root.add_child(d)
	var res := _Resident.new()
	res.position = Vector2(600, 118)
	t.root.add_child(res)
	necro.position = Vector2(640, 118)
	Events.sighting.emit(res, necro)
	t.check(res.route.size() == 1 and res.route[0] == door and res.mode == &"flee", "the witness runs for their door")
	var s0 := GameState.suspicion
	res.position = door + Vector2(4, 0)
	Threats.simulate(1.0, 0.5)
	t.check(d.used == 1 and interior.has_point(res.position), "they went in through the door")
	t.check(Threats.pending_reports.is_empty() and GameState.suspicion > s0, "and their report counts")

	for n in [heart, necro, inside, street, d, res]:
		n.queue_free()
	GameState.clear_heart()
	Threats.auto_tick = true
	Threats.reset()
	GameState.reset()


class _Door extends Node2D:
	var inside := Vector2.ZERO
	var used := 0

	func _ready() -> void:
		add_to_group(&"doors")

	func interact(by: Node2D) -> void:
		used += 1
		by.global_position = inside
		Events.entered_building.emit(self, by)


class _Resident extends Node2D:
	var home_id := 7
	var route := PackedVector2Array()
	var mode := &"work"

	func set_route(p: PackedVector2Array) -> void:
		route = p

	func set_mode(m: StringName) -> void:
		mode = m
