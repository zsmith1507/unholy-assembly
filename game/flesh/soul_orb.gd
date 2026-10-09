class_name SoulOrb
extends Node2D
## A loose soul (or a critter's sliver of one). Teal, glowing, bobbing.
## Inside the heart's range it drifts home by itself and pays into GameState.
## Near the necromancer it follows him (he has "claimed" it) until a heart's range takes over.
## Orbs that `fades` (a minion died far from home) vanish if he doesn't reach them in time.
## Owned by Bodies and Souls.

## The souls rule (design doc): a death's soul is his only if he is this close, or it is in the heart's range.
const SOULS := {
	"witness_radius": 160.0, ## px
}

const ORB := {
	"drift_speed": 0.9, ## px per tick toward the heart
	"follow_speed": 2.2, ## px per tick toward the necromancer once claimed
	"claim_radius": 48.0, ## px: the necromancer claims an orb this close
	"deposit_radius": 10.0, ## px from the heart's centre
	"fade_seconds": 20.0, ## unclaimed minion orbs last this long
	"color": Color("7fe8d8"),
}

var amount := 1.0
var source := ""
var fragment := false ## true: pays GameState.add_fragments instead of add_souls
var fades := false
var claimed := false
var life := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("soul_orbs")
	z_index = 30
	life = ORB.fade_seconds
	_t = randf() * TAU


func _physics_process(delta: float) -> void:
	_t += delta * 3.0
	var player := _necro()
	if player != null and not claimed and global_position.distance_to(player.global_position + Vector2(0, -32)) < ORB.claim_radius:
		claimed = true
	if GameState.has_heart and (claimed or GameState.in_heart_range(global_position)):
		var to := GameState.heart_pos - global_position
		var spd: float = ORB.follow_speed if claimed else ORB.drift_speed
		if to.length() <= ORB.deposit_radius + spd:
			_deposit()
			return
		global_position += to.normalized() * spd
	elif claimed and player != null:
		var tgt := player.global_position + Vector2(-14 * _facing(player), -48 + sin(_t) * 3.0)
		global_position = global_position.lerp(tgt, 0.08)
	else:
		global_position.y += sin(_t) * 0.15
		if fades:
			life -= delta
			modulate.a = clampf(life / 4.0, 0.0, 1.0)
			if life <= 0.0:
				queue_free()
				return
	queue_redraw()


func _deposit() -> void:
	if fragment:
		GameState.add_fragments(amount, source, global_position)
	else:
		GameState.add_souls(amount, source, global_position)
	queue_free()


func _draw() -> void:
	var worth := amount / float(GameState.ECON.fragments_per_soul) if fragment else amount
	var r := 1.5 + clampf(worth, 0.1, 3.0) * 2.5
	var c: Color = ORB.color
	var pulse := 0.5 + 0.5 * sin(_t)
	draw_circle(Vector2.ZERO, r * 2.2, Color(c.r, c.g, c.b, 0.12 + 0.08 * pulse))
	draw_circle(Vector2.ZERO, r * 1.4, Color(c.r, c.g, c.b, 0.3))
	draw_rect(Rect2(-r * 0.5, -r * 0.5, r, r), c.lightened(0.4))


static func _necro() -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for n in tree.get_nodes_in_group(&"necro"):
		if n is Node2D:
			return n
	return null


## True if the necromancer stands within `radius` px of `at`.
static func necro_within(at: Vector2, radius: float) -> bool:
	var n := _necro()
	return n != null and n.global_position.distance_to(at) <= radius


static func _facing(n: Node) -> int:
	var f = n.get("facing")
	return f if f is int else 1
