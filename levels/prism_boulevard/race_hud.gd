## Prism Boulevard – the race HUD: lap and time, the place, star bits, the
## order of all racers, a minimap, the countdown, banners and the speed lines.
extends Control

const FONT := preload("res://levels/prism_boulevard/fonts/Fredoka-Bold.woff2")
const FONT_SB := preload("res://levels/prism_boulevard/fonts/Fredoka-SemiBold.woff2")
const SPEED := preload("res://levels/prism_boulevard/shaders/speed_lines.gdshader")

var lap_label: Label
var time_label: Label
var place_label: Label
var place_suffix: Label
var bits_label: Label
var banner: Label
var sub_banner: Label
var count_label: Label
var order_box: Control
var order_dots: Array = []
var map_root: Control
var map_dots: Array = []
var speed_rect: ColorRect
var speed_mat: ShaderMaterial
var flash: ColorRect
var results: VBoxContainer
var _map_xform := Transform2D()
var _place := 0
var _bits := -1

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _label(size: int, col := Color(1, 1, 1), outline := 12, font: Font = FONT) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.06, 0.3))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.0, 0.12, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _pill() -> PanelContainer:
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.04, 0.2, 0.5)
	sb.set_corner_radius_all(36)
	sb.content_margin_left = 26; sb.content_margin_right = 26
	sb.content_margin_top = 6; sb.content_margin_bottom = 8
	sb.border_color = Color(1, 1, 1, 0.28)
	sb.set_border_width_all(2)
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill

func build(track, karts: Array, player_kart) -> void:
	# speed lines under everything
	speed_rect = ColorRect.new()
	speed_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	speed_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_mat = ShaderMaterial.new()
	speed_mat.shader = SPEED
	speed_rect.material = speed_mat
	add_child(speed_rect)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	add_child(flash)
	# top right: lap + time
	var pill := _pill()
	pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.offset_right = -40
	pill.offset_top = 34
	add_child(pill)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -8)
	pill.add_child(col)
	lap_label = _label(48, Color(1, 0.95, 0.8), 10)
	lap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(lap_label)
	time_label = _label(30, Color(0.85, 0.92, 1.0), 8, FONT_SB)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(time_label)
	# minimap under it
	map_root = Control.new()
	map_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_root.offset_left = -300
	map_root.offset_right = -40
	map_root.offset_top = 170
	map_root.offset_bottom = 430
	map_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_root)
	_build_map(track, karts, player_kart)
	# bottom right: the place
	var pr := HBoxContainer.new()
	pr.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pr.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pr.offset_right = -44
	pr.offset_bottom = -20
	pr.alignment = BoxContainer.ALIGNMENT_END
	pr.add_theme_constant_override("separation", 2)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pr)
	place_label = _label(150, Color(1, 0.85, 0.35), 18)
	pr.add_child(place_label)
	place_suffix = _label(64, Color(1, 0.85, 0.35), 12)
	place_suffix.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	place_suffix.custom_minimum_size.y = 120
	place_suffix.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	pr.add_child(place_suffix)
	# bottom left: star bits
	var bp := _pill()
	bp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bp.offset_left = 40
	bp.offset_bottom = -40
	add_child(bp)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 12)
	bp.add_child(brow)
	brow.add_child(_gem_icon(Color(1.0, 0.85, 0.3)))
	bits_label = _label(46, Color(1, 0.97, 0.88), 10)
	brow.add_child(bits_label)
	# left: the order of all racers
	order_box = Control.new()
	order_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	order_box.offset_left = 38
	order_box.offset_top = -230
	order_box.offset_bottom = 230
	order_box.offset_right = 120
	order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(order_box)
	for k in karts:
		var d := _dot(k.paint, 22.0 if k == player_kart else 15.0, k == player_kart)
		order_box.add_child(d)
		order_dots.append([d, k])
	# centre: countdown + banners
	count_label = _label(220, Color(1, 1, 1), 26)
	_center(count_label, -150)
	count_label.modulate.a = 0.0
	banner = _label(120, Color(1, 0.9, 0.5), 22)
	_center(banner, -170)
	banner.modulate.a = 0.0
	sub_banner = _label(44, Color(0.9, 0.95, 1.0), 10, FONT_SB)
	_center(sub_banner, -60)
	sub_banner.modulate.a = 0.0

func _center(l: Label, dy: float) -> void:
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.position.y += dy
	add_child(l)

func _gem_icon(c: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(44, 52)
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(22, 2), Vector2(40, 18), Vector2(34, 46), Vector2(10, 46), Vector2(4, 18)])
	p.color = c
	holder.add_child(p)
	var hi := Polygon2D.new()
	hi.polygon = PackedVector2Array([Vector2(22, 6), Vector2(34, 18), Vector2(22, 24), Vector2(10, 18)])
	hi.color = c.lightened(0.6)
	holder.add_child(hi)
	return holder

func _circle(r: float, col: Color, seg := 24) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in seg:
		pts.append(Vector2(cos(TAU * i / seg), sin(TAU * i / seg)) * r)
	p.polygon = pts
	p.color = col
	return p

func _dot(col: Color, r: float, me: bool) -> Node2D:
	var n := Node2D.new()
	n.add_child(_circle(r + 4.0, Color(1, 1, 1, 0.95) if me else Color(0.15, 0.05, 0.3, 0.8)))
	n.add_child(_circle(r, col))
	if me:
		var star := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI * 0.5 + TAU * i / 10.0
			pts.append(Vector2(cos(a), sin(a)) * (r * 0.6 if i % 2 == 0 else r * 0.26))
		star.polygon = pts
		star.color = Color(1, 1, 1)
		n.add_child(star)
	return n

func _build_map(track, karts: Array, player_kart) -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in range(0, track.n, 4):
		var p: Vector3 = track.P[i]
		mn = mn.min(Vector2(p.x, p.z))
		mx = mx.max(Vector2(p.x, p.z))
	var size := Vector2(260, 260)
	var sc := minf(size.x / (mx.x - mn.x), size.y / (mx.y - mn.y)) * 0.92
	var off := (size - (mx - mn) * sc) * 0.5
	_map_xform = Transform2D(0.0, Vector2(sc, sc), 0.0, off - mn * sc)
	var pts := PackedVector2Array()
	for i in range(0, track.n, 6):
		var p: Vector3 = track.P[i]
		pts.append(_map_xform * Vector2(p.x, p.z))
	pts.append(pts[0])
	var under := Line2D.new()
	under.points = pts
	under.width = 11.0
	under.default_color = Color(0.1, 0.03, 0.25, 0.65)
	under.joint_mode = Line2D.LINE_JOINT_ROUND
	map_root.add_child(under)
	var line := Line2D.new()
	line.points = pts
	line.width = 5.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.6, 0.7), Color(1, 0.9, 0.5), Color(0.6, 1, 0.7), Color(0.5, 0.8, 1), Color(0.8, 0.6, 1), Color(1, 0.6, 0.7)])
	g.offsets = PackedFloat32Array([0, 0.2, 0.4, 0.6, 0.8, 1])
	line.gradient = g
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	map_root.add_child(line)
	# start line
	var sl := _circle(5.0, Color(1, 1, 1))
	sl.position = pts[0]
	map_root.add_child(sl)
	for k in karts:
		var d := _dot(k.paint, 7.0 if k == player_kart else 5.0, k == player_kart)
		map_root.add_child(d)
		map_dots.append([d, k])
	# the player's dot on top
	for md in map_dots:
		if md[1] == player_kart: map_root.move_child(md[0], -1)

func update_race(player_kart, karts: Array, laps: int, race_time: float, dt: float) -> void:
	var lp: int = clampi(player_kart.lap + 1, 1, laps)
	lap_label.text = "LAP %d/%d" % [lp, laps]
	time_label.text = fmt_time(race_time)
	if player_kart.place != _place:
		_place = player_kart.place
		place_label.text = str(_place)
		place_suffix.text = ordinal_suffix(_place)
		var c := place_color(_place)
		place_label.add_theme_color_override("font_color", c)
		place_suffix.add_theme_color_override("font_color", c)
		place_label.pivot_offset = place_label.size * 0.5
		var tw := create_tween()
		place_label.scale = Vector2(1.25, 1.25)
		tw.tween_property(place_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	if player_kart.bits != _bits:
		_bits = player_kart.bits
		bits_label.text = str(_bits)
	for od in order_dots:
		var d: Node2D = od[0]
		var k = od[1]
		var target := Vector2(30, 20 + (k.place - 1) * 56.0)
		d.position = d.position.lerp(target, 1.0 - exp(-10.0 * dt)) if d.position != Vector2.ZERO else target
	for md in map_dots:
		var k = md[1]
		var p: Vector3 = k.world_pos
		(md[0] as Node2D).position = _map_xform * Vector2(p.x, p.z)

func set_speed_lines(amount: float) -> void:
	speed_mat.set_shader_parameter("amount", amount)

static func fmt_time(t: float) -> String:
	var m := int(t / 60.0)
	var sec := t - m * 60.0
	return "%d:%05.2f" % [m, sec]

static func ordinal_suffix(p: int) -> String:
	if p == 1: return "st"
	if p == 2: return "nd"
	if p == 3: return "rd"
	return "th"

static func place_color(p: int) -> Color:
	match p:
		1: return Color(1.0, 0.85, 0.3)
		2: return Color(0.85, 0.9, 1.0)
		3: return Color(1.0, 0.65, 0.4)
	return Color(0.75, 0.8, 1.0)

func show_count(text: String, col: Color) -> void:
	count_label.text = text
	count_label.add_theme_color_override("font_color", col)
	count_label.pivot_offset = count_label.size * 0.5
	count_label.modulate.a = 1.0
	count_label.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(count_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(count_label, "modulate:a", 0.0, 0.2)

func show_banner(text: String, sub := "", hold := 1.8, col := Color(1, 0.9, 0.5)) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	sub_banner.text = sub
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sub_banner, "modulate:a", 1.0 if sub != "" else 0.0, 0.3)
	if hold > 0.0:
		tw.tween_interval(hold)
		tw.tween_property(banner, "modulate:a", 0.0, 0.4)
		tw.parallel().tween_property(sub_banner, "modulate:a", 0.0, 0.4)

func hide_banner() -> void:
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(sub_banner, "modulate:a", 0.0, 0.3)

func do_flash(a := 0.6, dur := 0.4) -> void:
	flash.color.a = a
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, dur)

## the table at the end: [[place, name, time, is_player, colour], …]
func show_results(rows: Array, title: String) -> void:
	if results: results.queue_free()
	var panel := _pill()
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel")
	sb.set_corner_radius_all(28)
	sb.bg_color = Color(0.07, 0.03, 0.18, 0.72)
	sb.content_margin_left = 40; sb.content_margin_right = 40
	sb.content_margin_top = 22; sb.content_margin_bottom = 26
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	panel.position += Vector2(270, 30)
	results = VBoxContainer.new()
	results.add_theme_constant_override("separation", 2)
	panel.add_child(results)
	var t := _label(56, Color(1, 0.9, 0.5), 12)
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results.add_child(t)
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		var me: bool = r[3]
		var c: Color = Color(1, 0.95, 0.75) if me else Color(0.85, 0.88, 1.0)
		var pl := _label(38, place_color(r[0]), 8)
		pl.text = "%d%s" % [r[0], ordinal_suffix(r[0])]
		pl.custom_minimum_size.x = 90
		row.add_child(pl)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(30, 40)
		var dot := _dot(r[4], 11.0, me)
		dot.position = Vector2(15, 24)
		holder.add_child(dot)
		row.add_child(holder)
		var nm := _label(38, c, 8, FONT_SB if not me else FONT)
		nm.text = r[1]
		nm.custom_minimum_size.x = 260
		row.add_child(nm)
		var tm := _label(34, c, 8, FONT_SB)
		tm.text = r[2]
		row.add_child(tm)
		results.add_child(row)
	var hintl := _label(30, Color(0.85, 0.9, 1.0), 8, FONT_SB)
	hintl.text = "Space: continue   ·   R: race again"
	hintl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results.add_child(hintl)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.5)

func clear_results() -> void:
	if results:
		results.get_parent().queue_free()
		results = null
