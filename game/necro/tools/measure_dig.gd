extends RefCounted
## Not a test: a quick measurement of how fast Dig eats packed earth and what it costs.
## godot --headless --fixed-fps 60 --path game res://tests/runner.tscn -- --test=res://necro/tools/measure_dig.gd

const U := preload("res://necro/tests/necro_test_util.gd")


func run(t) -> void:
	var n: Necromancer = U.setup(t)
	await t.ticks(20)
	n.select_spell_id(&"dig")
	var dig = n.get_spell(&"dig")
	var talents = n.get_node_or_null("Talents")
	for pass_i in 2:
		if pass_i == 1:
			if talents == null:
				break
			talents.grant_points(99)
			for id in [&"dig_speed", &"dig_speed", &"dig_speed", &"dig_efficiency", &"dig_efficiency", &"dig_efficiency", &"dig_radius", &"dig_radius", &"dig_radius"]:
				talents.learn(id)
			n.position.x += 200.0 # fresh ground
			await t.ticks(10)
		GameState.max_mana = 10.0
		GameState.mana = 10.0
		var r0: int = dig.removed_total
		var m0 := GameState.mana
		# sweep the beam along a line 30 px under the surface, 4 seconds, the way you'd start a tunnel
		for i in 240:
			var aim := n.global_position + Vector2(30.0 + i * 0.4, 34.0)
			n.script_input = {"cast": true, "aim": aim}
			await t.ticks(1)
		n.script_input = {}
		var cells: int = dig.removed_total - r0
		var spent := m0 - GameState.mana
		t.note("%s: %d cells in 4 s (%.0f cells/s), %.3f mana spent (%.3f/s), %.0f cells per soul of mana, radius %.0f px" % [
			"base" if pass_i == 0 else "all dig talents", cells, cells / 4.0, spent, spent / 4.0, cells / maxf(spent, 0.0001), dig.radius_px() if dig.has_method("radius_px") else 32.0])
	t.check(true, "measured")
