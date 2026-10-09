## The planet mobile hanging over the desk: a felt-wrapped ring on yarn,
## stuffed planets on strings, a felt name tag under each. It is the world
## select: spin it, zoom to the planet in front, dive in.
extends Node3D

const FABRIC := preload("res://levels/plush_desk/shaders/fabric.gdshader")
const Finale := preload("res://levels/plush_desk/story/sec_finale.gd")
const Geo := preload("res://levels/plush_desk/geo.gd")
const T_FELT := preload("res://levels/plush_desk/textures/felt.png")
const T_KNIT := preload("res://levels/plush_desk/textures/knit.png")
const T_MOTTLE := preload("res://levels/plush_desk/textures/mottle.png")
const FONT := preload("res://levels/plush_desk/fonts/Fredoka-Bold.woff2")
const FUZZ := preload("res://levels/plush_desk/shaders/fuzz.gdshader")
const FUZZ_SHELLS := 4

const RING_Y := 11.0
const RING_R := 5.2

var angle := 0.0
var spin := 0.0           # rad/s
var drive := 0.0          # slow self-rotation once Claude is plugged in
var planets: Array = []
var ring: Node3D
var _t := 0.0
var _prev_spin := 0.0
var _strings: Array = []

func _fabric(col: Color, tex: Texture2D, sc := 2.0, strength := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FABRIC
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("fibre_tex", tex)
	m.set_shader_parameter("mottle_tex", T_MOTTLE)
	m.set_shader_parameter("fibre_scale", sc)
	m.set_shader_parameter("fibre_strength", strength)
	m.set_shader_parameter("sheen_color", col.lerp(Color.WHITE, 0.55))
	m.set_shader_parameter("stitches", 0.0)
	m.set_shader_parameter("use_vertex_seam", 0.0)
	return m

func build(planet_mesh: Mesh, tag_mesh: Mesh) -> void:
	ring = Node3D.new()
	ring.position.y = RING_Y
	add_child(ring)
	var torus := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RING_R - 0.13
	tm.outer_radius = RING_R + 0.13
	tm.rings = 96
	tm.ring_segments = 14
	torus.mesh = tm
	torus.material_override = _fabric(Color(0.93, 0.68, 0.32), T_KNIT, 5.0, 1.0)
	ring.add_child(torus)
	# hanger strings up to a knot, and one string up into the dark
	var yarn := _fabric(Color(0.95, 0.88, 0.72), T_KNIT, 14.0, 0.8)
	var knot := Vector3(0, RING_Y + 3.6, 0)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var p := Vector3(cos(a) * RING_R, RING_Y, sin(a) * RING_R)
		var s := MeshInstance3D.new()
		s.mesh = Geo.tube(PackedVector3Array([p - ring.position, knot - ring.position]), 0.022, 6)
		s.material_override = yarn
		ring.add_child(s)
	var up := MeshInstance3D.new()
	up.mesh = Geo.tube(PackedVector3Array([knot, knot + Vector3(0, 12, 0)]), 0.03, 6)
	up.material_override = yarn
	add_child(up)
	var kb := MeshInstance3D.new()
	var ks := SphereMesh.new(); ks.radius = 0.12; ks.height = 0.24
	kb.mesh = ks
	kb.material_override = yarn
	kb.position = knot
	add_child(kb)

	_add_planet(planet_mesh, tag_mesh, "STORY", "story", 1.7, 0.0, 4.4,
		[Color(0.86, 0.42, 0.36), Color(0.95, 0.86, 0.72), Color(0.93, 0.66, 0.34)], Color(0.99, 0.94, 0.84))
	_add_planet(planet_mesh, tag_mesh, "COMMUNITY", "community", 1.5, TAU * 0.25, 3.4,
		[Color(0.28, 0.56, 0.6), Color(0.2, 0.4, 0.5), Color(0.55, 0.75, 0.68)], Color(0.98, 0.9, 0.7))
	_add_planet(planet_mesh, tag_mesh, "RUSTY", "rusty", 1.35, TAU * 0.5, 4.9,
		[Color(0.5, 0.36, 0.62), Color(0.24, 0.2, 0.42), Color(0.72, 0.5, 0.7)], Color(1.0, 0.8, 0.4))
	_add_planet(planet_mesh, tag_mesh, "YOUR MOON", "moon", 0.85, TAU * 0.75, 5.8,
		[Color(0.8, 0.8, 0.84), Color(0.7, 0.71, 0.76), Color(0.86, 0.85, 0.88)], Color(0.45, 0.42, 0.6))
	_update(0.0)

func _add_planet(mesh: Mesh, tag_mesh: Mesh, title: String, id: String, r: float, a: float, drop: float, cols: Array, thread: Color) -> void:
	var pivot := Node3D.new()        # where the string meets the ring; swings
	ring.add_child(pivot)
	pivot.position = Vector3(cos(a) * RING_R, 0, sin(a) * RING_R)
	var strand := MeshInstance3D.new()
	strand.mesh = Geo.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, -drop + r, 0)]), 0.02, 6)
	strand.material_override = _fabric(Color(0.95, 0.88, 0.72), T_KNIT, 14.0, 0.8)
	pivot.add_child(strand)
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.scale = Vector3.ONE * r
	body.position = Vector3(0, -drop, 0)
	var m := ShaderMaterial.new()
	m.shader = FABRIC
	m.set_shader_parameter("albedo", cols[0])
	m.set_shader_parameter("panel_b", cols[1])
	m.set_shader_parameter("panel_c", cols[2])
	m.set_shader_parameter("use_panels", 1.0)
	m.set_shader_parameter("fibre_tex", T_FELT)
	m.set_shader_parameter("mottle_tex", T_MOTTLE)
	m.set_shader_parameter("fibre_scale", 1.6 / r)
	m.set_shader_parameter("fibre_strength", 1.1)
	m.set_shader_parameter("sheen_color", (cols[0] as Color).lerp(Color.WHITE, 0.6))
	m.set_shader_parameter("stitch_count", 16.0)
	m.set_shader_parameter("stitch_inset", 0.035)
	m.set_shader_parameter("stitch_width", 0.009)
	m.set_shader_parameter("thread_color", thread)
	# a few shells of fuzz on top (plush halo at the silhouette)
	var prev: Material = m
	for i in FUZZ_SHELLS:
		var f := ShaderMaterial.new()
		f.shader = FUZZ
		for key in ["albedo", "panel_b", "panel_c", "use_panels", "fibre_tex", "sheen_color"]:
			f.set_shader_parameter(key, m.get_shader_parameter(key))
		f.set_shader_parameter("mottle_tex", T_MOTTLE)
		f.set_shader_parameter("shell", float(i + 1) / FUZZ_SHELLS)
		f.set_shader_parameter("fuzz_len", 0.035)
		f.set_shader_parameter("density", 5.0)
		prev.next_pass = f
		prev = f
	body.material_override = m
	body.rotation = Vector3(0.5, a * 1.7, 0.3)
	pivot.add_child(body)
	var extra := Node3D.new()
	body.add_child(extra)
	if id == "community":
		var rg := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.45; tm.outer_radius = 1.85; tm.rings = 64; tm.ring_segments = 10
		rg.mesh = tm
		rg.scale = Vector3(1, 0.25, 1)
		rg.material_override = _fabric(Color(0.95, 0.75, 0.4), T_KNIT, 7.0, 1.0)
		rg.rotation = Vector3(0.0, 0.0, 0.0)
		var holder := Node3D.new()
		holder.position = body.position
		holder.rotation = Vector3(0.35, 0, 0.25)
		pivot.add_child(holder)
		rg.scale *= r
		holder.add_child(rg)
	if id == "moon":
		# sewing buttons as craters
		var bm := CylinderMesh.new()
		bm.top_radius = 0.16; bm.bottom_radius = 0.17; bm.height = 0.07; bm.radial_segments = 20
		var btn_mat := StandardMaterial3D.new()
		btn_mat.albedo_color = Color(0.55, 0.52, 0.7)
		btn_mat.roughness = 0.35
		var dirs := [Vector3(0.3, 0.8, 0.5), Vector3(-0.7, 0.2, 0.6), Vector3(0.5, -0.4, 0.75), Vector3(-0.2, -0.8, -0.5), Vector3(0.8, 0.1, -0.5)]
		for d in dirs:
			var n: Vector3 = (d as Vector3).normalized()
			var b := MeshInstance3D.new()
			b.mesh = bm
			b.material_override = btn_mat
			b.transform = Transform3D(Basis(Quaternion(Vector3.UP, n)), n * 1.02)
			extra.add_child(b)
	# felt name tag on a short string
	var tag := Node3D.new()
	tag.position = Vector3(0, -drop - r - 0.9, 0)
	pivot.add_child(tag)
	var ts := MeshInstance3D.new()
	ts.mesh = Geo.tube(PackedVector3Array([Vector3(0, 0.9 + r * 0.05, 0), Vector3(0, 0.4, 0)]), 0.014, 5)
	ts.material_override = strand.material_override
	tag.add_child(ts)
	var pillow := MeshInstance3D.new()
	pillow.mesh = tag_mesh
	var tw := 0.5 + title.length() * 0.27
	pillow.scale = Vector3(tw / 0.48, 0.5, 0.9 / 0.48)
	pillow.rotation = Vector3(PI * 0.5, 0, 0)
	pillow.position = Vector3(0, 0, -0.05)
	var pm := _fabric(cols[0], T_FELT, 3.0, 1.2)
	pillow.material_override = pm
	tag.add_child(pillow)
	var lab := Label3D.new()
	lab.text = title
	lab.font = FONT
	lab.font_size = 72
	lab.pixel_size = 0.0068
	lab.modulate = thread
	lab.outline_size = 0
	lab.shaded = true
	lab.double_sided = false
	lab.position = Vector3(0, 0, 0.1)
	tag.add_child(lab)
	planets.append({"id": id, "title": title, "pivot": pivot, "body": body, "tag": tag, "r": r,
		"drop": drop, "base_a": a, "swing": Vector2.ZERO, "swing_v": Vector2.ZERO, "phase": randf() * TAU})

## the best result of a world, sewn under its name tag: the score and the badge
func set_result(id: String, score: int, medal: String) -> void:
	for p in planets:
		if p.id != id:
			continue
		var tag: Node3D = p.tag
		var old := tag.get_node_or_null("Result")
		if old:
			old.free()
		var res := Node3D.new()
		res.name = "Result"
		res.position = Vector3(0, -0.62, 0.02)
		tag.add_child(res)
		var lab := Label3D.new()
		lab.text = "%d / 100" % score
		lab.font = FONT
		lab.font_size = 64
		lab.pixel_size = 0.0042
		lab.modulate = Color(0.3, 0.2, 0.32)
		lab.outline_size = 14
		lab.outline_modulate = Color(0.98, 0.94, 0.86)
		lab.shaded = true
		lab.position = Vector3(0.12, 0, 0.08)
		res.add_child(lab)
		if medal != "":
			var b: Node3D = Finale.badge_node(medal)
			b.position = Vector3(-0.42, 0, 0.06)
			b.scale = Vector3.ONE * 1.3
			res.add_child(b)

## world position of a planet's centre
func planet_pos(i: int) -> Vector3:
	return (planets[i].body as Node3D).global_position

## the planet closest to the camera (by angle around the mobile)
func front_index(cam_pos: Vector3) -> int:
	var c := global_position
	var to_cam := Vector2(cam_pos.x - c.x, cam_pos.z - c.z).normalized()
	var best := 0
	var best_d := -2.0
	for i in planets.size():
		var p := planet_pos(i)
		var d := Vector2(p.x - c.x, p.z - c.z).normalized().dot(to_cam)
		if d > best_d:
			best_d = d
			best = i
	return best

func _process(delta: float) -> void:
	_update(delta)

func _update(delta: float) -> void:
	_t += delta
	var accel := (spin - _prev_spin) / maxf(delta, 0.001) if delta > 0.0 else 0.0
	_prev_spin = spin
	angle += (spin + drive) * delta
	ring.rotation.y = angle
	ring.rotation.z = sin(_t * 0.4) * 0.015
	var cam: Camera3D = null
	if is_inside_tree():
		cam = get_viewport().get_camera_3d()
	for p in planets:
		var pv: Node3D = p.pivot
		# lean out when spinning, lag behind when it speeds up, idle sway
		var w := spin + drive
		var target := Vector2(clampf(w * w * 0.05, 0.0, 0.35), clampf(-accel * 0.02, -0.3, 0.3))
		target += Vector2(sin(_t * 0.7 + p.phase), cos(_t * 0.53 + p.phase)) * 0.02
		var sw: Vector2 = p.swing
		var sv: Vector2 = p.swing_v
		sv += ((target - sw) * 14.0 - sv * 2.2) * delta
		sw += sv * delta
		p.swing = sw
		p.swing_v = sv
		var out_dir := Vector3(cos(p.base_a), 0, sin(p.base_a))
		pv.basis = Basis(out_dir.cross(Vector3.UP).normalized(), -sw.x) * Basis(out_dir, sw.y)
		(p.body as Node3D).rotate_y(delta * 0.15)
		if cam:
			var tg: Node3D = p.tag
			var to := cam.global_position - tg.global_position
			tg.global_basis = Basis(Vector3.UP, atan2(to.x, to.z))
