extends RefCounted
## Humans: the Human orders hook (set_route, investigate, set_mode, fear, noticed) as Threats uses it,
## home at night, noticing the undead, fleeing by fear, bracing against Harvest, and dying into a
## bleeding corpse with a soul (if the necromancer is there), Events.human_killed and settlements.resident_died.


class FakeSettlements extends Node:
	var died: Array = []

	func _ready() -> void:
		add_to_group(&"settlements")

	func resident_died(id: int) -> void:
		died.append(id)


func run(t) -> void:
	t.flat_world(512, 160, 100)
	var ground := 200.0
	GameState.hour = 12.0
	var sp := FleshSpawner.new()
	sp.actors_layer = t.root
	sp.items_layer = t.root
	t.root.add_child(sp)
	var towns := FakeSettlements.new()
	t.root.add_child(towns)

	# --- spawning through the hook; only adults, only the kinds in the contract
	var h: Human = sp.spawn_human(&"farmer", Vector2(200, 120))
	t.check(h != null and h.is_in_group(&"humans") and h.kind == &"farmer", "spawn_human gives a farmer in group humans")
	var odd: Human = sp.spawn_human(&"child", Vector2(700, 120))
	t.check(odd.kind == &"villager", "an unknown kind is spawned as an adult villager")
	odd.queue_free()
	await t.ticks(30)
	t.check(absf(h.global_position.y - ground) < 3.0, "spawned on the ground (feet at %.0f)" % h.global_position.y)
	t.check("fear" in h and h.has_signal("noticed") and h.has_method("set_route") and h.has_method("investigate") and h.has_method("set_mode"), "speaks the Human orders hook")

	# --- patrol a route
	h.set_route(PackedVector2Array([Vector2(200, ground), Vector2(420, ground)]))
	h.set_mode(&"patrol")
	var x0 := h.global_position.x
	var far := x0
	for i in 400:
		await t.ticks(1)
		far = maxf(far, h.global_position.x)
	t.check(far > 400.0, "patrols along the route (got to x=%.0f)" % far)

	# --- investigate
	h.investigate(Vector2(260, ground))
	for i in 300:
		await t.ticks(1)
		if absf(h.global_position.x - 260.0) < 10.0:
			break
	t.check(absf(h.global_position.x - 260.0) < 12.0, "walks over to investigate (x=%.0f)" % h.global_position.x)
	h.set_mode(&"work")
	for i in 300:
		if h.current_mode() != &"investigate":
			break
		await t.ticks(1)

	# --- night sends workers home
	GameState.hour = 23.0
	t.check(h.current_mode() == &"home", "at night a worker heads home")
	GameState.hour = 12.0

	# --- notice the necromancer, report it, flee
	var necro := Node2D.new()
	necro.add_to_group(&"necro")
	necro.position = Vector2(h.global_position.x + 90.0, ground)
	t.root.add_child(necro)
	h.facing = 1
	h.set_mode(&"patrol")
	h.set_route(PackedVector2Array([Vector2(h.global_position.x + 60.0, ground)]))
	var seen := []
	var sightings := []
	var on_n := func(w): seen.append(w)
	var on_s := func(wit, of): sightings.append([wit, of])
	h.noticed.connect(on_n)
	Events.sighting.connect(on_s)
	await t.ticks(30)
	#t.note("DBG h %s facing %d necro %s threat %s ray %s mode %s" % [h.global_position, h.facing, necro.global_position, h._threat, Sim.raycast_px(h.global_position + Vector2(0, -50), necro.global_position + Vector2(0, -30)), h.current_mode()])
	t.check(seen.size() == 1 and seen[0] == necro, "noticed(what) fires for the necromancer")
	t.check(sightings.size() >= 1 and sightings[0][0] == h, "and Events.sighting(witness, of)")
	var fled_from := h.global_position.x
	for i in 180:
		await t.ticks(1)
	t.check(h.fear >= 0.4, "fear rises while the undead are in sight (%.2f)" % h.fear)
	t.check(h.current_mode() == &"flee" and h.global_position.x < fled_from - 30.0, "and they run away (%.0f -> %.0f)" % [fled_from, h.global_position.x])
	h.noticed.disconnect(on_n)
	Events.sighting.disconnect(on_s)

	# --- Threats sets fear directly; an ordered attack breaks at high fear
	h.set_mode(&"attack")
	h.fear = 0.2
	t.check(h.current_mode() == &"attack", "an ordered attack holds while fear is low")
	h.fear = 0.95
	t.check(h.current_mode() == &"flee", "and breaks into flight when terrified")

	# --- a calm human braces against Harvest; a terrified one is dragged
	var calm: Human = sp.spawn_human(&"villager", Vector2(800, 150))
	await t.ticks(20)
	calm.set_mode(&"patrol")
	calm.set_route(PackedVector2Array([calm.global_position]))
	calm.fear = 0.0
	var c0 := calm.global_position.x
	for i in 20:
		calm.fear = 0.0
		calm.apply_pull(Vector2(0.5, 0))
		await t.ticks(1)
	var calm_moved := calm.global_position.x - c0
	h.set_mode(&"patrol")
	h.set_route(PackedVector2Array([h.global_position]))
	var h0 := h.global_position.x
	for i in 20:
		h.fear = 1.0
		h.apply_pull(Vector2(0.5, 0))
		await t.ticks(1)
	var scared_moved := h.global_position.x - h0
	t.check(scared_moved > calm_moved + 2.0, "a terrified human is dragged further than a calm one (%.1f vs %.1f px)" % [scared_moved, calm_moved])

	# --- death: corpse, blood, soul, signals, settlements
	h.home_id = 7
	necro.position = h.global_position + Vector2(60, 0)
	var killed := []
	var on_k := func(a, wit): killed.append(wit)
	Events.human_killed.connect(on_k)
	var at := h.global_position
	h.take_damage(999.0, necro)
	await t.ticks(2)
	Events.human_killed.disconnect(on_k)
	t.check(killed == [true], "Events.human_killed fires, witnessed by the necromancer")
	t.check(towns.died == [7], "settlements.resident_died(home_id) is called")
	var corpses: Array = t.root.get_children().filter(func(n): return n is Corpse)
	t.check(corpses.size() == 1 and corpses[0].fresh and corpses[0].look == "farmer", "a fresh farmer corpse is left")
	var orbs: Array = t.root.get_children().filter(func(n): return n is SoulOrb)
	t.check(orbs.size() == 1 and orbs[0].amount == 1.0 and not orbs[0].fragment, "a whole soul is released")
	t.check(int(GameState.stats.get("humans_killed", 0)) == 1, "the kill is counted")

	# --- a death with nobody there: no soul
	var lone: Human = sp.spawn_human(&"villager", Vector2(900, 150))
	await t.ticks(10)
	necro.position = Vector2(50, ground)
	lone.take_damage(999.0, null)
	await t.ticks(2)
	orbs = t.root.get_children().filter(func(n): return n is SoulOrb and n.global_position.x > 850.0)
	t.check(orbs.is_empty(), "a death far from the necromancer (and any heart) releases no soul")
