class_name SimView
extends Node2D
## Draws the part of the sand world the camera can see. Re-rendered every frame from the C++ sim.
## Owned by the Pixel Physics department (rendering look: Art and Lighting may restyle via the material).

const MARGIN := 8 ## extra cells around the screen so scrolling never shows a gap

var _sprite: Sprite2D
var _glow_sprite: Sprite2D
var _image: Image
var _glow_image: Image
var _tex: ImageTexture
var _glow_tex: ImageTexture
var show_glow := true


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2(Sim.CELL, Sim.CELL)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_glow_sprite = Sprite2D.new()
	_glow_sprite.centered = false
	_glow_sprite.scale = Vector2(Sim.CELL, Sim.CELL)
	_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow_sprite.material = add
	add_child(_glow_sprite)


## The cell rectangle currently on screen (plus margin).
func visible_cells() -> Rect2i:
	var vp := get_viewport()
	var xf := vp.get_canvas_transform().affine_inverse()
	var r := Rect2(xf * Vector2.ZERO, vp.get_visible_rect().size / vp.get_canvas_transform().get_scale())
	var c0 := Sim.to_cell(r.position) - Vector2i(MARGIN, MARGIN)
	var size := Vector2i(ceili(r.size.x / Sim.CELL), ceili(r.size.y / Sim.CELL)) + Vector2i(MARGIN * 2, MARGIN * 2)
	return Rect2i(c0, size)


func _process(_delta: float) -> void:
	if Sim.world == null:
		return
	var r := visible_cells()
	if _image == null or _image.get_size() != r.size:
		_image = Image.create_empty(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		_glow_image = Image.create_empty(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		_tex = null
		_glow_tex = null
	Sim.world.render_region(_image, r.position.x, r.position.y)
	if _tex == null:
		_tex = ImageTexture.create_from_image(_image)
		_sprite.texture = _tex
	else:
		_tex.update(_image)
	_sprite.position = Sim.to_pixel(r.position)
	_glow_sprite.visible = show_glow
	if show_glow:
		Sim.world.render_glow(_glow_image, r.position.x, r.position.y)
		if _glow_tex == null:
			_glow_tex = ImageTexture.create_from_image(_glow_image)
			_glow_sprite.texture = _glow_tex
		else:
			_glow_tex.update(_glow_image)
		_glow_sprite.position = _sprite.position
