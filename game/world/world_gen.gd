class_name WorldGen
extends RefCounted
## Seeded world generation into a SandWorld. Same seed, same world.
## Fills the terrain column by column with fill_rect, then paints features (caves, pockets, trees, towns,
## graveyard) on top. Returns a Dictionary of everything the installer needs to build `info`.

const GEN := {
	"surface_frac": 0.40, ## typical surface height as a fraction of world height
	"hill_amp": 22.0, ## cells of rolling hill height either way
	"hill_freq": 0.006,
	"grass_depth": 2,
	"earth_depth": 80, ## packed earth below the grass, before clay starts
	"clay_depth": 60, ## clay band thickness
	"bedrock_rows": 5,
	"dirt_patches": 60, ## loose soil blobs in the earth layer
	"caves": 5,
	"liquid_pockets": 3, ## small, deep, used sparingly
	"tree_spacing": [18, 34], ## cells between trunks
	"town_width": 190, ## cells
	"town_margin": 70, ## cells from the world edge to a town
	"graveyard_width": 90,
	"graves": 8,
	"spawn_clearing": 40, ## no trees within this many cells of the necromancer's start
}

var w: SandWorld
var width := 0
var height := 0
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var heights := PackedInt32Array() ## first solid (grass) row per column
var flat_spans: Array = [] ## [x0, x1] spans kept flat for towns and the graveyard

var towns: Array = [] ## {name, rect(cells), side, homes:[{id, rect(cells), residents, alive}], chapel(rect), torches}
var graveyard := Rect2i()
var graves: Array = [] ## coffin centres in cells
var tombstones: Array = [] ## Rect2i in cells
var critter_zones: Array = [] ## Rect2i in cells
var spawn_cell := Vector2i()


func generate(world: SandWorld, seed: int) -> void:
	w = world
	width = w.get_width()
	height = w.get_height()
	rng.seed = seed
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = GEN.hill_freq
	noise.fractal_octaves = 3
	_plan_flat_spans()
	_heightmap()
	_terrain()
	_dirt_patches()
	_caves()
	_liquid_pockets()
	_towns()
	_graveyard()
	_trees()
	spawn_cell = Vector2i(width / 2, heights[width / 2])
	_critter_zones()


# ---------------------------------------------------------------- terrain

func _plan_flat_spans() -> void:
	var m: int = GEN.town_margin
	var tw: int = GEN.town_width
	var gw: int = GEN.graveyard_width
	# Left town, its graveyard just east of it; right town alone.
	flat_spans = [[m, m + tw + 12 + gw], [width - m - tw, width - m]]


func _heightmap() -> void:
	heights.resize(width)
	var base := height * float(GEN.surface_frac)
	var raw := PackedFloat32Array()
	raw.resize(width)
	for x in width:
		raw[x] = base + noise.get_noise_1d(x) * GEN.hill_amp * 1.6
	# Flatten town spans to their mean height and blend the edges over 30 cells.
	for span in flat_spans:
		var avg := 0.0
		for x in range(span[0], span[1]):
			avg += raw[x]
		avg /= float(span[1] - span[0])
		for x in range(maxi(0, span[0] - 30), mini(width, span[1] + 30)):
			var t := 1.0
			if x < span[0]:
				t = 1.0 - float(span[0] - x) / 30.0
			elif x >= span[1]:
				t = 1.0 - float(x - span[1] + 1) / 30.0
			t = smoothstep(0.0, 1.0, t)
			raw[x] = lerpf(raw[x], avg, t)
	for x in width:
		heights[x] = int(round(raw[x]))


func _terrain() -> void:
	var br: int = GEN.bedrock_rows
	for x in width:
		var top := heights[x]
		var g: int = GEN.grass_depth
		var e_end := top + g + GEN.earth_depth + int(noise.get_noise_2d(x, 500) * 8.0)
		var c_end := e_end + GEN.clay_depth + int(noise.get_noise_2d(x, 900) * 10.0)
		var b_start := height - br - int(absf(noise.get_noise_2d(x, 1300)) * 4.0)
		w.fill_rect(x, top, 1, g, SandWorld.M_GRASS)
		w.fill_rect(x, top + g, 1, e_end - top - g, SandWorld.M_EARTH)
		w.fill_rect(x, e_end, 1, c_end - e_end, SandWorld.M_CLAY)
		w.fill_rect(x, c_end, 1, b_start - c_end, SandWorld.M_STONE)
		w.fill_rect(x, b_start, 1, height - b_start, SandWorld.M_BEDROCK)


func _dirt_patches() -> void:
	for i in GEN.dirt_patches:
		var x := rng.randi_range(4, width - 5)
		var y := heights[x] + rng.randi_range(6, GEN.earth_depth)
		w.paint_circle(x, y, rng.randi_range(3, 7), SandWorld.M_DIRT, false)
	# Stone and clay lenses for texture.
	for i in 40:
		var x := rng.randi_range(4, width - 5)
		var y := heights[x] + rng.randi_range(60, 160)
		w.paint_circle(x, y, rng.randi_range(3, 6), SandWorld.M_STONE if i % 2 else SandWorld.M_CLAY, false)


func _caves() -> void:
	for i in GEN.caves:
		var x := float(rng.randi_range(100, width - 100))
		var y := float(heights[int(x)] + rng.randi_range(170, 330))
		y = minf(y, height - 40)
		var ang := rng.randf_range(-0.6, 0.6) + (PI if rng.randf() < 0.5 else 0.0)
		var r := rng.randf_range(9.0, 14.0)
		for s in rng.randi_range(14, 24):
			w.paint_circle(int(x), int(y), int(r), SandWorld.M_EMPTY, false)
			# Rubble on the cave floor.
			w.paint_circle(int(x), int(y + r) , 2, SandWorld.M_RUBBLE, false)
			r = clampf(r + rng.randf_range(-2.0, 2.0), 7.0, 16.0)
			ang += rng.randf_range(-0.5, 0.5)
			x = clampf(x + cos(ang) * 7.0, 30, width - 30)
			y = clampf(y + sin(ang) * 3.0, heights[int(x)] + 150, height - 35)


func _liquid_pockets() -> void:
	var mats := [SandWorld.M_ICHOR, SandWorld.M_BLOOD, SandWorld.M_MUD]
	for i in GEN.liquid_pockets:
		var x := rng.randi_range(450, width - 450)
		var y := mini(heights[x] + rng.randi_range(200, 360), height - 30)
		_basin(x, y, rng.randi_range(5, 8), mats[i % mats.size()])


## A stone bowl with liquid in its lower half. Stone holds liquids; soil soaks them.
func _basin(cx: int, cy: int, r: int, mat: int) -> void:
	w.paint_circle(cx, cy, r + 3, SandWorld.M_STONE, false)
	w.paint_circle(cx, cy, r, SandWorld.M_EMPTY, false)
	for y in range(cy, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if w.is_empty(x, y):
				w.set_mat(x, y, mat)


# ---------------------------------------------------------------- towns

func _towns() -> void:
	var m: int = GEN.town_margin
	var tw: int = GEN.town_width
	var specs := [
		{"name": "Gallowmere", "x0": m, "side": -1, "chapel": true},
		{"name": "Wretch's Ford", "x0": width - m - tw, "side": 1, "chapel": false},
	]
	var next_id := 0
	for s in specs:
		var x0: int = s.x0
		var gy := heights[x0 + tw / 2]
		var town := {"name": s.name, "side": s.side, "rect": Rect2i(x0, gy - 60, tw, 60), "homes": [], "torches": [], "chapel": Rect2i()}
		var x := x0 + 6
		var built_chapel := false
		while x < x0 + tw - 30:
			if s.chapel and not built_chapel and x > x0 + tw / 2 - 30:
				var cw := 34
				town.chapel = _chapel(x, gy, cw)
				town.torches.append(Vector2i(x - 3, gy - 14))
				town.torches.append(Vector2i(x + cw + 2, gy - 14))
				built_chapel = true
				x += cw + 10
				continue
			var hw := rng.randi_range(24, 32)
			var hh := rng.randi_range(18, 24)
			var rect := Rect2i(x, gy - hh, hw, hh)
			build_home(rect, false)
			town.homes.append({"id": next_id, "rect": rect, "residents": rng.randi_range(1, 3), "alive": 0})
			town.homes[-1].alive = town.homes[-1].residents
			next_id += 1
			town.torches.append(Vector2i(x + hw + 4, gy - 14))
			x += hw + rng.randi_range(8, 14)
		towns.append(town)


## Plank walls, an empty interior, a door on the side facing the forest, a wooden roof.
## `ruined` knocks out most of the walls and roof: an empty home, decaying.
func build_home(r: Rect2i, ruined: bool) -> void:
	var wall := SandWorld.M_PLANK
	var roof_h := 5
	var body := Rect2i(r.position.x, r.position.y + roof_h, r.size.x, r.size.y - roof_h)
	# Clear the space first so a rebuild never leaves rubble inside.
	w.fill_rect(r.position.x - 2, r.position.y - 1, r.size.x + 4, r.size.y + 1, SandWorld.M_EMPTY)
	if ruined:
		var rr := RandomNumberGenerator.new()
		rr.seed = r.position.x * 7919 + r.position.y
		for y in range(body.position.y, body.end.y):
			if rr.randf() < 0.45:
				w.set_mat(body.position.x, y, wall)
			if rr.randf() < 0.35:
				w.set_mat(body.end.x - 1, y, wall)
		for x in range(body.position.x, body.end.x):
			if rr.randf() < 0.2:
				w.set_mat(x, body.end.y - 1, SandWorld.M_RUBBLE)
		return
	w.fill_rect(body.position.x, body.position.y, 2, body.size.y, wall)
	w.fill_rect(body.end.x - 2, body.position.y, 2, body.size.y, wall)
	# Door: a gap in the left wall, 14 cells tall (characters are 32 cells; they duck in the art).
	var door_h := mini(body.size.y - 2, 16)
	w.fill_rect(body.position.x, body.end.y - door_h, 2, door_h, SandWorld.M_EMPTY)
	# Window in the right wall.
	w.fill_rect(body.end.x - 2, body.position.y + 3, 2, 3, SandWorld.M_EMPTY)
	# Pitched roof of wood, overhanging by two cells.
	for i in roof_h + 1:
		var y := r.position.y + i
		var inset := (roof_h - i) * (r.size.x / 2) / (roof_h + 1)
		w.fill_rect(r.position.x - 2 + inset, y, r.size.x + 4 - 2 * inset, 1, SandWorld.M_WOOD)
	w.fill_rect(body.position.x, body.position.y, body.size.x, 1, SandWorld.M_PLANK)


func _chapel(x: int, gy: int, cw: int) -> Rect2i:
	var hh := 34
	var r := Rect2i(x, gy - hh, cw, hh)
	w.fill_rect(x, gy - hh + 8, 3, hh - 8, SandWorld.M_BRICK)
	w.fill_rect(x + cw - 3, gy - hh + 8, 3, hh - 8, SandWorld.M_BRICK)
	w.fill_rect(x, gy - 18, 3, 18, SandWorld.M_EMPTY) # door
	w.fill_rect(x + cw - 3, gy - 26, 3, 5, SandWorld.M_EMPTY) # window
	w.fill_rect(x, gy - hh + 8, cw, 2, SandWorld.M_BRICK)
	for i in 8:
		var inset := (8 - i) * (cw / 2) / 9
		w.fill_rect(x + inset, gy - hh + i, cw - 2 * inset, 1, SandWorld.M_BRICK)
	# Steeple.
	w.fill_rect(x + cw / 2 - 2, gy - hh - 14, 4, 14, SandWorld.M_BRICK)
	w.fill_rect(x + cw / 2 - 1, gy - hh - 20, 2, 6, SandWorld.M_WOOD)
	w.fill_rect(x + cw / 2 - 3, gy - hh - 18, 6, 1, SandWorld.M_WOOD)
	# Holy water under the chapel, in a stone cistern.
	var cx := x + cw / 2
	var cy := gy + 26
	w.fill_rect(cx - 14, cy - 8, 28, 16, SandWorld.M_STONE)
	w.fill_rect(cx - 11, cy - 5, 22, 10, SandWorld.M_EMPTY)
	w.fill_rect(cx - 11, cy - 1, 22, 6, SandWorld.M_HOLY)
	return r


func _graveyard() -> void:
	var t: Dictionary = towns[0]
	var x0: int = t.rect.end.x + 12
	var gw: int = GEN.graveyard_width
	var gy := heights[x0 + gw / 2]
	graveyard = Rect2i(x0, gy - 12, gw, 36)
	# Iron-ish fence posts (stone) along the front.
	for x in range(x0, x0 + gw, 6):
		w.fill_rect(x, gy - 6, 1, 6, SandWorld.M_STONE)
	w.fill_rect(x0, gy - 6, gw, 1, SandWorld.M_STONE)
	var n: int = GEN.graves
	var step := (gw - 10) / n
	for i in n:
		var gx := x0 + 6 + i * step
		var depth := rng.randi_range(12, 18)
		# Tombstone: a small stone slab, a few leaning.
		var th := rng.randi_range(5, 8)
		var tomb := Rect2i(gx + 1, gy - th, 4, th)
		w.fill_rect(tomb.position.x, tomb.position.y, tomb.size.x, tomb.size.y, SandWorld.M_STONE)
		w.set_mat(tomb.position.x, tomb.position.y, SandWorld.M_EMPTY)
		w.set_mat(tomb.end.x - 1, tomb.position.y, SandWorld.M_EMPTY)
		tombstones.append(tomb)
		# Grave dirt above the coffin: loose, easy digging.
		w.fill_rect(gx, gy, 8, depth, SandWorld.M_DIRT)
		# Hollow coffin: a wood shell with bones inside.
		var cr := Rect2i(gx - 1, gy + depth, 10, 6)
		w.fill_rect(cr.position.x, cr.position.y, cr.size.x, cr.size.y, SandWorld.M_WOOD)
		w.fill_rect(cr.position.x + 1, cr.position.y + 1, cr.size.x - 2, cr.size.y - 2, SandWorld.M_EMPTY)
		w.fill_rect(cr.position.x + 2, cr.end.y - 2, cr.size.x - 4, 1, SandWorld.M_BONE)
		graves.append(Vector2i(cr.position.x + cr.size.x / 2, cr.position.y + cr.size.y / 2))


# ---------------------------------------------------------------- forest

func _trees() -> void:
	var x := 6
	var mid := width / 2
	while x < width - 6:
		x += rng.randi_range(GEN.tree_spacing[0], GEN.tree_spacing[1])
		if x >= width - 6 or _in_flat(x, 6) or absi(x - mid) < GEN.spawn_clearing:
			continue
		_tree(x, heights[x])


func _in_flat(x: int, pad: int) -> bool:
	for span in flat_spans:
		if x >= span[0] - pad and x < span[1] + pad:
			return true
	return false


func _tree(x: int, gy: int) -> void:
	var h := rng.randi_range(26, 48)
	var tw := 2 if h < 36 else 3
	w.fill_rect(x, gy - h, tw, h, SandWorld.M_WOOD)
	# Roots into the turf.
	w.set_mat(x - 1, gy - 1, SandWorld.M_WOOD)
	w.set_mat(x + tw, gy - 1, SandWorld.M_WOOD)
	# Canopy: a few overlapping leaf blobs, darker forest, sometimes a bare dead tree.
	if rng.randf() < 0.15:
		w.fill_rect(x - 5, gy - h + 8, 5, 1, SandWorld.M_WOOD)
		w.fill_rect(x + tw, gy - h + 12, 6, 1, SandWorld.M_WOOD)
		return
	var cy := gy - h
	var r := rng.randi_range(7, 11)
	w.paint_circle(x + tw / 2, cy, r, SandWorld.M_LEAVES, true)
	w.paint_circle(x + tw / 2 - r / 2 - 1, cy + 4, r - 2, SandWorld.M_LEAVES, true)
	w.paint_circle(x + tw / 2 + r / 2 + 1, cy + 4, r - 2, SandWorld.M_LEAVES, true)


func _critter_zones() -> void:
	var mid := width / 2
	var left_end: int = flat_spans[0][1] + 20
	var right_start: int = flat_spans[1][0] - 20
	for span in [[left_end, mid - 60], [mid + 60, right_start]]:
		if span[1] - span[0] < 40:
			continue
		var top := 1 << 30
		for x in range(span[0], span[1]):
			top = mini(top, heights[x])
		critter_zones.append(Rect2i(span[0], top - 50, span[1] - span[0], 50 + 40))
