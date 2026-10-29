class_name WorldGen
extends RefCounted
## Seeded world generation into a SandWorld. Same seed, same world.
## Fills the terrain column by column, then paints features (caves, liquid pockets, towns, graveyard) on top.
## Things actors must walk through (trees, bushes, tombstones, the cemetery fence, the back walls of homes)
## go into `scenery`, an image at cell resolution drawn just behind the sim, because every static sim
## material blocks actors. When Pixel Physics adds a walk-through trunk material (SandWorld.M_TRUNK) and
## makes LEAVES walk-through, the near trees move into the sim by themselves.

const GEN := {
	"surface_frac": 0.40, ## typical surface height as a fraction of world height
	"hill_amp": 34.0, ## cells of rolling hill height either way
	"hill_freq": 0.006,
	"grass_depth": 2,
	"earth_depth": 80, ## packed earth below the grass, before clay starts
	"clay_depth": 60, ## clay band thickness
	"bedrock_rows": 5,
	"dirt_patches": 70, ## loose soil blobs in the earth layer
	"shallow_caves": 3, ## small air pockets in the clay
	"caves": 6, ## winding caves in the stone
	"liquid_pockets": 3, ## small, deep, used sparingly
	"town_width": 290, ## cells
	"town_margin": 116, ## cells from the world edge to a town; the outer part is farmland
	"field_width": 96, ## cells of fields outside each town, on the side away from the forest
	"graveyard_gap": 14, ## cells between the left town and its graveyard
	"spawn_clearing": 40, ## no trees within this many cells of the necromancer's start
	"blend": 30, ## cells over which flattened town ground blends into the hills
}

## Homes are sized for adults: a human is 58 px (29 cells) tall.
const HOME := {
	"width": [40, 48], ## cells
	"wall_h": [36, 40], ## floor to ceiling, cells
	"roof_h": [10, 13],
	"gap": [10, 14], ## cells between buildings
	"door_h": 32,
	"wall": 2,
	"chimney_chance": 0.55,
}

## Building styles, picked per home from where it stands. footing: rows of stone at the foot of the walls.
const HOME_STYLES := [
	{"wall": SandWorld.M_PLANK, "roof": SandWorld.M_WOOD, "footing": 5},
	{"wall": SandWorld.M_WOOD, "roof": SandWorld.M_PLANK, "footing": 4},
	{"wall": SandWorld.M_PLANK, "roof": SandWorld.M_WOOD, "footing": 12},
	{"wall": SandWorld.M_CLAY, "roof": SandWorld.M_WOOD, "footing": 3},
]

const CHAPEL := {"width": 60, "wall_h": 46, "roof_h": 14, "steeple_h": 24, "door_h": 34, "wall": 3}

## Coffins hold a laid-out adult (about 52 px, 26 cells long).
const GRAVES := {"count": 6, "pitch": 38, "coffin": Vector2i(34, 8), "depth": [10, 15], "margin": 8,
	"shaft": 20, ## width of the loose grave dirt over each coffin
	"stone_h": [13, 18]}

## A forgotten catacomb gallery under the left forest: a taste of the deep.
const CATACOMB := {"size": Vector2i(90, 16), "depth": 250, "offset_x": 200}

const TREES := {
	"spacing": [12, 26], ## cells between trunks
	"height": [44, 80], ## cells
	"dead_chance": 0.12,
	"pine_chance": 0.3,
	"bush_chance": 0.45,
	"far_spacing": [8, 16], ## the darker row of trees further back
	"tuft_chance": 0.35, ## grass blades per surface column
	"sim_material": "M_TRUNK", ## when SandWorld has this constant, near trees go into the sim
}

## Scenery colours (a few tones each), matched to the sim's palette.
const PAL := {
	"bark": [Color8(0x4d, 0x32, 0x20), Color8(0x43, 0x2b, 0x1b), Color8(0x57, 0x3a, 0x26), Color8(0x3b, 0x26, 0x18)],
	"dead": [Color8(0x4a, 0x42, 0x3a), Color8(0x40, 0x39, 0x32), Color8(0x55, 0x4c, 0x43), Color8(0x36, 0x30, 0x2a)],
	"leaf": [Color8(0x2c, 0x3a, 0x1f), Color8(0x26, 0x33, 0x1a), Color8(0x33, 0x42, 0x25), Color8(0x1f, 0x2b, 0x15)],
	"leaf_lit": [Color8(0x3b, 0x4b, 0x27), Color8(0x42, 0x52, 0x2b), Color8(0x36, 0x46, 0x24), Color8(0x45, 0x55, 0x2e)],
	"pine": [Color8(0x1d, 0x2e, 0x24), Color8(0x19, 0x28, 0x1f), Color8(0x22, 0x35, 0x29), Color8(0x15, 0x22, 0x1a)],
	"far": [Color8(0x1a, 0x1f, 0x19), Color8(0x17, 0x1c, 0x17), Color8(0x1d, 0x23, 0x1c), Color8(0x15, 0x19, 0x14)],
	"grass": [Color8(0x3d, 0x4a, 0x26), Color8(0x45, 0x53, 0x2c), Color8(0x4b, 0x56, 0x2e), Color8(0x36, 0x42, 0x1f)],
	"stone": [Color8(0x55, 0x54, 0x5c), Color8(0x4b, 0x4a, 0x52), Color8(0x5f, 0x5e, 0x66), Color8(0x43, 0x42, 0x49)],
	"moss": [Color8(0x3a, 0x48, 0x28), Color8(0x33, 0x40, 0x22)],
	"iron": [Color8(0x22, 0x21, 0x26), Color8(0x1c, 0x1b, 0x20), Color8(0x29, 0x28, 0x2e), Color8(0x18, 0x17, 0x1b)],
	"backwall": [Color8(0x2a, 0x1d, 0x14), Color8(0x25, 0x1a, 0x12), Color8(0x30, 0x22, 0x17), Color8(0x21, 0x17, 0x10)],
	"seam": [Color8(0x14, 0x0e, 0x0a)],
	"blanket": [Color8(0x5a, 0x2a, 0x26), Color8(0x4e, 0x24, 0x21)],
	"hearth": [Color8(0x3a, 0x34, 0x33), Color8(0x30, 0x2b, 0x2a)],
	"ember": [Color8(0x9a, 0x45, 0x1c), Color8(0x7a, 0x30, 0x16), Color8(0xc4, 0x5c, 0x22)],
	"chapel_wall": [Color8(0x2e, 0x2a, 0x2c), Color8(0x29, 0x25, 0x27), Color8(0x33, 0x2f, 0x31), Color8(0x25, 0x21, 0x23)],
	"glass": [Color8(0x6a, 0x4a, 0x2a), Color8(0x3a, 0x4a, 0x5a), Color8(0x5a, 0x2a, 0x2a), Color8(0x8a, 0x6a, 0x3a)],
	"cloth": [Color8(0x5e, 0x55, 0x48), Color8(0x52, 0x4a, 0x3e)],
	"crop": [Color8(0x6a, 0x5e, 0x30), Color8(0x5a, 0x52, 0x2a), Color8(0x4e, 0x55, 0x2a), Color8(0x72, 0x66, 0x38)],
	"daub": [Color8(0x4a, 0x42, 0x34), Color8(0x45, 0x3d, 0x30), Color8(0x50, 0x47, 0x38), Color8(0x40, 0x39, 0x2d)],
	"rust": [Color8(0x5a, 0x34, 0x22), Color8(0x4a, 0x2c, 0x1e), Color8(0x6a, 0x3e, 0x26)],
}

var w: SandWorld
var width := 0
var height := 0
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var heights := PackedInt32Array() ## first solid (grass) row per column
var flat_spans: Array = [] ## [x0, x1] spans kept flat for towns and the graveyard
var forest_mid := 0 ## middle of the forest between the towns: the necromancer starts here
var scenery: Image ## walk-through scenery at cell resolution, drawn behind the sim
var trees_in_sim := false
var trunk_mat := -1

## {name, rect(cells), side, door_side, ground, homes:[{id, rect(cells), residents, alive, door_side}], chapel, torches}
var towns: Array = []
var graveyard := Rect2i()
var graves: Array = [] ## coffin centres in cells
var coffins: Array = [] ## Rect2i in cells
var tombstones: Array = [] ## Rect2i in cells (scenery)
var critter_zones: Array = [] ## Rect2i in cells
var battlefield := Rect2i() ## the old battlefield teaser, in cells
var catacomb := Rect2i() ## the forgotten catacomb teaser deep in the stone, in cells
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
	scenery = Image.create(width, height, false, Image.FORMAT_RGBA8)
	if ClassDB.class_has_integer_constant(&"SandWorld", StringName(TREES.sim_material)):
		trees_in_sim = true
		trunk_mat = ClassDB.class_get_integer_constant(&"SandWorld", StringName(TREES.sim_material))
	_plan_flat_spans()
	_heightmap()
	_terrain()
	_dirt_patches()
	_caves()
	_liquid_pockets()
	_far_trees()
	_towns()
	_graveyard()
	_fields()
	_battlefield()
	_catacomb()
	_trees()
	_grass_tufts()
	spawn_cell = Vector2i(forest_mid, heights[forest_mid])
	_critter_zones()


# ---------------------------------------------------------------- terrain

func _graveyard_width() -> int:
	return GRAVES.margin * 2 + GRAVES.count * GRAVES.pitch


func _plan_flat_spans() -> void:
	var m: int = GEN.town_margin
	var tw: int = GEN.town_width
	# Left town, its graveyard just east of it (toward the forest); right town alone.
	var f: int = GEN.field_width
	flat_spans = [[m - f, m + tw + GEN.graveyard_gap + _graveyard_width()], [width - m - tw, width - m + f]]
	forest_mid = (int(flat_spans[0][1]) + int(flat_spans[1][0])) / 2


func _heightmap() -> void:
	heights.resize(width)
	var base := height * float(GEN.surface_frac)
	var raw := PackedFloat32Array()
	raw.resize(width)
	for x in width:
		raw[x] = base + noise.get_noise_1d(x) * GEN.hill_amp
	# Flatten town spans to their mean height and blend the edges.
	var bl: int = GEN.blend
	for span in flat_spans:
		var avg := 0.0
		for x in range(span[0], span[1]):
			avg += raw[x]
		avg /= float(span[1] - span[0])
		for x in range(maxi(0, span[0] - bl), mini(width, span[1] + bl)):
			var t := 1.0
			if x < span[0]:
				t = 1.0 - float(span[0] - x) / bl
			elif x >= span[1]:
				t = 1.0 - float(x - span[1] + 1) / bl
			t = smoothstep(0.0, 1.0, t)
			raw[x] = lerpf(raw[x], avg, t)
	for x in width:
		heights[x] = int(round(raw[x]))


func _terrain() -> void:
	var br: int = GEN.bedrock_rows
	for x in width:
		var top := heights[x]
		var g: int = GEN.grass_depth
		var e_end := top + g + GEN.earth_depth + int(noise.get_noise_2d(x, 500) * 10.0)
		var c_end := e_end + GEN.clay_depth + int(noise.get_noise_2d(x, 900) * 14.0)
		var b_start := height - br - int(absf(noise.get_noise_2d(x * 3, 1300)) * 6.0)
		w.fill_rect(x, top, 1, g, SandWorld.M_GRASS)
		w.fill_rect(x, top + g, 1, e_end - top - g, SandWorld.M_EARTH)
		w.fill_rect(x, e_end, 1, c_end - e_end, SandWorld.M_CLAY)
		w.fill_rect(x, c_end, 1, b_start - c_end, SandWorld.M_STONE)
		w.fill_rect(x, b_start, 1, height - b_start, SandWorld.M_BEDROCK)


func _dirt_patches() -> void:
	# Loose soil in the packed earth: easy digging, and it slumps when opened.
	for i in GEN.dirt_patches:
		var x := rng.randi_range(4, width - 5)
		var r := rng.randi_range(3, 7)
		var y := heights[x] + rng.randi_range(r + 4, GEN.earth_depth - r)
		w.paint_circle(x, y, r, SandWorld.M_DIRT, false)
	# Stone and clay lenses for texture.
	for i in 40:
		var x := rng.randi_range(4, width - 5)
		var y := heights[x] + rng.randi_range(60, 170)
		w.paint_circle(x, y, rng.randi_range(3, 6), SandWorld.M_STONE if i % 2 else SandWorld.M_CLAY, false)


func _caves() -> void:
	# A few small pockets in the clay, then winding caves in the stone.
	for i in GEN.shallow_caves:
		var x := rng.randi_range(120, width - 160)
		var y := heights[x] + GEN.earth_depth + rng.randi_range(14, 40)
		if _in_flat(x, 40):
			continue
		for s in rng.randi_range(3, 6):
			w.paint_circle(x + s * 5, y + rng.randi_range(-2, 2), rng.randi_range(4, 7), SandWorld.M_EMPTY, false)
	for i in GEN.caves:
		var x := float(rng.randi_range(100, width - 100))
		var y := float(heights[int(x)] + rng.randi_range(170, 330))
		y = minf(y, height - 40)
		var ang := rng.randf_range(-0.6, 0.6) + (PI if rng.randf() < 0.5 else 0.0)
		var r := rng.randf_range(9.0, 14.0)
		for s in rng.randi_range(14, 24):
			w.paint_circle(int(x), int(y), int(r), SandWorld.M_EMPTY, false)
			w.paint_circle(int(x), int(y + r), 2, SandWorld.M_RUBBLE, false) # rubble on the cave floor
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


# ---------------------------------------------------------------- scenery helpers

func _hash(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)


func _tone(pal: Array, x: int, y: int) -> Color:
	return pal[_hash(x, y) % pal.size()]


func _sc(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < width and y < height:
		scenery.set_pixel(x, y, c)


func _sc_rect(x: int, y: int, ww: int, hh: int, pal: Array) -> void:
	for yy in range(y, y + hh):
		for xx in range(x, x + ww):
			_sc(xx, yy, _tone(pal, xx, yy))


func _sc_clear(r: Rect2i) -> void:
	var c := r.intersection(Rect2i(0, 0, width, height))
	if c.has_area():
		scenery.fill_rect(c, Color(0, 0, 0, 0))


# ---------------------------------------------------------------- towns

## Roof height of a home, fixed by where it stands so a rebuild matches the original.
static func roof_h_at(x: int) -> int:
	return HOME.roof_h[0] + posmod(x * 7, HOME.roof_h[1] - HOME.roof_h[0] + 1)


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
		var end := x0 + tw - 8
		var gy := heights[x0 + tw / 2]
		var door_side: int = -s.side # doors face the forest
		var town := {"name": s.name, "side": s.side, "door_side": door_side, "ground": gy,
			"rect": Rect2i(x0, gy - 90, tw, 90), "homes": [], "torches": [], "chapel": Rect2i()}
		var x := x0 + 8
		var built := 0
		var chapel_done: bool = not s.chapel
		while true:
			if not chapel_done and built == 1:
				if x + CHAPEL.width > end:
					break
				town.chapel = _chapel(x, gy, door_side)
				chapel_done = true
				x += CHAPEL.width
			else:
				var hw := rng.randi_range(HOME.width[0], HOME.width[1])
				if x + hw > end:
					break
				var hh := rng.randi_range(HOME.wall_h[0], HOME.wall_h[1]) + roof_h_at(x)
				var rect := Rect2i(x, gy - hh, hw, hh)
				build_home(rect, 0, door_side)
				var n := rng.randi_range(1, 3)
				town.homes.append({"id": next_id, "rect": rect, "residents": n, "alive": n, "door_side": door_side})
				next_id += 1
				built += 1
				x += hw
			var gap := rng.randi_range(HOME.gap[0], HOME.gap[1])
			if x + gap / 2 < x0 + tw:
				town.torches.append(Vector2i(x + gap / 2, gy - 12))
			x += gap
		towns.append(town)


## A poor timber home: stone footing, plank walls, a door toward the forest, a window, a wooden roof,
## a plank floor, and a back wall with a bed, table and hearth (scenery). `decay`: 0 lived in,
## 1 emptied and running down, 2 a ruin.
func build_home(r: Rect2i, decay: int, door_side: int) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = r.position.x * 7919 + r.position.y * 31 + decay * 104729
	var wall: int = HOME.wall
	var gy := r.end.y
	var roof_h := roof_h_at(r.position.x)
	var by := r.position.y + roof_h # top of the walls
	var has_chimney := _hash(r.position.x, r.position.y) % 100 < int(HOME.chimney_chance * 100.0)
	# Each home is built a little differently: plank, dark timber or wattle-and-daub, higher or lower footings.
	var v := _hash(r.position.x + 11, r.position.y) % HOME_STYLES.size()
	var style: Dictionary = HOME_STYLES[v]
	var wall_mat: int = style.wall
	var roof_mat: int = style.roof
	# Clear the space first so a rebuild never leaves rubble inside.
	var clear := Rect2i(r.position.x - 3, r.position.y - 8, r.size.x + 6, r.size.y + 8)
	w.fill_rect(clear.position.x, clear.position.y, clear.size.x, clear.size.y, SandWorld.M_EMPTY)
	_sc_clear(clear)
	var keep_wall: float = [1.0, 0.8, 0.45][decay]
	var keep_roof: float = [1.0, 0.7, 0.2][decay]
	w.fill_rect(r.position.x, gy, r.size.x, 1, SandWorld.M_PLANK) # floor
	# Walls: stone footing, plank above. Door gap on the forest side, window on the other.
	var door_x := r.end.x - wall if door_side > 0 else r.position.x
	var win_x := r.position.x if door_side > 0 else r.end.x - wall
	var foot := gy - int(style.footing)
	for side_x in [r.position.x, r.end.x - wall]:
		for y in range(by, gy):
			if side_x == door_x and y >= gy - int(HOME.door_h):
				continue
			if side_x == win_x and y >= by + 7 and y < by + 13:
				continue
			for dx in wall:
				if y >= foot and decay < 2:
					w.set_mat(side_x + dx, y, SandWorld.M_STONE)
				elif rr.randf() < keep_wall:
					w.set_mat(side_x + dx, y, SandWorld.M_STONE if y >= foot else wall_mat)
	if decay < 2:
		w.fill_rect(r.position.x, by, r.size.x, 1, SandWorld.M_PLANK) # ceiling plate
	# Pitched roof overhanging by three cells; a ruin keeps only scraps of it.
	var cx := r.position.x + r.size.x / 2
	for i in roof_h:
		var y := r.position.y + i
		var half := int(float(i + 1) / roof_h * (r.size.x / 2 + 3))
		for x in range(cx - half, cx + half):
			if rr.randf() < keep_roof or (decay < 2 and i == roof_h - 1):
				w.set_mat(x, y, roof_mat)
	# Inside, mirrored so the bed is always on the far wall from the door: offsets from the far wall.
	var inner := Rect2i(r.position.x + wall, by + 1, r.size.x - 2 * wall, gy - by - 1)
	var hearth_o := inner.size.x - 11
	if has_chimney and decay < 2:
		var chx := _mirror(inner, door_side, hearth_o + 3, 4)
		w.fill_rect(chx, r.position.y - 5 + roof_h / 3, 4, roof_h - roof_h / 3 + 5, SandWorld.M_BRICK)
	if decay == 2:
		for x in range(inner.position.x, inner.end.x):
			if rr.randf() < 0.25:
				w.set_mat(x, gy - 1, SandWorld.M_RUBBLE)
	_home_backdrop(inner, decay, door_side, has_chimney, hearth_o, rr, v)


## One pixel of a home's back wall, by building style: brown boards, dark timber, boards over a stone
## footing, or grimy daub between timber framing.
func _backwall(style: int, dx: int, y: int, gy: int, board: int, seam: bool) -> Color:
	var boards: Color = PAL.seam[0] if seam else PAL.backwall[(board + y / 9) % PAL.backwall.size()]
	match style:
		1:
			return boards.darkened(0.3)
		2:
			if y >= gy - 12:
				var course := (gy - y) / 3
				var brick := (dx + (course % 2) * 3) % 6 == 0 or (gy - y) % 3 == 0
				return PAL.seam[0] if brick else _tone(PAL.stone, dx, y).darkened(0.5)
			return boards
		3:
			var frame := dx % 12 == 0 or dx % 12 == 1 or absi(y - (gy - 18)) < 1 or (dx % 12) == (gy - y) % 12
			return _tone(PAL.bark, dx, y).darkened(0.2) if frame else _tone(PAL.daub, dx, y).darkened(0.25)
	return boards


## World x of something `size` wide at offset `o` from the home's far wall (the wall without the door).
func _mirror(inner: Rect2i, door_side: int, o: int, size: int) -> int:
	return inner.position.x + o if door_side > 0 else inner.end.x - o - size


## The inside of a home seen from the front: board back wall, bed, table, hearth. Scenery, so residents
## walk in front of it. Emptied homes lose boards and their fire; ruins keep only a broken back wall.
func _home_backdrop(inner: Rect2i, decay: int, door_side: int, hearth: bool, hearth_o: int, rr: RandomNumberGenerator, style := 0) -> void:
	var miss: float = [0.0, 0.15, 0.5][decay]
	var x0 := inner.position.x
	var y0 := inner.position.y
	var gy := inner.end.y
	var board := -1
	var gone_from := 0
	for x in range(x0, inner.end.x):
		if (x - x0) % 3 == 0:
			board += 1
			gone_from = y0 + rr.randi_range(0, inner.size.y) if rr.randf() < miss else gy + 1
		var seam := (x - x0) % 3 == 2
		for y in range(y0, gy):
			if y >= gone_from:
				continue
			_sc(x, y, _backwall(style, x - x0, y, gy, board, seam).darkened(0.1 * decay))
	if decay == 2:
		return
	# Bed on the far wall: frame, blanket, pillow.
	var bx := _mirror(inner, door_side, 1, 14)
	_sc_rect(bx, gy - 4, 14, 1, PAL.bark)
	_sc_rect(bx, gy - 6, 14, 2, PAL.blanket if decay == 0 else PAL.cloth)
	_sc_rect(_mirror(inner, door_side, 1, 4), gy - 7, 4, 1, PAL.cloth)
	_sc_rect(bx, gy - 3, 1, 3, PAL.bark)
	_sc_rect(bx + 13, gy - 3, 1, 3, PAL.bark)
	# Table in the middle, a crooked portrait of someone's dear departed above it.
	var tx := _mirror(inner, door_side, 16, 9)
	_sc_rect(tx, gy - 8, 9, 1, PAL.bark)
	_sc_rect(tx + 1, gy - 7, 1, 7, PAL.bark)
	_sc_rect(tx + 7, gy - 7, 1, 7, PAL.bark)
	_sc_rect(tx + 2, y0 + 6, 5, 6, PAL.bark)
	_sc_rect(tx + 3, y0 + 7, 3, 4, PAL.cloth)
	# Hearth under the chimney; embers only while someone lives here.
	if hearth:
		var hx := _mirror(inner, door_side, hearth_o, 10)
		_sc_rect(hx, gy - 12, 10, 12, PAL.hearth)
		_sc_rect(hx + 2, gy - 7, 6, 7, PAL.seam)
		if decay == 0:
			_sc_rect(hx + 3, gy - 2, 4, 2, PAL.ember)


func _chapel(x: int, gy: int, door_side: int) -> Rect2i:
	var cw: int = CHAPEL.width
	var wall: int = CHAPEL.wall
	var wh: int = CHAPEL.wall_h
	var rh: int = CHAPEL.roof_h
	var r := Rect2i(x, gy - wh - rh, cw, wh + rh)
	var by := gy - wh
	var cx := x + cw / 2
	# Inside first (scenery): dim stone, a stained window, an altar with a rusty cross.
	_sc_rect(x + wall, by + 2, cw - 2 * wall, wh - 2, PAL.chapel_wall)
	_sc_rect(cx - 6, by + 8, 12, 16, PAL.seam)
	for yy in range(by + 9, by + 23):
		for xx in range(cx - 5, cx + 5):
			_sc(xx, yy, PAL.glass[posmod((xx - cx) / 3 + (yy - by) / 4, PAL.glass.size())].darkened(0.25))
	_sc_rect(cx - 9, gy - 8, 18, 8, PAL.stone)
	_sc_rect(cx - 10, gy - 9, 20, 1, PAL.cloth)
	_sc_rect(cx - 1, gy - 16, 2, 7, PAL.rust)
	_sc_rect(cx - 3, gy - 14, 6, 1, PAL.rust)
	# Stone and brick shell.
	w.fill_rect(x, gy, cw, 1, SandWorld.M_STONE) # flagstone floor
	var door_x := x + cw - wall if door_side > 0 else x
	var win_x := x if door_side > 0 else x + cw - wall
	for sx in [x, x + cw - wall]:
		w.fill_rect(sx, by, wall, wh, SandWorld.M_BRICK)
		w.fill_rect(sx, gy - 6, wall, 6, SandWorld.M_STONE)
	w.fill_rect(door_x, gy - int(CHAPEL.door_h), wall, CHAPEL.door_h, SandWorld.M_EMPTY)
	w.fill_rect(win_x, by + 8, wall, 14, SandWorld.M_EMPTY)
	w.fill_rect(x, by, cw, 2, SandWorld.M_BRICK)
	for i in rh:
		var half := int(float(i + 1) / rh * (cw / 2 + 3))
		w.fill_rect(cx - half, r.position.y + i, half * 2, 1, SandWorld.M_STONE)
	# Steeple with a bell window and a wooden cross.
	var st: int = CHAPEL.steeple_h
	w.fill_rect(cx - 3, r.position.y - st, 6, st, SandWorld.M_BRICK)
	w.fill_rect(cx - 2, r.position.y - st + 4, 4, 5, SandWorld.M_EMPTY)
	w.fill_rect(cx - 1, r.position.y - st - 9, 2, 9, SandWorld.M_WOOD)
	w.fill_rect(cx - 4, r.position.y - st - 7, 8, 2, SandWorld.M_WOOD)
	# Holy water under the chapel, in a stone cistern (stone holds liquids).
	var cy := gy + 24
	w.fill_rect(cx - 16, cy - 9, 32, 18, SandWorld.M_STONE)
	w.fill_rect(cx - 13, cy - 6, 26, 12, SandWorld.M_EMPTY)
	w.fill_rect(cx - 13, cy - 1, 26, 7, SandWorld.M_HOLY)
	return r


func _graveyard() -> void:
	var t: Dictionary = towns[0]
	var x0: int = t.rect.end.x + GEN.graveyard_gap
	var gw := _graveyard_width()
	var gy := heights[x0 + gw / 2]
	# Wrought-iron fence behind the plot (scenery), stone gateposts on the town side.
	for x in range(x0 + 10, x0 + gw):
		if (x - x0) % 5 == 0:
			_sc_rect(x, gy - 13, 1, 13, PAL.iron)
			_sc(x, gy - 14, PAL.iron[2])
		_sc(x, gy - 11, PAL.iron[0])
		_sc(x, gy - 4, PAL.iron[1])
	for gx in [x0, x0 + 9]:
		_sc_rect(gx, gy - 16, 2, 16, PAL.stone)
	var deepest := gy
	for i in GRAVES.count:
		var gx: int = x0 + GRAVES.margin + i * GRAVES.pitch
		var cs: Vector2i = GRAVES.coffin
		var depth := rng.randi_range(GRAVES.depth[0], GRAVES.depth[1])
		_tombstone(gx + (1 if i % 2 == 0 else cs.x - 9), gy - 1)
		# Grave dirt over the coffin: loose, easy digging, with a low mound.
		var sh: int = GRAVES.shaft
		w.fill_rect(gx + (cs.x - sh) / 2, gy, sh, depth, SandWorld.M_DIRT)
		w.fill_rect(gx + (cs.x - sh) / 2 + 2, gy - 1, sh - 4, 1, SandWorld.M_DIRT)
		# Hollow coffin: a wood shell, big enough for an adult laid out.
		var cr := Rect2i(gx, gy + depth, cs.x, cs.y)
		w.fill_rect(cr.position.x, cr.position.y, cr.size.x, cr.size.y, SandWorld.M_WOOD)
		w.fill_rect(cr.position.x + 1, cr.position.y + 1, cr.size.x - 2, cr.size.y - 2, SandWorld.M_EMPTY)
		coffins.append(cr)
		graves.append(Vector2i(cr.position.x + cr.size.x / 2, cr.position.y + cr.size.y / 2))
		deepest = maxi(deepest, cr.end.y)
	graveyard = Rect2i(x0, gy - 16, gw, deepest - (gy - 16) + 2)
	# A dead tree watches over the plot.
	_tree_dead(x0 + gw - 4, gy, rng.randi_range(40, 52), false)


## A headstone on the ground line (scenery): rounded slab, carved cross slab, or wooden cross.
func _tombstone(x: int, base_y: int) -> void:
	var kind := rng.randi_range(0, 2)
	var th := rng.randi_range(GRAVES.stone_h[0], GRAVES.stone_h[1])
	var lean := rng.randi_range(-2, 2) if rng.randf() < 0.4 else 0
	if kind == 2:
		_sc_rect(x + 3, base_y - th, 2, th + 1, PAL.dead)
		_sc_rect(x, base_y - th + 4, 8, 2, PAL.dead)
		tombstones.append(Rect2i(x, base_y - th, 8, th + 1))
		return
	var ww := 8
	for yy in range(0, th + 1):
		var y := base_y - yy
		var off := (lean * yy) / th
		var inset := 0
		if kind == 0 and yy >= th - 2:
			inset = yy - (th - 3)
		for xx in range(inset, ww - inset):
			var c := _tone(PAL.stone, x + xx, y)
			if yy < 4 and _hash(x + xx, y) % 3 == 0:
				c = PAL.moss[_hash(x, y + xx) % 2]
			if xx == ww - 1 - inset or yy == th:
				c = c.darkened(0.2) # shaded edge
			var cross_v := (xx == 3 or xx == 4) and yy >= th - 10 and yy <= th - 3
			var cross_h := yy == th - 5 and xx >= 1 and xx <= 6
			if kind == 1 and (cross_v or cross_h):
				c = c.darkened(0.4)
			_sc(x + xx + off, y, c)
	tombstones.append(Rect2i(x - 2, base_y - th, ww + 4, th + 1))


# ---------------------------------------------------------------- fields

## Farmland on each town's far side from the forest (where Bodies and Souls sends farmers to work):
## tilled soil with rows of sorry crops, fence posts and a scarecrow; Gallowmere keeps its gallows there.
func _fields() -> void:
	var f: int = GEN.field_width
	for t in towns:
		var r: Rect2i = t.rect
		var x0: int = r.position.x - f if t.side < 0 else r.end.x
		var gy: int = t.ground
		var fr := Rect2i(x0 + 4, gy - 12, f - 8, 14)
		if t.side < 0 and t.name == "Gallowmere":
			_gallows(x0 + 4, gy)
			fr = Rect2i(x0 + 26, gy - 12, f - 30, 14)
		t["fields"] = fr
		w.fill_rect(fr.position.x, gy, fr.size.x, 2, SandWorld.M_DIRT) # tilled soil
		for x in range(fr.position.x + 2, fr.end.x - 2):
			var k := (x - fr.position.x) % 4
			if k == 0:
				var ph := 3 + _hash(x, gy) % 5
				for y in ph:
					_sc(x, gy - 1 - y, _tone(PAL.crop, x, y))
				_sc(x - 1, gy - ph, PAL.crop[0])
				_sc(x + 1, gy - ph + 1, PAL.crop[2])
		for px in [fr.position.x, fr.end.x - 1]:
			_sc_rect(px, gy - 7, 1, 7, PAL.bark)
		for x in range(fr.position.x, fr.end.x):
			_sc(x, gy - 5, _tone(PAL.bark, x, gy))
		# A scarecrow in a rag coat.
		var sx := fr.position.x + fr.size.x / 2
		_sc_rect(sx, gy - 20, 1, 20, PAL.bark)
		_sc_rect(sx - 5, gy - 16, 11, 1, PAL.bark)
		_sc_rect(sx - 2, gy - 16, 5, 7, PAL.cloth)
		_sc_rect(sx - 1, gy - 20, 3, 3, PAL.crop)
		_sc_rect(sx - 2, gy - 21, 5, 1, PAL.dead)


## Gallowmere's gallows: two posts, a beam, a dangling rope. Scenery.
func _gallows(x: int, gy: int) -> void:
	_sc_rect(x, gy - 9, 18, 2, PAL.bark) # platform
	_sc_rect(x + 1, gy - 7, 1, 7, PAL.bark)
	_sc_rect(x + 16, gy - 7, 1, 7, PAL.bark)
	_sc_rect(x + 2, gy - 34, 2, 25, PAL.bark)
	_sc_rect(x + 2, gy - 34, 14, 2, PAL.bark)
	_sc(x + 5, gy - 31, PAL.bark[0])
	_sc(x + 6, gy - 32, PAL.bark[0])
	_sc_rect(x + 13, gy - 32, 1, 8, PAL.cloth)
	_sc_rect(x + 12, gy - 24, 3, 2, PAL.cloth)


# ---------------------------------------------------------------- old battlefield teaser

## Rusted pikes and a torn banner on a rise in the right-hand forest, with old bones in the soil beneath.
func _battlefield() -> void:
	var x0 := forest_mid + 90
	var x1 := mini(x0 + 90, int(flat_spans[1][0]) - int(GEN.blend) - 10)
	if x1 - x0 < 40:
		return
	var top := 1 << 30
	for x in range(x0, x1):
		top = mini(top, heights[x])
	battlefield = Rect2i(x0, top - 30, x1 - x0, 70)
	for i in 6:
		var x := rng.randi_range(x0 + 4, x1 - 4)
		var gy := heights[x]
		var lean := rng.randi_range(-3, 3)
		var ph := rng.randi_range(12, 20)
		for k in ph:
			_sc(x + (lean * k) / ph, gy - k, _tone(PAL.dead, x, gy - k))
		_sc(x + lean, gy - ph, PAL.rust[2])
		_sc(x + lean, gy - ph - 1, PAL.rust[0])
		if i == 2:
			_sc_rect(x + lean + 1, gy - ph, 6, 4, PAL.blanket)
			_sc_rect(x + lean + 1, gy - ph + 4, 3, 2, PAL.blanket)
	for i in 8:
		var x := rng.randi_range(x0, x1)
		var y := heights[x] + rng.randi_range(6, 26)
		w.fill_rect(x, y, rng.randi_range(4, 7), 1, SandWorld.M_BONE)
		w.paint_circle(x + 2, y + 2, 2, SandWorld.M_BONEBIT, false)


## A teaser of the deep: a forgotten catacomb gallery in the stone under the left forest. Brick shell,
## bones heaped on the floor and laid in wall niches, one end caved in.
func _catacomb() -> void:
	var cw: int = CATACOMB.size.x
	var ch: int = CATACOMB.size.y
	var x := forest_mid - CATACOMB.offset_x - cw / 2
	var y := heights[x + cw / 2] + CATACOMB.depth
	catacomb = Rect2i(x, y, cw, ch)
	w.fill_rect(x - 3, y - 3, cw + 6, ch + 6, SandWorld.M_BRICK)
	w.fill_rect(x, y, cw, ch, SandWorld.M_EMPTY)
	# Niches in the back wall are scenery-dark; bones lie in shelves cut into the brick above the floor.
	for nx in range(x + 4, x + cw - 10, 12):
		w.fill_rect(nx, y + 3, 8, 3, SandWorld.M_EMPTY)
		w.fill_rect(nx + 1, y + 5, 6, 1, SandWorld.M_BONE)
	_sc_rect(x, y, cw, ch, PAL.chapel_wall)
	for i in 10:
		w.paint_circle(rng.randi_range(x + 4, x + cw - 4), y + ch - 1, rng.randi_range(1, 3), SandWorld.M_BONEBIT, false)
	w.fill_rect(x, y + ch, cw, 1, SandWorld.M_BRICK)
	# The far end has caved in.
	w.paint_circle(x + cw - 6, y + ch / 2, 9, SandWorld.M_RUBBLE, false)


# ---------------------------------------------------------------- forest

func _in_flat(x: int, pad: int) -> bool:
	for span in flat_spans:
		if x >= span[0] - pad and x < span[1] + pad:
			return true
	return false


## A darker row of trees further back, always scenery: depth for the forest silhouette.
func _far_trees() -> void:
	var x := 0
	while true:
		x += rng.randi_range(TREES.far_spacing[0], TREES.far_spacing[1])
		if x >= width - 2:
			break
		var gy := heights[x] + 2
		var h := rng.randi_range(40, 70)
		_sc_rect(x, gy - h, 2, h, [PAL.far[3]])
		if rng.randf() < 0.5:
			for t in 5:
				var half := 3 + t * 3
				_sc_rect(x + 1 - half, gy - h + t * 8, half * 2, 9, PAL.far)
		else:
			_blob(x + 1, gy - h + 6, rng.randi_range(9, 14), PAL.far, PAL.far, false)


func _trees() -> void:
	var x := 6
	var mid := forest_mid
	while x < width - 6:
		x += rng.randi_range(TREES.spacing[0], TREES.spacing[1])
		if x >= width - 6 or _in_flat(x, 8) or absi(x - mid) < GEN.spawn_clearing:
			continue
		var gy := heights[x]
		var h := rng.randi_range(TREES.height[0], TREES.height[1])
		var roll := rng.randf()
		if roll < TREES.dead_chance:
			_tree_dead(x, gy, h, trees_in_sim)
		elif roll < TREES.dead_chance + TREES.pine_chance:
			_tree_pine(x, gy, h, trees_in_sim)
		else:
			_tree_oak(x, gy, h, trees_in_sim)
		if rng.randf() < TREES.bush_chance:
			var bx := x + rng.randi_range(5, 10) * (1 if rng.randf() < 0.5 else -1)
			if bx > 4 and bx < width - 4 and not _in_flat(bx, 4) and absi(bx - mid) >= GEN.spawn_clearing:
				_blob(bx, heights[bx] - 2, rng.randi_range(3, 5), PAL.leaf, PAL.leaf_lit, trees_in_sim)


func _wood(x: int, y: int, pal: Array, in_sim: bool) -> void:
	if in_sim:
		if w.in_bounds(x, y) and w.is_empty(x, y):
			w.set_mat(x, y, trunk_mat)
	else:
		_sc(x, y, _tone(pal, x, y))


## A trunk rooted a few cells into the ground (hidden behind the turf), flared at the foot.
func _trunk(x: int, gy: int, h: int, tw: int, pal: Array, in_sim: bool) -> void:
	for k in h + 3:
		var y := gy + 3 - k
		var flare := 1 if k < 5 else 0
		var ww := tw + 2 * flare if k < 5 else (tw if k < h * 2 / 3 else maxi(1, tw - 1))
		for dx in ww:
			_wood(x - flare + dx, y, pal, in_sim)


func _branch(x: int, y: int, dir: int, length: int, rise: int, pal: Array, in_sim: bool) -> Vector2i:
	var p := Vector2i(x, y)
	for k in length:
		p = Vector2i(x + dir * k, y - (k * rise) / length)
		_wood(p.x, p.y, pal, in_sim)
	return p


## A leafy blob with a ragged edge, lighter on its upper left. Into the sim as LEAVES when trees are.
func _blob(cx: int, cy: int, r: int, pal: Array, lit: Array, in_sim: bool) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy > r * r - (_hash(x, y) % (r + 1)):
				continue
			if in_sim:
				if w.in_bounds(x, y) and w.is_empty(x, y):
					w.set_mat(x, y, SandWorld.M_LEAVES)
				continue
			var light := (-dx - dy * 1.5) / float(r)
			var c := _tone(lit if light > 0.6 else pal, x, y)
			if light < -0.9:
				c = c.darkened(0.25)
			_sc(x, y, c)


func _tree_oak(x: int, gy: int, h: int, in_sim: bool) -> void:
	var tw := 3 if h > 60 else 2
	_trunk(x, gy, h, tw, PAL.bark, in_sim)
	var top := gy - h
	var r := rng.randi_range(10, 14)
	var crown := Vector2i(x + tw / 2, top + r / 2) # canopy centre, low enough to swallow the trunk's top
	# Branches fork out under the crown and end in their own clumps.
	var ends: Array = []
	for b in rng.randi_range(2, 3):
		var by := top + r + rng.randi_range(0, maxi(2, h / 5))
		var dir := -1 if b % 2 == 0 else 1
		ends.append(_branch(x + (tw if dir > 0 else -1), by, dir, rng.randi_range(7, 12), rng.randi_range(5, 9), PAL.bark, in_sim))
	# A crown of overlapping clumps: darker ones first (behind), lit ones on top.
	for k in rng.randi_range(4, 6):
		var off := Vector2i(rng.randi_range(-r, r), rng.randi_range(-r / 2, r / 2))
		_blob(crown.x + off.x, crown.y + off.y + 2, r - rng.randi_range(3, 6), PAL.leaf, PAL.leaf, in_sim)
	for e in ends:
		_blob(e.x, e.y - 2, r - rng.randi_range(3, 5), PAL.leaf, PAL.leaf_lit, in_sim)
	_blob(crown.x, crown.y - r / 3, r, PAL.leaf, PAL.leaf_lit, in_sim)


func _tree_pine(x: int, gy: int, h: int, in_sim: bool) -> void:
	_trunk(x, gy, h, 2, PAL.bark, in_sim)
	var top := gy - h - 4
	var tiers := maxi(4, h / 10)
	for t in tiers:
		var ty := top + t * 7
		var half := 3 + t * 2
		for k in 9:
			var span := half * k / 8
			var py := ty + k
			if py >= gy - 8:
				continue
			for dx in range(-span, span + 2):
				var px := x + dx
				if in_sim:
					if w.in_bounds(px, py) and w.is_empty(px, py):
						w.set_mat(px, py, SandWorld.M_LEAVES)
				else:
					var c := _tone(PAL.pine, px, py)
					if dx < 0 and k < 5:
						c = c.lightened(0.08)
					_sc(px, py, c)


func _tree_dead(x: int, gy: int, h: int, in_sim: bool) -> void:
	_trunk(x, gy, h, 2, PAL.dead, in_sim)
	var top := gy - h
	for b in rng.randi_range(2, 4):
		var by := top + rng.randi_range(2, maxi(4, h / 2))
		var dir := -1 if b % 2 == 0 else 1
		var e := _branch(x + (2 if dir > 0 else -1), by, dir, rng.randi_range(5, 12), rng.randi_range(4, 9), PAL.dead, in_sim)
		_wood(e.x + dir, e.y - 1, PAL.dead, in_sim)


func _grass_tufts() -> void:
	for x in range(1, width - 1):
		if rng.randf() > TREES.tuft_chance:
			continue
		var gy := heights[x]
		if not w.is_empty(x, gy - 1) or w.get_mat(x, gy) != SandWorld.M_GRASS:
			continue
		for k in rng.randi_range(1, 3):
			_sc(x, gy - 1 - k, _tone(PAL.grass, x, gy - k))


func _critter_zones() -> void:
	var mid := forest_mid
	var left_end: int = flat_spans[0][1] + 20
	var right_start: int = flat_spans[1][0] - 20
	for span in [[left_end, mid - 60], [mid + 60, right_start]]:
		if span[1] - span[0] < 40:
			continue
		var top := 1 << 30
		for x in range(span[0], span[1]):
			top = mini(top, heights[x])
		critter_zones.append(Rect2i(span[0], top - 50, span[1] - span[0], 50 + 40))
