class_name LairMinion
extends Actor
## Tier 1 undead raised at the altar: the ghoul (does all the work) and the rotling (cheap fighter, idles for now).
## Ghouls take jobs from `Jobs` by their priority list: dig marked rects (bare hands: soil only), haul loose
## items to machines that want them and to stockpiles. They walk dug tunnels with `LairNav` and are noisy.
## Outside the heart's range they lose health; dying out there drops a soul orb (Bodies and Souls' spawner).

const GHOUL := {
	"speed": 1.2, # pixels per tick (72 px a second, a brisk shamble)
	"size": Vector2(18, 52),
	"hp": 60.0,
	"dig_power": 0.35, # wear per tick on the cells it digs
	"dig_radius_px": 6.0,
	"reach_px": 22.0,
	"max_hardness": 1.3, # bare hands: soil, packed earth and powders, not stone or bone
	"noise_every_s": 2.0,
	"noise": 0.08,
	"decay_hp_per_s": 2.0, # outside the heart
	"repath_s": 1.5,
	"stuck_s": 6.0, # give up on a job after this long without getting closer or digging anything
	"progress_px": 6.0, # getting this much closer to where it's walking counts as progress
	"priorities": [&"dig", &"haul"], # the work tab: earlier wins
	"work_speed_slowdown": 0.5, # morale slowdown multiplier
}
const ROTLING := {"speed": 0.6, "size": Vector2(18, 56), "hp": 90.0}

var tier := 1
var heart: Node2D = null
var morale_speed := 1.0 ## set by the director: 1 normal, lower when working to rule
var on_strike := false
var job: Dictionary = {}
var carrying: Node2D = null
var _path := PackedVector2Array()
var _path_i := 0
var _repath := 0.0
var _stuck := 0.0
var _noise_t := 0.0
var _goal := Vector2.INF
var _best_d := INF ## closest it has got to the current walk target
var _sprite: AnimatedSprite2D


static func make(minion_kind: StringName) -> LairMinion:
	var m := LairMinion.new()
	m.display_name = String(minion_kind)
	m.faction = Actor.Faction.UNDEAD
	var t: Dictionary = GHOUL if minion_kind == &"ghoul" else ROTLING
	m.max_hp = t.hp
	m.box_size = t.size
	m.step_height = 8.0
	m.name = String(minion_kind).capitalize()
	return m


func is_ghoul() -> bool:
	return display_name == "ghoul"


func _ready() -> void:
	super()
	add_to_group(StringName("lair_" + display_name))
	_sprite = ArtLib.make_sprite(display_name)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_life_outside_heart(delta)
	if dead:
		return
	if is_ghoul() and not on_strike:
		_work(delta)
	else:
		velocity.x = 0.0
	move_tick()
	if carrying != null and is_instance_valid(carrying):
		carrying.global_position = global_position + Vector2(0, -box_size.y - 2)
	if _sprite != null:
		_sprite.flip_h = facing < 0
		var anim := "walk" if absf(velocity.x) > 0.05 else ("work" if job.get("type") == Jobs.DIG else "idle")
		if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
			_sprite.play(anim)
	queue_redraw()


func _life_outside_heart(delta: float) -> void:
	if tier > 2 or not GameState.has_heart:
		return
	if not GameState.in_heart_range(global_position):
		take_damage(float(GHOUL.decay_hp_per_s) * delta, null)


func _on_death(_killer: Node2D) -> void:
	_drop_carry()
	if job.has("id"):
		Jobs.release(job.id)
	# The soul it was raised with comes back out: inside the heart's range the orb drifts home by itself,
	# outside it fades unless the necromancer fetches it.
	var outside := not GameState.in_heart_range(global_position)
	var sp := Lair.flesh_spawner(get_tree())
	if sp != null and sp.has_method("spawn_soul_orb"):
		var orb = sp.spawn_soul_orb(global_position - Vector2(0, 20), 1.0, display_name)
		if orb != null and outside:
			Events.soul_orb_dropped.emit(orb)
	if outside:
		LairText.say("minion_soul_lost", &"concerned")
	GameState.count("minions_lost")
	queue_free()


# ---------------------------------------------------------------- work

func _work(delta: float) -> void:
	var speed: float = GHOUL.speed * morale_speed
	if job.is_empty() or not Jobs.has_job(int(job.get("id", -1))):
		job = {}
		_drop_carry()
		job = _next_job()
		_path = PackedVector2Array()
		_stuck = 0.0
		if job.is_empty():
			velocity.x = 0.0
			return
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = float(GHOUL.noise_every_s)
		Events.noise_made.emit(global_position, float(GHOUL.noise), "ghoul")
	_stuck += delta
	if _stuck > float(GHOUL.stuck_s):
		_drop_carry()
		Jobs.give_up(job.id, self)
		job = {}
		return
	match job.type:
		Jobs.DIG:
			_do_dig(speed)
		Jobs.HAUL:
			_do_haul(speed)
		_:
			Jobs.release(job.id)
			job = {}


func _next_job() -> Dictionary:
	# Haul jobs are made on demand by the director; ask it to post any that are due.
	var d := Lair.director(get_tree())
	if d != null and d.has_method("post_haul_jobs"):
		d.post_haul_jobs()
	for t in GHOUL.priorities:
		var j := Jobs.claim_next(self, [t])
		if not j.is_empty():
			return j
	return {}


func _do_dig(speed: float) -> void:
	var r: Rect2i = job.rect
	var w := Sim.world
	if w == null:
		Jobs.complete(job.id)
		job = {}
		return
	# nearest diggable cell in the rect
	var best := Vector2i(-1, -1)
	var best_d := INF
	var left := 0
	var me := Sim.to_cell(global_position - Vector2(0, box_size.y * 0.5))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var m := w.get_mat(x, y)
			if m == SandWorld.M_EMPTY or not w.is_solid(x, y):
				continue
			if SandWorld.mat_hardness(m) <= 0.0 or SandWorld.mat_hardness(m) > float(GHOUL.max_hardness):
				continue
			left += 1
			var d := Vector2(x - me.x, y - me.y).length()
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	if left == 0:
		Jobs.complete(job.id)
		GameState.count("dig_jobs_done")
		job = {}
		return
	var target := Sim.cell_center(best)
	if (global_position - Vector2(0, box_size.y * 0.5)).distance_to(target) <= float(GHOUL.reach_px) + box_size.y * 0.3:
		velocity.x = 0.0
		facing = 1 if target.x >= global_position.x else -1
		var got := Sim.dig_px(target, float(GHOUL.dig_radius_px), float(GHOUL.dig_power) * morale_speed)
		if not got.is_empty():
			_stuck = 0.0
	else:
		_walk_to(target, speed)


func _do_haul(speed: float) -> void:
	var item = job.get("item")
	var dest = job.get("target")
	if carrying == null:
		if not is_instance_valid(item) or (item.get("carrier") != null and item.get("carrier") != self):
			Jobs.cancel(job.id)
			job = {}
			return
		if global_position.distance_to(item.global_position) <= float(GHOUL.reach_px) + 8.0:
			if item.pick_up(self):
				carrying = item
				item.reserved_by = self
				_path = PackedVector2Array()
				_stuck = 0.0
		else:
			_walk_to(item.global_position, speed)
		return
	var goal: Vector2
	if dest is Node2D and is_instance_valid(dest):
		goal = dest.global_position
	elif job.has("pos"):
		goal = job.pos
	else:
		_drop_carry()
		Jobs.cancel(job.id)
		job = {}
		return
	if absf(global_position.x - goal.x) <= 10.0 and absf(global_position.y - goal.y) <= 40.0:
		var it := carrying
		carrying = null
		it.drop(Vector2(goal.x, global_position.y - 6), Vector2.ZERO)
		if dest is LairMachine:
			dest.accept(it)
		Jobs.complete(job.id)
		GameState.count("items_hauled")
		job = {}
	else:
		_walk_to(goal, speed)


func _drop_carry() -> void:
	if carrying != null and is_instance_valid(carrying):
		carrying.drop(global_position + Vector2(0, -4))
	carrying = null


func _walk_to(target: Vector2, speed: float) -> void:
	_repath -= get_physics_process_delta_time()
	var dist := global_position.distance_to(target)
	if _goal.distance_to(target) > 16.0:
		_best_d = INF
	if dist < _best_d - float(GHOUL.progress_px):
		_best_d = dist
		_stuck = 0.0
	if _path.is_empty() or _repath <= 0.0 or _goal.distance_to(target) > 16.0:
		_repath = float(GHOUL.repath_s)
		_goal = target
		_path = LairNav.find_path(global_position, target, box_size, float(GHOUL.reach_px))
		_path_i = 1
	if _path.is_empty() or _path_i >= _path.size():
		# no path: shuffle straight at it and hope
		var dx := target.x - global_position.x
		velocity.x = signf(dx) * speed if absf(dx) > 2.0 else 0.0
		if velocity.x != 0.0:
			facing = int(signf(velocity.x))
		return
	var p := _path[_path_i]
	var dx2 := p.x - global_position.x
	if absf(dx2) <= speed + 0.5 and absf(p.y - global_position.y) < 10.0:
		_path_i += 1
		_stuck = maxf(0.0, _stuck - 0.05)
	velocity.x = signf(dx2) * speed if absf(dx2) > 0.5 else 0.0
	if velocity.x != 0.0:
		facing = int(signf(velocity.x))
	if p.y < global_position.y - 6.0 and on_floor:
		velocity.y = -3.6 # hop a ledge


## While on strike a ghoul is interactable: the necromancer pays a motivational visit.
func interact(_by: Node2D) -> void:
	var d := Lair.director(get_tree())
	if on_strike and d != null and d.has_method("motivational_visit"):
		d.motivational_visit()


func interact_hint() -> String:
	return LairText.t("hint_striker")


func _draw() -> void:
	if on_strike:
		# a picket sign
		draw_line(Vector2(6, -20), Vector2(6, -66), Color("5a4030"), 2.0)
		draw_rect(Rect2(-6, -80, 26, 14), Color("d8ccaa"))
		draw_rect(Rect2(-6, -80, 26, 14), Color(0.1, 0.05, 0.05), false, 1.0)
		draw_line(Vector2(-3, -74), Vector2(17, -74), Color("7d0f14"), 2.0)
