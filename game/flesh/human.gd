class_name Human
extends Actor
## A farmer or villager. Works by day, goes home at night, notices the undead and flees by `fear`,
## or fights weakly when cornered or ordered to. Dies into a bleeding six-part Corpse.
## Implements the "Human orders" hook for Threats: set_route, investigate, set_mode, fear, noticed.
## Owned by Bodies and Souls. Every human is an adult (design doc content boundary).

signal noticed(what: Node2D)

const HUMAN := {
	"walk_speed": 0.7, ## px per tick
	"run_speed": 1.6,
	"sight_px": 180.0, ## how far they notice the undead (by day; halved at night)
	"notice_cooldown": 4.0, ## seconds between sighting reports of the same thing
	"fear_gain": 0.5, ## fear per second while undead are in sight
	"fear_decay": 0.05, ## per second otherwise
	"flee_fear": 0.55, ## above this they run
	"brace": 0.6, ## how much a calm human resists Harvest (0 none, 1 immovable)
	"attack_range": 22.0,
	"attack_damage": 4.0, ## a pitchfork poke; they are not soldiers
	"attack_cooldown": 1.2,
	"wander_px": 120.0,
	"hp": {"farmer": 40.0, "villager": 30.0},
	"soul_witness_radius": 160.0, ## px: SOULS.witness_radius, the necromancer must be this close
	"jump": 3.6,
}

var kind: StringName = &"villager"
var mode: StringName = &"work"
var fear := 0.0
var brace := HUMAN.brace
var home_id := -1
var home_pos := Vector2.ZERO
var work_pos := Vector2.ZERO
var route: PackedVector2Array = PackedVector2Array()
var _route_i := 0
var _target := Vector2.ZERO
var _has_target := false
var _investigate := Vector2.ZERO
var _investigating := false
var _threat: Node2D = null
var _seen := {} ## node id -> seconds until it can be reported again
var _attack_cd := 0.0
var _phase := 0.0
var _rig: BodyRig
var _aim := Vector2.ZERO
var _think := 0.0
var _last_hit_by: Node2D = null


func _init() -> void:
	faction = Actor.Faction.HUMAN
	box_size = Vector2(12, 58)


func setup(k: StringName, at: Vector2) -> void:
	kind = k
	display_name = String(k)
	max_hp = HUMAN.hp.get(String(k), 30.0)
	position = at
	work_pos = at
	home_pos = at
	_target = at


func _ready() -> void:
	super._ready()
	add_to_group(&"pullable")
	add_to_group(&"human_actors")
	_rig = BodyRig.new()
	_rig.setup(String(kind))
	add_child(_rig)
	damaged.connect(_on_damaged)
	_rig.show_pose(BodyRig.pose(Vector2.ZERO, facing, 0.0, false))


# ---------------------------------------------------------------- Human orders hook

func set_route(points: PackedVector2Array) -> void:
	route = points
	_route_i = 0
	if mode != &"flee":
		mode = &"patrol"


func investigate(at: Vector2) -> void:
	_investigate = at
	_investigating = true


func set_mode(m: StringName) -> void:
	mode = m
	_has_target = false


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
	if _threat != null and is_instance_valid(_threat):
		fear = minf(1.0, fear + HUMAN.fear_gain * delta)
	else:
		_threat = null
		fear = maxf(0.0, fear - HUMAN.fear_decay * delta)
	var speed: float = HUMAN.walk_speed
	var goal := global_position
	var moving := false
	_aim = Vector2.ZERO
	var m := _effective_mode()
	match m:
		&"flee":
			speed = HUMAN.run_speed
			var away := 1.0
			if _threat != null:
				away = signf(global_position.x - _threat.global_position.x)
				if away == 0.0: away = 1.0
			goal = Vector2(global_position.x + away * 60.0, global_position.y)
			moving = true
		&"attack":
			if _threat != null:
				goal = _threat.global_position
				speed = HUMAN.run_speed * 0.8
				var d := global_position.distance_to(goal)
				moving = d > HUMAN.attack_range * 0.8
				if d < HUMAN.attack_range:
					_aim = (goal + Vector2(0, -30)) - (global_position + Vector2(0, -36))
					_try_attack()
			else:
				mode = &"work"
		_:
			goal = _wander_goal(m)
			moving = absf(goal.x - global_position.x) > 4.0
	var dir := signf(goal.x - global_position.x) if moving else 0.0
	velocity.x = dir * speed
	if dir != 0.0:
		facing = int(dir)
	if moving and hit_wall != 0 and on_floor:
		velocity.y = -HUMAN.jump
	move_tick()
	if moving:
		_phase += absf(velocity.x) * 0.18
	var lean := 0.25 if m == &"flee" else 0.0
	_rig.show_pose(BodyRig.pose(Vector2.ZERO, facing, _phase, moving and absf(velocity.x) > 0.05, lean, _aim))
	_rig.set_flip(facing < 0)


func _effective_mode() -> StringName:
	if mode == &"attack":
		return mode
	if fear >= HUMAN.flee_fear or mode == &"flee":
		return &"flee"
	if _threat != null and fear < 0.3 and kind == &"farmer":
		return &"attack" # a brave farmer pokes first, asks questions later
	if _investigating:
		return &"investigate"
	return mode


func _wander_goal(m: StringName) -> Vector2:
	if m == &"investigate":
		if absf(_investigate.x - global_position.x) < 8.0:
			_investigating = false
		return _investigate
	if m == &"patrol" and route.size() > 0:
		var p := route[_route_i % route.size()]
		if absf(p.x - global_position.x) < 6.0:
			_route_i += 1
		return p
	var night := GameState.is_night()
	if m == &"home" or (m == &"work" and night):
		return home_pos
	if not _has_target or absf(_target.x - global_position.x) < 4.0:
		_target = work_pos + Vector2(randf_range(-HUMAN.wander_px, HUMAN.wander_px), 0)
		_has_target = true
	return _target


## Look for the undead (and the necromancer himself).
func _look() -> void:
	var sight: float = HUMAN.sight_px * (0.5 if GameState.is_night() else 1.0)
	var best: Node2D = null
	var best_d := sight
	for group in [&"necro", &"minions"]:
		for n in get_tree().get_nodes_in_group(group):
			if not (n is Node2D) or (n is Actor and n.dead):
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
	_last_hit_by = source
	fear = minf(1.0, fear + 0.25)
	if source != null and _threat == null:
		_threat = source
	Sim.spill_px(global_position + Vector2(0, -34), SandWorld.M_BLOOD, 3, Vector2(randf_range(-1, 1), -1))


## Harvest on a living human: they brace against it, less so when terrified.
func apply_pull(force: Vector2) -> void:
	if dead:
		return
	var resist := clampf(brace * (1.0 - fear), 0.0, 0.95)
	velocity += force * (1.0 - resist) * 0.5
	fear = minf(1.0, fear + 0.01)


# ---------------------------------------------------------------- death

func _on_death(killer: Node2D) -> void:
	var at := global_position
	var witnessed := _necro_near(at)
	var pose := BodyRig.pose(at, facing, _phase, false, 0.3)
	var corpse := Corpse.new()
	corpse.setup(String(kind), pose, velocity + Vector2(randf_range(-0.6, 0.6), -1.2), true)
	if killer != null:
		var push := signf(at.x - killer.global_position.x)
		corpse.setup(String(kind), pose, velocity + Vector2(push * 1.5, -1.5), true)
	var layer := _item_layer()
	layer.add_child(corpse)
	Sim.spill_px(at + Vector2(0, -36), SandWorld.M_BLOOD, 10, Vector2(0, -1))
	if witnessed or GameState.in_heart_range(at):
		var orb := SoulOrb.new()
		orb.amount = 1.0
		orb.source = String(kind)
		orb.claimed = witnessed
		orb.position = at + Vector2(0, -40)
		_item_layer().add_child(orb)
	Events.human_killed.emit(self, witnessed)
	GameState.count("humans_killed")
	var s := get_tree().get_first_node_in_group(&"settlements")
	if s != null and home_id >= 0 and s.has_method("resident_died"):
		s.resident_died(home_id)
	queue_free()


func _item_layer() -> Node:
	var main := get_tree().current_scene
	if main != null and main.get("items") is Node:
		return main.items
	return get_parent()


static func _necro_near(at: Vector2) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	for n in tree.get_nodes_in_group(&"necro"):
		if n is Node2D and n.global_position.distance_to(at) <= HUMAN.soul_witness_radius:
			return true
	return false
