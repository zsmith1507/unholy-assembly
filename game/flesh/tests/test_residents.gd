extends RefCounted
## Round 5 (Zach's notes 1 and 2): residents live inside their house's interior. They sleep inside at
## night, come out through the front door by day and go back in at dusk; a bigger house holds more of
## them; the knife (take_damage) kills them indoors like anywhere else.

const DOOR_SRC := """
extends Node2D
var to := Vector2.ZERO
var used := 0
func _ready() -> void:
	add_to_group(&"doors")
func interact(by) -> void:
	used += 1
	by.global_position = to
"""


func _door(t, at: Vector2, to: Vector2) -> Node2D:
	var s := GDScript.new()
	s.source_code = DOOR_SRC
	s.reload()
	var d: Node2D = Node2D.new()
	d.set_script(s)
	d.position = at
	d.set("to", to)
	t.root.add_child(d)
	return d


func run(t) -> void:
	var w: SandWorld = t.flat_world(512, 200, 100)
	var ground := 200.0
	GameState.hour = 21.0
	# the interior: a brick room up in the sky, as World builds them away from the facades
	w.fill_rect(400, 10, 62, 42, SandWorld.M_BRICK)
	w.fill_rect(402, 12, 58, 38, SandWorld.M_EMPTY)
	var inner := Rect2(804, 24, 116, 76)
	var door_in := Vector2(812, 100)
	var big := {"id": 1, "rect": Rect2(300, 160, 60, 40), "residents": 3, "alive": 3, "door": Vector2(356, ground),
		"interior": inner, "door_inside": door_in}
	var small := {"id": 2, "rect": Rect2(160, 160, 30, 40), "residents": 1, "alive": 1, "door": Vector2(186, ground)}
	var info := {"towns": [{"name": "Ashby", "rect": Rect2(150, 140, 260, 60), "side": 1, "homes": [big, small]}]}
	var outer := _door(t, Vector2(356, ground), door_in)
	var indoor := _door(t, door_in, Vector2(356, ground))
	var inst = load("res://flesh/install.gd").new()
	inst.install(t.root, info)
	await t.ticks(5)
	var people: Array = t.root.get_children().filter(func(n): return n is Human)
	var inside: Array = people.filter(func(h): return h.home_id == 1)
	var outside: Array = people.filter(func(h): return h.home_id == 2)
	t.check(inside.size() == 3, "a bigger house gets one resident per its residents count (%d)" % inside.size())
	t.check(inside.all(func(h): return h.is_inside() and inner.has_point(h.global_position + Vector2(0, -4))), "residents spawn inside the house's interior")
	t.check(outside.size() == 1 and absf(outside[0].global_position.y - ground) < 4.0 and not outside[0].interior.has_area(), "a home without an interior keeps the old placement")
	var xs: Array = inside.map(func(h): return roundi(h.global_position.x))
	t.check(xs[0] != xs[1] and xs[1] != xs[2], "spread round the room (%s)" % [xs])

	# --- night: they stay in
	await t.ticks(180)
	t.check(inside.all(func(h): return h.is_inside() and h.at_home), "at night they stay inside, at home")

	# --- day: out through the door
	GameState.hour = 8.0
	var n := 0
	while n < 900 and inside.any(func(h): return h.is_inside()):
		n += 1
		await t.ticks(1)
	t.note("all out after %d ticks; door used %d times" % [n, indoor.used])
	t.check(inside.all(func(h): return not h.is_inside() and absf(h.global_position.y - ground) < 6.0), "by day they come out of the front door")
	t.check(indoor.used >= 3, "through World's door (interact)")
	await t.ticks(120)
	t.check(inside.all(func(h): return not h.is_inside()), "and stay out working")

	# --- dusk: back in
	GameState.hour = 20.5
	n = 0
	while n < 1500 and inside.any(func(h): return not h.is_inside()):
		n += 1
		await t.ticks(1)
	t.note("all home after %d ticks; front door used %d times" % [n, outer.used])
	t.check(inside.all(func(h): return h.is_inside()), "at dusk they go back in")

	# --- no door node: they still get in and out (straight to the paired spot)
	outer.queue_free()
	indoor.queue_free()
	GameState.hour = 9.0
	n = 0
	while n < 900 and inside.any(func(h): return h.is_inside()):
		n += 1
		await t.ticks(1)
	t.check(inside.all(func(h): return not h.is_inside()), "without door nodes they step out by themselves")
	GameState.hour = 21.0
	n = 0
	while n < 1500 and inside.any(func(h): return not h.is_inside()):
		n += 1
		await t.ticks(1)
	t.check(inside.all(func(h): return h.is_inside()), "and back in")

	# --- the knife kills them indoors
	var victim: Human = inside[0]
	var at := victim.global_position
	var killed: Array = []
	var on_kill := func(h, _w): killed.append(h)
	Events.human_killed.connect(on_kill)
	for i in 20:
		if not is_instance_valid(victim) or victim.dead:
			break
		victim.take_damage(8.0, null)
		await t.ticks(1)
	Events.human_killed.disconnect(on_kill)
	await t.ticks(2)
	var corpses: Array = t.root.get_children().filter(func(c): return c is Corpse and c.global_position.distance_to(at) < 60.0)
	t.check(killed.size() == 1 and corpses.size() == 1, "stabbed indoors, a resident dies into a corpse on the floor")
