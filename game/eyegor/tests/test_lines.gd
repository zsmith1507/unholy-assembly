extends RefCounted
## Eyegor's words: every key resolves, announcements stay short, the mission statement is exact.

const Lines := preload("res://eyegor/lines.gd")

## Every key the other departments ask Narrative for (grepped from their branches, session 3).
## Dynamic families: spell_<id>, build_<kind>, stockpile_<kind>.
const REQUIRED := [
	# Lair (LairText)
	"heart_refill", "heart_refill_empty", "heart_refill_full", "hint_heart", "hint_altar_raise", "hint_altar_empty",
	"altar_mode", "altar_no_soul", "altar_no_mana", "altar_raised", "hint_machine", "status_working", "status_waiting",
	"status_ready", "stockpile_refused", "stockpile_made", "dig_needs_tools", "memo_complaint", "memo_slowdown",
	"memo_strike", "memo_strike_over", "memo_motivated", "need_food", "need_rest", "hint_striker", "heart_destroyed",
	"minion_soul_lost",
	# Necromancer (NecroText)
	"necro_no_mana", "necro_stockpile_needs_hollow", "necro_cost_per_s", "necro_cost_mana", "necro_cost_souls",
	"necro_siphon_cost", "necro_command_cost", "necro_free", "necro_build_nothing", "necro_build_too_far",
	"necro_build_no_builder", "necro_build_blocked", "necro_build_need_mana", "necro_build_need_souls",
	"hint_refill_hint",
	"spell_dig", "spell_harvest", "spell_siphon", "spell_build", "spell_command_dig", "spell_stockpile",
	"build_heart", "build_grinder", "build_stitching_table", "build_altar", "build_spike_trap",
	"stockpile_gibs", "stockpile_bones", "stockpile_corpses",
]

## Placeholders the callers fill; the words must keep them.
const PLACEHOLDERS := {
	"heart_refill": ["{souls}"], "hint_heart": ["{souls}"], "hint_altar_raise": ["{minion}"],
	"hint_altar_empty": ["{minion}"], "altar_mode": ["{minion}"], "altar_raised": ["{minion}"],
	"hint_machine": ["{name}", "{status}"], "status_waiting": ["{needs}"], "stockpile_made": ["{kind}"],
	"memo_complaint": ["{need}"], "necro_cost_per_s": ["{c}"], "necro_cost_mana": ["{c}"],
	"necro_cost_souls": ["{c}"], "hint_refill_hint": ["{s}"], "ann_machine_built": ["{name}"],
}

## Calls in other departments' code that name a line key as a literal.
const CALL_PATTERN := "(?:NecroText\\.t|LairText\\.t|LairText\\.say|Narrative\\.line|Narrative\\.say_line|Narrative\\.announce)\\(\\s*\"([a-z0-9_]+)\""


func run(t) -> void:
	for key in REQUIRED:
		t.check(Narrative.has_line(key), "line exists for %s" % key)
	for key in PLACEHOLDERS:
		for ph in PLACEHOLDERS[key]:
			var v = Lines.LINES.get(key, "")
			for text in (v if v is Array else [v]):
				t.check(String(text).contains(ph), "%s keeps %s" % [key, ph])
	# When the other departments are merged in (integration), scan their code for literal keys too.
	var re := RegEx.create_from_string(CALL_PATTERN)
	var found := 0
	for dept in ["necro", "lair", "flesh", "world", "threats", "art"]:
		for path in _scripts("res://" + dept):
			if path.contains("/tests/"):
				continue
			var src := FileAccess.get_file_as_string(path)
			for m in re.search_all(src):
				var key := m.get_string(1)
				if key.ends_with("_"):
					continue # a dynamic family, checked above
				found += 1
				t.check(Narrative.has_line(key), "%s asks for %s" % [path.get_file(), key])
	print("    scanned %d literal line keys in other departments" % found)
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


func _scripts(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
