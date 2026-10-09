extends RefCounted
## Eyegor's words: every key resolves, announcements stay short, the mission statement is exact.

const Lines := preload("res://eyegor/lines.gd")


func run(t) -> void:
	t.check(Narrative.mission() == "Bringing Eternal Life to a Village Near You, Since 1197.", "mission statement")
	t.check(Narrative.line("no_such_key") == "no_such_key", "unknown key returns itself")
	t.check(Narrative.line("ann_machine_built", {"name": "Corpse Grinder"}) == "Corpse Grinder constructed.", "args fill in")
	for key in Lines.LINES:
		var v = Lines.LINES[key]
		var variants: Array = v if v is Array else [v]
		for text in variants:
			t.check(String(text) != "", "%s is not empty" % key)
			if String(key).begins_with("ann_"):
				var words := String(text).split(" ", false).size()
				t.check(words <= 6, "%s is an announcement of 6 words or fewer (%d)" % [key, words])
				t.check(not String(text).contains("!"), "%s has no exclamation mark" % key)
			elif not String(key).begins_with("memo_"):
				t.check(String(text).length() <= 160, "%s fits the panel (%d chars)" % [key, String(text).length()])
	t.check(Narrative.describe_item(&"part", {"part": "arm", "side": "left"}).begins_with("Left Arm"), "describe a left arm")
	t.check(Narrative.describe_item(&"teapot").begins_with("Teapot"), "unknown item is still described")
	var heard := []
	var cb := func(text, mood): heard.append([text, mood])
	Events.advisor_line.connect(cb)
	Narrative.announce("ghoul_hungry")
	Events.advisor_line.disconnect(cb)
	t.check(heard.size() == 1 and heard[0][0] == "A ghoul is hungry." and heard[0][1] == &"announce", "announce() emits a flat line")
