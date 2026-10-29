class_name EyegorCommentary
extends Node
## Eyegor's running commentary: turns Events into announcements (ann_*) and the occasional longer line.
## Announcements are the Dungeon Keeper register: short, flat, frequent. Commentary is rationed by a cooldown.

const TALK := {
	"announce_cooldown": 3.0, ## seconds before the same announcement may repeat
	"comment_cooldown": 20.0, ## seconds between longer commentary lines
	"meter_steps": [25.0, 50.0, 75.0], ## Suspicion/Hunger thresholds with their own lines
	"mana_low": 0.25, ## fraction of max
}

var _last := {} ## key -> time it was last said
var _last_comment := -999.0
var _sus_step := 0
var _hun_step := 0
var _mana_warned := false
var _souls_banked := 0
var _patrols: Node = null
var _patrols_announced := 0


func _ready() -> void:
	# The Lair says its own lines for the heart's loss and each raising (heart_destroyed, altar_raised).
	Events.heart_placed.connect(func(_a, _r): _ann("heart_placed"))
	Events.body_harvested.connect(_on_harvested)
	Events.machine_built.connect(_on_machine)
	Events.soul_collected.connect(_on_soul)
	Events.human_killed.connect(_on_killed)
	Events.suspicion_changed.connect(_on_sus)
	Events.hunger_changed.connect(_on_hun)
	Events.mana_changed.connect(_on_mana)
	Events.sighting.connect(func(_w, _o): _ann("seen"))
	Events.night_started.connect(func(_d): _comment("night_started"))
	Events.day_started.connect(func(_d): _comment("day_started"))
	_hook_threats()


## Suspicion and Patrols (autoload Threats, and its patrols node once that exists).
func _hook_threats() -> void:
	var th := get_node_or_null(^"/root/Threats")
	if th == null:
		return
	if th.has_signal("raid_started") and not th.raid_started.is_connected(_on_raid):
		th.raid_started.connect(_on_raid)
	if th.has_signal("alarm_raised") and not th.alarm_raised.is_connected(_on_alarm):
		th.alarm_raised.connect(_on_alarm)
	if th.has_signal("depth_tier_reached") and not th.depth_tier_reached.is_connected(_on_depth):
		th.depth_tier_reached.connect(_on_depth)


func _process(_delta: float) -> void:
	if _patrols != null and is_instance_valid(_patrols):
		return
	var th := get_node_or_null(^"/root/Threats")
	var pn = th.get("patrols") if th != null else null
	if pn is Node and is_instance_valid(pn) and pn.has_signal("patrol_left"):
		_patrols = pn
		pn.patrol_left.connect(_on_patrol_left)
		pn.patrol_returned.connect(func(_p): _ann("patrol_gone"))


func _on_patrol_left(p: Dictionary) -> void:
	var th := get_node_or_null(^"/root/Threats")
	var towns: Array = th.get("info").get("towns", []) if th != null and th.get("info") is Dictionary else []
	var t := int(p.get("town", -1))
	var town := String(towns[t].get("name", "")) if t >= 0 and t < towns.size() else ""
	if town == "" or _patrols_announced > 0:
		_ann("patrol_coming")
	else:
		_comment("patrol_left", &"concerned", true, {"town": town})
	_patrols_announced += 1


func _on_raid(_at: Vector2) -> void:
	_comment("raid_started", &"concerned", true)


func _on_alarm(_at: Vector2, _reason: String, _by: Node2D) -> void:
	_comment("alarm_raised", &"concerned")


func _on_depth(_tier: int, _tier_name: String) -> void:
	_comment("depth_tier", &"concerned", true)


## A graveyard body (not fresh) reaching the hand is a robbed grave.
func _on_harvested(item: Node2D) -> void:
	if item == null or not is_instance_valid(item):
		return
	var data = item.get("data")
	if item.get("fresh") == false or (data is Dictionary and (data as Dictionary).get("fresh", true) == false):
		_ann("grave_robbed", {}, 30.0)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _ann(key: String, args: Dictionary = {}, cooldown: float = -1.0) -> void:
	if _now() - float(_last.get(key, -999.0)) < (cooldown if cooldown >= 0.0 else TALK.announce_cooldown):
		return
	_last[key] = _now()
	Narrative.announce(key, args)


func _comment(key: String, mood: StringName = &"chipper", force := false, args: Dictionary = {}) -> void:
	if not force and _now() - _last_comment < TALK.comment_cooldown:
		return
	_last_comment = _now()
	Narrative.say_line(key, args, mood)


func _on_machine(m: Node2D) -> void:
	var k := EyegorObjectives._kind_of(m)
	if k == &"heart":
		return
	var key := "build_" + String(k)
	_ann("machine_built", {"name": Narrative.line(key) if Narrative.has_line(key) else String(k).capitalize()})


func _on_soul(_amount: float, source: String, _at: Vector2) -> void:
	_souls_banked += 1
	if _souls_banked == 1:
		_comment("first_soul", &"proud", true)
	elif source == "fragments":
		_ann("fragments_combined")
	else:
		_ann("soul_banked")


func _on_killed(_actor: Node2D, witnessed: bool) -> void:
	if witnessed:
		_comment("human_killed_witnessed")
	else:
		_ann("soul_lost")


func _on_sus(value: float, delta: float, _reason: String) -> void:
	var steps: Array = TALK.meter_steps
	if _sus_step < steps.size() and value >= steps[_sus_step]:
		_comment("suspicion_%d" % int(steps[_sus_step]), &"concerned", true)
		_sus_step += 1
	elif delta > 0.0:
		_ann("suspicion_rising")
	while _sus_step > 0 and value < float(steps[_sus_step - 1]) - 10.0:
		_sus_step -= 1
		_ann("suspicion_falling")


func _on_hun(value: float, delta: float, _reason: String) -> void:
	var steps: Array = TALK.meter_steps
	if _hun_step < steps.size() and value >= steps[_hun_step]:
		_comment("hunger_%d" % int(steps[_hun_step]), &"concerned", true)
		_hun_step += 1
	elif delta > 0.0:
		_ann("hunger_rising")


func _on_mana(mana: float, max_mana: float) -> void:
	if max_mana <= 0.0:
		return
	if mana <= 0.001:
		_ann("mana_empty")
		_mana_warned = true
	elif mana < max_mana * TALK.mana_low and not _mana_warned:
		_ann("mana_low")
		_mana_warned = true
	elif mana >= max_mana * 0.5:
		_mana_warned = false
