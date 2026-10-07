## Clicks through the title screen and the pause menu everywhere:
## title → intro film (pause, skip) → attic → main menu → "Weiter" →
## the first dream → back to the attic → a gallery level → back.
extends Node
var t := 0.0
var step := 0
var _mark := 0.0
var _vpos := 0.0
var _mpos := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _buttons(n: Node) -> Array:
	var out := []
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and not b.is_queued_for_deletion(): out.append((b as Button).text)
	return out

func _press(n: Node, text: String) -> bool:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree() and not b.is_queued_for_deletion():
			(b as Button).pressed.emit()
			return true
	print("!! no button ", text, " in ", _buttons(n))
	return false

func _esc() -> void:
	var e := InputEventAction.new(); e.action = "pause"; e.pressed = true
	Input.parse_input_event(e)
	var u := InputEventAction.new(); u.action = "pause"; u.pressed = false
	Input.parse_input_event(u)

func _next(s: int) -> void:
	step = s
	_mark = t

func _process(d: float) -> void:
	t += d
	var sc := get_tree().current_scene
	var since := t - _mark
	match step:
		0:
			if sc and sc.name == "Title" and since > 2.5:
				print("title buttons: ", _buttons(sc))
				_press(sc, "Spielen"); _next(1)
		1:
			if sc and sc.name == "Main" and since > 4.0:
				print("film: context=", Menus.context(), " music=", Sound.music_name(), " pos=%.2f" % Sound.music_pos())
				_vpos = (sc.video._players[sc.video._active] as VideoStreamPlayer).stream_position
				_mpos = Sound.music_pos()
				_esc(); _next(2)
		2:
			if since > 1.5:
				var v := sc.video._players[sc.video._active] as VideoStreamPlayer
				print("paused=", get_tree().paused, " menu=", _buttons(Menus), " video moved %.2f s, music moved %.2f s while paused" % [v.stream_position - _vpos, Sound.music_pos() - _mpos])
				_press(Menus, "Einstellungen"); _next(3)
		3:
			if since > 0.5:
				print("settings page: ", _buttons(Menus).size(), " buttons")
				_esc(); _next(4)   # back to the pause page
		4:
			if since > 0.5:
				_press(Menus, "Film überspringen"); _next(5)
		5:
			if since > 5.0:
				print("after skip: context=", Menus.context(), " intro_seen=", GameState.intro_seen, " save=", GameState.has_save(), " hub state=", sc.hub.state, " music=", Sound.music_name())
				_esc(); _next(6)
		6:
			if since > 0.5:
				print("hub pause menu: ", _buttons(Menus))
				_press(Menus, "Hauptmenü"); _next(7)
		7:
			if sc and sc.name == "Title" and since > 2.5:
				print("title buttons now: ", _buttons(sc))
				_press(sc, "Weiter"); _next(8)
		8:
			if sc and sc.name == "Main" and since > 3.0:
				print("weiter: context=", Menus.context(), " hub state=", sc.hub.state, " pos=", sc.hub.pos)
				GameState.next_mode = "dream"
				get_tree().change_scene_to_file("res://scenes/main.tscn")
				_next(9)
		9:
			if sc and sc.name == "Main" and since > 6.0:
				print("dream: context=", Menus.context(), " director state=", sc.director.state)
				_esc(); _next(10)
		10:
			if since > 0.5:
				print("dream pause menu: ", _buttons(Menus))
				_press(Menus, "Zurück in den Dachboden"); _next(11)
		11:
			if sc and sc.name == "Main" and sc.director == null and since > 5.0:
				print("back from dream: context=", Menus.context(), " hub state=", sc.hub.state, " pos=", sc.hub.pos, " zoom=%.2f" % sc.hub.zoom, " painted=", GameState.painted, " easel a=", sc.hub.painting.modulate.a)
				get_tree().change_scene_to_file(LevelRegistry.by_id("stardust").scene)
				_next(12)
		12:
			if sc is DreamLevel and since > 5.0:
				print("level: context=", Menus.context())
				_esc(); _next(13)
		13:
			if since > 0.5:
				print("level pause menu: ", _buttons(Menus))
				_press(Menus, "Zurück in den Dachboden"); _next(14)
		14:
			if sc and sc.name == "Main" and since > 4.0:
				print("back from level: context=", Menus.context(), " hub state=", sc.hub.state, " pos=", sc.hub.pos)
				print("DONE")
				get_tree().quit()
	if t > 120.0:
		print("TIMEOUT at step ", step)
		get_tree().quit()
