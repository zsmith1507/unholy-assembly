extends RefCounted
## The Necromancer's real Build spell against the real lair builder: the ghost turns green, casting places
## the heart and then a grinder, he pays the builder's cost, and interacting with the heart refills mana.
## Skips itself when the Necromancer department's code isn't in this checkout (the lair branch on its own).

const NECRO := "res://necro/necromancer.gd"


func run(t) -> void:
	if not ResourceLoader.exists(NECRO):
		t.note("necromancer not in this checkout: skipped")
		t.check(true, "skipped without the necromancer")
		return
	Jobs.reset()
	t.flat_world() # ground at row 100 = 200 px, open air above
	var b := LairBuilder.new()
	b.parent_layer = t.root
	t.root.add_child(b)
	var n = load(NECRO).new()
	n.set("scripted", true)
	n.position = Vector2(160, 200)
	t.root.add_child(n)
	await t.ticks(20)

	n.select_spell_id(&"build")
	var build = n.get_selected()
	t.check(build.available_kinds() == [&"heart"], "only the heart before it stands")
	GameState.mana = 1.0
	var at: Vector2 = n.global_position + Vector2(70, -20)
	n.script_input = {"aim": at}
	await t.ticks(2)
	t.check(build.ghost_ok, "heart ghost is green over open ground (%s)" % build.ghost_reason)
	n.script_input = {"aim": at, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": at}
	await t.ticks(1)
	var heart = build.last_placed
	t.check(heart is NecroticHeart and GameState.has_heart, "cast places the real heart")
	t.check(absf(GameState.mana - (1.0 - float(b.cost(&"heart").mana))) < 0.001, "he pays the heart's cost once")
	t.check(build.current_kind() == &"grinder", "next up is the grinder")

	GameState.mana = 1.0
	var at2: Vector2 = n.global_position + Vector2(-60, -20)
	n.script_input = {"aim": at2}
	await t.ticks(2)
	t.check(build.ghost_ok, "grinder ghost is green in the heart's range (%s)" % build.ghost_reason)
	n.script_input = {"aim": at2, "cast": true}
	await t.ticks(1)
	n.script_input = {}
	await t.ticks(1)
	t.check(build.last_placed is LairMachine and build.last_placed.kind == &"grinder", "cast places a grinder")

	# Deep in solid earth the ghost is red and nothing is placed.
	var count0: int = t.tree.get_nodes_in_group(&"lair_structures").size()
	t.check(not b.can_place(&"altar", n.global_position + Vector2(40, 60)), "no altar inside solid earth")
	t.check(t.tree.get_nodes_in_group(&"lair_structures").size() == count0, "nothing extra placed")

	# Interact with the heart: walk-up distance is measured to its box.
	n.global_position = heart.global_position + Vector2(-30, 0)
	GameState.souls = 2.0
	GameState.mana = 0.1
	await t.ticks(2)
	t.check(n.get_interact_hint() != "", "a hint shows beside the heart")
	n.script_input = {"interact": true}
	await t.ticks(2)
	n.script_input = {}
	t.check(GameState.mana > 0.99 and GameState.souls < 2.0, "the heart refills mana from souls")
