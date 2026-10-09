class_name LairStructure
extends Node2D
## Anything the necromancer builds in the lair. The node's origin is the middle of the footprint's bottom edge
## (where it stands on the floor), like characters. Joins `lair_structures` and `lair_<kind>`.

var kind: StringName = &""
var footprint := Vector2(32,32) ## pixels: width, height
var heart: Node2D = null ## the heart this structure belongs to (destroyed with it)
var sprite: AnimatedSprite2D = null


func _ready() -> void:
	add_to_group(&"lair_structures")
	add_to_group(StringName("lair_" + String(kind)))
	if ArtLib.SIZES.has(String(kind)) or ResourceLoader.exists("res://art/sprites/%s.tres" % kind):
		sprite = ArtLib.make_sprite(String(kind))
		sprite.z_index = -1
		add_child(sprite)


## Footprint in pixels, world space.
func get_rect() -> Rect2:
	return Rect2(global_position.x - footprint.x * 0.5, global_position.y - footprint.y, footprint.x, footprint.y)


## Middle of the footprint, pixels.
func center() -> Vector2:
	return global_position - Vector2(0, footprint.y * 0.5)


## Taken down: the heart going, or a later deconstruct command.
func destroy() -> void:
	queue_free()
