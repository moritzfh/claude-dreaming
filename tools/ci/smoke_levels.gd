## CI smoke test: checks every level's level.tres and plays each level for a
## few seconds (walk, jump, spin) without a window. Exit code 1 on problems.
##   godot --headless --path . --fixed-fps 30 res://tools/ci/smoke_levels.tscn
## Add `-- --only=<id>` to test a single level.
extends Node

const RUN_SECONDS := 5.0

class ErrorCounter extends Logger:
	var errors: Array[String] = []
	var active := false
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if not active or error_type == ERROR_TYPE_WARNING: return
		var msg := rationale if rationale != "" else code
		errors.append("%s (%s:%d in %s)" % [msg, file, line, function])
	func _log_message(_message: String, _error: bool) -> void:
		pass

var logger := ErrorCounter.new()
var queue: Array = []        # [id, LevelInfo]
var failures: Array[String] = []
var current_id := ""
var t := 0.0
var phase := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(logger)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.substr(7)
	if only == "" or only == "@title":
		queue.append("@title")     # the title screen and its menu
	if only == "" or only == "@hub":
		queue.append("@hub")       # the attic with every room and painting
	for id in DirAccess.get_directories_at("res://levels"):
		if id.begins_with("."): continue
		if only != "" and id != only: continue
		queue.append(id)
	print("levels to check: ", queue)
	_start_next.call_deferred()

func _fail(msg: String) -> void:
	failures.append("[%s] %s" % [current_id, msg])
	printerr("FAIL [%s] %s" % [current_id, msg])

func _start_next() -> void:
	if get_tree().current_scene == self:
		# step out of the "current scene" slot so changing scenes keeps us alive
		var root := get_tree().root
		root.remove_child(self)
		root.add_child(self)
	_release_all()
	if current_id != "":
		for e in logger.errors: _fail("error while playing: " + e)
	logger.errors.clear()
	logger.active = false
	if queue.is_empty():
		_finish()
		return
	current_id = queue.pop_front()
	if current_id == "@title":
		print("▶ opening the title screen")
		logger.active = true
		t = 0.0
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	if current_id == "@hub":
		print("▶ opening the attic")
		logger.active = true
		t = 0.0
		phase = 0
		GameState.next_mode = "hub"
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	var info := _validate(current_id)
	if info == null:
		_start_next.call_deferred()
		return
	print("▶ playing ", current_id)
	logger.active = true
	t = 0.0
	phase = 0
	get_tree().change_scene_to_file(info.scene)

func _validate(id: String) -> LevelInfo:
	var dir := "res://levels/%s/" % id
	if not ResourceLoader.exists(dir + "level.tres"):
		_fail("missing level.tres"); return null
	var info := load(dir + "level.tres") as LevelInfo
	if info == null:
		_fail("level.tres is not a LevelInfo resource"); return null
	if info.title.strip_edges() == "": _fail("title is empty")
	if info.author.strip_edges() == "": _fail("author is empty")
	if info.painting == null:
		_fail("no painting")
	else:
		var s := info.painting.get_size()
		if s.x < 640 or absf(s.x / s.y - 16.0 / 9.0) > 0.03:
			_fail("painting should be 16:9 and at least 640x360 (is %dx%d)" % [s.x, s.y])
	if not info.scene.begins_with(dir):
		_fail("scene must live inside its own folder (%s)" % info.scene)
		return null
	if not ResourceLoader.exists(info.scene):
		_fail("scene not found: " + info.scene); return null
	return info

func _process(delta: float) -> void:
	if current_id == "" or not logger.active: return
	var scene := get_tree().current_scene
	if current_id == "@title":
		if scene == null or scene.name != "Title": return
		t += delta
		if t > 2.0:
			print("  ok after %.1fs, %d error(s)" % [t, logger.errors.size()])
			logger.active = false
			_start_next.call_deferred()
		return
	if current_id == "@hub":
		if scene == null or scene.name != "Main": return
		t += delta
		if t > 3.0:
			if scene.get("hub") == null or (scene.hub as AtticHub).rooms.size() != RoomRegistry.all().size():
				_fail("the attic didn't build all rooms")
			print("  ok after %.1fs, %d error(s)" % [t, logger.errors.size()])
			logger.active = false
			_start_next.call_deferred()
		return
	if scene == null or scene.scene_file_path.get_base_dir().get_file() != current_id: return
	t += delta
	if not (scene is DreamLevel):
		_fail("root node must extend DreamLevel")
		logger.active = false
		_start_next.call_deferred()
		return
	var lvl := scene as DreamLevel
	if phase == 0 and t > 1.0:
		phase = 1
		if lvl.claude == null: _fail("no Claude – call spawn_claude() in build()")
		Input.action_press("move_forward")
	if phase == 1 and t > 2.5:
		phase = 2
		Input.action_press("jump")
	if phase == 2 and t > 2.7:
		phase = 3
		Input.action_release("jump")
		Input.action_press("interact")
	if phase == 3 and t > 2.9:
		phase = 4
		Input.action_release("interact")
	# the pause menu (Esc) must not break the level
	if phase == 4 and t > 3.4:
		phase = 5
		Menus.open_pause()
	if phase == 5 and t > 3.9:
		phase = 6
		Menus.close()
	if t > RUN_SECONDS:
		print("  ok after %.1fs, %d error(s)" % [t, logger.errors.size()])
		_start_next.call_deferred()
		logger.active = false

func _release_all() -> void:
	for a in ["move_forward", "jump", "interact"]: Input.action_release(a)

func _finish() -> void:
	OS.remove_logger(logger)
	print("")
	if failures.is_empty():
		print("ALL LEVELS OK")
		get_tree().quit(0)
	else:
		print("%d PROBLEM(S):" % failures.size())
		for f in failures: print("  - ", f)
		get_tree().quit(1)
