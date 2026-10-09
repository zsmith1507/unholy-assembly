class_name BodyRig
extends Node2D
## Draws a body made of six parts (head, torso, two arms, two legs) on a stick skeleton.
## The living pose it with `BodyRig.pose(...)`; the dead (Remains) feed it their ragdoll points.
## Textures come from ArtLib.body_parts(look), so real art drops in without code changes.
## Owned by Bodies and Souls.

## Bone lengths in pixels (a ~60 px adult, feet to crown).
const RIG := {
	"leg": 24.0,
	"torso": 20.0,
	"head": 10.0,
	"arm": 18.0,
}
## Skeleton points and the six segments between them: [key, root point, far point].
const PT_NAMES := ["hip", "neck", "top", "handB", "handF", "footB", "footF"]
const SEGS := [
	["torso", "hip", "neck"],
	["head", "neck", "top"],
	["armB", "neck", "handB"],
	["armF", "neck", "handF"],
	["legB", "hip", "footB"],
	["legF", "hip", "footF"],
]
## Which art each segment uses, and what it is called as an item part.
const PART := {"torso": "torso", "head": "head", "armB": "arm", "armF": "arm", "legB": "leg", "legF": "leg"}
## How heavy each part is. Heavy parts drag in slower and their joints hold longer,
## so Harvest takes a body apart in order: arms, then head, then legs, then the torso.
const WEIGHT := {"armB": 1.0, "armF": 1.0, "head": 2.0, "legB": 3.0, "legF": 3.0, "torso": 6.0}
const DRAW_ORDER := ["armB", "legB", "torso", "head", "legF", "armF"]
## The art for these runs from the far point back toward the root (a head's crown is its far end).
const REVERSED := {"torso": true, "head": true}
const BACK_SHADE := Color(0.72, 0.7, 0.74) ## limbs on the far side are a touch darker

var look := "villager"
var _sprites := {} ## seg key -> Sprite2D


func setup(look_name: String) -> void:
	look = look_name
	var tex := ArtLib.body_parts(look)
	for i in DRAW_ORDER.size():
		var k: String = DRAW_ORDER[i]
		var s := Sprite2D.new()
		s.texture = tex[PART[k]]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_index = i
		s.z_as_relative = true
		if k.ends_with("B"):
			s.self_modulate = BACK_SHADE
		s.visible = false
		add_child(s)
		_sprites[k] = s


## Place one segment's sprite between two points in this node's local space.
func show_segment(k: String, a: Vector2, b: Vector2) -> void:
	var s: Sprite2D = _sprites.get(k)
	if s == null:
		return
	var top := a
	var bottom := b
	if REVERSED.has(k):
		top = b
		bottom = a
	var d := bottom - top
	var l := d.length()
	s.visible = true
	s.position = (top + bottom) * 0.5
	s.rotation = d.angle() - PI * 0.5 if l > 0.01 else 0.0
	var th := float(s.texture.get_height()) if s.texture else 1.0
	s.scale = Vector2(1.0, clampf(l / th, 0.4, 2.0))


func hide_segment(k: String) -> void:
	var s: Sprite2D = _sprites.get(k)
	if s:
		s.visible = false


## Draw a whole living pose (points in local space).
func show_pose(pts: Dictionary) -> void:
	for seg in SEGS:
		show_segment(seg[0], pts[seg[1]], pts[seg[2]])


## Mirror the art for a body facing left.
func set_flip(left: bool) -> void:
	for s in _sprites.values():
		s.flip_h = left


## The skeleton of a living body this frame. `feet` is where it stands; facing 1 right, -1 left.
## phase: walk cycle; lean: radians forward; aim: if set, the front arm points this way (a pitchfork thrust).
static func pose(feet: Vector2, facing: int, phase: float, moving: bool, lean := 0.0, aim := Vector2.ZERO) -> Dictionary:
	var sw := sin(phase) * 0.55 if moving else 0.0
	var bob := absf(cos(phase)) * 1.5 if moving else 0.0
	var ln := lean * facing
	var up := Vector2(sin(ln), -cos(ln))
	var hip := feet + Vector2(0, -RIG.leg + bob)
	var neck := hip + up * RIG.torso
	var top := neck + up * RIG.head
	var shoulder := neck + Vector2(0, 2)
	var out := {
		"hip": hip,
		"neck": neck,
		"top": top,
		"footF": _limb(hip, sw * facing, RIG.leg),
		"footB": _limb(hip, -sw * facing, RIG.leg),
		"handB": _limb(shoulder, sw * 0.8 * facing, RIG.arm),
	}
	if aim != Vector2.ZERO:
		out["handF"] = shoulder + aim.normalized() * RIG.arm
	else:
		out["handF"] = _limb(shoulder, -sw * 0.8 * facing, RIG.arm)
	return out


## A limb hanging from `o` at angle `ang` (0 = straight down).
static func _limb(o: Vector2, ang: float, l: float) -> Vector2:
	return o + Vector2(sin(ang), cos(ang)) * l


## A body lying on its back with its feet toward `facing`, centred on `center` (for graves and tests).
static func lying_pose(center: Vector2, facing: int = 1) -> Dictionary:
	var f := float(facing)
	var hip := center + Vector2(f * 8.0, 0)
	var neck := hip - Vector2(f * RIG.torso, 0)
	return {
		"hip": hip,
		"neck": neck,
		"top": neck - Vector2(f * RIG.head, 0),
		"handB": neck + Vector2(f * RIG.arm * 0.95, -2),
		"handF": neck + Vector2(f * RIG.arm * 0.95, 2),
		"footB": hip + Vector2(f * RIG.leg, -2),
		"footF": hip + Vector2(f * RIG.leg, 2),
	}
