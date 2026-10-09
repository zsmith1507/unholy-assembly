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
}

var actors_layer: Node = null
var items_layer: Node = null
var critter_zones: Array = [] ## Array[Rect2], pixels
var _restock := 0.0


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


# ---------------------------------------------------------------- restocking the forest

func _physics_process(delta: float) -> void:
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
