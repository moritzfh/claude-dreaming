## The title screen: the first dream, painted in oil and slowly breathing,
## with the main menu. On the very first start "Play" plays the whole film
## (then you are in the attic); later "Continue" goes straight to the attic.
## Start options on the command line (--hub, --dream, …) skip this screen.
extends Control

const MAIN_SCENE := "res://scenes/main.tscn"
const PAINTING := "res://assets/hub/gallery_src/garden.jpg"
## options the dev tools handle themselves – they don't skip the title
const OWN_ARGS := ["--lshot", "--lcam=", "--devlog", "--title"]
const CREAM := Color(1.0, 0.97, 0.92)
const GOLD := Color(1.0, 0.84, 0.55)

var _bg: Sprite2D
var _ui: Control
var _menu: VBoxContainer
var _col: VBoxContainer
var _page: PanelContainer
var _page_box: VBoxContainer
var _black: ColorRect
var _t := 0.0
var _settle := 0.0      # 0 = breathing, 1 = exactly "cover" (to zoom into the attic)
var _leaving := false
static var _started := false

func _ready() -> void:
	InputSetup.setup()
	# only right at start-up (not when coming back via "Main menu"), and only
	# if the game was started with its normal first scene (tests start others)
	var first := not _started
	_started = true
	if first and not _scene_on_cmdline():
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--level="): return     # Dev opens the level
			if not _own_arg(a):
				get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)
				return
	SceneSwap.discard()
	get_viewport().disable_3d = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_show_menu()
	Sound.music("garden", 2.5)
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	_ui.modulate.a = 0.0
	tw.parallel().tween_property(_ui, "modulate:a", 1.0, 1.2).set_delay(0.6)

func _scene_on_cmdline() -> bool:
	for a in OS.get_cmdline_args():
		if a.ends_with(".tscn") or a.ends_with(".scn"): return true
	return false

func _own_arg(a: String) -> bool:
	for o in OWN_ARGS:
		if a.begins_with(o): return true
	return false

# ------------------------------------------------------------------ build
func _build() -> void:
	_bg = Sprite2D.new()
	var tex: Texture2D = load(PAINTING)
	_bg.texture = tex
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bg.material = PaintingPortal.oil_material(tex)
	add_child(_bg)
	add_child(_petals())
	# a soft dark veil on the left, so the menu stays readable
	var veil := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.07, 0.03, 0.11, 0.78))
	g.set_color(1, Color(0.07, 0.03, 0.11, 0.0))
	g.add_point(0.55, Color(0.07, 0.03, 0.11, 0.45))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(1, 0)
	gt.width = 256; gt.height = 4
	veil.texture = gt
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.anchor_right = 0.62; veil.anchor_bottom = 1.0
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	var col := VBoxContainer.new()
	col.position = Vector2(150, 150)
	col.add_theme_constant_override("separation", 0)
	_ui.add_child(col)
	_col = col
	var title := Menus.label("Claude Dreaming", 150, CREAM, Menus.FONT_TITLE)
	title.add_theme_color_override("font_shadow_color", Color(0.12, 0.04, 0.16, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 14)
	col.add_child(title)
	var sub := Menus.label("✦  a playable dream", 44, GOLD, Menus.FONT_ITALIC)
	sub.add_theme_color_override("font_shadow_color", Color(0.12, 0.04, 0.16, 0.6))
	sub.add_theme_constant_override("shadow_outline_size", 10)
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 90)
	col.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	_menu.custom_minimum_size = Vector2(470, 0)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_menu)

	var foot := Menus.label("Unofficial fan project based on the short film “Claude Dreaming” · not affiliated with Anthropic", 22, Color(CREAM, 0.7), Menus.FONT_ITALIC)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_left = 152; foot.offset_bottom = -30
	foot.add_theme_color_override("font_shadow_color", Color(0.1, 0.03, 0.12, 0.7))
	foot.add_theme_constant_override("shadow_offset_x", 1)
	foot.add_theme_constant_override("shadow_offset_y", 2)
	_ui.add_child(foot)

	_page = PanelContainer.new()
	_page.add_theme_stylebox_override("panel", Menus.panel_style())
	_page.set_anchors_preset(Control.PRESET_CENTER)
	_page.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_page.grow_vertical = Control.GROW_DIRECTION_BOTH
	_page.visible = false
	_ui.add_child(_page)
	_page_box = VBoxContainer.new()
	_page_box.add_theme_constant_override("separation", 10)
	_page_box.custom_minimum_size = Vector2(620, 0)
	_page.add_child(_page_box)

	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

## petals drifting through the picture, like in the dream
func _petals() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 46
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1200, 10)
	p.position = Vector2(1100, -40)
	p.direction = Vector2(-0.5, 1.0)
	p.spread = 25.0
	p.gravity = Vector2(-4, 10)
	p.initial_velocity_min = 40.0; p.initial_velocity_max = 90.0
	p.angular_velocity_min = -90.0; p.angular_velocity_max = 90.0
	p.angle_min = 0.0; p.angle_max = 360.0
	p.scale_amount_min = 5.0; p.scale_amount_max = 10.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.8, 0.88, 0.0)); g.set_color(1, Color(1, 0.85, 0.9, 0.0))
	g.add_point(0.1, Color(1, 0.8, 0.88, 0.85)); g.add_point(0.85, Color(1, 0.93, 0.85, 0.75))
	p.color_ramp = g
	return p

# ------------------------------------------------------------------ pages
func _show_menu() -> void:
	_page.visible = false
	_col.visible = true
	for c in _menu.get_children(): c.queue_free()
	if not GameState.intro_seen:
		_add("Play", func(): _start("full"))
	else:
		_add("Continue", func(): _start("hub"))
		_add("Watch the intro film", func(): _start("full"))
	_add("Settings", func(): _show_page("settings"))
	_add("Controls", func(): _show_page("controls"))
	_add("Credits", func(): _show_page("credits"))
	_add("Quit", func():
		GameState.save()
		get_tree().quit())
	_focus_first.call_deferred(_menu)

func _add(text: String, action: Callable) -> void:
	var b := Menus.button(text, action)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 40)
	(b.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_left = 18
	(b.get_theme_stylebox("hover") as StyleBoxFlat).content_margin_left = 18
	_menu.add_child(b)

func _show_page(page: String) -> void:
	_col.visible = false
	_page.visible = true
	for c in _page_box.get_children(): c.queue_free()
	match page:
		"settings": Menus.build_settings(_page_box, _show_menu)
		"controls": Menus.build_controls(_page_box, _show_menu)
		"credits": Menus.build_credits(_page_box, _show_menu)
	_focus_first.call_deferred(_page_box)

func _focus_first(box: Control) -> void:
	Menus.focus_first(box)

func _unhandled_input(event: InputEvent) -> void:
	if _page.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_show_menu()

# ------------------------------------------------------------------ start
func _start(mode: String) -> void:
	if _leaving: return
	_leaving = true
	GameState.next_mode = mode
	_menu.process_mode = Node.PROCESS_MODE_DISABLED
	var tw := create_tween().set_parallel()
	tw.tween_property(_ui, "modulate:a", 0.0, 0.6)
	tw.tween_property(self, "_settle", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if mode == "full":
		# the film starts in the dark
		Sound.stop_music(1.2)
		tw.tween_property(_black, "color:a", 1.0, 1.2)
	else:
		# this is the painting on the easel: the attic zooms out of it
		GameState.hub_return = "@easel"
	await tw.finished
	if mode != "full":
		await get_tree().process_frame
		await get_tree().process_frame
		PaintingPortal.capture(get_viewport())
	get_tree().change_scene_to_file(MAIN_SCENE)

# ------------------------------------------------------------------ update
func _process(delta: float) -> void:
	_t += delta
	if _bg == null: return
	var vs := get_viewport_rect().size
	var ts := Vector2(_bg.texture.get_size())
	var cover := maxf(vs.x / ts.x, vs.y / ts.y)
	# breathe: a slow zoom and drift, like a camera that can't quite hold still
	var z := lerpf(1.06 + 0.035 * sin(_t * 0.09), 1.015, _settle)
	var drift := Vector2(sin(_t * 0.05) * 0.012 * vs.x, cos(_t * 0.07) * 0.01 * vs.y) * (1.0 - _settle)
	_bg.scale = Vector2.ONE * cover * z
	_bg.position = vs * 0.5 + drift
