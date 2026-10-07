## Small story props: colour orbs, rocket ribbons, the butterfly,
## ambient petals, the special flower and the channel beacon.
class_name StoryProps
extends RefCounted

static var _glow_shader: Shader
static func glow_mat(col: Color, energy := 2.0, billboard := true) -> ShaderMaterial:
	if _glow_shader == null: _glow_shader = load("res://shaders/glow.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _glow_shader
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("billboard", billboard)
	return m

static func make_orb(col: Color, radius := 1.6) -> Node3D:
	var o := Node3D.new()
	o.name = "ColorOrb"
	o.set_meta("color", col)
	o.set_meta("radius", radius)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.28; sm.height = 0.56
	core.mesh = sm
	var om := ShaderMaterial.new(); om.shader = load("res://shaders/orb.gdshader")
	om.set_shader_parameter("base", col)
	core.material_override = om
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.add_child(core)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(2.2, 2.2)
	halo.mesh = q
	halo.material_override = glow_mat(col, 1.4)
	o.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = col; light.light_energy = 1.2; light.omni_range = 4.0
	o.add_child(light)
	# sparkles
	var ps := GPUParticles3D.new()
	ps.amount = 16; ps.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 0.5
	pm.gravity = Vector3(0, 0.4, 0); pm.initial_velocity_min = 0.1; pm.initial_velocity_max = 0.4
	pm.scale_min = 0.08; pm.scale_max = 0.18
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0)); g.set_color(1, Color(1, 1, 1, 0)); g.add_point(0.3, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new(); gt.gradient = g; pm.color_ramp = gt
	ps.process_material = pm
	var pq := QuadMesh.new(); pq.size = Vector2(1, 1); pq.material = glow_mat(col.lerp(Color.WHITE, 0.5), 3.0)
	ps.draw_pass_1 = pq
	o.add_child(ps)
	return o

static func burst(parent: Node3D, pos: Vector3, col: Color) -> void:
	var ps := GPUParticles3D.new()
	ps.one_shot = true; ps.amount = 60; ps.lifetime = 1.4; ps.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.initial_velocity_min = 2.0; pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -1.5, 0); pm.damping_min = 2.0; pm.damping_max = 3.0
	pm.scale_min = 0.12; pm.scale_max = 0.3
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new(); gt.gradient = g; pm.color_ramp = gt
	ps.process_material = pm
	var pq := QuadMesh.new(); pq.size = Vector2(1, 1); pq.material = glow_mat(col.lerp(Color.WHITE, 0.3), 4.0)
	ps.draw_pass_1 = pq
	parent.add_child(ps)
	ps.global_position = pos
	ps.emitting = true
	parent.get_tree().create_timer(2.0).timeout.connect(ps.queue_free)

static func ambient_petals() -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.name = "Petals"
	ps.amount = 160; ps.lifetime = 12.0; ps.preprocess = 12.0
	ps.local_coords = false
	ps.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	var pm := ParticleProcessMaterial.new()
	# a ring around the camera, so no petal ever drifts right in front of the lens
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = 28.0
	pm.emission_ring_inner_radius = 5.0
	pm.emission_ring_height = 14.0
	pm.direction = Vector3(1, -0.2, 0.4); pm.spread = 30.0
	pm.initial_velocity_min = 0.4; pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0.2, -0.25, 0.1)
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 1.5; pm.turbulence_noise_scale = 4.0
	pm.angular_velocity_min = -90; pm.angular_velocity_max = 90
	pm.scale_min = 0.7; pm.scale_max = 1.3
	pm.particle_flag_rotate_y = true
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0)); g.set_color(1, Color(1, 1, 1, 0)); g.add_point(0.1, Color(1, 1, 1, 1)); g.add_point(0.85, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new(); gt.gradient = g; pm.color_ramp = gt
	ps.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.17, 0.12)   # billboard particles ignore the scale params here, so the quad sets the size
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.72, 0.84)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.albedo_texture = _petal_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.backlight_enabled = true; m.backlight = Color(0.6, 0.4, 0.45)
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	# petals right at the lens dissolve instead of covering the view
	m.distance_fade_min_distance = 1.2
	m.distance_fade_max_distance = 4.0
	q.material = m
	ps.draw_pass_1 = q
	return ps

static func _petal_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var u := (x - 15.5) / 15.5
			var v := (y - 15.5) / 15.5
			var d := u * u + (v * 1.25) * (v * 1.25) + 0.25 * maxf(0.0, -v) * absf(u) * 4.0
			var a := 1.0 if d < 0.85 else 0.0
			var shade := 1.0 - 0.15 * d
			img.set_pixel(x, y, Color(shade, shade * 0.97, shade, a))
	return ImageTexture.create_from_image(img)

static func special_flower(flower_mat: Material) -> Node3D:
	var f := Node3D.new()
	f.name = "DreamFlower"
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.018; cm.bottom_radius = 0.028; cm.height = 0.7
	stem.mesh = cm; stem.position.y = 0.35
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.35, 0.75, 0.25); sm.roughness = 0.6
	stem.material_override = sm
	f.add_child(stem)
	# blossom: several crossed flower cards
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true; mm.use_custom_data = true
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = 5
	for i in 5:
		var b := Basis(Vector3.UP, PI * i / 5.0).rotated(Vector3.RIGHT, 0.25 if i % 2 == 0 else -0.2).scaled(Vector3(0.55, 0.55, 1.0))
		mm.set_instance_transform(i, Transform3D(b, Vector3(0, 0.62, 0)))
		mm.set_instance_color(i, Color(1.0, 0.45, 0.85))
		mm.set_instance_custom_data(i, Color(0.3, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = flower_mat
	f.add_child(mmi)
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new(); hq.size = Vector2(1.4, 1.4)
	halo.mesh = hq; halo.position.y = 0.75
	halo.material_override = glow_mat(Color(1.0, 0.55, 0.85), 0.7)
	f.add_child(halo)
	var ps := GPUParticles3D.new()
	ps.amount = 14; ps.lifetime = 2.0; ps.position.y = 0.75
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 0.35
	pm.gravity = Vector3(0, 0.3, 0); pm.scale_min = 0.04; pm.scale_max = 0.09
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0)); g.set_color(1, Color(1, 1, 1, 0)); g.add_point(0.4, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new(); gt.gradient = g; pm.color_ramp = gt
	ps.process_material = pm
	var pq := QuadMesh.new(); pq.size = Vector2(1, 1); pq.material = glow_mat(Color(1.0, 0.85, 0.95), 3.0)
	ps.draw_pass_1 = pq
	f.add_child(ps)
	return f

static func beacon() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Beacon"
	var cm := CylinderMesh.new(); cm.top_radius = 1.2; cm.bottom_radius = 1.6; cm.height = 16.0; cm.cap_top = false; cm.cap_bottom = false
	mi.mesh = cm
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/beam.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A ribbon that trails behind a moving point (rocket streaks).
class RibbonTrail extends MeshInstance3D:
	var pts: Array[Vector3] = []
	var max_pts := 42
	var width := 0.16
	var col_a := Color(1.0, 0.75, 0.3)
	var col_b := Color(1.0, 0.35, 0.55)
	var im := ImmediateMesh.new()
	var emitting := true

	func _ready() -> void:
		mesh = im
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new(); m.shader = load("res://shaders/trail.gdshader")
		material_override = m
		extra_cull_margin = 16384.0

	func push(p: Vector3) -> void:
		if emitting: pts.push_front(p)
		while pts.size() > max_pts: pts.pop_back()

	func _process(_d: float) -> void:
		# once it stops emitting the tail catches up with the head
		if not emitting and pts.size() > 0: pts.pop_back()
		im.clear_surfaces()
		if pts.size() < 2: return
		var cam := get_viewport().get_camera_3d()
		if cam == null: return
		var cp := cam.global_position
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := pts.size()
		for i in n:
			var p := pts[i]
			var d := (pts[maxi(i - 1, 0)] - pts[mini(i + 1, n - 1)])
			if d.length() < 0.0001: d = Vector3.FORWARD
			var side := d.cross(cp - p).normalized()
			var t := float(i) / float(n - 1)
			var w := width * (1.0 - t * 0.6) * (0.4 + 0.6 * minf(1.0, i * 0.5))
			var c := col_a.lerp(col_b, t)
			c.a = (1.0 - t) * (1.0 - t)
			im.surface_set_color(c); im.surface_set_uv(Vector2(t, 0.0)); im.surface_add_vertex(p - side * w)
			im.surface_set_color(c); im.surface_set_uv(Vector2(t, 1.0)); im.surface_add_vertex(p + side * w)
		im.surface_end()


## The blue butterfly from the film; flutters to a target and lands on it.
class Butterfly extends Node3D:
	var target: Node3D
	var land_offset := Vector3(0, 0.07, 0)
	var _t := 0.0
	var _wl: Node3D
	var _wr: Node3D
	var _vel := Vector3.ZERO
	var landed := false

	func _ready() -> void:
		var m := ShaderMaterial.new(); m.shader = load("res://shaders/wing.gdshader")
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			add_child(pivot)
			var w := MeshInstance3D.new()
			var q := QuadMesh.new(); q.size = Vector2(0.11, 0.11)
			w.mesh = q
			w.material_override = m
			w.rotation.x = -PI * 0.5
			w.position = Vector3(side * 0.055, 0, 0)
			w.scale = Vector3(side, 1, 1)
			pivot.add_child(w)
			if side < 0: _wl = pivot
			else: _wr = pivot
		var body := MeshInstance3D.new()
		var cm := CapsuleMesh.new(); cm.radius = 0.008; cm.height = 0.07
		body.mesh = cm; body.rotation.x = PI * 0.5
		var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.1, 0.08, 0.15)
		body.material_override = bm
		add_child(body)

	func _process(delta: float) -> void:
		_t += delta
		var flap_speed := 4.0 if landed else 22.0
		var flap := sin(_t * flap_speed) * (0.35 if landed else 1.0) + (0.6 if landed else 0.2)
		_wl.rotation.z = flap
		_wr.rotation.z = -flap
		if target == null: return
		var goal := target.global_position + target.global_basis * land_offset
		if landed:
			global_position = goal
			global_basis = target.global_basis
			return
		var flutter := Vector3(sin(_t * 3.1), sin(_t * 4.3) * 0.7, cos(_t * 2.7)) * 0.6
		var to := goal - global_position
		if to.length() < 0.06:
			landed = true
			return
		_vel = _vel.lerp(to.normalized() * clampf(to.length() * 1.5, 0.3, 2.5) + flutter * clampf(to.length(), 0.0, 1.0), 1.0 - exp(-4.0 * delta))
		global_position += _vel * delta
		if _vel.length() > 0.05:
			look_at(global_position + Vector3(_vel.x, 0, _vel.z).normalized() + Vector3(0, 0.001, 0), Vector3.UP)
