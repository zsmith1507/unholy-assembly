class_name WorldScenery
extends Sprite2D
## Draws WorldGen.scenery (trees, bushes, grass blades, tombstones, the cemetery fence, the insides of
## homes) just behind the sim, so actors walk in front of it and the sim's terrain hides anything below
## ground. One texel per sim cell.

var gen: WorldGen
var _tex: ImageTexture


func _init(world_gen: WorldGen = null) -> void:
	name = "WorldScenery"
	gen = world_gen
	centered = false
	scale = Vector2(Sim.CELL, Sim.CELL)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1 # behind the sim view on the terrain layer
	add_to_group("world_scenery")
	if gen != null and gen.scenery != null:
		_tex = ImageTexture.create_from_image(gen.scenery)
		texture = _tex


## Re-upload after the scenery image changed (a home decayed or was rebuilt).
func refresh() -> void:
	if _tex != null and gen != null:
		_tex.update(gen.scenery)
