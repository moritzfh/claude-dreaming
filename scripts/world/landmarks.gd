## Big distant shapes: cliff wall with waterfalls, mountains, the cliff city,
## floating islands and cumulus clouds.
class_name Landmarks
extends RefCounted

static var rng := RandomNumberGenerator.new()

static func ss(a: float, b: float, x: float) -> float:
	return Terrain.ss(a, b, x)

# ------------------------------------------------------------------ cliff wall
static func build_mesa(parent: Node3D, rock_mat: Material, fall_mat: Material, mist_mat: Material) -> void:
	var n := FastNoiseLite.new(); n.seed = 3; n.frequency = 0.01
	var nv := FastNoiseLite.new(); nv.seed = 9; nv.frequency = 0.08
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 180
	var rows := 40
	var top := 150.0
	var grid := []
	for c in cols + 1:
		var s := float(c) / cols
		var x := lerpf(-150.0, 250.0, s)
		var z := -560.0 - 220.0 * pow(absf(2.0 * s - 1.0), 2.5) + n.get_noise_1d(x) * 18.0
		var th := top * (0.55 + 0.45 * Terrain.ss(-150.0, -60.0, x)) + n.get_noise_2d(x, 50.0) * 14.0 + nv.get_noise_1d(x * 0.4) * 6.0
		var col := []
		for r in rows + 1:
			var t := float(r) / rows
			var y := lerpf(-8.0, th, t)
			# vertical ribs + overhang-ish bulges
			var out := nv.get_noise_2d(x * 1.0, y * 0.08) * 7.0 + n.get_noise_2d(x * 2.0, y) * 6.0
			out += (1.0 - t) * 10.0   # wider foot
			col.append(Vector3(x, y, z + out))
		# top cap going back
		col.append(Vector3(x, th + 2.0, z - 30.0))
		col.append(Vector3(x, th + 6.0 + n.get_noise_2d(x, 99.0) * 8.0, -1000.0))
		grid.append(col)
	var rr: int = rows + 3
	for c in cols + 1:
		for r in rr:
			st.add_vertex(grid[c][r])
	for c in cols:
		for r in rr - 1:
			var a := c * rr + r
			var b := (c + 1) * rr + r
			st.add_index(a); st.add_index(a + 1); st.add_index(b)
			st.add_index(b); st.add_index(a + 1); st.add_index(b + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "CliffWall"
	mi.mesh = st.commit()
	mi.material_override = rock_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

	# three waterfalls like in the film (thin left, wide middle, right)
	for f in [[-40.0, 6.0], [35.0, 15.0], [118.0, 8.0]]:
		var fx: float = f[0]
		var s2 := (fx + 150.0) / 400.0
		var fz := -560.0 - 220.0 * pow(absf(2.0 * s2 - 1.0), 2.5) + n.get_noise_1d(fx) * 18.0 + 14.0
		build_waterfall(parent, Vector3(fx, 138.0 * (0.55 + 0.45 * Terrain.ss(-150.0, -60.0, fx)), fz), Vector3(fx, -1.0, fz + 6.0), f[1], 12.0, fall_mat, mist_mat, 3.0)

static func build_waterfall(parent: Node3D, top: Vector3, bottom: Vector3, width: float, push: float, fall_mat: Material, mist_mat: Material, mist_scale := 1.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 24
	var across := 6
	var dir := Vector3(bottom.x - top.x, 0, bottom.z - top.z)
	var outward := dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	var side := outward.cross(Vector3.UP).normalized()
	for i in segs + 1:
		var t := float(i) / segs
		# ballistic-ish arc: pushes out first, then falls
		var p := top.lerp(bottom, t)
		p.y = lerpf(top.y, bottom.y, t * t * 0.4 + t * 0.6)
		p += outward * push * sin(minf(t * 2.2, 1.0) * PI * 0.5)
		var wdt := width * (1.0 + t * 0.6)
		for k in across + 1:
			var u := float(k) / across
			st.set_uv(Vector2(u, t * (top.y - bottom.y) / 30.0))
			st.add_vertex(p + side * (u - 0.5) * wdt)
	for i in segs:
		for k in across:
			var a := i * (across + 1) + k
			var b := a + across + 1
			st.add_index(a); st.add_index(a + 1); st.add_index(b)
			st.add_index(a + 1); st.add_index(b + 1); st.add_index(b)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Waterfall"
	mi.mesh = st.commit()
	mi.material_override = fall_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# spray / mist at the bottom
	var ps := GPUParticles3D.new()
	ps.name = "Mist"
	ps.amount = int(40 * mist_scale)
	ps.lifetime = 6.0
	ps.preprocess = 6.0
	ps.visibility_aabb = AABB(Vector3(-60, -10, -60) * mist_scale, Vector3(120, 60, 120) * mist_scale)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.6, 1.0, 3.0)
	pm.direction = Vector3(0, 1, 0.6)
	pm.spread = 60.0
	pm.initial_velocity_min = 1.0 * mist_scale
	pm.initial_velocity_max = 4.0 * mist_scale
	pm.gravity = Vector3(0, 0.3, 0)
	pm.damping_min = 0.5; pm.damping_max = 1.0
	pm.scale_min = 6.0 * mist_scale
	pm.scale_max = 14.0 * mist_scale
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.2, Color(1, 1, 1, 1))
	grad.add_point(0.6, Color(1, 1, 1, 0.7))
	var gt := GradientTexture1D.new(); gt.gradient = grad
	pm.color_ramp = gt
	ps.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	q.material = mist_mat
	ps.draw_pass_1 = q
	ps.position = bottom + outward * push
	parent.add_child(ps)
	var snd := AudioStreamPlayer3D.new()
	var wst := load("res://assets/audio/sfx/waterfall_loop.ogg") as AudioStreamOggVorbis
	wst.loop = true
	snd.stream = wst
	snd.unit_size = 12.0 * mist_scale
	snd.max_distance = 260.0 * mist_scale
	snd.volume_db = -4.0
	snd.autoplay = true
	snd.position = bottom + outward * push + Vector3(0, 4, 0)
	parent.add_child(snd)

# ------------------------------------------------------------------ mountains
static func build_mountains(parent: Node3D, mat: Material) -> void:
	var peaks := [
		[Vector3(70, -20, -880), 300.0, 230.0],
		[Vector3(-60, -20, -1050), 220.0, 260.0],
		[Vector3(300, -20, -1050), 260.0, 280.0],
		[Vector3(-700, -20, -1300), 380.0, 420.0],
		[Vector3(-1100, -20, -700), 300.0, 380.0],
		[Vector3(700, -20, -1400), 420.0, 420.0],
	]
	var n := FastNoiseLite.new(); n.seed = 21; n.frequency = 0.012; n.fractal_octaves = 5
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	for pk in peaks:
		var c: Vector3 = pk[0]
		var h: float = pk[1]
		var r: float = pk[2]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ang := 48
		var rings := 24
		for i in rings + 1:
			var t := float(i) / rings     # 0 = peak, 1 = base
			for a in ang:
				var phi := TAU * a / ang
				var dir := Vector3(cos(phi), 0, sin(phi))
				var rad := r * pow(t, 0.85)
				var p := c + dir * rad
				var ridge := n.get_noise_3d(dir.x * 120.0, t * 80.0, dir.z * 120.0)
				var lump := n.get_noise_2d(phi * 30.0, 7.0)
				p.y = c.y + h * (1.0 - pow(t, 0.6 + lump * 0.25)) + ridge * 55.0 * sin(t * PI)
				p += dir * ridge * 40.0 * t
				st.add_vertex(p)
		for i in rings:
			for a in ang:
				var a0 := i * ang + a
				var a1 := i * ang + (a + 1) % ang
				st.add_index(a0); st.add_index(a0 + ang); st.add_index(a1)
				st.add_index(a1); st.add_index(a0 + ang); st.add_index(a1 + ang)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Mountain"
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

# ------------------------------------------------------------------ city
static func build_city(parent: Node3D, mat: Material, dome_mat: Material, roof_mat: Material) -> void:
	rng.seed = 77
	var boxes: Array[Transform3D] = []
	var colors: Array[Color] = []
	var domes: Array[Transform3D] = []
	var cones: Array[Transform3D] = []
	var palette := [Color(0.68, 0.57, 0.47), Color(0.62, 0.54, 0.48), Color(0.72, 0.60, 0.48), Color(0.56, 0.49, 0.48), Color(0.70, 0.56, 0.44), Color(0.60, 0.53, 0.56)]
	var z := -70.0
	while z > -640.0:
		var x := Terrain.city_front(z) - 6.0
		while x < 470.0:
			var jx := x + rng.randf_range(-2.5, 2.5)
			var jz := z + rng.randf_range(-2.5, 2.5)
			var h := Terrain.city_height(jx, jz)
			var cd := jx - Terrain.city_front(jz)
			if h > 4.0 and rng.randf() < 0.62:
				var w := rng.randf_range(6.0, 14.0)
				var d := rng.randf_range(6.0, 13.0)
				var ht := rng.randf_range(5.0, 13.0) + (5.0 if cd < 40.0 else 0.0) + (rng.randf_range(0.0, 8.0) if rng.randf() < 0.2 else 0.0)
				var tower := rng.randf() < 0.025
				if tower:
					w = rng.randf_range(4.0, 6.0); d = w
					ht = rng.randf_range(22.0, 38.0)
				var base := h - 3.0
				var yaw := rng.randf_range(-0.08, 0.08)
				var b := Basis(Vector3.UP, yaw).scaled(Vector3(w, ht, d))
				boxes.append(Transform3D(b, Vector3(jx, base + ht * 0.5, jz)))
				colors.append(palette[rng.randi() % palette.size()] * rng.randf_range(0.93, 1.03))
				if tower:
					if rng.randf() < 0.75:
						domes.append(Transform3D(Basis().scaled(Vector3(w * 0.62, w * 0.75, w * 0.62)), Vector3(jx, base + ht, jz)))
					else:
						cones.append(Transform3D(Basis().scaled(Vector3(w * 0.75, w * 1.6, w * 0.75)), Vector3(jx, base + ht + w * 0.8, jz)))
				elif rng.randf() < 0.05:
					domes.append(Transform3D(Basis().scaled(Vector3(minf(w, d) * 0.45, minf(w, d) * 0.5, minf(w, d) * 0.45)), Vector3(jx, base + ht, jz)))
			x += rng.randf_range(7.0, 10.0)
		z -= rng.randf_range(7.0, 10.0)
	var box := BoxMesh.new()
	_multimesh(parent, "CityBlocks", box, boxes, colors, mat)
	var dome := SphereMesh.new(); dome.is_hemisphere = true; dome.radius = 1.0; dome.height = 1.0; dome.radial_segments = 24; dome.rings = 8
	_multimesh(parent, "CityDomes", dome, domes, [], dome_mat)
	var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 1.0; cone.height = 1.0; cone.radial_segments = 12
	_multimesh(parent, "CitySpires", cone, cones, [], roof_mat)
	print("city blocks: ", boxes.size())

static func _multimesh(parent: Node3D, nm: String, mesh: Mesh, xf: Array, cols: Array, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = cols.size() > 0
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if mm.use_colors: mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)
	return mmi

# ------------------------------------------------------------------ floating islands
static func island_mesh(radius: float, depth: float, seed_v: int, grass := true) -> ArrayMesh:
	var n := FastNoiseLite.new(); n.seed = seed_v; n.frequency = 0.9
	var r2 := RandomNumberGenerator.new(); r2.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ang := 40
	var rings := 14
	var top_col := Color(0.42, 0.56, 0.30)
	var rock_hi := Color(0.50, 0.42, 0.46)
	var rock_lo := Color(0.30, 0.26, 0.34)
	# top cap (fan)
	st.set_color(top_col)
	st.add_vertex(Vector3(0, radius * 0.06, 0))
	var edge := []
	for a in ang:
		var phi := TAU * a / ang
		var rr := radius * (1.0 + n.get_noise_1d(phi * 3.0) * 0.18)
		edge.append(Vector3(cos(phi) * rr, n.get_noise_1d(phi * 5.0 + 9.0) * radius * 0.03, sin(phi) * rr))
	for a in ang:
		st.set_color(top_col if grass else rock_hi)
		st.add_vertex(edge[a])
	# underside rings
	for i in range(1, rings + 1):
		var t := float(i) / rings
		var shrink := pow(1.0 - t, 0.6)
		for a in ang:
			var phi := TAU * a / ang
			var e: Vector3 = edge[a]
			var jag := n.get_noise_2d(phi * 4.0, t * 6.0)
			var p := Vector3(e.x * shrink * (1.0 + jag * 0.15), -depth * t * (0.8 + jag * 0.25), e.z * shrink * (1.0 + jag * 0.15))
			if i == 1:
				p = Vector3(e.x * 1.02, -radius * 0.08, e.z * 1.02)
			st.set_color(rock_hi.lerp(rock_lo, t))
			st.add_vertex(p)
	for a in ang:
		st.add_index(0); st.add_index(1 + a); st.add_index(1 + (a + 1) % ang)
	for i in rings:
		var o0 := 1 + i * ang
		var o1 := o0 + ang
		for a in ang:
			var b := (a + 1) % ang
			st.add_index(o0 + a); st.add_index(o1 + a); st.add_index(o0 + b)
			st.add_index(o0 + b); st.add_index(o1 + a); st.add_index(o1 + b)
	# stalactite spikes hanging below
	var spikes := r2.randi_range(4, 8)
	var base_i := 1 + (rings + 1) * ang
	for s in spikes:
		var phi := r2.randf() * TAU
		var dist := r2.randf_range(0.15, 0.7) * radius
		var c := Vector3(cos(phi) * dist, -depth * r2.randf_range(0.1, 0.4), sin(phi) * dist)
		var len := depth * r2.randf_range(0.4, 1.0) * (1.0 - dist / radius * 0.6)
		var sr := radius * r2.randf_range(0.12, 0.25)
		var tip := c + Vector3(r2.randf_range(-0.1, 0.1) * len, -len, r2.randf_range(-0.1, 0.1) * len)
		var k := 6
		for j in k:
			var ph := TAU * j / k
			st.set_color(rock_hi)
			st.add_vertex(c + Vector3(cos(ph) * sr, sr * 0.5, sin(ph) * sr))
		st.set_color(rock_lo)
		st.add_vertex(tip)
		for j in k:
			st.add_index(base_i + j); st.add_index(base_i + k); st.add_index(base_i + (j + 1) % k)
		base_i += k + 1
	st.generate_normals()
	return st.commit()

static func build_islands(parent: Node3D, mat: Material) -> void:
	var defs := [
		[Vector3(-175, 175, -520), 62.0, 70.0, 1],
		[Vector3(-95, 150, -470), 22.0, 30.0, 2],
		[Vector3(55, 205, -640), 26.0, 30.0, 3],
		[Vector3(170, 240, -520), 17.0, 22.0, 4],
		[Vector3(-330, 190, -640), 24.0, 30.0, 5],
		[Vector3(260, 260, -760), 30.0, 34.0, 6],
		[Vector3(-30, 300, -900), 40.0, 50.0, 7],
	]
	for d in defs:
		var mi := MeshInstance3D.new()
		mi.name = "FloatingIsland"
		mi.mesh = island_mesh(d[1], d[2], d[3])
		mi.material_override = mat
		mi.position = d[0]
		mi.rotation.y = d[3] * 1.7
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	# little floating rocks scattered around
	rng.seed = 404
	for i in 26:
		var mi := MeshInstance3D.new()
		var r := rng.randf_range(2.0, 6.0)
		mi.mesh = island_mesh(r, r * 1.6, 100 + i, false)
		mi.material_override = mat
		mi.position = Vector3(rng.randf_range(-450, 350), rng.randf_range(120, 280), rng.randf_range(-350, -800))
		mi.rotation.y = rng.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

# ------------------------------------------------------------------ clouds
static func build_clouds(parent: Node3D, mat: Material) -> void:
	rng.seed = 1234
	var xf: Array[Transform3D] = []
	var centers := []
	for i in 34:
		var ang := rng.randf_range(-PI * 0.95, PI * 0.95)
		var dist := rng.randf_range(650.0, 1400.0)
		centers.append(Vector3(sin(ang) * dist, rng.randf_range(170.0, 360.0), -cos(ang) * dist))
	for c in centers:
		var size := rng.randf_range(25.0, 60.0)
		var puffs := rng.randi_range(9, 18)
		for p in puffs:
			var o := Vector3(rng.randf_range(-1.6, 1.6) * size, 0.0, rng.randf_range(-0.8, 0.8) * size)
			var r := size * rng.randf_range(0.35, 0.75) * (1.0 - absf(o.x) / (size * 2.4))
			o.y = r * 0.35 + rng.randf_range(0.0, 0.5) * size * (1.0 - absf(o.x) / (size * 1.8))
			xf.append(Transform3D(Basis().scaled(Vector3(r, r * 0.9, r)), c + o))
	var sph := SphereMesh.new(); sph.radius = 1.0; sph.height = 2.0; sph.radial_segments = 20; sph.rings = 10
	var mmi := _multimesh(parent, "Clouds", sph, xf, [], mat)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
