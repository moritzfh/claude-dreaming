## Registers the input actions in code (keyboard + mouse + gamepad).
class_name InputSetup
extends RefCounted

static func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action, 0.2)
	for k in keys:
		var e := InputEventKey.new(); e.physical_keycode = k
		InputMap.action_add_event(action, e)

static func _joy_axis(action: String, axis: int, val: float) -> void:
	var e := InputEventJoypadMotion.new(); e.axis = axis; e.axis_value = val
	InputMap.action_add_event(action, e)

static func _joy_btn(action: String, btn: int) -> void:
	var e := InputEventJoypadButton.new(); e.button_index = btn
	InputMap.action_add_event(action, e)

static func setup() -> void:
	if InputMap.has_action("leave"): return   # already done (autoload + scenes)
	_key("move_forward", [KEY_W, KEY_UP]); _joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_key("move_back", [KEY_S, KEY_DOWN]); _joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_key("move_left", [KEY_A, KEY_LEFT]); _joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_key("move_right", [KEY_D, KEY_RIGHT]); _joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_key("jump", [KEY_SPACE]); _joy_btn("jump", JOY_BUTTON_A)
	_key("sprint", [KEY_SHIFT]); _joy_btn("sprint", JOY_BUTTON_LEFT_STICK); _joy_btn("sprint", JOY_BUTTON_B)
	_key("cam_left", []); _joy_axis("cam_left", JOY_AXIS_RIGHT_X, -1.0)
	_key("cam_right", []); _joy_axis("cam_right", JOY_AXIS_RIGHT_X, 1.0)
	_key("cam_up", []); _joy_axis("cam_up", JOY_AXIS_RIGHT_Y, -1.0)
	_key("cam_down", []); _joy_axis("cam_down", JOY_AXIS_RIGHT_Y, 1.0)
	_key("mood", [KEY_Q]); _joy_btn("mood", JOY_BUTTON_Y)
	_key("interact", [KEY_E]); _joy_btn("interact", JOY_BUTTON_X)
	_key("skip", [KEY_ENTER, KEY_KP_ENTER])
	_key("pause", [KEY_ESCAPE]); _joy_btn("pause", JOY_BUTTON_START)
	_key("respawn", [KEY_R]); _joy_btn("respawn", JOY_BUTTON_BACK)
	_key("teleport_waterfall", [KEY_F2])
	_key("toggle_quality", [KEY_F3])
	_key("leave", [KEY_BACKSPACE])
