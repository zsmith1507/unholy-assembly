extends RefCounted
## Robbing a grave by magic (design doc, Harvesting phase 1): a corpse in a buried coffin can't be
## pulled through the earth; Dig bores a shaft to the coffin; then Harvest draws the corpse up and out.

const U := preload("res://necro/tests/necro_test_util.gd")
const Demo := preload("res://necro/demo/demo.gd")


func run(t) -> void:
	var n: Necromancer = U.setup(t, 160.0)
	# a coffin under the grass, like the demo's: wood box with a hollow, 18 cells (36 px) down
	var cx := 110
	var cy := 118
	Sim.world.fill_rect(cx - 16, cy - 7, 32, 14, SandWorld.M_WOOD)
	Sim.world.fill_rect(cx - 14, cy - 5, 28, 10, SandWorld.M_EMPTY)
	var corpse := Demo.make_item(&"corpse", Vector2(cx * Sim.CELL, (cy + 5) * Sim.CELL), Vector2(24, 8), {"source": "villager"})
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
	for i in 150:
		n.script_input = {"cast": true, "aim": corpse.get_box().get_center()}
		await t.ticks(1)
	n.script_input = {}
	await t.ticks(5)
	var hit := Sim.world.raycast(Sim.to_cell(n.get_hand_pos()), Sim.to_cell(corpse.get_box().get_center()), false)
	t.check(hit == Vector2i(-1, -1), "dig opened a clear line from his hand to the corpse (blocked at %s)" % [hit])

	# now the wind draws it up and drops it at his feet
	var got := []
	var on_h := func(it): got.append(it)
	Events.body_harvested.connect(on_h)
	n.select_spell_id(&"harvest")
	GameState.mana = 1.0
	for i in 240:
		n.script_input = {"cast": true, "aim": corpse.get_box().get_center()}
		await t.ticks(1)
		if not got.is_empty():
			break
	n.script_input = {}
	Events.body_harvested.disconnect(on_h)
	t.check(got.size() == 1 and got[0] == corpse, "the corpse is drawn up out of the grave and harvested")
	await t.ticks(30)
	t.check(corpse.global_position.y < c0.y - 20.0, "the corpse is out of the coffin (%.0f -> %.0f)" % [c0.y, corpse.global_position.y])
