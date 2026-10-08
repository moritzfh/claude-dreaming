## Developer tools (autoload "Dev", always available, also inside levels):
##   F1  – jump menu: start any part of the game or any gallery level directly
##   F4  – fast forward (1x / 3x / 6x), handy for cutscenes
##   F6  – collect all "colours without names"
##   Enter (hold) skips the films, F2 = waterfall teleport, F3 = low quality,
##   Backspace (hold) leaves a gallery level
extends CanvasLayer

const STORY := [
	["Title screen", "title", []],
	["Intro: the whole film (first start)", "full", []],
	["Film part 1 → 3D transition", "test", ["--fromvideo"]],
	["Painting camera flight (intro)", "dream", []],
	["Garden (free roam)", "test", ["--nointro"]],
	["Moment: the flower", "test", ["--beat=flower"]],
	["Moment: the mirror pool", "test", ["--beat=pool"]],
	["Canal wall / waterfall", "test", ["--waterfall"]],
	["Rocket flight", "test", ["--flight"]],
	["Space", "test", ["--space"]],
	["Warp", "test", ["--warp"]],
	["Pixel film part 2", "test", ["--videob"]],
	["Hub: transition from the film", "hub", ["--hubzoom"]],
	["Hub: studio", "hub", []],
	["Hub: hallway (pinboard, guestbook)", "hub", ["--hubpos=-120,178"]],
]
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "A", "S", "D", "F", "G", "H", "J", "K", "L"]
const SPEEDS := [1.0, 3.0, 6.0]

var panel: PanelContainer
var list: VBoxContainer
var badge: Label
var jumps: Array = []      # [label, mode, opts, level scene or ""]
var _sel := 0
var _speed_i := 0
var _prev_mouse := Input.MOUSE_MODE_VISIBLE
# command line helpers for screenshots / testing levels:
#   -- --level=<id>  start a gallery level directly
#   -- --lshot=<file.png> --lshot_at=<seconds>  save a screenshot and quit
#   -- --lcam=x,y,z:lx,ly,lz  look through a fixed debug camera
var _shot_path := ""
var _shot_at := -1.0
var _time := 0.0
var _cam: Camera3D
var _cam_pose := []

func current_speed() -> float:
	return SPEEDS[_speed_i]

func _ready() -> void:
	InputSetup.setup()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			var id := a.substr(8)
			var l := LevelRegistry.by_id(id)
			if l: get_tree().change_scene_to_file.call_deferred(l.scene)
			else: push_error("no level with id " + id)
		elif a.begins_with("--lshot="): _shot_path = a.substr(8)
		elif a.begins_with("--lshot_at="): _shot_at = float(a.substr(11))
		elif a.begins_with("--lcam="):
			var parts := a.substr(7).split(":")
			var p := parts[0].split(","); var q := parts[1].split(",")
			_cam_pose = [Vector3(float(p[0]), float(p[1]), float(p[2])), Vector3(float(q[0]), float(q[1]), float(q[2]))]
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	badge = Label.new()
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	badge.add_theme_constant_override("outline_size", 4)
	badge.position = Vector2(10, 6)
	badge.text = "F1 Dev"
	add_child(badge)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.09, 0.94)
	sb.border_color = Color(0.85, 0.55, 0.35)
	sb.set_border_width_all(3); sb.set_corner_radius_all(6)
	sb.content_margin_left = 24; sb.content_margin_right = 24; sb.content_margin_top = 18; sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.visible = false
	add_child(panel)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	panel.add_child(list)

func _build_menu() -> void:
	for c in list.get_children(): c.queue_free()
	jumps.clear()
	for j in STORY: jumps.append([j[0], j[1], j[2], ""])
	for r in RoomRegistry.all():
		jumps.append(["Room: " + r.title, "hub", ["--hubroom=" + str(r.get_meta("id"))], ""])
	for l in LevelRegistry.all():
		jumps.append(["Gallery: " + l.title + ("  ★" if GameState.completed.has(l.get_meta("id")) else ""), "", [], l.scene])
	var title := Label.new()
	title.text = "DEV – jump to …   (↑↓ / key / click, Enter, Esc)"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.6))
	list.add_child(title)
	for i in jumps.size():
		var b := Button.new()
		var key: String = KEYS[i] if i < KEYS.size() else " "
		b.text = "%s   %s" % [key, jumps[i][0]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_jump.bind(i))
		b.mouse_entered.connect(func(): _sel = i; _refresh())
		list.add_child(b)
	var foot := Label.new()
	foot.text = "F4 speed · F6 all colors · hold Enter: skip the film · hold Backspace: leave a level · F2 waterfall · F3 quality"
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	list.add_child(foot)
	_sel = clampi(_sel, 0, jumps.size() - 1)
	_refresh()

func _process(delta: float) -> void:
	_time += delta / maxf(Engine.time_scale, 0.001)
	if not _cam_pose.is_empty():
		if _cam == null or not is_instance_valid(_cam):
			var scene := get_tree().current_scene
			if scene is Node3D:
				_cam = Camera3D.new()
				_cam.far = 8000.0
				_cam.fov = 60.0
				scene.add_child(_cam)
		if _cam and is_instance_valid(_cam):
			_cam.look_at_from_position(_cam_pose[0], _cam_pose[1])
			_cam.current = true
	if _shot_path != "" and _shot_at >= 0.0 and _time >= _shot_at - 0.1 and "--lshot_noui" in OS.get_cmdline_user_args():
		visible = false
		for c in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
			(c as CanvasLayer).visible = false
	if _shot_path != "" and _shot_at >= 0.0 and _time >= _shot_at:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		_shot_path = ""
		get_tree().quit()

func _refresh() -> void:
	for i in jumps.size():
		if i + 1 >= list.get_child_count(): break
		var b := list.get_child(i + 1) as Button
		if b: b.modulate = Color(1, 0.85, 0.5) if i == _sel else Color(1, 1, 1, 0.85)
	badge.text = "F1 Dev" + ("" if _speed_i == 0 else "   ▶▶ %dx" % int(SPEEDS[_speed_i]))

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo: return
	match k.physical_keycode:
		KEY_F1:
			_toggle(not panel.visible)
			get_viewport().set_input_as_handled()
		KEY_F4:
			_speed_i = (_speed_i + 1) % SPEEDS.size()
			Engine.time_scale = SPEEDS[_speed_i]
			_refresh()
		KEY_F6:
			for i in 12: GameState.found_orbs[i] = true
			badge.text = "F1 Dev   all colors collected (takes effect when a section restarts)"
		_:
			if not panel.visible: return
			get_viewport().set_input_as_handled()
			var kc := k.physical_keycode
			var idx := -1
			var ch := OS.get_keycode_string(kc).to_upper()
			if KEYS.has(ch): idx = KEYS.find(ch)
			if kc == KEY_UP: _sel = (_sel - 1 + jumps.size()) % jumps.size(); _refresh(); return
			if kc == KEY_DOWN: _sel = (_sel + 1) % jumps.size(); _refresh(); return
			if kc == KEY_ENTER or kc == KEY_KP_ENTER: idx = _sel
			if kc == KEY_ESCAPE: _toggle(false); return
			if idx >= 0 and idx < jumps.size(): _jump.call_deferred(idx)

func _toggle(on: bool) -> void:
	if on: _build_menu()
	panel.visible = on
	get_tree().paused = on or Menus.is_open()
	if on:
		_prev_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = _prev_mouse

func _jump(i: int) -> void:
	panel.visible = false
	get_tree().paused = false
	Engine.time_scale = SPEEDS[_speed_i]
	Sound.stop_all(0.0)
	var j: Array = jumps[i]
	Menus.close()
	SceneSwap.discard()
	if j[1] == "title":
		get_tree().change_scene_to_file(Menus.TITLE_SCENE)
		return
	if j[3] != "":
		get_tree().change_scene_to_file(j[3])
		return
	GameState.next_mode = j[1]
	GameState.next_opts = (j[2] as Array).duplicate()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
