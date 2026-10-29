class_name Corpse
extends Item
## A dead human: a six-part ragdoll (verlet points on BodyRig's skeleton) that flops into the sand world.
## Harvest (apply_pull) drags it toward the necromancer's hand. When the body is held back (stuck in a
## coffin, wedged in a shaft) its joints strain and the light parts tear off first: arms, then the head,
## then the legs, until only the torso is left, which becomes a torso part.
## Each tear leaves a stump that pumps blood into the sim while the blood timer lasts.
## Siphon drinks its blood (rich mana) then its flesh (thin mana); empty, it crumbles to ash.
## Graveyard corpses start `interred`: still, hidden, odourless, until Harvest first touches them.
## Owned by Bodies and Souls.

const CORPSE := {
	"gravity": 0.25, ## px per tick²
	"damping": 0.985, ## velocity kept per tick in the air
	"ground_friction": 0.7, ## sideways velocity kept per tick on the ground
	"iterations": 4, ## constraint passes per tick
	"blood_seconds": 90.0, ## the blood timer: a fresh body's blood is gone (dried, drained) after this
	"pull_scale": 0.85, ## share of Harvest's pull a whole body feels (a body drags in a bit slower than a part)
	"flail": 0.6, ## extra pull on each limb's far end, divided by its weight (light limbs fly ahead)
	"joint_strength": 22.0, ## a joint tears when strain reaches this × weight; strain grows by pull ÷ weight per tick
	"old_joint_strength": 11.0, ## graveyard bodies come apart easily
	"stuck_speed": 1.0, ## px per tick: a pulled body moving slower than this is being held back and strains
	"free_strain": 0.15, ## share of strain gathered while it is flying freely toward the hand
	"strain_relax": 0.97, ## strain kept per tick when nobody is pulling
	"pump_rate": 0.55, ## chance per tick that a fresh wound squirts a cell of blood (times its strength)
	"pump_beat": 7.0, ## heartbeat-ish pulse, radians per second (the heart has stopped; the gore has not)
	"spurt_speed": 1.6, ## px per tick
	"tear_spurt": 14, ## cells of blood flung when a part tears free
	"blood_mana": 0.35, ## souls' worth from a full body's blood
	"flesh_mana": 0.12, ## souls' worth from the meat once the blood is gone
	"old_flesh": 0.6, ## graveyard bodies have this much flesh left
	"old_tint": Color(0.62, 0.66, 0.58),
	"ash_cells": 22,
	"sleep_speed": 0.03, ## px per tick: slower than this for sleep_ticks and the ragdoll stops simulating
	"sleep_ticks": 45,
	"topple": 0.7, ## px per tick: a body that dies standing has its upper half pushed over so it falls down
	"lead": 0.5, ## Harvest pulls the body's leading end this much harder, its trailing end this much softer
	"jitter": 0.15,
	"unstick_ticks": 60, ## pulled this long without headway, the grave-wind draws it through the earth regardless
	"unstick_speed": 0.15, ## px per tick toward the pull that counts as headway
	"ghost_ticks": 20, ## how long a body drawn through earth keeps passing through it after reaching air ## px per tick of random wobble per point at death, so no two bodies fall alike
}

var look := "villager"
var fresh := true ## false for graveyard bodies: no blood, no soul
var interred := false ## a graveyard body still in its coffin: no physics, not drawn, doesn't smell
var blood := 1.0 ## 0..1 of the body's blood left in it
var flesh := 1.0 ## 0..1 left for Siphon once the blood is gone
var pts := {} ## point name -> world position
var prev := {} ## point name -> world position last tick
var attached := {} ## seg key -> true while still on the body
var strain := {} ## seg key -> accumulated strain
var wounds: Array = [] ## [{pt: String, strength: float}]
var ghost := {} ## point name -> ticks: passes through earth while pulled (see exhume, apply_pull); gone once in air
var _pull_t := 0 ## ticks left in which the body counts as being pulled
var _stuck_pull := 0 ## ticks the pull has made no headway
var asleep := false
var _pulled := false
var _rig: BodyRig
var _t := 0.0
var _last_pos := Vector2.ZERO
var _still := 0


func _init() -> void:
	kind = &"corpse"
	box_size = Vector2(16, 6)


## Call before adding to the tree. `pose` is BodyRig points in world space (living pose at death, or lying).
func setup(look_name: String, pose: Dictionary, vel := Vector2.ZERO, is_fresh := true) -> void:
	look = look_name
	fresh = is_fresh
	blood = 1.0 if fresh else 0.0
	flesh = 1.0 if fresh else CORPSE.old_flesh
	var tip_dir := signf(vel.x) if absf(vel.x) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	var upright: bool = pose["top"].y < pose["hip"].y - 10.0
	for k in BodyRig.PT_NAMES:
		pts[k] = pose[k]
		var v := vel + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * CORPSE.jitter
		if upright and k in ["neck", "top", "handB", "handF"]:
			v.x += tip_dir * CORPSE.topple * (1.4 if k == "top" else 1.0)
		prev[k] = pose[k] - v
	for seg in BodyRig.SEGS:
		attached[seg[0]] = true
		strain[seg[0]] = 0.0
	data = {"source": look_name, "fresh": fresh, "parts": attached.keys()}
	position = pts["hip"]
	if fresh:
		wounds.append({"pt": "neck", "strength": 0.6})


## A graveyard body in its coffin at `center` (pixels). Call before adding to the tree.
func setup_grave(look_name: String, center: Vector2) -> void:
	setup(look_name, BodyRig.grave_pose(center, 1 if randf() < 0.5 else -1), Vector2.ZERO, false)
	interred = true


func _ready() -> void:
	super._ready()
	add_to_group(&"pullable")
	add_to_group(&"siphonable")
	add_to_group(&"corpses")
	if interred:
		add_to_group(&"grave_corpses")
		remove_from_group(&"item_corpse") # nobody can smell or haul it until it is dug up
		visible = false
	_rig = BodyRig.new()
	_rig.setup(look)
	if not fresh:
		_rig.modulate = CORPSE.old_tint
	add_child(_rig)
	_last_pos = global_position
	_redraw_rig()


## The first touch of Harvest wakes a graveyard body: it shows, smells and can be hauled from now on.
func exhume() -> void:
	if not interred:
		return
	interred = false
	visible = true
	# the coffin is snug and the grave dirt is packed round it: whatever is in the earth passes up through it
	for k in pts:
		if Sim.solid_at(pts[k]):
			ghost[k] = 0
	remove_from_group(&"grave_corpses")
	add_to_group(&"item_corpse")
	asleep = false


func _physics_process(delta: float) -> void:
	_t += delta
	if interred:
		return
	if carrier != null:
		var shift := global_position - _last_pos
		for k in pts:
			pts[k] += shift
			prev[k] = pts[k]
		asleep = false
	elif not asleep:
		_step()
		global_position = pts["hip"]
		velocity = pts["hip"] - prev["hip"]
		_check_sleep()
	elif Engine.get_physics_frames() % 20 == 0 and not Sim.solid_at(pts["hip"] + Vector2(0, 3)):
		asleep = false # the ground under it went away
	_last_pos = global_position
	if not _pulled:
		for k in strain:
			strain[k] *= CORPSE.strain_relax
	_pulled = false
	_pull_t = maxi(0, _pull_t - 1)
	_bleed(delta)
	if not asleep or carrier != null:
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
		pts[k] = BodyRig.collide_point(p, p + v, _g(k))
	for i in CORPSE.iterations:
		for seg in BodyRig.SEGS:
			if not attached.get(seg[0], false):
				continue
			_constrain(seg[1], seg[2], BodyRig.RIG[BodyRig.PART[seg[0]]])
	for k in ghost.keys():
		ghost[k] -= 1
		if ghost[k] <= 0 and not Sim.solid_at(pts[k]):
			ghost.erase(k)
	# floor friction: a point resting on ground loses most of its sideways speed
	for k in live:
		if Sim.solid_at(pts[k] + Vector2(0, 1.5)):
			var p: Vector2 = pts[k]
			var px: float = prev[k].x
			prev[k] = Vector2(p.x - (p.x - px) * CORPSE.ground_friction, prev[k].y)


## Keep two points `length` apart. A point may not be pushed into the ground, but one already stuck
## in it may be pulled out by the rest of the body.
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
	pts[a] = BodyRig.collide_point(pa, na, _g(a))
	pts[b] = BodyRig.collide_point(pb, nb, _g(b))


func _check_sleep() -> void:
	var fastest := 0.0
	for k in _live_points():
		fastest = maxf(fastest, (pts[k] - prev[k]).length())
	_still = _still + 1 if fastest < CORPSE.sleep_speed else 0
	if _still >= CORPSE.sleep_ticks:
		asleep = true
		_still = 0
		for k in pts:
			prev[k] = pts[k]


## True if point `k` passes through earth this tick (only while Harvest is pulling).
func _g(k: String) -> bool:
	return _pull_t > 0 and ghost.has(k)


func wake() -> void:
	asleep = false
	_still = 0


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


## Item.drop for a ragdoll: move every point so the hip lands at `at`.
func drop(at: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	carrier = null
	reserved_by = null
	exhume()
	var shift: Vector2 = at - pts.get("hip", global_position)
	for k in pts:
		pts[k] += shift
		prev[k] = pts[k] - vel
	global_position = at
	_last_pos = at
	velocity = vel
	wake()
	_redraw_rig()


# ---------------------------------------------------------------- blood

func _bleed(delta: float) -> void:
	if not fresh or blood <= 0.0:
		return
	blood = maxf(0.0, blood - delta / CORPSE.blood_seconds)
	data["fresh"] = blood > 0.0
	if carrier != null:
		return
	var beat := 0.5 + 0.5 * sin(_t * CORPSE.pump_beat)
	for w in wounds:
		if randf() < CORPSE.pump_rate * w.strength * beat * blood:
			var at: Vector2 = pts.get(w.pt, global_position)
			var dir := Vector2(randf_range(-0.6, 0.6), -1.0).normalized() * CORPSE.spurt_speed * (0.5 + beat)
			Sim.spill_px(at + Vector2(0, -2), SandWorld.M_BLOOD, 1, dir)
	for w in wounds:
		w.strength = maxf(0.08, w.strength * 0.9995)


# ---------------------------------------------------------------- Harvest (pullable)

## Harvest pulls with `force` (px per tick², for this tick). The body slides toward the hand; light limbs
## fly ahead. Held back, its joints strain and tear in weight order: arms, head, legs.
func apply_pull(force: Vector2) -> void:
	if carrier != null:
		return
	exhume()
	wake()
	_pulled = true
	var body_force := force * CORPSE.pull_scale
	# points further along the pull lead and the rest trail, so the body swings round and follows like a rope
	var dir := force.normalized()
	var live := _live_points()
	var c := Vector2.ZERO
	for k in live:
		c += pts[k]
	c /= float(live.size())
	_pull_t = 3
	if body_velocity().dot(dir) < CORPSE.unstick_speed:
		_stuck_pull += 1
		if _stuck_pull >= CORPSE.unstick_ticks:
			_stuck_pull = 0
			for k in live:
				ghost[k] = CORPSE.ghost_ticks
	else:
		_stuck_pull = 0
	for k in live:
		var lead := clampf((pts[k] - c).dot(dir) / 20.0, -1.0, 1.0) * CORPSE.lead
		pts[k] = BodyRig.collide_point(pts[k], pts[k] + body_force * (1.0 + lead), _g(k))
	var f := force.length()
	var stuck := body_velocity().length() < CORPSE.stuck_speed
	var gain := f * (1.0 if stuck else CORPSE.free_strain)
	var limit: float = CORPSE.joint_strength if fresh else CORPSE.old_joint_strength
	var weakest := ""
	var weakest_left := INF
	for seg in BodyRig.SEGS:
		var k: String = seg[0]
		if k == "torso" or not attached.get(k, false):
			continue
		var w: float = BodyRig.WEIGHT[k]
		var tip: Vector2 = pts[seg[2]]
		pts[seg[2]] = BodyRig.collide_point(tip, tip + force * CORPSE.flail / w, _g(seg[2]))
		strain[k] += gain / w
		var left: float = limit * w - strain[k]
		if left < weakest_left:
			weakest_left = left
			weakest = k
	if weakest != "" and weakest_left <= 0.0:
		tear(weakest) # one tear per tick reads better


## Rip one limb or the head off as a part Item. When nothing is left but the torso, the corpse becomes
## a torso part. Returns the new part.
func tear(k: String) -> Node2D:
	if not attached.get(k, false):
		return null
	if k == "torso":
		for other in attached.keys():
			if other != "torso" and attached[other]:
				_tear_one(other)
		return _become_torso()
	var part := _tear_one(k)
	var left := attached.keys().filter(func(x): return attached[x] and x != "torso")
	if left.is_empty():
		_become_torso()
	return part


func _tear_one(k: String) -> Node2D:
	var seg: Array = []
	for s in BodyRig.SEGS:
		if s[0] == k:
			seg = s
	var a: Vector2 = pts[seg[1]]
	var b: Vector2 = pts[seg[2]]
	attached[k] = false
	strain[k] = 0.0
	data["parts"] = attached.keys().filter(func(x): return attached[x])
	var bleeding := fresh and blood > 0.0
	var part := _spawn_part(BodyRig.PART[k], a, b, (b - prev[seg[2]]) * 1.2)
	part.ghost_a = int(ghost.get(seg[1], -1))
	part.ghost_b = int(ghost.get(seg[2], -1))
	part.pull_t = _pull_t
	ghost.erase(seg[2])
	if bleeding:
		Sim.spill_px(a, SandWorld.M_BLOOD, int(CORPSE.tear_spurt * blood), (b - a).normalized() * 1.5)
		wounds.append({"pt": seg[1], "strength": 1.0})
	Events.noise_made.emit(global_position, 0.15, "flesh_tear")
	return part


func _become_torso() -> Node2D:
	attached["torso"] = false
	var part := _spawn_part("torso", pts["hip"], pts["neck"], body_velocity())
	part.ghost_a = int(ghost.get("hip", -1))
	part.ghost_b = int(ghost.get("neck", -1))
	part.pull_t = _pull_t
	queue_free()
	return part


func _spawn_part(part_name: String, a: Vector2, b: Vector2, vel: Vector2) -> BodyPart:
	var part := BodyPart.new()
	part.setup(look, part_name, a, b, vel, fresh and blood > 0.0, blood)
	if not fresh:
		part.make_old()
	var parent := get_parent()
	if parent != null:
		parent.add_child(part)
	return part


# ---------------------------------------------------------------- Siphon

## Siphon asks for `amount` souls' worth of mana; returns what it got (never more). Blood goes first
## (rich), then the flesh (thin). Empty bodies crumble to ash.
func siphon(amount: float) -> float:
	if interred or amount <= 0.0:
		return 0.0
	var got := 0.0
	if blood > 0.0:
		var take := minf(amount / CORPSE.blood_mana, blood)
		blood -= take
		got += take * CORPSE.blood_mana
	if got < amount and flesh > 0.0:
		var take2 := minf((amount - got) / CORPSE.flesh_mana, flesh)
		flesh -= take2
		got += take2 * CORPSE.flesh_mana
	data["fresh"] = blood > 0.0
	var dry := clampf(flesh / (1.0 if fresh else CORPSE.old_flesh), 0.0, 1.0)
	if _rig:
		_rig.modulate = Color(0.45, 0.42, 0.4).lerp(Color.WHITE if fresh else CORPSE.old_tint, dry)
	if flesh <= 0.0:
		crumble()
	return got


func crumble() -> void:
	for k in _live_points():
		Sim.spill_px(pts[k] + Vector2(0, -4), SandWorld.M_ASH, int(CORPSE.ash_cells / 5.0), Vector2(0, -0.8))
	queue_free()
