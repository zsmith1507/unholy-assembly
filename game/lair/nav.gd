class_name LairNav
extends RefCounted
## Simple walking paths through the sand world for ghouls and other minions.
## A path is a list of feet positions a box can stand at. Moves between them are: walk sideways, step or hop up
## a small ledge, or drop off an edge. Dug tunnels are the path network; nothing is precomputed, so digging
## and collapses are picked up the next time a path is asked for.

const NAV := {
	"step_px": 4.0, # sideways distance between path points
	"hop_px": 16.0, # highest ledge a walker gets up (with a little hop)
	"fall_px": 240.0, # furthest drop it will take
	"max_nodes": 2500, # search budget per path; beyond it the walker gives up
}


## A box of `size` with its feet at `feet` overlaps solid ground.
static func blocked(feet: Vector2, size: Vector2) -> bool:
	var w := Sim.world
	if w == null:
		return false
	var c := Sim.CELL
	var x0 := floori((feet.x - size.x * 0.5) / c)
	var x1 := floori((feet.x + size.x * 0.5 - 0.01) / c)
	var y0 := floori((feet.y - size.y) / c)
	var y1 := floori((feet.y - 0.01) / c)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if w.is_solid(x, y):
				return true
	return false


## True if the row of cells just under the feet has something solid.
static func has_floor(feet: Vector2, size: Vector2) -> bool:
	var w := Sim.world
	if w == null:
		return true
	var c := Sim.CELL
	var x0 := floori((feet.x - size.x * 0.5) / c)
	var x1 := floori((feet.x + size.x * 0.5 - 0.01) / c)
	var y := floori(feet.y / c)
	for x in range(x0, x1 + 1):
		if w.is_solid(x, y):
			return true
	return false


## Drop the feet straight down until standing. Returns the standing feet position, or null if it falls too far.
static func land(feet: Vector2, size: Vector2, max_fall: float = NAV.fall_px) -> Variant:
	var p := snap(feet)
	var fallen := 0.0
	while not has_floor(p, size):
		p.y += Sim.CELL
		fallen += Sim.CELL
		if fallen > max_fall:
			return null
	return p


static func snap(p: Vector2) -> Vector2:
	var c := float(Sim.CELL)
	return Vector2(roundf(p.x / c) * c, roundf(p.y / c) * c)


## A path of feet positions from `from` to anywhere whose body centre is within `reach` px of `target`.
## Empty if none was found. The first point is the start.
static func find_path(from: Vector2, target: Vector2, size: Vector2, reach: float) -> PackedVector2Array:
	var start = land(from, size, 64.0)
	if start == null:
		start = snap(from)
	var half := Vector2(0, size.y * 0.5)
	var step: float = NAV.step_px
	var open: Array = [] # binary heap of [f, key]
	var came := {}
	var g := {}
	var pos := {}
	var k0 := _key(start)
	g[k0] = 0.0
	pos[k0] = start
	came[k0] = null
	_push(open, [start.distance_to(target), k0])
	var nodes := 0
	var best_key = k0
	var best_d := INF
	while not open.is_empty():
		var cur: Array = _pop(open)
		var ck: Vector2i = cur[1]
		var cp: Vector2 = pos[ck]
		var d := (cp - half).distance_to(target)
		if d < best_d:
			best_d = d
			best_key = ck
		if d <= reach:
			return _rebuild(came, pos, ck)
		nodes += 1
		if nodes > int(NAV.max_nodes):
			break
		for dir in [-1.0, 1.0]:
			var n = _neighbour(cp, dir * step, size)
			if n == null:
				continue
			var nk := _key(n)
			var cost: float = g[ck] + cp.distance_to(n)
			if g.has(nk) and g[nk] <= cost:
				continue
			g[nk] = cost
			pos[nk] = n
			came[nk] = ck
			_push(open, [cost + ((n as Vector2) - half).distance_to(target), nk])
	return PackedVector2Array()


## Where a walker standing at `p` ends up after moving `dx` sideways, or null.
static func _neighbour(p: Vector2, dx: float, size: Vector2) -> Variant:
	var nx := p.x + dx
	var hop: float = NAV.hop_px
	var up := 0.0
	while up <= hop:
		var probe := Vector2(nx, p.y - up)
		if not blocked(probe, size) and (up == 0.0 or not blocked(Vector2(p.x, p.y - up), size)):
			return land(probe, size)
		up += Sim.CELL
	return null


static func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x / Sim.CELL), roundi(p.y / Sim.CELL))


static func _rebuild(came: Dictionary, pos: Dictionary, k) -> PackedVector2Array:
	var out := PackedVector2Array()
	while k != null:
		out.append(pos[k])
		k = came[k]
	out.reverse()
	return out


static func _push(heap: Array, e: Array) -> void:
	heap.append(e)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap[parent][0] <= heap[i][0]:
			break
		var t = heap[parent]
		heap[parent] = heap[i]
		heap[i] = t
		i = parent


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and heap[l][0] < heap[m][0]:
				m = l
			if r < n and heap[r][0] < heap[m][0]:
				m = r
			if m == i:
				break
			var t = heap[m]
			heap[m] = heap[i]
			heap[i] = t
			i = m
	return top
