extends RefCounted
## A ghoul hauls a corpse into the grinder; morale falls to a strike and a motivational visit ends it;
## the spike trap skewers the living; a dying ghoul gives its soul back; the heart takes everything with it.

class FakeSpawner extends Node:
	var orbs := 0
	func _ready() -> void:
		add_to_group(&"flesh_spawner")
	func spawn_soul_orb(at: Vector2, _amount: float, _source: String) -> Node2D:
		orbs += 1
		var n := Node2D.new()
		add_child(n)
		n.global_position = at
		return n


func run(t) -> void:
	Jobs.reset()
	var w: SandWorld = t.flat_world(256, 160, 100)
	w.fill_rect(10, 60, 236, 40, SandWorld.M_EMPTY) # a dug hall, floor at y = 200 px
	var d := LairDirector.new()
	d.layers = {"items": t.root, "actors": t.root, "buildings": t.root}
	t.root.add_child(d)
	var b := LairBuilder.new()
	b.parent_layer = t.root
	t.root.add_child(b)
	var sp := FakeSpawner.new()
	t.root.add_child(sp)
	var heart: NecroticHeart = b.place(&"heart", Vector2(256, 200))
	var grinder: LairMachine = b.place(&"grinder", Vector2(140, 200))
	t.check(heart != null and grinder != null, "heart and grinder placed")

	# --- a ghoul hauls a corpse into the grinder
	var g := LairMinion.make(&"ghoul")
	t.root.add_child(g)
	g.global_position = Vector2(330, 200)
	var corpse := Lair.spawn_item(t.tree, &"corpse", Vector2(380, 196), t.root)
	var ground := false
	for i in 40:
		await t.ticks(30)
		if int(GameState.stats.get("bodies_ground", 0)) >= 1 or grinder.working:
			ground = true
			break
	t.check(ground, "ghoul hauled the corpse into the grinder")
	t.check(not is_instance_valid(corpse) or corpse.is_queued_for_deletion(), "the corpse went in")

	# --- unions: morale sinks to a strike, a motivational visit ends it
	d.morale = 5.0
	await t.ticks(2)
	t.check(d.stage == 3 and g.on_strike, "morale below the line: the ghouls strike")
	t.check(g.is_in_group(&"interactable") and g.interact_hint() != "", "a striker can be visited")
	g.interact(null)
	await t.ticks(2)
	t.check(not g.on_strike and d.stage == 0, "the motivational visit ends the strike")

	# --- spike trap skewers the living, not the dead
	var trap: LairSpikeTrap = b.place(&"spike_trap", Vector2(200, 200))
	t.check(trap != null, "spike trap placed")
	var victim := Actor.new()
	victim.faction = Actor.Faction.HUMAN
	t.root.add_child(victim)
	victim.global_position = Vector2(200, 200)
	await t.ticks(3)
	t.check(victim.dead or victim.hp < victim.max_hp, "the trap skewers a living thing")
	t.check(not trap.armed, "the trap needs re-arming")

	# --- a ghoul dying gives its soul back (orb from the flesh spawner)
	var o0 := sp.orbs
	g.die(null)
	await t.ticks(2)
	t.check(sp.orbs == o0 + 1, "a dead ghoul drops a soul orb")

	# --- destroying the heart takes the lair with it
	var g2 := LairMinion.make(&"ghoul")
	t.root.add_child(g2)
	g2.global_position = Vector2(300, 200)
	await t.ticks(2)
	heart.destroy()
	await t.ticks(3)
	t.check(not GameState.has_heart, "heart gone from GameState")
	t.check(not is_instance_valid(grinder) and not is_instance_valid(trap), "buildings fall with the heart")
	t.check(not is_instance_valid(g2) or g2.dead, "minions fall with the heart")
