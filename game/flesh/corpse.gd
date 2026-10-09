class_name Corpse
extends Item
## A dead human: a six-part ragdoll (verlet points on BodyRig's skeleton) that flops into the sand world.
## Harvest (apply_pull) strains its joints; light parts tear off first: arms, then the head, legs, torso.
## Each tear leaves a stump that pumps blood into the sim while the blood timer lasts.
## Siphon drinks its blood (rich mana) then its flesh (thin mana); empty, it crumbles to ash.
## Owned by Bodies and Souls.

const CORPSE := {
	"gravity": 0.25, ## px per tick²
	"damping": 0.985, ## velocity kept per tick in the air
	"ground_friction": 0.7, ## sideways velocity kept per tick on the ground
	"iterations": 4, ## constraint passes per tick
	"blood_seconds": 90.0, ## the blood timer: a fresh body's blood is gone (dried, drained) after this
	"joint_strength": 26.0, ## strain a weight-1 joint takes before it tears (strain += pull / weight per tick)
	"old_joint_strength": 14.0, ## graveyard bodies come apart easily
	"strain_relax": 0.97, ## strain kept per tick when nobody is pulling
	"pump_rate": 0.55, ## chance per tick that a fresh wound squirts a cell of blood (times its strength)
	"pump_beat": 7.0, ## heartbeat-ish pulse, radians per second (the heart has stopped; the gore has not)
	"spurt_speed": 1.6, ## px per tick
	"tear_spurt": 14, ## cells of blood flung when a part tears free
	"blood_mana": 0.35, ## souls' worth from a full body's blood
	"flesh_mana": 0.12, ## souls' worth from the meat once the blood is gone
	"old_tint": Color(0.62, 0.66, 0.58),
	"ash_cells": 22,
}

var look := "villager"
var fresh := true ## false for graveyard bodies: no blood, no soul
var blood := 1.0 ## 0..1 of the body's blood left in it
var flesh := 1.0 ## 0..1 left for Siphon once the blood is gone
var pts := {} ## point name -> world position
var prev := {} ## point name -> world position last tick
var attached := {} ## seg key -> true while still on the body
var strain := {} ## seg key -> accumulated strain
var wounds: Array = [] ## [{pt: String, strength: float}]
var _pulled := false
var _rig: BodyRig
var _t := 0.0
var _last_pos := Vector2.ZERO


func _init() -> void:
	kind = &"corpse"
	box_size = Vector2(16, 6)


## Call before adding to the tree. `pose` is BodyRig points in world space (living pose at death, or lying).
func setup(look_name: String, pose: Dictionary, vel := Vector2.ZERO, is_fresh := true) -> void:
	look = look_name
	fresh = is_fresh
	blood = 1.0 if fresh else 0.0
	flesh = 1.0 if fresh else 0.6
	for k in BodyRig.PT_NAMES:
		pts[k] = pose[k]
		prev[k] = pose[k] - vel
	for seg in BodyRig.SEGS:
		attached[seg[0]] = true
		strain[seg[0]] = 0.0
	data = {"source": look_name, "fresh": fresh, "parts": attached.keys()}
	position = pts["hip"]
	if fresh:
		wounds.append({"pt": "neck", "strength": 0.6})


func _ready() -> void:
	super._ready()
	add_to_group(&"pullable")
	add_to_group(&"siphonable")
	add_to_group(&"corpses")
	_rig = BodyRig.new()
	_rig.setup(look)
	if not fresh:
		_rig.modulate = CORPSE.old_tint
	add_child(_rig)
	_last_pos = global_position
	_redraw_rig()


func _physics_process(delta: float) -> void:
	_t += delta
	if carrier != null:
		var shift := global_position - _last_pos
		for k in pts:
			pts[k] += shift
			prev[k] = pts[k]
	else:
		_step()
		global_position = pts["hip"]
	_last_pos = global_position
	if not _pulled:
		for k in strain:
			strain[k] *= CORPSE.strain_relax
	_pulled = false
	_bleed(delta)
	_redraw_rig()


# ---------------------------------------------------------------- ragdoll

func _live_points() -> Array:
	var out := ["hip", "neck"]
	for seg in BodyRig.SEGS:
		if attached.get(seg[0], false) and not out.has(seg[2]):
			out.append(seg[2])
	return out


func _step() -> void:
	var live := _live_points()
	for k in live:
		var p: Vector2 = pts[k]
		var v: Vector2 = (p - prev[k]) * CORPSE.damping
		v.y += CORPSE.gravity
		prev[k] = p
		pts[k] = _collide(p, p + v)
	for i in CORPSE.iterations:
		for seg in BodyRig.SEGS:
			if not attached.get(seg[0], false):
				continue
			_constrain(seg[1], seg[2], BodyRig.RIG[BodyRig.PART[seg[0]]])
	# floor friction: a point resting on ground loses most of its sideways speed
	for k in live:
		if Sim.solid_at(pts[k] + Vector2(0, 1.5)):
			var p: Vector2 = pts[k]
			var px: float = prev[k].x
			prev[k] = Vector2(p.x - (p.x - px) * CORPSE.ground_friction, prev[k].y)


func _collide(from: Vector2, to: Vector2) -> Vector2:
	if Sim.world == null or not Sim.solid_at(to):
		return to
	var tx := Vector2(to.x, from.y)
	if not Sim.solid_at(tx):
		return tx
	var ty := Vector2(from.x, to.y)
	if not Sim.solid_at(ty):
		return ty
	if Sim.solid_at(from):
		return from + Vector2(0, -1) # buried: work upward out of the dirt
	return from


func _constrain(a: String, b: String, length: float) -> void:
	var pa: Vector2 = pts[a]
	var pb: Vector2 = pts[b]
	var d := pb - pa
	var l := d.length()
	if l < 0.001:
		return
	var diff := (l - length) / l * 0.5
	var na := pa + d * diff
	var nb := pb - d * diff
	pts[a] = na if not Sim.solid_at(na) else pa
	pts[b] = nb if not Sim.solid_at(nb) else pb


func _redraw_rig() -> void:
	if _rig == null:
		return
	for seg in BodyRig.SEGS:
		if attached.get(seg[0], false):
			_rig.show_segment(seg[0], pts[seg[1]] - global_position, pts[seg[2]] - global_position)
		else:
			_rig.hide_segment(seg[0])


## Average velocity of the body, px per tick.
func body_velocity() -> Vector2:
	return pts["hip"] - prev["hip"]


# ---------------------------------------------------------------- blood

func _bleed(delta: float) -> void:
	if not fresh or blood <= 0.0:
		return
	blood = maxf(0.0, blood - delta / CORPSE.blood_seconds)
	data["fresh"] = blood > 0.0
	var beat := 0.5 + 0.5 * sin(_t * CORPSE.pump_beat)
	for w in wounds:
		if randf() < CORPSE.pump_rate * w.strength * beat * blood:
			var at: Vector2 = pts.get(w.pt, global_position)
			var dir := Vector2(randf_range(-0.6, 0.6), -1.0).normalized() * CORPSE.spurt_speed * (0.5 + beat)
			Sim.spill_px(at, SandWorld.M_BLOOD, 1, dir)
	for w in wounds:
		w.strength = maxf(0.08, w.strength * 0.9995)


# ---------------------------------------------------------------- Harvest (pullable)

## Harvest pulls with `force` (px per tick², for this tick). Light parts move most and tear first.
func apply_pull(force: Vector2) -> void:
	if carrier != null:
		return
	_pulled = true
	var f := force.length()
	var limit: float = CORPSE.joint_strength if fresh else CORPSE.old_joint_strength
	for seg in BodyRig.SEGS:
		var k: String = seg[0]
		if not attached.get(k, false):
			continue
		var w: float = BodyRig.WEIGHT[k]
		pts[seg[2]] += force / w
		strain[k] += f / w
		if strain[k] >= limit:
			tear(k)
			return # one tear per tick reads better
	# the whole body slides along
	for k in _live_points():
		pts[k] += force * 0.5


## Rip one segment off as a part Item. Tearing the torso turns what is left into a torso part.
func tear(k: String) -> Node2D:
	if not attached.get(k, false):
		return null
	var seg: Array = []
	for s in BodyRig.SEGS:
		if s[0] == k:
			seg = s
	var a: Vector2 = pts[seg[1]]
	var b: Vector2 = pts[seg[2]]
	if k == "torso":
		for other in attached.keys():
			if other != "torso" and attached[other]:
				tear(other)
	attached[k] = false
	data["parts"] = attached.keys().filter(func(x): return attached[x])
	var part := BodyPart.new()
	part.setup(look, BodyRig.PART[k], a, b, (b - prev[seg[2]]) * 1.2, fresh and blood > 0.0, blood)
	if not fresh:
		part.make_old()
	var parent := get_parent()
	if parent != null:
		parent.add_child(part)
	if fresh and blood > 0.0:
		Sim.spill_px(a, SandWorld.M_BLOOD, int(CORPSE.tear_spurt * blood), (b - a).normalized() * 1.5)
		wounds.append({"pt": seg[1], "strength": 1.0})
	Events.noise_made.emit(global_position, 0.15, "flesh_tear")
	if k == "torso":
		queue_free()
	return part


# ---------------------------------------------------------------- Siphon

## Drain up to `amount` (0..1 of the body) and return mana in souls' worth. Empty bodies crumble to ash.
func siphon(amount: float) -> float:
	var got := 0.0
	if blood > 0.0:
		var take := minf(amount, blood)
		blood -= take
		got += take * CORPSE.blood_mana
		amount -= take
	if amount > 0.0 and flesh > 0.0:
		var take2 := minf(amount, flesh)
		flesh -= take2
		got += take2 * CORPSE.flesh_mana
	var dry := clampf(flesh, 0.0, 1.0)
	if _rig:
		_rig.modulate = Color(0.45, 0.42, 0.4).lerp(Color.WHITE if fresh else CORPSE.old_tint, dry)
	if flesh <= 0.0:
		crumble()
	return got


func crumble() -> void:
	for k in _live_points():
		Sim.spill_px(pts[k], SandWorld.M_ASH, int(CORPSE.ash_cells / 5.0), Vector2(0, -0.3))
	queue_free()
