class_name EyegorMenus
extends Control
## Title overlay (pauses the tree until Begin), pause menu, and the controls card. Owned by Eyegor and HUD.
## Runs while the tree is paused. Gamepad: every screen has a focused button; Start/Esc toggles pause.

signal begun

const MENU := {
	"dim": Color(0.02, 0.015, 0.03, 0.82),
}

const CONTROLS := ["ctl_move", "ctl_jump", "ctl_cast", "ctl_cast_alt", "ctl_interact", "ctl_spells", "ctl_advisor", "ctl_pause"]
const CONTROL_ACTIONS := {
	"ctl_move": "move_right", "ctl_jump": "jump", "ctl_cast": "cast", "ctl_cast_alt": "cast_alt",
	"ctl_interact": "interact", "ctl_spells": "spell_next", "ctl_advisor": "advisor", "ctl_pause": "pause",
}

var screen := &"" ## &"title", &"pause", &"controls", or &"" when playing
var _back_to := &""
var _box: VBoxContainer
var _ctl_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = EyegorUI.theme()
	var dim := ColorRect.new()
	dim.color = MENU.dim
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 4)
	center.add_child(_box)
	visible = false


func show_title() -> void:
	_build(&"title")
	get_tree().paused = true


func toggle_pause() -> void:
	if screen == &"title":
		return
	if screen == &"":
		_build(&"pause")
		get_tree().paused = true
	else:
		_resume()


func _unhandled_input(event: InputEvent) -> void:
	EyegorUI.note_input(event)
	if event.is_action_pressed("pause"):
		if screen == &"controls":
			_build(_back_to)
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()


func _resume() -> void:
	var was_title := screen == &"title"
	screen = &""
	visible = false
	get_tree().paused = false
	if was_title:
		begun.emit()


func _build(which: StringName) -> void:
	screen = which
	visible = true
	for c in _box.get_children():
		c.queue_free()
	var first: Button = null
	match which:
		&"title":
			_add(EyegorUI.label(Narrative.line("game_title"), "logo", EyegorUI.SIZES.logo, EyegorUI.COLORS.text))
			_add(EyegorUI.label(Narrative.mission(), "italic", EyegorUI.SIZES.body, EyegorUI.COLORS.teal))
			_box.add_child(Control.new())
			first = _button("title_begin", _resume)
			_button("title_controls", _show_controls)
			_button("title_quit", func(): get_tree().quit())
		&"pause":
			_add(EyegorUI.label(Narrative.line("pause_title"), "display", EyegorUI.SIZES.display_big, EyegorUI.COLORS.text))
			_add(EyegorUI.label(Narrative.line("pause_subtitle"), "italic", EyegorUI.SIZES.body, EyegorUI.COLORS.text_dim))
			first = _button("pause_resume", _resume)
			_button("pause_controls", _show_controls)
			_button("pause_quit", func(): get_tree().quit())
		&"controls":
			_add(EyegorUI.label(Narrative.line("controls_title"), "display", EyegorUI.SIZES.display, EyegorUI.COLORS.text))
			var grid := GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 12)
			_box.add_child(grid)
			for h in ["", "controls_keyboard", "controls_gamepad"]:
				grid.add_child(EyegorUI.label(Narrative.line(h) if h != "" else "", "small", -1, EyegorUI.COLORS.text_dim))
			for k in CONTROLS:
				grid.add_child(EyegorUI.label(Narrative.line(k), "body"))
				var act: String = CONTROL_ACTIONS[k]
				grid.add_child(EyegorUI.label(EyegorUI.binding_name(act, false), "mono", -1, EyegorUI.COLORS.teal))
				grid.add_child(EyegorUI.label(EyegorUI.binding_name(act, true), "mono", -1, EyegorUI.COLORS.teal))
			first = _button("controls_back", func(): _build(_back_to))
	if first != null:
		first.call_deferred("grab_focus")


func _show_controls() -> void:
	_back_to = screen
	_build(&"controls")


func _add(l: Label) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)


func _button(key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = Narrative.line(key)
	b.custom_minimum_size = Vector2(140, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	_box.add_child(b)
	return b
