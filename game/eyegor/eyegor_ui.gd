class_name EyegorUI
extends RefCounted
## The game's UI look: palette, fonts, the Theme, and small formatting helpers. Owned by Eyegor and HUD.
## Other departments that draw UI can use EyegorUI.theme() and EyegorUI.COLORS so everything matches.

## Palette. Grime and parchment, with colour saved for magic and the two meters.
const COLORS := {
	"ink": Color("0b090c"), # near-black background
	"panel": Color(0.075, 0.055, 0.08, 0.90), # HUD panels
	"panel_solid": Color("140f16"),
	"edge": Color("4a3a4c"), # panel borders
	"edge_hi": Color("7a6478"),
	"text": Color("e8dcc0"), # parchment
	"text_dim": Color("a89c88"),
	"text_faint": Color("6e6458"),
	"teal": Color("5fe0cc"), # necromancy, mana and souls
	"teal_dark": Color("1e5c55"),
	"suspicion": Color("e8903a"), # warm, from above
	"suspicion_dark": Color("5a3014"),
	"hunger": Color("a462e8"), # purple, from below
	"hunger_dark": Color("3a1e58"),
	"gold": Color("e0b860"), # milestones
	"blood": Color("9a2a2a"),
	"paper": Color("e9dfc4"), # memos
	"paper_ink": Color("2e2218"),
	"pin": Color("c0302a"),
}

## Font sizes chosen to stay crisp at 640x360 (see fonts/ and VOICE.md).
const SIZES := {
	"body": 11, # Alegreya Sans Bold
	"small": 10,
	"mono": 9, # IBM Plex Mono Medium, numbers
	"display": 16, # Pirata One, headings and banners
	"display_big": 24,
	"logo": 36, # Jacquarda Bastarda 9, the title logo (crisp at multiples of 9)
}

const FONT_FILES := {
	"body": "res://eyegor/fonts/AlegreyaSans-Bold.ttf",
	"body_regular": "res://eyegor/fonts/AlegreyaSans-Regular.ttf",
	"italic": "res://eyegor/fonts/AlegreyaSans-Italic.ttf",
	"mono": "res://eyegor/fonts/IBMPlexMono-Medium.ttf",
	"display": "res://eyegor/fonts/PirataOne-Regular.ttf",
	"logo": "res://eyegor/fonts/JacquardaBastarda9-Regular.ttf",
}

static var _fonts := {}
static var _theme: Theme = null


## A font by role: "body", "body_regular", "italic", "mono", "display", "logo".
static func font(role: String) -> Font:
	if _fonts.has(role):
		return _fonts[role]
	var path: String = FONT_FILES.get(role, FONT_FILES.body)
	var f: FontFile = null
	if ResourceLoader.exists(path):
		f = (load(path) as FontFile).duplicate()
	if f == null:
		_fonts[role] = ThemeDB.fallback_font
		return ThemeDB.fallback_font
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NORMAL
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	_fonts[role] = f
	return f


static func color(name: String) -> Color:
	return COLORS.get(name, Color.MAGENTA)


## A flat panel box with a 1-px border. Used by every HUD panel.
static func box(bg: Color = COLORS.panel, border: Color = COLORS.edge, pad: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s


## The shared Theme: parchment text on grime panels; teal focus for gamepad navigation.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = SIZES.body
	t.set_color("font_color", "Label", COLORS.text)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", -1)
	t.set_color("default_color", "RichTextLabel", COLORS.text)
	t.set_font("normal_font", "RichTextLabel", font("body"))
	t.set_font("italics_font", "RichTextLabel", font("italic"))
	t.set_font("mono_font", "RichTextLabel", font("mono"))
	t.set_font_size("normal_font_size", "RichTextLabel", SIZES.body)
	t.set_stylebox("panel", "PanelContainer", box())
	t.set_stylebox("panel", "Panel", box())
	# Buttons: big enough to hit on a Deck, focus ring for the gamepad.
	t.set_font("font", "Button", font("display"))
	t.set_font_size("font_size", "Button", SIZES.display)
	t.set_color("font_color", "Button", COLORS.text_dim)
	t.set_color("font_hover_color", "Button", COLORS.text)
	t.set_color("font_focus_color", "Button", COLORS.teal)
	t.set_color("font_pressed_color", "Button", COLORS.teal)
	t.set_color("font_hover_pressed_color", "Button", COLORS.teal)
	var normal := box(Color(0.08, 0.06, 0.09, 0.85), COLORS.edge, 3)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var hover := normal.duplicate()
	hover.border_color = COLORS.edge_hi
	hover.bg_color = Color(0.12, 0.09, 0.13, 0.92)
	var focus := normal.duplicate()
	focus.draw_center = false
	focus.border_color = COLORS.teal
	focus.set_border_width_all(1)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 1
	focus.expand_margin_bottom = 1
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.06, 0.14, 0.13, 0.95)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("hover_pressed", "Button", pressed)
	_theme = t
	return t


## A ready Label in a given role, size and colour.
static func label(text: String = "", role: String = "body", size: int = -1, col: Color = COLORS.text) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(role))
	l.add_theme_font_size_override("font_size", size if size > 0 else int(SIZES.get(role, SIZES.body)))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Souls for display: "0.6 souls", "1 soul", "12 souls". Rounds down to a tenth (so a nearly-full bar never
## reads as full), keeps tiny non-zero amounts visible, and drops ".0".
static func format_souls(v: float, with_unit: bool = true) -> String:
	var num := format_soul_number(v)
	if not with_unit:
		return num
	var unit := "soul" if num == "1" else "souls"
	if typeof(Narrative) != TYPE_NIL and Narrative != null:
		unit = Narrative.line("hud_soul_unit" if num == "1" else "hud_souls_unit")
	return "%s %s" % [num, unit]


static func format_soul_number(v: float) -> String:
	if v <= 0.0005:
		return "0"
	if v < 0.1:
		return "<0.1"
	if v >= 100.0:
		return str(int(floor(v + 0.001)))
	var tenths := floori(v * 10.0 + 0.01)
	if tenths % 10 == 0:
		return str(tenths / 10)
	return "%d.%d" % [tenths / 10, tenths % 10]


## "21:30" from a 0-24 hour.
static func format_clock(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	var hh := int(floor(h))
	var mm := int(floor((h - hh) * 60.0))
	mm = mm - mm % 10 # tens of minutes are enough and stop the clock flickering
	return "%02d:%02d" % [hh, mm]


## "dawn", "day", "dusk" or "night" for an hour. Night matches GameState.is_night().
static func phase_of(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	if h >= 20.0 or h < 6.0:
		return "night"
	if h < 8.0:
		return "dawn"
	if h >= 18.0:
		return "dusk"
	return "day"


## The name of the first binding of an action for keyboard/mouse or gamepad, for prompts like "[E]".
static func binding_name(action: String, gamepad: bool) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev in InputMap.action_get_events(action):
		if gamepad:
			if ev is InputEventJoypadButton:
				return _joy_button_name(ev.button_index)
			if ev is InputEventJoypadMotion:
				return _joy_axis_name(ev.axis, ev.axis_value)
		else:
			if ev is InputEventKey:
				var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
				return OS.get_keycode_string(code)
			if ev is InputEventMouseButton:
				return _mouse_name(ev.button_index)
	return "-"


static func _mouse_name(b: int) -> String:
	match b:
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
	return "Mouse %d" % b


static func _joy_button_name(b: int) -> String:
	match b:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_BACK: return "View"
		JOY_BUTTON_DPAD_UP: return "D-pad Up"
		JOY_BUTTON_DPAD_DOWN: return "D-pad Down"
		JOY_BUTTON_DPAD_LEFT: return "D-pad Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-pad Right"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
	return "Button %d" % b


static func _joy_axis_name(axis: int, value: float) -> String:
	match axis:
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "Left Stick"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "Right Stick"
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
	return "Axis %d" % axis


## True when the player last used a gamepad (HUD prompts switch glyphs).
static var using_gamepad := false

static func note_input(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.5):
		using_gamepad = true
	elif ev is InputEventKey or ev is InputEventMouseButton:
		using_gamepad = false
