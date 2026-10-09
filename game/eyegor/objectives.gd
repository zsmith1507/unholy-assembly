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
	"dig_casts_for_chamber": 6, ## Dig spell casts that count as "a chamber" (if Necro doesn't count cells)
	"cells_for_chamber": 300, ## or this many cells dug, if GameState.stats["cells_dug"] is kept
	"poll_interval": 0.25, ## seconds between stat/group checks
}

## The checklist, in order. `stats`: GameState.stats counters that also complete it (any one >= 1, or the
## number given). The events each one listens to are wired in _connect_events() below.
const LIST := [
	{"id": &"place_heart", "stats": {"hearts_placed": 1}},
	{"id": &"refill_mana", "stats": {"mana_refills": 1}},
	{"id": &"dig_chamber", "stats": {"cells_dug": 300, "chambers_dug": 1}},
	{"id": &"rob_grave", "stats": {"graves_robbed": 1}},
	{"id": &"build_grinder", "stats": {"grinders_built": 1}},
	{"id": &"grind_corpse", "stats": {"corpses_ground": 1}},
	{"id": &"build_stitching_table", "stats": {"stitching_tables_built": 1}},
	{"id": &"stitch_body", "stats": {"bodies_stitched": 1}},
	{"id": &"build_altar", "stats": {"altars_built": 1}},
	{"id": &"raise_ghoul", "stats": {"minions_raised": 1}},
	{"id": &"mark_dig", "stats": {"dig_orders": 1}},
	{"id": &"harvest_fragments", "stats": {"fragments_collected": 1}},
	{"id": &"survive_patrol", "stats": {"patrols_survived": 1}},
]

var current := -1 ## index into LIST; -1 before start(), LIST.size() when all done
var done := {} ## id -> true
var _satisfied := {} ## id -> true: its event happened, even before it was current
var _progress := {} ## id -> int, for objectives that count (dig casts)
var _poll := 0.0
var _intro_timer := -1.0
var _last_mana := -1.0
var _last_souls := -1.0
var _souls_dropped_frame := -1
var _last_fragments := 0.0
var _patrol_seen := false
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
	if id == &"dig_chamber":
		var cells := int(GameState.stats.get("cells_dug", 0))
		if cells > 0:
			return Vector2i(int(cells * 100.0 / OBJ.cells_for_chamber), 100)
		return Vector2i(int(_progress.get(id, 0)), OBJ.dig_casts_for_chamber)
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
	Events.heart_placed.connect(func(_at, _r): satisfy(&"place_heart"))
	Events.souls_changed.connect(_on_souls_changed)
	Events.mana_changed.connect(_on_mana_changed)
	Events.spell_cast.connect(_on_spell_cast)
	Events.body_harvested.connect(_on_body_harvested)
	Events.machine_built.connect(_on_machine_built)
	Events.item_produced.connect(_on_item_produced)
	Events.minion_raised.connect(func(_m): satisfy(&"raise_ghoul"))
	Events.dig_marked.connect(func(_cells): satisfy(&"mark_dig"))
	Events.soul_collected.connect(_on_soul_collected)


func _on_souls_changed(souls: float) -> void:
	if souls < _last_souls - 0.0001:
		_souls_dropped_frame = Engine.get_process_frames()
	_last_souls = souls
	if GameState.fragments > _last_fragments + 0.0001:
		satisfy(&"harvest_fragments")
	_last_fragments = GameState.fragments


## A refill is mana going up in the same frame souls went down (GameState.refill_mana_from_heart).
## Siphon adds mana without spending souls, so it doesn't count.
func _on_mana_changed(mana: float, _max_mana: float) -> void:
	if mana > _last_mana + 0.0001 and _souls_dropped_frame == Engine.get_process_frames():
		satisfy(&"refill_mana")
	_last_mana = mana


func _on_spell_cast(spell_id: StringName, at: Vector2) -> void:
	var s := String(spell_id)
	if s == "dig" or s == "bore":
		# Count digging near the heart (or anywhere, before there is one) toward the chamber.
		if not GameState.has_heart or GameState.heart_radius <= 0.0 or at.distance_to(GameState.heart_pos) <= GameState.heart_radius * 1.5:
			_progress[&"dig_chamber"] = int(_progress.get(&"dig_chamber", 0)) + 1
			if int(_progress[&"dig_chamber"]) >= OBJ.dig_casts_for_chamber:
				satisfy(&"dig_chamber")
	elif s.contains("dig") and (s.contains("command") or s.contains("order") or s.contains("mark")):
		satisfy(&"mark_dig")


func _on_body_harvested(item: Node2D) -> void:
	if item == null or not is_instance_valid(item):
		return
	if _kind_of(item) == &"corpse" or item.is_in_group(&"item_corpse"):
		satisfy(&"rob_grave")


func _on_machine_built(machine: Node2D) -> void:
	match _kind_of(machine):
		&"heart": satisfy(&"place_heart")
		&"grinder", &"corpse_grinder": satisfy(&"build_grinder")
		&"stitching_table": satisfy(&"build_stitching_table")
		&"altar", &"reanimation_altar": satisfy(&"build_altar")


func _on_item_produced(kind: StringName, _amount: int, _at: Vector2) -> void:
	match kind:
		&"gibs", &"bones", &"part": satisfy(&"grind_corpse")
		&"stitched_body": satisfy(&"stitch_body")
		&"fragment", &"soul_fragment": satisfy(&"harvest_fragments")


func _on_soul_collected(_amount: float, source: String, _at: Vector2) -> void:
	if source == "fragments" or source.contains("critter") or source.contains("fragment"):
		satisfy(&"harvest_fragments")


## Polled: fragments that arrive without a souls_changed, and the patrol watch.
func _poll_state() -> void:
	if GameState.fragments > _last_fragments + 0.0001:
		satisfy(&"harvest_fragments")
	_last_fragments = GameState.fragments
	if current_id() == &"survive_patrol" or _patrol_seen:
		var patrols := _patrol_count()
		if patrols > 0:
			_patrol_seen = true
		elif _patrol_seen and GameState.has_heart:
			satisfy(&"survive_patrol")


## Farmers on patrol: nodes in group "patrol"/"patrols", or humans whose mode is &"patrol".
func _patrol_count() -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var n := tree.get_nodes_in_group(&"patrol").size() + tree.get_nodes_in_group(&"patrols").size()
	if n > 0:
		return n
	for h in tree.get_nodes_in_group(&"humans"):
		var mode = h.get("mode")
		if mode != null and StringName(str(mode)) == &"patrol":
			n += 1
	return n


## A machine's or item's kind, whatever the owning department called the property.
static func _kind_of(node: Node) -> StringName:
	if node == null or not is_instance_valid(node):
		return &""
	for prop in ["kind", "machine_kind", "building_kind", "type"]:
		var v = node.get(prop)
		if v != null and (v is String or v is StringName) and String(v) != "":
			return StringName(v)
	for g in node.get_groups():
		var gs := String(g)
		for k in ["heart", "grinder", "stitching_table", "altar", "corpse"]:
			if gs == k or gs == "machine_" + k or gs == "item_" + k:
				return StringName(k)
	return &""
