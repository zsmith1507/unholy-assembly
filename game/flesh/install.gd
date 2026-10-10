extends RefCounted
## Bodies and Souls installer: the flesh spawner hook, the towns' residents (from info.towns[*].homes),
## an old corpse in every grave (info.graves), and the forest's critters (info.critter_zones).
## Returns {"flesh_spawner": node}.

const INSTALL := {
	"grave_looks": ["villager", "farmer"],
}


func install(main: Node, info: Dictionary) -> Variant:
	var sp := FleshSpawner.new()
	sp.actors_layer = _layer(main, "actors")
	sp.items_layer = _layer(main, "items")
	sp.critter_zones = info.get("critter_zones", [])
	sp.towns = info.get("towns", [])
	main.add_child(sp)
	spawn_residents(sp, info.get("towns", []))
	bury_graves(sp, info.get("graves", []))
	stock_forest(sp, info.get("critter_zones", []))
	return {"flesh_spawner": sp}


static func _layer(main: Node, n: String) -> Node:
	var l = main.get(n)
	return l if l is Node else main


## One human per living resident of every home. They start at home (the run opens at dusk).
static func spawn_residents(sp: FleshSpawner, towns: Array) -> Array:
	var out: Array = []
	for t in towns:
		for h in t.get("homes", []):
			for i in int(h.get("alive", h.get("residents", 1))):
				out.append(sp.spawn_resident(t, h, i))
	return out


## An old body in every coffin: no blood, no soul, waiting for Harvest.
static func bury_graves(sp: FleshSpawner, graves: Array) -> Array:
	var out: Array = []
	for g in graves:
		var c := Corpse.new()
		c.setup_grave(INSTALL.grave_looks[randi() % INSTALL.grave_looks.size()], g)
		sp._items().add_child(c)
		out.append(c)
	return out


static func stock_forest(sp: FleshSpawner, zones: Array) -> Array:
	var out: Array = []
	for z in zones:
		var rect: Rect2 = z
		for i in FleshSpawner.SPAWN.critters_per_zone:
			var kind := FleshSpawner.pick_critter()
			var x := randf_range(rect.position.x + 8.0, rect.end.x - 8.0)
			var at := FleshSpawner.find_footing(Vector2(x, rect.position.y))
			out.append(sp.spawn_critter(kind, at))
	return out
