class_name ArtBackdrop
extends Node2D
## Clock-driven sky, parallax forest silhouettes, a darkening underground backdrop and drifting mist.
## Lives on main.background and follows the camera. Owned by Art.

var surface_y := 0.0
var override_hour := -1.0
var lighting: ArtLighting
var _mist: CPUParticles2D
var _rng := RandomNumberGenerator.new()
var _trees_far := PackedFloat32Array()
var _trees_near := PackedFloat32Array()


func _ready() -> void:
	_rng.seed = 7
	for i in 64:
		_trees_far.append(_rng.randf_range(0.6, 1.0))
		_trees_near.append(_rng.randf_range(0.5, 1.0))
	_mist = CPUParticles2D.new()
	_mist.amount = 40
	_mist.lifetime = 14.0
	_mist.preprocess = 14.0
	_mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_mist.emission_rect_extents = Vector2(360, 30)
	_mist.direction = Vector2(1, 0)
	_mist.spread = 10.0
	_mist.gravity = Vector2.ZERO
	_mist.initial_velocity_min = 3.0
	_mist.initial_velocity_max = 8.0
	_mist.scale_amount_min = 6.0
	_mist.scale_amount_max = 14.0
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.75, 0.8, 0.0))
	g.set_color(1, Color(0.7, 0.75, 0.8, 0.0))
	g.add_point(0.5, Color(0.65, 0.72, 0.78, 0.09))
	_mist.color_ramp = g
	_mist.texture = ArtLighting.light_texture()
	_mist.scale_amount_min = 0.5
	_mist.scale_amount_max = 1.2
	_mist.z_index = 30  # in front of the background, still on its layer
	add_child(_mist)


func _hour() -> float:
	if override_hour >= 0.0: return override_hour
	if lighting: return lighting.current_hour()
	var gs := get_node_or_null(^"/root/GameState")
	return gs.hour if gs else 20.0


func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position = cam.get_screen_center_position()
	_mist.position = Vector2(0, surface_y - global_position.y - 10)
	_mist.visible = global_position.y < surface_y + 200
	queue_redraw()


func _sky(h: float) -> Array:
	# [top, horizon] colours
	h = fposmod(h, 24.0)
	var night := [Color("07080f"), Color("1b2233")]
	var dusk := [Color("1d1428"), Color("7a3a2e")]
	var day := [Color("4a4e58"), Color("8e8a7e")]
	var t: Array
	if h < 5.0 or h >= 21.0: t = night
	elif h < 6.5: t = _mix(night, dusk, (h - 5.0) / 1.5)
	elif h < 8.0: t = _mix(dusk, day, (h - 6.5) / 1.5)
	elif h < 18.0: t = day
	elif h < 19.5: t = _mix(day, dusk, (h - 18.0) / 1.5)
	else: t = _mix(dusk, night, (h - 19.5) / 1.5)
	return t


func _mix(a: Array, b: Array, k: float) -> Array:
	return [a[0].lerp(b[0], k), a[1].lerp(b[1], k)]


func _draw() -> void:
	var vs := get_viewport_rect().size
	var half := vs * 0.5
	var cx := global_position.x
	var sy := surface_y - global_position.y  # surface in local coords
	var h := _hour()
	var sky := _sky(h)
	# sky gradient in 8 flat bands (pixel-art banding, no airbrush)
	var top := -half.y
	var bottom := minf(sy, half.y)
	if bottom > top:
		var bands := 8
		for i in bands:
			var y0 := lerpf(top, bottom, float(i) / bands)
			var y1 := lerpf(top, bottom, float(i + 1) / bands)
			draw_rect(Rect2(-half.x, floorf(y0), vs.x, ceilf(y1 - y0) + 1), sky[0].lerp(sky[1], float(i) / (bands - 1)))
		# moon or a smothered sun
		var night := h >= 19.5 or h < 6.0
		var arc := fposmod(h - (19.0 if night else 7.0), 24.0) / (11.0 if night else 12.0)
		var mp := Vector2(lerpf(-half.x * 0.8, half.x * 0.8, arc), -half.y + 40 + absf(arc - 0.5) * 90)
		if night:
			draw_circle(mp, 9, Color("c9cfc8"))
			draw_circle(mp + Vector2(3, -2), 8, sky[0])
			for i in 40:
				var p := Vector2(fposmod(i * 97.3 - cx * 0.02, vs.x) - half.x, -half.y + fposmod(i * 53.7, maxf(1.0, bottom - top) * 0.7))
				draw_rect(Rect2(p.floor(), Vector2.ONE), Color(0.8, 0.85, 0.9, 0.35 + 0.3 * (i % 3) / 2.0))
		else:
			draw_circle(mp, 12, Color(0.85, 0.8, 0.65, 0.25))
			draw_circle(mp, 7, Color(0.9, 0.85, 0.7, 0.6))
		# far ridge, far forest, near forest: parallax by camera x
		_ridge(cx * 0.1, sy - 40, 30.0, sky[1].darkened(0.45), vs, 0.013)
		_forest(cx * 0.25, sy - 18, 34.0, sky[1].darkened(0.65), vs, _trees_far, 14.0)
		_forest(cx * 0.5, sy - 4, 44.0, Color("0c0b10"), vs, _trees_near, 22.0)
	# underground backdrop: earth that darkens with depth, teal at mid depth, purple near the deep
	if sy < half.y:
		var u0 := maxf(sy, -half.y)
		var steps := 10
		for i in steps:
			var y0 := lerpf(u0, half.y, float(i) / steps)
			var y1 := lerpf(u0, half.y, float(i + 1) / steps)
			var depth := (y0 + global_position.y) - surface_y
			var c := Color("2a2019").lerp(Color("0d1416"), clampf(depth / 300.0, 0, 1)).lerp(Color("140c1c"), clampf((depth - 900.0) / 1200.0, 0, 1))
			draw_rect(Rect2(-half.x, floorf(y0), vs.x, ceilf(y1 - y0) + 1), c)
		# old strata lines
		for k in 6:
			var wy := floorf(surface_y + 60 + k * 90) - global_position.y
			if wy > u0 and wy < half.y:
				for x in range(int(-half.x), int(half.x), 4):
					var off := sin((x + cx * 0.8) * 0.03 + k) * 3.0
					draw_rect(Rect2(x, wy + off, 4, 1), Color(0, 0, 0, 0.25))


func _ridge(off: float, base_y: float, amp: float, col: Color, vs: Vector2, f: float) -> void:
	var half := vs * 0.5
	var pts := PackedVector2Array()
	pts.append(Vector2(-half.x, half.y + 400))
	for x in range(int(-half.x), int(half.x) + 9, 8):
		var wx := x + off
		var y := base_y - amp * (0.5 + 0.3 * sin(wx * f) + 0.2 * sin(wx * f * 2.7 + 1.3))
		pts.append(Vector2(x, floorf(y)))
	pts.append(Vector2(half.x + 8, half.y + 400))
	draw_colored_polygon(pts, col)


func _forest(off: float, base_y: float, tall: float, col: Color, vs: Vector2, heights: PackedFloat32Array, gap: float) -> void:
	var half := vs * 0.5
	draw_rect(Rect2(-half.x, base_y - 4, vs.x, half.y + 400), col)
	var first := floori((-half.x + off) / gap) - 1
	var last := floori((half.x + off) / gap) + 1
	for i in range(first, last + 1):
		var hgt := heights[posmod(i, heights.size())] * tall
		var x := i * gap - off + sin(i * 12.9) * gap * 0.3
		var w := hgt * 0.32
		# a ragged, dead-ish conifer: stacked jagged tiers
		var tiers := 4
		for t in tiers:
			var ty := base_y - hgt * (float(t) / tiers)
			var tw := w * (1.0 - float(t) / (tiers + 1))
			draw_colored_polygon(PackedVector2Array([
				Vector2(floorf(x - tw), floorf(ty)), Vector2(floorf(x + tw), floorf(ty)),
				Vector2(floorf(x), floorf(ty - hgt / tiers * 1.6))]), col)
		draw_rect(Rect2(floorf(x) - 1, base_y - hgt * 0.2, 2, hgt * 0.2 + 4), col)
