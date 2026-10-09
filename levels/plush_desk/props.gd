## The rest of the desk: plush mouse on a corduroy pad (mirrors the real
## mouse), its braided yarn cable, the felt desk lamp and the star quilt.
extends Node3D

const FABRIC := preload("res://levels/plush_desk/shaders/fabric.gdshader")
const MOUSE := preload("res://levels/plush_desk/shaders/mouse.gdshader")
const BACKDROP := preload("res://levels/plush_desk/shaders/backdrop.gdshader")
const Geo := preload("res://levels/plush_desk/geo.gd")
const T_FELT := preload("res://levels/plush_desk/textures/felt.png")
const T_KNIT := preload("res://levels/plush_desk/textures/knit.png")
const T_CORD := preload("res://levels/plush_desk/textures/cord.png")
const T_WEAVE := preload("res://levels/plush_desk/textures/weave.png")
const T_MOTTLE := preload("res://levels/plush_desk/textures/mottle.png")

var mouse: Node3D
var mouse_mat: ShaderMaterial
var wheel: MeshInstance3D
var pad_center := Vector3()
var pad_half := Vector2(1.5, 1.2)
var mouse_off := Vector2.ZERO      # offset on the pad (metres)
var mouse_vel := Vector2.ZERO
var _btn := [0.0, 0.0]
var _btn_t := [0.0, 0.0]
var _wheel_v := 0.0
var cable: MeshInstance3D
var cable_end := Vector3()
var lamp_light: SpotLight3D
var lamp_bulb: StandardMaterial3D
var _cable_t := 0.0

static func fabric(col: Color, tex: Texture2D, sc := 2.0, strength := 1.0, sheen := 0.9) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FABRIC
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("fibre_tex", tex)
	m.set_shader_parameter("mottle_tex", T_MOTTLE)
	m.set_shader_parameter("fibre_scale", sc)
	m.set_shader_parameter("fibre_strength", strength)
	m.set_shader_parameter("sheen", sheen)
	m.set_shader_parameter("sheen_color", col.lerp(Color.WHITE, 0.55))
	m.set_shader_parameter("stitches", 0.0)
	m.set_shader_parameter("use_vertex_seam", 0.0)
	return m

func build_mouse(mouse_mesh: Mesh, pad_mesh: Mesh, at: Vector3, kb_back: Vector3) -> void:
	pad_center = at
	var pad := MeshInstance3D.new()
	pad.mesh = pad_mesh
	pad.position = at
	var pm := fabric(Color(0.36, 0.52, 0.5), T_CORD, 1.6, 1.4, 1.1)
	pm.set_shader_parameter("sheen_roughness", 0.35)
	pad.material_override = pm
	add_child(pad)
	var pa := pad_mesh.get_aabb()
	var top := at.y + pa.end.y
	var pipe := MeshInstance3D.new()
	pipe.mesh = Geo.tube(Geo.rounded_rect(at.x, at.z, pa.size.x - 0.04, pa.size.z - 0.04, 0.3, top - 0.05, 6), 0.045, 8, true)
	pipe.material_override = fabric(Color(0.95, 0.85, 0.66), T_KNIT, 8.0, 0.8)
	add_child(pipe)
	pad_half = Vector2(pa.size.x * 0.5 - 1.05, pa.size.z * 0.5 - 1.65)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(pa.size.x, top - at.y, pa.size.z)
	cs.shape = bs
	cs.position = at + Vector3(0, (top - at.y) * 0.5, 0)
	body.add_child(cs)
	add_child(body)

	mouse = Node3D.new()
	mouse.position = Vector3(at.x, top - 0.01, at.z)
	add_child(mouse)
	var mi := MeshInstance3D.new()
	mi.mesh = mouse_mesh
	mouse_mat = ShaderMaterial.new()
	mouse_mat.shader = MOUSE
	mouse_mat.set_shader_parameter("albedo", Color(0.42, 0.45, 0.72))
	mouse_mat.set_shader_parameter("btn_col", Color(0.93, 0.86, 0.74))
	mouse_mat.set_shader_parameter("fibre_tex", T_FELT)
	mouse_mat.set_shader_parameter("mottle_tex", T_MOTTLE)
	mouse_mat.set_shader_parameter("fibre_scale", 4.0)
	mouse_mat.set_shader_parameter("fibre_strength", 0.6)
	mouse_mat.set_shader_parameter("sheen", 1.6)
	mouse_mat.set_shader_parameter("sheen_roughness", 0.3)
	mouse_mat.set_shader_parameter("sheen_color", Color(0.8, 0.85, 1.0))
	mi.material_override = mouse_mat
	mouse.add_child(mi)
	var ma := mouse_mesh.get_aabb()
	# corduroy scroll wheel between the buttons
	wheel = MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.17; wm.bottom_radius = 0.17; wm.height = 0.13; wm.radial_segments = 24
	wheel.mesh = wm
	wheel.rotation = Vector3(0, 0, PI * 0.5)
	wheel.position = Vector3(0, ma.end.y - 0.22, ma.position.z * 0.48)
	var wmat := fabric(Color(0.92, 0.62, 0.32), T_CORD, 5.0, 1.4)
	wheel.material_override = wmat
	mouse.add_child(wheel)
	var mcol := StaticBody3D.new()
	var mcs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = ma.size.x * 0.42
	cap.height = ma.size.z * 0.9
	mcs.shape = cap
	mcs.rotation = Vector3(PI * 0.5, 0, 0)
	mcs.position = Vector3(0, ma.size.y * 0.36, 0)
	mcs.scale = Vector3(1, 1, 0.75)
	mcol.add_child(mcs)
	mouse.add_child(mcol)
	# braided yarn cable from the nose of the mouse to the back of the keyboard
	cable_end = kb_back
	cable = MeshInstance3D.new()
	cable.material_override = fabric(Color(0.95, 0.85, 0.66), T_KNIT, 10.0, 1.0)
	add_child(cable)
	_update_cable()

func _update_cable() -> void:
	var nose := mouse.global_position + Vector3(0, 0.25, -1.4)
	var pts := PackedVector3Array()
	var a := nose
	var b := cable_end
	var mid := Vector3((a.x + b.x) * 0.5 + 0.8, 0.12, minf(a.z, b.z) - 1.6)
	for i in 25:
		var t := i / 24.0
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		p.y = maxf(0.09, p.y) + sin(t * PI) * 0.04
		pts.append(p)
	cable.mesh = Geo.tube(pts, 0.06, 8)

func mouse_move(rel: Vector2) -> void:
	mouse_vel += rel * 0.004

func mouse_button(i: int, down: bool) -> void:
	if i < 2:
		_btn_t[i] = 1.0 if down else 0.0

func mouse_wheel(dir: float) -> void:
	_wheel_v += dir * 9.0

func _process(delta: float) -> void:
	if mouse == null:
		return
	# glide with the real mouse, then ease back to the middle of the pad
	mouse_off += mouse_vel
	mouse_vel = Vector2.ZERO
	mouse_off = mouse_off.lerp(Vector2.ZERO, 1.0 - exp(-1.6 * delta))
	mouse_off = mouse_off.clamp(-pad_half, pad_half)
	var target := pad_center + Vector3(mouse_off.x, 0, mouse_off.y)
	var cur := mouse.position
	var np := Vector3(lerpf(cur.x, target.x, 1.0 - exp(-18.0 * delta)), cur.y, lerpf(cur.z, target.z, 1.0 - exp(-18.0 * delta)))
	var v := (np - cur) / maxf(delta, 0.001)
	mouse.position = np
	mouse.rotation.z = lerpf(mouse.rotation.z, clampf(-v.x * 0.02, -0.12, 0.12), 1.0 - exp(-8.0 * delta))
	mouse.rotation.x = lerpf(mouse.rotation.x, clampf(v.z * 0.015, -0.1, 0.1), 1.0 - exp(-8.0 * delta))
	for i in 2:
		var tgt: float = _btn_t[i]
		_btn[i] = lerpf(_btn[i], tgt, 1.0 - exp(-(30.0 if tgt > _btn[i] else 12.0) * delta))
	mouse_mat.set_shader_parameter("btn_l", _btn[0])
	mouse_mat.set_shader_parameter("btn_r", _btn[1])
	wheel.rotate_object_local(Vector3.UP, _wheel_v * delta)
	_wheel_v = lerpf(_wheel_v, 0.0, 1.0 - exp(-5.0 * delta))
	_cable_t += delta
	if v.length() > 0.05 or _cable_t > 0.5:
		_cable_t = 0.0
		_update_cable()

func set_glow(g: float) -> void:
	if mouse_mat:
		mouse_mat.set_shader_parameter("glow", g)

## felt desk lamp: weighted base, knitted arm, felt shade with the key light
func build_lamp(base_pos: Vector3, target: Vector3) -> SpotLight3D:
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.1; cm.bottom_radius = 1.3; cm.height = 0.45; cm.radial_segments = 32
	base.mesh = cm
	base.position = base_pos + Vector3(0, 0.22, 0)
	base.material_override = fabric(Color(0.86, 0.47, 0.4), T_FELT, 2.0, 1.2)
	add_child(base)
	var joint1 := base_pos + Vector3(0, 0.45, 0)
	var elbow := base_pos + Vector3(0.6, 5.6, 0.4)
	var head := base_pos + Vector3(3.2, 8.4, 2.6)
	var arm := MeshInstance3D.new()
	var pts := PackedVector3Array()
	for i in 13:
		var t := i / 12.0
		pts.append(joint1.lerp(elbow, t) + Vector3(sin(t * PI) * 0.25, 0, 0))
	for i in range(1, 13):
		var t := i / 12.0
		pts.append(elbow.lerp(head, t) + Vector3(0, sin(t * PI) * 0.35, 0))
	arm.mesh = Geo.tube(pts, 0.17, 10)
	arm.material_override = fabric(Color(0.93, 0.68, 0.32), T_KNIT, 4.0, 1.0)
	add_child(arm)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.32; sm.height = 0.64
	knob.mesh = sm
	knob.position = elbow
	knob.material_override = fabric(Color(0.86, 0.47, 0.4), T_FELT, 3.0, 1.2)
	add_child(knob)
	# shade: a felt cone pointing at the target
	var shade := Node3D.new()
	add_child(shade)
	shade.look_at_from_position(head, target, Vector3.UP)
	var cone := MeshInstance3D.new()
	var co := CylinderMesh.new()
	# the wide, open mouth faces the desk (-Z after the rotation), the narrow end the arm
	co.top_radius = 1.5; co.bottom_radius = 0.45; co.height = 1.9; co.radial_segments = 32
	co.cap_top = false
	cone.mesh = co
	cone.rotation = Vector3(-PI * 0.5, 0, 0)
	cone.position = Vector3(0, 0, -0.75)
	var shm := fabric(Color(0.38, 0.6, 0.62), T_FELT, 2.0, 1.2)
	shm.set_shader_parameter("translucency", 0.5)
	cone.material_override = shm
	shade.add_child(cone)
	var inner := MeshInstance3D.new()
	var co2 := co.duplicate() as CylinderMesh
	co2.flip_faces = true
	inner.mesh = co2
	inner.rotation = cone.rotation
	inner.position = cone.position
	var inm := fabric(Color(1.0, 0.9, 0.75), T_FELT, 2.0, 1.0)
	inm.set_shader_parameter("emission_color", Color(1.0, 0.75, 0.45))
	inm.set_shader_parameter("emission_energy", 0.6)
	inner.material_override = inm
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.add_child(inner)
	var bulb := MeshInstance3D.new()
	var bs := SphereMesh.new(); bs.radius = 0.42; bs.height = 0.84
	bulb.mesh = bs
	bulb.position = Vector3(0, 0, -1.2)
	lamp_bulb = StandardMaterial3D.new()
	lamp_bulb.albedo_color = Color(1.0, 0.92, 0.75)
	lamp_bulb.emission_enabled = true
	lamp_bulb.emission = Color(1.0, 0.82, 0.55)
	lamp_bulb.emission_energy_multiplier = 6.0
	bulb.material_override = lamp_bulb
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.add_child(bulb)
	lamp_light = SpotLight3D.new()
	lamp_light.position = Vector3(0, 0, -1.55)
	lamp_light.light_color = Color(1.0, 0.77, 0.52)
	lamp_light.light_energy = 14.0
	lamp_light.spot_range = 34.0
	lamp_light.spot_angle = 47.0
	lamp_light.spot_angle_attenuation = 0.8
	lamp_light.spot_attenuation = 0.4
	lamp_light.shadow_enabled = true
	lamp_light.shadow_blur = 1.5
	lamp_light.shadow_bias = 0.04
	shade.add_child(lamp_light)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new(); cy.radius = 1.25; cy.height = 0.45
	cs.shape = cy
	cs.position = base.position
	col.add_child(cs)
	add_child(col)
	return lamp_light

func build_backdrop(z: float, w: float, h: float) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	q.mesh = qm
	q.position = Vector3(0, h * 0.5 - 0.3, z)
	var m := ShaderMaterial.new()
	m.shader = BACKDROP
	m.set_shader_parameter("albedo", Color(0.11, 0.12, 0.3))
	m.set_shader_parameter("fibre_tex", T_WEAVE)
	m.set_shader_parameter("mottle_tex", T_MOTTLE)
	m.set_shader_parameter("fibre_scale", 1.5)
	m.set_shader_parameter("fibre_strength", 0.9)
	m.set_shader_parameter("sheen", 0.6)
	m.set_shader_parameter("sheen_color", Color(0.5, 0.55, 0.9))
	m.set_shader_parameter("moon_pos", Vector2(11.5, 13.5 - (h * 0.5 - 0.3)))
	q.material_override = m
	add_child(q)
	# the same night quilt on both sides, so no camera ever looks past it
	for side in [-1.0, 1.0]:
		var sq := MeshInstance3D.new()
		var sm := QuadMesh.new()
		sm.size = Vector2(44.0, h)
		sq.mesh = sm
		sq.position = Vector3(side * 26.0, h * 0.5 - 0.3, z + 22.0)
		sq.rotation = Vector3(0.0, -side * PI * 0.5, 0.0)
		var m2 := m.duplicate() as ShaderMaterial
		m2.set_shader_parameter("moon_pos", Vector2(-400.0, 0.0))
		sq.material_override = m2
		add_child(sq)

## sewing things that ended up on the desk: a ball of yarn with a loose end,
## a tomato pin cushion and a few big buttons
func build_sewing(planet_mesh: Mesh) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# ball of yarn: a knitted core wrapped in loops of yarn
	var yc := Vector3(-13.2, 1.35, 3.0)
	var R := 1.35
	var yarn_col := Color(0.86, 0.47, 0.42)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = R - 0.05; sm.height = (R - 0.05) * 2.0
	core.mesh = sm
	core.position = yc
	core.material_override = fabric(yarn_col.darkened(0.25), T_KNIT, 3.0, 1.0)
	add_child(core)
	var ym := fabric(yarn_col, T_KNIT, 16.0, 1.0)
	ym.set_shader_parameter("sheen", 1.1)
	var st := SurfaceTool.new()
	var all := ArrayMesh.new()
	for i in 46:
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := axis.cross(u)
		var pts := PackedVector3Array()
		var rr := R + rng.randf_range(-0.03, 0.04)
		for k in 40:
			var a := TAU * k / 40.0
			pts.append(yc + (u * cos(a) + v * sin(a)) * rr)
		var m := Geo.tube(pts, 0.05, 6, true)
		st.append_from(m, 0, Transform3D())
	all = st.commit()
	var wraps := MeshInstance3D.new()
	wraps.mesh = all
	wraps.material_override = ym
	add_child(wraps)
	# the loose end trails across the quilt
	var trail := PackedVector3Array()
	var start := yc + Vector3(0.9, -1.0, 0.6)
	for k in 30:
		var t := k / 29.0
		trail.append(start + Vector3(t * 2.6 + sin(t * 6.0) * 0.6, 0, t * 7.0) + Vector3(0, 0.07 if t > 0.05 else 0.25, 0))
	var tr := MeshInstance3D.new()
	tr.mesh = Geo.tube(trail, 0.05, 6)
	tr.material_override = ym
	add_child(tr)
	var yb := StaticBody3D.new()
	var ys := CollisionShape3D.new()
	var ysh := SphereShape3D.new(); ysh.radius = R
	ys.shape = ysh
	ys.position = yc
	yb.add_child(ys)
	add_child(yb)

	# tomato pin cushion with a felt leaf crown and a few pins
	var tc := Vector3(14.4, 0.95, -5.0)
	var tom := MeshInstance3D.new()
	tom.mesh = planet_mesh
	tom.scale = Vector3(1.35, 0.95, 1.35)
	tom.position = tc
	var tm := ShaderMaterial.new()
	tm.shader = FABRIC
	tm.set_shader_parameter("albedo", Color(0.82, 0.22, 0.2))
	tm.set_shader_parameter("fibre_tex", T_FELT)
	tm.set_shader_parameter("mottle_tex", T_MOTTLE)
	tm.set_shader_parameter("fibre_scale", 1.5)
	tm.set_shader_parameter("sheen_color", Color(1.0, 0.6, 0.55))
	tm.set_shader_parameter("thread_color", Color(0.95, 0.85, 0.6))
	tm.set_shader_parameter("stitch_count", 14.0)
	tm.set_shader_parameter("stitch_inset", 0.04)
	tm.set_shader_parameter("stitch_width", 0.007)
	tom.material_override = tm
	add_child(tom)
	var leaf := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.55; lm.bottom_radius = 0.6; lm.height = 0.08; lm.radial_segments = 10
	leaf.mesh = lm
	leaf.position = tc + Vector3(0, 0.95, 0)
	leaf.material_override = fabric(Color(0.35, 0.6, 0.3), T_FELT, 4.0, 1.2)
	add_child(leaf)
	var stem := MeshInstance3D.new()
	var stm := CylinderMesh.new()
	stm.top_radius = 0.09; stm.bottom_radius = 0.12; stm.height = 0.35
	stem.mesh = stm
	stem.position = tc + Vector3(0, 1.12, 0)
	stem.material_override = leaf.material_override
	add_child(stem)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.8, 0.82, 0.86); steel.metallic = 1.0; steel.roughness = 0.25
	var heads := [Color(0.95, 0.8, 0.3), Color(0.4, 0.6, 0.95), Color(0.95, 0.95, 0.9), Color(0.6, 0.85, 0.5), Color(0.9, 0.5, 0.8)]
	for i in 5:
		var d := Vector3(cos(i * 1.4) * 0.8, 0.75, sin(i * 1.4) * 0.8).normalized()
		var pin := Node3D.new()
		pin.transform = Transform3D(Basis(Quaternion(Vector3.UP, d)), tc + d * Vector3(1.2, 0.85, 1.2))
		add_child(pin)
		var shaft := MeshInstance3D.new()
		var sh := CylinderMesh.new(); sh.top_radius = 0.025; sh.bottom_radius = 0.025; sh.height = 0.8
		shaft.mesh = sh
		shaft.material_override = steel
		shaft.position = Vector3(0, 0.15, 0)
		pin.add_child(shaft)
		var head := MeshInstance3D.new()
		var hm := SphereMesh.new(); hm.radius = 0.11; hm.height = 0.22
		head.mesh = hm
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = heads[i]
		hmat.roughness = 0.2
		head.material_override = hmat
		head.position = Vector3(0, 0.58, 0)
		pin.add_child(head)
	var tb := StaticBody3D.new()
	var tcs := CollisionShape3D.new()
	var tsh := SphereShape3D.new(); tsh.radius = 1.3
	tcs.shape = tsh
	tcs.position = tc
	tb.add_child(tcs)
	add_child(tb)

	# big sewing buttons lying on the quilt
	var spots := [[Vector3(-4.2, 0.0, 6.6), 0.75, Color(0.95, 0.75, 0.3)], [Vector3(3.8, 0.0, 5.4), 0.55, Color(0.45, 0.62, 0.9)],
		[Vector3(6.8, 0.0, 7.8), 0.9, Color(0.92, 0.5, 0.55)], [Vector3(-10.5, 0.0, 8.0), 0.6, Color(0.6, 0.82, 0.62)],
		[Vector3(12.8, 0.0, 6.0), 0.7, Color(0.95, 0.92, 0.85)]]
	for s in spots:
		add_child(_button(s[0], s[1], s[2], rng.randf() * TAU))

func _button(pos: Vector3, r: float, col: Color, rot: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = Vector3(0.0, rot, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.28
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.97; cm.bottom_radius = r; cm.height = r * 0.22; cm.radial_segments = 40
	body.mesh = cm
	body.position.y = r * 0.11
	body.material_override = mat
	n.add_child(body)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.78; tm.outer_radius = r * 0.98; tm.rings = 40; tm.ring_segments = 10
	rim.mesh = tm
	rim.scale = Vector3(1, 0.6, 1)
	rim.position.y = r * 0.22
	rim.material_override = mat
	n.add_child(rim)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = col.darkened(0.6)
	for i in 4:
		var h := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = r * 0.09; hm.bottom_radius = r * 0.09; hm.height = 0.02; hm.radial_segments = 12
		h.mesh = hm
		h.position = Vector3(cos(i * PI * 0.5 + 0.785) * r * 0.24, r * 0.225, sin(i * PI * 0.5 + 0.785) * r * 0.24)
		h.material_override = dark
		n.add_child(h)
	var body2 := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new(); cy.radius = r; cy.height = r * 0.25
	cs.shape = cy
	cs.position.y = r * 0.12
	body2.add_child(cs)
	n.add_child(body2)
	return n
