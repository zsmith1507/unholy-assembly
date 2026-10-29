extends RefCounted
## Build calls the lair builder (heart first, only one), Dig Here posts a job, Stockpile designates.

const U := preload("res://necro/tests/necro_test_util.gd")
const StandInBuilder := preload("res://necro/demo/stand_in_builder.gd")


func run(t) -> void:
	var n: Necromancer = U.setup(t)
	var b := StandInBuilder.new()
	t.root.add_child(b)
	await t.ticks(20)

	n.select_spell_id(&"build")
	var build: NecroSpell = n.get_selected()
	t.check(build.available_kinds() == [&"heart"], "only the heart can be built before the heart stands")
	var at := n.global_position + Vector2(70, -20)
	n.script_input = {"aim": at}
	await t.ticks(2)
	t.check(build.ghost_ok, "ghost is green over open ground (%s)" % build.ghost_reason)
	t.check(b.calls.can_place > 0, "ghost asks the builder can_place")
	var mana0 := GameState.mana
	n.script_input = {"aim": at, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": at}
	await t.ticks(1)
	t.check(b.calls.place == 1 and b.placed.size() == 1, "cast calls builder.place")
	t.check(b.placed.size() == 1 and b.placed[0].kind == &"heart", "first build is the heart")
	t.check(absf(mana0 - GameState.mana - 0.25) < 0.001, "build pays the builder's mana cost")
	t.check(GameState.has_heart, "heart registered")
	t.check(not build.available_kinds().has(&"heart"), "no second heart")
	t.check(build.current_kind() == &"grinder", "next up is the grinder")
	n.script_input = {"aim": at, "cast_alt": true}
	await t.ticks(1)
	n.script_input = {"aim": at}
	await t.ticks(1)
	t.check(build.current_kind() == &"stitching_table", "alternate button cycles the building")

	# underground is refused (red ghost), nothing placed
	var deep := n.global_position + Vector2(-60, 80)
	n.script_input = {"aim": deep, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": deep}
	await t.ticks(1)
	t.check(not build.ghost_ok, "ghost is red inside solid ground")
	t.check(b.placed.size() == 1, "nothing placed where it won't fit")

	# --- Dig Here: drag a rectangle over the ground
	var marked := []
	var on_mark := func(r): marked.append(r)
	Events.dig_marked.connect(on_mark)
	n.select_spell_id(&"command_dig")
	var a := n.global_position + Vector2(-80, 10)
	var z := n.global_position + Vector2(-20, 50)
	n.script_input = {"aim": a, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": z, "cast": true}
	await t.ticks(3)
	n.script_input = {"aim": z}
	await t.ticks(1)
	t.check(marked.size() == 1, "dig order posted (Events.dig_marked)")
	if marked.size() == 1:
		var r: Rect2i = marked[0]
		t.check(r.position == Sim.to_cell(a) and r.end == Sim.to_cell(z) + Vector2i.ONE, "dig order covers the dragged cells (%s)" % r)
	var dig_jobs := Jobs.all_jobs().filter(func(j): return j.type == Jobs.DIG)
	t.check(dig_jobs.size() >= 1, "Jobs board has a dig job")
	Events.dig_marked.disconnect(on_mark)

	# --- Stockpile: refused over solid ground, accepted in a hollow
	var piles := []
	var on_pile := func(r, k): piles.append([r, k])
	Events.stockpile_designated.connect(on_pile)
	n.select_spell_id(&"stockpile")
	n.script_input = {"aim": a, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": z}
	await t.ticks(1)
	t.check(piles.is_empty(), "stockpile refused over undug ground")
	var hollow := Rect2i(Sim.to_cell(a), Sim.to_cell(z) - Sim.to_cell(a))
	Sim.world.fill_rect(hollow.position.x, hollow.position.y, hollow.size.x + 1, hollow.size.y + 1, SandWorld.M_EMPTY)
	n.script_input = {"aim": a, "cast_alt": true}
	await t.ticks(1)
	n.script_input = {"aim": a, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": z, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": z}
	await t.ticks(1)
	t.check(piles.size() == 1 and piles[0][1] == &"bones", "stockpile designated in the hollow, kind picked with alt (%s)" % [piles])
	Events.stockpile_designated.disconnect(on_pile)
