extends RefCounted
## Ragdoll corpses: they fall and settle, bleed into the sim on the blood timer, come apart under
## Harvest in weight order (arms, head, legs, then the torso), and Siphon drinks them down to ash.


func _blood(w: SandWorld) -> int:
	return int(w.count_rect(0, 0, w.get_width(), w.get_height()).get(SandWorld.M_BLOOD, 0))


func run(t) -> void:
	var w: SandWorld = t.flat_world(256, 160, 100)
	var ground := 200.0

	# --- falls, settles, bleeds
	var c := Corpse.new()
	c.setup("farmer", BodyRig.pose(Vector2(150, 150), 1, 0.0, false), Vector2(0.5, 0), true)
	t.root.add_child(c)
	await t.ticks(150)
	t.check(c.pts["hip"].y > 185.0 and c.pts["hip"].y <= ground + 1.0, "corpse falls onto the ground (hip at %.0f)" % c.pts["hip"].y)
	var low := INF
	for k in c.pts:
		low = minf(low, c.pts[k].y)
	t.check(low > ground - 16.0, "it lies down rather than standing (highest point %.0f)" % low)
	t.check(c.asleep, "a settled corpse stops simulating")
	t.check(_blood(w) > 0, "the neck wound pumps blood into the sim (%d cells)" % _blood(w))
	t.check(c.is_in_group(&"pullable") and c.is_in_group(&"siphonable") and c.is_in_group(&"item_corpse"), "corpse joins pullable, siphonable, item_corpse")
	t.check(c.blood < 1.0 and c.blood > 0.9, "the blood timer is running (%.3f left)" % c.blood)

	# --- the blood timer runs out
	c.blood = 0.0005
	await t.ticks(10)
	t.check(c.blood == 0.0 and c.data.fresh == false, "when the blood timer runs out the body is no longer fresh")
	c.queue_free()

	# --- Harvest on a body that's held down: tears come in weight order
	var d := Corpse.new()
	d.setup("villager", BodyRig.lying_pose(Vector2(256, ground - 3), 1), Vector2.ZERO, true)
	t.root.add_child(d)
	await t.ticks(30)
	var order: Array = []
	var parts: Array = []
	var on_child := func(n): if n is BodyPart: order.append(n.part)
	t.root.child_entered_tree.connect(on_child)
	for i in 600:
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			break
		d.apply_pull(Vector2(0, 0.6)) # straight into the ground: held fast, it strains
		await t.ticks(1)
	t.root.child_entered_tree.disconnect(on_child)
	t.note("tear order: %s" % [order])
	t.check(order.size() >= 5, "the held body comes apart (%d tears)" % order.size())
	if order.size() >= 5:
		t.check(order[0] == "arm" and order[1] == "arm", "arms tear first")
		t.check(order[2] == "head", "then the head")
		t.check(order[3] == "leg" and order[4] == "leg", "then the legs")
	for n in t.root.get_children():
		if n is BodyPart:
			parts.append(n)
	t.check(not is_instance_valid(d) or d.is_queued_for_deletion(), "with only the torso left the corpse becomes a torso part")
	var names := parts.map(func(p): return p.part)
	names.sort()
	t.check(names == ["arm", "arm", "head", "leg", "leg", "torso"], "six parts on the ground: %s" % [names])
	t.check(parts.all(func(p): return p.kind == &"part" and p.is_in_group(&"item_part") and p.is_in_group(&"pullable")), "parts are pullable part items")
	await t.ticks(120)
	t.check(parts.all(func(p): return is_instance_valid(p) and p.global_position.y <= ground + 2.0 and p.global_position.y > ground - 20.0), "parts settle on the ground")

	# --- a light part flies to the pull, a heavy one drags
	var arm: BodyPart = parts.filter(func(p): return p.part == "arm")[0]
	var torso: BodyPart = parts.filter(func(p): return p.part == "torso")[0]
	var a0 := arm.global_position
	var t0 := torso.global_position
	for i in 40:
		arm.apply_pull(Vector2(0, -0.45))
		torso.apply_pull(Vector2(0, -0.45))
		await t.ticks(1)
	t.check(a0.y - arm.global_position.y > t0.y - torso.global_position.y, "an arm lifts faster than a torso (%.0f vs %.0f px)" % [a0.y - arm.global_position.y, t0.y - torso.global_position.y])

	# --- Siphon: blood first, then flesh, then ash
	var e := Corpse.new()
	e.setup("farmer", BodyRig.lying_pose(Vector2(400, ground - 3), -1), Vector2.ZERO, true)
	t.root.add_child(e)
	await t.ticks(5)
	var first := e.siphon(0.05)
	t.check(is_equal_approx(first, 0.05), "siphon gives what it asks for while there is blood (%.3f)" % first)
	var total := first
	var calls := 0
	while is_instance_valid(e) and not e.is_queued_for_deletion() and calls < 2000:
		total += e.siphon(0.01)
		calls += 1
	var worth: float = Corpse.CORPSE.blood_mana + Corpse.CORPSE.flesh_mana
	t.check(absf(total - worth) < 0.06, "a whole fresh body is worth about %.2f souls of mana (got %.3f, blood mostly gone already)" % [worth, total])
	t.check(not is_instance_valid(e) or e.is_queued_for_deletion(), "an emptied body crumbles to ash")
	await t.ticks(60)
	var ash := int(w.count_rect(0, 0, 256, 160).get(SandWorld.M_ASH, 0))
	t.check(ash > 0, "ash is left on the ground (%d cells)" % ash)
