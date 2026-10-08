## Stardust Islands – a dreamy space level: floating islands, candy
## platforms, launch stars, two little planets with their own gravity, star
## bits to collect and the Dream Star at the end.
extends DreamLevel

const B := preload("res://levels/stardust/builders.gd")
const SKY := preload("res://levels/stardust/shaders/galaxy_sky.gdshader")
const SPARKLE := preload("res://levels/stardust/shaders/sparkle.gdshader")
const FAR := preload("res://levels/stardust/shaders/far_planet.gdshader")
const RING := preload("res://levels/stardust/shaders/ring.gdshader")
const SPIRAL := preload("res://levels/stardust/shaders/spiral.gdshader")
const FONT := preload("res://levels/stardust/fonts/Fredoka-Bold.woff2")
const DIR := "res://levels/stardust/"
const TUFT := preload("res://levels/stardust/shaders/tuft.gdshader")
const FLOWER := preload("res://levels/stardust/shaders/flower.gdshader")
const CLOUD := preload("res://levels/stardust/shaders/cloud.gdshader")
const DUST := preload("res://levels/stardust/shaders/dust.gdshader")

const BIT_COLORS := [Color(1.0, 0.85, 0.25), Color(1.0, 0.45, 0.7), Color(0.4, 0.75, 1.0), Color(0.55, 1.0, 0.55), Color(0.8, 0.55, 1.0), Color(1.0, 0.6, 0.3)]

# --- layout (world space)
const START := Vector3(0, 0, 0)
const SPAWN := Vector3(0, 0.6, 8.5)
const PATH_LAND := Vector3(6, 14, -58)
const PLANET_A := Vector3(56, 38, -170)
const PLANET_A_R := 9.0
const PLANET_B := Vector3(78, 45, -180)
const PLANET_B_R := 4.6
const SUMMIT := Vector3(36, 58, -262)

var env: Environment
var sun: DirectionalLight3D
var cine: Camera3D
var bits: Array = []           # star bit nodes
var chips: Array = []
var launch_stars: Array = []   # {node, to, apex, dur, active, area}
var springs: Array = []        # {node, up}
var movers: Array = []         # {body, base, kind, amp, speed, phase}
var dream_star: Node3D
var lanterns: Array = []
var bit_count := 0
var chip_count := 0
var _combo := 0
var _combo_t := 0.0
var _t := 0.0
var _flying := false
var _area := 0
var _ui_bits: Label
var _ui_chips: Array = []
var _ui_chip_box: Control
var _ui_root: Control
var _void_fade: ColorRect
var _title: Control
var _prompt_star = null
var _checkpoint := SPAWN
var _won := false
var _falling_out := false      # respawn sequence running (once, not every frame)
var _fall_sound := false

func build() -> void:
	_build_environment()
	_build_backdrop()
	_build_start_island()
	_build_candy_path()
	_build_planets()
	_build_summit()
	_clouds()
	_build_ui()
	cine = Camera3D.new()
	cine.fov = 60.0
	cine.far = 8000.0
	add_child(cine)
	var c := spawn_claude(SPAWN, 0.0)
	c.step_kind = "grass"
	c.can_spin = true
	c.spin_sfx = DIR + "audio/spin.ogg"
	c.kill_y = -1e9           # this level handles falling itself
	c.walk_speed = 5.6
	c.run_speed = 8.2
	c.jump_velocity = 7.0
	c.can_double_jump = true
	c.double_jump_velocity = 7.4
	c.double_jump_sfx = DIR + "audio/jump2.ogg"
	c.can_triple_jump = true
	c.triple_jump_sfx = DIR + "audio/jump3.ogg"
	c.spun.connect(_on_spin)
	set_checkpoint(SPAWN)
	Sound.music(DIR + "audio/stardust_theme.ogg", 1.0)
	_show_title()

# ------------------------------------------------------------------ world
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.38, 0.72)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0); env.set_glow_level(1, 0.6); env.set_glow_level(2, 1.0); env.set_glow_level(3, 0.7); env.set_glow_level(4, 0.35); env.set_glow_level(5, 0.15)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.3
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.20, 0.12, 0.38)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.86)
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.65, 1.0)
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	add_child(fill)

func _build_backdrop() -> void:
	# a big ringed planet, a small blue moon and a spiral galaxy far away
	var far := Node3D.new()
	far.name = "Backdrop"
	add_child(far)
	_far_planet(far, Vector3(-0.62, 0.10, -0.78) * 2200.0, 380.0, Color(1.0, 0.62, 0.45), Color(0.72, 0.32, 0.58), Color(1.0, 0.78, 0.62), true)
	_far_planet(far, Vector3(0.78, 0.30, -0.55) * 2000.0, 110.0, Color(0.45, 0.80, 1.0), Color(0.25, 0.42, 0.85), Color(0.7, 0.9, 1.0), false)
	_far_planet(far, Vector3(0.30, -0.35, 0.89) * 2100.0, 160.0, Color(0.95, 0.85, 0.55), Color(0.75, 0.55, 0.40), Color(1.0, 0.9, 0.7), false)
	var gal := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(700, 700)
	gal.mesh = q
	var gm := ShaderMaterial.new(); gm.shader = SPIRAL
	gal.material_override = gm
	far.add_child(gal)
	gal.position = Vector3(0.1, 0.55, 0.83).normalized() * 2600.0
	gal.look_at_from_position(gal.position, Vector3.ZERO, Vector3.UP)
	gal.rotate_object_local(Vector3.FORWARD, 0.5)
	# twinkling sparkles all around
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	var sq := QuadMesh.new(); sq.size = Vector2(1, 1)
	var spm := ShaderMaterial.new(); spm.shader = SPARKLE
	spm.set_shader_parameter("energy", 4.0)
	sq.material = spm
	mm.mesh = sq
	mm.instance_count = 320
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	for i in mm.instance_count:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(8.0, 26.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), d * rng.randf_range(1200, 1800)))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), 0))
		mm.set_instance_color(i, Color(1, 1, 1))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 4000.0
	far.add_child(mmi)

func _far_planet(parent: Node3D, pos: Vector3, r: float, a: Color, b: Color, atmo: Color, ring: bool) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 64; sm.rings = 32
	mi.mesh = sm
	var m := ShaderMaterial.new(); m.shader = FAR
	m.set_shader_parameter("col_a", a); m.set_shader_parameter("col_b", b); m.set_shader_parameter("atmo", atmo)
	m.set_shader_parameter("light_dir", -sun.global_transform.basis.z if sun else Vector3(-0.6, 0.6, 0.4))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	mi.rotation = Vector3(0.3, 0.2, 0.25)
	if ring:
		var rm := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(r * 4.6, r * 4.6)
		rm.mesh = pm
		var rmat := ShaderMaterial.new(); rmat.shader = RING
		rm.material_override = rmat
		rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(rm)

func _island(pos: Vector3, r: float, depth: float, seed_v: int, mat: Material, dome := 0.6) -> Array:
	var res := B.island(r, depth, seed_v, dome)
	var mesh: ArrayMesh = res[0]
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	body.position = pos
	return [body, res[1]]

func _on_island(isl: Array, local_xz: Vector2) -> Vector3:
	var body: Node3D = isl[0]
	var h: float = isl[1].call(local_xz)
	return body.position + Vector3(local_xz.x, h, local_xz.y)

func _tree(pos: Vector3, up: Vector3, h := 2.2, r := 1.1, col := Color(0.36, 0.82, 0.30)) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_transform = Transform3D(_basis_up(up), pos)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.12; cm.bottom_radius = 0.2; cm.height = h
	trunk.mesh = cm
	trunk.material_override = B.candy_mat(Color(0.72, 0.45, 0.30), Color(0.85, 0.58, 0.38), 3.0)
	trunk.position.y = h * 0.5
	n.add_child(trunk)
	var top := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 1.85
	top.mesh = sm
	top.material_override = B.toon({"mode": 0, "spherical": true, "center": pos + up * (h + r * 0.6), "grass_level": -2.0,
		"grass_a": col, "grass_b": col.lightened(0.3), "rim_col": Color(0.8, 1.0, 0.7), "rim_strength": 0.35})
	top.position.y = h + r * 0.6
	n.add_child(top)

## grass tufts + flowers over a surface. sampler(rng) -> [position, up]
func _scatter(count: int, seed_v: int, sampler: Callable, grass_root := Color(0.20, 0.55, 0.22), grass_tip := Color(0.70, 0.95, 0.40)) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_v
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	tm.use_custom_data = true
	var tmesh := B.tuft(seed_v)
	var tmat := ShaderMaterial.new(); tmat.shader = TUFT
	tmat.set_shader_parameter("root_col", grass_root); tmat.set_shader_parameter("tip_col", grass_tip)
	tmesh.surface_set_material(0, tmat)
	tm.mesh = tmesh
	tm.instance_count = count
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_custom_data = true
	var fmesh := B.flower()
	var fmat := ShaderMaterial.new(); fmat.shader = FLOWER
	fmesh.surface_set_material(0, fmat)
	fm.mesh = fmesh
	var fcount := count / 5
	fm.instance_count = fcount
	var cols := [Color(1.0, 0.95, 0.45), Color(1.0, 0.55, 0.78), Color(1.0, 1.0, 1.0), Color(0.65, 0.78, 1.0), Color(1.0, 0.62, 0.38), Color(0.85, 0.6, 1.0)]
	for i in count:
		var pu: Array = sampler.call(rng)
		var b := _basis_up(pu[1]).rotated(pu[1], rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 0.95))
		tm.set_instance_transform(i, Transform3D(b, pu[0]))
		var k := rng.randf_range(0.85, 1.12)
		tm.set_instance_custom_data(i, Color(k, k * rng.randf_range(0.95, 1.05), k, 1))
	for i in fcount:
		var pu: Array = sampler.call(rng)
		var b := _basis_up(pu[1]).rotated(pu[1], rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 0.95))
		fm.set_instance_transform(i, Transform3D(b, pu[0]))
		fm.set_instance_custom_data(i, cols[rng.randi() % cols.size()])
	for mm in [tm, fm]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

func _island_sampler(isl: Array, max_r: float) -> Callable:
	return func(r: RandomNumberGenerator) -> Array:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * max_r
		return [_on_island(isl, Vector2(cos(a), sin(a)) * d), Vector3.UP]

func _planet_sampler(center: Vector3, radius: float, band := Vector3.ZERO, band_w := 0.0) -> Callable:
	return func(r: RandomNumberGenerator) -> Array:
		for tries in 20:
			var d := Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), r.randf_range(-1, 1)).normalized()
			if band_w > 0.0:
				var wav := d.dot(band.normalized()) + 0.12 * sin(d.x * 7.0 + d.z * 5.0)
				if absf(wav) < band_w + 0.03: continue
			return [center + d * radius, d]
		return [center + Vector3.UP * radius, Vector3.UP]

func _basis_up(up: Vector3) -> Basis:
	var u := up.normalized()
	var ref := Vector3.FORWARD if absf(u.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(u).normalized()
	var z := x.cross(u).normalized()
	return Basis(x, u, z)

func _sparkles(center: Vector3, extent: Vector3, amount := 60) -> void:
	var ps := GPUParticles3D.new()
	ps.amount = amount
	ps.lifetime = 5.0
	ps.preprocess = 5.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extent
	pm.gravity = Vector3(0, 0.15, 0)
	pm.initial_velocity_min = 0.05; pm.initial_velocity_max = 0.3
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.scale_min = 0.15; pm.scale_max = 0.4
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0)); g.set_color(1, Color(1, 1, 1, 0)); g.add_point(0.25, Color(1, 1, 1, 1)); g.add_point(0.7, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new(); gt.gradient = g; pm.color_ramp = gt
	ps.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	var m := ShaderMaterial.new(); m.shader = SPARKLE
	m.set_shader_parameter("energy", 3.0)
	m.set_shader_parameter("speed", 2.0)
	q.material = m
	ps.draw_pass_1 = q
	ps.visibility_aabb = AABB(-extent - Vector3.ONE * 5, extent * 2 + Vector3.ONE * 10)
	add_child(ps)
	ps.position = center

func _start_island() -> void:
	pass

func _build_start_island() -> void:
	var grass := B.grass_mat()
	var isl := _island(START, 13.0, 9.0, 3, grass, 0.7)
	# a few satellites around it
	_island(START + Vector3(-20, -4, 6), 4.0, 4.0, 11, grass, 0.3)
	_island(START + Vector3(17, -7, 12), 3.0, 3.5, 12, grass, 0.25)
	_island(START + Vector3(-9, 9, -30), 2.5, 3.0, 13, grass, 0.2)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for i in 7:
		var a := rng.randf() * TAU
		var d := rng.randf_range(5.0, 10.5)
		var p := Vector2(cos(a), sin(a)) * d
		if p.distance_to(Vector2(0, 8.5)) < 3.0 or p.distance_to(Vector2(0, -9.0)) < 3.5: continue
		var col: Color = [Color(0.36, 0.82, 0.30), Color(0.95, 0.55, 0.75), Color(0.55, 0.85, 0.95)][i % 3]
		_tree(_on_island(isl, p), Vector3.UP, rng.randf_range(1.6, 2.6), rng.randf_range(0.8, 1.3), col)
	_scatter(2600, 7, _island_sampler(isl, 12.6))
	# star bits: a ring around the spawn and a trail to the launch star
	for i in 12:
		var a := TAU * i / 12.0
		var p := Vector2(cos(a), sin(a)) * 4.0 + Vector2(0, 2.0)
		_bit(_on_island(isl, p) + Vector3(0, 0.9, 0))
	for i in 6:
		_bit(_on_island(isl, Vector2(0, -2.5 - i * 1.0)) + Vector3(0, 0.9, 0))
	# little stepping platforms with bits off the edge
	_platform(START + Vector3(15, 1.0, -4), 1.8, Color(1.0, 0.6, 0.78))
	_platform(START + Vector3(19, 2.6, -11), 1.6, Color(0.62, 0.92, 0.78), "bob")
	for i in 5: _bit(START + Vector3(15, 2.2, -4) + Vector3(0, 0, i * 0.0) + Vector3(cos(i * 1.25), 0, sin(i * 1.25)) * 0.9)
	_bit(START + Vector3(19, 4.0, -11))
	_sparkles(START + Vector3(0, 3, 0), Vector3(16, 5, 16), 70)
	# stepping stones from the spawn to the launch star
	var stone_mat := B.candy_mat(Color(0.93, 0.88, 0.98), Color(0.82, 0.78, 0.95), 6.0)
	for i in 11:
		var t := i / 10.0
		var p2 := Vector2(sin(t * PI * 1.5) * 1.6 + (0.45 if i % 2 == 0 else -0.45), lerpf(6.5, -7.0, t))
		var st := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.6; cm.height = 0.2; cm.radial_segments = 16
		st.mesh = cm
		st.material_override = stone_mat
		add_child(st)
		st.position = _on_island(isl, p2) + Vector3(0, 0.03, 0)
		st.rotation.y = randf() * TAU
	# glowing crystal clusters near the edge
	for c in [[Vector2(-10.5, 3), Color(0.7, 0.5, 1.0)], [Vector2(9.5, -5), Color(0.4, 0.85, 1.0)], [Vector2(-5, -10), Color(1.0, 0.5, 0.8)]]:
		_crystals(_on_island(isl, c[0]), Vector3.UP, c[1], 5)
	_launch_star(_on_island(isl, Vector2(0, -9.0)) + Vector3(0, 1.0, 0), PATH_LAND + Vector3(0, 0.6, 0), 26.0, 2.6, 1)

func _crystals(pos: Vector3, up: Vector3, col: Color, n: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(pos.x * 13.0 + pos.z * 7.0)
	var mat := B.crystal_mat(col, 1.4)
	for i in n:
		var g := MeshInstance3D.new()
		g.mesh = _gem_mesh()
		g.material_override = mat
		add_child(g)
		var b := _basis_up(up)
		var tilt := Basis(b.x, rng.randf_range(-0.5, 0.5)) * Basis(b.z, rng.randf_range(-0.5, 0.5))
		var s := rng.randf_range(1.6, 3.8)
		g.global_transform = Transform3D((tilt * b).scaled(Vector3(s * 0.8, s * 1.6, s * 0.8)), pos + b.x * rng.randf_range(-0.6, 0.6) + b.z * rng.randf_range(-0.6, 0.6) + up * 0.2 * s)
	var l := OmniLight3D.new()
	l.light_color = col; l.light_energy = 1.2; l.omni_range = 5.0
	add_child(l)
	l.global_position = pos + up * 1.0

func _clouds() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for i in 46:
		var t := rng.randf()
		var base := START.lerp(SUMMIT, t)
		var p := base + Vector3(rng.randf_range(-70, 70), rng.randf_range(-48, -22), rng.randf_range(-40, 40))
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new(); var sz := rng.randf_range(30, 70); q.size = Vector2(sz, sz * 0.6)
		mi.mesh = q
		var m := ShaderMaterial.new(); m.shader = CLOUD
		var hue := rng.randf()
		m.set_shader_parameter("col_top", Color(1.0, 0.72, 0.88).lerp(Color(0.75, 0.85, 1.0), hue))
		m.set_shader_parameter("col_bottom", Color(0.42, 0.25, 0.70).lerp(Color(0.25, 0.30, 0.65), hue))
		m.set_shader_parameter("opacity", rng.randf_range(0.35, 0.6))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.position = p

func _platform(pos: Vector3, r: float, col: Color, kind := "", amp := 1.0, speed := 1.0) -> Node3D:
	var body: Node3D
	if kind == "":
		body = StaticBody3D.new()
	else:
		var ab := AnimatableBody3D.new()
		ab.sync_to_physics = true
		body = ab
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r * 0.78; cm.height = 0.9; cm.radial_segments = 40
	base.mesh = cm
	base.material_override = B.candy_mat(col, col.lightened(0.45), 3.3)
	base.position.y = -0.45
	body.add_child(base)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = r + 0.06; tm.bottom_radius = r + 0.1; tm.height = 0.22; tm.radial_segments = 40
	top.mesh = tm
	top.material_override = B.toon({"mode": 3, "base_col": col.lightened(0.35), "stripe_col": Color(1.0, 0.98, 0.94), "disc_radius": r + 0.06, "rim_col": Color(1, 0.95, 1), "rim_strength": 0.3})
	top.position.y = -0.05
	body.add_child(top)
	# little bulbs around the rim
	for i in 10:
		var a := TAU * i / 10.0
		var bl := MeshInstance3D.new()
		var bs := SphereMesh.new(); bs.radius = 0.09; bs.height = 0.18
		bl.mesh = bs
		bl.material_override = B.crystal_mat(BIT_COLORS[i % BIT_COLORS.size()], 2.2)
		bl.position = Vector3(cos(a) * (r + 0.02), -0.28, sin(a) * (r + 0.02))
		body.add_child(bl)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new(); shape.radius = r + 0.05; shape.height = 1.0
	cs.shape = shape
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)
	body.position = pos
	if kind != "":
		movers.append({"body": body, "base": pos, "kind": kind, "amp": amp, "speed": speed, "phase": randf() * TAU})
	return body

func _build_candy_path() -> void:
	var cols := [Color(1.0, 0.55, 0.75), Color(0.55, 0.88, 0.80), Color(1.0, 0.82, 0.45), Color(0.72, 0.62, 1.0), Color(0.55, 0.78, 1.0)]
	var land := _platform(PATH_LAND, 4.2, Color(1.0, 0.6, 0.78))
	var pts := [
		[PATH_LAND + Vector3(7, 0.8, -7), 2.2, ""],
		[PATH_LAND + Vector3(13, 2.0, -13), 2.0, "bob"],
		[PATH_LAND + Vector3(19.5, 3.0, -19), 2.6, "spin"],
		[PATH_LAND + Vector3(26, 4.4, -24), 2.0, ""],
		[PATH_LAND + Vector3(31, 5.6, -31), 2.0, "slide"],
		[PATH_LAND + Vector3(37, 7.0, -38), 2.2, "bob"],
	]
	var prev := PATH_LAND
	for i in pts.size():
		var p: Vector3 = pts[i][0]
		_platform(p, pts[i][1], cols[i % cols.size()], pts[i][2], 1.0 if pts[i][2] != "slide" else 2.5, 1.0)
		# arc of star bits from the previous platform
		for k in range(1, 4):
			var t := k / 4.0
			_bit(prev.lerp(p, t) + Vector3(0, 1.6 + sin(t * PI) * 1.4, 0))
		prev = p
	var goal := PATH_LAND + Vector3(44, 8.0, -47)
	_platform(goal, 4.0, Color(0.72, 0.62, 1.0))
	for k in range(1, 4):
		var t := k / 4.0
		_bit(prev.lerp(goal, t) + Vector3(0, 1.6 + sin(t * PI) * 1.4, 0))
	for i in 8:
		var a := TAU * i / 8.0
		_bit(PATH_LAND + Vector3(cos(a) * 2.5, 1.0, sin(a) * 2.5))
	_sparkles(PATH_LAND + Vector3(22, 4, -24), Vector3(30, 8, 30), 90)
	# floating candy decorations around the path
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	for i in 14:
		var p := PATH_LAND + Vector3(rng.randf_range(-20, 60), rng.randf_range(-14, 18), rng.randf_range(-60, 10))
		if p.distance_to(PATH_LAND + Vector3(22, 4, -24)) < 14.0: continue
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new(); var rr := rng.randf_range(0.8, 2.4); sm.radius = rr; sm.height = rr * 2.0
		mi.mesh = sm
		mi.material_override = B.toon({"mode": 2, "spherical": true, "center": p, "base_col": cols[i % cols.size()], "stripe_col": Color(1, 0.97, 0.98), "rim_col": Color(1, 0.9, 1)})
		add_child(mi)
		mi.position = p
	_launch_star(goal + Vector3(0, 1.0, 0), PLANET_A + Vector3(0, PLANET_A_R + 0.4, 0), 30.0, 3.0, 2)
	_checkpoint_zone(PATH_LAND + Vector3(0, 0.6, 0), 1)

func _build_planets() -> void:
	# planet A: a grassy little world with trees
	var a := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = PLANET_A_R; sm.height = PLANET_A_R * 2.0; sm.radial_segments = 96; sm.rings = 48
	mi.mesh = sm
	mi.material_override = B.toon({"mode": 0, "spherical": true, "center": PLANET_A, "grass_level": -0.25,
		"grass_a": Color(0.24, 0.66, 0.30), "grass_b": Color(0.62, 0.92, 0.34), "earth_a": Color(0.86, 0.62, 0.40), "earth_b": Color(0.95, 0.76, 0.50), "stripe_scale": 3.0,
		"patchiness": 0.22, "band_normal": Vector3(0.3, 1.0, -0.2), "band_width": 0.06})
	a.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := SphereShape3D.new(); sh.radius = PLANET_A_R; cs.shape = sh
	a.add_child(cs)
	add_child(a)
	a.position = PLANET_A
	var ga := GravityField.new(); ga.radius = PLANET_A_R; ga.field_radius = PLANET_A_R + 9.0
	add_child(ga); ga.position = PLANET_A
	# planet B: a candy moon
	var b := StaticBody3D.new()
	var mb := MeshInstance3D.new()
	var sb := SphereMesh.new(); sb.radius = PLANET_B_R; sb.height = PLANET_B_R * 2.0; sb.radial_segments = 64; sb.rings = 32
	mb.mesh = sb
	mb.material_override = B.toon({"mode": 2, "spherical": true, "center": PLANET_B, "base_col": Color(1.0, 0.55, 0.72), "stripe_col": Color(1.0, 0.96, 0.97), "rim_col": Color(1.0, 0.85, 1.0)})
	b.add_child(mb)
	var cb := CollisionShape3D.new(); var shb := SphereShape3D.new(); shb.radius = PLANET_B_R; cb.shape = shb
	b.add_child(cb)
	add_child(b)
	b.position = PLANET_B
	var gb := GravityField.new(); gb.radius = PLANET_B_R; gb.field_radius = PLANET_B_R + 7.0
	add_child(gb); gb.position = PLANET_B
	# trees and flowers on A
	var rng := RandomNumberGenerator.new(); rng.seed = 33
	var to_b := (PLANET_B - PLANET_A).normalized()
	for i in 9:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		if d.dot(Vector3.UP) > 0.85 or d.dot(to_b) > 0.8: continue
		var col: Color = [Color(0.36, 0.82, 0.30), Color(0.95, 0.55, 0.75), Color(1.0, 0.8, 0.35)][i % 3]
		_tree(PLANET_A + d * PLANET_A_R, d, rng.randf_range(1.2, 2.0), rng.randf_range(0.7, 1.0), col)
	_scatter(2600, 9, _planet_sampler(PLANET_A, PLANET_A_R, Vector3(0.3, 1.0, -0.2), 0.06))
	# star chips: 3 on A, 2 on B
	var chip_dirs_a := [Vector3(0.6, 0.6, 0.5), Vector3(-0.8, -0.1, 0.6), Vector3(0.1, -0.95, -0.3)]
	for d in chip_dirs_a:
		var u := (d as Vector3).normalized()
		_chip(PLANET_A + u * (PLANET_A_R + 0.9), u)
	var chip_dirs_b := [Vector3(0.3, 0.7, -0.6), Vector3(0.5, -0.6, 0.6)]
	for d in chip_dirs_b:
		var u := (d as Vector3).normalized()
		_chip(PLANET_B + u * (PLANET_B_R + 0.9), u)
	# star bits ringing planet A's equator
	for i in 18:
		var ang := TAU * i / 18.0
		var u := Vector3(cos(ang), 0.15 * sin(ang * 3.0), sin(ang)).normalized()
		_bit(PLANET_A + u * (PLANET_A_R + 1.0))
	# springy flowers between the planets
	_spring(PLANET_A + to_b * PLANET_A_R, to_b)
	_spring(PLANET_B - to_b * PLANET_B_R, -to_b)
	_sparkles(PLANET_A.lerp(PLANET_B, 0.4), Vector3(20, 14, 20), 90)
	_checkpoint_zone(PLANET_A + Vector3(0, PLANET_A_R + 0.6, 0), 2)

func _build_summit() -> void:
	var grass := B.grass_mat(Color(0.16, 0.58, 0.42), Color(0.50, 0.88, 0.48), Color(0.52, 0.38, 0.62), Color(0.74, 0.55, 0.80))
	var isl := _island(SUMMIT, 15.0, 13.0, 41, grass, 2.2)
	_island(SUMMIT + Vector3(-22, -6, 4), 4.5, 5.0, 42, grass, 0.4)
	_island(SUMMIT + Vector3(20, -3, -8), 5.0, 6.0, 43, grass, 0.5)
	var rng := RandomNumberGenerator.new(); rng.seed = 61
	for i in 10:
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, 13.0)
		var p := Vector2(cos(a), sin(a)) * d
		if p.distance_to(Vector2(0, 10)) < 4.0: continue
		var col: Color = [Color(0.95, 0.55, 0.75), Color(0.55, 0.85, 0.95), Color(1.0, 0.8, 0.35)][i % 3]
		_tree(_on_island(isl, p), Vector3.UP, rng.randf_range(1.8, 3.0), rng.randf_range(0.9, 1.5), col)
	_scatter(4600, 17, _island_sampler(isl, 14.6), Color(0.14, 0.46, 0.36), Color(0.62, 0.95, 0.56))
	# candy stepping stones from the landing spot up to the shrine
	var stone_mat := B.candy_mat(Color(1.0, 0.90, 0.80), Color(0.98, 0.80, 0.70), 6.0)
	for i in 9:
		var t := i / 8.0
		var p2 := Vector2(sin(t * PI * 1.2) * 1.4 + (0.4 if i % 2 == 0 else -0.4), lerpf(9.5, 2.2, t))
		var st := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.6; cm.bottom_radius = 0.66; cm.height = 0.2; cm.radial_segments = 16
		st.mesh = cm
		st.material_override = stone_mat
		add_child(st)
		st.position = _on_island(isl, p2) + Vector3(0, 0.03, 0)
		st.rotation.y = rng.randf() * TAU
	# paper-lantern lights drifting around the summit
	var lantern_mesh := SphereMesh.new(); lantern_mesh.radius = 0.32; lantern_mesh.height = 0.5
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.15, 0.15)
		var d := rng.randf_range(9.0, 17.0)
		var lp := SUMMIT + Vector3(cos(a) * d, rng.randf_range(3.0, 9.0), sin(a) * d)
		var l := MeshInstance3D.new()
		l.mesh = lantern_mesh
		var lc: Color = [Color(1.0, 0.72, 0.38), Color(1.0, 0.55, 0.62), Color(1.0, 0.85, 0.5)][i % 3]
		l.material_override = B.star_mat(lc, lc.darkened(0.25), 0.9)
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var g := MeshInstance3D.new()
		var gq := QuadMesh.new(); gq.size = Vector2(1.6, 1.6)
		g.mesh = gq
		g.material_override = StoryProps.glow_mat(lc, 0.7)
		l.add_child(g)
		add_child(l)
		l.position = lp
		l.set_meta("base", lp)
		l.set_meta("ph", rng.randf() * TAU)
		lanterns.append(l)
	# a little shrine: striped pedestal, crystal pillars, a floating halo
	var top_pos := _on_island(isl, Vector2(0, -2))
	var ped := StaticBody3D.new()
	var pm := MeshInstance3D.new()
	var pc := CylinderMesh.new(); pc.top_radius = 3.0; pc.bottom_radius = 3.4; pc.height = 1.2; pc.radial_segments = 48
	pm.mesh = pc
	pm.material_override = B.candy_mat(Color(0.72, 0.62, 1.0), Color(0.95, 0.9, 1.0), 2.2)
	ped.add_child(pm)
	var ptop := MeshInstance3D.new()
	var ptc := CylinderMesh.new(); ptc.top_radius = 3.05; ptc.bottom_radius = 3.05; ptc.height = 0.12; ptc.radial_segments = 48
	ptop.mesh = ptc
	ptop.material_override = B.toon({"mode": 3, "base_col": Color(1.0, 0.86, 0.55), "stripe_col": Color(1.0, 0.98, 0.9), "disc_radius": 3.05, "rim_col": Color(1, 0.95, 0.8), "rim_strength": 0.3})
	ptop.position.y = 0.62
	ped.add_child(ptop)
	var pcs := CollisionShape3D.new(); var psh := CylinderShape3D.new(); psh.radius = 3.2; psh.height = 1.25; pcs.shape = psh
	ped.add_child(pcs)
	add_child(ped)
	ped.position = top_pos + Vector3(0, 0.35, 0)
	for i in 8:
		var a := TAU * i / 8.0
		var cp2 := Vector2(cos(a), sin(a)) * 6.2 + Vector2(0, -2)
		_crystals(_on_island(isl, cp2), Vector3.UP, BIT_COLORS[i % BIT_COLORS.size()], 2)
	var halo_ring := MeshInstance3D.new()
	var tr := TorusMesh.new(); tr.inner_radius = 4.6; tr.outer_radius = 4.85; tr.rings = 96; tr.ring_segments = 10
	halo_ring.mesh = tr
	halo_ring.material_override = B.crystal_mat(Color(1.0, 0.85, 0.55), 2.0)
	halo_ring.name = "Halo"
	add_child(halo_ring)
	halo_ring.position = top_pos + Vector3(0, 7.5, 0)
	# the Dream Star, hovering over the pedestal
	dream_star = Node3D.new()
	add_child(dream_star)
	dream_star.position = top_pos + Vector3(0, 3.0, 0)
	var star := MeshInstance3D.new()
	star.mesh = B.star(1.15, 0.58, 0.48)
	star.material_override = B.star_mat(Color(1.0, 0.86, 0.32), Color(1.0, 0.62, 0.18), 1.1)
	star.name = "Mesh"
	dream_star.add_child(star)
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new(); hq.size = Vector2(6, 6)
	halo.mesh = hq
	halo.material_override = StoryProps.glow_mat(Color(1.0, 0.8, 0.4), 0.9)
	dream_star.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.5); light.light_energy = 2.5; light.omni_range = 9.0
	dream_star.add_child(light)
	_sparkles(dream_star.position, Vector3(2.5, 2.5, 2.5), 40)
	_sparkles(SUMMIT + Vector3(0, 4, 0), Vector3(18, 6, 18), 90)
	# a ring of bits around the star
	for i in 10:
		var a := TAU * i / 10.0
		_bit(dream_star.position + Vector3(cos(a) * 3.5, -1.2, sin(a) * 3.5))
	_checkpoint_zone(SUMMIT + Vector3(0, 1.0, 10), 3)

# ------------------------------------------------------------------ collectables
func _bit(pos: Vector3) -> void:
	var n := MeshInstance3D.new()
	n.mesh = _gem_mesh()
	var c: Color = BIT_COLORS[bits.size() % BIT_COLORS.size()]
	n.material_override = B.crystal_mat(c, 1.7)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	n.position = pos
	n.set_meta("base", pos)
	n.set_meta("ph", randf() * TAU)
	n.set_meta("col", c)
	bits.append(n)

var _gem: ArrayMesh
func _gem_mesh() -> ArrayMesh:
	if _gem == null: _gem = B.gem(0.17, 0.22)
	return _gem

func _chip(pos: Vector3, up: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_transform = Transform3D(_basis_up(up), pos)
	var mi := MeshInstance3D.new()
	mi.mesh = B.star(0.42, 0.2, 0.14)
	mi.material_override = B.star_mat(Color(1.0, 0.9, 0.45), Color(1.0, 0.7, 0.2), 1.3)
	n.add_child(mi)
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new(); hq.size = Vector2(1.8, 1.8)
	halo.mesh = hq
	halo.material_override = StoryProps.glow_mat(Color(1.0, 0.85, 0.4), 1.4)
	n.add_child(halo)
	n.set_meta("up", up)
	n.set_meta("base", pos)
	chips.append(n)

func _launch_star(pos: Vector3, to: Vector3, apex: float, dur: float, area: int, active := true) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = B.star(1.0, 0.5, 0.3)
	mi.material_override = B.star_mat(Color(1.0, 0.72, 0.25), Color(1.0, 0.45, 0.15), 1.0)
	mi.name = "Mesh"
	n.add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 1.3; tm.outer_radius = 1.42; tm.rings = 48; tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = B.crystal_mat(Color(1.0, 0.85, 0.5), 2.5)
	ring.rotation.x = PI * 0.5
	ring.name = "Ring"
	n.add_child(ring)
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new(); hq.size = Vector2(4, 4)
	halo.mesh = hq
	halo.material_override = StoryProps.glow_mat(Color(1.0, 0.65, 0.3), 1.2)
	n.add_child(halo)
	n.visible = active
	launch_stars.append({"node": n, "to": to, "apex": apex, "dur": dur, "active": active, "area": area})
	return n

func _spring(pos: Vector3, up: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_transform = Transform3D(_basis_up(up), pos)
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.12; cm.bottom_radius = 0.16; cm.height = 0.6
	stem.mesh = cm
	stem.material_override = B.candy_mat(Color(0.4, 0.8, 0.4), Color(0.55, 0.95, 0.5), 4.0)
	stem.position.y = 0.3
	n.add_child(stem)
	var cap := MeshInstance3D.new()
	var cc := CylinderMesh.new(); cc.top_radius = 0.95; cc.bottom_radius = 0.75; cc.height = 0.3; cc.radial_segments = 32
	cap.mesh = cc
	cap.material_override = B.candy_mat(Color(1.0, 0.45, 0.7), Color(1.0, 0.85, 0.92), 6.0)
	cap.position.y = 0.72
	cap.name = "Cap"
	n.add_child(cap)
	for i in 6:
		var a := TAU * i / 6.0
		var p := MeshInstance3D.new()
		var ps := SphereMesh.new(); ps.radius = 0.32; ps.height = 0.3
		p.mesh = ps
		p.material_override = B.candy_mat(Color(1.0, 0.95, 0.5), Color(1.0, 1.0, 0.8), 1.0)
		p.position = Vector3(cos(a) * 0.95, 0.72, sin(a) * 0.95)
		n.add_child(p)
	springs.append({"node": n, "up": up, "cool": 0.0})

func _checkpoint_zone(pos: Vector3, area: int) -> void:
	var a := Area3D.new()
	var cs := CollisionShape3D.new(); var sh := SphereShape3D.new(); sh.radius = 3.0; cs.shape = sh
	a.add_child(cs)
	add_child(a)
	a.position = pos
	a.body_entered.connect(func(b: Node) -> void:
		if b == claude and _area < area:
			_area = area
			_checkpoint = pos
			set_checkpoint(pos))

# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui_root)
	_void_fade = ColorRect.new()
	_void_fade.color = Color(0.10, 0.05, 0.22, 0.0)
	_void_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_void_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_void_fade)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.2, 0.55)
	sb.set_corner_radius_all(40)
	sb.content_margin_left = 22; sb.content_margin_right = 30; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.border_color = Color(1, 1, 1, 0.25); sb.set_border_width_all(2)
	pill.add_theme_stylebox_override("panel", sb)
	# top right, so it never collides with the hints (top left)
	pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.offset_right = -40
	pill.offset_top = 36
	_ui_root.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	pill.add_child(row)
	var icon := _gem_icon(Color(1.0, 0.85, 0.3))
	row.add_child(icon)
	_ui_bits = Label.new()
	_ui_bits.add_theme_font_override("font", FONT)
	_ui_bits.add_theme_font_size_override("font_size", 46)
	_ui_bits.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_ui_bits.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.35))
	_ui_bits.add_theme_constant_override("outline_size", 10)
	_ui_bits.text = "0"
	row.add_child(_ui_bits)
	# star chip slots (shown on the planets)
	_ui_chip_box = HBoxContainer.new()
	_ui_chip_box.add_theme_constant_override("separation", 10)
	_ui_chip_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ui_chip_box.position = Vector2(-160, 40)
	_ui_chip_box.modulate.a = 0.0
	_ui_root.add_child(_ui_chip_box)
	for i in 5:
		var s := _star_icon()
		s.modulate = Color(0.3, 0.25, 0.5, 0.8)
		_ui_chip_box.add_child(s)
		_ui_chips.append(s)

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

func _star_icon() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(56, 56)
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		var r := 26.0 if i % 2 == 0 else 12.0
		pts.append(Vector2(28, 30) + Vector2(cos(a), sin(a)) * r)
	p.polygon = pts
	p.color = Color(1.0, 0.85, 0.3)
	holder.add_child(p)
	return holder

func _show_title() -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_title)
	var t := Label.new()
	t.text = info.title if info else "Stardust Islands"
	t.add_theme_font_override("font", FONT)
	t.add_theme_font_size_override("font_size", 110)
	t.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	t.add_theme_color_override("font_outline_color", Color(0.35, 0.12, 0.45))
	t.add_theme_constant_override("outline_size", 22)
	t.add_theme_color_override("font_shadow_color", Color(0.1, 0.0, 0.2, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 8)
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.grow_vertical = Control.GROW_DIRECTION_BOTH
	t.position.y -= 60
	_title.add_child(t)
	var s := Label.new()
	s.text = "Collect star bits · find the Dream Star"
	s.add_theme_font_override("font", FONT)
	s.add_theme_font_size_override("font_size", 38)
	s.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	s.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.3))
	s.add_theme_constant_override("outline_size", 10)
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.grow_horizontal = Control.GROW_DIRECTION_BOTH
	s.position.y += 50
	_title.add_child(s)
	_title.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(2.2)   # while the camera glides out of the painting
	tw.tween_property(_title, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.6)
	tw.tween_property(_title, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func(): hint("Space: jump · again in the air = double jump\nJump right after landing while running = triple jump · E: spin", 8.0))

# ------------------------------------------------------------------ update
func _process(delta: float) -> void:
	_t += delta
	_combo_t -= delta
	if _combo_t <= 0.0: _combo = 0
	if claude == null: return
	var cp := claude.global_position
	# star bits: spin, bob, get collected
	for n in bits:
		var b := n as MeshInstance3D
		if not b.visible: continue
		var base: Vector3 = b.get_meta("base")
		b.position = base + Vector3(0, sin(_t * 2.0 + float(b.get_meta("ph"))) * 0.12, 0)
		b.rotation.y = _t * 2.2 + float(b.get_meta("ph"))
		if b.position.distance_to(cp + claude.up() * 0.6) < 1.05 and not _flying:
			_collect_bit(b)
	# star chips
	for n in chips:
		var c := n as Node3D
		if not c.visible: continue
		var up: Vector3 = c.get_meta("up")
		c.global_position = (c.get_meta("base") as Vector3) + up * sin(_t * 2.4) * 0.15
		(c.get_child(0) as Node3D).rotation.y = _t * 2.0
		if c.global_position.distance_to(cp + claude.up() * 0.6) < 1.3:
			_collect_chip(c)
	# launch stars
	_prompt_star = null
	for ls in launch_stars:
		var n: Node3D = ls["node"]
		if not ls["active"]: continue
		(n.get_node("Mesh") as Node3D).rotation.z = _t * 1.6
		(n.get_node("Ring") as Node3D).rotation.y = _t * 0.8
		n.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.04)
		if not _flying and n.position.distance_to(cp) < 2.2:
			_prompt_star = ls
	hud.set_prompt("Space / E: lift off!" if _prompt_star != null else "")
	if _prompt_star != null and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact")):
		_launch(_prompt_star)
	# springs
	for s in springs:
		s["cool"] = float(s["cool"]) - delta
		var n: Node3D = s["node"]
		var cap := n.get_node("Cap") as Node3D
		cap.scale = cap.scale.lerp(Vector3.ONE, 1.0 - exp(-10.0 * delta))
		var top: Vector3 = n.global_position + (s["up"] as Vector3) * 0.9
		var d_top := top.distance_to(cp)
		# a spring re-arms once Claude has stepped off it on solid ground, so
		# landing on the other planet's spring doesn't ping-pong her back
		if not s.get("armed", true) and d_top > 1.8 and claude.is_on_floor() and claude.velocity.dot(claude.up()) < 1.0:
			s["armed"] = true
		if s.get("armed", true) and float(s["cool"]) <= 0.0 and d_top < 1.2 and not _flying:
			for o in springs: o["armed"] = false
			s["cool"] = 0.8
			cap.scale = Vector3(1.4, 0.5, 1.4)
			claude.velocity = (s["up"] as Vector3) * 17.0
			Sound.sfx(DIR + "audio/boing.ogg", -4.0, 1.0, 0.05)
	for n in lanterns:
		var l := n as Node3D
		var ph: float = l.get_meta("ph")
		l.position = (l.get_meta("base") as Vector3) + Vector3(sin(_t * 0.35 + ph) * 0.6, sin(_t * 0.8 + ph) * 0.45, cos(_t * 0.3 + ph) * 0.6)
	# dream star
	var halo_r := get_node_or_null("Halo") as Node3D
	if halo_r: halo_r.rotation = Vector3(0.42 + sin(_t * 0.4) * 0.1, _t * 0.3, cos(_t * 0.3) * 0.1)
	if dream_star and not _won:
		dream_star.get_node("Mesh").rotation.y = _t * 1.4
		dream_star.position.y += sin(_t * 2.0) * 0.004
		if dream_star.global_position.distance_to(cp + Vector3(0, 0.8, 0)) < 2.4:
			_win()
	# falling into space
	if not _flying and not _won and not _falling_out and claude.up().y > 0.9:
		if cp.y < _checkpoint.y - 7.0 and not claude.is_on_floor() and claude.velocity.y < -6.0 and not _fall_sound:
			_fall_sound = true
			Sound.sfx(DIR + "audio/fall.ogg", -9.0)
		if cp.y < _checkpoint.y - 22.0:
			_fall_respawn()
	if _fall_sound and claude.is_on_floor(): _fall_sound = false
	# chip HUD only on the planets
	var near_planet := cp.distance_to(PLANET_A) < 40.0 or cp.distance_to(PLANET_B) < 30.0
	_ui_chip_box.modulate.a = lerpf(_ui_chip_box.modulate.a, 1.0 if near_planet and chip_count < 5 else 0.0, 1.0 - exp(-4.0 * delta))

func _physics_process(delta: float) -> void:
	for m in movers:
		var body: AnimatableBody3D = m["body"]
		var base: Vector3 = m["base"]
		var ph: float = m["phase"]
		match m["kind"]:
			"bob": body.position = base + Vector3(0, sin(_t * m["speed"] * 1.3 + ph) * m["amp"], 0)
			"slide": body.position = base + Vector3(sin(_t * m["speed"] * 0.8 + ph) * m["amp"], 0, 0)
			"spin": body.rotation.y += delta * 0.9 * m["speed"]

func _collect_bit(b: MeshInstance3D) -> void:
	b.visible = false
	bit_count += 1
	# the jar of star bits in Rusty's room in the attic shows the best count
	var st: Dictionary = GameState.stats.get("stardust", {})
	if bit_count > int(st.get("bits", 0)):
		st["bits"] = bit_count
		GameState.stats["stardust"] = st
	_ui_bits.text = str(bit_count)
	var steps := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
	var p := pow(2.0, steps[mini(_combo, steps.size() - 1)] / 12.0)
	_combo += 1
	_combo_t = 0.7
	Sound.sfx(DIR + "audio/bit.ogg", -7.0, p)
	StoryProps.burst(self, b.global_position, b.get_meta("col"))
	var tw := create_tween()
	_ui_bits.pivot_offset = _ui_bits.size * 0.5
	tw.tween_property(_ui_bits, "scale", Vector2(1.25, 1.25), 0.06)
	tw.tween_property(_ui_bits, "scale", Vector2.ONE, 0.15)

func _collect_chip(c: Node3D) -> void:
	c.visible = false
	chip_count += 1
	(_ui_chips[chip_count - 1] as Control).modulate = Color(1, 1, 1, 1)
	Sound.sfx(DIR + "audio/chip_%d.ogg" % chip_count, -3.0)
	StoryProps.burst(self, c.global_position, Color(1.0, 0.85, 0.4))
	if chip_count == 5:
		_form_launch_star(c.global_position)

func _form_launch_star(from: Vector3) -> void:
	# the five chips fly together and become a launch star on top of planet A
	var target := PLANET_A + Vector3(-0.35, 0.92, -0.18).normalized() * (PLANET_A_R + 1.1)
	var up := (target - PLANET_A).normalized()
	var ls := _launch_star(target, SUMMIT + Vector3(0, 1.4, 11.0), 34.0, 3.2, 3, false)
	ls.global_transform = Transform3D(_basis_up(up), target)
	await get_tree().create_timer(0.6).timeout
	say("The pieces fit together!", 2.4)
	for i in 5:
		var spark := MeshInstance3D.new()
		spark.mesh = B.star(0.35, 0.16, 0.12)
		spark.material_override = B.star_mat()
		add_child(spark)
		spark.global_position = claude.global_position + claude.up() * 1.2
		var tw := create_tween()
		tw.tween_property(spark, "global_position", target, 1.0 + i * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(spark.queue_free)
	await get_tree().create_timer(1.6).timeout
	Sound.sfx(DIR + "audio/star_appear.ogg", -2.0)
	ls.visible = true
	ls.scale = Vector3.ZERO
	create_tween().tween_property(ls, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for l in launch_stars:
		if l["node"] == ls: l["active"] = true
	StoryProps.burst(self, target, Color(1.0, 0.8, 0.4))
	hint("A launch star appeared!", 4.0)

func _on_spin() -> void:
	# spinning also grabs star bits a bit further away
	for n in bits:
		var b := n as MeshInstance3D
		if b.visible and b.global_position.distance_to(claude.global_position + claude.up() * 0.6) < 2.4:
			_collect_bit(b)

# ------------------------------------------------------------------ launch stars
func _launch(ls: Dictionary) -> void:
	_flying = true
	hud.set_prompt("")
	claude.in_flight = true
	claude.control_enabled = false
	claude.velocity = Vector3.ZERO
	var n: Node3D = ls["node"]
	var from := n.global_position
	var to: Vector3 = ls["to"]
	var apex: float = ls["apex"]
	var dur: float = ls["dur"]
	Sound.sfx(DIR + "audio/launch.ogg", -2.0)
	# wind-up: Claude is pulled into the star and spins
	var t := 0.0
	var start := claude.global_position
	while t < 0.55:
		var dt := get_process_delta_time()
		t += dt
		var k := clampf(t / 0.55, 0.0, 1.0)
		claude.global_position = start.lerp(from, k * k)
		claude.rig.rotation.y += dt * 18.0 * k
		(n.get_node("Mesh") as Node3D).rotation.z += dt * 20.0
		await get_tree().process_frame
	# flight along an arc, cinematic camera
	cine.global_transform = claude.camera.global_transform
	cine.current = true
	var ctrl := from.lerp(to, 0.5) + Vector3.UP * apex
	var trail := _dust_trail()
	claude.add_child(trail)
	trail.position = Vector3(0, 0.5, 0)
	var side := (to - from).cross(Vector3.UP).normalized()
	t = 0.0
	var prev := from
	while t < dur:
		var dt := get_process_delta_time()
		t += dt
		var k := clampf(t / dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k) * 0.3 + k * 0.7
		var p := _bez(from, ctrl, to, e)
		claude.global_position = p
		var vel := (p - prev) / maxf(dt, 0.0001)
		prev = p
		# superman pose with a corkscrew spin; in the last stretch Claude
		# rights herself so she lands on her feet
		var settle := smoothstep(0.78, 0.97, k)
		if vel.length() > 0.1:
			claude.rig.rotation = Vector3(-1.2 * (1.0 - settle), atan2(-vel.x, -vel.z), 0.0)
		claude.rig.flight = lerpf(claude.rig.flight, 1.0 - settle, 1.0 - exp(-8.0 * dt))
		claude.rig.rotation.z = t * 9.0 * (1.0 - settle)
		claude.rig.animate(dt, Vector3.ZERO, settle < 0.5)
		# camera: behind and to the side, looking ahead of Claude
		var look_ahead := _bez(from, ctrl, to, minf(1.0, e + 0.08))
		var back := (from - to).normalized()
		var cam_target := p + back * 6.0 + Vector3.UP * 3.0 + side * (2.5 + 2.5 * sin(k * PI))
		cine.global_position = cine.global_position.lerp(cam_target, 1.0 - exp(-7.0 * dt))
		cine.look_at(p.lerp(look_ahead, 0.4), Vector3.UP)
		cine.fov = lerpf(cine.fov, 70.0 - 10.0 * k, 1.0 - exp(-3.0 * dt))
		await get_tree().process_frame
	trail.emitting = false
	get_tree().create_timer(1.2).timeout.connect(trail.queue_free)
	# landing
	claude.rig.rotation = Vector3.ZERO
	claude.rig.flight = 0.0
	var dir := (to - from); dir.y = 0.0
	claude.teleport(Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), to))
	claude.in_flight = false
	claude.control_enabled = true
	claude.make_current()
	cine.fov = 60.0
	Sound.sfx("land", -4.0)
	_flying = false
	if ls["area"] == 1: say("Whee!", 1.6)
	if ls["area"] == 2:
		hint("A tiny planet! Run all the way around it – find the 5 star pieces.", 6.0)
	if ls["area"] == 3: say("There it is …", 2.2)

## Rainbow star dust that Claude leaves behind while flying.
func _dust_trail() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 0.8
	p.local_coords = false
	p.fixed_fps = 0
	p.visibility_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.45
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -0.6, 0)
	pm.damping_min = 1.0; pm.damping_max = 2.0
	pm.scale_min = 0.35; pm.scale_max = 1.0
	var sc := Curve.new(); sc.add_point(Vector2(0, 1)); sc.add_point(Vector2(0.6, 0.7)); sc.add_point(Vector2(1, 0))
	var sct := CurveTexture.new(); sct.curve = sc
	pm.scale_curve = sct
	var cols := Gradient.new()
	cols.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	cols.colors = PackedColorArray(BIT_COLORS)
	var ct := GradientTexture1D.new(); ct.gradient = cols
	pm.color_initial_ramp = ct
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new(); ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.55, 0.55)
	var m := ShaderMaterial.new(); m.shader = DUST
	q.material = m
	p.draw_pass_1 = q
	return p

func _bez(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t

func _fall_respawn() -> void:
	# fade to a deep dream-violet, reappear at the checkpoint with a shimmer
	_falling_out = true
	claude.control_enabled = false
	var tw := create_tween()
	tw.tween_property(_void_fade, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		claude.respawn()
		Sound.sfx(DIR + "audio/respawn.ogg", -8.0))
	tw.tween_interval(0.15)
	tw.tween_property(_void_fade, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		claude.control_enabled = true
		_falling_out = false
		_fall_sound = false)

# ------------------------------------------------------------------ the end
func _win() -> void:
	_won = true
	claude.control_enabled = false
	claude.velocity = Vector3.ZERO
	hud.set_prompt("")
	Sound.stop_music(0.4)
	Sound.sfx(DIR + "audio/fanfare.ogg", 0.0)
	claude.rig.mood = RobotRig.Mood.SPARKLE
	var tw := create_tween()
	tw.tween_property(dream_star, "global_position", claude.global_position + Vector3(0, 2.4, 0), 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(dream_star, "scale", Vector3.ONE * 0.7, 0.8)
	# camera circles around Claude holding the star up
	cine.global_transform = claude.camera.global_transform
	cine.current = true
	var big := Label.new()
	big.text = "DREAM STAR!"
	big.add_theme_font_override("font", FONT)
	big.add_theme_font_size_override("font_size", 130)
	big.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	big.add_theme_color_override("font_outline_color", Color(0.45, 0.15, 0.4))
	big.add_theme_constant_override("outline_size", 24)
	big.set_anchors_preset(Control.PRESET_CENTER)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	big.grow_vertical = Control.GROW_DIRECTION_BOTH
	big.position.y += 260
	big.modulate.a = 0.0
	_ui_root.add_child(big)
	var tw2 := create_tween()
	tw2.tween_interval(1.0)
	tw2.tween_property(big, "modulate:a", 1.0, 0.4)
	var t := 0.0
	var center := claude.global_position + Vector3(0, 1.4, 0)
	while t < 5.5:
		var dt := get_process_delta_time()
		t += dt
		var a := t * 0.6 + 0.4
		cine.global_position = cine.global_position.lerp(center + Vector3(sin(a) * 5.5, 1.5 + t * 0.15, cos(a) * 5.5), 1.0 - exp(-3.0 * dt))
		cine.look_at(center, Vector3.UP)
		claude.rig.animate(dt, Vector3.ZERO, true)
		claude.rig.head_extra = Vector3(-0.35, 0, 0)
		if dream_star: dream_star.get_node("Mesh").rotation.y += dt * 4.0
		await get_tree().process_frame
	say("I'll paint this one next.", 2.6)
	complete(2.8)
