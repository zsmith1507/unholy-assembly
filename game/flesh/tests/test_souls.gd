extends RefCounted
## Soul orbs and critters: orbs in the heart's range drift home and pay GameState; a minion's orb far
## from home fades unless the necromancer reaches it; critters bolt from him, crows take wing, and a
## critter killed near him gives a soul fragment.


func run(t) -> void:
	t.flat_world(512, 160, 100)
	var ground := 200.0
	GameState.hour = 12.0
	var sp := FleshSpawner.new()
	sp.actors_layer = t.root
	sp.items_layer = t.root
	t.root.add_child(sp)
	t.check(sp.is_in_group(&"flesh_spawner"), "the spawner is in group flesh_spawner")
	var heart := Node2D.new()
	heart.position = Vector2(100, ground - 20)
	t.root.add_child(heart)
	GameState.set_heart(heart, 150.0)

	# --- an orb in the heart's range drifts home
	var s0 := GameState.souls
	var orb: Node2D = sp.spawn_soul_orb(Vector2(220, ground - 30), 1.0, "Ghoul")
	t.check(orb is SoulOrb and not orb.fades, "spawn_soul_orb in the heart's range gives an orb that won't fade")
	for i in 400:
		await t.ticks(1)
		if not is_instance_valid(orb):
			break
	t.check(not is_instance_valid(orb) and is_equal_approx(GameState.souls - s0, 1.0), "it drifts into the heart: +1 soul (%.2f)" % (GameState.souls - s0))

	# --- a minion's orb far from home fades if nobody comes
	var lost: SoulOrb = sp.spawn_soul_orb(Vector2(800, ground - 30), 1.0, "Ghoul")
	t.check(lost.fades, "outside the heart's range the orb fades")
	lost.life = 0.5
	await t.ticks(45)
	t.check(not is_instance_valid(lost), "and is gone when its time runs out")

	# --- ...unless the necromancer gets to it in time
	var necro := Node2D.new()
	necro.add_to_group(&"necro")
	necro.position = Vector2(700, ground)
	t.root.add_child(necro)
	var saved: SoulOrb = sp.spawn_soul_orb(Vector2(820, ground - 30), 1.0, "Ghoul")
	await t.ticks(10)
	t.check(not saved.claimed, "not his until he comes close")
	necro.position = Vector2(815, ground)
	await t.ticks(5)
	t.check(saved.claimed, "he claims it by walking up to it")
	s0 = GameState.souls
	for i in 600:
		await t.ticks(1)
		if not is_instance_valid(saved):
			break
	t.check(not is_instance_valid(saved) and is_equal_approx(GameState.souls - s0, 1.0), "a claimed orb flies home to the heart")

	# --- critters through the hook
	var kinds := [&"rabbit", &"deer", &"crow"]
	var cs: Array = []
	for i in 3:
		cs.append(sp.spawn_critter(kinds[i], Vector2(300 + i * 60, ground - 4)))
	await t.ticks(30)
	t.check(cs.all(func(c): return c is Critter and c.is_in_group(&"critters") and c.is_in_group(&"pullable")), "spawn_critter gives rabbits, deer and crows (pullable, group critters)")
	t.check(absf(cs[0].global_position.y - ground) < 4.0 and absf(cs[1].global_position.y - ground) < 4.0, "rabbit and deer stand on the ground")

	# --- they bolt from him; the crow takes wing
	var rabbit: Critter = cs[0]
	var crow: Critter = cs[2]
	var r0 := rabbit.global_position.x
	var cy0 := crow.global_position.y
	necro.position = Vector2(250, ground)
	await t.ticks(60)
	t.check(rabbit.global_position.x > r0 + 20.0, "the rabbit bolts away from him (%.0f -> %.0f)" % [r0, rabbit.global_position.x])
	necro.position = crow.global_position + Vector2(-60, 0)
	await t.ticks(40)
	t.check(crow.flying and crow.global_position.y < cy0 - 15.0, "the crow takes off (%.0f -> %.0f)" % [cy0, crow.global_position.y])

	# --- a kill near him gives a fragment that flies home
	var f0 := GameState.fragments
	var deer: Critter = cs[1]
	necro.position = deer.global_position + Vector2(-50, 0)
	deer.take_damage(999.0, necro)
	await t.ticks(2)
	var frags: Array = t.root.get_children().filter(func(n): return n is SoulOrb and n.fragment)
	t.check(frags.size() == 1 and frags[0].amount == 2.0, "a deer killed near him drops a fragment orb worth 2")
	for i in 600:
		await t.ticks(1)
		if frags.is_empty() or not is_instance_valid(frags[0]):
			break
	t.check(is_equal_approx(GameState.fragments - f0, 2.0), "the fragments reach the heart (%.1f)" % (GameState.fragments - f0))

	# --- a kill far from him and from the heart gives nothing
	necro.position = Vector2(50, ground)
	if is_instance_valid(crow):
		crow.global_position = Vector2(900, ground - 60)
		crow.take_damage(999.0, null)
	await t.ticks(2)
	frags = t.root.get_children().filter(func(n): return n is SoulOrb and n.global_position.x > 850.0)
	t.check(frags.is_empty(), "a critter dying unseen gives no fragment")
	t.check(int(GameState.stats.get("critters_killed", 0)) == 2, "critter kills are counted")
