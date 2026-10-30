extends RefCounted
## Robbing a grave by magic (design doc, Harvesting phase 1): a corpse in a buried coffin can't be
## pulled through the earth; Dig bores a shaft to the coffin; then Harvest draws the corpse up and out.

const U := preload("res://necro/tests/necro_test_util.gd")
const StandInBody := preload("res://necro/demo/stand_in_body.gd")


func run(t) -> void:
	# round 5: he stands nearly over the grave and digs straight down (the narrower early bore makes a
	# steep diagonal shaft too tight to draw a whole body up through)
	var n: Necromancer = U.setup(t, 211.0)
	# a coffin under the grass, like the demo's: wood box with a hollow, 18 cells (36 px) down
	var cx := 110
	var cy := 118
	Sim.world.fill_rect(cx - 16, cy - 7, 32, 14, SandWorld.M_WOOD)
	Sim.world.fill_rect(cx - 14, cy - 5, 28, 10, SandWorld.M_EMPTY)
	var corpse := StandInBody.new()
	corpse.kind = &"corpse"
	corpse.box_size = Vector2(24, 8)
	corpse.data = {"source": "villager", "fresh": false}
	corpse.position = Vector2(cx * Sim.CELL, (cy + 5) * Sim.CELL)
	t.root.add_child(corpse)
	await t.ticks(20)
	var c0 := corpse.global_position
	t.check(c0.y > n.global_position.y + 30.0, "the corpse lies buried below him (%.0f vs %.0f)" % [c0.y, n.global_position.y])

	# the grave-wind can't reach it through the earth
	n.select_spell_id(&"harvest")
	n.script_input = {"cast": true, "aim": corpse.get_box().get_center()}
	await t.ticks(30)
	t.check(corpse.global_position.distance_to(c0) < 2.0, "harvest can't reach the buried corpse")
	n.script_input = {}

	# bore a shaft down to the coffin
	n.select_spell_id(&"dig")
	GameState.mana = 1.0
	for i in 300: # round 5: digging starts slower and narrower, so he sweeps the beam across the lid
		n.script_input = {"cast": true, "aim": corpse.get_box().get_center() + Vector2(14.0 * sin(i * 0.08), 0)}
		await t.ticks(1)
	n.script_input = {}
	await t.ticks(5)
	var hit := Sim.world.raycast(Sim.to_cell(n.get_hand_pos()), Sim.to_cell(corpse.get_box().get_center()), false)
	t.check(hit == Vector2i(-1, -1), "dig opened a clear line from his hand to the corpse (blocked at %s)" % [hit])

	# now the wind draws it up, and it goes into his satchel (round 5)
	var got := []
	var on_h := func(it): got.append(it)
	Events.body_harvested.connect(on_h)
	n.select_spell_id(&"harvest")
	GameState.mana = 1.0
	GameState.inventory = {}
	for i in 240:
		n.script_input = {"cast": true, "aim": corpse.get_box().get_center()}
		await t.ticks(1)
		if not got.is_empty():
			break
	n.script_input = {}
	if got.is_empty():
		t.note("corpse at %s, hand %s" % [corpse.global_position, n.get_hand_pos()])
	Events.body_harvested.disconnect(on_h)
	t.check(got.size() == 1 and got[0] == corpse, "the corpse is drawn up out of the grave and harvested")
	await t.ticks(2)
	t.check(not is_instance_valid(corpse) and GameState.item_count(&"flesh") > 0.0, "the corpse is out of the coffin and in his satchel (%s)" % [GameState.inventory])
