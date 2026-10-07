## Menus (autoload "Menus"): the pause menu (Esc / Start) everywhere in the
## game, plus the panels it shares with the title screen – settings,
## controls, credits. Also loads the settings and the saved progress at start
## and saves when the game is closed.
extends CanvasLayer

const FONT_TITLE := preload("res://assets/fonts/EBGaramond-SemiBold.woff2")
const FONT_ITALIC := preload("res://assets/fonts/EBGaramond-Italic.woff2")
const GOLD := Color(1.0, 0.86, 0.55)
const CREAM := Color(1.0, 0.96, 0.9)
const TITLE_SCENE := "res://scenes/title.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"

var _dim: ColorRect
var _panel: PanelContainer
var _box: VBoxContainer
var _open := false
var _page := ""
var _prev_mouse := Input.MOUSE_MODE_VISIBLE
var _reset_armed := false

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.setup()
	Settings.load_settings()
	GameState.load_save()
	get_tree().set_auto_accept_quit(false)
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.02, 0.08, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", panel_style())
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.custom_minimum_size = Vector2(560, 0)
	_panel.add_child(_box)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save()
		get_tree().quit()

# ------------------------------------------------------------------ pause menu
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"): return
	if Dev.panel and Dev.panel.visible: return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == TITLE_SCENE: return
	get_viewport().set_input_as_handled()
	if not _open:
		open_pause()
	elif _page != "pause":
		show_page("pause")
	else:
		close()

func is_open() -> bool:
	return _open

func open_pause() -> void:
	_open = true
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	Sound.ui("blip", -6.0, 0.9)
	_dim.visible = true
	_panel.visible = true
	show_page("pause")

func close() -> void:
	if not _open: return
	_open = false
	_dim.visible = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse

## what is running right now: "film", "hub", "dream" (the first dream) or "level"
func context() -> String:
	var scene := get_tree().current_scene
	if scene is DreamLevel: return "level"
	if scene and scene.name == "Main":
		var v = scene.get("video")
		if v != null and is_instance_valid(v) and not v.get("_done"): return "film"
		var h = scene.get("hub")
		if h != null and is_instance_valid(h) and (h as CanvasLayer).visible: return "hub"
		return "dream"
	return ""

func show_page(page: String) -> void:
	_page = page
	_reset_armed = false
	for c in _box.get_children(): c.queue_free()
	match page:
		"pause": _build_pause()
		"settings": build_settings(_box, func(): show_page("pause"))
		"controls": build_controls(_box, func(): show_page("pause"))
	_focus_first.call_deferred()

func _focus_first() -> void:
	focus_first(_box)

## give the keyboard / gamepad focus to the first thing that can take it
static func focus_first(box: Control) -> void:
	for c in box.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.focus_mode == Control.FOCUS_ALL and ctl.is_visible_in_tree() and not ctl.is_queued_for_deletion():
			ctl.grab_focus()
			return

func _build_pause() -> void:
	_box.add_child(heading("Pause"))
	var ctx := context()
	_box.add_child(button("Weiter", close))
	if ctx == "film":
		_box.add_child(button("Film überspringen", func():
			close()
			var v = get_tree().current_scene.get("video")
			if v: v.skip()))
	if ctx == "level":
		_box.add_child(button("Zurück in den Dachboden", func():
			close()
			(get_tree().current_scene as DreamLevel).back_to_hub()))
	if ctx == "dream":
		_box.add_child(button("Zurück in den Dachboden", func():
			close()
			to_attic_from_dream()))
	_box.add_child(button("Einstellungen", func(): show_page("settings")))
	_box.add_child(button("Steuerung", func(): show_page("controls")))
	_box.add_child(button("Hauptmenü", func():
		close()
		GameState.save()
		Sound.stop_all(0.6)
		SceneSwap.discard()
		get_tree().change_scene_to_file(TITLE_SCENE)))
	_box.add_child(button("Spiel beenden", func():
		GameState.save()
		get_tree().quit()))

## leave the first dream: the view melts into the painting on the easel
func to_attic_from_dream() -> void:
	# build the attic now (the menu has just closed, nothing moves yet), so
	# the end of the camera move into the painting doesn't stall
	GameState.painted = true
	GameState.hub_return = "@easel"
	GameState.next_mode = "hub"
	GameState.save()
	SceneSwap.prepare(load(MAIN_SCENE) as PackedScene, self)
	var sc := get_tree().current_scene
	var d = sc.get("director") if sc else null
	if d != null and is_instance_valid(d) and d.has_method("leave_to_attic"):
		d.leave_to_attic(_dream_to_attic)
	else:
		_dream_to_attic()

func _dream_to_attic() -> void:
	PaintingPortal.capture(get_viewport())
	Sound.stop_all(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if SceneSwap.parked_by == self:
		SceneSwap.swap()
		return
	GameState.hub_return = "@easel"
	GameState.next_mode = "hub"
	get_tree().change_scene_to_file(MAIN_SCENE)

# ------------------------------------------------------------------ shared panels
func build_settings(box: VBoxContainer, back: Callable) -> void:
	box.add_child(heading("Einstellungen"))
	box.add_child(slider("Gesamtlautstärke", Settings.master, 0.0, 1.0, func(v: float):
		Settings.master = v; _settings_changed()))
	box.add_child(slider("Musik", Settings.music, 0.0, 1.0, func(v: float):
		Settings.music = v; _settings_changed()))
	box.add_child(slider("Effekte", Settings.sfx, 0.0, 1.0, func(v: float):
		Settings.sfx = v; _settings_changed()))
	box.add_child(toggle("Vollbild", Settings.fullscreen, func(on: bool):
		Settings.fullscreen = on; _settings_changed()))
	box.add_child(toggle("Grafik: niedrig (schneller)", Settings.low_quality, func(on: bool):
		Settings.low_quality = on
		_settings_changed()
		var sc := get_tree().current_scene
		if sc and sc.has_method("set_low_quality"): sc.set_low_quality(on)))
	box.add_child(slider("Kamera-Tempo", Settings.mouse_sens, 0.3, 2.0, func(v: float):
		Settings.mouse_sens = v; _settings_changed()))
	box.add_child(toggle("Kamera: oben/unten umkehren", Settings.invert_y, func(on: bool):
		Settings.invert_y = on; _settings_changed()))
	var reset := button("Fortschritt zurücksetzen …", Callable())
	reset.pressed.connect(func():
		if not _reset_armed:
			_reset_armed = true
			reset.text = "Wirklich alles vergessen? Nochmal klicken."
		else:
			GameState.reset()
			reset.text = "Zurückgesetzt – beim nächsten Start läuft der Film."
			reset.disabled = true)
	box.add_child(reset)
	box.add_child(button("Zurück", back))

func _settings_changed() -> void:
	Settings.apply()
	Settings.save_settings()

func build_controls(box: VBoxContainer, back: Callable) -> void:
	box.add_child(heading("Steuerung"))
	var rows := [
		["WASD / linker Stick", "laufen"],
		["Shift / B", "rennen"],
		["Leertaste / A", "springen · in der Luft halten = gleiten"],
		["", "Stardust: in der Luft nochmal = Doppelsprung,\nnach der Landung im Lauf = Dreifachsprung"],
		["E / X", "benutzen · ins Gemälde steigen · Drehung"],
		["Maus / rechter Stick", "Kamera"],
		["Q / Y", "Gesicht wechseln"],
		["R / Select", "zurück zum Checkpoint"],
		["Enter halten", "Film überspringen"],
		["Backspace halten", "ein Gemälde-Level verlassen"],
		["Esc / Start", "Pause-Menü"],
		["F1", "Entwickler-Menü (Sprung zu jedem Teil)"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	for r in rows:
		grid.add_child(label(r[0], 24, GOLD, FONT_TITLE))
		grid.add_child(label(r[1], 24, CREAM, FONT_ITALIC))
	box.add_child(grid)
	box.add_child(button("Zurück", back))

func build_credits(box: VBoxContainer, back: Callable) -> void:
	box.add_child(heading("Credits"))
	var text := "Ein spielbarer Traum nach dem Kurzfilm „Claude Dreaming“\n(youtu.be/8BtSRB_LieE) – Film, Musik und die Figur Claude:\nder Ersteller des Videos, mit Claude. Verwendet mit freundlicher Erlaubnis.\n\nSpiel: Rusty & Claude · Godot Engine 4.7"
	box.add_child(label(text, 24, CREAM, FONT_ITALIC, true))
	var people: Array = []
	for r in RoomRegistry.all(): people.append("%s – %s" % [r.owner, r.title])
	for l in LevelRegistry.all(): people.append("„%s“ von %s" % [l.title, l.author])
	if people.size() > 0:
		box.add_child(label("Zimmer und Träume der Community", 26, GOLD, FONT_TITLE, true))
		box.add_child(label("\n".join(people), 22, CREAM, FONT_ITALIC, true))
	box.add_child(label("Schriften: EB Garamond, Pixelify Sans, Fredoka (SIL OFL)\nInoffizielles Fan-Projekt – nicht mit Anthropic verbunden.", 20, Color(CREAM, 0.7), FONT_ITALIC, true))
	box.add_child(button("Zurück", back))

# ------------------------------------------------------------------ widgets
static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.05, 0.13, 0.93)
	sb.border_color = Color(0.85, 0.65, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 40; sb.content_margin_right = 40
	sb.content_margin_top = 28; sb.content_margin_bottom = 28
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 18
	return sb

static func heading(text: String) -> Label:
	var l := label(text, 46, GOLD, FONT_TITLE, true)
	return l

static func label(text: String, size: int, col: Color, font: Font, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if center: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_TITLE)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.75, 0.4))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.04)
	normal.set_corner_radius_all(6)
	normal.content_margin_top = 6; normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 0.8, 0.45, 0.14)
	hover.border_color = Color(1, 0.8, 0.45, 0.6)
	hover.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.focus_entered.connect(func(): Sound.ui("blip", -14.0, 1.2))
	b.pressed.connect(func(): Sound.ui("beep", -10.0))
	if action.is_valid(): b.pressed.connect(action)
	return b

static func slider(text: String, value: float, lo: float, hi: float, changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := label(text, 26, CREAM, FONT_ITALIC)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(240, 28)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4; track.content_margin_bottom = 4
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(0.95, 0.72, 0.4, 0.85)
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = GOLD
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1, 0.8, 0.45, 0.5)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(6)
	focus.expand_margin_left = 6; focus.expand_margin_right = 6
	s.add_theme_stylebox_override("focus", focus)
	s.value_changed.connect(changed)
	s.focus_entered.connect(func(): Sound.ui("blip", -14.0, 1.2))
	row.add_child(s)
	return row

## a setting that is on or off: the label and an "An"/"Aus" switch
static func toggle(text: String, on: bool, changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := label(text, 26, CREAM, FONT_ITALIC)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := button("", Callable())
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = Vector2(130, 0)
	b.add_theme_font_size_override("font_size", 26)
	var paint := func(v: bool):
		b.text = "✓  An" if v else "Aus"
		b.add_theme_color_override("font_color", GOLD if v else Color(CREAM, 0.6))
		b.add_theme_color_override("font_pressed_color", GOLD)
		b.add_theme_color_override("font_hover_pressed_color", GOLD)
	paint.call(on)
	b.toggled.connect(func(v: bool):
		paint.call(v)
		changed.call(v))
	row.add_child(b)
	return row
