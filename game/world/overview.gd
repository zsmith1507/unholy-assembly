extends Node2D
## Renders the whole generated map (sim plus walk-through scenery) for checking world generation by eye.
## Saves the full map to /tmp/unholy-shots/world_map.png and 2x close-ups of the left town with its
## graveyard, the right town and the forest start. Pass `-- --quit` to exit after saving (works headless).

const OVERVIEW := {
	"seed": 666,
	"dir": "/tmp/unholy-shots/",
	"sky": Color8(0x14, 0x12, 0x1a),
}


func _ready() -> void:
	var seed: int = OVERVIEW.seed
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
	Sim.create(1536, 768, seed)
	Sim.running = false
	var gen := WorldGen.new()
	gen.generate(Sim.world, seed)
	var sim := Image.create(Sim.world.get_width(), Sim.world.get_height(), false, Image.FORMAT_RGBA8)
	Sim.world.render_region(sim, 0, 0)
	var img := Image.create(sim.get_width(), sim.get_height(), false, Image.FORMAT_RGBA8)
	img.fill(OVERVIEW.sky)
	img.blend_rect(gen.scenery, Rect2i(Vector2i.ZERO, sim.get_size()), Vector2i.ZERO)
	img.blend_rect(sim, Rect2i(Vector2i.ZERO, sim.get_size()), Vector2i.ZERO)
	var dir: String = OVERVIEW.dir
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "world_map.png")
	var small := img.duplicate() as Image
	small.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	small.save_png(dir + "world_map_view.png")
	var left: Rect2i = gen.towns[0].rect
	var gy: int = gen.towns[0].ground
	_crop(img, Rect2i(left.position.x - 10, gy - 110, gen.graveyard.end.x - left.position.x + 20, 150), dir + "world_town.png")
	var right: Rect2i = gen.towns[1].rect
	gy = gen.towns[1].ground
	_crop(img, Rect2i(right.position.x - 10, gy - 110, right.size.x + 20, 150), dir + "world_town_right.png")
	var sp := gen.spawn_cell
	_crop(img, Rect2i(sp.x - 240, sp.y - 120, 480, 200), dir + "world_forest.png")
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tr.size = get_viewport_rect().size
	add_child(tr)
	if "--quit" in OS.get_cmdline_user_args():
		get_tree().quit()


func _crop(img: Image, r: Rect2i, path: String) -> void:
	var c := img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	c.resize(c.get_width() * 2, c.get_height() * 2, Image.INTERPOLATE_NEAREST)
	c.save_png(path)
