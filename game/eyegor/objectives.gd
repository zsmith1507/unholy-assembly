class_name EyegorObjectives
extends Node
## The hidden-start objectives: Eyegor's onboarding checklist (ADA-style quests). Owned by Eyegor and HUD.
##
## One objective is current at a time. Each listens for its own Events (and GameState.stats counters as a
## fallback), so finishing things out of order still counts: an objective already satisfied completes the
## moment it becomes current. If another department's signal never arrives, the objective simply waits.
##
## On completion: Eyegor says done_<id>, GameState.unlock(<id>) (which emits Events.milestone_reached and
## shows the banner), then after a beat he introduces the next one (intro_<id>).
## Words for every objective live in lines.gd: obj_<id>, intro_<id>, done_<id>, milestone_<id>.

signal objective_started(id: StringName)
signal objective_completed(id: StringName)
signal all_completed

## Tuning.
const OBJ := {
	"intro_delay": 4.0, ## seconds between a completion line and the next objective's introduction
	"first_intro_delay": 0.6, ## after start()
	"cells_for_chamber": 400, ## cells the Dig spell must remove after the heart is placed to count as "a chamber"
	"poll_interval": 0.25, ## seconds between stat/patrol checks
}

## The checklist, in order. Each is completed by the real event noted beside it (wired in _connect_events),
## or by the GameState.stats counter the owning department keeps (any listed counter reaching its number).
const LIST := [
	{"id": &"place_heart", "stats": {"built_heart": 1}}, ## Events.heart_placed (Lair: GameState.set_heart)
	{"id": &"refill_mana", "stats": {}}, ## GameState.refill_mana_from_heart: souls_changed down, then mana_changed up
	{"id": &"dig_chamber", "stats": {}}, ## Necromancer's Dig spell removed_total, counted from when the heart went in
	{"id": &"rob_grave", "stats": {}}, ## Events.body_harvested with a graveyard body (Corpse.fresh / part data.fresh false)
	{"id": &"build_grinder", "stats": {"built_grinder": 1}}, ## Events.machine_built, machine.kind == &"grinder"
	{"id": &"grind_corpse", "stats": {"bodies_ground": 1}}, ## Events.item_produced(&"gibs"/&"bones") from the grinder
	{"id": &"build_stitching_table", "stats": {"built_stitching_table": 1}}, ## Events.machine_built
	{"id": &"stitch_body", "stats": {"made_stitched_body": 1}}, ## Events.item_produced(&"stitched_body")
	{"id": &"build_altar", "stats": {"built_altar": 1}}, ## Events.machine_built
	{"id": &"raise_ghoul", "stats": {"minions_raised": 1}}, ## Events.minion_raised
	{"id": &"mark_dig", "stats": {}}, ## Events.dig_marked (the Dig Order spell)
	{"id": &"harvest_fragments", "stats": {}}, ## GameState.fragments rises (critter orbs: GameState.add_fragments)
	{"id": &"survive_patrol", "stats": {}}, ## Threats.patrols: a patrol that left comes home (or never does), heart intact
]

var current := -1 ## index into LIST; -1 before start(), LIST.size() when all done
var done := {} ## id -> true
var _satisfied := {} ## id -> true: its event happened, even before it was current
var _dig_base := -1 ## the Dig spell's removed_total when the heart went in
var _poll := 0.0
var _intro_timer := -1.0
var _last_mana := -1.0
var _last_souls := -1.0
var _souls_dropped_frame := -1
var _last_fragments := 0.0
var patrols_node: Node = null ## tests may hand in a patrols node; otherwise Threats.patrols is used
var _patrols_out := {} ## patrol id -> true while a patrol is out
var _started := false


func _ready() -> void:
	_connect_events()
	_last_mana = GameState.mana
	_last_souls = GameState.souls
	_last_fragments = GameState.fragments


## Begin the checklist (called when the title screen closes). Safe to call twice.
func start() -> void:
	if _started:
		return
	_started = true
	current = 0
	_intro_timer = OBJ.first_intro_delay
	objective_started.emit(current_id())
	_check()


func current_id() -> StringName:
	if current < 0 or current >= LIST.size():
		return &""
	return LIST[current].id


func is_done(id: StringName) -> bool:
	return done.has(id)


func all_done() -> bool:
	return current >= LIST.size()


## Text for the HUD's objective panel, with progress when there is some ("Dig out your first chamber 3/6").
func current_text() -> String:
	var id := current_id()
	if id == &"":
		return ""
	var t := Narrative.line("obj_%s" % id)
	var p := progress_of(id)
	if p.y > 1:
		t += "  %d/%d" % [mini(p.x, p.y), p.y]
	return t


## (have, need) for objectives that count up; (0, 1) otherwise.
func progress_of(id: StringName) -> Vector2i:
	if id == &"dig_chamber" and not _satisfied.has(id):
		return Vector2i(int(_dug_since_heart() * 100.0 / OBJ.cells_for_chamber), 100)
	return Vector2i(1 if _satisfied.has(id) else 0, 1)


## Mark an objective's condition as met. Departments may call this directly if that's simpler for them,
## e.g. EyegorObjectives instance via group "objectives": get_first_node_in_group("objectives").satisfy(&"rob_grave").
func satisfy(id: StringName) -> void:
	if _satisfied.has(id):
		return
	_satisfied[id] = true
	_check()


## Complete the current objective right now (debug console, tests).
func skip() -> void:
	if current >= 0 and current < LIST.size():
		satisfy(current_id())


func _process(delta: float) -> void:
	if _intro_timer >= 0.0:
		_intro_timer -= delta
		if _intro_timer < 0.0:
			_introduce()
	_poll -= delta
	if _poll <= 0.0:
		_poll = OBJ.poll_interval
		_poll_state()
		_check()


# ------------------------------------------------------------------ advancing

func _check() -> void:
	if not _started:
		return
	var guard := 0
	while current >= 0 and current < LIST.size() and _is_met(LIST[current]):
		_complete(LIST[current].id)
		guard += 1
		if guard > LIST.size():
			break


func _is_met(o: Dictionary) -> bool:
	if _satisfied.has(o.id):
		return true
	for stat in o.stats:
		if int(GameState.stats.get(stat, 0)) >= int(o.stats[stat]):
			return true
	if o.id == &"place_heart" and GameState.has_heart:
		return true
	return false


func _complete(id: StringName) -> void:
	done[id] = true
	current += 1
	Narrative.say(Narrative.line("done_%s" % id), &"proud")
	GameState.unlock(id)
	objective_completed.emit(id)
	if current >= LIST.size():
		_intro_timer = -1.0
		Narrative.say(Narrative.line("all_done"), &"proud")
		GameState.unlock(&"hidden_start_complete")
		all_completed.emit()
	else:
		objective_started.emit(current_id())
		_intro_timer = OBJ.intro_delay


func _introduce() -> void:
	var id := current_id()
	if id == &"" or _is_met(LIST[current]):
		return
	Narrative.say(Narrative.line("intro_%s" % id), &"chipper")


# ------------------------------------------------------------------ listening

func _connect_events() -> void:
	Events.heart_placed.connect(_on_heart_placed)
	Events.souls_changed.connect(_on_souls_changed)
	Events.mana_changed.connect(_on_mana_changed)
	Events.body_harvested.connect(_on_body_harvested)
	Events.machine_built.connect(_on_machine_built)
	Events.item_produced.connect(_on_item_produced)
	Events.minion_raised.connect(func(_m): satisfy(&"raise_ghoul"))
	Events.dig_marked.connect(func(_cells): satisfy(&"mark_dig"))
	Events.soul_collected.connect(_on_soul_collected)


func _on_heart_placed(_at: Vector2, _r: float) -> void:
	satisfy(&"place_heart")
	if _dig_base < 0:
		_dig_base = _dig_removed()


func _on_souls_changed(souls: float) -> void:
	if souls < _last_souls - 0.0001:
		_souls_dropped_frame = Engine.get_process_frames()
	_last_souls = souls
	_check_fragments()


## A refill is mana going up in the same frame souls went down (GameState.refill_mana_from_heart).
## Siphon adds mana without spending souls, so it doesn't count.
func _on_mana_changed(mana: float, _max_mana: float) -> void:
	if mana > _last_mana + 0.0001 and _souls_dropped_frame == Engine.get_process_frames():
		satisfy(&"refill_mana")
	_last_mana = mana


## Harvest hands us whatever reached the necromancer's hand. Graveyard bodies are not fresh.
func _on_body_harvested(item: Node2D) -> void:
	if item == null or not is_instance_valid(item):
		return
	var fresh = item.get("fresh")
	var data = item.get("data")
	if fresh == null and data is Dictionary:
		fresh = (data as Dictionary).get("fresh", null)
	if fresh == false:
		satisfy(&"rob_grave")


func _on_machine_built(machine: Node2D) -> void:
	match _kind_of(machine):
		&"heart": satisfy(&"place_heart")
		&"grinder": satisfy(&"build_grinder")
		&"stitching_table": satisfy(&"build_stitching_table")
		&"altar": satisfy(&"build_altar")


func _on_item_produced(kind: StringName, _amount: int, _at: Vector2) -> void:
	match kind:
		&"gibs", &"bones": satisfy(&"grind_corpse")
		&"stitched_body": satisfy(&"stitch_body")


func _on_soul_collected(_amount: float, source: String, _at: Vector2) -> void:
	if source == "fragments":
		satisfy(&"harvest_fragments")


func _check_fragments() -> void:
	if GameState.fragments > _last_fragments + 0.0001:
		satisfy(&"harvest_fragments")
	_last_fragments = GameState.fragments


## Polled: fragments, the chamber's size, and the patrol watch.
func _poll_state() -> void:
	_check_fragments()
	_last_souls = GameState.souls
	_last_mana = GameState.mana
	if _dig_base < 0 and GameState.has_heart:
		_dig_base = _dig_removed()
	if _dig_base >= 0 and _dug_since_heart() >= OBJ.cells_for_chamber:
		satisfy(&"dig_chamber")
	_watch_patrols()


## Cells the Dig spell has removed since the heart went in.
func _dug_since_heart() -> int:
	if _dig_base < 0:
		return 0
	return maxi(0, _dig_removed() - _dig_base)


func _dig_removed() -> int:
	var nec := _player()
	if nec == null or not nec.has_method("get_spell"):
		return 0
	var dig = nec.get_spell(&"dig")
	if dig == null:
		return 0
	var n = dig.get("removed_total")
	return int(n) if n != null else 0


func _player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var p := tree.get_first_node_in_group(&"player")
	return p


## The Threats autoload's patrols node (patrols.gd) and its `out` list of patrols in the field.
## A patrol that left and is no longer out (home, or nobody left to walk home) has been survived.
func _watch_patrols() -> void:
	var pn = patrols_node
	if pn == null:
		var threats := get_node_or_null(^"/root/Threats")
		pn = threats.get("patrols") if threats != null else null
	if pn == null or not is_instance_valid(pn):
		return
	var still := {}
	var out = pn.get("out")
	if out is Array:
		for p in out:
			if p is Dictionary:
				still[p.get("id", 0)] = true
	for id in _patrols_out:
		if not still.has(id):
			_patrol_over()
	_patrols_out = still


func _patrol_over() -> void:
	if GameState.has_heart:
		GameState.count("patrols_survived")
		satisfy(&"survive_patrol")


## A machine's or item's kind (Lair machines and core Items both use `kind`).
static func _kind_of(node: Node) -> StringName:
	if node == null or not is_instance_valid(node):
		return &""
	var v = node.get("kind")
	if v != null and (v is String or v is StringName):
		return StringName(v)
	return &""
