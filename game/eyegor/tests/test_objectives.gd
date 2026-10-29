extends RefCounted
## The hidden-start objectives: each completes from the event or stat its owning department really emits,
## in order, with a banner (milestone_reached) and Eyegor's lines; an objective already met completes the
## moment it becomes current. The stand-ins below carry only the property names the real nodes use.


class FakeDig:
	extends RefCounted
	var removed_total := 0 ## NecroSpell dig.gd


class FakeNecro:
	extends Node2D
	var dig := FakeDig.new()

	func _init() -> void:
		add_to_group(&"player") ## necromancer.gd

	func get_spell(id: StringName) -> Object:
		return dig if id == &"dig" else null


class FakeMachine:
	extends Node2D
	var kind: StringName = &"" ## LairMachine.kind


class FakeBody:
	extends Node2D
	var fresh := false ## Corpse.fresh: false for graveyard bodies


class FakePatrols:
	extends Node
	var out: Array = [] ## patrols.gd: {id, town, members, ...}


func run(t) -> void:
	var nec := FakeNecro.new()
	t.root.add_child(nec)
	var o := EyegorObjectives.new()
	t.root.add_child(o)
	var pat := FakePatrols.new()
	t.root.add_child(pat)
	o.patrols_node = pat
	var milestones: Array = []
	var on_ms := func(id): milestones.append(id)
	Events.milestone_reached.connect(on_ms)
	o.start()
	t.check(o.current_id() == &"place_heart", "starts at place_heart")

	# 1 place heart: Lair calls GameState.set_heart -> Events.heart_placed
	var heart := Node2D.new()
	t.root.add_child(heart)
	GameState.add_souls(1.0, "start")
	GameState.set_heart(heart, 64.0)
	t.check(o.is_done(&"place_heart"), "place_heart from GameState.set_heart")
	t.check(milestones.has(&"place_heart"), "banner milestone for place_heart")
	# 2 refill: spend mana, then the heart's refill (souls down, mana up in one frame)
	GameState.spend_mana(0.5)
	t.check(not o.is_done(&"refill_mana"), "spending mana alone doesn't count as a refill")
	GameState.add_mana(0.1) # siphon-like gain without spending souls
	t.check(not o.is_done(&"refill_mana"), "siphon gain doesn't count")
	GameState.refill_mana_from_heart()
	t.check(o.is_done(&"refill_mana"), "refill_mana from GameState.refill_mana_from_heart")
	# 3 dig a chamber: the Dig spell's removed_total after the heart
	nec.dig.removed_total = EyegorObjectives.OBJ.cells_for_chamber / 2
	await t.ticks(20)
	t.check(not o.is_done(&"dig_chamber"), "half a chamber isn't a chamber")
	t.check(o.current_text().contains("50/100"), "objective shows dig progress (%s)" % o.current_text())
	nec.dig.removed_total = EyegorObjectives.OBJ.cells_for_chamber + 5
	await t.ticks(20)
	t.check(o.is_done(&"dig_chamber"), "dig_chamber from Dig removed_total")
	# 4 rob a grave: a fresh body doesn't count, a graveyard one does
	var fresh_body := FakeBody.new()
	fresh_body.fresh = true
	t.root.add_child(fresh_body)
	Events.body_harvested.emit(fresh_body)
	t.check(not o.is_done(&"rob_grave"), "a fresh corpse isn't a robbed grave")
	var old := FakeBody.new()
	t.root.add_child(old)
	Events.body_harvested.emit(old)
	t.check(o.is_done(&"rob_grave"), "rob_grave from body_harvested with a graveyard body")
	# 5-9 machines and products
	for k in [&"grinder"]:
		var m := FakeMachine.new()
		m.kind = k
		t.root.add_child(m)
		Events.machine_built.emit(m)
	t.check(o.is_done(&"build_grinder"), "build_grinder from machine_built kind grinder")
	Events.item_produced.emit(&"gibs", 2, Vector2.ZERO)
	t.check(o.is_done(&"grind_corpse"), "grind_corpse from item_produced gibs")
	# out of order: the altar goes up before the stitching table; it is remembered
	var altar := FakeMachine.new()
	altar.kind = &"altar"
	t.root.add_child(altar)
	Events.machine_built.emit(altar)
	t.check(not o.is_done(&"build_altar"), "an out-of-order objective waits its turn")
	var table := FakeMachine.new()
	table.kind = &"stitching_table"
	t.root.add_child(table)
	Events.machine_built.emit(table)
	t.check(o.is_done(&"build_stitching_table"), "build_stitching_table from machine_built")
	Events.item_produced.emit(&"stitched_body", 1, Vector2.ZERO)
	t.check(o.is_done(&"stitch_body"), "stitch_body from item_produced stitched_body")
	t.check(o.is_done(&"build_altar"), "the altar built earlier completes as soon as it is current")
	# 10 raise
	Events.minion_raised.emit(Node2D.new())
	t.check(o.is_done(&"raise_ghoul"), "raise_ghoul from minion_raised")
	# 11 mark ground
	Events.dig_marked.emit(Rect2i(0, 0, 4, 4))
	t.check(o.is_done(&"mark_dig"), "mark_dig from dig_marked")
	# 12 fragments: a critter orb pays GameState.add_fragments
	GameState.add_fragments(1.0, "rabbit", Vector2.ZERO)
	t.check(o.is_done(&"harvest_fragments"), "harvest_fragments from GameState.add_fragments")
	# 13 patrol: one leaves, then is no longer out
	pat.out = [{"id": 1, "town": 0, "members": []}]
	await t.ticks(20)
	t.check(not o.is_done(&"survive_patrol"), "patrol still out")
	pat.out = []
	await t.ticks(20)
	t.check(o.is_done(&"survive_patrol"), "survive_patrol once the patrol is no longer out")
	t.check(o.all_done(), "all objectives done")
	t.check(GameState.is_unlocked(&"hidden_start_complete"), "hidden start complete unlock")
	t.check(milestones.size() >= EyegorObjectives.LIST.size(), "a banner milestone per objective (%d)" % milestones.size())
	for ob in EyegorObjectives.LIST:
		for pre in ["obj_", "intro_", "done_", "milestone_"]:
			t.check(Narrative.has_line(pre + String(ob.id)), "%s%s has words" % [pre, ob.id])
	Events.milestone_reached.disconnect(on_ms)

	# A second checklist driven only by the departments' GameState.stats counters.
	GameState.reset()
	var o2 := EyegorObjectives.new()
	t.root.add_child(o2)
	o2.start()
	GameState.count("built_heart")
	await t.ticks(20)
	t.check(o2.is_done(&"place_heart"), "place_heart from stats built_heart")
