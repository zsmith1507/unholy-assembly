extends RefCounted
## Round 5 (Zach's playtest notes 1, 4, 5, 6, 8, 12, 14): slower digging that talents improve, the talent
## and skill trees, the knife, Harvest into the satchel, build placement from a menu, doors, shroud skills.

const U := preload("res://necro/tests/necro_test_util.gd")
const StandInBuilder := preload("res://necro/demo/stand_in_builder.gd")


const StandInBody := preload("res://necro/demo/stand_in_body.gd")


class StandInHuman extends Actor:
	func _init() -> void:
		faction = Faction.HUMAN
		max_hp = 30.0
		box_size = Vector2(14, 56)


class StandInDoor extends Node2D:
	var to := Vector2.ZERO
	var used := 0
	func _ready() -> void:
		add_to_group("doors")
	func interact(by: Node2D) -> void:
		used += 1
		by.global_position = to


class StandInShroud extends Node:
	var reveal_radius_cells := 12
	var corpse_sense_radius_px := 0.0
	func _ready() -> void:
		add_to_group("shroud")


func _dig_cells(t, n: Necromancer, ticks: int) -> Array:
	var dig = n.get_spell(&"dig")
	n.select_spell_id(&"dig")
	GameState.max_mana = 10.0
	GameState.mana = 10.0
	var r0: int = dig.removed_total
	for i in ticks:
		n.script_input = {"cast": true, "aim": n.global_position + Vector2(30.0 + i * 0.4, 34.0)}
		await t.ticks(1)
	n.script_input = {}
	return [dig.removed_total - r0, 10.0 - GameState.mana]


func run(t) -> void:
	var n: Necromancer = U.setup(t)
	await t.ticks(20)
	var tl = t.tree.get_first_node_in_group("talents")
	t.check(tl == n.get_talents() and tl != null, "the talents node is in group talents")

	# --- note 4: digging starts slow and cheap
	var base: Array = await _dig_cells(t, n, 120)
	t.check(absf(base[1] - 0.08) < 0.01, "dig costs 0.04 a second at first (spent %.3f in 2 s)" % base[1])

	# --- note 5: the trees
	var trees: Array = tl.trees()
	t.check(trees.size() == 2 and trees[0].kind == "talent" and trees[1].kind == "skill", "two trees: talents and skills")
	var nd: Dictionary = trees[0].nodes[0]
	for key in ["id", "name", "desc", "cost", "max_rank", "rank", "requires", "pos"]:
		t.check(nd.has(key), "tree nodes carry %s" % key)
	t.check(tl.points() == 1, "one point to spend at the start")
	var pts := []
	var on_pts := func(p): pts.append(p)
	Events.skill_points_changed.connect(on_pts)
	var learned := []
	var on_learn := func(id, r): learned.append([id, r])
	Events.talent_learned.connect(on_learn)
	t.check(not tl.can_learn(&"dig_radius"), "Wide Bore needs Hungry Earth first")
	t.check(tl.learn(&"dig_speed") and tl.rank(&"dig_speed") == 1, "learn Hungry Earth")
	t.check(learned == [[&"dig_speed", 1]] and pts.back() == 0, "learning emits talent_learned and skill_points_changed")
	t.check(not tl.learn(&"dig_efficiency"), "no points, no learning")
	n.position.x += 60.0
	await t.ticks(5)
	var faster: Array = await _dig_cells(t, n, 120)
	t.check(faster[0] > base[0] * 1.2, "Hungry Earth digs faster (%d -> %d cells in 2 s)" % [base[0], faster[0]])

	# points from progress
	Events.soul_collected.emit(3.0, "test", Vector2.ZERO)
	Events.heart_placed.emit(Vector2.ZERO, 100.0)
	Events.heart_placed.emit(Vector2.ZERO, 100.0)
	var h1 := StandInHuman.new(); t.root.add_child(h1)
	Events.human_killed.emit(h1, false)
	Events.human_killed.emit(h1, false)
	h1.queue_free()
	t.check(tl.points() == 3, "a point each for 3 souls, the first heart, and 2 human kills (%d)" % tl.points())
	t.check(tl.learn(&"dig_efficiency"), "learn Thrifty Grave-Wind")
	n.position.x += 60.0
	await t.ticks(5)
	var cheaper: Array = await _dig_cells(t, n, 120)
	t.check(cheaper[1] < base[1] * 0.85, "Thrifty Grave-Wind costs less (%.3f -> %.3f in 2 s)" % [base[1], cheaper[1]])
	var mm := GameState.max_mana
	t.check(tl.learn(&"mana_well") and absf(GameState.max_mana - mm - 0.5) < 0.001, "Deeper Well adds half a soul of bar")
	Events.skill_points_changed.disconnect(on_pts)
	Events.talent_learned.disconnect(on_learn)

	# --- note 12: shroud skills
	var shroud := StandInShroud.new()
	t.root.add_child(shroud)
	tl.grant_points(4)
	t.check(not tl.can_learn(&"corpse_sense"), "Corpse Sense needs Spirit Vision")
	t.check(tl.learn(&"spirit_vision") and shroud.reveal_radius_cells > 12, "Spirit Vision widens the shroud's reveal (%d cells)" % shroud.reveal_radius_cells)
	t.check(tl.learn(&"corpse_sense") and shroud.corpse_sense_radius_px > 100.0, "Corpse Sense turns on (%.0f px)" % shroud.corpse_sense_radius_px)
	t.check(not tl.can_learn(&"soul_pull"), "Soul Pull is there but not learnable yet")
	# fresh ground for the rest (the digging above left pits)
	t.flat_world()
	n.position = Vector2(160, 100 * Sim.CELL)
	n.velocity = Vector2.ZERO
	GameState.max_mana = 1.0
	GameState.mana = 1.0
	await t.ticks(5)

	# --- note 8: the knife kills a human, no mana
	var h := StandInHuman.new()
	h.position = n.global_position + Vector2(24, 0)
	t.root.add_child(h)
	await t.ticks(3)
	var deaths := []
	var on_die := func(a, k, _at): deaths.append([a, k])
	Events.actor_died.connect(on_die)
	var noises := []
	var on_noise := func(_at, l, src): if src == "knife": noises.append(l)
	Events.noise_made.connect(on_noise)
	var m0 := GameState.mana
	for i in 6:
		n.script_input = {"attack": true, "aim": h.get_box().get_center()}
		await t.ticks(1)
		n.script_input = {"aim": h.get_box().get_center()}
		await t.ticks(int(Necromancer.KNIFE.cooldown_ticks))
		if h.dead:
			break
	t.check(h.dead and n.knife_hits == 3, "three stabs kill a 30 hp villager (%d hits)" % n.knife_hits)
	t.check(deaths.size() == 1 and deaths[0][1] == n, "the kill is his")
	t.check(absf(GameState.mana - m0) < 0.0001, "the knife costs no mana")
	t.check(not noises.is_empty() and noises[0] < 0.1, "a stab makes a little noise")
	Events.actor_died.disconnect(on_die)
	Events.noise_made.disconnect(on_noise)
	h.queue_free()
	# Wicked Edge cuts deeper
	var h2 := StandInHuman.new()
	h2.position = n.global_position + Vector2(24, 0)
	t.root.add_child(h2)
	await t.ticks(30)
	tl.grant_points(1)
	tl.learn(&"knife_edge")
	n.script_input = {"attack": true, "aim": h2.get_box().get_center()}
	await t.ticks(1)
	n.script_input = {}
	t.check(absf(h2.hp - 15.0) < 0.01, "Wicked Edge: a stab does 15 (hp %.1f)" % h2.hp)
	h2.queue_free()
	await t.ticks(30)

	# --- note 14: Harvest takes a body into the satchel
	GameState.inventory = {}
	var body := StandInBody.new()
	body.box_size = Vector2(20, 8)
	body.kind = &"corpse"
	body.position = n.global_position + Vector2(100, -4)
	t.root.add_child(body)
	await t.ticks(5)
	n.select_spell_id(&"harvest")
	var harvest = n.get_spell(&"harvest")
	var announced := []
	var on_h := func(it): announced.append(it)
	Events.body_harvested.connect(on_h)
	GameState.mana = 1.0
	var hm0 := GameState.mana
	var ticks := 0
	for i in 300:
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			break
		n.script_input = {"cast": true, "aim": body.get_box().get_center()}
		await t.ticks(1)
		ticks += 1
	n.script_input = {}
	Events.body_harvested.disconnect(on_h)
	t.check(announced.size() == 1, "the harvest is announced")
	t.check(GameState.item_count(&"flesh") == 2.0 and GameState.item_count(&"bones") == 1.0 and GameState.item_count(&"blood") == 1.0, "the body goes into the satchel (%s)" % [GameState.inventory])
	t.check(not harvest.popups.is_empty(), "a +flesh pop-up shows")
	t.note("harvesting a body took %.1f s and %.3f mana" % [ticks / 60.0, hm0 - GameState.mana])
	t.check(hm0 - GameState.mana < 0.05, "harvesting a body is cheap (%.3f)" % (hm0 - GameState.mana))

	# --- note 6: build placement from the menu
	var b := StandInBuilder.new()
	t.root.add_child(b)
	await t.ticks(2)
	var started := []
	var ended := []
	var on_s := func(k): started.append(k)
	var on_e := func(k, placed): ended.append([k, placed])
	Events.build_placement_started.connect(on_s)
	Events.build_placement_ended.connect(on_e)
	t.check(not n.begin_placement(&"grinder"), "can't place a grinder before the heart")
	var at := n.global_position + Vector2(70, -20)
	# the menu click is still held when placement starts: it must not place
	n.script_input = {"aim": at, "cast": true}
	t.check(n.begin_placement(&"heart") and n.placing, "begin_placement shows the heart's ghost")
	await t.ticks(2)
	t.check(b.placed.is_empty(), "the click that chose it from the menu doesn't place it")
	n.script_input = {"aim": at}
	await t.ticks(2)
	t.check(n.get_selected().ghost_ok, "ghost is green (%s)" % n.get_selected().ghost_reason)
	n.script_input = {"aim": at, "cast": true}
	await t.ticks(1)
	n.script_input = {"aim": at}
	await t.ticks(1)
	t.check(b.placed.size() == 1 and b.placed[0].kind == &"heart", "cast places the heart")
	t.check(not n.placing, "placement ends after placing")
	t.check(started == [&"heart"] and ended == [[&"heart", true]], "placement started/ended events (%s %s)" % [started, ended])
	# cancel with the alternate button; the spell bar comes back
	t.check(n.begin_placement(&"grinder"), "now the grinder")
	n.script_input = {"aim": at, "cast_alt": true}
	await t.ticks(1)
	n.script_input = {}
	await t.ticks(1)
	t.check(not n.placing and ended.back() == [&"grinder", false], "cast_alt cancels placement")
	t.check(b.placed.size() == 1, "nothing placed on cancel")
	Events.build_placement_started.disconnect(on_s)
	Events.build_placement_ended.disconnect(on_e)

	# --- note 1: doors
	var door := StandInDoor.new()
	door.position = n.global_position + Vector2(6, 0)
	door.to = n.global_position + Vector2(-90, 0)
	t.root.add_child(door)
	await t.ticks(2)
	t.check(n.get_interact_hint() != "", "a hint at the door")
	var y0 := n.global_position.y
	n.script_input = {"move": Vector2(0, -1), "jump": true}
	await t.ticks(4)
	t.check(door.used == 1, "up at a door goes through it")
	t.check(n.global_position.y > y0 - 3.0, "and doesn't also jump")
	n.script_input = {}
	await t.ticks(2)
	door.position = n.global_position + Vector2(-4, 0)
	door.to = n.global_position + Vector2(90, 0)
	n.script_input = {"interact": true}
	await t.ticks(2)
	n.script_input = {}
	t.check(door.used == 2, "interact at a door goes through it too")
	door.position.x += 300
	await t.ticks(2)
	n.script_input = {"move": Vector2(0, -1), "jump": true}
	await t.ticks(6)
	n.script_input = {}
	t.check(n.global_position.y < y0 - 3.0, "away from doors, W still jumps")
