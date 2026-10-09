extends RefCounted
## Bodies and Souls installer: the flesh spawner hook, the towns' residents (from info.towns[*].homes),
## an old corpse in every grave (info.graves), and the forest's critters (info.critter_zones).
## Returns {"flesh_spawner": node}.

const INSTALL := {
	"farmer_share": 0.5, ## share of residents who are farmers (they work the fields outside town)
	"field_px": [60.0, 220.0], ## how far outside the town edge a farmer's field lies
	"grave_looks": ["villager", "farmer"],
}


func install(main: Node, info: Dictionary) -> Variant:
	var sp := FleshSpawner.new()
	sp.actors_layer = _layer(main, "actors")
	sp.items_layer = _layer(main, "items")
	sp.critter_zones = info.get("critter_zones", [])
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
	var n := 0
	for t in towns:
		var trect: Rect2 = t.get("rect", Rect2())
		var side: int = t.get("side", 1)
		for h in t.get("homes", []):
			var r: Rect2 = h.rect
			for i in int(h.get("alive", h.get("residents", 1))):
				n += 1
				var farmer := fmod(n * INSTALL.farmer_share, 1.0) < INSTALL.farmer_share - 0.001
				var kind := &"farmer" if farmer else &"villager"
				var x := r.get_center().x + (i - 1) * 6.0
				var feet := FleshSpawner.find_footing(Vector2(x, r.end.y - 4.0))
				var work := Vector2(randf_range(trect.position.x, trect.end.x), feet.y)
				if farmer:
					# fields lie on the far side of town from the forest
					var edge := trect.position.x if side < 0 else trect.end.x
					var out_dir := -1.0 if side < 0 else 1.0
					var fx := edge + out_dir * randf_range(INSTALL.field_px[0], INSTALL.field_px[1])
					work = Vector2(fx, feet.y)
				var hu := sp.spawn_human(kind, feet) as Human
				hu.set_home(int(h.id), r, feet, work)
				out.append(hu)
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
