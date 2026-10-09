extends Node
## Owns the falling-sand world and ticks it at 60 Hz.
## Game positions are in pixels; the sim works in cells. One cell is CELL x CELL pixels.

signal world_ready(world: SandWorld)

const CELL := 2 ## pixels per cell side. Characters are drawn at full pixel detail on top.

var world: SandWorld = null
var running := true
var ticks_per_frame := 1 ## raise to fast-forward in tests


## Create a fresh world. World generation fills it in afterwards.
func create(width_cells: int, height_cells: int, seed: int = 0) -> SandWorld:
	world = SandWorld.new()
	world.setup(width_cells, height_cells, seed if seed != 0 else randi())
	world_ready.emit(world)
	return world


func _physics_process(_delta: float) -> void:
	if world == null or not running:
		return
	for i in ticks_per_frame:
		world.step()


# ---------------------------------------------------------------- coordinate helpers

func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func to_pixel(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL, c.y * CELL)


## Centre of a cell in pixels.
func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)


func world_size_px() -> Vector2:
	if world == null:
		return Vector2.ZERO
	return Vector2(world.get_width() * CELL, world.get_height() * CELL)


# ---------------------------------------------------------------- pixel-space conveniences

func solid_at(p: Vector2) -> bool:
	if world == null:
		return false
	var c := to_cell(p)
	return world.is_solid(c.x, c.y)


func liquid_at(p: Vector2) -> bool:
	if world == null:
		return false
	var c := to_cell(p)
	return world.is_liquid(c.x, c.y)


func mat_at(p: Vector2) -> int:
	if world == null:
		return 0
	var c := to_cell(p)
	return world.get_mat(c.x, c.y)


## First solid point on the line from a to b, in pixels, or null.
func raycast_px(a: Vector2, b: Vector2, stop_at_liquid := false) -> Variant:
	if world == null:
		return null
	var hit := world.raycast(to_cell(a), to_cell(b), stop_at_liquid)
	if hit.x < 0:
		return null
	return cell_center(hit)


## Dig a circle around a pixel position. Returns {mat_id: cells removed}.
func dig_px(at: Vector2, radius_px: float, power: float) -> Dictionary:
	if world == null:
		return {}
	var c := to_cell(at)
	return world.dig(c.x, c.y, maxi(1, int(radius_px / CELL)), power)


## Splash or spill grains at a pixel position, velocity in pixels per tick.
func spill_px(at: Vector2, mat: int, count: int, vel: Vector2 = Vector2.ZERO) -> void:
	if world == null:
		return
	var c := to_cell(at)
	world.spill(c.x, c.y, mat, count, vel.x / CELL, vel.y / CELL)
