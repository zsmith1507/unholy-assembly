class_name EyegorClipboard
extends PanelContainer
## Eyegor's clipboard: the onboarding checklist (ticked, current, still hidden) and his recent lines.
## Toggled with the "advisor" action (F1 / View); closes with it or ui_cancel. Doesn't pause the game.
## Owned by Eyegor and HUD.

const CLIP := {
	"width": 260,
	"top": 52, ## px from the top of the screen
	"log_lines": 6, ## recent lines shown under the checklist
	"upcoming_shown": 1, ## objectives after the current one that are named; later ones show as "..."
}

var objectives: EyegorObjectives = null
var _box: VBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", EyegorUI.box(EyegorUI.COLORS.paper, EyegorUI.COLORS.paper_ink, 6))
	# top-right, under the clock and meters, growing down
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	offset_right = -6
	offset_left = -6
	offset_top = CLIP.top
	offset_bottom = CLIP.top
	custom_minimum_size = Vector2(CLIP.width, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 1)
	add_child(_box)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advisor"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		rebuild()


func rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	var ink: Color = EyegorUI.COLORS.paper_ink
	_add(Narrative.line("clipboard_title"), "display", EyegorUI.SIZES.display, ink)
	if objectives != null and is_instance_valid(objectives):
		var shown_ahead := 0
		for i in EyegorObjectives.LIST.size():
			var id: StringName = EyegorObjectives.LIST[i].id
			var text := Narrative.line("obj_%s" % id)
			if objectives.is_done(id):
				_add("[x] " + text, "body", -1, ink.lightened(0.35))
			elif i == objectives.current:
				_add("[  ] " + objectives.current_text(), "body", -1, Color("8a1f1a"))
			elif i > objectives.current and shown_ahead < CLIP.upcoming_shown:
				shown_ahead += 1
				_add("[  ] " + text, "body", -1, ink)
			elif i > objectives.current:
				_add("[  ] ...", "body", -1, ink.lightened(0.5))
				break
	_add(Narrative.line("clipboard_log"), "display", EyegorUI.SIZES.body + 2, ink)
	var hist: Array = Narrative.history
	for j in range(maxi(0, hist.size() - CLIP.log_lines), hist.size()):
		var t := String(hist[j].text).replace("\n", " ")
		var l := _add("- " + t, "small", -1, ink)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(Narrative.line("clipboard_close", {"key": EyegorUI.binding_name("advisor", EyegorUI.using_gamepad)}), "italic", EyegorUI.SIZES.small, ink.lightened(0.4))


func _add(text: String, role: String, size: int, col: Color) -> Label:
	var l := EyegorUI.label(text, role, size, col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.custom_minimum_size.x = CLIP.width - 12
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(l)
	return l
