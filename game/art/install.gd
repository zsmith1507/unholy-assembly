extends RefCounted
## Art and Lighting installer: darkness + light pools (group `lighting`), the sky/parallax/mist backdrop, and a
## soft bloom on the sim's glow map.

## Bloom on SimView's glow layer (shaders/glow_bloom.gdshader). halo: how far glowing cells light their
## neighbours; radius in cells; bands quantise the falloff so it stays pixel-art (0 = smooth).
const GLOW := {"core": 1.0, "halo": 1.6, "radius": 3.5, "bands": 10.0}


func install(main: Node, info: Dictionary) -> Variant:
	var surface: float = info.get("surface_y_px", Sim.world_size_px().y * 0.3)
	var lighting := ArtLighting.new()
	lighting.name = "Lighting"
	lighting.surface_y = surface
	lighting.deep_y = maxf(800.0, Sim.world_size_px().y - surface)
	main.add_child(lighting)
	var bd := ArtBackdrop.new()
	bd.name = "Backdrop"
	bd.surface_y = surface
	bd.lighting = lighting
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	bd.material = unshaded  # sky colours are final; the darkness only falls on the world
	main.background.add_child(bd)
	var sv = main.get("sim_view")
	if sv != null:
		if sv.is_node_ready():
			style_glow(sv)
		else:
			sv.ready.connect(style_glow.bind(sv), CONNECT_ONE_SHOT)
	return {"lighting": lighting}


## Swap SimView's plain additive glow for the bloom shader. Safe to call on any SimView.
static func style_glow(sim_view: Node) -> bool:
	var g = sim_view.get("_glow_sprite")
	if not (g is CanvasItem):
		return false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://art/shaders/glow_bloom.gdshader")
	for k in GLOW:
		mat.set_shader_parameter(k, GLOW[k])
	g.material = mat
	return true
