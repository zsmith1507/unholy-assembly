extends RefCounted
## Threats against the real World and Bodies and Souls code (skipped when their installers are missing).
## World's towns, homes, graves and patrol routes; real Human farmers on patrol; a real grave body exhumed;
## a real resident killed out of town.

const NEED := ["res://world/install.gd", "res://flesh/install.gd"]


func run(t) -> void:
	for p in NEED:
		if not ResourceLoader.exists(p):
			t.note("skipped: %s is not in this branch (merge World and Bodies and Souls to run it)" % p)
			return
	var fake := _Main.new()
	fake.name = "Main"
	for n in ["terrain", "buildings", "items", "actors", "fx"]:
		var l := Node2D.new()
		l.name = n
		fake.add_child(l)
		fake.set(n, l)
	var ui := CanvasLayer.new()
	ui.name = "ui"
	fake.add_child(ui)
	fake.ui = ui
	t.root.add_child(fake)
	Sim.create(1536, 768, 1)
	var info: Dictionary = load("res://world/install.gd").new().install(fake, {})
	info.merge(load("res://flesh/install.gd").new().install(fake, info), true)
	load("res://threats/install.gd").new().install(fake, info)
	Threats.end_grace() # these checks are about what happens after the grace period
	Threats.auto_tick = false
	var patrols: Node = Threats.patrols
	t.check(patrols != null, "installer added the patrols")

	# World's data reaches us
	var towns: Array = info.get("towns", [])
	t.check(towns.size() >= 2 and info.get("patrol_routes", []).size() >= towns.size(), "World gave towns and patrol routes")
	var pop := Threats.town_population(0)
	var homes_n := 0
	for h in towns[0].homes:
		homes_n += int(h.residents)
	t.check(pop == homes_n and pop > 0, "town 0's population %d comes from World's homes (%d)" % [pop, homes_n])

	# a real grave body: Harvest's first touch (exhume) means a robbed grave, coffin wood intact
	var buried: Array = t.root.get_tree().get_nodes_in_group(&"grave_corpses")
	t.check(buried.size() > 0, "Bodies and Souls buried %d bodies" % buried.size())
	Threats.simulate(5.0, 1.0)
	t.check(Threats.graves_waiting_to_be_found() == 0, "no grave robbed yet")
	if buried.size() > 0:
		buried[0].exhume()
		Threats.simulate(5.0, 1.0)
		t.check(Threats.graves_waiting_to_be_found() == 1, "an exhumed body is a robbed grave")

	# a real patrol of real farmers along World's route
	GameState.suspicion = 45.0
	GameState.hour = 10.0
	var p: Dictionary = patrols.send(0)
	t.check(not p.is_empty() and p.members.size() == Threats.patrol_size(45.0), "patrol of %d left town 0" % (p.members.size() if not p.is_empty() else 0))
	if p.is_empty():
		fake.queue_free()
		return
	var m: Node2D = p.members[0]
	t.check(m.is_in_group(&"human_actors") and String(m.get("kind")) == "farmer", "members are Bodies and Souls farmers")
	var route: PackedVector2Array = m.get("route")
	var centre: float = (towns[0].rect as Rect2).get_center().x
	t.check(route.size() > 2 and absf(route[0].x - centre) < 4.0, "they walk World's route from the town centre")
	t.check(m.get("mode") == &"patrol", "mode is patrol")
	await t.ticks(30)

	# the farmer sees a minion: Events.sighting from the real Human -> a pending report and an alarm
	var ghoul := Node2D.new()
	ghoul.add_to_group(&"minions")
	ghoul.position = m.global_position + Vector2(40 * int(m.get("facing")), 0)
	fake.get_node("actors").add_child(ghoul)
	var alarms := []
	Threats.alarm_raised.connect(func(_a, _r, _b): alarms.append(1))
	await t.ticks(30)
	t.check(Threats.pending_reports.size() > 0, "the farmer is running home to report the minion")
	t.check(alarms.size() > 0, "the farmer raised the alarm")
	ghoul.queue_free()

	# a resident killed out in the forest: missing, and their own town shrinks
	var res: Node2D = null
	for h in t.root.get_tree().get_nodes_in_group(&"human_actors"):
		if int(h.get("home_id")) >= 0:
			res = h
			break
	t.check(res != null, "found a resident")
	if res != null:
		var tname: String = Threats._town_name(Threats._home_town(res))
		res.global_position = Vector2(Sim.world_size_px().x * 0.5, res.global_position.y)
		res.die(null)
		var hit := false
		for e in Threats.ledger:
			if e.key == "missing" and String(e.text).contains(tname):
				hit = true
		t.check(hit, "the ledger says a resident of %s went missing" % tname)

	Threats.auto_tick = true
	fake.queue_free()
	await t.ticks(2)
	Threats.reset()
	GameState.reset()


class _Main extends Node2D:
	var terrain: Node
	var buildings: Node
	var items: Node
	var actors: Node
	var fx: Node
	var ui: Node
