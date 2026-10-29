class_name LairMachine
extends LairStructure
## A machine of the first chain: the corpse grinder, the stitching table and the reanimation altar.
## Items dropped on (or hauled into) its footprint are taken into its hopper. When the hopper holds a full
## recipe the machine works for `seconds`, then spits the outputs out beside itself.
## The altar also needs a soul from the heart and the necromancer's touch (interact), which costs mana.

const MACHINES := {
	&"grinder": {
		"name": "Corpse Grinder", "footprint": Vector2(48, 48), "seconds": 4.0,
		"noise": 0.7, # loud: Threats turns this into Suspicion
		"recipes": [
			{"in": {&"corpse": 1}, "out": {&"gibs": 2, &"bones": 1}},
			{"in": {&"part": 1}, "out": {&"gibs": 1, &"bones": 1}},
		],
		"blood": 40, # blood cells sprayed per batch
	},
	&"stitching_table": {
		"name": "Stitching Table", "footprint": Vector2(56, 32), "seconds": 5.0, "noise": 0.15,
		"recipes": [{"in": {&"gibs": 2, &"bones": 1}, "out": {&"stitched_body": 1}}],
		"blood": 0,
	},
	&"altar": {
		"name": "Reanimation Altar", "footprint": Vector2(48, 40), "seconds": 2.5, "noise": 0.25,
		"recipes": [{"in": {&"stitched_body": 1}, "out": {}}],
		"blood": 0,
		"touch_mana": 0.15, # the necromancer's touch, in souls' worth
		"soul_cost": 1.0,
	},
}
const HOPPER := {"grab_margin_px": 6.0, "max_per_kind": 4}

var spec: Dictionary = {}
var hopper := {} ## kind -> count waiting
var working := false
var progress := 0.0 ## seconds into the current batch
var _batch: Dictionary = {}
var _noise_t := 0.0
## Altar only: what the next raising makes, &"ghoul" or &"rotling".
var raise_kind: StringName = &"ghoul"
var touched := false


static func make(machine_kind: StringName) -> LairMachine:
	var m := LairMachine.new()
	m.kind = machine_kind
	m.spec = MACHINES[machine_kind]
	m.footprint = m.spec.footprint
	m.name = String(machine_kind).capitalize().replace(" ", "")
	return m


func _ready() -> void:
	if spec.is_empty():
		spec = MACHINES.get(kind, {})
	super()
	add_to_group(&"interactable")
	add_to_group(&"lair_machines")


func _physics_process(delta: float) -> void:
	_grab_items()
	if working:
		progress += delta
		_noise_t -= delta
		if _noise_t <= 0.0:
			_noise_t = 1.0
			Events.noise_made.emit(center(), float(spec.noise), String(kind))
			if int(spec.blood) > 0:
				Sim.spill_px(center() + Vector2(randf_range(-10, 10), -6), SandWorld.M_BLOOD, int(spec.blood) / 4,
					Vector2(randf_range(-2.0, 2.0), -2.5))
		if progress >= float(spec.seconds):
			_finish()
	else:
		_try_start()
	queue_redraw()


## How many more of `item_kind` this machine wants in its hopper (ghouls haul to the neediest).
func wants(item_kind: StringName) -> int:
	for r in spec.get("recipes", []):
		if r["in"].has(item_kind):
			var need: int = int(r["in"][item_kind]) * 2 - int(hopper.get(item_kind, 0))
			return clampi(need, 0, int(HOPPER.max_per_kind))
	return 0


## How many more of `item_kind` the next batch still lacks (hauls that complete a batch go first).
func missing(item_kind: StringName) -> int:
	for r in spec.get("recipes", []):
		if r["in"].has(item_kind):
			return maxi(0, int(r["in"][item_kind]) - int(hopper.get(item_kind, 0)))
	return 0


## Take an item into the hopper. Returns true if it was accepted (the item is freed).
func accept(item: Node) -> bool:
	var k := Lair.item_kind(item)
	if wants(k) <= 0:
		return false
	hopper[k] = int(hopper.get(k, 0)) + 1
	if item.has_method("set") and item.get("data") != null and kind == &"altar":
		set_meta("body_data", item.get("data"))
	item.queue_free()
	return true


func _grab_items() -> void:
	var r := get_rect().grow(float(HOPPER.grab_margin_px))
	for it in get_tree().get_nodes_in_group(&"items"):
		if not Lair.item_free(it):
			continue
		if r.has_point((it as Node2D).global_position) and wants(Lair.item_kind(it)) > 0:
			accept(it)


func _ready_recipe() -> Dictionary:
	for r in spec.get("recipes", []):
		var ok := true
		for k in r["in"]:
			if int(hopper.get(k, 0)) < int(r["in"][k]):
				ok = false
				break
		if ok:
			return r
	return {}


func _try_start() -> void:
	var r := _ready_recipe()
	if r.is_empty():
		return
	if kind == &"altar":
		if not touched:
			return
		if not GameState.spend_souls(float(spec.soul_cost)):
			touched = false
			LairText.say("altar_no_soul", &"concerned")
			return
	for k in r["in"]:
		hopper[k] = int(hopper[k]) - int(r["in"][k])
	_batch = r
	working = true
	progress = 0.0
	_noise_t = 0.0


func _finish() -> void:
	working = false
	progress = 0.0
	touched = false
	var outs: Dictionary = _batch.get("out", {})
	var i := 0
	for k in outs:
		for n in int(outs[k]):
			var side := -1.0 if i % 2 == 0 else 1.0
			var at := global_position + Vector2(side * (footprint.x * 0.5 + 8.0 + 6.0 * i), -4)
			Lair.spawn_item(get_tree(), k, at, self, Vector2(side * 1.2, -1.5))
			i += 1
		Events.item_produced.emit(k, int(outs[k]), center())
		GameState.count("made_" + String(k), int(outs[k]))
	if kind == &"grinder":
		GameState.count("bodies_ground")
		Sim.spill_px(center() + Vector2(0, -footprint.y * 0.3), SandWorld.M_BLOOD, int(spec.blood), Vector2(0, -3))
	if kind == &"altar":
		_raise()
	_batch = {}


func _raise() -> void:
	var m: Node2D = LairMinion.make(raise_kind)
	var parent := Lair.layer(get_tree(), "actors", self)
	parent.add_child(m)
	m.global_position = global_position + Vector2(footprint.x * 0.5 + 12.0, 0)
	m.set("heart", heart)
	GameState.count("minions_raised")
	GameState.count(String(raise_kind) + "s_raised")
	GameState.unlock(StringName("first_" + String(raise_kind)))
	Events.minion_raised.emit(m)
	LairText.say("altar_raised", &"proud", {"minion": String(raise_kind)})


# ---------------------------------------------------------------- interactable

func interact(_by: Node2D) -> void:
	if kind != &"altar":
		return
	if int(hopper.get(&"stitched_body", 0)) <= 0 and not working:
		raise_kind = &"rotling" if raise_kind == &"ghoul" else &"ghoul"
		LairText.say("altar_mode", &"chipper", {"minion": String(raise_kind)})
		return
	if working or touched:
		return
	if GameState.souls + 0.0001 < float(spec.soul_cost):
		LairText.say("altar_no_soul", &"concerned")
		return
	if not GameState.spend_mana(float(spec.touch_mana)):
		LairText.say("altar_no_mana", &"concerned")
		return
	touched = true


func interact_hint() -> String:
	if kind == &"altar":
		if int(hopper.get(&"stitched_body", 0)) > 0:
			return LairText.t("hint_altar_raise", {"minion": String(raise_kind)})
		return LairText.t("hint_altar_empty", {"minion": &"rotling" if raise_kind == &"ghoul" else &"ghoul"})
	return LairText.t("hint_machine", {"name": spec.name, "status": status_text()})


func status_text() -> String:
	if working:
		return LairText.t("status_working")
	var needs := []
	for r in spec.get("recipes", []):
		for k in r["in"]:
			if int(hopper.get(k, 0)) < int(r["in"][k]):
				needs.append(String(k).replace("_", " "))
		break
	return LairText.t("status_waiting", {"needs": ", ".join(needs)})


func _draw() -> void:
	var r := Rect2(-footprint.x * 0.5, -footprint.y, footprint.x, footprint.y)
	if sprite == null:
		draw_rect(r, Color("3a3238"))
		draw_rect(r, Color(0.05, 0.03, 0.05), false, 1.0)
	# progress bar and a shake while working
	if working:
		var f := clampf(progress / float(spec.seconds), 0.0, 1.0)
		draw_rect(Rect2(r.position.x, r.position.y - 4, r.size.x, 2), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(r.position.x, r.position.y - 4, r.size.x * f, 2), Color("8a1a1a") if kind == &"grinder" else Color("2fd8c0"))
		if sprite != null:
			sprite.position.x = randf_range(-1, 1) if kind == &"grinder" else 0.0
	# hopper pips
	var x := r.position.x + 2
	for k in hopper:
		for n in int(hopper[k]):
			draw_rect(Rect2(x, r.position.y + 2, 3, 3), LairItem.COLORS.get(k, Color.WHITE))
			x += 4
	if kind == &"altar" and touched:
		draw_circle(Vector2(0, r.position.y + 6), 4, Color(0.18, 0.85, 0.75, 0.6))
