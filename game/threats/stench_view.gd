extends Node2D
## A faint browning-green haze over Threats.stench_sources(), drawn in the fx layer.

const HAZE := {
	"color": Color(0.50, 0.55, 0.20, 0.16),
	"core_color": Color(0.45, 0.40, 0.15, 0.20),
	"radius_px": 22.0, # at strength 1
	"max_radius_px": 70.0,
	"wobble_px": 3.0,
	"puffs": 3,
}


func _ready() -> void:
	z_index = 2


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for src in Threats.stench_sources():
		var p: Vector2 = src.pos
		var r := clampf(HAZE.radius_px * sqrt(float(src.strength)), 6.0, HAZE.max_radius_px)
		for i in HAZE.puffs:
			var ph := t * 0.7 + i * 2.1 + p.x * 0.01
			var off := Vector2(sin(ph), cos(ph * 1.3) - 0.6 * i) * HAZE.wobble_px * (i + 1)
			draw_circle(p + off, r * (1.0 - 0.2 * i), HAZE.color)
		draw_circle(p, r * 0.4, HAZE.core_color)
