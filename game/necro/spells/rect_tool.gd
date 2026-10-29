class_name NecroRectTool
extends NecroSpell
## A spell that paints a rectangle: press to start, drag, release to commit. The alternate button
## cancels a drag in progress (or, for tools with choices, cycles the choice when not dragging).
## Works the same with a gamepad: hold the trigger and sweep the right stick.

var dragging := false
var drag_from := Vector2.ZERO
var drag_to := Vector2.ZERO
var _hover := Vector2.ZERO
var _shown := false


## The rectangle being painted, in cells.
func drag_rect_cells() -> Rect2i:
	var a := Sim.to_cell(Vector2(minf(drag_from.x, drag_to.x), minf(drag_from.y, drag_to.y)))
	var b := Sim.to_cell(Vector2(maxf(drag_from.x, drag_to.x), maxf(drag_from.y, drag_to.y)))
	return Rect2i(a, b - a + Vector2i.ONE)


func tick(aim: Vector2, held: bool, pressed: bool, released: bool) -> void:
	channelling = false
	_shown = true
	_hover = aim
	if pressed:
		dragging = true
		drag_from = aim
	if dragging:
		drag_to = aim
		channelling = held
	if released and dragging:
		dragging = false
		var r := drag_rect_cells()
		if r.size.x >= 2 and r.size.y >= 2:
			commit(r)


func alt_pressed() -> void:
	if dragging:
		dragging = false
	else:
		cycle()


func on_deselect() -> void:
	super.on_deselect()
	dragging = false
	_shown = false


## Override: do the thing with a finished rectangle of cells.
func commit(_rect: Rect2i) -> void:
	pass


## Override: cycle the tool's choice (stockpile kind).
func cycle() -> void:
	pass


## Override: is this rectangle acceptable? Drawn red when not.
func rect_ok(_rect: Rect2i) -> bool:
	return true


func _draw() -> void:
	super._draw()
	if not _shown or necro == null or necro.get_selected() != self:
		return
	if dragging:
		var r := drag_rect_cells()
		var px := Rect2(Sim.to_pixel(r.position), Vector2(r.size) * Sim.CELL)
		var c := color if rect_ok(r) else Color(1.0, 0.3, 0.3)
		draw_rect(px, Color(c, 0.15))
		_dashed_rect(px, Color(c, 0.85))
	else:
		var p := (_hover / Sim.CELL).floor() * Sim.CELL
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(color, 0.6), false, 1.0)


func _dashed_rect(r: Rect2, c: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 4]
		var L := a.distance_to(b)
		var d := 0.0
		while d < L:
			draw_line(a.lerp(b, d / L), a.lerp(b, minf(L, d + 4.0) / L), c, 1.0)
			d += 7.0
