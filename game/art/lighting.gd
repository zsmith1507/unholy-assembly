class_name ArtLighting
extends Node2D
## Darkness and light pools. In group `lighting`. Owned by Art.
## A CanvasModulate darkens the world by GameState.hour and by how deep the camera is; lights added through
## add_light() cut pools out of it. The sim's glow map and sprite glow layers are unshaded, so they stay bright.
##   get_tree().get_first_node_in_group("lighting").add_light(node, Color("3fd6c0"), 48.0, 1.0)

const NIGHT := Color("232a3d")   # moonlit blue-grey on the surface
const DUSK := Color("6e4a4e")    # bruised warm dusk
const DAY := Color("b7ad9a")     # grimy overcast day; never full white
const DEEP := Color("101c22")    # cold teal-black underground
const ABYSS := Color("1a1026")   # purple near the deep
const NECRO_TEAL := Color("3fd6c0")

var modulate_node: CanvasModulate
var surface_y := 0.0  ## pixels; set from info.surface_y_px
var deep_y := 2000.0  ## pixels below which the purple creeps in
var override_hour := -1.0  ## >= 0 pins the hour (demo, tests)
var override_depth := -1.0 ## >= 0 pins depth below surface in px (demo, tests)

static var _tex_cache := {}


func _ready() -> void:
	add_to_group("lighting")
	modulate_node = CanvasModulate.new()
	modulate_node.name = "Darkness"
	add_child(modulate_node)
	_update()


func _process(_delta: float) -> void:
	_update()


func current_hour() -> float:
	if override_hour >= 0.0:
		return override_hour
	var gs := get_node_or_null(^"/root/GameState")
	return gs.hour if gs else 20.0


func current_depth() -> float:
	if override_depth >= 0.0:
		return override_depth
	var cam := get_viewport().get_camera_2d()
	return maxf(0.0, (cam.get_screen_center_position().y if cam else surface_y) - surface_y)


## Sky/ambient colour for an hour of the day (0-24). Night 21-5, dawn 5-7, day 7-18, dusk 18-21.
static func ambient_for_hour(h: float) -> Color:
	h = fposmod(h, 24.0)
	if h < 5.0 or h >= 21.0: return NIGHT
	if h < 6.0: return NIGHT.lerp(DUSK, h - 5.0)
	if h < 7.5: return DUSK.lerp(DAY, (h - 6.0) / 1.5)
	if h < 18.0: return DAY
	if h < 19.5: return DAY.lerp(DUSK, (h - 18.0) / 1.5)
	return DUSK.lerp(NIGHT, (h - 19.5) / 1.5)


## Darkness colour for an hour and a depth below the surface (px).
func ambient(h: float, depth_px: float) -> Color:
	var c := ambient_for_hour(h)
	var t := clampf(depth_px / 160.0, 0.0, 1.0)        # fully underground ~10 m down
	c = c.lerp(DEEP, t)
	var d := clampf((depth_px - deep_y * 0.5) / deep_y, 0.0, 1.0)
	return c.lerp(ABYSS, d)


func _update() -> void:
	modulate_node.color = ambient(current_hour(), current_depth())


## A soft light pool on `node`. Everyone's lights go through here so they share one look.
func add_light(node: Node2D, color: Color, radius_px: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.name = "ArtLight"
	l.texture = light_texture()
	l.texture_scale = radius_px / 64.0
	l.color = color
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.shadow_enabled = false
	if node:
		node.add_child(l)
	return l


## A 128 px radial falloff, quantised into a few bands so pools read as pixel art, not airbrush.
static func light_texture() -> Texture2D:
	if _tex_cache.has("light"):
		return _tex_cache["light"]
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var v := clampf(1.0 - d, 0.0, 1.0)
			v = v * v * (3.0 - 2.0 * v)
			v = floorf(v * 6.0) / 6.0
			img.set_pixel(x, y, Color(1, 1, 1, v))
	var t := ImageTexture.create_from_image(img)
	_tex_cache["light"] = t
	return t
