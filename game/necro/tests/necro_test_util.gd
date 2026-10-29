extends RefCounted
## Shared helpers for the necro tests: a flat world and a scripted necromancer standing on it.

const NecromancerScript := preload("res://necro/necromancer.gd")


## Flat world (256 x 160 cells, ground at row 100 = 200 px) with a scripted necromancer on it.
static func setup(t, x_px := 160.0) -> Necromancer:
	t.flat_world()
	var n: Necromancer = NecromancerScript.new()
	n.scripted = true
	n.position = Vector2(x_px, 100 * Sim.CELL)
	t.root.add_child(n)
	return n


static func count_solid(rect_cells: Rect2i) -> int:
	var counts := Sim.world.count_rect(rect_cells.position.x, rect_cells.position.y, rect_cells.size.x, rect_cells.size.y)
	var n := 0
	for m in counts:
		var k := SandWorld.mat_kind(m)
		if k == 1 or k == 2:
			n += counts[m]
	return n
