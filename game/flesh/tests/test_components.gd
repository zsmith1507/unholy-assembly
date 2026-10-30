extends RefCounted
## Round 5 (Zach's notes 13 and 14): bodies come apart into flesh, bones and blood for the satchel, and a
## body in a coffin shows as soon as the coffin is opened, with no Harvest.


func _near(a: float, b: float, tol := 0.06) -> bool:
	return absf(a - b) <= tol


## A coffin the size World builds (34 x 8 cells, wooden shell, hollow inside) under `depth` cells of grave
## dirt. Returns its centre in pixels.
func _coffin(w: SandWorld, gx: int, gy: int, depth: int) -> Vector2:
	w.fill_rect(gx + 7, gy, 20, depth, SandWorld.M_DIRT)
	var cr := Rect2i(gx, gy + depth, 34, 8)
	w.fill_rect(cr.position.x - 2, cr.position.y - 1, cr.size.x + 4, cr.size.y + 3, SandWorld.M_EARTH)
	w.fill_rect(cr.position.x, cr.position.y, cr.size.x, cr.size.y, SandWorld.M_WOOD)
	w.fill_rect(cr.position.x + 1, cr.position.y + 1, cr.size.x - 2, cr.size.y - 2, SandWorld.M_EMPTY)
	return Sim.cell_center(Vector2i(cr.position.x + cr.size.x / 2, cr.position.y + cr.size.y / 2))


func _sum(y: Dictionary) -> String:
	return "flesh %.2f, bones %.2f, blood %.2f" % [y.get(&"flesh", 0.0), y.get(&"bones", 0.0), y.get(&"blood", 0.0)]


func run(t) -> void:
	var w: SandWorld = t.flat_world(512, 200, 100)
	var ground := 200.0
	GameState.inventory = {}

	# --- a fresh body and its pieces
	var c := Corpse.new()
	c.setup("villager", BodyRig.lying_pose(Vector2(100, ground - 3), 1), Vector2.ZERO, true)
	t.root.add_child(c)
	await t.ticks(2)
	var y := c.components()
	t.note("fresh body: " + _sum(y))
	t.check(c.is_in_group(&"harvestable") and c.has_method("consume"), "a corpse is harvestable")
	t.check(_near(y.get(&"flesh", 0.0), 6.0) and _near(y.get(&"bones", 0.0), 4.0), "a whole fresh adult is flesh 6, bones 4")
	t.check(_near(y.get(&"blood", 0.0), 3.0), "and about 3 blood while fresh")
	var arm: BodyPart = c.tear("armF")
	await t.ticks(1)
	var ay := arm.components()
	t.note("an arm: " + _sum(ay))
	t.check(arm.is_in_group(&"harvestable"), "a torn-off part is harvestable")
	t.check(_near(ay.get(&"flesh", 0.0), 0.5) and _near(ay.get(&"bones", 0.0), 0.5) and ay.get(&"blood", 0.0) > 0.2, "an arm is a small share (flesh 0.5, bones 0.5, a little blood)")
	var rest := c.components()
	t.check(_near(rest.get(&"flesh", 0.0), 5.5) and _near(rest.get(&"bones", 0.0), 3.5), "the body keeps the rest (%s)" % _sum(rest))
	var torso: BodyPart = c.tear("torso")
	await t.ticks(1)
	var ty := torso.components()
	t.check(ty.get(&"blood", 0.0) > 1.5, "the torso holds most of the blood (%.2f)" % ty.get(&"blood", 0.0))

	# --- consume: returns the yield, adds nothing itself, frees the piece, spills a little gore
	var before := int(w.count_rect(0, 0, 512, 200).get(SandWorld.M_BLOOD, 0)) + int(w.count_rect(0, 0, 512, 200).get(SandWorld.M_GIBS, 0))
	var got := arm.consume()
	t.check(got == ay, "consume returns what components promised")
	t.check(GameState.inventory.is_empty(), "consume puts nothing in the satchel itself (the Necromancer does)")
	t.check(arm.is_queued_for_deletion() and not arm.is_in_group(&"harvestable") and not arm.is_in_group(&"pullable"), "the consumed part is gone")
	t.check(arm.consume().is_empty(), "a part can only be harvested once")
	var tgot := torso.consume()
	t.check(tgot.get(&"blood", 0.0) > 1.5, "the torso gives its blood")
	await t.ticks(3)
	var after := int(w.count_rect(0, 0, 512, 200).get(SandWorld.M_BLOOD, 0)) + int(w.count_rect(0, 0, 512, 200).get(SandWorld.M_GIBS, 0))
	t.check(after > before, "harvesting spills a little gore into the sim (%d cells)" % (after - before))

	# --- blood only while the blood timer lasts
	var dry := Corpse.new()
	dry.setup("farmer", BodyRig.lying_pose(Vector2(180, ground - 3), 1), Vector2.ZERO, true)
	t.root.add_child(dry)
	dry.blood = 0.0
	t.check(not dry.components().has(&"blood"), "a body whose blood timer ran out gives no blood")
	var whole := dry.consume()
	t.check(_near(whole.get(&"flesh", 0.0), 6.0) and dry.is_queued_for_deletion(), "a whole body is consumed in one go (%s)" % _sum(whole))

	# --- a graveyard body is old: flesh and bones, no blood
	var g := Corpse.new()
	g.setup_grave("villager", Vector2(260, ground - 6))
	t.root.add_child(g)
	await t.ticks(1)
	var gy := g.components()
	t.note("grave body: " + _sum(gy))
	t.check(not gy.has(&"blood") and _near(gy.get(&"bones", 0.0), 4.0) and gy.get(&"flesh", 0.0) < 5.0 and gy.get(&"flesh", 0.0) > 2.0, "a grave body is old meat: less flesh, all its bones, no blood")
	g.queue_free()

	# --- Harvest's pull takes a free body apart quickly: arms, head, legs, then the torso flies in
	var p := Corpse.new()
	p.setup("villager", BodyRig.lying_pose(Vector2(330, ground - 3), 1), Vector2.ZERO, true)
	t.root.add_child(p)
	await t.ticks(20)
	var hand := Vector2(470, ground - 60)
	var order: Array = []
	var on_child := func(n): if n is BodyPart: order.append(n.part)
	t.root.child_entered_tree.connect(on_child)
	var ticks := 0
	while is_instance_valid(p) and not p.is_queued_for_deletion() and ticks < 300:
		var to: Vector2 = hand - p.global_position
		var dir := to.normalized()
		var v: Vector2 = p.velocity
		var along := v.dot(dir)
		p.apply_pull(dir * 0.5 * clampf(4.0 - along, 0.0, 1.0) - (v - dir * along) * 0.12) # as Harvest does
		ticks += 1
		await t.ticks(1)
	t.root.child_entered_tree.disconnect(on_child)
	t.note("pulled apart in %d ticks (%.2f s): %s" % [ticks, ticks / 60.0, order])
	t.check(order.size() == 6 and order[0] == "arm" and order[2] == "head" and order[5] == "torso", "Harvest pulls a body apart arms first, the torso last")
	t.check(ticks <= 90, "in about a second, so harvesting a body is quick")

	# --- a body in its coffin shows the moment the coffin is broken open, with no Harvest
	var at_a := _coffin(w, 20, 100, 12)
	var at_b := _coffin(w, 90, 100, 10)
	var at_c := _coffin(w, 160, 100, 14)
	var bodies: Array = []
	for at in [at_a, at_b, at_c]:
		var b := Corpse.new()
		b.setup_grave("farmer", at)
		t.root.add_child(b)
		bodies.append(b)
	await t.ticks(40)
	t.check(bodies.all(func(b): return b.interred and not b.visible and b.is_in_group(&"grave_corpses")), "buried bodies stay hidden in closed coffins")
	# A: break a hole in the coffin's side wall (as Dig would, earth and plank)
	var ca := Sim.to_cell(at_a)
	w.fill_rect(ca.x + 16, ca.y - 2, 4, 3, SandWorld.M_EMPTY)
	# B: dig the grave dirt off the lid, down to the wood
	var cb := Sim.to_cell(at_b)
	w.fill_rect(cb.x - 6, 100, 12, cb.y - 4 - 100 + 1 - 1, SandWorld.M_EMPTY)
	await t.ticks(15)
	var a: Corpse = bodies[0]
	var b2: Corpse = bodies[1]
	var c3: Corpse = bodies[2]
	t.check(not a.interred and a.visible and a.is_in_group(&"item_corpse") and a.is_in_group(&"pullable"), "a coffin broken open shows its body at once (no Harvest)")
	t.check(not a.is_in_group(&"grave_corpses"), "it leaves grave_corpses (Suspicion counts robbed graves by this)")
	t.check(not b2.interred and b2.visible, "digging the earth off the lid uncovers the body too")
	t.check(c3.interred and not c3.visible, "an untouched coffin keeps its body hidden")
	await t.ticks(60)
	t.check(is_instance_valid(a) and a.global_position.distance_to(at_a) < 20.0, "the uncovered body lies in its coffin (%.0f px from the middle)" % a.global_position.distance_to(at_a))
	t.check(_near(a.components().get(&"bones", 0.0), 4.0), "and can be harvested like any body")
