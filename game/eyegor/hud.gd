class_name EyegorHUD
extends Control
## The HUD: mana (in souls' worth), souls in the heart, fragments, Suspicion and Hunger, the spell toolbar,
## the interact hint, day and clock, soul pop-ups, the current objective and milestone banners, and Eyegor's
## panel. Owned by Eyegor and HUD. Everything it reads is looked up null-safely, so it runs at every stage.

const HUD := {
	"margin": 6,
	"bar_w": 96,
	"bar_h": 6,
	"meter_w": 70,
	"popup_rise": 22.0, ## pixels a soul pop-up floats up
	"popup_time": 1.4,
	"banner_time": 3.2,
	"hint_radius": 24.0, ## matches the necromancer's interact reach
	"poll": 0.15,
}

var objectives: EyegorObjectives = null
var panel: EyegorPanel
var _mana_bar: ProgressBar
var _mana_text: Label
var _heart_text: Label
var _frag_text: Label
var _sus_bar: ProgressBar
var _hun_bar: ProgressBar
var _clock: Label
var _spells: HBoxContainer
var _hint: Label
var _obj: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_t := 0.0
var _poll := 0.0
var _spell_sig := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = EyegorUI.theme()
	var m: int = HUD.margin
	# top-left: mana, heart, fragments
	var tl := _corner(Control.PRESET_TOP_LEFT, Vector2(m, m))
	var mana_row := HBoxContainer.new()
	tl.add_child(mana_row)
	mana_row.add_child(EyegorUI.label(Narrative.line("hud_mana"), "small", -1, EyegorUI.COLORS.teal))
	_mana_bar = _bar(EyegorUI.COLORS.teal, EyegorUI.COLORS.teal_dark, HUD.bar_w)
	mana_row.add_child(_mana_bar)
	_mana_text = EyegorUI.label("", "mono")
	mana_row.add_child(_mana_text)
	_heart_text = EyegorUI.label("", "mono", -1, EyegorUI.COLORS.text_dim)
	tl.add_child(_heart_text)
	_frag_text = EyegorUI.label("", "mono", -1, EyegorUI.COLORS.text_dim)
	tl.add_child(_frag_text)
	# top-right: clock, then the two meters
	var tr := _corner(Control.PRESET_TOP_RIGHT, Vector2(-m, m))
	tr.alignment = BoxContainer.ALIGNMENT_END
	_clock = EyegorUI.label("", "display", EyegorUI.SIZES.body + 2, EyegorUI.COLORS.text)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_clock)
	_sus_bar = _meter(tr, "hud_suspicion", EyegorUI.COLORS.suspicion, EyegorUI.COLORS.suspicion_dark)
	_hun_bar = _meter(tr, "hud_hunger", EyegorUI.COLORS.hunger, EyegorUI.COLORS.hunger_dark)
	# top-centre: objective
	_obj = EyegorUI.label("", "body", -1, EyegorUI.COLORS.text)
	_obj.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_obj.position.y = m
	add_child(_obj)
	# bottom-centre: spells; above them, the interact hint
	_spells = HBoxContainer.new()
	_spells.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_spells.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_spells.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_spells.position.y = -m
	_spells.add_theme_constant_override("separation", 3)
	add_child(_spells)
	_hint = EyegorUI.label("", "body", -1, EyegorUI.COLORS.text)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -30
	add_child(_hint)
	# bottom-left: Eyegor
	panel = EyegorPanel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = m
	panel.offset_bottom = -m
	add_child(panel)
	# centre: milestone banner
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.position.y = -70
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_title = EyegorUI.label("", "display", EyegorUI.SIZES.display_big, EyegorUI.COLORS.gold)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub = EyegorUI.label("", "italic", EyegorUI.SIZES.small, EyegorUI.COLORS.text_dim)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var small := EyegorUI.label(Narrative.line("banner_milestone"), "small", -1, EyegorUI.COLORS.text_dim)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(small)
	_banner.add_child(_banner_title)
	_banner.add_child(_banner_sub)
	_banner.modulate.a = 0.0
	add_child(_banner)
	Events.soul_collected.connect(_on_soul)
	Events.milestone_reached.connect(show_banner)
	_refresh()


## Show the milestone banner. id is an objective id (or any unlock id with a milestone_<id> line).
func show_banner(id: StringName) -> void:
	var key := "milestone_" + String(id)
	if not Narrative.has_line(key):
		return
	_banner_title.text = Narrative.line(key)
	_banner_sub.text = Narrative.mission()
	_banner_t = HUD.banner_time


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = HUD.poll
		_refresh()
	_banner_t -= delta
	_banner.modulate.a = clampf(minf(_banner_t, HUD.banner_time - _banner_t) * 3.0, 0.0, 1.0)


func _refresh() -> void:
	_mana_bar.max_value = maxf(GameState.max_mana, 0.001)
	_mana_bar.value = GameState.mana
	_mana_text.text = "%s / %s" % [EyegorUI.format_soul_number(GameState.mana), EyegorUI.format_souls(GameState.max_mana)]
	_heart_text.text = ("%s: %s" % [Narrative.line("hud_heart"), EyegorUI.format_souls(GameState.souls)]) if GameState.has_heart else Narrative.line("hud_no_heart")
	_frag_text.text = "%s: %d / %d" % [Narrative.line("hud_fragments"), int(GameState.fragments), int(GameState.ECON.fragments_per_soul)]
	_sus_bar.value = GameState.suspicion
	_hun_bar.value = GameState.hunger
	_clock.text = "%s  %s  %s" % [Narrative.line("hud_day", {"day": GameState.day}), EyegorUI.format_clock(GameState.hour), Narrative.line("phase_" + EyegorUI.phase_of(GameState.hour))]
	if objectives != null and is_instance_valid(objectives) and not objectives.all_done():
		var t := objectives.current_text()
		_obj.text = ("%s: %s" % [Narrative.line("hud_objective"), t]) if t != "" else ""
	else:
		_obj.text = ""
	_refresh_spells()
	_refresh_hint()


func _necro() -> Node:
	if not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group(&"necro"):
		if n.has_method("get_spells"):
			return n
	return null


func _refresh_spells() -> void:
	var nec := _necro()
	var spells: Array = nec.get_spells() if nec != null else []
	var sel: StringName = nec.get_selected_spell() if nec != null and nec.has_method("get_selected_spell") else &""
	var sig := str(spells) + String(sel)
	if sig == _spell_sig:
		return
	_spell_sig = sig
	for c in _spells.get_children():
		c.queue_free()
	var i := 0
	for s in spells:
		i += 1
		var id := StringName(str(s.get("id", "")))
		var on := id == sel
		var box := PanelContainer.new()
		var col: Color = s.get("color", EyegorUI.COLORS.teal)
		box.add_theme_stylebox_override("panel", EyegorUI.box(Color(0.06, 0.05, 0.07, 0.92) if not on else col.darkened(0.7), col if on else EyegorUI.COLORS.edge, 3))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		box.add_child(v)
		var name_key := "spell_" + String(id)
		var nm := Narrative.line(name_key) if Narrative.has_line(name_key) else str(s.get("name", id))
		v.add_child(EyegorUI.label("%d %s" % [i, nm], "small", -1, EyegorUI.COLORS.text if on else EyegorUI.COLORS.text_dim))
		var cost := str(s.get("cost_text", ""))
		if cost != "":
			v.add_child(EyegorUI.label(cost, "mono", -1, col if on else EyegorUI.COLORS.text_faint))
		_spells.add_child(box)


func _refresh_hint() -> void:
	var nec := _necro()
	var who: Node2D = nec as Node2D
	if who == null and is_inside_tree():
		var players := get_tree().get_nodes_in_group(&"player")
		who = players[0] as Node2D if not players.is_empty() else null
	_hint.text = ""
	if who == null:
		return
	var best: Node = null
	var best_d: float = HUD.hint_radius
	for n in get_tree().get_nodes_in_group(&"interactable"):
		if n is Node2D and n.has_method("interact_hint"):
			var d: float = (n as Node2D).global_position.distance_to(who.global_position)
			if d <= best_d:
				best_d = d
				best = n
	if best != null:
		_hint.text = "[%s] %s" % [EyegorUI.binding_name("interact", EyegorUI.using_gamepad), best.interact_hint()]


func _on_soul(amount: float, source: String, at: Vector2) -> void:
	var frag := source == "fragment" or source.contains("critter")
	var key := "popup_soul" if absf(amount - 1.0) < 0.01 else "popup_souls"
	if frag:
		key = "popup_fragment" if absf(amount - 1.0) < 0.01 else "popup_fragments"
	var l := EyegorUI.label(Narrative.line(key, {"amount": EyegorUI.format_soul_number(amount)}), "display", EyegorUI.SIZES.body + 2, EyegorUI.COLORS.teal)
	add_child(l)
	var vp := get_viewport()
	var screen := size * 0.5
	if vp != null and at != Vector2.ZERO:
		screen = vp.get_canvas_transform() * at
	l.position = screen - Vector2(20, 10)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - HUD.popup_rise, HUD.popup_time)
	tw.tween_property(l, "modulate:a", 0.0, HUD.popup_time).set_delay(HUD.popup_time * 0.4)
	tw.chain().tween_callback(l.queue_free)


func _corner(preset: int, offset: Vector2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(preset)
	v.add_theme_constant_override("separation", 1)
	if offset.x < 0:
		v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	v.offset_left = offset.x
	v.offset_right = offset.x
	v.offset_top = offset.y
	v.offset_bottom = offset.y
	add_child(v)
	return v


func _bar(fill: Color, bg: Color, w: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, HUD.bar_h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.max_value = 100.0
	b.add_theme_stylebox_override("background", EyegorUI.box(bg.darkened(0.4), bg, 0))
	b.add_theme_stylebox_override("fill", EyegorUI.box(fill, fill, 0))
	return b


func _meter(parent: Control, key: String, fill: Color, bg: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(row)
	row.add_child(EyegorUI.label(Narrative.line(key), "small", -1, fill))
	var b := _bar(fill, bg, HUD.meter_w)
	row.add_child(b)
	return b
