extends RefCounted
## Art and Lighting installer: darkness + light pools (group `lighting`) and the sky/parallax/mist backdrop.

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
	return {"lighting": lighting}
