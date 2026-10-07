## Plays the whole intro film without skipping and checks that it ends in the
## attic, with the soundtrack in sync at every chunk switch.
extends Node
var t := 0.0
var _last_idx := -1
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup.call_deferred()
func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	GameState.reset()
	GameState.next_mode = "full"
	get_tree().change_scene_to_file("res://scenes/main.tscn")
func _process(d: float) -> void:
	t += d
	var sc := get_tree().current_scene
	if sc == null or sc.name != "Main": return
	var v = sc.video
	if v != null and is_instance_valid(v) and v._idx != _last_idx:
		_last_idx = v._idx
		print("t=%6.2f chunk %2d %s music=%s %.2f" % [t, v._idx, str(v.files[mini(v._idx, v.files.size() - 1)]).get_file(), Sound.music_name(), Sound.music_pos()])
	if sc.hub.visible and sc.hub.state == "play":
		print("t=%6.2f in the attic, intro_seen=%s skipped=%s" % [t, GameState.intro_seen, v.skipped if v and is_instance_valid(v) else "?"])
		get_tree().quit()
	if t > 300.0:
		print("TIMEOUT"); get_tree().quit()
