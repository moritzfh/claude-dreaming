## The plush keyboard: a stuffed felt case, 88 felt keycap cushions (one
## MultiMesh), a piped seam, the USB port and the fairy lights.
## Real key presses (physical keys, so QWERTY and QWERTZ both work) and
## Claude's feet push the keys down; they bounce back like stuffed cushions.
extends Node3D

const KEYCAP := preload("res://levels/plush_desk/shaders/keycap.gdshader")
const FABRIC := preload("res://levels/plush_desk/shaders/fabric.gdshader")
const Geo := preload("res://levels/plush_desk/geo.gd")
const T_FELT := preload("res://levels/plush_desk/textures/felt.png")
const T_KNIT := preload("res://levels/plush_desk/textures/knit.png")
const T_MOTTLE := preload("res://levels/plush_desk/textures/mottle.png")
const T_LABELS := preload("res://levels/plush_desk/textures/labels.png")

const PITCH := 0.55
const KEY_TRAVEL := 0.1

## must match LABELS in source/make_textures.py
const LABELS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R",
	"S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"Ä", "Ö", "Ü", "ß", "`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/", "<", "#", "+", "^", "´",
	"esc", "tab", "caps", "shift", "ctrl", "alt", "enter", "del", "ins", "home", "end",
	"pg up", "pg dn", "fn", "menu", "BKSP", "LEFT", "RIGHT", "UP", "DOWN", "STAR",
	"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
	"prt", "scr", "pause", "alt gr"]

## [x in key units, row, width, physical key, fixed label or "", felt colour, location]
## location: 0 any, 1 left, 2 right (for the doubled modifiers)
var layout: Array = []
var keys: Array = []          # dictionaries
var mm: MultiMesh
var mat: ShaderMaterial
var base_top := 0.36
var key_y := 0.36
var key_rect := Rect2()       # xz of the key area (local)
var size := Vector3()
var port_pos := Vector3()     # top of the USB port (local)
var glow_lights: Array = []
var lit := 0.0                # fairy lights master 0..1
var _wave_t := -1.0
var _wave_order: Array = []
var _blip_i := 0
var _t := 0.0

func _row(y: float, items: Array, x0 := 0.0) -> void:
	var x := x0
	for it in items:
		if it is float or it is int:
			x += float(it)          # a gap
			continue
		var w: float = it[0]
		layout.append([x, y, w, it[1], it[2] if it.size() > 2 else "", it[3] if it.size() > 3 else 0,
			it[4] if it.size() > 4 else 0])
		x += w

func _make_layout() -> void:
	var fr := 0.0
	_row(fr, [[1.0, KEY_ESCAPE, "esc", 1], 1.0,
		[1.0, KEY_F1, "F1", 3], [1.0, KEY_F2, "F2", 3], [1.0, KEY_F3, "F3", 3], [1.0, KEY_F4, "F4", 3], 0.5,
		[1.0, KEY_F5, "F5", 2], [1.0, KEY_F6, "F6", 2], [1.0, KEY_F7, "F7", 2], [1.0, KEY_F8, "F8", 2], 0.5,
		[1.0, KEY_F9, "F9", 3], [1.0, KEY_F10, "F10", 3], [1.0, KEY_F11, "F11", 3], [1.0, KEY_F12, "F12", 3], 0.25,
		[1.0, KEY_PRINT, "prt", 2], [1.0, KEY_SCROLLLOCK, "scr", 2], [1.0, KEY_PAUSE, "pause", 2]])
	var r1 := 1.35
	var num := [[1.0, KEY_QUOTELEFT]]
	for k in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]:
		num.append([1.0, k])
	num += [[2.0, KEY_BACKSPACE, "BKSP", 1], 0.25, [1.0, KEY_INSERT, "ins", 2], [1.0, KEY_HOME, "home", 2], [1.0, KEY_PAGEUP, "pg up", 2]]
	_row(r1, num)
	var top := [[1.5, KEY_TAB, "tab", 2]]
	for k in [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		top.append([1.0, k])
	top += [0.25, [11.25, KEY_ENTER, "enter", 2], 0.25, [1.0, KEY_DELETE, "del", 2], [1.0, KEY_END, "end", 2], [1.0, KEY_PAGEDOWN, "pg dn", 2]]
	_row(r1 + 1.0, top)
	var home := [[1.75, KEY_CAPSLOCK, "caps", 3]]
	for k in [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE, KEY_BACKSLASH]:
		home.append([1.0, k])
	_row(r1 + 2.0, home)
	var bottom := [[1.25, KEY_SHIFT, "shift", 3, 1], [1.0, KEY_SECTION]]
	for k in [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M, KEY_COMMA, KEY_PERIOD, KEY_SLASH]:
		bottom.append([1.0, k])
	bottom += [[2.75, KEY_SHIFT, "shift", 3, 2], 1.25, [1.0, KEY_UP, "UP", 2]]
	_row(r1 + 3.0, bottom)
	_row(r1 + 4.0, [[1.25, KEY_CTRL, "ctrl", 1, 1], [1.25, KEY_META, "STAR", 1, 1], [1.25, KEY_ALT, "alt", 1, 1],
		[6.25, KEY_SPACE, "", 3], [1.25, KEY_ALT, "alt gr", 1, 2], [1.25, KEY_META, "STAR", 1, 2],
		[1.25, KEY_MENU, "menu", 1], [1.25, KEY_CTRL, "ctrl", 1, 2], 0.25,
		[1.0, KEY_LEFT, "LEFT", 2], [1.0, KEY_DOWN, "DOWN", 2], [1.0, KEY_RIGHT, "RIGHT", 2]])

func _label_for(phys: int, fixed: String) -> int:
	if fixed != "":
		return LABELS.find(fixed)
	if phys == KEY_SPACE:
		return -1
	var code := phys
	if DisplayServer.get_name() != "headless":
		var l := DisplayServer.keyboard_get_label_from_physical(phys)
		if l != KEY_NONE:
			code = l
	if code > 0 and code < 0x400000:
		var s := String.chr(code).to_upper()
		var i := LABELS.find(s)
		if i >= 0:
			return i
	# fall back to the US legend
	var us := {KEY_QUOTELEFT: "`", KEY_MINUS: "-", KEY_EQUAL: "=", KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]",
		KEY_SEMICOLON: ";", KEY_APOSTROPHE: "'", KEY_BACKSLASH: "#", KEY_COMMA: ",", KEY_PERIOD: ".",
		KEY_SLASH: "/", KEY_SECTION: "<"}
	if us.has(phys):
		return LABELS.find(us[phys])
	if phys > 0 and phys < 0x400000:
		return LABELS.find(String.chr(phys).to_upper())
	return -1

func build(base_mesh: Mesh, keycap_mesh: Mesh) -> void:
	_make_layout()
	var aabb := base_mesh.get_aabb()
	size = aabb.size
	base_top = aabb.end.y
	key_y = base_top - 0.02
	# the case
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	var bm := ShaderMaterial.new()
	bm.shader = FABRIC
	bm.set_shader_parameter("albedo", Color(0.25, 0.2, 0.33))
	bm.set_shader_parameter("fibre_tex", T_FELT)
	bm.set_shader_parameter("mottle_tex", T_MOTTLE)
	bm.set_shader_parameter("fibre_scale", 2.2)
	bm.set_shader_parameter("sheen", 0.9)
	bm.set_shader_parameter("sheen_color", Color(0.8, 0.72, 0.95))
	bm.set_shader_parameter("stitches", 0.0)
	bm.set_shader_parameter("seam_shadow", 0.0)
	base.material_override = bm
	add_child(base)
	# piping around the top edge
	var pipe := MeshInstance3D.new()
	pipe.mesh = Geo.tube(Geo.rounded_rect(0, 0, size.x - 0.05, size.z - 0.05, 0.34, base_top - 0.13, 6), 0.055, 10, true)
	pipe.material_override = _fabric(Color(0.93, 0.68, 0.32), T_KNIT, 7.0, 0.8)
	add_child(pipe)

	# keys: the key area sits right of a margin that holds the USB port
	var total_w := 18.25 * PITCH
	var total_d := 6.35 * PITCH
	var x0 := size.x * 0.5 - 0.42 - total_w
	var z0 := -total_d * 0.5
	key_rect = Rect2(x0, z0, total_w, total_d)
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = keycap_mesh
	mm.instance_count = layout.size()
	for i in layout.size():
		var L: Array = layout[i]
		var w: float = fmod(L[2], 10.0)
		var dz: float = floor(float(L[2]) / 10.0)
		var cx: float = x0 + (float(L[0]) + w * 0.5) * PITCH
		var cz: float = z0 + (float(L[1]) + 0.5 + dz * 0.5) * PITCH
		var k := {"phys": L[3], "loc": L[6], "pos": Vector3(cx, key_y, cz), "w": w * PITCH, "d": (1.0 + dz) * PITCH,
			"press": 0.0, "vel": 0.0, "target": 0.0, "real": false, "feet": false, "glow": 0.0,
			"glow_t": 0.0, "custom": Color(L[2], float(_label_for(L[3], L[4])), 0.0, float(L[5]))}
		keys.append(k)
		mm.set_instance_custom_data(i, k.custom)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mat = ShaderMaterial.new()
	mat.shader = KEYCAP
	mat.set_shader_parameter("albedo", Color(0.86, 0.8, 0.7))
	mat.set_shader_parameter("col1", Color(0.86, 0.47, 0.4))
	mat.set_shader_parameter("col2", Color(0.38, 0.6, 0.62))
	mat.set_shader_parameter("col3", Color(0.92, 0.7, 0.36))
	mat.set_shader_parameter("thread_color", Color(0.3, 0.22, 0.34))
	mat.set_shader_parameter("thread1", Color(0.99, 0.95, 0.87))
	mat.set_shader_parameter("fibre_tex", T_FELT)
	mat.set_shader_parameter("mottle_tex", T_MOTTLE)
	mat.set_shader_parameter("labels_tex", T_LABELS)
	mat.set_shader_parameter("fibre_scale", 2.6)
	mat.set_shader_parameter("fibre_strength", 1.5)
	mat.set_shader_parameter("mottle_amount", 0.18)
	mat.set_shader_parameter("pitch", PITCH)
	mat.set_shader_parameter("sheen_color", Color(1, 0.95, 0.9))
	mmi.material_override = mat
	add_child(mmi)
	_update_keys(0.0)

	# collision: the case, and the key tops (slightly below, keys squash under Claude)
	var body := StaticBody3D.new()
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x - 0.1, base_top - 0.04, size.z - 0.1)
	cs.shape = bs
	cs.position = Vector3(0, (base_top - 0.04) * 0.5, 0)
	body.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	var key_top := key_y + 0.29 - 0.075
	bs2.size = Vector3(total_w - 0.05, key_top - base_top + 0.05, total_d - 0.05)
	cs2.shape = bs2
	cs2.position = Vector3(x0 + total_w * 0.5, (key_top + base_top - 0.05) * 0.5, 0)
	body.add_child(cs2)

	# USB port in the left margin, opening upwards
	port_pos = Vector3(x0 - 0.95, base_top + 0.02, z0 + 0.75)
	_build_port()
	# fairy lights: a few warm lights that come on with the keys
	for i in 3:
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.7, 0.4)
		ol.omni_range = 4.5
		ol.light_energy = 0.0
		ol.position = Vector3(x0 + total_w * (0.2 + 0.3 * i), key_y + 0.9, 0.4)
		add_child(ol)
		glow_lights.append(ol)

func _fabric(col: Color, tex: Texture2D, sc: float, strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FABRIC
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("fibre_tex", tex)
	m.set_shader_parameter("mottle_tex", T_MOTTLE)
	m.set_shader_parameter("fibre_scale", sc)
	m.set_shader_parameter("fibre_strength", strength)
	m.set_shader_parameter("stitches", 0.0)
	m.set_shader_parameter("use_vertex_seam", 0.0)
	m.set_shader_parameter("sheen_color", col.lerp(Color.WHITE, 0.5))
	return m

var port_glow: ShaderMaterial

func _build_port() -> void:
	# a padded patch with a dark slot, ringed with piping
	var pad := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.05, 0.42)
	pad.mesh = bm
	pad.position = port_pos + Vector3(0, -0.02, 0)
	pad.material_override = _fabric(Color(0.2, 0.17, 0.27), T_FELT, 3.0, 1.0)
	add_child(pad)
	var slot := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.18, 0.012, 0.085)
	slot.mesh = sm
	slot.position = port_pos + Vector3(0, 0.006, 0)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.02, 0.04)
	dark.roughness = 1.0
	dark.emission_enabled = true
	dark.emission = Color(1.0, 0.65, 0.3)
	dark.emission_energy_multiplier = 0.0
	slot.material_override = dark
	add_child(slot)
	port_mat = dark
	var ring := MeshInstance3D.new()
	ring.mesh = Geo.tube(Geo.rounded_rect(port_pos.x, port_pos.z, 0.3, 0.19, 0.07, port_pos.y + 0.012, 4), 0.026, 8, true)
	ring.material_override = _fabric(Color(0.93, 0.68, 0.32), T_KNIT, 9.0, 0.8)
	add_child(ring)
	var ring2 := MeshInstance3D.new()
	ring2.mesh = Geo.tube(Geo.rounded_rect(port_pos.x, port_pos.z, 0.62, 0.42, 0.1, port_pos.y - 0.005, 4), 0.03, 8, true)
	ring2.material_override = ring.material_override
	add_child(ring2)

var port_mat: StandardMaterial3D

## real input: physical keycode + location (left/right for modifiers)
func set_real(phys: int, loc: int, down: bool) -> bool:
	var hit := false
	for k in keys:
		if k.phys == phys and (k.loc == 0 or loc == 0 or k.loc == loc):
			k.real = down
			hit = true
	return hit

## Claude's feet (local xz) push down the keys they stand on
func set_feet(points: Array, on_keys: bool) -> void:
	for k in keys:
		k.feet = false
	if not on_keys:
		return
	for p in points:
		var lp: Vector3 = p
		for k in keys:
			var kp: Vector3 = k.pos
			if absf(lp.x - kp.x) < k.w * 0.5 + 0.02 and absf(lp.z - kp.z) < k.d * 0.5 + 0.02:
				if not k.feet and k.press < 0.3:
					Sound.sfx("res://levels/plush_desk/audio/squish.ogg", -14.0, 1.0, 0.25)
				k.feet = true

func key_index_at(lp: Vector3) -> int:
	for i in keys.size():
		var kp: Vector3 = keys[i].pos
		if absf(lp.x - kp.x) < keys[i].w * 0.5 and absf(lp.z - kp.z) < keys[i].d * 0.5:
			return i
	return -1

## the fairy lights chase across the keys, starting at the port
func light_wave() -> void:
	_wave_order = range(keys.size())
	var o := port_pos
	_wave_order.sort_custom(func(a, b): return (keys[a].pos as Vector3).distance_to(o) < (keys[b].pos as Vector3).distance_to(o))
	_wave_t = 0.0
	_blip_i = 0

func lights_off() -> void:
	_wave_t = -1.0
	lit = 0.0
	for k in keys:
		k.glow_t = 0.0

func _process(delta: float) -> void:
	_t += delta
	if _wave_t >= 0.0:
		_wave_t += delta
		var n := int(_wave_t / 0.022)
		for j in mini(n, _wave_order.size()):
			keys[_wave_order[j]].glow_t = 1.0
		while _blip_i < mini(n, _wave_order.size()):
			if _blip_i % 6 == 0:
				var notes := [0, 4, 7, 12, 16, 19, 24, 28, 31, 36, 40, 43, 48, 52, 55]
				var st: int = notes[mini(_blip_i / 6, notes.size() - 1)]
				Sound.sfx("res://levels/plush_desk/audio/twinkle.ogg", -10.0, pow(2.0, (st - 12) / 12.0))
			_blip_i += 1
		lit = clampf(_wave_t / (0.022 * keys.size()), 0.0, 1.0)
		if n >= _wave_order.size():
			_wave_t = -1.0
			lit = 1.0
	_update_keys(delta)
	for i in glow_lights.size():
		(glow_lights[i] as OmniLight3D).light_energy = lit * (0.9 + 0.1 * sin(_t * 3.0 + i))
	if port_mat:
		port_mat.emission_energy_multiplier = lit * 1.5

func _update_keys(delta: float) -> void:
	if mm == null:
		return
	for i in keys.size():
		var k: Dictionary = keys[i]
		var target := 1.0 if (k.real or k.feet) else 0.0
		# a stuffed cushion: fast down, springy up with a little overshoot
		if delta > 0.0:
			var stiff := 900.0 if target > k.press else 380.0
			var damp := 34.0 if target > k.press else 13.0
			k.vel += ((target - k.press) * stiff - k.vel * damp) * delta
			k.press = clampf(k.press + k.vel * delta, -0.25, 1.15)
			var gt: float = k.glow_t * (0.55 + 0.45 * target) if lit > 0.0 else 0.0
			gt += target * 0.35 * lit
			k.glow = lerpf(k.glow, gt, 1.0 - exp(-14.0 * delta))
		var p: float = k.press
		var sq := 1.0 - p * 0.3
		var bulge := 1.0 + maxf(p, 0.0) * 0.07
		var b := Basis.from_scale(Vector3(bulge, sq, bulge))
		var pos: Vector3 = k.pos
		mm.set_instance_transform(i, Transform3D(b, pos + Vector3(0, -p * 0.02, 0)))
		var c: Color = k.custom
		c.b = k.glow
		mm.set_instance_custom_data(i, c)
