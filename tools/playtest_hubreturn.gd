## Screenshots of coming back from a gallery level into the attic.
extends Node

var t := 0.0
var shots := [1.0, 2.5, 4.0, 6.0]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	GameState.next_mode = "hub"
	GameState.hub_return = "stardust"
	GameState.completed["stardust"] = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.name != "Main": return
	t += delta
	if not shots.is_empty() and t >= shots[0]:
		get_viewport().get_texture().get_image().save_png("/home/claude/shots/hr_%.1f.png" % shots[0])
		print("shot %.1f state=%s pos=%s" % [shots[0], scene.hub.state, scene.hub.pos])
		shots.pop_front()
		if shots.is_empty(): get_tree().quit()
