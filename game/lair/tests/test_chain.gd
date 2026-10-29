extends RefCounted
## Builder rules, the heart, and grinder -> stitching table -> altar raising a ghoul.


func run(t) -> void:
	Jobs.reset()
	var w: SandWorld = t.flat_world(256, 160, 100)
	w.fill_rect(10, 60, 236, 40, SandWorld.M_EMPTY) # a dug hall, floor at cell 100 (y = 200 px)
	var b := LairBuilder.new()
	b.parent_layer = t.root
	t.root.add_child(b)
	var fy := 200.0
	t.check(b.kinds().size() == 5, "five kinds")
	t.check(not b.cost(&"grinder").is_empty(), "grinder has a cost")
	t.check(not b.can_place(&"grinder", Vector2(100, fy)), "no machine without a heart")
	t.check(not b.can_place(&"heart", Vector2(100, 150)), "heart refused in mid-air (no floor)")
	t.check(not b.can_place(&"heart", Vector2(100, 260)), "heart refused inside solid earth")
	var heart = b.place(&"heart", Vector2(256, fy))
	t.check(heart != null and GameState.has_heart, "heart placed and registered")
	t.check(heart != null and heart.is_in_group(&"interactable"), "heart is interactable")
	t.check(not b.can_place(&"heart", Vector2(100, fy)), "only one heart")
	t.check(not b.can_place(&"grinder", Vector2(256, fy)), "no overlap with the heart")
	var grinder = b.place(&"grinder", Vector2(120, fy))
	var table = b.place(&"stitching_table", Vector2(380, fy))
	var altar = b.place(&"altar", Vector2(450, fy))
	t.check(grinder != null and table != null and altar != null, "machines placed in range")

	# heart refill
	GameState.souls = 2.0
	GameState.mana = 0.2
	heart.interact(null)
	t.check(GameState.mana > 0.99 and GameState.souls < 1.3, "heart refills mana from souls")

	# grinder
	var loud := [0]
	var on_noise := func(_a, _l, _s): loud[0] += 1
	Events.noise_made.connect(on_noise)
	var corpse := Lair.spawn_item(t.tree, &"corpse", grinder.global_position + Vector2(0, -20), t.root)
	await t.ticks(20)
	t.check(not is_instance_valid(corpse) or corpse.is_queued_for_deletion(), "grinder takes the corpse")
	t.check(grinder.working, "grinder is working")
	await t.ticks(int(LairMachine.MACHINES[&"grinder"].seconds * 60) + 10)
	t.check(t.tree.get_nodes_in_group(&"item_gibs").size() == 2, "grinder made 2 gibs")
	t.check(t.tree.get_nodes_in_group(&"item_bones").size() == 1, "grinder made 1 bones")
	t.check(loud[0] > 0, "grinder is loud")
	Events.noise_made.disconnect(on_noise)

	# carry the outputs to the table by hand
	for k in [&"item_gibs", &"item_bones"]:
		for it in t.tree.get_nodes_in_group(k):
			it.global_position = table.global_position + Vector2(0, -10)
	await t.ticks(10)
	t.check(table.working, "stitching table is working")
	await t.ticks(int(LairMachine.MACHINES[&"stitching_table"].seconds * 60) + 10)
	var bodies: Array = t.tree.get_nodes_in_group(&"item_stitched_body")
	t.check(bodies.size() == 1, "table made a stitched body")

	# altar: needs a soul and the touch
	GameState.souls = 1.0
	GameState.mana = 1.0
	for it in bodies:
		it.global_position = altar.global_position + Vector2(0, -10)
	await t.ticks(10)
	t.check(not altar.working, "altar waits for the touch")
	altar.interact(null)
	t.check(GameState.mana < 1.0, "the touch costs mana")
	await t.ticks(int(LairMachine.MACHINES[&"altar"].seconds * 60) + 20)
	t.check(t.tree.get_nodes_in_group(&"lair_ghoul").size() == 1, "altar raised a ghoul")
	t.check(GameState.souls < 0.01, "raising spent a soul")
	t.check(int(GameState.stats.get("minions_raised", 0)) == 1, "stat counted")
	var g = t.tree.get_nodes_in_group(&"lair_ghoul")[0]
	t.check(g.is_in_group(&"minions"), "ghoul is a minion")
