extends Node2D
## Renders the whole generated map zoomed out (for checking world generation by eye).
## Also saves the full-resolution map to /tmp/unholy-shots/world_map.png.

const OVERVIEW := {"seed": 666, "out": "/tmp/unholy-shots/world_map.png"}


func _ready() -> void:
	Sim.create(1536, 768, OVERVIEW.seed)
	Sim.running = false
	var gen := WorldGen.new()
	gen.generate(Sim.world, OVERVIEW.seed)
	var img := Image.create(Sim.world.get_width(), Sim.world.get_height(), false, Image.FORMAT_RGBA8)
	Sim.world.render_region(img, 0, 0)
	DirAccess.make_dir_recursive_absolute(OVERVIEW.out.get_base_dir())
	img.save_png(OVERVIEW.out)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tr.size = get_viewport_rect().size
	add_child(tr)
