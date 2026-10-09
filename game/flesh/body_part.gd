class_name BodyPart
extends Item
## A torn-off arm, leg, head or torso: a two-point stick that tumbles in the sand world.
## Fresh parts dribble blood from the torn end until the blood timer runs out.
## Pullable by Harvest, siphonable for a little mana, carried by ghouls like any Item.
## Owned by Bodies and Souls.

const PART := {
	"gravity": 0.25,
	"damping": 0.985,
	"ground_friction": 0.6,
	"dribble": 0.25, ## chance per tick of a drop from the torn end, while fresh
	"blood_seconds": 45.0,
	"mana": {"arm": 0.04, "leg": 0.06, "head": 0.05, "torso": 0.12}, ## souls' worth, fresh
	"old_tint": Color(0.62, 0.66, 0.58),
	"weight": {"arm": 1.0, "head": 2.0, "leg": 3.0, "torso": 6.0},
}

var look := "villager"
var part := "arm"
var blood := 0.0
var flesh := 1.0
var a := Vector2.ZERO ## torn end (root)
var b := Vector2.ZERO ## far end
var pa := Vector2.ZERO
var pb := Vector2.ZERO
var length := 10.0
var _sprite: Sprite2D
var _last_pos := Vector2.ZERO
var _old := false


func _init() -> void:
	kind = &"part"
	box_size = Vector2(8, 6)


func setup(look_name: String, part_name: String, root: Vector2, tip: Vector2, vel: Vector2, bleeding: bool, blood_left: float) -> void:
	look = look_name
	part = part_name
	a = root
	b = tip
	pa = root - vel
	pb = tip - vel
	length = maxf(4.0, root.distance_to(tip))
	blood = blood_left if bleeding else 0.0
	data = {"part": part, "source": look, "fresh": bleeding}
	position = (a + b) * 0.5


func make_old() -> void:
	_old = true
	flesh = 0.6
	blood = 0.0
	data["fresh"] = false


func _ready() -> void:
	super._ready()
	add_to_group(&"pullable")
	add_to_group(&"siphonable")
	add_to_group(&"body_parts")
	_sprite = Sprite2D.new()
	_sprite.texture = ArtLib.body_parts(look)[part]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _old:
		_sprite.modulate = PART.old_tint
	add_child(_sprite)
	_last_pos = global_position
	_update_sprite()


func _physics_process(delta: float) -> void:
	if carrier != null:
		var shift := global_position - _last_pos
		a += shift; b += shift; pa = a; pb = b
	else:
		var va := (a - pa) * PART.damping + Vector2(0, PART.gravity)
		var vb := (b - pb) * PART.damping + Vector2(0, PART.gravity)
		pa = a; pb = b
		a = _collide(a, a + va)
		b = _collide(b, b + vb)
		var d := b - a
		var l := maxf(0.001, d.length())
		var diff := (l - length) / l * 0.5
		var na := a + d * diff
		var nb := b - d * diff
		if not Sim.solid_at(na): a = na
		if not Sim.solid_at(nb): b = nb
		if Sim.solid_at(a + Vector2(0, 1.5)):
			pa.x = a.x - (a.x - pa.x) * PART.ground_friction
		if Sim.solid_at(b + Vector2(0, 1.5)):
			pb.x = b.x - (b.x - pb.x) * PART.ground_friction
		global_position = (a + b) * 0.5
	_last_pos = global_position
	if blood > 0.0:
		blood = maxf(0.0, blood - delta / PART.blood_seconds)
		data["fresh"] = blood > 0.0
		if randf() < PART.dribble * blood:
			Sim.spill_px(a, SandWorld.M_BLOOD, 1, (a - b).normalized() * 0.6)
	_update_sprite()


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
		return from + Vector2(0, -1)
	return from


func _update_sprite() -> void:
	if _sprite == null:
		return
	var top := b if part in ["head", "torso"] else a
	var bot := a if part in ["head", "torso"] else b
	var d := bot - top
	_sprite.position = (top + bot) * 0.5 - global_position
	_sprite.rotation = d.angle() - PI * 0.5
	var th := float(_sprite.texture.get_height())
	_sprite.scale = Vector2(1, clampf(d.length() / th, 0.4, 2.0))


## Harvest. Light parts fly; heavy ones drag.
func apply_pull(force: Vector2) -> void:
	if carrier != null:
		return
	var w: float = PART.weight.get(part, 2.0)
	a += force / w
	b += force / w


func siphon(amount: float) -> float:
	var take := minf(amount, flesh)
	flesh -= take
	var rich := 2.0 if blood > 0.0 else 1.0
	var got: float = take * PART.mana.get(part, 0.05) * rich
	if _sprite:
		_sprite.modulate = Color(0.45, 0.42, 0.4).lerp(PART.old_tint if _old else Color.WHITE, clampf(flesh, 0.0, 1.0))
	if flesh <= 0.0:
		Sim.spill_px(global_position, SandWorld.M_ASH, 4, Vector2(0, -0.2))
		queue_free()
	return got
