class_name LairDirector
extends Node2D
## Runs the lair's logistics (group `lair_director`): stockpiles from `Events.stockpile_designated`, haul jobs
## (loose items to machines that want them, finished goods to stockpiles), and ghoul morale and unions.

const LOGISTICS := {
	"haul_priority": 5,
	"haul_to_machine_priority": 4,
	"post_every_s": 0.5,
}
## Light needs: morale falls with work and rises with rest and food. Below the thresholds: memo, slowdown, strike.
const MORALE := {
	"start": 80.0,
	"loss_per_ghoul_job_s": 0.06, # per second, per busy ghoul, averaged over the crew
	"rest_gain_s": 0.4, # per second while idle
	"complain_below": 50.0,
	"slowdown_below": 30.0,
	"strike_below": 12.0,
	"strike_over_above": 45.0,
	"slowdown_speed": 0.5,
	"visit_bonus": 40.0, # the necromancer's motivational visit (interact with a striker)
}

var layers := {} ## name -> Node for "buildings", "items", "actors", "fx"
var stockpiles: Array = [] ## {rect: Rect2i (cells), kind: StringName}
var morale: float = MORALE.start
var stage := 0 ## 0 fine, 1 complained, 2 slowdown, 3 strike
var _post_t := -INF


func _ready() -> void:
	add_to_group(&"lair_director")
	if not Events.stockpile_designated.is_connected(_on_stockpile):
		Events.stockpile_designated.connect(_on_stockpile)


func get_layer(layer_name: String) -> Node:
	return layers.get(layer_name)


# ---------------------------------------------------------------- stockpiles

func _on_stockpile(rect: Rect2i, kind: StringName) -> void:
	var k: StringName = Lair.STOCKPILE_ALIASES.get(kind, kind)
	if Lair.is_raw(k):
		LairText.say("stockpile_refused", &"concerned")
		return
	stockpiles.append({"rect": rect, "kind": k})
	LairText.say("stockpile_made", &"chipper", {"kind": String(k).replace("_", " ")})
	queue_redraw()


func clear_stockpiles() -> void:
	stockpiles.clear()
	queue_redraw()


func stockpile_for(kind: StringName) -> Dictionary:
	for s in stockpiles:
		if s.kind == kind:
			return s
	return {}


func _in_any_stockpile(p: Vector2) -> bool:
	var c := Sim.to_cell(p - Vector2(0, 1))
	for s in stockpiles:
		if (s.rect as Rect2i).grow(1).has_point(c):
			return true
	return false


## Post haul jobs for loose items that have somewhere to go and no job yet. Cheap; ghouls call it.
func post_haul_jobs() -> void:
	# game time, not wall time: headless runs go faster than real time
	var now := float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
	if now - _post_t < float(LOGISTICS.post_every_s):
		return
	_post_t = now
	var taken := {}
	var pending := {} # machine id -> kind -> count already on the way
	for j in Jobs.all_jobs():
		if j.type == Jobs.HAUL and j.get("item") != null and is_instance_valid(j.item):
			taken[j.item.get_instance_id()] = true
			var t = j.get("target")
			if t is LairMachine:
				var per: Dictionary = pending.get(t.get_instance_id(), {})
				var k := Lair.item_kind(j.item)
				per[k] = int(per.get(k, 0)) + 1
				pending[t.get_instance_id()] = per
	var machines := get_tree().get_nodes_in_group(&"lair_machines")
	for it in get_tree().get_nodes_in_group(&"items"):
		if taken.has(it.get_instance_id()) or not Lair.item_free(it):
			continue
		var k := Lair.item_kind(it)
		var p: Vector2 = it.global_position
		if GameState.has_heart and not GameState.in_heart_range(p):
			continue
		# to the nearest machine that still wants this kind
		var best: Node = null
		var best_d := INF
		for m in machines:
			var want: int = m.wants(k) - int(pending.get(m.get_instance_id(), {}).get(k, 0))
			if want <= 0 or m.get_rect().grow(6).has_point(p):
				continue
			var d := p.distance_to(m.global_position)
			if d < best_d:
				best_d = d
				best = m
		if best != null:
			Jobs.post({"type": Jobs.HAUL, "item": it, "target": best, "priority": LOGISTICS.haul_to_machine_priority})
			var per2: Dictionary = pending.get(best.get_instance_id(), {})
			per2[k] = int(per2.get(k, 0)) + 1
			pending[best.get_instance_id()] = per2
			continue
		if Lair.is_raw(k) or _in_any_stockpile(p):
			continue
		var sp := stockpile_for(k)
		if not sp.is_empty():
			var r: Rect2i = sp.rect
			var spot := Sim.to_pixel(Vector2i(r.position.x + randi() % maxi(1, r.size.x), r.end.y))
			Jobs.post({"type": Jobs.HAUL, "item": it, "pos": spot, "priority": LOGISTICS.haul_priority})


# ---------------------------------------------------------------- morale and unions

func _physics_process(delta: float) -> void:
	var ghouls := get_tree().get_nodes_in_group(&"lair_ghoul")
	if ghouls.is_empty():
		return
	var busy := 0
	for g in ghouls:
		if not (g.get("job") as Dictionary).is_empty():
			busy += 1
	var idle := ghouls.size() - busy
	morale += (float(idle) * float(MORALE.rest_gain_s) - float(busy) * float(MORALE.loss_per_ghoul_job_s) * 4.0) \
		/ float(ghouls.size()) * delta
	morale = clampf(morale, 0.0, 100.0)
	_update_stage(ghouls)


func _update_stage(ghouls: Array) -> void:
	var s := stage
	if stage == 3:
		if morale >= float(MORALE.strike_over_above):
			s = 0
			Narrative.say(LairText.t("memo_strike_over"), &"memo")
	elif morale < float(MORALE.strike_below):
		s = 3
		Narrative.say(LairText.t("memo_strike"), &"memo")
		GameState.count("strikes")
	elif morale < float(MORALE.slowdown_below) and stage < 2:
		s = 2
		Narrative.say(LairText.t("memo_slowdown"), &"memo")
	elif morale < float(MORALE.complain_below) and stage < 1:
		s = 1
		Narrative.say(LairText.t("memo_complaint", {"need": LairText.t("need_rest")}), &"memo")
	elif morale >= float(MORALE.complain_below) + 10.0 and stage in [1, 2]:
		s = 0
	stage = s
	for g in ghouls:
		var striking := stage == 3
		if striking and not g.on_strike:
			g.job = {} if g.job.is_empty() else g.job
			if not g.job.is_empty():
				Jobs.release(g.job.id)
				g.job = {}
			g.add_to_group(&"interactable")
		elif not striking and g.on_strike:
			g.remove_from_group(&"interactable")
		g.on_strike = striking
		g.morale_speed = float(MORALE.slowdown_speed) if stage == 2 else 1.0


## The necromancer's motivational visit. Consequences either way: morale up, a little Suspicion from the shouting.
func motivational_visit() -> void:
	morale = clampf(morale + float(MORALE.visit_bonus), 0.0, 100.0)
	Narrative.say(LairText.t("memo_motivated"), &"memo")
	Events.noise_made.emit(GameState.heart_pos, 0.3, "motivational_visit")


func _draw() -> void:
	for s in stockpiles:
		var r: Rect2i = s.rect
		var pr := Rect2(Sim.to_pixel(r.position), Vector2(r.size) * Sim.CELL)
		var c: Color = LairItem.COLORS.get(s.kind, Color.WHITE)
		draw_rect(pr, Color(c.r, c.g, c.b, 0.08))
		draw_rect(pr, Color(c.r, c.g, c.b, 0.35), false, 1.0)
