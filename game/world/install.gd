extends RefCounted
## World and Towns installer. Runs first: generates the world into Sim.world and returns `info`
## (see docs/ARCHITECTURE.md, "info keys").

const WORLD := {
	"default_seed": 666,
}

var gen: WorldGen


func install(main: Node, _info: Dictionary) -> Variant:
	var seed: int = main.get("world_seed") if main.get("world_seed") else WORLD.default_seed
	gen = WorldGen.new()
	gen.generate(Sim.world, seed)
	var c := float(Sim.CELL)

	var settlements := Settlements.new(gen)
	main.add_child(settlements)
	var clock := DayClock.new()
	main.add_child(clock)
	_torches(main)

	var heights := gen.heights
	var surface_at := func(x_px: float) -> float:
		var x := clampi(int(x_px / c), 0, heights.size() - 1)
		return heights[x] * c

	var avg := 0.0
	for h in heights:
		avg += h
	avg /= float(heights.size())

	var graves: Array[Vector2] = []
	for g in gen.graves:
		graves.append(Sim.cell_center(g))
	var zones: Array[Rect2] = []
	for z in gen.critter_zones:
		zones.append(Rect2(Vector2(z.position) * c, Vector2(z.size) * c))

	return {
		"necro_spawn": Vector2(gen.spawn_cell) * c,
		"surface_y_px": avg * c,
		"surface_at": surface_at,
		"graveyard": Rect2(Vector2(gen.graveyard.position) * c, Vector2(gen.graveyard.size) * c),
		"graves": graves,
		"towns": settlements.towns,
		"critter_zones": zones,
		"patrol_routes": _patrol_routes(surface_at, settlements.towns),
		"world_seed": seed,
		"settlements": settlements,
	}


## Each town patrols out toward the forest middle and back, along the surface.
func _patrol_routes(surface_at: Callable, towns: Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var mid := Sim.world_size_px().x * 0.5
	for t in towns:
		var r: Rect2 = t.rect
		var start := r.end.x if t.side < 0 else r.position.x
		var route := PackedVector2Array()
		for i in 6:
			var x := lerpf(start, mid - 80.0 * t.side, i / 5.0)
			route.append(Vector2(x, surface_at.call(x)))
		out.append(route)
	# A graveyard watch: walk along the cemetery.
	var g := Rect2(Vector2(gen.graveyard.position) * Sim.CELL, Vector2(gen.graveyard.size) * Sim.CELL)
	out.append(PackedVector2Array([Vector2(g.position.x, surface_at.call(g.position.x)),
		Vector2(g.end.x, surface_at.call(g.end.x))]))
	return out


## Town torches: a post and flame per torch; TownTorches asks Art's lighting hook for the glow.
func _torches(main: Node) -> void:
	var holder := TownTorches.new()
	for t in gen.towns:
		for tc in t.torches:
			holder.add_torch(Sim.cell_center(tc))
	var layer: Node = main.get("buildings")
	(layer if layer != null else main).add_child(holder)
