extends NecroSpell
## Harvest (the grave-wind): a cone of necrotic wind from his palm that draws bodies, parts and loose
## things toward his hand. Whatever reaches the hand drops at his feet for the ghouls to haul, and the
## harvest is announced on Events.body_harvested. It is also how he robs graves by magic: bore a tunnel
## down to a coffin with Dig, then draw the corpse up through it.
##
## Uses the Pullables hook: nodes in group "pullable" with apply_pull(force) (px per tick², one tick).
## The wind only reaches what it can see: a body behind solid ground isn't pulled.

const HARV := {
	"cost": 0.06, # souls' worth of mana per second of channelling
	"range_px": 180.0, # reach of the cone from his hand
	"cone": 0.56, # half-angle of the cone, radians (about 32 degrees either side)
	"pull": 0.38, # pull at the far edge of the reach, px per tick² (gravity is 0.25)
	"pull_near": 0.5, # extra pull close to the hand
	"max_speed": 4.0, # things fly toward the hand no faster than this, px per tick
	"steer": 0.12, # share of sideways drift removed per tick, so things home in on the hand
	"collect_px": 14.0, # within this of the hand, a thing is harvested and dropped at his feet
	"ignore_ticks": 75, # a dropped thing isn't pulled again for this long (stops it bouncing back up)
	"grains_per_tick": 3, # loose dirt and blood sucked toward the hand each tick (feel)
	"grain_speed": 3.0, # px per tick for those grains
	"wind_motes": 3, # FX: wind motes spawned per tick
}

var pulling: Array = [] ## nodes pulled on the last tick (tests and FX read this)
var harvested_total := 0
var _on := false
var _hand := Vector2.ZERO
var _dir := Vector2.RIGHT
var _t := 0


func _init() -> void:
	id = &"harvest"
	title = "Harvest"
	color = Color(0.5, 0.95, 0.85)


func cost_text() -> String:
	return NecroText.t("spell.cost_per_s", "{c} souls/s", {"c": "%.2f" % HARV.cost})


func on_deselect() -> void:
	super.on_deselect()
	_on = false
	pulling = []


func tick(aim: Vector2, held: bool, _pressed: bool, _released: bool) -> void:
	_t += 1
	channelling = false
	_on = false
	pulling = []
	if not held:
		return
	if not GameState.spend_mana(HARV.cost / 60.0):
		necro.warn_no_mana()
		return
	channelling = true
	_on = true
	_hand = necro.get_hand_pos()
	_dir = aim - _hand
	_dir = _dir.normalized() if _dir.length() > 0.01 else Vector2(necro.facing, 0)
	var feet: Vector2 = necro.global_position
	for n in get_tree().get_nodes_in_group("pullable"):
		if not (n is Node2D) or n == necro or not is_instance_valid(n):
			continue
		if n is Item and n.carrier != null:
			continue
		if int(n.get_meta("necro_dropped_at", -100000)) + HARV.ignore_ticks > _t:
			continue
		var p := _target_point(n)
		var to := p - _hand
		var d := to.length()
		if d <= HARV.collect_px:
			_collect(n, feet)
			continue
		if not in_cone(p):
			continue
		if not _visible(p):
			continue
		var near := 1.0 - clampf(d / HARV.range_px, 0.0, 1.0)
		var dir := -to / d
		var force := dir * (HARV.pull + HARV.pull_near * near)
		if "velocity" in n:
			# ease off near top speed, and trim sideways drift so things home in on the hand
			var v: Vector2 = n.velocity
			var along := v.dot(dir)
			force *= clampf(HARV.max_speed - along, 0.0, 1.0)
			force -= (v - dir * along) * HARV.steer
		if n.has_method("apply_pull"):
			n.apply_pull(force)
		elif "velocity" in n:
			n.velocity += force
		pulling.append(n)
	_suck_grains()
	_wind_fx()


## True when a point is inside the wind's cone and reach.
func in_cone(p: Vector2) -> bool:
	var to := p - _hand
	var d := to.length()
	if d > HARV.range_px or d < 0.5:
		return false
	return to.dot(_dir) / d >= cos(HARV.cone)


func _target_point(n: Node2D) -> Vector2:
	if n.has_method("get_box"):
		return n.get_box().get_center()
	return n.global_position


## Clear air between hand and target (a little slack for the target's own surface).
func _visible(p: Vector2) -> bool:
	var hit = Sim.raycast_px(_hand, p, false)
	return hit == null or (hit as Vector2).distance_to(p) <= 6.0


## Reached his hand: drop it at his feet for the ghouls and announce it.
func _collect(n: Node2D, feet: Vector2) -> void:
	var drop_at := feet + Vector2(necro.facing * 10.0, -1.0)
	if n is Item:
		n.drop(drop_at, Vector2(necro.facing * 0.5, 0.0))
	elif "velocity" in n:
		n.global_position = drop_at
		n.velocity = Vector2.ZERO
	else:
		n.global_position = drop_at
	n.set_meta("necro_dropped_at", _t)
	harvested_total += 1
	if n is Item or n.is_in_group("items"):
		Events.body_harvested.emit(n)
	for k in 8:
		emit_part(_hand, Vector2.from_angle(randf() * TAU) * randf_range(0.5, 1.8), TEAL, randi_range(12, 24), true, 1.5)


## The wind lifts loose grave dirt and blood in the cone and throws it toward his hand.
func _suck_grains() -> void:
	var w := Sim.world
	if w == null or HARV.grains_per_tick <= 0:
		return
	for k in HARV.grains_per_tick * 3:
		var ang := _dir.angle() + randf_range(-HARV.cone, HARV.cone)
		var dist := randf_range(16.0, HARV.range_px)
		var p := _hand + Vector2.from_angle(ang) * dist
		var c := Sim.to_cell(p)
		var kind := w.get_kind(c.x, c.y)
		if kind != 2 and kind != 3: # powder or liquid
			continue
		var mat := w.get_mat(c.x, c.y)
		if mat == SandWorld.M_RUBBLE:
			continue # too heavy for the wind
		if not _visible(p):
			continue
		w.set_mat(c.x, c.y, SandWorld.M_EMPTY)
		var v := (_hand - p).normalized() * HARV.grain_speed + Vector2(0, -0.6)
		Sim.spill_px(p, mat, 1, v)


func _wind_fx() -> void:
	for k in HARV.wind_motes:
		var ang := _dir.angle() + randf_range(-HARV.cone, HARV.cone)
		var dist := randf_range(HARV.range_px * 0.3, HARV.range_px)
		var p := _hand + Vector2.from_angle(ang) * dist
		var v := (_hand - p) / randf_range(22.0, 34.0)
		emit_part(p, v, Color(color, 0.55), randi_range(18, 30), true, 1.0)


func _physics_process(delta: float) -> void:
	# wind motes are drawn in toward the hand rather than slowing down
	for q in _parts:
		if q.glow and _on:
			q.v = q.v.lerp((_hand - q.p) * 0.08, 0.15)
	super._physics_process(delta)


func _draw_glow() -> void:
	super._draw_glow()
	if not _on:
		return
	var pulse := 0.7 + 0.3 * sin(_t * 0.3)
	var a := _dir.angle()
	var pts := PackedVector2Array([_hand])
	for i in 13:
		pts.append(_hand + Vector2.from_angle(a - HARV.cone + 2.0 * HARV.cone * i / 12.0) * HARV.range_px)
	var cols := PackedColorArray()
	cols.append(Color(TEAL, 0.16 * pulse))
	for i in 13:
		cols.append(Color(TEAL, 0.0))
	_glow.draw_polygon(pts, cols)
	glow_circle(_hand, 4.0 * pulse, Color(TEAL, 0.5))
	for n in pulling:
		if is_instance_valid(n):
			glow_line(_target_point(n), _hand, Color(TEAL, 0.18), 1.0)
