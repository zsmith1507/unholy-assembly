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


func _ready() -> void:
	Events.heart_placed.connect(func(_a, _r): _ann("heart_placed"))
	Events.heart_destroyed.connect(func(_a): Narrative.say_line("heart_destroyed", {}, &"concerned"))
	Events.minion_raised.connect(func(_m): _ann("ghoul_raised"))
	Events.machine_built.connect(_on_machine)
	Events.soul_collected.connect(_on_soul)
	Events.human_killed.connect(_on_killed)
	Events.suspicion_changed.connect(_on_sus)
	Events.hunger_changed.connect(_on_hun)
	Events.mana_changed.connect(_on_mana)
	Events.sighting.connect(func(_w, _o): _ann("seen"))
	Events.night_started.connect(func(_d): _comment("night_started"))
	Events.day_started.connect(func(_d): _comment("day_started"))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _ann(key: String, args: Dictionary = {}) -> void:
	if _now() - float(_last.get(key, -999.0)) < TALK.announce_cooldown:
		return
	_last[key] = _now()
	Narrative.announce(key, args)


func _comment(key: String, mood: StringName = &"chipper", force := false) -> void:
	if not force and _now() - _last_comment < TALK.comment_cooldown:
		return
	_last_comment = _now()
	Narrative.say_line(key, {}, mood)


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
