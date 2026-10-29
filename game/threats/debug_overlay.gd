extends Control
## F3 debug overlay: the two meters and the latest reasons they moved (from Threats.ledger).

const OVERLAY := {
	"toggle_key": KEY_F3,
	"lines": 14, # ledger lines shown
	"width": 300.0,
	"font_size": 8,
	"bg": Color(0.05, 0.04, 0.06, 0.82),
	"up": Color(0.95, 0.55, 0.35), # Suspicion went up
	"down": Color(0.55, 0.85, 0.6), # went down
	"hunger": Color(0.75, 0.45, 0.95),
	"note": Color(0.7, 0.7, 0.72),
	"start_visible": false,
}

var _label: RichTextLabel


func _ready() -> void:
	visible = OVERLAY.start_visible
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(4, 4)
	var bg := ColorRect.new()
	bg.color = OVERLAY.bg
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = Vector2(OVERLAY.width, 10)
	add_child(bg)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(4, 2)
	_label.size = Vector2(OVERLAY.width - 8, 10)
	_label.add_theme_font_size_override("normal_font_size", OVERLAY.font_size)
	add_child(_label)
	Threats.ledger_changed.connect(_refresh)
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == OVERLAY.toggle_key:
		visible = not visible
		_refresh()
		get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	if visible and Engine.get_process_frames() % 30 == 0:
		_refresh()


func _refresh() -> void:
	if not visible or _label == null:
		return
	var s := "[b]SUSPICION %.1f[/b]  (%+.2f/min)   [b]HUNGER %.1f[/b]\n" % [
		GameState.suspicion, Threats.suspicion_per_min(), GameState.hunger]
	if Threats.is_quiet():
		s += "quiet: fading %.1f/min\n" % Threats.SUSPICION.decay_per_min
	else:
		s += "fades after %d s of quiet\n" % ceili(Threats.seconds_until_quiet())
	s += "patrol: %d farmer%s every %d s%s\n" % [Threats.patrol_size(), "" if Threats.patrol_size() == 1 else "s",
		roundi(Threats.patrol_interval()), " (night)" if GameState.is_night() else ""]
	var tier := Threats.next_depth_tier()
	if not tier.is_empty():
		s += "deepest %d cells; %s at %d\n" % [roundi(Threats.max_depth_cells), tier.name, int(tier.cells)]
	var led: Array = Threats.ledger
	var n: int = mini(OVERLAY.lines, led.size())
	for i in range(led.size() - 1, led.size() - 1 - n, -1):
		var e: Dictionary = led[i]
		var col: Color = OVERLAY.note
		var amount := ""
		if e.meter == "hunger":
			col = OVERLAY.hunger
			amount = "H%+.2f " % e.delta
		elif e.meter == "suspicion":
			col = OVERLAY.up if e.delta > 0.0 else OVERLAY.down
			amount = "%+.2f " % e.delta
		var times := " x%d" % e.count if e.count > 1 else ""
		var ago := roundi(Threats.time - float(e.t))
		s += "[color=#%s]%s%s%s[/color] [color=#888]%ds[/color]\n" % [col.to_html(false), amount, e.text, times, ago]
	_label.text = s
	await get_tree().process_frame
	if is_instance_valid(_label):
		(get_child(0) as ColorRect).size = Vector2(OVERLAY.width, _label.get_content_height() + 6)
