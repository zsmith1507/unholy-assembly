class_name EyegorPanel
extends PanelContainer
## Eyegor's advisor panel: his portrait, his name, and a typewriter line. Owned by Eyegor and HUD.
## Listens to Events.advisor_line (which Narrative.say emits) and plays lines one at a time from a queue.
## Mood &"announce" lines are short flat status reports: they skip the queue's long hold and type fast.
## Mood &"memo" lines show as an HR notice on cream paper.

const PANEL := {
	"chars_per_sec": 45.0, ## typewriter speed for commentary
	"announce_chars_per_sec": 90.0,
	"hold_base": 2.2, ## seconds a finished line stays up...
	"hold_per_char": 0.045, ## ...plus this per character
	"announce_hold": 2.0,
	"max_queue": 6, ## older lines are dropped if the player is drowning in them
	"width": 250,
	"portrait": 40,
	"fade": 0.35,
}

const MOOD_COLORS := {
	&"chipper": Color("5fe0cc"),
	&"proud": Color("e0b860"),
	&"concerned": Color("e8903a"),
	&"memo": Color("c0302a"),
	&"announce": Color("a89c88"),
}

var queue: Array = [] ## [{text, mood}]
var current: Dictionary = {}
var _shown := 0.0 ## characters revealed
var _hold := 0.0
var _portrait: EyegorPortrait
var _name: Label
var _text: Label
var _memo_head: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PANEL.width, 0)
	add_theme_stylebox_override("panel", EyegorUI.box(EyegorUI.COLORS.panel, EyegorUI.COLORS.edge, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_portrait = EyegorPortrait.new()
	_portrait.custom_minimum_size = Vector2(PANEL.portrait, PANEL.portrait)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_name = EyegorUI.label(Narrative.line("advisor_name"), "display", EyegorUI.SIZES.small + 2, EyegorUI.COLORS.teal)
	col.add_child(_name)
	_memo_head = EyegorUI.label("", "display", EyegorUI.SIZES.small + 2, EyegorUI.COLORS.paper_ink)
	_memo_head.visible = false
	col.add_child(_memo_head)
	_text = EyegorUI.label("", "body")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(PANEL.width - PANEL.portrait - 20, 0)
	col.add_child(_text)
	modulate.a = 0.0
	Events.advisor_line.connect(push)


## Queue a line. Normally called through Events.advisor_line / Narrative.say.
func push(text: String, mood: StringName = &"chipper") -> void:
	if text.strip_edges() == "":
		return
	queue.append({"text": text, "mood": mood})
	while queue.size() > PANEL.max_queue:
		queue.pop_front()


## Skip to the end of the current line, or to the next line if it's already shown.
func advance() -> void:
	if current.is_empty():
		return
	if _shown < String(current.text).length():
		_shown = String(current.text).length()
	else:
		_hold = 0.0


func is_busy() -> bool:
	return not current.is_empty() or not queue.is_empty()


func _process(delta: float) -> void:
	if current.is_empty():
		if queue.is_empty():
			modulate.a = move_toward(modulate.a, 0.0, delta / PANEL.fade)
			return
		_start(queue.pop_front())
	modulate.a = move_toward(modulate.a, 1.0, delta / PANEL.fade)
	var full := String(current.text)
	var announce: bool = current.mood == &"announce"
	if _shown < full.length():
		_shown += delta * (PANEL.announce_chars_per_sec if announce else PANEL.chars_per_sec)
		_text.visible_characters = int(_shown)
		_portrait.talking = true
		if _shown >= full.length():
			_hold = PANEL.announce_hold if announce else PANEL.hold_base + PANEL.hold_per_char * full.length()
	else:
		_portrait.talking = false
		_text.visible_characters = -1
		_hold -= delta
		if _hold <= 0.0:
			current = {}


func _start(entry: Dictionary) -> void:
	current = entry
	var mood: StringName = entry.mood
	var text := String(entry.text)
	var is_memo := mood == &"memo"
	_memo_head.visible = false
	if is_memo:
		var parts := text.split("\n", true, 1)
		_memo_head.text = "%s  %s" % [Narrative.line("memo_header"), parts[0]]
		_memo_head.visible = true
		text = (parts[1] if parts.size() > 1 else "") + "\n- " + Narrative.line("memo_signoff")
		current.text = text
	add_theme_stylebox_override("panel", EyegorUI.box(EyegorUI.COLORS.paper if is_memo else EyegorUI.COLORS.panel, MOOD_COLORS.get(mood, EyegorUI.COLORS.edge).darkened(0.3), 4))
	_text.add_theme_color_override("font_color", EyegorUI.COLORS.paper_ink if is_memo else (EyegorUI.COLORS.text_dim if mood == &"announce" else EyegorUI.COLORS.text))
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0 if is_memo else 0.8))
	_name.visible = not is_memo
	_name.add_theme_color_override("font_color", MOOD_COLORS.get(mood, EyegorUI.COLORS.teal))
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_hold = 999.0
	_portrait.mood = mood
