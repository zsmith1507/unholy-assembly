extends RefCounted
## Dig, Harvest, Siphon, mana rules, the spell list and interact.

const U := preload("res://necro/tests/necro_test_util.gd")
const Demo := preload("res://necro/demo/demo.gd")


func run(t) -> void:
	var n: Necromancer = U.setup(t)
	await t.ticks(20)

	# --- spell list hook
	var list := n.get_spells()
	t.check(list.size() == 6, "six spells in the list")
	var ids := list.map(func(s): return s.id)
	t.check(ids == [&"dig", &"harvest", &"siphon", &"build", &"command_dig", &"stockpile"], "spell order: %s" % [ids])
	t.check(list[0].has("name") and list[0].has("cost_text") and list[0].has("color"), "entries have name, cost_text, color")
	var got := []
	var on_sel := func(id): got.append(id)
	Events.spell_selected.connect(on_sel)
	n.select_spell(1)
	t.check(n.get_selected_spell() == &"harvest" and got == [&"harvest"], "selecting emits Events.spell_selected")
	Events.spell_selected.disconnect(on_sel)

	# --- dig: aim down-right into the ground
	n.select_spell_id(&"dig")
	var noise := [0]
	var on_noise := func(_at, _l, src): if src == "dig": noise[0] += 1
	Events.noise_made.connect(on_noise)
	var target := n.global_position + Vector2(50, 30)
	var probe := Rect2i(Sim.to_cell(target) - Vector2i(12, 12), Vector2i(24, 24))
	var before := U.count_solid(probe)
	var mana0 := GameState.mana
	n.script_input = {"cast": true, "aim": target}
	await t.ticks(60)
	n.script_input = {"aim": target}
	await t.ticks(1)
	var after := U.count_solid(probe)
	t.check(after < before - 100, "dig removes ground (%d -> %d cells)" % [before, after])
	var spent := mana0 - GameState.mana
	t.check(absf(spent - 0.1) < 0.01, "dig spends 0.1 souls' worth per second (spent %.3f)" % spent)
	t.check(noise[0] > 0, "dig makes noise")
	Events.noise_made.disconnect(on_noise)

	# --- no mana, no spell
	GameState.mana = 0.0
	before = U.count_solid(probe)
	var removed0: int = n.get_spell(&"dig").removed_total
	n.script_input = {"cast": true, "aim": target + Vector2(10, 10)}
	await t.ticks(20)
	t.check(n.get_spell(&"dig").removed_total == removed0, "can't dig with an empty bar")
	t.check(not n.casting, "not in the cast pose with an empty bar")
	n.script_input = {}
	GameState.mana = 1.0

	# --- harvest pulls a part toward his hand, then drops it at his feet
	var harvested := []
	var on_h := func(it): harvested.append(it)
	Events.body_harvested.connect(on_h)
	var arm := Demo.make_item(&"part", n.global_position + Vector2(110, -6), Vector2(8, 6), {"part": "arm"})
	t.root.add_child(arm)
	await t.ticks(10)
	n.select_spell_id(&"harvest")
	var d0 := arm.global_position.distance_to(n.get_hand_pos())
	n.script_input = {"cast": true, "aim": arm.get_box().get_center()}
	await t.ticks(30)
	var d1 := arm.global_position.distance_to(n.get_hand_pos())
	t.check(d1 < d0 - 20.0, "harvest pulls the item toward him (%.0f -> %.0f px)" % [d0, d1])
	for i in 120:
		n.script_input = {"cast": true, "aim": arm.get_box().get_center()}
		await t.ticks(1)
		if not harvested.is_empty():
			break
	t.check(harvested.size() == 1 and harvested[0] == arm, "harvest announces Events.body_harvested")
	n.script_input = {}
	await t.ticks(30)
	t.check(absf(arm.global_position.x - n.global_position.x) < 30.0, "harvested item lies at his feet")
	Events.body_harvested.disconnect(on_h)

	# --- harvest won't pull through solid ground
	var buried := Demo.make_item(&"corpse", n.global_position + Vector2(-60, 70), Vector2(20, 8))
	buried.collide = false
	buried.gravity = 0.0
	t.root.add_child(buried)
	var b0 := buried.global_position
	n.script_input = {"cast": true, "aim": buried.global_position}
	await t.ticks(20)
	t.check(buried.global_position.distance_to(b0) < 1.0, "harvest can't reach through the earth")
	n.script_input = {}

	# --- siphon: blood on the ground becomes mana, and turns (partly) to nothing/ash
	GameState.mana = 0.2
	var spot := n.global_position + Vector2(50, -2)
	var sc := Sim.to_cell(spot)
	Sim.world.fill_rect(sc.x - 6, sc.y - 3, 12, 4, SandWorld.M_BLOOD)
	n.select_spell_id(&"siphon")
	n.script_input = {"cast": true, "aim": spot}
	await t.ticks(30)
	n.script_input = {}
	t.check(GameState.mana > 0.25, "siphoning blood gives mana (%.3f)" % GameState.mana)
	var blood := 0
	var counts := Sim.world.count_rect(sc.x - 20, sc.y - 20, 40, 40)
	blood = int(counts.get(SandWorld.M_BLOOD, 0))
	t.check(blood < 48, "siphoned blood is gone (%d cells left)" % blood)

	# --- interact: nearest interactable within 24 px
	var heart := Node2D.new()
	heart.set_script(preload("res://necro/demo/stand_in_heart.gd"))
	heart.position = n.global_position + Vector2(30, 0)
	t.root.add_child(heart)
	GameState.souls = 2.0
	GameState.mana = 0.1
	t.check(n.get_interact_hint() != "", "shows a hint near the heart")
	n.script_input = {"interact": true}
	await t.ticks(2)
	n.script_input = {}
	t.check(is_equal_approx(GameState.mana, 1.0) and absf(GameState.souls - 1.1) < 0.001, "interacting with the heart refills mana from souls")
	heart.position.x += 200
	t.check(n.get_interact_hint() == "", "no hint when nothing is near")
