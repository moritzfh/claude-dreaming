## All screen-space UI: film-style subtitles, interaction prompt, hints,
## colour counter, fades, the painterly overlay and the end card.
class_name GameHUD
extends CanvasLayer

const FONT_ITALIC := preload("res://assets/fonts/EBGaramond-Italic.woff2")
const FONT_TITLE := preload("res://assets/fonts/EBGaramond-SemiBold.woff2")
const GOLD := Color(1.0, 0.90, 0.68)

var subtitle: Label
var prompt: Label
var hint: Label
var counter: Label
var fade: ColorRect
var painterly: ColorRect
var fx: ColorRect
var overlay: TextureRect
var end_card: Control
var _sub_tween: Tween
var _hint_tween: Tween

func _ready() -> void:
	layer = 10
	painterly = ColorRect.new()
	painterly.set_anchors_preset(Control.PRESET_FULL_RECT)
	painterly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/painterly.gdshader")
	pm.set_shader_parameter("canvas_noise", Tex.noise(77, 0.05, 256, 3))
	pm.set_shader_parameter("stroke_noise", Tex.white(5))
	painterly.material = pm
	painterly.visible = false
	add_child(painterly)
	# fresh copy of the screen, so the effects below see the painted image
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bbc)

	fx = ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/screen_fx.gdshader")
	fx.material = fm
	fx.visible = false
	add_child(fx)

	overlay = TextureRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)

	subtitle = _label(FONT_ITALIC, 46, GOLD)
	subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left = 0; subtitle.offset_right = 0
	subtitle.offset_top = -180; subtitle.offset_bottom = -100
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.modulate.a = 0.0

	prompt = _label(FONT_ITALIC, 30, Color(1, 0.97, 0.92))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -400; prompt.offset_right = 400
	prompt.offset_top = -80; prompt.offset_bottom = -40
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.visible = false

	hint = _label(FONT_ITALIC, 28, Color(1, 0.97, 0.92))
	hint.position = Vector2(36, 28)
	hint.modulate.a = 0.0

	counter = _label(FONT_TITLE, 30, GOLD)
	counter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	counter.offset_left = -420; counter.offset_right = -36; counter.offset_top = 24
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.modulate.a = 0.0

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

func _label(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0.12, 0.05, 0.18, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

## film-style line: types in, holds, dissolves upwards
func say(text: String, hold := 2.6) -> void:
	if _sub_tween: _sub_tween.kill()
	subtitle.text = text
	subtitle.modulate.a = 0.0
	subtitle.offset_top = -180; subtitle.offset_bottom = -100
	_sub_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_sub_tween.tween_property(subtitle, "modulate:a", 1.0, 0.7)
	_sub_tween.tween_interval(hold + 0.02 * text.length())
	_sub_tween.tween_property(subtitle, "modulate:a", 0.0, 1.1)
	_sub_tween.parallel().tween_property(subtitle, "offset_top", -200.0, 1.1)
	_sub_tween.parallel().tween_property(subtitle, "offset_bottom", -120.0, 1.1)

func show_hint(text: String, duration := 6.0) -> void:
	if _hint_tween: _hint_tween.kill()
	hint.text = text
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint, "modulate:a", 1.0, 0.5)
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_property(hint, "modulate:a", 0.0, 1.0)

func set_prompt(text: String) -> void:
	prompt.visible = text != ""
	prompt.text = text

func set_count(n: int, total: int) -> void:
	counter.text = "Farben ohne Namen  %d / %d" % [n, total]
	var tw := create_tween()
	counter.modulate.a = 1.0
	counter.scale = Vector2.ONE
	tw.tween_interval(3.0)
	tw.tween_property(counter, "modulate:a", 0.35, 1.0)

func fade_to(col: Color, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "color", col, duration)
	return tw

var _fx := {"burst": 0.0, "crack": 0.0, "coral": 0.0, "white": 0.0}
func set_fx(name: String, v: float) -> void:
	_fx[name] = v
	(fx.material as ShaderMaterial).set_shader_parameter(name, v)
	var any := false
	for k in _fx: any = any or float(_fx[k]) > 0.001
	fx.visible = any

## show a still (e.g. the film's last frame) and dissolve it away
func dissolve_from(tex: Texture2D, hold: float, dur: float) -> void:
	overlay.texture = tex
	overlay.visible = true
	overlay.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(overlay, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): overlay.visible = false)

func set_painterly(a: float) -> void:
	painterly.visible = a > 0.001
	(painterly.material as ShaderMaterial).set_shader_parameter("amount", a)

func show_end_card(found: int, total: int) -> void:
	end_card = Control.new()
	end_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(end_card)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(900, 400)
	v.position = Vector2(-450, -200)
	end_card.add_child(v)
	var dark := Color(0.30, 0.20, 0.36)
	for row in [["CLAUDE DREAMING", FONT_TITLE, 84], ["Farben ohne Namen gefunden: %d / %d" % [found, total], FONT_ITALIC, 36], ["Fortsetzung folgt …", FONT_ITALIC, 32], ["Enter / Start: nochmal träumen", FONT_ITALIC, 26]]:
		var l := Label.new()
		l.text = row[0]
		l.add_theme_font_override("font", row[1])
		l.add_theme_font_size_override("font_size", row[2])
		l.add_theme_color_override("font_color", dark)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	end_card.modulate.a = 0.0
	create_tween().tween_property(end_card, "modulate:a", 1.0, 1.5)
