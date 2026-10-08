## The film's "hold to skip" prompt: a held key from before the film doesn't
## count, another key makes the prompt blink, a gamepad button switches the
## glyph, and holding Space skips into the attic. Screenshots (needs a window
## / xvfb): -- --skip_out=<dir>
extends Node
var t := 0.0
var out := "/home/claude/shots/skip/"
var _done := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skip_out="): out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(out)
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	GameState.reset()
	GameState.next_mode = "full"
	# Space pressed (e.g. on the title screen) before the film starts and held on
	_key(KEY_SPACE, true)
	for i in 3: await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func _pad(down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_B
	e.pressed = down
	Input.parse_input_event(e)

func _once(name: String, at: float) -> bool:
	if t < at or _done.has(name): return false
	_done[name] = true
	return true

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
	var v = _video()
	print("t=%5.2f shot %s  progress=%.2f" % [t, name, v._prompt.progress if v else -1.0])

func _video():
	var sc := get_tree().current_scene
	if sc == null or sc.name != "Main": return null
	var v = sc.video
	return v if v != null and is_instance_valid(v) else null

func _process(d: float) -> void:
	t += d
	# Space held from before the film: must not skip
	if _once("shot_early", 3.0): _shot("1_early_hold")
	if _once("release_early", 3.2): _key(KEY_SPACE, false)
	if _once("shot_loud", 5.0): _shot("2_loud")
	if _once("pad", 7.0): _pad(true)
	if _once("pad_up", 7.1): _pad(false)
	if _once("shot_pad", 7.3): _shot("3_pad")
	if _once("w", 9.0): _key(KEY_W, true)
	if _once("w_up", 9.1): _key(KEY_W, false)
	if _once("shot_bump", 9.25): _shot("4_bump")
	if _once("shot_idle", 22.0): _shot("5_idle")
	if _once("hold", 24.0): _key(KEY_SPACE, true)
	if _once("shot_half", 24.5): _shot("6_half")
	if _once("release", 26.0): _key(KEY_SPACE, false)
	var sc := get_tree().current_scene
	if t < 24.0 and sc and sc.name == "Main" and sc.hub.visible and sc.hub.state == "play":
		print("FAIL: in the attic too early at t=%.2f" % t); get_tree().quit(1)
	if t > 24.0 and sc and sc.name == "Main" and sc.hub.visible and sc.hub.state == "play":
		print("t=%5.2f in the attic, skipped=%s" % [t, sc.video.skipped if sc.video and is_instance_valid(sc.video) else "?"])
		_shot("7_attic")
		get_tree().quit()
	if t > 40.0:
		print("TIMEOUT"); get_tree().quit(1)
