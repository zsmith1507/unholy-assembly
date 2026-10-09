extends Node
## Eyegor's voice and every bit of flavour text (autoload `Narrative`). Owned by the Eyegor and HUD department.
## Other departments call these; they never hard-code player-facing strings of their own.
## The words themselves live in res://eyegor/lines.gd; how Eyegor writes is in res://eyegor/VOICE.md.

const Lines := preload("res://eyegor/lines.gd")

const NARRATIVE := {
	"history_size": 24, ## how many recent lines Eyegor's clipboard remembers
}

## Recent lines, oldest first: [{text, mood, time}]. The clipboard shows these.
var history: Array = []


func _ready() -> void:
	Events.advisor_line.connect(_remember)


## Ask Eyegor to say something. mood: &"chipper", &"concerned", &"proud", &"memo".
func say(text: String, mood: StringName = &"chipper") -> void:
	Events.advisor_line.emit(text, mood)


## Say a line by key: Narrative.say_line("first_soul") or say_line("memo_food", {}, &"memo").
func say_line(key: String, args: Dictionary = {}, mood: StringName = &"chipper") -> void:
	say(line(key, args), mood)


## A line by key, e.g. line("heart_placed"). Unknown keys return the key itself so gaps are visible.
## Keys with several variants pick one at random; pass {"variant": n} to choose.
func line(key: String, args: Dictionary = {}) -> String:
	if not Lines.LINES.has(key):
		return key.format(args)
	var v = Lines.LINES[key]
	if v is Array:
		var arr: Array = v
		if arr.is_empty():
			return key
		var i: int = int(args.get("variant", randi() % arr.size())) % arr.size()
		v = arr[i]
	return String(v).format(args)


## True when a key has words written for it.
func has_line(key: String) -> bool:
	return Lines.LINES.has(key)


## The company's mission statement.
func mission() -> String:
	return Lines.MISSION


## Deadpan description of an item ("Left Arm, Slightly Used. Previous owner no longer requires it.").
## data may carry {"part": "arm"|"leg"|"head"|"torso", "side": "left"|"right"}.
func describe_item(kind: StringName, data: Dictionary = {}) -> String:
	var k := String(kind)
	if k == "part" and data.has("part"):
		var pk := "item_part_%s" % String(data.part)
		if has_line(pk):
			var side := String(data.get("side", ""))
			return line(pk, {"side": (side.capitalize() + " ") if side != "" else ""})
	if has_line("item_" + k):
		return line("item_" + k, data)
	return line("item_unknown", {"name": k.capitalize()})


## Display name of a material id from the sim.
func material_name(mat: int) -> String:
	return SandWorld.mat_name(mat)


func _remember(text: String, mood: StringName) -> void:
	history.append({"text": text, "mood": mood, "time": Time.get_ticks_msec()})
	while history.size() > NARRATIVE.history_size:
		history.pop_front()
