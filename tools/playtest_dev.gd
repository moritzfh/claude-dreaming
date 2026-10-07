## Opens the dev menu, jumps to a few entries and reports the resulting state.
extends Node
static var t := 0.0
static var step := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup.call_deferred()
func _setup() -> void:
	# stay alive across scene changes, make main the current scene
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
func _key(k: int) -> void:
	var e := InputEventKey.new(); e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var u := InputEventKey.new(); u.physical_keycode = k; u.pressed = false
	Input.parse_input_event(u)
func _process(d: float) -> void:
	t += d
	var m := get_tree().current_scene
	if m == null or m.name != "Main": return
	if step == 0 and t > 3.0: _key(KEY_F1); step = 1
	elif step == 1 and t > 3.5:
		print("paused=", get_tree().paused); _key(KEY_9); step = 2   # rocket flight
	elif step == 2 and t > 7.0:
		print("after jump: mode=", m.mode if m else "?", " state=", m.director.state if m and m.director else "?")
		_key(KEY_F1); step = 3
	elif step == 3 and t > 7.5: _key(KEY_W); step = 4   # Film Teil 2
	elif step == 4 and t > 11.0:
		print("after videob: video=", m.video != null, " music=", Sound.music_name(), " mode=", m.mode)
		_key(KEY_F1); step = 5
	elif step == 5 and t > 11.5: _key(KEY_T); step = 6   # Hub: Flur
	elif step == 6 and t > 15.0:
		print("galerie: mode=", m.mode, " hub state=", m.hub.state if m and m.hub else "?", " pos=", m.hub.pos if m and m.hub else "?")
		_key(KEY_F4)
		step = 7
	elif step == 7 and t > 15.5:
		print("time_scale=", Engine.time_scale); get_tree().quit()
