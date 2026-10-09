extends Node2D
## A stand-in farmer used only when Bodies and Souls has no flesh_spawner yet.
## Speaks the Human orders hook: set_route, investigate, set_mode, fear, signal noticed.

signal noticed(what: Node2D)

const STAND_IN := {"speed_px_s": 34.0, "run_mult": 2.0, "size": Vector2(18, 60), "look_every_s": 0.5}

var fear := 0.3
var dead := false
var mode: StringName = &"patrol"
var route := PackedVector2Array()
var display_name := "Farmer"
var _i := 0
var _target := Vector2.INF
var _look := 0.0
var _seen := {}


func _ready() -> void:
	add_to_group("humans")
	add_to_group("actors")


func set_route(points: PackedVector2Array) -> void:
	route = points
	_i = 0
	_target = Vector2.INF


func investigate(at: Vector2) -> void:
	_target = at


func set_mode(m: StringName) -> void:
	mode = m


func _physics_process(dt: float) -> void:
	if dead:
		return
	var goal := _goal()
	var speed: float = STAND_IN.speed_px_s * (STAND_IN.run_mult if mode in [&"flee", &"attack", &"home"] else 1.0)
	if goal != Vector2.INF:
		var dx := goal.x - position.x
		position.x += clampf(dx, -speed * dt, speed * dt)
		if absf(dx) < 4.0:
			if _target != Vector2.INF and goal == _target:
				_target = Vector2.INF
			elif route.size() > 0:
				_i = mini(_i + 1, route.size() - 1) if mode != &"patrol" else (_i + 1) % route.size()
	position.y = Threats.surface_at(position.x)
	_look -= dt
	if _look <= 0.0:
		_look = STAND_IN.look_every_s
		_look_around()
	queue_redraw()


func _goal() -> Vector2:
	if _target != Vector2.INF and mode != &"flee" and mode != &"home":
		return _target
	if route.is_empty():
		return Vector2.INF
	return route[clampi(_i, 0, route.size() - 1)]


func _look_around() -> void:
	var r: float = Threats.PATROL.sight_px
	for g in [&"minions", &"necro"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node2D and is_instance_valid(n) and (n as Node2D).global_position.distance_to(global_position) <= r:
				var id: int = n.get_instance_id()
				if _seen.has(id):
					continue
				_seen[id] = true
				noticed.emit(n)
				Events.sighting.emit(self, n)


func take_damage(amount: float, _source: Node2D = null) -> void:
	if amount >= 1.0:
		die()


func die(killer: Node2D = null) -> void:
	if dead:
		return
	dead = true
	Events.actor_died.emit(self, killer, global_position)
	queue_free()


func _draw() -> void:
	var s: Vector2 = STAND_IN.size
	var col := Color(0.55, 0.42, 0.28) if mode != &"flee" else Color(0.75, 0.65, 0.4)
	draw_rect(Rect2(-s.x / 2, -s.y, s.x, s.y), col)
	draw_rect(Rect2(-s.x / 2 - 2, -s.y - 4, s.x + 4, 6), Color(0.3, 0.22, 0.12)) # hat
	draw_line(Vector2(s.x / 2, -s.y * 0.7), Vector2(s.x / 2 + 10, -s.y - 10), Color(0.5, 0.5, 0.5), 2.0) # pitchfork
