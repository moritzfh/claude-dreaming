## The level editor of "Work in Progress": the cursor, the toolbar with play /
## pause, the toolbox, the output console, the error popup and the commit
## terminal at the end. Everything the player changes in the world goes
## through the level (wip.gd); this script is the UI and the input.
##
## Mouse: click to place / pick up, right click to take back, wheel for the
## tool. Keyboard / gamepad: the move keys move the cursor, E / X place,
## Shift / B take back, Q / Y next tool, Space / A play / pause, R / Back
## Claude to the start, 1–6 pick a tool, Ctrl+Z undo.
extends Node

signal error_closed

const WB := preload("res://levels/wip/world.gd")
const MONO := preload("res://levels/wip/fonts/JetBrainsMono-Regular.woff2")
const MONO_B := preload("res://levels/wip/fonts/JetBrainsMono-Bold.woff2")
const DIR := "res://levels/wip/"

const BG := Color(0.12, 0.13, 0.16, 0.94)
const BG2 := Color(0.19, 0.20, 0.25, 1.0)
const LINE := Color(0.30, 0.32, 0.39)
const TEXT := Color(0.87, 0.89, 0.93)
const DIM := Color(0.56, 0.59, 0.66)
const ORANGE := Color(1.0, 0.62, 0.2)
const GREEN := Color(0.46, 0.86, 0.52)
const RED := Color(1.0, 0.40, 0.37)
const YELLOW := Color(1.0, 0.82, 0.32)
const BLUE := Color(0.5, 0.82, 1.0)
const NAMES := {"block": "Block", "ramp_r": "Rampe ↗", "ramp_l": "Rampe ↖", "spring": "Feder",
	"col_add": "Kollision +", "col_del": "Kollision −"}

var level: Node
var revealed := false
var flags := {}

var _layer: CanvasLayer
var _root: Control
var _frame: Panel
var _bar: Panel
var _btns: Array = []           # [Box, action]
var _mode: Label
var _mode_sub: Label
var _hot: Panel
var _slots: Array = []          # [Box, tool]
var _tool_lbl: Label
var _console: Panel
var _lines: VBoxContainer
var _err: Panel
var _err_msg: Label
var _err_detail: Label
var _err_ok: Box
var _err_open := false
var _term: Panel
var _term_txt: RichTextLabel
var _cursor: TextureRect
var _tex_arrow: Texture2D
var _tex_hand: Texture2D

var _cur := Vector2(960, 540)
var _pad_speed := 500.0
var _tool_i := 0
var _held := {}
var _undo: Array = []
var _ghost: MeshInstance3D
var _ghost_kind := ""
var _ghost_ok: StandardMaterial3D
var _ghost_bad: StandardMaterial3D
var _sel: MeshInstance3D
var _sel_mat: ShaderMaterial
var _last_mouse := Vector2.ZERO
var _hot_hidden := false

## a Control that draws itself with a callable (icons, buttons, slots)
class Box extends Control:
	var painter: Callable
	var hovered := false
	var active := false
	var data: Variant
	func _draw() -> void:
		if painter.is_valid(): painter.call(self)

# ================================================================== setup
func _ready() -> void:
	# keeps running in the pause menu, only to hide the cursor there
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	_build_frame()
	_build_toolbar()
	_build_hotbar()
	_build_console()
	_build_error()
	_build_terminal()
	_build_cursor()
	_build_3d()
	for c in [_frame, _bar, _hot, _tool_lbl, _console]: (c as CanvasItem).modulate.a = 0.0
	_layout()
	get_viewport().size_changed.connect(_layout)
	stage_changed()

func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size

func _style(bg: Color, border := LINE, radius := 8, bw := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb

func _lbl(text: String, size: int, col := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", MONO_B if bold else MONO)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _panel(bg: Color, border := LINE) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _style(bg, border))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _box(painter: Callable, sz: Vector2) -> Box:
	var b := Box.new()
	b.painter = painter
	b.size = sz
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _build_frame() -> void:
	_frame = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(ORANGE, 0.55)
	sb.set_border_width_all(5)
	_frame.add_theme_stylebox_override("panel", sb)
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)

func _build_toolbar() -> void:
	_bar = _panel(BG)
	_bar.size = Vector2(430, 70)
	_root.add_child(_bar)
	var acts := [["play", func(): level.toggle_play()], ["pause", func(): level.toggle_play()], ["reset", func(): level.reset_claude()]]
	for i in acts.size():
		var b := _box(_draw_button, Vector2(54, 50))
		b.data = acts[i][0]
		b.position = Vector2(10 + i * 60, 10)
		_bar.add_child(b)
		_btns.append([b, acts[i][1]])
	_mode = _lbl("BEARBEITEN", 20, ORANGE, true)
	_mode.position = Vector2(196, 9)
	_bar.add_child(_mode)
	_mode_sub = _lbl("Leertaste: Play · R: Reset", 13, DIM)
	_mode_sub.position = Vector2(197, 38)
	_bar.add_child(_mode_sub)

func _build_hotbar() -> void:
	_hot = _panel(BG)
	_root.add_child(_hot)
	_tool_lbl = _lbl("", 20, TEXT, true)
	_tool_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.9))
	_tool_lbl.add_theme_constant_override("outline_size", 6)
	_root.add_child(_tool_lbl)

func _build_console() -> void:
	_console = _panel(Color(0.1, 0.11, 0.13, 0.82))
	_console.size = Vector2(580, 132)
	_root.add_child(_console)
	var tab := _lbl("Ausgabe", 15, DIM, true)
	tab.position = Vector2(14, 6)
	_console.add_child(tab)
	_lines = VBoxContainer.new()
	_lines.position = Vector2(14, 30)
	_lines.size = Vector2(552, 96)
	_lines.add_theme_constant_override("separation", 2)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_console.add_child(_lines)

func _build_error() -> void:
	_err = _panel(BG, Color(RED, 0.8))
	_err.size = Vector2(700, 240)
	_err.visible = false
	_err.pivot_offset = _err.size * 0.5
	_root.add_child(_err)
	var title := _panel(Color(0.2, 0.1, 0.11, 1.0), Color(0, 0, 0, 0))
	title.position = Vector2(2, 2)
	title.size = Vector2(696, 40)
	_err.add_child(title)
	var ic := _box(_draw_error_icon, Vector2(26, 26))
	ic.position = Vector2(12, 7)
	title.add_child(ic)
	var tl := _lbl("Fehler", 19, TEXT, true)
	tl.position = Vector2(48, 8)
	title.add_child(tl)
	_err_msg = _lbl("", 24, TEXT, true)
	_err_msg.position = Vector2(28, 66)
	_err.add_child(_err_msg)
	_err_detail = _lbl("", 17, DIM)
	_err_detail.position = Vector2(28, 108)
	_err.add_child(_err_detail)
	_err_ok = _box(_draw_ok, Vector2(124, 46))
	_err_ok.position = Vector2(700 - 28 - 124, 240 - 24 - 46)
	_err.add_child(_err_ok)

func _build_terminal() -> void:
	_term = _panel(Color(0.045, 0.05, 0.065, 0.97), Color(GREEN, 0.5))
	_term.size = Vector2(1500, 230)
	_term.visible = false
	_root.add_child(_term)
	_term_txt = RichTextLabel.new()
	_term_txt.bbcode_enabled = true
	_term_txt.position = Vector2(24, 18)
	_term_txt.size = Vector2(1452, 200)
	_term_txt.scroll_active = false
	_term_txt.add_theme_font_override("normal_font", MONO)
	_term_txt.add_theme_font_override("bold_font", MONO_B)
	_term_txt.add_theme_font_size_override("normal_font_size", 23)
	_term_txt.add_theme_font_size_override("bold_font_size", 23)
	_term_txt.add_theme_color_override("default_color", TEXT)
	_term_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_term.add_child(_term_txt)

func _build_cursor() -> void:
	var arrow := [
		"X...........",
		"XX..........",
		"XOX.........",
		"XOOX........",
		"XOOOX.......",
		"XOOOOX......",
		"XOOOOOX.....",
		"XOOOOOOX....",
		"XOOOOOOOX...",
		"XOOOOOOOOX..",
		"XOOOOOOOOOX.",
		"XOOOOOOXXXXX",
		"XOOOXOOX....",
		"XOOX.XOOX...",
		"XOX..XOOX...",
		"XX....XOOX..",
		"......XOOX..",
		".......XX...",
	]
	var hand := [
		"....XX.XX.XX....",
		"...XOOXOOXOOX...",
		"...XOOXOOXOOXX..",
		"..XXOOXOOXOOXOX.",
		".XOXOOOOOOOOXOX.",
		".XOOXOOOOOOOOOX.",
		".XOOOOOOOOOOOOX.",
		"..XOOOOOOOOOOX..",
		"..XOOOOOOOOOOX..",
		"...XOOOOOOOOX...",
		"....XOOOOOOX....",
		"....XOOOOOOX....",
		"....XXXXXXXX....",
	]
	_tex_arrow = _pix(arrow)
	_tex_hand = _pix(hand)
	_cursor = TextureRect.new()
	_cursor.texture = _tex_arrow
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor.scale = Vector2(3, 3)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	_root.add_child(_cursor)

func _pix(rows: Array) -> Texture2D:
	var h := rows.size()
	var w := (rows[0] as String).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var r: String = rows[y]
		for x in r.length():
			match r[x]:
				"X": img.set_pixel(x, y, Color(0.08, 0.07, 0.12))
				"O": img.set_pixel(x, y, Color(1.0, 0.98, 0.94))
	return ImageTexture.create_from_image(img)

func _build_3d() -> void:
	_ghost_ok = StandardMaterial3D.new()
	_ghost_ok.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_ok.albedo_color = Color(1.0, 0.7, 0.3, 0.42)
	_ghost_ok.no_depth_test = true
	_ghost_bad = _ghost_ok.duplicate()
	_ghost_bad.albedo_color = Color(1.0, 0.25, 0.25, 0.32)
	_ghost = MeshInstance3D.new()
	_ghost.visible = false
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(_ghost)
	_sel_mat = WB.select_mat(Vector3.ONE)
	_sel = MeshInstance3D.new()
	_sel.mesh = WB.box(Vector3.ONE)
	_sel.material_override = _sel_mat
	_sel.visible = false
	_sel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(_sel)

func _layout() -> void:
	var vs := _vs()
	_bar.position = Vector2((vs.x - _bar.size.x) * 0.5, 16)
	_hot.position = Vector2(24, vs.y - 24 - _hot.size.y)
	_tool_lbl.position = _hot.position + Vector2(4, -36)
	_console.position = Vector2(vs.x - 24 - _console.size.x, 16)
	_err.position = (vs - _err.size) * 0.5
	_term.position = Vector2((vs.x - _term.size.x) * 0.5, vs.y - _term.size.y - 40)

# ================================================================== drawing
func _draw_button(b: Box) -> void:
	var playing: bool = level.playing
	var on: bool = (b.data == "play" and playing) or (b.data == "pause" and not playing)
	var bg := BG2.lightened(0.12) if b.hovered else BG2
	if on: bg = (GREEN if b.data == "play" else ORANGE).darkened(0.55)
	b.draw_style_box(_style(bg, (GREEN if b.data == "play" else ORANGE) if on else LINE, 6, 2), Rect2(Vector2.ZERO, b.size))
	var c := b.size * 0.5
	var col := TEXT if not on else (GREEN if b.data == "play" else ORANGE).lightened(0.3)
	match b.data:
		"play":
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -12), c + Vector2(12, 0), c + Vector2(-8, 12)]), col)
		"pause":
			b.draw_rect(Rect2(c + Vector2(-10, -11), Vector2(7, 22)), col)
			b.draw_rect(Rect2(c + Vector2(3, -11), Vector2(7, 22)), col)
		"reset":
			b.draw_arc(c, 11, -PI * 0.15, PI * 1.45, 24, col, 3.5, true)
			var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * 11
			b.draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -3), tip + Vector2(5, -6), tip + Vector2(2, 6)]), col)

func _draw_slot(b: Box) -> void:
	var tool: String = b.data
	if tool == "":
		b.draw_style_box(_style(BG2, LINE, 8, 2), Rect2(Vector2.ZERO, b.size))
		return
	var n: int = level.inv_count(tool)
	var bg := BG2.lightened(0.1) if b.hovered else BG2
	b.draw_style_box(_style(bg, ORANGE if b.active else LINE, 8, 3 if b.active else 2), Rect2(Vector2.ZERO, b.size))
	var mod := Color(1, 1, 1, 1.0 if n > 0 else 0.35)
	_draw_icon(b, tool, Rect2(Vector2(16, 14), b.size - Vector2(32, 34)), mod)

func _draw_icon(c: CanvasItem, kind: String, r: Rect2, mod: Color) -> void:
	var o := Color(1.0, 0.62, 0.2) * mod
	var ol := Color(1.0, 0.85, 0.65) * mod
	var p := r.position
	var s := r.size
	match kind:
		"block":
			c.draw_rect(Rect2(p + s * 0.12, s * 0.76), o)
			c.draw_rect(Rect2(p + s * 0.12, s * 0.76), ol, false, 2.0)
			c.draw_line(p + Vector2(s.x * 0.5, s.y * 0.12), p + Vector2(s.x * 0.5, s.y * 0.88), ol, 1.0)
			c.draw_line(p + Vector2(s.x * 0.12, s.y * 0.5), p + Vector2(s.x * 0.88, s.y * 0.5), ol, 1.0)
		"ramp_r", "ramp_l":
			var f := 1.0 if kind == "ramp_r" else -1.0
			var x0 := p.x + s.x * (0.12 if f > 0 else 0.88)
			var x1 := p.x + s.x * (0.88 if f > 0 else 0.12)
			var pts := PackedVector2Array([Vector2(x0, p.y + s.y * 0.88), Vector2(x1, p.y + s.y * 0.88), Vector2(x1, p.y + s.y * 0.12)])
			c.draw_colored_polygon(pts, o)
			pts.append(pts[0])
			c.draw_polyline(pts, ol, 2.0)
		"spring":
			c.draw_rect(Rect2(p + Vector2(s.x * 0.12, s.y * 0.78), Vector2(s.x * 0.76, s.y * 0.12)), o)
			var zz := PackedVector2Array()
			for k in 7:
				zz.append(p + Vector2(s.x * (0.3 if k % 2 == 0 else 0.7), s.y * (0.76 - k * 0.075)))
			c.draw_polyline(zz, Color(0.85, 0.88, 0.95) * mod, 3.0)
			c.draw_rect(Rect2(p + Vector2(s.x * 0.18, s.y * 0.14), Vector2(s.x * 0.64, s.y * 0.12)), Color(0.95, 0.32, 0.32) * mod)
		"col_add", "col_del":
			var bc := BLUE * mod
			var rr := Rect2(p + s * 0.14, s * 0.72)
			c.draw_rect(rr, Color(bc, 0.25 * mod.a))
			for k in 4:
				var a := [rr.position, rr.position + Vector2(rr.size.x, 0), rr.end, rr.position + Vector2(0, rr.size.y)]
				var u: Vector2 = a[k]
				var v: Vector2 = a[(k + 1) % 4]
				for d in 5:
					c.draw_line(u.lerp(v, d / 5.0), u.lerp(v, d / 5.0 + 0.12), bc, 2.0)
			var mid := rr.get_center()
			c.draw_line(mid - Vector2(9, 0), mid + Vector2(9, 0), Color(1, 1, 1) * mod, 4.0)
			if kind == "col_add": c.draw_line(mid - Vector2(0, 9), mid + Vector2(0, 9), Color(1, 1, 1) * mod, 4.0)

func _draw_error_icon(b: Box) -> void:
	var c := b.size * 0.5
	b.draw_circle(c, 12.0, RED)
	b.draw_rect(Rect2(c + Vector2(-1.5, -7), Vector2(3, 9)), Color(1, 1, 1))
	b.draw_rect(Rect2(c + Vector2(-1.5, 4), Vector2(3, 3)), Color(1, 1, 1))

func _draw_ok(b: Box) -> void:
	b.draw_style_box(_style(BG2.lightened(0.15) if b.hovered else BG2, ORANGE if b.hovered else LINE, 6, 2), Rect2(Vector2.ZERO, b.size))
	var f := MONO_B
	var w := f.get_string_size("OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	b.draw_string(f, Vector2((b.size.x - w) * 0.5, 30), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT)

# ================================================================== level hooks
## the first fall is over: the editor appears
func reveal() -> void:
	revealed = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_cur = _vs() * Vector2(0.5, 0.55)
	_cursor.visible = true
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c in [_frame, _bar, _hot, _tool_lbl, _console]:
		tw.tween_property(c, "modulate:a", 1.0, 0.5)
	var by := _bar.position.y
	_bar.position.y = -90
	tw.tween_property(_bar, "position:y", by, 0.6)
	var hx := _hot.position.x
	_hot.position.x = -_hot.size.x - 40
	tw.tween_property(_hot, "position:x", hx, 0.6).set_delay(0.15)
	Sound.sfx("riser", -10.0, 1.4)
	log_line("▶  Editor geöffnet – Claude.steuerung = null", "info")

## the level is left: fade the whole editor out
func hide_all() -> void:
	cancel_hold()
	revealed = false
	_cursor.visible = false
	_ghost.visible = false
	_sel.visible = false
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.4)

func stage_changed() -> void:
	_tool_i = 0
	_undo.clear()
	cancel_hold()
	for s in _slots: (s[0] as Node).queue_free()
	_slots.clear()
	var tl: Array = level.tools()
	var n := tl.size()
	if n == 0: tl = ["", "", "", ""]     # an empty toolbox (until it leaves the UI)
	_hot.size = Vector2(tl.size() * 96 - 8 + 24, 112)
	for i in tl.size():
		var b := _box(_draw_slot, Vector2(88, 88))
		b.data = tl[i]
		b.position = Vector2(12 + i * 96, 12)
		var count := _lbl("", 20, TEXT, true)
		count.name = "Count"
		count.position = Vector2(48, 60)
		b.add_child(count)
		var key := _lbl(str(i + 1), 14, DIM, true)
		key.position = Vector2(8, 4)
		b.add_child(key)
		_hot.add_child(b)
		_slots.append([b, tl[i]])
	_hot.visible = not _hot_hidden
	_tool_lbl.visible = _hot.visible
	_layout()
	_refresh()

func hide_hotbar() -> void:
	_hot_hidden = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_hot, "modulate:a", 0.0, 0.5)
	tw.tween_property(_tool_lbl, "modulate:a", 0.0, 0.5)

func hotbar_center() -> Vector2:
	return _hot.position + _hot.size * 0.5

func mode_changed(playing: bool) -> void:
	if _mode == null: return
	_mode.text = "SPIELT" if playing else "BEARBEITEN"
	_mode.add_theme_color_override("font_color", GREEN if playing else ORANGE)
	for b in _btns: (b[0] as CanvasItem).queue_redraw()
	if revealed: log_line("▶  Spiel läuft" if playing else "⏸  Pause – Zeit angehalten", "info")

func log_line(text: String, kind := "info") -> void:
	if _lines == null: return
	var col := {"info": TEXT, "warn": YELLOW, "error": RED, "ok": GREEN}.get(kind, TEXT) as Color
	var t: float = level._t
	var l := _lbl("%02d:%02d  %s" % [int(t / 60.0) % 60, int(t) % 60, text], 16, col)
	l.clip_text = true
	l.custom_minimum_size = Vector2(552, 0)
	_lines.add_child(l)
	while _lines.get_child_count() > 4:
		var old := _lines.get_child(0)
		_lines.remove_child(old)
		old.queue_free()

func show_error(msg: String, detail: String) -> void:
	_err_msg.text = msg
	_err_detail.text = detail
	_err.visible = true
	_err_open = true
	_err.scale = Vector2(0.85, 0.85)
	_err.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_err, "scale", Vector2.ONE, 0.25)
	tw.tween_property(_err, "modulate:a", 1.0, 0.15)
	Sound.sfx(DIR + "audio/error.ogg", -4.0)
	var auto := create_tween()
	auto.tween_interval(3.4)
	auto.tween_callback(_close_error)

func _close_error() -> void:
	if not _err_open: return
	_err_open = false
	var tw := create_tween()
	tw.tween_property(_err, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): _err.visible = false)
	error_closed.emit()

## the finale: a terminal types the commit
func commit_sequence() -> void:
	_term.visible = true
	_term.modulate.a = 0.0
	create_tween().tween_property(_term, "modulate:a", 1.0, 0.3)
	var prompt := "[color=#7ee787]claude@werkstatt[/color]:[color=#79c0ff]~/claude-dreaming[/color]$ "
	var steps := [
		["cmd", "git add levels/wip"],
		["cmd", "git commit -m \"feat: Level fertig (wirklich)\""],
		["out", "[main 7c1a2e9] feat: Level fertig (wirklich)\n 1 level changed, 1 Claude happy, 0 bugs (probably)"],
		["cmd", ""],
	]
	var shown := ""
	for s in steps:
		if s[0] == "cmd":
			var base := shown + prompt
			var cmd: String = s[1]
			for k in cmd.length() + 1:
				_term_txt.text = base + cmd.substr(0, k) + "[color=#e6edf3]█[/color]"
				if k % 3 == 1: Sound.sfx("text", -14.0, randf_range(1.2, 1.5))
				await _pause(0.035)
			shown = base + cmd + "\n"
			await _pause(0.35)
		else:
			shown += "[color=#c9d1d9]" + s[1] + "[/color]\n"
			_term_txt.text = shown
			Sound.sfx("blip", -10.0, 1.5)
			await _pause(0.6)
	_term_txt.text = shown.trim_suffix("\n") + "[color=#e6edf3]█[/color]"
	await _pause(1.6)
	create_tween().tween_property(_term, "modulate:a", 0.0, 0.5)

func _pause(t: float) -> Signal:
	var tw := create_tween()
	tw.tween_interval(t)
	return tw.finished

func cancel_hold() -> void:
	if _held.is_empty(): return
	if _held["type"] == "piece":
		level.drop(_held["ref"], _held["from"])
	else:
		var p: Dictionary = _held["ref"]
		level.panel_drop(p, _held["from"])
	_held = {}

# ================================================================== input
func _tool() -> String:
	var tl: Array = level.tools()
	if tl.is_empty(): return ""
	return tl[clampi(_tool_i, 0, tl.size() - 1)]

func _can_edit() -> bool:
	return revealed and not level.locked and not get_tree().paused

func _input(event: InputEvent) -> void:
	if not revealed or get_tree().paused: return
	if event is InputEventMouseMotion:
		_cur = (event as InputEventMouseMotion).position
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_cur = mb.position
		get_viewport().set_input_as_handled()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed: _primary(true)
			else: _release()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed: _secondary()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: _cycle(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: _cycle(1)
	elif event is InputEventKey and event.pressed and not event.is_echo():
		var k := event as InputEventKey
		if k.keycode == KEY_Z and (k.ctrl_pressed or k.meta_pressed):
			get_viewport().set_input_as_handled()
			_do_undo()
		elif k.keycode >= KEY_1 and k.keycode <= KEY_6 and not k.ctrl_pressed:
			var i := k.keycode - KEY_1
			if i < (level.tools() as Array).size():
				_tool_i = i
				Sound.sfx("beep", -14.0, 1.6)
				_refresh()

func _process(delta: float) -> void:
	if not revealed: return
	var paused := get_tree().paused
	_cursor.visible = not paused
	if paused: return
	# the mouse moves the cursor (see _input); so do the move keys and the left stick
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if v.length() > 0.15:
		_pad_speed = minf(_pad_speed + delta * 1600.0, 1250.0)
		_cur += v * _pad_speed * delta
	else:
		_pad_speed = 480.0
	_cur = _cur.clamp(Vector2.ZERO, _vs())
	if _err_open:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"): _close_error()
	elif _can_edit():
		if Input.is_action_just_pressed("interact"): _primary(false)
		if Input.is_action_just_pressed("sprint"): _secondary()
		if Input.is_action_just_pressed("mood"): _cycle(1)
		if Input.is_action_just_pressed("jump"): level.toggle_play()
		if Input.is_action_just_pressed("respawn"): level.reset_claude()
	_update_hover()
	_frame.modulate.a = level.edit_view * 0.9 if revealed else 0.0

func _ui_hit() -> Box:
	for b in _btns:
		if (b[0] as Box).get_global_rect().has_point(_cur): return b[0]
	if _hot.visible and _hot.modulate.a > 0.5:
		for s in _slots:
			if s[1] != "" and (s[0] as Box).get_global_rect().has_point(_cur): return s[0]
	if _err_open and _err_ok.get_global_rect().has_point(_cur): return _err_ok
	return null

func _ui_click() -> bool:
	if _err_open:
		_close_error()
		return true
	var b := _ui_hit()
	if b == null:
		return _hot.visible and _hot.get_global_rect().has_point(_cur) or _bar.get_global_rect().has_point(_cur)
	if not _can_edit(): return true
	for x in _btns:
		if x[0] == b: (x[1] as Callable).call(); return true
	for i in _slots.size():
		if _slots[i][0] == b:
			_tool_i = i
			Sound.sfx("beep", -14.0, 1.6)
			_refresh()
			return true
	return true

func _primary(from_mouse: bool) -> void:
	if _ui_click(): return
	if not _can_edit(): return
	var cell: Vector2i = level.screen_to_cell(_cur)
	if not _held.is_empty():
		_drop(cell)
		return
	var pn: Dictionary = level.panel_at(cell)
	if pn.is_empty(): pn = level.panel_on_screen(_cur)
	if not pn.is_empty():
		_grab_panel(pn, cell, from_mouse)
		return
	var e: Dictionary = level.what_at(cell)
	if e.get("kind") == "piece":
		_held = {"type": "piece", "ref": e["piece"], "from": (e["piece"] as Dictionary)["cell"], "mouse": from_mouse}
		level.pick(e["piece"])
		Sound.sfx(DIR + "audio/pick.ogg", -6.0)
		return
	var tool := _tool()
	if tool == "": return
	if tool == "col_add" or tool == "col_del":
		if e.get("kind") == "wire":
			var w: Dictionary = e["wire"]
			if level.wire_tool(w, tool == "col_add"):
				_undo.append(func() -> bool: return level.wire_revert(w))
				log_line(("+  CollisionShape3D hinzugefügt" if tool == "col_add" else "−  CollisionShape3D entfernt") + "  (%s)" % w["id"], "ok")
				Sound.sfx(DIR + "audio/place.ogg", -4.0, 1.3)
				_refresh()
				return
		_nope("Das geht hier nicht." if level.inv_count(tool) > 0 else "Keine %s mehr übrig." % NAMES[tool])
		return
	if level.can_place(tool, cell):
		var p: Dictionary = level.place(tool, cell)
		_undo.append(func() -> bool: level.remove(p); return true)
		log_line("+  %s bei (%d, %d)" % [NAMES[tool], cell.x % 24, cell.y], "info")
		Sound.sfx(DIR + "audio/place.ogg", -4.0, randf_range(0.95, 1.05))
		_refresh()
	elif level.inv_count(tool) <= 0:
		_nope("Keine %s mehr übrig – Rechtsklick nimmt Teile zurück." % NAMES[tool])
	else:
		_nope("")

func _grab_panel(pn: Dictionary, cell: Vector2i, from_mouse: bool) -> void:
	var from: Vector2i = pn["cell"]
	var off := 0
	if bool(pn["placed"]): off = clampi(cell.x - from.x, 0, int(pn["w"]) - 1)
	else: off = int(pn["w"]) / 2
	if bool(pn["placed"]) and _claude_on(pn):
		_nope("Claude steht da drauf.")
		return
	_held = {"type": "panel", "ref": pn, "from": from, "off": off, "mouse": from_mouse}
	level.panel_pick(pn)
	Sound.sfx(DIR + "audio/pick.ogg", -6.0, 0.9)
	if not flags.has("panel_log"):
		flags["panel_log"] = true
		log_line("W  UI-Element verlässt die Benutzeroberfläche", "warn")

func _claude_on(pn: Dictionary) -> bool:
	var c: Vector2i = pn["cell"]
	var p: Vector3 = level.claude.global_position
	return p.x > c.x - 0.3 and p.x < c.x + int(pn["w"]) + 0.3 and absf(p.y - (c.y + 1.0)) < 0.25

func _release() -> void:
	if _held.is_empty() or not bool(_held["mouse"]): return
	var cell: Vector2i = level.screen_to_cell(_cur)
	var target := cell if _held["type"] == "piece" else cell - Vector2i(int(_held["off"]), 0)
	if target == _held["from"] and _held["type"] == "piece":
		_held["mouse"] = false        # a click: keep holding it until the next click
		return
	_drop(cell)

func _drop(cell: Vector2i) -> void:
	var h := _held
	_held = {}
	if h["type"] == "piece":
		var p: Dictionary = h["ref"]
		var from: Vector2i = h["from"]
		if level.drop(p, cell):
			if cell != from:
				_undo.append(func() -> bool:
					level.pick(p)
					var ok: bool = level.drop(p, from)
					return ok)
			Sound.sfx(DIR + "audio/place.ogg", -4.0, 1.08)
		else:
			_nope("Da ist kein Platz.")
	else:
		var pn: Dictionary = h["ref"]
		var left := cell - Vector2i(int(h["off"]), 0)
		var from: Vector2i = h["from"]
		var was_placed: bool = pn["placed"]
		if level.panel_drop(pn, left):
			if was_placed:
				_undo.append(func() -> bool:
					level.panel_pick(pn)
					return level.panel_drop(pn, from))
			Sound.sfx(DIR + "audio/place.ogg", -4.0, 0.9)
		else:
			if not was_placed:
				level.panel_drop(pn, from)
			_nope("Da passt das nicht hin.")
	_refresh()

func _secondary() -> void:
	if not _can_edit(): return
	if not _held.is_empty():
		cancel_hold()
		Sound.sfx(DIR + "audio/pick.ogg", -8.0, 0.8)
		return
	var cell: Vector2i = level.screen_to_cell(_cur)
	var e: Dictionary = level.what_at(cell)
	if e.get("kind") == "piece":
		var p: Dictionary = e["piece"]
		level.remove(p)
		_undo.append(func() -> bool: return level.restore(p))
		log_line("−  %s zurück in den Werkzeugkasten" % NAMES[p["kind"]], "info")
		Sound.sfx(DIR + "audio/pick.ogg", -5.0, 0.85)
		_refresh()
	elif e.get("kind") == "wire" and (e["wire"] as Dictionary).has("changed"):
		var w: Dictionary = e["wire"]
		var key: String = w["changed"]
		level.wire_revert(w)
		_undo.append(func() -> bool: return level.wire_tool(w, key == "col_add"))
		log_line("↺  Kollision zurückgesetzt  (%s)" % w["id"], "info")
		Sound.sfx(DIR + "audio/pick.ogg", -5.0, 0.85)
		_refresh()

func _cycle(d: int) -> void:
	if not _can_edit(): return
	var n := (level.tools() as Array).size()
	if n == 0: return
	_tool_i = (_tool_i + d + n) % n
	Sound.sfx("beep", -14.0, 1.6)
	_refresh()

func _do_undo() -> void:
	if not _can_edit() or not _held.is_empty(): return
	if _undo.is_empty():
		_nope("Nichts zum Rückgängigmachen.")
		return
	var f: Callable = _undo.pop_back()
	if f.call():
		log_line("↶  Rückgängig (Strg+Z – natürlich geht das)", "info")
		Sound.sfx(DIR + "audio/pick.ogg", -6.0, 1.2)
	else:
		_nope("Rückgängig geht gerade nicht.")
	_refresh()

func _nope(why: String) -> void:
	Sound.sfx(DIR + "audio/nope.ogg", -6.0)
	if why != "": log_line("W  " + why, "warn")

func _refresh() -> void:
	for i in _slots.size():
		var b: Box = _slots[i][0]
		b.active = i == _tool_i
		var n: int = level.inv_count(_slots[i][1])
		(b.get_node("Count") as Label).text = "×%d" % n if _slots[i][1] != "" else ""
		b.queue_redraw()
	var t := _tool()
	_tool_lbl.text = "%s   ×%d" % [NAMES.get(t, ""), level.inv_count(t)] if t != "" else ""

# ================================================================== hover, ghost, selection
func _update_hover() -> void:
	var hit := _ui_hit()
	for b in _btns + _slots:
		var bx: Box = b[0]
		var h := bx == hit
		if bx.hovered != h:
			bx.hovered = h
			bx.queue_redraw()
	if _err_ok.hovered != (hit == _err_ok):
		_err_ok.hovered = hit == _err_ok
		_err_ok.queue_redraw()
	var over_ui := hit != null or (_hot.visible and _hot.modulate.a > 0.5 and _hot.get_global_rect().has_point(_cur)) or _bar.get_global_rect().has_point(_cur) or _err_open
	var wp: Vector3 = level.screen_to_world(_cur)
	var cell := Vector2i(floori(wp.x), floori(wp.y))
	var grid: ShaderMaterial = level._grid_mat
	grid.set_shader_parameter("cursor", Vector2(wp.x, wp.y))
	var grab := false
	_ghost.visible = false
	_sel.visible = false
	var hover_on := 0.0
	var editing := _can_edit() and not over_ui
	if not _held.is_empty():
		grab = true
		if _held["type"] == "piece":
			var p: Dictionary = _held["ref"]
			var n: Node3D = p["node"]
			n.position = n.position.lerp(Vector3(cell.x + 0.5, cell.y + 0.5, 0.25), 0.45)
			_show_sel(Vector3(cell.x + 0.5, cell.y + 0.5, 0), Vector3(1.08, 1.08, 1.7), Color(1.0, 0.62, 0.2) if level.cell_free(cell) else RED)
		else:
			var pn: Dictionary = _held["ref"]
			var left := cell - Vector2i(int(_held["off"]), 0)
			level.panel_hover(pn, left)
			var w := float(pn["w"])
			_show_sel(Vector3(left.x + w * 0.5, left.y + 0.5, 0), Vector3(w + 0.08, 1.08, 0.4), Color(1.0, 0.62, 0.2) if level.panel_fits(pn, left) else RED)
	elif editing:
		var pn: Dictionary = level.panel_at(cell)
		if pn.is_empty(): pn = level.panel_on_screen(_cur)
		var e: Dictionary = level.what_at(cell)
		if not pn.is_empty():
			grab = true
			var n: Node3D = pn["node"]
			var w := float(pn["w"])
			_show_sel(n.position + Vector3(0, -0.5 if bool(pn["placed"]) else (pn["center"] as Vector3).y, 0), Vector3(w + 0.1, 1.1, 0.4), Color(1.0, 0.62, 0.2))
		elif e.get("kind") == "piece":
			grab = true
			var n: Node3D = (e["piece"] as Dictionary)["node"]
			_show_sel(n.position, Vector3(1.1, 1.1, 1.72), Color(1.0, 0.62, 0.2))
		elif e.get("kind") == "wire" and _tool() in ["col_add", "col_del"]:
			var w: Dictionary = e["wire"]
			var mi: MeshInstance3D = w["mesh"]
			var ok: bool = level.inv_count(_tool()) > 0 and not w.has("changed") and bool(w["col"]) != (_tool() == "col_add")
			_show_sel(mi.global_position, (w["size"] as Vector3) + Vector3(0.12, 0.12, 0.12), BLUE if ok else Color(0.6, 0.6, 0.7))
		else:
			var t := _tool()
			if t in ["block", "ramp_r", "ramp_l", "spring"] and not (cell in level._claude_cells()):
				_show_ghost(t, cell, level.can_place(t, cell))
				hover_on = 1.0
	grid.set_shader_parameter("hover_cell", Vector2(cell))
	grid.set_shader_parameter("hover_on", hover_on)
	_cursor.texture = _tex_hand if grab else _tex_arrow
	_cursor.position = _cur - (Vector2(24, 6) if grab else Vector2(1, 1))

func _show_sel(pos: Vector3, size: Vector3, col: Color) -> void:
	_sel.visible = true
	_sel.position = pos
	_sel.scale = size
	_sel_mat.set_shader_parameter("size", size)
	_sel_mat.set_shader_parameter("color", col)

func _show_ghost(kind: String, cell: Vector2i, ok: bool) -> void:
	if kind != _ghost_kind:
		_ghost_kind = kind
		match kind:
			"block": _ghost.mesh = WB.box(Vector3(1, 1, WB.DEPTH))
			"ramp_r": _ghost.mesh = WB.ramp(1.0)[0]
			"ramp_l": _ghost.mesh = WB.ramp(-1.0)[0]
			"spring": _ghost.mesh = WB.box(Vector3(0.9, 0.5, 1.0))
	_ghost.visible = true
	_ghost.material_override = _ghost_ok if ok else _ghost_bad
	_ghost.position = Vector3(cell.x + 0.5, cell.y + (0.25 if kind == "spring" else 0.5), 0)
