## Films the way into a gallery painting and back out (frame sequence).
## Run with a window:  godot --path . --resolution 640x360 --fixed-fps 30
##   res://scenes/playtest_portal.tscn -- --hub --hubpos=-316,172 --hubauto=lvl:stardust
extends Node

var OUT := "/home/claude/shots/portal/"
var frame := 0
var t_level := -1.0
var t_back := -1.0
var left := false
var max_frames := 3000

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--portal_frames="): max_frames = int(a.substr(16))
		if a.begins_with("--portal_out="): OUT = a.substr(13)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(OUT)
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	# start in the attic via GameState (command line args would survive the
	# scene reloads and drag every reload back into the attic)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--t_hub="):
			GameState.next_mode = "hub"
			GameState.next_opts = ["--hubpos=" + a.substr(8)]
		if a.begins_with("--t_auto="):
			GameState.next_opts.append("--hubauto=" + a.substr(9))
	get_tree().change_scene_to_file("res://scenes/main.tscn")

var shot_dumped := false
func _process(delta: float) -> void:
	frame += 1
	if PaintingPortal.shot != null and not shot_dumped:
		shot_dumped = true
		PaintingPortal.shot.get_image().save_png(OUT + "captured.png")
	var scene := get_tree().current_scene
	if scene == null: return
	if frame % 3 == 0:
		get_viewport().get_texture().get_image().save_png(OUT + "f_%04d.png" % (frame / 3))
	if scene is DreamLevel:
		if t_level < 0.0:
			t_level = 0.0; print("level at frame ", frame)
		t_level += delta
		if t_level > 7.0 and not left:
			left = true
			print("leaving at frame ", frame)
			(scene as DreamLevel).back_to_hub()
	elif scene.name == "Main" and left:
		if t_back < 0.0: t_back = 0.0; print("back in hub at frame ", frame)
		t_back += delta
		if t_back > 4.0: get_tree().quit()
	if frame > max_frames: get_tree().quit()
