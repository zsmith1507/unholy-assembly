extends RefCounted
## Lair installer: the director (logistics, stockpiles, morale) and the builder hook. Nothing is built at
## start; the necromancer places the heart with his build spell.


func install(main: Node, _info: Dictionary) -> Variant:
	var d := LairDirector.new()
	d.name = "LairDirector"
	for l in ["buildings", "items", "actors", "fx"]:
		var n = main.get(l)
		if n != null:
			d.layers[l] = n
	var parent: Node = main.get("buildings") if main.get("buildings") != null else main
	parent.add_child(d)
	var b := LairBuilder.new()
	b.name = "LairBuilder"
	b.parent_layer = main.get("buildings")
	main.add_child(b)
	Jobs.reset()
	return {"lair_builder": b}
