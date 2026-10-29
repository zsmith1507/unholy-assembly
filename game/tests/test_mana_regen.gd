extends RefCounted
## Mana comes back slowly on its own, but only after a pause since the last spell, and never past the bar.

func run(t) -> void:
	var E: Dictionary = GameState.ECON
	GameState.reset()
	t.check(GameState.spend_mana(GameState.max_mana), "spending the whole bar works")
	t.check(GameState.mana < 0.001, "the bar is empty")

	await t.ticks(int(E.mana_regen_delay * 60.0 * 0.5))
	t.check(GameState.mana < 0.001, "nothing comes back during the pause after a spell")

	await t.ticks(int(E.mana_regen_delay * 60.0 * 0.5) + 120)
	var expect: float = E.mana_regen_per_sec * 2.0
	t.note("mana after the pause plus 2 s: %.3f (expected about %.3f)" % [GameState.mana, expect])
	t.check(GameState.mana > expect * 0.5 and GameState.mana < expect * 2.0, "mana regenerates at about ECON.mana_regen_per_sec")

	GameState.spend_mana(0.001)
	var before := GameState.mana
	await t.ticks(30)
	t.check(GameState.mana <= before + 0.0001, "casting again restarts the pause")

	GameState.reset()
	await t.ticks(30)
	t.check(GameState.mana <= GameState.max_mana + 0.0001, "never fills past the bar")
