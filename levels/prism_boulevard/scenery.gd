## Prism Boulevard – everything you look at but don't drive on: the sky, the
## lights, the road meshes, the sea of clouds and the cloud towers, planets,
## the set pieces along the course.
extends RefCounted

const DIR := "res://levels/prism_boulevard/"
const MESH := preload("res://levels/prism_boulevard/track_mesh.gd")
const SKY := preload("res://levels/prism_boulevard/shaders/sky.gdshader")
const GLASS := preload("res://levels/prism_boulevard/shaders/road_glass.gdshader")
const RIM := preload("res://levels/prism_boulevard/shaders/road_rim.gdshader")
const UNDER := preload("res://levels/prism_boulevard/shaders/road_under.gdshader")
const WALL := preload("res://levels/prism_boulevard/shaders/wall.gdshader")
const NEON := preload("res://levels/prism_boulevard/shaders/neon.gdshader")
const RIVER := preload("res://levels/prism_boulevard/shaders/river.gdshader")
const PUFF := preload("res://levels/prism_boulevard/shaders/cloud_puff.gdshader")
const SEA := preload("res://levels/prism_boulevard/shaders/cloud_sea.gdshader")
const WISP := preload("res://levels/prism_boulevard/shaders/wisp.gdshader")

static func mat(sh: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

# ------------------------------------------------------------------ environment
static func environment(root: Node3D) -> Array:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = mat(SKY)
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.45, 0.38, 0.75)
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.05
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 0.95
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0); env.set_glow_level(1, 0.5); env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8); env.set_glow_level(4, 0.45); env.set_glow_level(5, 0.2)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_light_color = Color(0.28, 0.16, 0.45)
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.0
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 2.5
	env.ssao_enabled = false
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.93, 0.95)
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-38.0, -50.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.5, 0.75, 1.0)
	fill.light_energy = 0.4
	fill.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	root.add_child(fill)
	return [env, sun]

# ------------------------------------------------------------------ the road
static func road(root: Node3D, tr) -> void:
	var parts := MESH.build_road(tr)
	var mats := {
		"glass": mat(GLASS), "river": mat(RIVER), "rim": mat(RIM),
		"under": mat(UNDER), "wall": mat(WALL), "neon": mat(NEON),
	}
	var holder := Node3D.new()
	holder.name = "Road"
	root.add_child(holder)
	for kind in parts.keys():
		for m in parts[kind]:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.material_override = mats[kind]
			if kind in ["neon", "under", "rim"]:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)

# ------------------------------------------------------------------ clouds
static func cloud_sea(root: Node3D, y: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	pm.subdivide_width = 2
	pm.subdivide_depth = 2
	mi.mesh = pm
	mi.material_override = mat(SEA)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(300, y, 150)
	mi.extra_cull_margin = 10000.0
	root.add_child(mi)

## Towers of cumulus rising from the sea of clouds around the course: a few
## big overlapping puffs per layer, getting smaller towards the top, with a
## crown of domes. Each puff knows how high up in its cloud it sits (for the
## shading). They keep their distance from every part of the road.
static func cloud_towers(root: Node3D, tr, sea_y: float, count: int, seed_v := 7, segs := 32) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = segs
	sphere.rings = segs / 2
	var m := mat(PUFF)
	var puffs: Array = []      # [pos, radius, height fraction]
	var tries := 0
	var made := 0
	while made < count and tries < count * 40:
		tries += 1
		var s: float = rng.randf() * tr.length
		var fr: Transform3D = tr.frame(s)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var flat := Vector3(fr.basis.x.x, 0, fr.basis.x.z)
		if flat.length() < 0.2: continue
		var off := rng.randf_range(45.0, 260.0)
		var base: Vector3 = fr.origin + flat.normalized() * side * off
		var big := rng.randf_range(28.0, 64.0)
		var base_y := sea_y - 20.0
		var top_y: float = fr.origin.y + rng.randf_range(-48.0, 4.0) - big * 0.25
		var hgt := top_y - base_y
		if hgt < 30.0: continue
		# puffs scattered through a cone: wide and flat below, lumpy domes on top
		var cand: Array = []
		var npf := clampi(int(hgt / big * 4.0) + 6, 8, 22)
		for k in npf:
			var u := pow(rng.randf(), 0.8)
			if k < 3: u = 1.0 - rng.randf() * 0.15          # make sure there is a crown
			var y := base_y + hgt * u
			var rad_allowed := big * (1.05 - 0.6 * u)
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * rad_allowed * 0.75
			var pr := big * (0.55 - 0.22 * u) * rng.randf_range(0.8, 1.25)
			cand.append([Vector3(base.x + cos(a) * d, y, base.z + sin(a) * d), pr, u])
		var ok := true
		for c in cand:
			var p: Vector3 = c[0]
			var rr: float = c[1]
			for i in range(0, tr.n, 8):
				if p.distance_to(tr.P[i]) < rr + 16.0 + tr.W[i] * 0.5:
					ok = false
					break
			if not ok: break
		if not ok: continue
		puffs.append_array(cand)
		made += 1
	_puff_multimeshes(root, puffs, sphere, m, rng, 0.88)

## Big flat billows half sunk into the sea of clouds, so it isn't flat.
static func sea_billows(root: Node3D, center: Vector3, sea_y: float, count: int, seed_v := 5) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var puffs: Array = []
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 1100.0
		var r := rng.randf_range(50.0, 150.0)
		puffs.append([center + Vector3(cos(a) * d, sea_y - r * 0.12 + rng.randf_range(-6.0, 6.0), sin(a) * d), r, 0.55])
	_puff_multimeshes(root, puffs, sphere, mat(PUFF), rng, 0.32)

static func _puff_multimeshes(root: Node3D, puffs: Array, sphere: Mesh, m: Material, rng: RandomNumberGenerator, flat: float) -> void:
	var buckets := {}
	for pf in puffs:
		var p: Vector3 = pf[0]
		var key := Vector2i(floori(p.x / 400.0), floori(p.z / 400.0))
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(pf)
	for key in buckets.keys():
		var arr: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = sphere
		mm.instance_count = arr.size()
		for i in arr.size():
			var p: Vector3 = arr[i][0]
			var rr: float = arr[i][1]
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rr, rr * flat, rr))
			mm.set_instance_transform(i, Transform3D(b, p))
			mm.set_instance_custom_data(i, Color(rng.randf(), float(arr[i][2]), 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)

## Soft cloud wisps (billboards) drifting close to the road – they make the
## speed visible.
static func wisps(root: Node3D, tr, count: int, seed_v := 11) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := mat(WISP)
	var buckets := {}
	var made := 0
	var tries := 0
	while made < count and tries < count * 20:
		tries += 1
		var s: float = rng.randf() * tr.length
		if tr.is_hyper(s): continue
		var fr: Transform3D = tr.frame(s)
		var size := rng.randf_range(22.0, 60.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var w: float = tr.width(s)
		var off := w * 0.5 + 8.0 + size * 0.4 + rng.randf_range(0.0, 40.0)
		var p: Vector3 = fr.origin + fr.basis.x * side * off + Vector3(0, rng.randf_range(-16.0, 4.0), 0)
		var ok := true
		for i in range(0, tr.n, 6):
			if p.distance_to(tr.P[i]) < size * 0.4 + tr.W[i] * 0.5 + 4.0:
				ok = false
				break
		if not ok: continue
		var key := Vector2i(floori(p.x / 400.0), floori(p.z / 400.0))
		if not buckets.has(key): buckets[key] = []
		buckets[key].append([p, size])
		made += 1
	for key in buckets.keys():
		var arr: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = q
		mm.instance_count = arr.size()
		for i in arr.size():
			var sz: float = arr[i][1]
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sz, sz * 0.55, 1.0)), arr[i][0]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 60.0
		root.add_child(mmi)

# ------------------------------------------------------------------ far away
const FAR := preload("res://levels/prism_boulevard/shaders/far_planet.gdshader")
const RING := preload("res://levels/prism_boulevard/shaders/ring.gdshader")
const SPIRAL := preload("res://levels/prism_boulevard/shaders/spiral.gdshader")
const SPARKLE := preload("res://levels/prism_boulevard/shaders/sparkle.gdshader")

static func backdrop(root: Node3D, tr) -> Node3D:
	var far := Node3D.new()
	far.name = "Backdrop"
	root.add_child(far)
	var c := Vector3(300, 0, 150)       # roughly the middle of the course
	var sun_dir := Vector3(-0.45, 0.62, 0.64)
	_far_planet(far, c + Vector3(-0.72, 0.16, -0.67).normalized() * 2900.0, 560.0, Color(1.0, 0.62, 0.5), Color(0.75, 0.32, 0.62), Color(1.0, 0.78, 0.7), true, sun_dir)
	_far_planet(far, c + Vector3(0.82, 0.38, -0.42).normalized() * 2500.0, 150.0, Color(0.45, 0.85, 1.0), Color(0.3, 0.45, 0.9), Color(0.7, 0.92, 1.0), false, sun_dir)
	_far_planet(far, c + Vector3(0.3, 0.05, 0.95).normalized() * 2600.0, 230.0, Color(0.7, 1.0, 0.75), Color(0.35, 0.7, 0.75), Color(0.8, 1.0, 0.9), true, sun_dir)
	var gal := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1100, 1100)
	gal.mesh = q
	gal.material_override = mat(SPIRAL)
	far.add_child(gal)
	gal.position = c + Vector3(0.2, 0.55, 0.81).normalized() * 3300.0
	gal.look_at_from_position(gal.position, c, Vector3.UP)
	gal.rotate_object_local(Vector3.FORWARD, 0.6)
	gal.extra_cull_margin = 4000.0
	# twinkling stars all around
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	var sq := QuadMesh.new()
	sq.size = Vector2(1, 1)
	var spm := mat(SPARKLE)
	spm.set_shader_parameter("energy", 4.0)
	sq.material = spm
	mm.mesh = sq
	mm.instance_count = 420
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in mm.instance_count:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(10.0, 30.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), c + d * rng.randf_range(1600, 2400)))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), 0))
		mm.set_instance_color(i, Color(1, 1, 1))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 5000.0
	far.add_child(mmi)
	return far

static func _far_planet(parent: Node3D, pos: Vector3, r: float, a: Color, b: Color, atmo: Color, ring: bool, light_dir: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 64
	sm.rings = 32
	mi.mesh = sm
	var m := mat(FAR)
	m.set_shader_parameter("col_a", a)
	m.set_shader_parameter("col_b", b)
	m.set_shader_parameter("atmo", atmo)
	m.set_shader_parameter("light_dir", light_dir)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4000.0
	parent.add_child(mi)
	mi.position = pos
	mi.rotation = Vector3(0.35, 0.2, 0.3)
	if ring:
		var rm := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(r * 4.8, r * 4.8)
		rm.mesh = pm
		rm.material_override = mat(RING)
		rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(rm)
