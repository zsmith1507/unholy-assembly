class_name LairMachine
extends LairStructure
## A machine of the first chain: the corpse grinder, the stitching table and the reanimation altar.
## Items dropped on (or hauled into) its footprint are taken into its hopper. When the hopper holds a full
## recipe the machine works for `seconds`, then spits the outputs out beside itself.
## The altar also needs a soul from the heart and the necromancer's touch (interact), which costs mana.
##
## The necromancer's satchel (playtest note 14):
## - Stitching table: interact while carrying its `satchel` recipe (flesh and bones) and it takes them and
##   stitches a body, which comes out beside the table. Ghouls can still feed it gibs and bones.
## - A stitched body lying loose can be picked up into the satchel (interact or Harvest, see LairItem).
## - Altar: one rule, it raises a stitched body. The body is either lying on it (hauled there) or carried in
##   the satchel; touching the altar lays it down and raises it, for a soul from the heart and mana.
##   The first raising of a run needs no soul (`first_raise_soul_cost`), so the opening can always raise
##   its first ghoul even after the heart's starting soul went on a mana refill.
## - Grinder: ghoul-fed only. The necromancer doesn't need to haul to it.
## Outputs land in the nearest open air beside the machine, never inside walls or the floor.

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
		# From the necromancer's satchel. A fresh adult gives about flesh 6, bones 4, blood 3 and a graveyard
		# body about flesh 3.6, bones 4 (Bodies and Souls), so one harvested adult of either kind makes one body.
		"satchel": {&"flesh": 3, &"bones": 3},
		"blood": 0,
	},
	&"altar": {
		"name": "Reanimation Altar", "footprint": Vector2(48, 40), "seconds": 2.5, "noise": 0.25,
		"recipes": [{"in": {&"stitched_body": 1}, "out": {}}],
		"blood": 0,
		"touch_mana": 0.15, # the necromancer's touch, in souls' worth
		"soul_cost": 1.0,
		"first_raise_soul_cost": 0.0, # the run's first raising: the heart spares it (set to 1.0 to turn off)
	},
}
const HOPPER := {"grab_margin_px": 6.0, "max_per_kind": 4}
## Where outputs come out: the nearest open air beside the machine, searched outward from its sides.
const OUTPUT := {"gap_px": 8.0, "step_px": 4.0, "reach_px": 96.0, "rise_step_px": 4.0}

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
	_animate()
	queue_redraw()


## "work" while running, "idle" otherwise (when the sprite has them).
func _animate() -> void:
	play_anim(&"work" if working else &"idle")


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


## Souls the next raising takes from the heart (altar). The run's first raising is discounted.
func soul_cost() -> float:
	if int(GameState.stats.get("minions_raised", 0)) == 0:
		return float(spec.get("first_raise_soul_cost", spec.get("soul_cost", 1.0)))
	return float(spec.get("soul_cost", 1.0))


func _try_start() -> void:
	var r := _ready_recipe()
	if r.is_empty():
		return
	if kind == &"altar":
		if not touched:
			return
		var soul := soul_cost()
		if soul > 0.0 and not GameState.spend_souls(soul):
			touched = false
			LairText.say("altar_no_soul", &"concerned")
			return
		if soul < float(spec.soul_cost):
			LairText.say("altar_first_free", &"chipper")
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
			var at := output_spot(k, side, i)
			side = signf(at.x - global_position.x) if absf(at.x - global_position.x) > 1.0 else 0.0
			Lair.spawn_item(get_tree(), k, at, self, Vector2(side * 0.6, -1.0))
			i += 1
		Events.item_produced.emit(k, int(outs[k]), center())
		GameState.count("made_" + String(k), int(outs[k]))
	if kind == &"grinder":
		GameState.count("bodies_ground")
		Sim.spill_px(center() + Vector2(0, -footprint.y * 0.3), SandWorld.M_BLOOD, int(spec.blood), Vector2(0, -3))
	if kind == &"altar":
		_raise()
	_batch = {}


## Feet position for an output of `item_kind`: the nearest spot beside the machine where the item's whole box
## is open air (or liquid), trying `side` (-1 left, 1 right) first, then the other side, then on top of it.
## `nth` spreads several outputs apart.
func output_spot(item_kind: StringName, side: float, nth: int = 0) -> Vector2:
	var box: Vector2 = LairItem.SIZES.get(item_kind, Vector2(10, 8))
	var base_y := global_position.y - 1.0
	var d := float(OUTPUT.gap_px) + float(nth / 2) * 6.0
	while d <= float(OUTPUT.reach_px):
		for sd in [side, -side]:
			var x: float = global_position.x + sd * (footprint.x * 0.5 + d + box.x * 0.5)
			var rise := 0.0
			while rise <= footprint.y:
				var at := Vector2(x, base_y - rise)
				if _open(at, box):
					return at
				rise += float(OUTPUT.rise_step_px)
		d += float(OUTPUT.step_px)
	var top := Vector2(global_position.x, global_position.y - footprint.y - 1.0)
	var up := 0.0
	while up < 64.0 and not _open(top - Vector2(0, up), box):
		up += float(OUTPUT.rise_step_px)
	return top - Vector2(0, up)


## True if a box of `box` pixels standing with its feet at `at` is all air, gas or liquid.
static func _open(at: Vector2, box: Vector2) -> bool:
	var w := Sim.world
	if w == null:
		return true
	var c := Sim.CELL
	var x0 := floori((at.x - box.x * 0.5) / c)
	var x1 := floori((at.x + box.x * 0.5 - 0.01) / c)
	var y0 := floori((at.y - box.y) / c)
	var y1 := floori((at.y - 0.01) / c)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not w.in_bounds(x, y):
				return false
			if not (w.is_empty(x, y) or w.is_liquid(x, y)):
				return false
	return true


func _raise() -> void:
	var m: Node2D = LairMinion.make(raise_kind)
	var parent := Lair.layer(get_tree(), "actors", self)
	parent.add_child(m)
	m.global_position = output_spot(&"corpse", 1.0)
	m.set("heart", heart)
	GameState.count("minions_raised")
	GameState.count(String(raise_kind) + "s_raised")
	GameState.unlock(StringName("first_" + String(raise_kind)))
	Events.minion_raised.emit(m)
	LairText.say("altar_raised", &"proud", {"minion": String(raise_kind)})


# ---------------------------------------------------------------- interactable

func interact(_by: Node2D) -> void:
	match kind:
		&"stitching_table":
			_interact_table()
		&"altar":
			_interact_altar()


## The stitching table takes its satchel recipe and stitches a body.
func _interact_table() -> void:
	if working:
		return
	var recipe: Dictionary = spec.get("satchel", {})
	if recipe.is_empty():
		return
	if not GameState.take_items(recipe):
		LairText.say("table_needs", &"concerned", {"missing": missing_text(recipe)})
		return
	_batch = {"in": recipe, "out": {&"stitched_body": 1}}
	working = true
	progress = 0.0
	_noise_t = 0.0
	GameState.count("stitched_from_satchel")
	LairText.say("table_stitch", &"chipper")


func _interact_altar() -> void:
	if working or touched:
		return
	var on_altar := int(hopper.get(&"stitched_body", 0)) > 0
	var carried := GameState.item_count(&"stitched_body") >= 1.0
	if not on_altar and not carried:
		raise_kind = &"rotling" if raise_kind == &"ghoul" else &"ghoul"
		LairText.say("altar_mode", &"chipper", {"minion": String(raise_kind)})
		return
	if GameState.souls + 0.0001 < soul_cost():
		LairText.say("altar_no_soul", &"concerned")
		return
	if not GameState.spend_mana(float(spec.touch_mana)):
		LairText.say("altar_no_mana", &"concerned")
		return
	if not on_altar:
		GameState.take_items({&"stitched_body": 1})
		hopper[&"stitched_body"] = int(hopper.get(&"stitched_body", 0)) + 1
	touched = true


## "2 more bones, 1 more flesh" for what the satchel lacks of `recipe`.
static func missing_text(recipe: Dictionary) -> String:
	var parts := []
	for k in recipe:
		var short := ceili(float(recipe[k]) - GameState.item_count(k) - 0.0001)
		if short > 0:
			parts.append(LairText.t("more_of", {"n": short, "kind": String(k).replace("_", " ")}))
	return ", ".join(parts)


func interact_hint() -> String:
	match kind:
		&"altar":
			if working:
				return LairText.t("hint_machine", {"name": spec.name, "status": LairText.t("status_working")})
			var on_altar := int(hopper.get(&"stitched_body", 0)) > 0
			var carried := GameState.item_count(&"stitched_body") >= 1.0
			if not on_altar and not carried:
				return LairText.t("hint_altar_empty", {"minion": &"rotling" if raise_kind == &"ghoul" else &"ghoul"})
			if GameState.souls + 0.0001 < soul_cost():
				return LairText.t("hint_altar_needs_soul")
			if GameState.mana + 0.0001 < float(spec.touch_mana):
				return LairText.t("hint_altar_needs_mana", {"mana": "%.2f" % float(spec.touch_mana)})
			if soul_cost() < float(spec.soul_cost):
				return LairText.t("hint_altar_first", {"minion": String(raise_kind)})
			if on_altar:
				return LairText.t("hint_altar_raise", {"minion": String(raise_kind)})
			return LairText.t("hint_altar_satchel", {"minion": String(raise_kind)})
		&"stitching_table":
			if working:
				return LairText.t("hint_machine", {"name": spec.name, "status": LairText.t("status_working")})
			var recipe: Dictionary = spec.get("satchel", {})
			if GameState.has_items(recipe):
				return LairText.t("hint_table_stitch", {"recipe": recipe_text(recipe)})
			return LairText.t("hint_table_needs", {"missing": missing_text(recipe)})
		&"grinder":
			return LairText.t("hint_grinder", {"status": status_text()})
	return LairText.t("hint_machine", {"name": spec.name, "status": status_text()})


static func recipe_text(recipe: Dictionary) -> String:
	var parts := []
	for k in recipe:
		parts.append("%d %s" % [int(recipe[k]), String(k).replace("_", " ")])
	return ", ".join(parts)


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
