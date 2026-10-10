class_name FleshSpawner
extends Node
## The "Flesh spawner" hook (group `flesh_spawner`): makes humans, critters and soul orbs for anyone.
##   spawn_human(kind, at) -> Actor        &"farmer", &"villager"
##   spawn_critter(kind, at) -> Actor      &"rabbit", &"crow", &"deer"
##   spawn_soul_orb(at, amount, source) -> Node2D
## It also keeps the forest stocked: critters that die are replaced, away from the necromancer.
## Owned by Bodies and Souls.

const SPAWN := {
	"critters_per_zone": 5, ## the forest's standing population, per critter zone
	"critter_mix": {"rabbit": 5, "crow": 3, "deer": 2}, ## relative odds
	"restock_seconds": 25.0, ## one missing critter comes back this often
	"restock_min_px": 420.0, ## never pops in closer than this to the necromancer
	"ground_search_px": 160.0, ## how far up or down to look for footing when placing someone
	"farmer_share": 0.5, ## share of residents who are farmers (they work the fields outside town)
	"field_px": [60.0, 220.0], ## how far outside the town edge a farmer's field lies
	"census_seconds": 5.0, ## how often to check for homes a new family has moved into
}

var actors_layer: Node = null
var items_layer: Node = null
var critter_zones: Array = [] ## Array[Rect2], pixels
var towns: Array = [] ## info.towns (World keeps each home's `alive` count current)
var _restock := 0.0
var _census := 0.0
var _resident_n := 0


func _init() -> void:
	name = "FleshSpawner"


func _ready() -> void:
	add_to_group(&"flesh_spawner")


## The layer bodies and souls go in: the spawner's own when there is one, else `fallback`.
static func layer_for(node: Node, which: StringName, fallback: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return fallback
	var sp := node.get_tree().get_first_node_in_group(&"flesh_spawner")
	if sp != null:
		var l: Node = sp.items_layer if which == &"items" else sp.actors_layer
		if l != null and is_instance_valid(l):
			return l
	return fallback


# ---------------------------------------------------------------- the hook

func spawn_human(kind: StringName, at: Vector2) -> Actor:
	var h := Human.new()
	h.setup(kind if kind in [&"farmer", &"villager"] else &"villager", find_footing(at))
	_actors().add_child(h)
	return h


func spawn_critter(kind: StringName, at: Vector2) -> Actor:
	var c := Critter.new()
	c.setup(kind if Critter.CRITTER.kinds.has(String(kind)) else &"rabbit", find_footing(at) if kind != &"crow" else at)
	_actors().add_child(c)
	return c


## A soul orb at `at`. Inside the heart's range it drifts home by itself; outside it fades unless the
## necromancer comes for it (a minion fallen far from home).
func spawn_soul_orb(at: Vector2, amount: float, source: String) -> Node2D:
	var orb := SoulOrb.new()
	orb.amount = amount
	orb.source = source
	orb.fades = not GameState.in_heart_range(at)
	orb.position = at
	_items().add_child(orb)
	return orb


# ---------------------------------------------------------------- helpers

func _actors() -> Node:
	return actors_layer if actors_layer != null and is_instance_valid(actors_layer) else self


func _items() -> Node:
	return items_layer if items_layer != null and is_instance_valid(items_layer) else self


## Feet position nearest `at` standing on solid ground with air above (pixels).
static func find_footing(at: Vector2, clear_px: float = 40.0) -> Vector2:
	if Sim.world == null:
		return at
	var step := float(Sim.CELL)
	var reach: float = SPAWN.ground_search_px
	# inside the ground: go up until there is air
	var p := at
	var up := 0.0
	while Sim.solid_at(p + Vector2(0, -1)) and up < reach:
		p.y -= step
		up += step
	# in the air: fall until something solid is underfoot
	var down := 0.0
	while not Sim.solid_at(p) and down < reach * 2.0:
		p.y += step
		down += step
	p.y = floorf(p.y / step) * step
	# make sure there is headroom
	var head := 0.0
	while head < clear_px:
		if Sim.solid_at(p + Vector2(0, -head - 1)):
			return at
		head += step
	return p


# ---------------------------------------------------------------- townsfolk

## One adult resident of `home` (World's home dictionary) in `town`. Farmers work fields outside town;
## villagers potter about inside it. They start at home.
func spawn_resident(town: Dictionary, home: Dictionary, index: int = 0) -> Human:
	_resident_n += 1
	var farmer := fmod(_resident_n * SPAWN.farmer_share, 1.0) < SPAWN.farmer_share - 0.001
	var r: Rect2 = home.rect
	var trect: Rect2 = town.get("rect", r)
	var x := r.get_center().x + (index - 1) * 6.0
	var feet := find_footing(Vector2(x, r.end.y - 4.0))
	var work := Vector2(randf_range(trect.position.x, trect.end.x), feet.y)
	if farmer:
		var side: int = town.get("side", 1)
		var edge := trect.position.x if side < 0 else trect.end.x
		var fx := edge + float(side if side != 0 else 1) * randf_range(SPAWN.field_px[0], SPAWN.field_px[1])
		work = Vector2(fx, feet.y)
	var hu := spawn_human(&"farmer" if farmer else &"villager", feet) as Human
	hu.set_home(int(home.id), r, feet, work)
	return hu


## Homes World has refilled (a new family moved in) get their residents.
func census() -> int:
	var living := {}
	for h in get_tree().get_nodes_in_group(&"human_actors"):
		if h is Human and not h.dead and h.home_id >= 0:
			living[h.home_id] = int(living.get(h.home_id, 0)) + 1
	var alive := {} ## home id -> living count, from World's settlements when it is there
	var st := get_tree().get_first_node_in_group(&"settlements")
	if st != null and st.has_method("homes"):
		for home in st.homes():
			alive[int(home.id)] = int(home.get("alive", 0))
	var added := 0
	for t in towns:
		for home in t.get("homes", []):
			var want := int(alive.get(int(home.id), home.get("alive", 0)))
			var have := int(living.get(int(home.id), 0))
			for i in range(have, want):
				spawn_resident(t, home, i)
				added += 1
	return added


# ---------------------------------------------------------------- restocking the forest

func _physics_process(delta: float) -> void:
	if not towns.is_empty():
		_census += delta
		if _census >= SPAWN.census_seconds:
			_census = 0.0
			census()
	if critter_zones.is_empty():
		return
	_restock += delta
	if _restock < SPAWN.restock_seconds:
		return
	_restock = 0.0
	var want: int = SPAWN.critters_per_zone * critter_zones.size()
	if get_tree().get_nodes_in_group(&"critters").size() >= want:
		return
	var necro := SoulOrb._necro()
	for attempt in 6:
		var z: Rect2 = critter_zones[randi() % critter_zones.size()]
		var x := randf_range(z.position.x, z.end.x)
		if necro != null and absf(necro.global_position.x - x) < SPAWN.restock_min_px:
			continue
		var at := Vector2(x, z.position.y)
		var kind := pick_critter()
		if kind == &"crow":
			at = find_footing(at) + Vector2(0, -2)
		spawn_critter(kind, at)
		return


static func pick_critter() -> StringName:
	var mix: Dictionary = SPAWN.critter_mix
	var total := 0
	for k in mix:
		total += int(mix[k])
	var r := randi() % maxi(1, total)
	for k in mix:
		r -= int(mix[k])
		if r < 0:
			return StringName(k)
	return &"rabbit"
