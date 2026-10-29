class_name Human
extends Actor
## A farmer or villager. Works by day, goes home at night, notices the undead and flees by `fear`,
## or fights weakly when cornered or ordered to. Dies into a bleeding six-part Corpse.
## Implements the "Human orders" hook for Threats: set_route, investigate, set_mode, fear, signal noticed.
## Owned by Bodies and Souls. Every human is an adult (design doc content boundary).

signal noticed(what: Node2D)

const HUMAN := {
	"walk_speed": 0.7, ## px per tick
	"run_speed": 1.6,
	"sight_px": 180.0, ## how far they notice the undead by day
	"night_sight": 0.5, ## share of sight at night
	"asleep_sight": 0.25, ## share of sight while at home at night (dozing by the fire)
	"notice_cooldown": 4.0, ## seconds before the same thing is reported again
	"fear_gain": 0.5, ## fear per second while the undead are in sight
	"fear_decay": 0.05, ## per second otherwise
	"fear_on_hit": 0.25,
	"flee_fear": 0.55, ## above this they run (unless ordered to attack)
	"ordered_attack_breaks": 0.9, ## even an ordered attack breaks into flight at this fear
	"brave_fear": 0.3, ## a farmer this calm goes at the thing with his pitchfork
	"brace": 0.85, ## how much a calm human resists Harvest (0 none, 1 immovable); terror melts it
	"drag_keep": 0.85, ## share of Harvest's drag kept per tick (their feet find the ground again)
	"calm_fear": 0.25, ## once running, they keep running until fear falls below this
	"threat_memory": 3.0, ## seconds a threat they can no longer see still counts (it is behind them as they run)
	"attack_range": 22.0,
	"attack_damage": 4.0, ## a pitchfork poke; they are not soldiers
	"attack_cooldown": 1.2,
	"wander_px": {"farmer": 160.0, "villager": 90.0}, ## how far from their work spot they amble by day
	"investigate_linger": 3.0, ## seconds they stand and look at the spot
	"flee_px": 220.0, ## how far they run from a threat when they have nowhere better to go
	"hp": {"farmer": 40.0, "villager": 30.0},
	"jump": 3.6,
	"give_up_seconds": 2.5, ## stuck against a wall this long and they pick another goal
	"idle_tick_every": 8, ## standing still, physics runs only every this many ticks
}

## How likely each limb is to come off at the moment of death, by what killed them.
const SEVER := {
	"necro": {"arm": 0.3, "leg": 0.2, "head": 0.12}, ## the dig beam cuts
	"other": {"arm": 0.05, "leg": 0.03, "head": 0.0},
}

var kind: StringName = &"villager"
var mode: StringName = &"work"
var fear := 0.0
var brace: float = HUMAN.brace
var home_id := -1
var home_rect := Rect2()
var home_pos := Vector2.ZERO
var work_pos := Vector2.ZERO
var route: PackedVector2Array = PackedVector2Array()
var at_home := false
var _route_i := 0
var _route_dir := 1
var _target := Vector2.ZERO
var _has_target := false
var _investigate := Vector2.ZERO
var _investigating := false
var _linger := 0.0
var _threat: Node2D = null
var _seen := {} ## node id -> seconds until it can be reported again
var _attack_cd := 0.0
var _phase := 0.0
var _rig: BodyRig
var _aim := Vector2.ZERO
var _think := 0.0
var _stuck := 0.0
var _idle_ticks := 0
var _fled_from := Vector2.ZERO
var _fleeing := false
var _drag_x := 0.0 ## sideways speed from Harvest's pull, px per tick
var _threat_left := 0.0 ## seconds the last threat is still remembered


func _init() -> void:
	faction = Actor.Faction.HUMAN
	box_size = Vector2(12, 58)


func setup(k: StringName, at: Vector2) -> void:
	kind = k
	display_name = String(k).capitalize()
	max_hp = HUMAN.hp.get(String(k), 30.0)
	position = at
	work_pos = at
	home_pos = at
	_target = at


## A resident: lives in home `id` (rect in pixels), works around `work`.
func set_home(id: int, rect: Rect2, feet: Vector2, work: Vector2) -> void:
	home_id = id
	home_rect = rect
	home_pos = feet
	work_pos = work


func _ready() -> void:
	super._ready()
	add_to_group(&"pullable")
	add_to_group(&"human_actors")
	_rig = BodyRig.new()
	_rig.setup(String(kind))
	add_child(_rig)
	damaged.connect(_on_damaged)
	facing = 1 if randf() < 0.5 else -1
	_phase = randf() * TAU
	_think = randf() * 0.2
	_rig.show_pose(BodyRig.pose(Vector2.ZERO, facing, 0.0, false))


# ---------------------------------------------------------------- Human orders hook (Threats)

## Walk these points. Patrol loops them; home and flee head for the last one; attack walks them
## until something undead turns up.
func set_route(points: PackedVector2Array) -> void:
	route = points
	_route_i = 0
	_route_dir = 1


## Go and look at a spot (a noise, a hole, a sighting).
func investigate(at: Vector2) -> void:
	_investigate = at
	_investigating = true
	_linger = HUMAN.investigate_linger


## &"home", &"work", &"patrol", &"flee", &"attack".
func set_mode(m: StringName) -> void:
	mode = m
	_has_target = false
	if m == &"flee":
		_investigating = false


# ---------------------------------------------------------------- brain

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	for k in _seen.keys():
		_seen[k] -= delta
		if _seen[k] <= 0.0:
			_seen.erase(k)
	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		_look()
	if _threat != null and not is_instance_valid(_threat):
		_threat = null
	if _threat != null:
		fear = minf(1.0, fear + HUMAN.fear_gain * delta)
		_fled_from = _threat.global_position
		_threat_left = HUMAN.threat_memory
	else:
		_threat_left = maxf(0.0, _threat_left - delta)
		if _threat_left <= 0.0:
			fear = maxf(0.0, fear - HUMAN.fear_decay * delta)
	if fear >= HUMAN.flee_fear:
		_fleeing = true
	elif fear < HUMAN.calm_fear:
		_fleeing = false
	var speed: float = HUMAN.walk_speed
	var goal := global_position
	_aim = Vector2.ZERO
	var m := current_mode()
	match m:
		&"flee":
			speed = HUMAN.run_speed
			goal = _flee_goal()
		&"attack":
			goal = _attack_goal()
			speed = HUMAN.run_speed * 0.8 if _threat != null else HUMAN.walk_speed * 1.3
		&"investigate":
			goal = _investigate
			if absf(goal.x - global_position.x) < 10.0:
				_linger -= delta
				if _linger <= 0.0:
					_investigating = false
		&"patrol":
			goal = _route_goal(true)
		&"home":
			goal = route[route.size() - 1] if mode == &"home" and route.size() > 0 else home_pos
		_:
			goal = _work_goal()
	var moving := absf(goal.x - global_position.x) > 4.0
	at_home = m == &"home" and not moving and home_rect.has_area() and home_rect.grow(8.0).has_point(global_position + Vector2(0, -4))
	var dir := signf(goal.x - global_position.x) if moving else 0.0
	velocity.x = dir * speed + _drag_x
	_drag_x *= HUMAN.drag_keep
	if absf(_drag_x) < 0.01:
		_drag_x = 0.0
	if dir != 0.0:
		facing = int(dir)
	elif _threat != null:
		facing = int(signf(_threat.global_position.x - global_position.x)) if _threat.global_position.x != global_position.x else facing
	if moving and hit_wall != 0 and on_floor:
		velocity.y = -HUMAN.jump
		_stuck += delta
		if _stuck > HUMAN.give_up_seconds:
			_give_up()
	elif moving:
		_stuck = maxf(0.0, _stuck - delta)
	# standing still on firm ground: physics only now and then (dozens of townsfolk are cheap this way)
	_idle_ticks += 1
	if moving or not on_floor or velocity.length_squared() > 0.0001 or _idle_ticks >= HUMAN.idle_tick_every:
		_idle_ticks = 0
		move_tick()
	if moving:
		_phase += absf(velocity.x) * 0.18
	var lean := 0.25 if m == &"flee" else 0.0
	_rig.show_pose(BodyRig.pose(Vector2.ZERO, facing, _phase, moving and absf(velocity.x) > 0.05, lean, _aim))
	_rig.set_flip(facing < 0)


## What they are actually doing this tick: orders, bent by fear and what they can see.
func current_mode() -> StringName:
	if mode == &"attack":
		return &"flee" if fear >= HUMAN.ordered_attack_breaks else &"attack"
	if mode == &"flee" or _fleeing:
		return &"flee"
	if _threat != null and fear < HUMAN.brave_fear and kind == &"farmer":
		return &"attack" # a brave farmer pokes first, asks questions later
	if _investigating:
		return &"investigate"
	if mode == &"work" and GameState.is_night():
		return &"home"
	return mode


func _flee_goal() -> Vector2:
	if mode == &"flee" and route.size() > 0:
		return route[route.size() - 1]
	var from := _fled_from if _fled_from != Vector2.ZERO else global_position - Vector2(facing, 0)
	# run for home if home is away from the danger, else just away
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = float(-facing)
	if home_pos != Vector2.ZERO and signf(home_pos.x - global_position.x) == away and absf(home_pos.x - global_position.x) > 8.0:
		return home_pos
	if fear < HUMAN.flee_fear * 0.5 and mode != &"flee":
		return global_position
	return Vector2(global_position.x + away * HUMAN.flee_px, global_position.y)


func _attack_goal() -> Vector2:
	if _threat != null:
		var goal := _threat.global_position
		var d := global_position.distance_to(goal)
		if d < HUMAN.attack_range:
			_aim = (goal + Vector2(0, -30)) - (global_position + Vector2(0, -36))
			_try_attack()
			return global_position if d < HUMAN.attack_range * 0.7 else goal
		return goal
	if _investigating:
		if absf(_investigate.x - global_position.x) < 10.0:
			_investigating = false
		return _investigate
	if route.size() > 0:
		return _route_goal(false)
	return _work_goal()


## Next point on the route. Looping patrols walk it there and back.
func _route_goal(loop: bool) -> Vector2:
	if route.is_empty():
		return _work_goal()
	_route_i = clampi(_route_i, 0, route.size() - 1)
	var p := route[_route_i]
	if absf(p.x - global_position.x) < 6.0:
		if loop and route.size() > 1:
			if _route_i + _route_dir < 0 or _route_i + _route_dir >= route.size():
				_route_dir = -_route_dir
			_route_i += _route_dir
		elif _route_i < route.size() - 1:
			_route_i += 1
		p = route[_route_i]
	return p


func _work_goal() -> Vector2:
	if not _has_target or absf(_target.x - global_position.x) < 4.0:
		if randf() < 0.008 or not _has_target: # dawdle a little between errands
			var reach: float = HUMAN.wander_px.get(String(kind), 100.0)
			_target = work_pos + Vector2(randf_range(-reach, reach), 0)
			_has_target = true
		else:
			return global_position
	return _target


func _give_up() -> void:
	_stuck = 0.0
	_has_target = false
	if _investigating:
		_investigating = false
	elif route.size() > 1:
		_route_dir = -_route_dir
		_route_i = clampi(_route_i + _route_dir, 0, route.size() - 1)


## Look for the undead (and the necromancer himself).
func _look() -> void:
	var sight: float = HUMAN.sight_px
	if GameState.is_night():
		sight *= HUMAN.night_sight
		if at_home:
			sight *= HUMAN.asleep_sight / HUMAN.night_sight
	var best: Node2D = null
	var best_d := sight
	for group in [&"necro", &"minions"]:
		for n in get_tree().get_nodes_in_group(group):
			if not (n is Node2D) or not n.is_visible_in_tree() or (n is Actor and n.dead):
				continue
			var d: float = n.global_position.distance_to(global_position)
			if d < best_d and _can_see(n):
				best = n
				best_d = d
	if best != null:
		_threat = best
		var id := best.get_instance_id()
		if not _seen.has(id):
			_seen[id] = HUMAN.notice_cooldown
			noticed.emit(best)
			Events.sighting.emit(self, best)
	else:
		_threat = null


func _can_see(n: Node2D) -> bool:
	if signf(n.global_position.x - global_position.x) != float(facing) and global_position.distance_to(n.global_position) > 40.0:
		return false # it is behind them
	if Sim.world == null:
		return true
	return Sim.raycast_px(global_position + Vector2(0, -50), n.global_position + Vector2(0, -30)) == null


func _try_attack() -> void:
	if _attack_cd > 0.0 or _threat == null:
		return
	_attack_cd = HUMAN.attack_cooldown
	if _threat.has_method("take_damage"):
		_threat.take_damage(HUMAN.attack_damage, self)
	Events.noise_made.emit(global_position, 0.2, "human_fight")


func _on_damaged(_a: Actor, _amount: float, source: Node2D) -> void:
	fear = minf(1.0, fear + HUMAN.fear_on_hit)
	if source != null and is_instance_valid(source):
		_fled_from = source.global_position
		if _threat == null and source != self:
			_threat = source
	Sim.spill_px(global_position + Vector2(0, -34), SandWorld.M_BLOOD, 3, Vector2(randf_range(-1, 1), -1))


## Harvest on a living human: they brace against it, less so when terrified.
func apply_pull(force: Vector2) -> void:
	if dead:
		return
	var resist := clampf(brace * (1.0 - fear), 0.0, 0.95)
	_drag_x += force.x * (1.0 - resist)
	velocity.y += force.y * (1.0 - resist)
	fear = minf(1.0, fear + 0.01)


# ---------------------------------------------------------------- death

func _on_death(killer: Node2D) -> void:
	var at := global_position
	var witnessed := SoulOrb.necro_within(at, SoulOrb.SOULS.witness_radius)
	var pose := BodyRig.pose(at, facing, _phase, false, 0.3)
	var push := Vector2(randf_range(-0.6, 0.6), -1.2)
	if killer != null and is_instance_valid(killer):
		push = Vector2(signf(at.x - killer.global_position.x) * 1.5, -1.5)
	var corpse := Corpse.new()
	corpse.setup(String(kind), pose, velocity + push, true)
	var items := FleshSpawner.layer_for(self, &"items", get_parent())
	items.add_child(corpse)
	Sim.spill_px(at + Vector2(0, -36), SandWorld.M_BLOOD, 10, Vector2(0, -1))
	var cause := "necro" if killer != null and is_instance_valid(killer) and killer.is_in_group(&"necro") else "other"
	var chances: Dictionary = SEVER[cause]
	for seg in BodyRig.SEGS:
		var k: String = seg[0]
		if k != "torso" and randf() < float(chances.get(BodyRig.PART[k], 0.0)):
			corpse.tear(k)
	if witnessed or GameState.in_heart_range(at):
		var orb := SoulOrb.new()
		orb.amount = 1.0
		orb.source = String(kind)
		orb.claimed = witnessed
		orb.position = at + Vector2(0, -40)
		items.add_child(orb)
	Events.human_killed.emit(self, witnessed)
	GameState.count("humans_killed")
	var s := get_tree().get_first_node_in_group(&"settlements")
	if s != null and home_id >= 0 and s.has_method("resident_died"):
		s.resident_died(home_id)
	queue_free()
