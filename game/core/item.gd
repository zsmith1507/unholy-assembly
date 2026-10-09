class_name Item
extends GridBody
## A loose thing in the world that minions carry and machines eat: a corpse, an arm, a sack of gibs.
## Items fall and settle like characters. While carried, the carrier moves them and physics is off.
## Kinds used by the hidden-start slice (add more freely, but tell the Lair department):
##   &"corpse"   a whole dead human (data: {"source": "farmer"})
##   &"part"     an arm, leg, head or torso (data: {"part": "arm"})
##   &"gibs"     processed flesh
##   &"bones"    processed bone
##   &"stitched_body" ready for the reanimation altar
##   &"meat"     farm meat that feeds ghouls
##   &"metal", &"wood", &"stone"   building materials

@export var kind: StringName = &"part"
@export var amount := 1
var data := {}
var carrier: Node2D = null
var reserved_by: Node = null ## a ghoul that has claimed this item for a job


func _ready() -> void:
	add_to_group("items")
	add_to_group(StringName("item_" + String(kind)))


func _physics_process(_delta: float) -> void:
	if carrier != null:
		return
	velocity.x *= 0.9 if on_floor else 0.99
	move_tick()


func pick_up(by: Node2D) -> bool:
	if carrier != null:
		return false
	carrier = by
	velocity = Vector2.ZERO
	return true


func drop(at: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	carrier = null
	reserved_by = null
	global_position = at
	velocity = vel


func describe() -> String:
	return Narrative.describe_item(kind, data)
