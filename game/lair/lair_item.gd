class_name LairItem
extends Item
## An item the lair makes (gibs, bones, stitched bodies) or a stand-in corpse for tests and demos.
## Adds a look and the Harvest spell's pull. Corpses and parts from Bodies and Souls are their own Items;
## the lair handles any node in group `items` with a `kind`.

## Box size in pixels for each kind (lying down).
const SIZES := {
	&"corpse": Vector2(26, 8),
	&"part": Vector2(10, 6),
	&"gibs": Vector2(10, 8),
	&"bones": Vector2(12, 6),
	&"stitched_body": Vector2(26, 9),
	&"meat": Vector2(8, 6),
}

## Placeholder colours until Art draws items (res://art/sprites/<kind>.tres replaces them).
const COLORS := {
	&"corpse": Color("7a6a5a"),
	&"part": Color("8f5b5a"),
	&"gibs": Color("7f3a3a"),
	&"bones": Color("d8ccaa"),
	&"stitched_body": Color("6a7a5a"),
	&"meat": Color("b06a5a"),
}


static func make(item_kind: StringName, item_data: Dictionary = {}) -> LairItem:
	var it := LairItem.new()
	it.kind = item_kind
	it.data = item_data.duplicate()
	it.box_size = SIZES.get(item_kind, Vector2(10, 8))
	it.step_height = 2.0
	it.name = String(item_kind).capitalize().replace(" ", "")
	return it


func _ready() -> void:
	super()
	add_to_group("pullable")
	if ResourceLoader.exists("res://art/sprites/%s.tres" % kind) or ArtLib.SIZES.has(String(kind)):
		add_child(ArtLib.make_sprite(String(kind)))
	queue_redraw()


## The Harvest spell tugs on loose items. Pixels per tick squared, for one tick.
func apply_pull(force: Vector2) -> void:
	if carrier != null:
		return
	velocity += force


func _draw() -> void:
	if get_child_count() > 0:
		return
	var s := box_size
	var c: Color = COLORS.get(kind, Color.MAGENTA)
	var r := Rect2(-s.x * 0.5, -s.y, s.x, s.y)
	var dark := Color(0.03, 0.02, 0.04)
	match kind:
		&"gibs":
			# a lumpy sack
			draw_rect(r.grow(-1), c)
			draw_rect(Rect2(r.position.x + 3, r.position.y - 2, 4, 3), c.darkened(0.3))
			draw_rect(r, dark, false, 1.0)
		&"bones":
			# a bundle of long bones, tied
			for i in 3:
				draw_rect(Rect2(r.position.x, r.position.y + i * 2, s.x, 2), c.darkened(i * 0.08))
			draw_rect(Rect2(-1, r.position.y, 2, s.y), Color("5a4030"))
		&"stitched_body":
			draw_rect(r, c)
			draw_rect(Rect2(r.end.x - 7, r.position.y - 1, 7, s.y + 1), c.lightened(0.1))
			for i in range(3, int(s.x) - 8, 3):
				draw_line(Vector2(r.position.x + i, r.position.y + 2), Vector2(r.position.x + i, r.end.y - 2), dark, 1.0)
			draw_rect(r, dark, false, 1.0)
		_:
			draw_rect(r, c)
			draw_rect(r, dark, false, 1.0)
