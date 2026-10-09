class_name Critter
extends Actor
## Woodland critters: rabbits and deer on the ground, crows that peck about and take to the air.
## They hold only a sliver of soul: killed with the necromancer near (or inside the heart's range),
## they drop a soul-fragment orb; enough fragments make a soul (GameState.add_fragments).
## They bolt from the necromancer and his minions. Pullable by Harvest. Owned by Bodies and Souls.

const CRITTER := {
	"kinds": {
		"rabbit": {"hp": 6.0, "size": Vector2(10, 9), "walk": 0.5, "run": 2.4, "sight": 110.0, "fragments": 1.0, "blood": 8, "flesh": 2, "hop": 2.4},
		"deer": {"hp": 24.0, "size": Vector2(26, 32), "walk": 0.45, "run": 2.6, "sight": 170.0, "fragments": 2.0, "blood": 22, "flesh": 6, "hop": 3.4},
		"crow": {"hp": 4.0, "size": Vector2(10, 8), "walk": 0.3, "run": 0.0, "sight": 95.0, "fragments": 1.0, "blood": 4, "flesh": 1, "hop": 1.2},
	},
	"wander_px": 90.0, ## how far a calm critter ambles from where it settled
	"calm_seconds": 5.0, ## after a fright, how long until it settles again
	"fly_speed": 1.9, ## crows, px per tick
	"fly_up_px": 70.0, ## how high a startled crow climbs before gliding off
	"fly_away_px": [160.0, 320.0],
	"idle_tick_every": 10,
}

var kind: StringName = &"rabbit"
var spec: Dictionary = {}
var home_x := 0.0
var scared := 0.0
var flying := false
var _goal := Vector2.ZERO
var _has_goal := false
var _from := Vector2.ZERO
var _sprite: AnimatedSprite2D
var _think := 0.0
var _idle_ticks := 0
var _base_gravity := 0.25


func _init() -> void:
	faction = Actor.Faction.CRITTER


func setup(k: StringName, at: Vector2) -> void:
	kind = k
	spec = CRITTER.kinds.get(String(k), CRITTER.kinds.rabbit)
	display_name = String(k).capitalize()
	max_hp = spec.hp
	box_size = spec.size
	step_height = 4.0 if box_size.y < 20 else 6.0
	position = at
	home_x = at.x


func _ready() -> void:
	super._ready()
	if spec.is_empty():
		setup(kind, position)
	add_to_group(&"pullable")
	add_to_group(&"critter_actors")
	_base_gravity = gravity
	_sprite = ArtLib.make_sprite(String(kind))
	add_child(_sprite)
	facing = 1 if randf() < 0.5 else -1
	_think = randf() * 0.3
	# a crow placed in the air starts out flying
	if kind == &"crow" and Sim.world != null and not Sim.solid_at(position + Vector2(0, 3)):
		_take_off(position + Vector2(randf_range(-60, 60), 0), false)


func _physics_process(delta: float) -> void:
	if dead:
		return
	scared = maxf(0.0, scared - delta)
	_think -= delta
	if _think <= 0.0:
		_think = 0.25
		_look()
	if flying:
		_fly()
	else:
		_walk()
	_sprite.flip_h = facing < 0


func _walk() -> void:
	var speed: float = spec.run if scared > 0.0 else spec.walk
	var goal_x := global_position.x
	if scared > 0.0 and spec.run > 0.0:
		goal_x = global_position.x + signf(global_position.x - _from.x) * 60.0
	elif _has_goal:
		goal_x = _goal.x
	elif randf() < 0.01:
		_goal = Vector2(home_x + randf_range(-CRITTER.wander_px, CRITTER.wander_px), global_position.y)
		_has_goal = true
	var moving := absf(goal_x - global_position.x) > 3.0
	if not moving:
		_has_goal = false
	var dir := signf(goal_x - global_position.x) if moving else 0.0
	velocity.x = dir * speed
	if dir != 0.0:
		facing = int(dir)
	if moving and on_floor and (hit_wall != 0 or (kind == &"rabbit" and randf() < 0.08)):
		velocity.y = -spec.hop
		if hit_wall != 0:
			_has_goal = false
	_idle_ticks += 1
	if moving or not on_floor or velocity.length_squared() > 0.0001 or _idle_ticks >= CRITTER.idle_tick_every:
		_idle_ticks = 0
		move_tick()
	if scared <= 0.0 and absf(global_position.x - home_x) > CRITTER.wander_px * 3.0:
		home_x = global_position.x # settled somewhere new


func _fly() -> void:
	var to := _goal - global_position
	if to.length() < 4.0 or hit_wall != 0 or hit_ceiling:
		# glide down to land
		gravity = _base_gravity * 0.3
		velocity.x *= 0.98
		move_tick()
		if on_floor:
			_land()
		return
	velocity = velocity.lerp(to.normalized() * CRITTER.fly_speed, 0.08)
	if absf(velocity.x) > 0.05:
		facing = int(signf(velocity.x))
	move_tick()
	if on_floor and to.y > 0.0:
		_land()


func _take_off(goal: Vector2, startled := true) -> void:
	flying = true
	gravity = 0.0
	_goal = goal
	if startled:
		velocity = Vector2(signf(goal.x - global_position.x) * 0.8, -1.6)
		Events.noise_made.emit(global_position, 0.05, "crow")


func _land() -> void:
	flying = false
	gravity = _base_gravity
	velocity = Vector2.ZERO
	home_x = global_position.x
	_has_goal = false


## Bolt from the necromancer and his minions.
func _look() -> void:
	var sight: float = spec.sight * (0.6 if GameState.is_night() else 1.0)
	for group in [&"necro", &"minions"]:
		for n in get_tree().get_nodes_in_group(group):
			if not (n is Node2D) or (n is Actor and n.dead):
				continue
			if n.global_position.distance_to(global_position) < sight:
				_fright(n.global_position)
				return


func _fright(from: Vector2) -> void:
	var was := scared
	scared = CRITTER.calm_seconds
	_from = from
	if kind == &"crow" and (not flying or was <= 0.0):
		var away := signf(global_position.x - from.x)
		if away == 0.0:
			away = 1.0
		var dist := randf_range(CRITTER.fly_away_px[0], CRITTER.fly_away_px[1])
		_take_off(global_position + Vector2(away * dist, -CRITTER.fly_up_px), true)


func take_damage(amount: float, source: Node2D = null) -> void:
	if source != null and is_instance_valid(source):
		_fright(source.global_position)
	super.take_damage(amount, source)


## Harvest yanks critters about (crows right out of the sky).
func apply_pull(force: Vector2) -> void:
	if dead:
		return
	velocity += force
	if flying:
		gravity = _base_gravity
		_goal = global_position
	_fright(global_position - force * 40.0)


func _on_death(_killer: Node2D) -> void:
	var at := global_position + Vector2(0, -box_size.y * 0.5)
	Sim.spill_px(at, SandWorld.M_BLOOD, int(spec.blood), Vector2(randf_range(-0.5, 0.5), -1.2))
	Sim.spill_px(at, SandWorld.M_FLESH, int(spec.flesh), Vector2(randf_range(-0.8, 0.8), -1.4))
	if SoulOrb.necro_within(at, SoulOrb.SOULS.witness_radius) or GameState.in_heart_range(at):
		var orb := SoulOrb.new()
		orb.amount = spec.fragments
		orb.fragment = true
		orb.source = String(kind)
		orb.claimed = not GameState.in_heart_range(at)
		orb.position = at + Vector2(0, -8)
		FleshSpawner.layer_for(self, &"items", get_parent()).add_child(orb)
	GameState.count("critters_killed")
	queue_free()
