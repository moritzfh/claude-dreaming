## The narrator: lines appear letter by letter on a felt ribbon at the bottom
## of the screen, with a soft murmur while the text runs (a TTS voice can be
## dropped in later: put audio/narrator/<key>.ogg next to the line keys).
extends CanvasLayer

const FONT := preload("res://levels/plush_desk/fonts/Fredoka-Bold.woff2")

var panel: PanelContainer
var text_label: Label
var _queue: Array = []
var _cur := ""
var _shown := 0.0
var _hold := 0.0
var _blip_t := 0.0
var _fade := 0.0
var quiet := false

func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.88, 0.74, 0.96)
	sb.border_color = Color(0.86, 0.45, 0.38)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 34; sb.content_margin_right = 34
	sb.content_margin_top = 14; sb.content_margin_bottom = 16
	sb.shadow_color = Color(0.1, 0.05, 0.1, 0.35)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5; panel.anchor_right = 0.5
	panel.anchor_top = 1.0; panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -34
	panel.custom_minimum_size = Vector2(760, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var who := Label.new()
	who.text = "THE NARRATOR"
	who.add_theme_font_override("font", FONT)
	who.add_theme_font_size_override("font_size", 15)
	who.add_theme_color_override("font_color", Color(0.86, 0.45, 0.38))
	v.add_child(who)
	text_label = Label.new()
	text_label.add_theme_font_override("font", FONT)
	text_label.add_theme_font_size_override("font_size", 30)
	text_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.32))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(700, 0)
	v.add_child(text_label)
	panel.modulate.a = 0.0

## queue a line; hold = seconds it stays after it is fully shown
func line(text: String, hold := 2.8) -> void:
	_queue.append([text, hold])

func clear() -> void:
	_queue.clear()
	_cur = ""
	_hold = 0.0

func busy() -> bool:
	return _cur != "" or not _queue.is_empty()

func _process(delta: float) -> void:
	if _cur == "" and not _queue.is_empty():
		var q: Array = _queue.pop_front()
		_cur = q[0]
		_hold = q[1]
		_shown = 0.0
	if _cur != "":
		_fade = minf(_fade + delta * 5.0, 1.0)
		if _shown < _cur.length():
			_shown += delta * 42.0
			_blip_t -= delta
			if _blip_t <= 0.0 and not quiet:
				_blip_t = randf_range(0.07, 0.12)
				Sound.sfx("res://levels/plush_desk/audio/murmur.ogg", -17.0, randf_range(0.85, 1.15))
		else:
			_hold -= delta
			if _hold <= 0.0:
				_cur = ""
		text_label.text = _cur.substr(0, int(_shown))
	else:
		_fade = maxf(_fade - delta * 3.0, 0.0)
	panel.modulate.a = _fade
	panel.scale = Vector2.ONE * (0.96 + 0.04 * _fade)
	panel.pivot_offset = panel.size * Vector2(0.5, 1.0)
