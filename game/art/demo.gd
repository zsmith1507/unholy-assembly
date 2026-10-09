extends Node2D
## Mood demo: a slice of surface at night over a teal-lit lair. No sim needed.
##   xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/shot.tscn -- --scene=res://art/demo.tscn --frames=120 --out=/tmp/unholy-shots/art.png
## --hour=<h> on the command line pins the time of day.

const SURFACE := 150.0

var lighting: ArtLighting


func _ready() -> void:
	var hour := 21.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hour="): hour = float(a.substr(7))
	var cam := Camera2D.new()
	cam.position = Vector2(320, 180)
	add_child(cam)
	cam.make_current()
	lighting = ArtLighting.new()
	lighting.surface_y = SURFACE
	lighting.override_hour = hour
	lighting.override_depth = 0.0
	add_child(lighting)
	var bd := ArtBackdrop.new()
	bd.surface_y = SURFACE
	bd.override_hour = hour
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	bd.material = m
	bd.z_index = -100
	add_child(bd)
	var ground := DemoGround.new()
	ground.surface = SURFACE
	add_child(ground)
	# surface: a farmer with a lantern and a villager on patrol, critters
	var farmer := _put("farmer", Vector2(470, SURFACE), "walk", true)
	lighting.add_light(farmer, Color("e0a050"), 70.0, 1.1).position = Vector2(-10, -30)
	_put("villager", Vector2(520, SURFACE), "walk", true)
	_put("rabbit", Vector2(110, SURFACE), "idle")
	_put("crow", Vector2(380, SURFACE), "work")
	_put("deer", Vector2(40, SURFACE), "work")
	# the necromancer at the lip of his pit, casting
	var necro := _put("necromancer", Vector2(210, SURFACE), "cast")
	lighting.add_light(necro, ArtLighting.NECRO_TEAL, 60.0, 0.9).position = Vector2(14, -34)
	# the lair below
	var lair_floor := 300.0
	var kinds := ["ghoul", "rotling", "ghoul"]
	var anims := ["work", "walk", "carry"]
	for i in 3:
		_put(kinds[i], Vector2(250 + i * 50, lair_floor), anims[i])
	var heart_glow := Node2D.new()
	heart_glow.position = Vector2(440, lair_floor - 30)
	add_child(heart_glow)
	lighting.add_light(heart_glow, ArtLighting.NECRO_TEAL, 140.0, 1.3)
	var torch := Node2D.new()
	torch.position = Vector2(180, lair_floor - 40)
	add_child(torch)
	lighting.add_light(torch, Color("6a40a0"), 90.0, 0.9)


func _put(n: String, at: Vector2, anim: String, flip := false) -> AnimatedSprite2D:
	var s := ArtLib.make_sprite(n)
	s.position = at
	s.flip_h = flip
	if s.sprite_frames.has_animation(anim):
		s.play(anim)
	add_child(s)
	return s


class DemoGround extends Node2D:
	var surface := 150.0

	func _draw() -> void:
		var top := Color("3a2c22")
		var dirt := Color("2a2019")
		var rock := Color("1d1a1e")
		var cave := Rect2(150, 228, 420, 74)
		var shaft := Rect2(222, surface, 22, 80)
		draw_rect(Rect2(-100, surface, 900, 400), dirt)
		draw_rect(Rect2(-100, surface, 900, 3), top)
		for x in range(-100, 800, 3):
			if (x * 7) % 5 < 2:
				draw_rect(Rect2(x, surface - 2, 1, 2), Color("2c3320"))
		draw_rect(cave, Color("120f14"))
		draw_rect(shaft, Color("120f14"))
		draw_rect(Rect2(150, 300, 420, 60), rock)
		for i in 220:
			var p := Vector2(fposmod(i * 37.1, 900) - 100, surface + 6 + fposmod(i * 23.7, 200))
			if not cave.has_point(p) and not shaft.has_point(p):
				draw_rect(Rect2(p.floor(), Vector2(2, 1)), Color("3b2e24") if i % 3 else Color("1a1513"))
		# the necrotic heart, a stand-in lump until the lair's sprite lands
		var h := Vector2(440, 272)
		draw_circle(h, 14, Color("0e2a28"))
		draw_circle(h, 10, Color("1f6a60"))
		draw_circle(h + Vector2(-3, -3), 4, Color("7fe8d8"))
