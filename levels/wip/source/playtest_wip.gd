## Automated run through "Work in Progress": waits for each stage, builds the
## solution through the level's editor API, presses play and checks that
## Claude arrives – up to the commit at the end and the way back to the attic.
##   godot --headless --path . res://levels/wip/source/playtest_wip.tscn
## With a screen (xvfb) it also saves screenshots:
##   -- --t_shots=/tmp/wip_   (prefix for the png files)
##   -- --wip_stage=N         start in stage N (skips the intro)
extends Node

var lvl: Node
var phase := -1
var t := 0.0
var st := 0.0
var shots := ""
var start_stage := 0
var _log_t := 0.0
var _done := false
var stop_at := -1
var _shot_flags := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--t_shots="): shots = a.substr(10)
		if a.begins_with("--wip_stage="): start_stage = int(a.substr(12))
		if a.begins_with("--t_stop="): stop_at = int(a.substr(9))
	if DisplayServer.get_name() == "headless": shots = ""
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	get_tree().change_scene_to_file("res://levels/wip/wip.tscn")

func _shot(name: String) -> void:
	if _shot_flags.has(name): return
	_shot_flags[name] = true
	if shots != "":
		get_viewport().get_texture().get_image().save_png(shots + name + ".png")
		_log("shot " + name)

func _log(s: String) -> void:
	print("[t=%5.1f] %s" % [t, s])

func _go(p: int) -> void:
	phase = p
	st = 0.0

## point the editor's cursor at a world cell (for the screenshots)
func _cursor_at(cell: Vector2i) -> void:
	lvl.editor._cur = lvl.world_to_screen(Vector3(cell.x + 0.5, cell.y + 0.5, 0.0))
	lvl.editor._last_mouse = lvl.editor.get_viewport().get_mouse_position()

func _place(tool: String, cell: Vector2i) -> void:
	var p: Dictionary = lvl.place(tool, cell)
	if p.is_empty(): _log("FAIL: could not place %s at %s" % [tool, cell])

func _ready_to_build(stage: int) -> bool:
	return lvl.stage == stage and not lvl.playing and not lvl.locked and lvl.editor.revealed and st > 1.0

func _process(delta: float) -> void:
	t += delta
	st += delta
	var sc := get_tree().current_scene
	if sc == null: return
	if not sc.has_method("toggle_play"):
		if phase >= 6 and sc.name == "Main" and not _done:
			_done = true
			_log("back in the attic. completed=%s stats=%s" % [GameState.completed.has("wip"), GameState.stats.get("wip")])
			_shot("z_attic")
			_finish(GameState.completed.has("wip"))
		return
	lvl = sc
	if phase == -1:
		_go(start_stage)
	_log_t += delta
	if _log_t > 2.0 and lvl.claude:
		_log_t = 0.0
		_log("phase %d stage %d playing %s locked %s falls %d claude %s" % [phase, lvl.stage, lvl.playing, lvl.locked, lvl.falls, lvl.claude.global_position.snapped(Vector3(0.01, 0.01, 0.01))])
	if t > 260.0:
		_log("TIMEOUT in phase %d" % phase)
		_finish(false)
		return
	if stop_at >= 0 and phase == stop_at and st > 0.6:
		_log("stopping at phase %d" % phase)
		_finish(true)
		return
	match phase:
		0:
			if lvl.playing and lvl.claude.global_position.x > 5.0: _shot("a_intro_walk")
			if lvl.editor._err_open and not lvl.editor.flags.has("pt_err"):
				lvl.editor.flags["pt_err"] = t
			if lvl.editor.flags.has("pt_err") and t - float(lvl.editor.flags["pt_err"]) > 0.4:
				_shot("b_error")
			if _ready_to_build(0):
				_cursor_at(Vector2i(10, 2))
				_shot("c_editor")
				if "--t_input" in OS.get_cmdline_user_args():
					_go(100)       # the same, but with real mouse and key events
					return
				_place("block", Vector2i(10, 2))
				_cursor_at(Vector2i(11, 2))
				_go(10)
		100:
			# the same through the editor's own click handling: hover a cell,
			# click, release – then space through a real key event
			var cells := [Vector2i(10, 2), Vector2i(11, 2)]
			var k := int(st / 0.5)
			if k < 2 and not _shot_flags.has("click%d" % k):
				_shot_flags["click%d" % k] = true
				var pos: Vector2 = lvl.world_to_screen(Vector3(cells[k].x + 0.5, cells[k].y + 0.5, 0.0))
				lvl.editor._cur = pos
				lvl.editor._primary(true)
				lvl.editor._release()
				_log("clicked at %s → cell %s, pieces now %d" % [pos, lvl.screen_to_cell(pos), lvl.pieces.size()])
			if st > 1.3 and not _shot_flags.has("space"):
				_shot_flags["space"] = true
				var e := InputEventKey.new()
				e.keycode = KEY_SPACE
				e.physical_keycode = KEY_SPACE
				e.pressed = true
				Input.parse_input_event(e)
			if st > 1.5 and _shot_flags.has("space") and not _shot_flags.has("space_up"):
				_shot_flags["space_up"] = true
				var e := InputEventKey.new()
				e.keycode = KEY_SPACE
				e.physical_keycode = KEY_SPACE
				e.pressed = false
				Input.parse_input_event(e)
				_log("space → playing: %s" % lvl.playing)
				_go(1)
		10:
			if st > 0.3:
				_shot("d_block_ghost")
				_place("block", Vector2i(11, 2))
				lvl.toggle_play()
				_go(1)
		1:
			if lvl.claude.global_position.x > 14.0 and lvl.stage == 0: _shot("e_walking")
			if _ready_to_build(1):
				_shot("f_stage1")
				_place("ramp_r", Vector2i(29, 3))
				_place("ramp_r", Vector2i(37, 1))
				_place("block", Vector2i(38, 1))
				_place("ramp_r", Vector2i(38, 2))
				_cursor_at(Vector2i(31, 5))
				_shot("g_stage1_built")
				lvl.toggle_play()
				_go(2)
		2:
			if _ready_to_build(2):
				_shot("h_stage2")
				_place("ramp_r", Vector2i(53, 3))
				_place("block", Vector2i(54, 3))
				_place("ramp_r", Vector2i(54, 4))
				_place("spring", Vector2i(61, 5))
				_shot("i_stage2_built")
				lvl.toggle_play()
				_go(20)
		20:
			if lvl.claude.velocity.y > 6.0 and not lvl.editor.flags.has("pt_spring"):
				lvl.editor.flags["pt_spring"] = true
				_shot("j_spring")
			if lvl.stage == 3: _go(3)
		3:
			if st > 0.8: _shot("k_stage3_paused")
			if _ready_to_build(3):
				var e: Dictionary = lvl.what_at(Vector2i(77, 0))
				lvl.wire_tool(e["wire"], true)
				e = lvl.what_at(Vector2i(83, 0))
				lvl.wire_tool(e["wire"], true)
				e = lvl.what_at(Vector2i(85, 3))
				lvl.wire_tool(e["wire"], false)
				_shot("l_stage3_built")
				lvl.toggle_play()
				_go(4)
		4:
			if _ready_to_build(4) and lvl.panels.size() == 3 and st > 2.5:
				_shot("m_stage4_ui")
				var by := {}
				for p in lvl.panels: by[p["id"]] = p
				for d in [["subtitle", Vector2i(100, 2)], ["hint", Vector2i(106, 1)], ["toolbox", Vector2i(110, 0)]]:
					var p: Dictionary = by[d[0]]
					lvl.panel_pick(p)
					if not lvl.panel_drop(p, d[1]): _log("FAIL: panel %s does not fit at %s" % [d[0], d[1]])
				_go(40)
		40:
			if st > 1.0:
				_shot("n_stage4_built")
				lvl.toggle_play()
				_go(5)
		5:
			if lvl._won:
				_log("goal reached. falls: %d (1 expected: the intro)" % lvl.falls)
				_go(6)
		6:
			if st > 2.0: _shot("o_win")
			if lvl.editor._term.visible and lvl.editor._term_txt.text.contains("probably") and not lvl.editor.flags.has("pt_term"):
				lvl.editor.flags["pt_term"] = true
				_shot("p_commit")

func _finish(ok: bool) -> void:
	_log("RESULT: " + ("OK" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
