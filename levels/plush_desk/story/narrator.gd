## The narrator: lines appear letter by letter on a felt ribbon at the bottom
## of the screen. With a recorded voice for the line, it is played and the text
## runs along with it; without one, a soft hum murmurs while the text runs.
##
## Voice files: audio/narrator/<key>.ogg (or .wav / .mp3), where <key> is the
## first six words of the line in lowercase, joined by "_", without
## apostrophes: "Ah. You're new. Everyone is, at first." -> ah_youre_new_everyone_is_at.
## The player's name in a line counts as "%s". source/narrator_lines.py lists
## every line with its key (source/narrator_lines.md).
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
var voice: AudioStreamPlayer
var _speed := 42.0          # letters per second
var _voiced := false

const VOICE_DIR := "res://levels/plush_desk/audio/narrator/"

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
	voice = AudioStreamPlayer.new()
	voice.bus = "SFX"
	voice.volume_db = 1.0
	add_child(voice)

## the file name (without extension) a recorded line is looked up under
static func voice_key(text: String, player_name := "") -> String:
	var s := text
	if player_name != "":
		s = s.replace(", " + player_name + ".", ", %s.").replace(", " + player_name + ",", ", %s,")
	s = s.to_lower().replace("'", "").replace("\u2019", "")
	var words: PackedStringArray = []
	var cur := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			cur += ch
		elif cur != "":
			words.append(cur)
			cur = ""
	if cur != "":
		words.append(cur)
	return "_".join(words.slice(0, 6))

func _voice_for(text: String) -> AudioStream:
	var pn: Variant = get_parent().get("player_name") if get_parent() else null
	var key := voice_key(text, str(pn) if pn != null else "")
	for ext in [".ogg", ".wav", ".mp3"]:
		var path: String = VOICE_DIR + key + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

## queue a line; hold = seconds it stays after it is fully shown
func line(text: String, hold := 2.8) -> void:
	_queue.append([text, hold])

func clear() -> void:
	_queue.clear()
	_cur = ""
	_hold = 0.0
	voice.stop()

func busy() -> bool:
	return _cur != "" or not _queue.is_empty()

func _process(delta: float) -> void:
	if _cur == "" and not _queue.is_empty():
		var q: Array = _queue.pop_front()
		_cur = q[0]
		_hold = q[1]
		_shown = 0.0
		_speed = 42.0
		_voiced = false
		var st := _voice_for(_cur) if not quiet else null
		if st:
			voice.stream = st
			voice.play()
			_voiced = true
			# the text runs along with the voice and is complete a little before it ends
			var len_s := st.get_length()
			_speed = clampf(_cur.length() / maxf(len_s * 0.8, 0.3), 14.0, 60.0)
			_hold = maxf(_hold * 0.6, len_s - _cur.length() / _speed + 0.7)
	if _cur != "":
		_fade = minf(_fade + delta * 5.0, 1.0)
		if _shown < _cur.length():
			_shown += delta * _speed
			_blip_t -= delta
			if _blip_t <= 0.0 and not quiet and not _voiced:
				_blip_t = randf_range(0.11, 0.17)
				Sound.sfx("res://levels/plush_desk/audio/murmur.ogg", -15.0, randf_range(0.9, 1.12))
		else:
			_hold -= delta
			if _hold <= 0.0 and not (_voiced and voice.playing):
				_cur = ""
		text_label.text = _cur.substr(0, int(_shown))
	else:
		_fade = maxf(_fade - delta * 3.0, 0.0)
	panel.modulate.a = _fade
	panel.scale = Vector2.ONE * (0.96 + 0.04 * _fade)
	panel.pivot_offset = panel.size * Vector2(0.5, 1.0)
