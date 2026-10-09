extends RefCounted
## Ghouls haul a loose bones bundle to a stockpile, dig a marked soil rect, and decay outside the heart.


func run(t) -> void:
	Jobs.reset()
	var w: SandWorld = t.flat_world(256, 160, 100)
	w.fill_rect(10, 60, 236, 40, SandWorld.M_EMPTY)
	var d := LairDirector.new()
	d.layers = {"items": t.root, "actors": t.root, "buildings": t.root}
	t.root.add_child(d)
	var b := LairBuilder.new()
	b.parent_layer = t.root
	t.root.add_child(b)
	b.place(&"heart", Vector2(256, 200))
	var g := LairMinion.make(&"ghoul")
	t.root.add_child(g)
	g.global_position = Vector2(200, 200)
	Events.stockpile_designated.emit(Rect2i(20, 90, 20, 10), &"ossuary")
	t.check(d.stockpiles.size() == 1, "stockpile designated")
	Events.stockpile_designated.emit(Rect2i(60, 90, 10, 10), &"part")
	t.check(d.stockpiles.size() == 1, "raw parts refused as a stockpile")
	var bones := Lair.spawn_item(t.tree, &"bones", Vector2(300, 196), t.root)
	var reached := false
	for i in 40:
		await t.ticks(30)
		if is_instance_valid(bones) and bones.carrier == null and bones.global_position.x < 90:
			reached = true
			break
	t.check(reached, "ghoul hauled bones to the ossuary")

	# dig a soil (dirt) rect in the wall
	w.fill_rect(150, 80, 8, 20, SandWorld.M_DIRT)
	await t.ticks(20) # let it settle
	Jobs.mark_dig(Rect2i(150, 80, 8, 20))
	var cleared := false
	for i in 60:
		await t.ticks(30)
		if Jobs.all_jobs().filter(func(j): return j.type == Jobs.DIG).is_empty():
			cleared = true
			break
	var left: Dictionary = w.count_rect(150, 80, 8, 20)
	t.note("dig left: %s" % str(left))
	t.check(cleared, "ghoul finished the dig job")

	# bare hands cannot dig stone
	w.fill_rect(200, 90, 4, 10, SandWorld.M_STONE)
	Jobs.mark_dig(Rect2i(200, 90, 4, 10))
	await t.ticks(60)
	t.check(w.get_mat(201, 95) == SandWorld.M_STONE, "stone untouched by bare hands")

	# life outside the heart
	var g2 := LairMinion.make(&"ghoul")
	t.root.add_child(g2)
	g2.global_position = Vector2(20, 200)
	GameState.heart_radius = 50.0
	var hp0 := g2.hp
	await t.ticks(60)
	t.check(g2.hp < hp0, "ghoul decays outside the heart")
