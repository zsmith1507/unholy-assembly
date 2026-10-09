class_name GridBody
extends Node2D
## Moves a box through the falling-sand world. Every character and loose item uses this.
## The node's position is the middle of the box's bottom edge (the feet). Units are pixels.
## Solid cells (static ground and settled powders) block; liquids slow you and let you swim.

@export var box_size := Vector2(12, 56) ## width and height in pixels
@export var gravity := 0.25 ## pixels per tick per tick
@export var max_fall := 7.0
@export var step_height := 6.0 ## climbs ledges up to this many pixels without jumping
@export var liquid_drag := 0.85 ## velocity kept per tick while submerged
@export var collide := true

var velocity := Vector2.ZERO ## pixels per tick (60 ticks a second)
var on_floor := false
var submerged := 0.0 ## 0 = dry, 1 = fully under liquid
var hit_wall := 0 ## -1 left, 1 right, 0 none (last move)
var hit_ceiling := false


## Advance one physics tick. Call from _physics_process.
func move_tick() -> void:
	submerged = _liquid_fraction()
	velocity.y = minf(velocity.y + gravity * (1.0 - submerged * 0.85), max_fall)
	if submerged > 0.0:
		velocity *= liquid_drag
	if not collide or Sim.world == null:
		position += velocity
		return
	hit_wall = 0
	hit_ceiling = false
	_move_x(velocity.x)
	on_floor = false
	_move_y(velocity.y)
	if not on_floor:
		on_floor = _box_blocked(position + Vector2(0, 1))


## True if the box placed with its feet at `feet` overlaps a solid cell.
func _box_blocked(feet: Vector2) -> bool:
	var w := Sim.world
	var c := Sim.CELL
	var x0 := floori((feet.x - box_size.x * 0.5) / c)
	var x1 := floori((feet.x + box_size.x * 0.5 - 0.01) / c)
	var y0 := floori((feet.y - box_size.y) / c)
	var y1 := floori((feet.y - 0.01) / c)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if w.is_solid(x, y):
				return true
	return false


func _move_x(dx: float) -> void:
	var remaining := dx
	while absf(remaining) > 0.0001:
		var stepv := clampf(remaining, -1.0, 1.0)
		var next := position + Vector2(stepv, 0)
		if not _box_blocked(next):
			position = next
		else:
			# try to walk up a small ledge
			var climbed := false
			if on_floor or submerged > 0.3:
				var up := 1.0
				while up <= step_height:
					if not _box_blocked(next - Vector2(0, up)):
						position = next - Vector2(0, up)
						climbed = true
						break
					up += 1.0
			if not climbed:
				hit_wall = signi(int(sign(stepv)))
				velocity.x = 0.0
				return
		remaining -= stepv


func _move_y(dy: float) -> void:
	var remaining := dy
	while absf(remaining) > 0.0001:
		var stepv := clampf(remaining, -1.0, 1.0)
		var next := position + Vector2(0, stepv)
		if _box_blocked(next):
			if stepv > 0:
				on_floor = true
			else:
				hit_ceiling = true
			velocity.y = 0.0
			return
		position = next
		remaining -= stepv


## Share of the box's height standing in liquid, sampled down the middle.
func _liquid_fraction() -> float:
	if Sim.world == null:
		return 0.0
	var c := Sim.CELL
	var cx := floori(position.x / c)
	var y0 := floori((position.y - box_size.y) / c)
	var y1 := floori((position.y - 0.01) / c)
	var wet := 0
	for y in range(y0, y1 + 1):
		if Sim.world.is_liquid(cx, y):
			wet += 1
	return float(wet) / float(maxi(1, y1 - y0 + 1))


## Bounding rect in pixels.
func get_box() -> Rect2:
	return Rect2(position.x - box_size.x * 0.5, position.y - box_size.y, box_size.x, box_size.y)
