extends RefCounted
## Builds the input map in code so actions stay readable in diffs and work on keyboard, mouse and gamepad.
## Steam Deck: left stick moves, A jumps, right trigger casts, bumpers cycle spells.

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT, ["axis", JOY_AXIS_LEFT_X, -1.0], ["button", JOY_BUTTON_DPAD_LEFT]],
	"move_right": [KEY_D, KEY_RIGHT, ["axis", JOY_AXIS_LEFT_X, 1.0], ["button", JOY_BUTTON_DPAD_RIGHT]],
	"move_up": [KEY_W, KEY_UP, ["axis", JOY_AXIS_LEFT_Y, -1.0], ["button", JOY_BUTTON_DPAD_UP]],
	"move_down": [KEY_S, KEY_DOWN, ["axis", JOY_AXIS_LEFT_Y, 1.0], ["button", JOY_BUTTON_DPAD_DOWN]],
	"jump": [KEY_SPACE, KEY_W, ["button", JOY_BUTTON_A]],
	"cast": [["mouse", MOUSE_BUTTON_LEFT], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"cast_alt": [["mouse", MOUSE_BUTTON_RIGHT], ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"interact": [KEY_E, ["button", JOY_BUTTON_X]],
	"spell_next": [KEY_TAB, ["mouse", MOUSE_BUTTON_WHEEL_DOWN], ["button", JOY_BUTTON_RIGHT_SHOULDER]],
	"spell_prev": [["mouse", MOUSE_BUTTON_WHEEL_UP], ["button", JOY_BUTTON_LEFT_SHOULDER]],
	"spell_1": [KEY_1],
	"spell_2": [KEY_2],
	"spell_3": [KEY_3],
	"spell_4": [KEY_4],
	"spell_5": [KEY_5],
	"spell_6": [KEY_6],
	"spell_7": [KEY_7],
	"spell_8": [KEY_8],
	"pause": [KEY_ESCAPE, KEY_P, ["button", JOY_BUTTON_START]],
	"advisor": [KEY_F1, ["button", JOY_BUTTON_BACK]], ## open Eyegor's clipboard
	"debug_console": [KEY_QUOTELEFT],
}

## Right stick aims spells on a gamepad; read it with Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down").
const AIM := {
	"aim_left": [JOY_AXIS_RIGHT_X, -1.0],
	"aim_right": [JOY_AXIS_RIGHT_X, 1.0],
	"aim_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"aim_down": [JOY_AXIS_RIGHT_Y, 1.0],
}


static func setup() -> void:
	for action in ACTIONS:
		_ensure(action, 0.4)
		for spec in ACTIONS[action]:
			InputMap.action_add_event(action, _event(spec))
	for action in AIM:
		_ensure(action, 0.25)
		var ev := InputEventJoypadMotion.new()
		ev.axis = AIM[action][0]
		ev.axis_value = AIM[action][1]
		InputMap.action_add_event(action, ev)


static func _ensure(action: String, deadzone: float) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, deadzone)


static func _event(spec) -> InputEvent:
	if spec is int:
		var k := InputEventKey.new()
		k.physical_keycode = spec
		return k
	match spec[0]:
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = spec[1]
			return m
		"button":
			var b := InputEventJoypadButton.new()
			b.button_index = spec[1]
			return b
		"axis":
			var a := InputEventJoypadMotion.new()
			a.axis = spec[1]
			a.axis_value = spec[2]
			return a
	return null
