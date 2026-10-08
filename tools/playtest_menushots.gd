## Rendered screenshots of the menus and the new transitions (needs a window /
## xvfb). -- --ms=<case> --ms_out=<dir>
##   settings     title screen → settings page → credits
##   pause_hub    the pause menu in the attic
##   leave_dream  the first dream → pause → "Back to the attic"
##   cut_a6m1     the intro film's cut from the pixel part into the 3D part
##   cut_m8b      the cut from the 3D part to waking up
##   intro_end    the last seconds of the film → the attic
extends Node
var t := 0.0
var case := ""
var out := "/home/claude/shots/ms/"
var shots: Array = []
var step := 0
var _base := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ms="): case = a.substr(5)
		if a.begins_with("--ms_out="): out = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out)
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	match case:
		"settings":
			get_tree().change_scene_to_file("res://scenes/title.tscn")
			shots = [3.0]
		"pause_hub":
			GameState.next_mode = "hub"
			get_tree().change_scene_to_file("res://scenes/main.tscn")
			shots = [2.6]
		"leave_dream":
			GameState.next_mode = "dream"
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"cut_a6m1", "cut_m8b", "intro_end":
			GameState.next_mode = "hub"
			get_tree().change_scene_to_file("res://scenes/main.tscn")

func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("shot ", name, " t=%.2f" % t)

func _process(delta: float) -> void:
	t += delta
	var sc := get_tree().current_scene
	if sc == null: return
	match case:
		"settings":
			if step == 0 and t > 1.5:
				_shot("title"); sc._show_page("settings"); step = 1
			if step == 1 and t > 3.0:
				_shot("settings"); sc._show_page("credits"); step = 2
			if step == 2 and t > 3.6:
				_shot("credits"); get_tree().quit()
		"pause_hub":
			if step == 0 and t > 2.0:
				Menus.open_pause(); step = 1
			if step == 1 and t > 2.6:
				_shot("pause_hub"); Menus.show_page("controls"); step = 2
			if step == 2 and t > 3.2:
				_shot("controls"); get_tree().quit()
		"leave_dream":
			if step == 0 and sc.name == "Main" and sc.director and t > 4.5:
				# a little into the garden
				Menus.open_pause(); step = 1; _base = t
			if step == 1 and t > _base + 0.6:
				_shot("dream_pause"); Menus.close(); Menus.to_attic_from_dream(); step = 2; _base = t
				shots = [0.5, 1.2, 1.8]
			if step == 2:
				if not shots.is_empty() and t - _base >= shots[0]:
					_shot("leave_%.1f" % shots[0]); shots.pop_front()
				if sc.name == "Main" and sc.director == null:
					step = 3; _base = t; shots = [0.05, 0.25, 0.6, 1.4, 3.2]
			if step == 3:
				if not shots.is_empty() and t - _base >= shots[0]:
					_shot("attic_%.2f" % shots[0]); shots.pop_front()
				if shots.is_empty(): get_tree().quit()
		"cut_a6m1", "cut_m8b", "intro_end":
			if step == 0 and sc.name == "Main" and t > 0.5:
				sc.hub.visible = false
				var v := VideoChain.new()
				sc.add_child(v)
				sc.video = v
				if case == "cut_a6m1":
					v.play_chain(["res://assets/video/part_a6.ogv", "res://assets/video/part_m1.ogv"], "film_full", 5 * 458.0 / 30.0, [458.0 / 30.0, 448.0 / 30.0])
					shots = [14.9, 15.15, 15.35, 15.6]
				elif case == "cut_m8b":
					v.play_chain(["res://assets/video/part_m8.ogv", "res://assets/video/part_b.ogv"], "film_full", (2748.0 + 7 * 448.0) / 30.0, [445.0 / 30.0, 27.0])
					shots = [14.5, 14.8, 15.0, 15.3]
				else:
					v.play_chain(["res://assets/video/part_b.ogv"], "film_full", 6329.0 / 30.0, [27.0])
					v.finished.connect(sc._on_intro_done)
					shots = [25.5, 26.8, 27.3, 28.0, 29.5, 31.5]
				step = 1; _base = t
			if step == 1:
				if not shots.is_empty() and t - _base >= shots[0]:
					_shot("%s_%.2f" % [case, shots[0]]); shots.pop_front()
				if shots.is_empty(): get_tree().quit()
	if case in ["settings", "pause_hub"] and t > 20.0: get_tree().quit()
	if t > 90.0:
		print("TIMEOUT"); get_tree().quit()
