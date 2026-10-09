extends Node2D
## Farmer patrols: leave each town along World's patrol routes, investigate noises and sightings,
## raise the alarm, fight or flee by fear, and at high Suspicion search for (then raid) the heart.
## Tuning lives in Threats.PATROL (threat_director.gd).

signal patrol_left(patrol: Dictionary)
signal patrol_returned(patrol: Dictionary)

var info: Dictionary = {}
var out: Array = [] ## {id, town, members: Array, route, t, home_t, raid}
var _next := {} ## town index -> seconds until the next patrol
var _clock := 0.0
var _tunnel_t := 0.0
var _id := 0


func _ready() -> void:
	Threats.patrols = self
	info = Threats.info
	Threats.noise_heard.connect(_on_noise_heard)
	Threats.sighting_logged.connect(_on_sighting)
	Events.actor_died.connect(_on_actor_died)


func _physics_process(dt: float) -> void:
	if Threats.auto_tick:
		tick(dt)


func tick(dt: float) -> void:
	info = Threats.info
	_clock += dt
	var towns: Array = info.get("towns", [])
	for t in towns.size():
		if not _next.has(t):
			_next[t] = float(Threats.PATROL.first_after_s) + t * 20.0
		_next[t] = float(_next[t]) - dt
		if float(_next[t]) <= 0.0:
			_next[t] = Threats.patrol_interval()
			if out.size() < int(Threats.PATROL.max_out):
				send(t)
	for p in out.duplicate():
		_update(p, dt)
	_tunnel_t -= dt
	if _tunnel_t <= 0.0:
		_tunnel_t = Threats.PATROL.tunnel_check_every_s
		_check_tunnels()


## Send a patrol out of town `t` now. Returns the patrol, or {} if nobody could be spawned.
func send(t: int) -> Dictionary:
	var towns: Array = info.get("towns", [])
	if t < 0 or t >= towns.size():
		return {}
	var rect: Rect2 = towns[t].get("rect", Rect2())
	var start := Vector2(rect.get_center().x, Threats.surface_at(rect.get_center().x))
	var raid := GameState.has_heart and GameState.suspicion >= Threats.PATROL.raid_at
	var size := Threats.patrol_size() + (int(Threats.PATROL.raid_extra) if raid else 0)
	var route := _route_for(t, start)
	var members: Array = []
	for i in size:
		var m := _spawn(start + Vector2((i - size / 2.0) * 14.0, 0))
		if m == null:
			continue
		members.append(m)
		_order(m, "set_route", [route])
		_order(m, "set_mode", [&"attack" if raid else &"patrol"])
		if m.has_signal("noticed"):
			m.connect("noticed", _on_member_noticed.bind(m))
	if members.is_empty():
		return {}
	_id += 1
	var p := {"id": _id, "town": t, "members": members, "route": route, "t": 0.0, "home_t": -1.0, "raid": raid}
	out.append(p)
	var what := "raid" if raid else ("search party" if _searching() else "patrol")
	Threats.note("patrol", "a %s of %d left %s%s" % [what, members.size(), _town_name(t),
		" at night" if GameState.is_night() else ""])
	if raid:
		Threats.raid_started.emit(Threats.heart_surface_pos())
	patrol_left.emit(p)
	return p


func members_out() -> Array:
	var all: Array = []
	for p in out:
		for m in p.members:
			if is_instance_valid(m):
				all.append(m)
	return all


func _searching() -> bool:
	return GameState.has_heart and GameState.suspicion >= Threats.PATROL.search_at


func _route_for(t: int, start: Vector2) -> PackedVector2Array:
	var route := PackedVector2Array()
	var routes: Array = info.get("patrol_routes", [])
	var best := INF
	for r in routes:
		var pr := r as PackedVector2Array
		if pr.is_empty():
			continue
		var d := pr[0].distance_to(start)
		if d < best:
			best = d
			route = pr.duplicate()
	if route.is_empty():
		var side: int = int(info.get("towns", [])[t].get("side", -1))
		var dir := -side if side != 0 else 1
		var x1 := start.x + dir * float(Threats.PATROL.wander_px)
		route = PackedVector2Array([start, Vector2(x1, Threats.surface_at(x1))])
	if _searching():
		# they have a guess where it is; the closer to 100, the better the guess
		var h := Threats.heart_surface_pos()
		var j: Array = Threats.PATROL.search_jitter_px
		var k := clampf((GameState.suspicion - Threats.PATROL.search_at) / maxf(1.0, 100.0 - Threats.PATROL.search_at), 0.0, 1.0)
		var off := randf_range(-1.0, 1.0) * lerpf(float(j[0]), float(j[1]), k)
		var gx := h.x + off
		route = PackedVector2Array([start, Vector2(gx, Threats.surface_at(gx))])
	return route


func _spawn(at: Vector2) -> Node2D:
	var sp := get_tree().get_first_node_in_group("flesh_spawner")
	if sp != null and sp.has_method("spawn_human"):
		var h = sp.spawn_human(Threats.PATROL.kind, at)
		if h is Node2D:
			return h
	if not Threats.PATROL.use_stand_ins:
		return null
	var f: Node2D = load("res://threats/stand_in_farmer.gd").new()
	f.position = at
	add_child(f)
	return f


func _order(m: Object, method: String, args: Array) -> void:
	if m != null and is_instance_valid(m) and m.has_method(method):
		m.callv(method, args)


func _update(p: Dictionary, dt: float) -> void:
	p.t += dt
	var alive: Array = []
	for m in p.members:
		if is_instance_valid(m) and not Threats._is_dead(m):
			alive.append(m)
	p.members = alive
	if alive.is_empty():
		out.erase(p)
		return
	if p.home_t < 0.0 and p.t >= Threats.PATROL.duration_s:
		_head_home(p)
	if p.home_t >= 0.0:
		var towns: Array = info.get("towns", [])
		var rect: Rect2 = towns[p.town].get("rect", Rect2()) if p.town < towns.size() else Rect2()
		for m in alive.duplicate():
			var home: bool = rect.grow(Threats.WITNESS.home_margin_px).has_point((m as Node2D).global_position)
			if home or p.t - p.home_t >= Threats.PATROL.home_timeout_s:
				p.members.erase(m)
				(m as Node).queue_free()
		if p.members.is_empty():
			out.erase(p)
			patrol_returned.emit(p)


func _head_home(p: Dictionary) -> void:
	p.home_t = p.t
	var towns: Array = info.get("towns", [])
	if p.town >= towns.size():
		return
	var c: Vector2 = (towns[p.town].get("rect", Rect2()) as Rect2).get_center()
	var home := PackedVector2Array([Vector2(c.x, Threats.surface_at(c.x))])
	for m in p.members:
		_order(m, "set_route", [home])
		_order(m, "set_mode", [&"home"])


## Members near enough to hear go and look.
func _on_noise_heard(at: Vector2, audible: float, source: String) -> void:
	if audible < Threats.PATROL.investigate_min:
		return
	var r: float = Threats.PATROL.hear_px * sqrt(audible)
	var sent := 0
	for m in members_out():
		if (m as Node2D).global_position.distance_to(at) <= r:
			_order(m, "investigate", [at])
			sent += 1
	if sent > 0:
		Threats.note("patrol", "%d farmer%s went to look at a %s noise" % [sent, "" if sent == 1 else "s", source])


func _on_sighting(at: Vector2, witness: Node2D) -> void:
	for m in members_out():
		if m != witness and (m as Node2D).global_position.distance_to(at) <= Threats.PATROL.sighting_call_px:
			_order(m, "investigate", [at])


## A member saw something: shout, then fight or run by fear.
func _on_member_noticed(what: Node2D, m: Node2D) -> void:
	if not is_instance_valid(m) or what == null or not is_instance_valid(what):
		return
	Threats.raise_alarm(m.global_position, "a farmer saw %s" % Threats._who(what), m)
	_fight_or_flee(m, what.global_position)


func _fight_or_flee(m: Node2D, at: Vector2) -> void:
	var f = m.get("fear")
	var fear: float = float(f) if f != null else 0.3
	if fear >= Threats.PATROL.flee_fear:
		var towns: Array = info.get("towns", [])
		var t := _nearest_town(m.global_position)
		if t >= 0:
			var c: Vector2 = (towns[t].rect as Rect2).get_center()
			_order(m, "set_route", [PackedVector2Array([Vector2(c.x, Threats.surface_at(c.x))])])
		_order(m, "set_mode", [&"flee"])
	else:
		_order(m, "investigate", [at])
		_order(m, "set_mode", [&"attack"])


func _on_actor_died(actor: Node2D, _killer: Node2D, at: Vector2) -> void:
	for p in out:
		if not p.members.has(actor):
			continue
		for m in p.members:
			if m == actor or not is_instance_valid(m):
				continue
			var f = m.get("fear")
			if f != null:
				m.set("fear", clampf(float(f) + Threats.PATROL.fear_on_ally_death, 0.0, 1.0))
			_fight_or_flee(m, at)
		Threats.raise_alarm(at, "a farmer on patrol was killed", null)


## A farmer walking past a dug hole notices it.
func _check_tunnels() -> void:
	var w := Sim.world
	if w == null:
		return
	var look: float = Threats.PATROL.tunnel_look_px
	for m in members_out():
		var p: Vector2 = (m as Node2D).global_position
		var x := p.x - look
		while x <= p.x + look:
			var c := Sim.to_cell(Vector2(x, Threats.surface_at(x)))
			var deep := int(Threats.PATROL.tunnel_depth_cells)
			if w.in_bounds(c.x, c.y + deep) and _open_column(w, c.x, c.y + 2, deep):
				var hole := Sim.to_pixel(Vector2i(c.x, c.y))
				var key := "tunnel:%d" % int(hole.x / 64.0)
				if not m.has_meta(key):
					m.set_meta(key, true)
					_order(m, "investigate", [hole])
					Threats.start_report(m, "a hole dug into the ground", hole, Threats.WITNESS.tunnel_mult)
				break
			x += 8.0


func _open_column(w: SandWorld, cx: int, y0: int, n: int) -> bool:
	for i in n:
		if w.is_solid(cx, y0 + i):
			return false
	return true


func _nearest_town(p: Vector2) -> int:
	var towns: Array = info.get("towns", [])
	var best := -1
	var bd := INF
	for i in towns.size():
		var d := (towns[i].get("rect", Rect2()) as Rect2).get_center().distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func _town_name(t: int) -> String:
	return Threats._town_name(t)
