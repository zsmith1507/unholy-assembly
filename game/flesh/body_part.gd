class_name BodyPart
extends Item
## A torn-off arm, leg, head or torso: a two-point stick that tumbles in the sand world.
## Fresh parts dribble blood from the torn end until the blood timer runs out.
## Pullable by Harvest, siphonable for a little mana, carried by ghouls like any Item (kind "part",
## data {"part": "arm"|"leg"|"head"|"torso", "source": look, "fresh": bool}).
## Owned by Bodies and Souls.

const PART := {
	"gravity": 0.25,
	"damping": 0.985,
	"ground_friction": 0.6,
	"dribble": 0.25, ## chance per tick of a drop from the torn end, while fresh
	"blood_seconds": 45.0,
	"mana": {"arm": 0.04, "leg": 0.06, "head": 0.05, "torso": 0.12}, ## souls' worth of a whole fresh part
	"old_mana": 0.5, ## graveyard parts give this share
	"old_tint": Color(0.62, 0.66, 0.58),
	## share of Harvest's pull each part feels: heavy parts drag in slower (must stay above gravity, 0.25 / 0.38)
	"pull_scale": {"arm": 1.0, "head": 0.95, "leg": 0.85, "torso": 0.75},
	"sleep_speed": 0.03,
	"sleep_ticks": 40,
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
var asleep := false
var _sprite: Sprite2D
var _last_pos := Vector2.ZERO
var _old := false
var _still := 0


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
		asleep = false
	elif not asleep:
		_step()
		global_position = (a + b) * 0.5
		velocity = global_position - (pa + pb) * 0.5
	elif Engine.get_physics_frames() % 20 == 0 and not Sim.solid_at(global_position + Vector2(0, 4)):
		asleep = false
	_last_pos = global_position
	if blood > 0.0:
		blood = maxf(0.0, blood - delta / PART.blood_seconds)
		data["fresh"] = blood > 0.0
		if carrier == null and randf() < PART.dribble * blood:
			Sim.spill_px(a, SandWorld.M_BLOOD, 1, (a - b).normalized() * 0.6)
	if not asleep:
		_update_sprite()


func _step() -> void:
	var va := (a - pa) * PART.damping + Vector2(0, PART.gravity)
	var vb := (b - pb) * PART.damping + Vector2(0, PART.gravity)
	pa = a; pb = b
	a = BodyRig.collide_point(a, a + va)
	b = BodyRig.collide_point(b, b + vb)
	var d := b - a
	var l := maxf(0.001, d.length())
	var diff := (l - length) / l * 0.5
	var na := a + d * diff
	var nb := b - d * diff
	if not Sim.solid_at(na) or Sim.solid_at(a): a = na
	if not Sim.solid_at(nb) or Sim.solid_at(b): b = nb
	if Sim.solid_at(a + Vector2(0, 1.5)):
		pa.x = a.x - (a.x - pa.x) * PART.ground_friction
	if Sim.solid_at(b + Vector2(0, 1.5)):
		pb.x = b.x - (b.x - pb.x) * PART.ground_friction
	var fastest := maxf((a - pa).length(), (b - pb).length())
	_still = _still + 1 if fastest < PART.sleep_speed else 0
	if _still >= PART.sleep_ticks:
		asleep = true
		_still = 0
		pa = a; pb = b


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


## Item.drop for a two-point stick: move both ends so the middle lands at `at`.
func drop(at: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	carrier = null
	reserved_by = null
	var shift := at - (a + b) * 0.5
	a += shift; b += shift
	pa = a - vel; pb = b - vel
	global_position = at
	_last_pos = at
	velocity = vel
	asleep = false
	_update_sprite()


## Harvest. Light parts fly; heavy ones drag.
func apply_pull(force: Vector2) -> void:
	if carrier != null:
		return
	asleep = false
	_still = 0
	var f: Vector2 = force * float(PART.pull_scale.get(part, 0.85))
	a = BodyRig.collide_point(a, a + f)
	b = BodyRig.collide_point(b, b + f)


## Siphon asks for `amount` souls' worth; returns what it got. Fresh (bloody) parts give double.
func siphon(amount: float) -> float:
	if amount <= 0.0 or flesh <= 0.0:
		return 0.0
	var worth: float = PART.mana.get(part, 0.05) * (2.0 if blood > 0.0 else 1.0) * (PART.old_mana if _old else 1.0)
	var take := minf(amount / worth, flesh)
	flesh -= take
	if _sprite:
		_sprite.modulate = Color(0.45, 0.42, 0.4).lerp(PART.old_tint if _old else Color.WHITE, clampf(flesh, 0.0, 1.0))
	if flesh <= 0.0:
		Sim.spill_px(global_position + Vector2(0, -4), SandWorld.M_ASH, 4, Vector2(0, -0.8))
		queue_free()
	return take * worth
