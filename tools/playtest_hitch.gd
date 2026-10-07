## Measures how long every frame takes around stepping into a painting and
## back out (to find hitches). Prints the slowest frames of each phase.
##   -- --t_auto=lvl:stardust   or   -- --t_auto=easel
extends Node
var last := 0
var frames: Array = []      # [ms, phase]
var t := 0.0
var auto := "lvl:stardust"
var phase := "attic"
var _main: Node
var _since := 0
var _out := ""        # -- --t_frames=<dir>: save the frames around the switches
var _n := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--t_auto="): auto = a.substr(9)
		if a.begins_with("--t_frames="): _out = a.substr(11)
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	GameState.next_mode = "hub"
	GameState.next_opts = ["--hubauto=" + auto, "--hubpos=" + ("-316,172" if auto.begins_with("lvl") else "192,190")]
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	last = Time.get_ticks_usec()

func _go(p: String) -> void:
	phase = p
	_since = 0
	print("-> ", p, " at frame ", frames.size())

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	frames.append([(now - last) / 1000.0, phase])
	last = now
	t += delta
	_since += 1
	var sc := get_tree().current_scene
	if sc == null: return
	if _out != "" and (phase in ["zoom in", "zoom out"] or (phase in ["inside", "attic again"] and _since < 24)):
		var img := get_viewport().get_texture().get_image()
		img.resize(320, 180)
		img.save_jpg(_out + "%04d_%s.jpg" % [_n, phase.replace(" ", "")], 0.85)
		_n += 1
	match phase:
		"attic":
			if sc.name == "Main":
				_main = sc
				if sc.hub.state == "talk": _go("talk")
		"talk":
			if sc.hub.state == "portal": _go("zoom in")
		"zoom in":
			if sc is DreamLevel or (sc == _main and sc.mode == "dream"): _go("inside")
		"inside":
			if _since == 150:
				_go("zoom out")
				if sc is DreamLevel: (sc as DreamLevel).back_to_hub()
				else: Menus.to_attic_from_dream()
		"zoom out":
			if sc.name == "Main" and sc != _main: _go("attic again")
		"attic again":
			if _since > 120: _report()
	if t > 90.0:
		print("TIMEOUT in ", phase)
		_report()

func _report() -> void:
	var by := {}
	for f in frames:
		var p: String = f[1]
		if not by.has(p): by[p] = []
		by[p].append(f[0])
	for p in ["attic", "talk", "zoom in", "inside", "zoom out", "attic again"]:
		if by.has(p):
			var a: Array = by[p]
			a.sort()
			print("  %-12s slowest frame %7.1f ms   typical %6.1f ms" % [p, a[-1], a[a.size() / 2]])
	get_tree().quit()
