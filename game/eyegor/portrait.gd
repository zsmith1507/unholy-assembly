class_name EyegorPortrait
extends Control
## Eyegor's portrait, drawn in code until Art supplies one: a floating bloodshot eye with two black feathered
## wings and a clipboard. The pupil darts while he talks; the lid narrows when he's concerned.

const LOOK := {
	"flap_speed": 5.0,
	"bob": 1.5,
}

var mood: StringName = &"chipper"
var talking := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var c := s * 0.5 + Vector2(0, sin(_t * 2.0) * LOOK.bob - 2)
	var r := minf(s.x, s.y) * 0.24
	draw_rect(Rect2(Vector2.ZERO, s), Color("0b090c"))
	draw_rect(Rect2(Vector2.ZERO, s), Color("4a3a4c"), false, 1.0)
	# wings: three black feathers each side, flapping
	var flap := sin(_t * LOOK.flap_speed) * 0.35
	for side in [-1.0, 1.0]:
		for i in 3:
			var ang := (-0.5 + i * 0.35 + flap) * side
			var base := c + Vector2(side * r * 0.8, 0)
			var dir := Vector2(side, 0).rotated(-ang * side * side)
			dir = Vector2(side * cos(ang), -sin(absf(ang)) + 0.3 * i - 0.3)
			var tip := base + dir.normalized() * r * (1.6 - i * 0.25)
			draw_colored_polygon(PackedVector2Array([base + Vector2(0, -2), tip, base + Vector2(0, 2)]), Color("1a1418") if i % 2 == 0 else Color("2a2028"))
	# clipboard, held below
	var cb := Rect2(c + Vector2(-r * 0.7, r * 0.9), Vector2(r * 1.4, r * 0.9))
	draw_rect(cb, Color("6b4a2e"))
	draw_rect(cb.grow(-1.5), Color("e9dfc4"))
	draw_rect(Rect2(cb.position + Vector2(cb.size.x * 0.35, -1.5), Vector2(cb.size.x * 0.3, 2.5)), Color("8a8a8a"))
	for i in 2:
		draw_line(cb.position + Vector2(3, 4 + i * 3), cb.position + Vector2(cb.size.x - 3, 4 + i * 3), Color("2e2218"), 1.0)
	# eyeball
	draw_circle(c, r, Color("e8dcc0"))
	for i in 4: # bloodshot veins
		var a := i * 1.7 + 0.4
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.95, c + Vector2(cos(a + 0.3), sin(a + 0.3)) * r * 0.55, Color("9a2a2a"), 1.0)
	var iris_col: Color = EyegorPanel.MOOD_COLORS.get(mood, Color("5fe0cc"))
	var look := Vector2(sin(_t * 7.0) * 0.25, cos(_t * 5.0) * 0.15) if talking else Vector2(0.15, 0.05)
	var ic := c + look * r
	draw_circle(ic, r * 0.5, iris_col.darkened(0.2))
	draw_circle(ic, r * 0.22, Color("0b090c"))
	draw_circle(ic + Vector2(-r * 0.15, -r * 0.15), r * 0.08, Color(1, 1, 1, 0.8))
	# lid: narrows when concerned, flat line for announcements
	var lid := 0.0
	match mood:
		&"concerned": lid = 0.45
		&"announce": lid = 0.3
		&"proud": lid = -0.1
	if fmod(_t, 4.0) < 0.12:
		lid = 1.0 # blink
	if lid > 0.0:
		draw_rect(Rect2(c - Vector2(r + 1, r + 1), Vector2(r * 2 + 2, r * 2.0 * lid)), Color("3a2a30"))
	draw_arc(c, r, 0, TAU, 24, Color("2a1e22"), 1.0)
