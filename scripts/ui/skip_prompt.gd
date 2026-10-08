## "Hold [Space] to skip" over the films (VideoChain). A ring fills while the
## player holds Space, Enter, E, A or X on a gamepad, the left mouse button or
## a finger on the screen; the key shown follows the device used last. It is
## fully visible for the first seconds, then a little quieter, and any press
## brings it back (a press of another key makes the key cap blink: hold this one).
extends Control

signal done

const HOLD := 1.0            # seconds to hold
const SHOW_AT := 1.0         # appears after the title screen's fade
const LOUD_FOR := 8.0        # fully visible this long, then quieter
const IDLE_ALPHA := 0.6
const ACTIONS := ["skip", "jump", "interact"]
const FONT := preload("res://assets/fonts/EBGaramond-SemiBold.woff2")
const FONT_IT := preload("res://assets/fonts/EBGaramond-Italic.woff2")
const GOLD := Color(1.0, 0.86, 0.55)
const CREAM := Color(1.0, 0.96, 0.9)
const INK := Color(0.13, 0.08, 0.18)
const H := 64.0              # height of the pill
const MARGIN := Vector2(40, 36)
const TEXT := 28
const KEY_TEXT := 22

## 0..1 while held
var progress := 0.0
var _t := 0.0
var _wake := 0.0             # seconds of "fully visible" left after a press
var _bump := 0.0             # 1 → 0: the key cap blinks
var _armed := false          # a hold only counts if it started while the film runs
var _fired := false
var _gone := false
var _touches := {}
var _device := "kb"          # kb / pad / touch
var _pill := StyleBoxFlat.new()
var _cap := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		_device = "touch"
	elif not Input.get_connected_joypads().is_empty():
		_device = "pad"
	_pill.bg_color = Color(0.07, 0.04, 0.11, 0.7)
	_pill.set_corner_radius_all(int(H / 2))
	_pill.set_border_width_all(2)
	_pill.anti_aliasing = true
	_cap.set_corner_radius_all(9)
	_cap.border_width_bottom = 4
	_cap.border_color = Color(0.66, 0.55, 0.42)
	_cap.anti_aliasing = true
	modulate.a = 0.0
	_layout()

## the film is over (watched or skipped): fade out
func dismiss() -> void:
	if _gone: return
	_gone = true
	create_tween().tween_property(self, "modulate:a", 0.0, 0.25)

# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if _gone: return
	var dev := ""
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed: _touches[st.index] = true
		else: _touches.erase(st.index)
		dev = "touch"
	elif event is InputEventJoypadButton:
		dev = "pad"
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5: dev = "pad"
	elif event is InputEventKey:
		dev = "kb"
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		dev = "kb"
	if dev != "" and dev != _device:
		_device = dev
		_layout()
	if event is InputEventMouseMotion or not event.is_pressed() or event.is_echo(): return
	if event is InputEventJoypadMotion: return
	_wake = 3.0
	if _is_skip_press(event): _armed = true
	else: _bump = 1.0

func _is_skip_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch: return true
	if event is InputEventMouseButton: return (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	for a in ACTIONS:
		if event.is_action(a): return true
	return false

func _holding() -> bool:
	for a in ACTIONS:
		if Input.is_action_pressed(a): return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not _touches.is_empty()

func _process(delta: float) -> void:
	_t += delta
	var held := _holding()
	if not held: _armed = false
	if _gone:
		queue_redraw()
		return
	if _armed and held:
		progress = minf(1.0, progress + delta / HOLD)
	else:
		progress = maxf(0.0, progress - delta * 3.0 / HOLD)
	if progress >= 1.0 and not _fired:
		_fired = true
		done.emit()
	_wake = maxf(0.0, _wake - delta)
	_bump = maxf(0.0, _bump - delta * 2.5)
	var target := 0.0
	if _t >= SHOW_AT:
		target = 1.0 if (_t < SHOW_AT + LOUD_FOR or _wake > 0.0 or progress > 0.0) else IDLE_ALPHA
	modulate.a = move_toward(modulate.a, target, delta * (3.0 if target > modulate.a else 0.8))
	var b := sin(_bump * PI) * 0.07
	scale = Vector2.ONE * (1.0 + b + 0.04 * progress)
	queue_redraw()

# ------------------------------------------------------------------ drawing
func _parts() -> Array:
	match _device:
		"pad": return [["text", "Hold"], ["button", "A"], ["text", "to skip"]]
		"touch": return [["text", "Touch & hold to skip"]]
	return [["text", "Hold"], ["key", "Space"], ["text", "to skip"]]

func _part_w(p: Array) -> float:
	match p[0]:
		"text": return FONT.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT).x
		"key": return FONT.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_TEXT).x + 30.0
		"button": return 38.0
	return 0.0

func _layout() -> void:
	var w := 22.0 + 40.0 + 16.0          # padding, the ring, gap
	var parts := _parts()
	for i in parts.size():
		w += _part_w(parts[i]) + (12.0 if i < parts.size() - 1 else 0.0)
	w += 28.0
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_right = -MARGIN.x
	offset_left = -MARGIN.x - w
	offset_bottom = -MARGIN.y
	offset_top = -MARGIN.y - H - 32.0     # the pill and the small line under it
	pivot_offset = Vector2(w, H / 2)      # it grows from its right end
	queue_redraw()

func _baseline(f: Font, fs: int, cy: float) -> float:
	return cy + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0

func _draw() -> void:
	var w := size.x
	var hot := maxf(_bump, progress)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2) if _t < SHOW_AT + LOUD_FOR else 0.0
	_pill.border_color = Color(GOLD, 0.3 + 0.35 * pulse).lerp(GOLD, progress)
	draw_style_box(_pill, Rect2(0, 0, w, H))
	# the ring with a fast-forward sign; it fills while held
	var c := Vector2(22.0 + 20.0, H / 2)
	draw_arc(c, 18.0, 0.0, TAU, 48, Color(CREAM, 0.28), 4.0, true)
	if progress > 0.0:
		draw_arc(c, 18.0, -PI / 2, -PI / 2 + TAU * progress, 48, GOLD, 5.0, true)
	var ff := CREAM.lerp(GOLD, progress)
	for dx in [-8.0, 0.0]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(dx, -6.5), c + Vector2(dx + 8.5, 0), c + Vector2(dx, 6.5)]), ff)
	var x := 22.0 + 40.0 + 16.0
	for p in _parts():
		var pw := _part_w(p)
		match p[0]:
			"text":
				draw_string(FONT, Vector2(x, _baseline(FONT, TEXT, H / 2)), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT, CREAM)
			"key":
				_cap.bg_color = CREAM.lerp(GOLD, hot)
				draw_style_box(_cap, Rect2(x, H / 2 - 19, pw, 38))
				draw_string(FONT, Vector2(x + 15, _baseline(FONT, KEY_TEXT, H / 2 - 2)), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_TEXT, INK)
			"button":
				var bc := Vector2(x + 19, H / 2)
				draw_circle(bc, 18.0, Color(0.36, 0.7, 0.36).lerp(GOLD, hot))
				var lw := FONT.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_TEXT).x
				draw_string(FONT, Vector2(bc.x - lw / 2, _baseline(FONT, KEY_TEXT, bc.y)), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_TEXT, Color.WHITE)
		x += pw + 12.0
	# the pause menu, small, under the pill
	var sub: String = {"kb": "Esc: menu", "pad": "Start: menu"}.get(_device, "")
	if sub != "":
		var sw := FONT_IT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(FONT_IT, Vector2(w - sw - 26, H + 24), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(CREAM, 0.6))
