## Mesh and material helpers for Stardust Islands (procedural geometry).
extends RefCounted

const TOON := preload("res://levels/stardust/shaders/toon.gdshader")
const STAR := preload("res://levels/stardust/shaders/star.gdshader")
const CRYSTAL := preload("res://levels/stardust/shaders/crystal.gdshader")

static func toon(params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	for k in params: m.set_shader_parameter(k, params[k])
	return m

static func grass_mat(a := Color(0.24, 0.66, 0.28), b := Color(0.60, 0.90, 0.32), ea := Color(0.62, 0.40, 0.26), eb := Color(0.82, 0.56, 0.34)) -> ShaderMaterial:
	return toon({"mode": 0, "grass_a": a, "grass_b": b, "earth_a": ea, "earth_b": eb})

static func candy_mat(base: Color, stripe := Color(1.0, 0.96, 0.98), scale := 2.4) -> ShaderMaterial:
	return toon({"mode": 1, "base_col": base, "stripe_col": stripe, "stripe_scale": scale, "rim_col": Color(1.0, 0.9, 1.0), "rim_strength": 0.45})

static func star_mat(a := Color(1.0, 0.82, 0.25), b := Color(1.0, 0.55, 0.15), energy := 0.9) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = STAR
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("energy", energy)
	return m

static func crystal_mat(c: Color, energy := 1.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CRYSTAL
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("energy", energy)
	return m

## Floating island: a slightly domed grassy top with a wavy outline and a
## rounded lip, above a rocky cone that tapers to a tip.
## Returns [mesh, top_height_func(Vector2 local xz) -> float]
static func island(r: float, depth: float, seed_v: int, dome := 0.6) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var seg := 64
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var amp := [rng.randf_range(0.04, 0.08), rng.randf_range(0.03, 0.06), rng.randf_range(0.01, 0.025)]
	var m_of := func(a: float) -> float:
		return 1.0 + amp[0] * sin(3.0 * a + ph[0]) + amp[1] * sin(5.0 * a + ph[1]) + amp[2] * sin(9.0 * a + ph[2])
	var rings: Array = []   # each: Array of Vector3
	# top: centre + rings out to the rim
	var top_n := 7
	for i in range(1, top_n + 1):
		var t := float(i) / top_n
		var ring := []
		for k in seg:
			var a := TAU * k / seg
			var rr: float = r * m_of.call(a) * t
			var y := dome * (1.0 - t * t)
			ring.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		rings.append(ring)
	# rounded lip
	for lip in [[1.03, -0.18], [1.035, -0.45], [1.0, -0.75]]:
		var ring := []
		for k in seg:
			var a := TAU * k / seg
			var rr: float = r * m_of.call(a) * lip[0]
			ring.append(Vector3(cos(a) * rr, lip[1], sin(a) * rr))
		rings.append(ring)
	# rocky underside
	var bot_n := 9
	for j in range(1, bot_n + 1):
		var t := float(j) / (bot_n + 1)
		var ring := []
		for k in seg:
			var a := TAU * k / seg
			var bump := 1.0 + rng.randf_range(-0.07, 0.07) + 0.08 * sin(a * 4.0 + j)
			var rr: float = r * m_of.call(a) * pow(1.0 - t, 1.25) * 0.98 * bump
			var y := -0.75 - depth * pow(t, 0.95) + rng.randf_range(-0.15, 0.15) * depth * 0.05
			ring.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var top_c := Vector3(0, dome, 0)
	var tip := Vector3(rng.randf_range(-0.1, 0.1) * r, -0.75 - depth * 1.05, rng.randf_range(-0.1, 0.1) * r)
	# fan at the top
	for k in seg:
		var k2 := (k + 1) % seg
		_tri(st, top_c, rings[0][k2], rings[0][k])
	for i in rings.size() - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			var a: Vector3 = rings[i][k]; var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k]; var d: Vector3 = rings[i + 1][k2]
			_tri(st, a, b, d)
			_tri(st, a, d, c)
	var last: Array = rings[rings.size() - 1]
	for k in seg:
		var k2 := (k + 1) % seg
		_tri(st, last[k], last[k2], tip)
	st.generate_normals()
	var mesh := st.commit()
	var top_h := func(p: Vector2) -> float:
		var a := atan2(p.y, p.x)
		var t := p.length() / (r * float(m_of.call(a)))
		return dome * (1.0 - t * t) if t <= 1.0 else -1.0
	return [mesh, top_h]

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# callers list vertices counter-clockwise seen from outside; Godot wants
	# clockwise for front faces, so emit them reversed
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)

## Puffy five-pointed star in the XY plane, facing +Z.
static func star(r_out := 1.0, r_in := 0.48, thick := 0.32, points := 5) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var n := points * 2
	var outline := []
	for i in n:
		var a := PI * 0.5 + TAU * i / n
		var rr := r_out if i % 2 == 0 else r_in
		outline.append(Vector3(cos(a) * rr, sin(a) * rr, 0.0))
	for side in [1.0, -1.0]:
		var c := Vector3(0, 0, thick * side)
		var mid := []
		for p in outline:
			mid.append((p as Vector3) * 0.55 + Vector3(0, 0, thick * 0.78 * side))
		for i in n:
			var i2 := (i + 1) % n
			var o1: Vector3 = outline[i]; var o2: Vector3 = outline[i2]
			var m1: Vector3 = mid[i]; var m2: Vector3 = mid[i2]
			if side > 0.0:
				_tri(st, c, m2, m1)
				_tri(st, m1, m2, o2)
				_tri(st, m1, o2, o1)
			else:
				_tri(st, c, m1, m2)
				_tri(st, m1, o1, o2)
				_tri(st, m1, o2, m2)
	st.generate_normals()
	return st.commit()

## A sweet-like gem (hexagonal bipyramid).
static func gem(r := 0.16, h := 0.2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, h, 0)
	var bot := Vector3(0, -h, 0)
	var ring := []
	for i in 6:
		var a := TAU * i / 6.0
		ring.append(Vector3(cos(a) * r, 0, sin(a) * r))
	for i in 6:
		var a: Vector3 = ring[i]; var b: Vector3 = ring[(i + 1) % 6]
		_tri(st, top, b, a)
		_tri(st, bot, a, b)
	st.generate_normals()
	return st.commit()

## A tuft of 5 chunky grass blades (UV.y = height 0..1).
static func tuft(seed_v := 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf_range(-0.3, 0.3)
		var h := rng.randf_range(0.2, 0.34)
		var w := rng.randf_range(0.045, 0.07)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var base := out * 0.03
		var tip := out * rng.randf_range(0.08, 0.14) + Vector3(0, h, 0)
		var mid := base.lerp(tip, 0.5) + out * 0.02
		var n := out
		st.set_normal(n)
		st.set_uv(Vector2(0, 0)); st.add_vertex(base - side * w)
		st.set_uv(Vector2(0, 0)); st.add_vertex(base + side * w)
		st.set_uv(Vector2(0, 0.55)); st.add_vertex(mid + side * w * 0.6)
		st.set_uv(Vector2(0, 0)); st.add_vertex(base - side * w)
		st.set_uv(Vector2(0, 0.55)); st.add_vertex(mid + side * w * 0.6)
		st.set_uv(Vector2(0, 0.55)); st.add_vertex(mid - side * w * 0.6)
		st.set_uv(Vector2(0, 0.55)); st.add_vertex(mid - side * w * 0.6)
		st.set_uv(Vector2(0, 0.55)); st.add_vertex(mid + side * w * 0.6)
		st.set_uv(Vector2(0, 1)); st.add_vertex(tip)
	return st.commit()

## A little flower: stem and centre from vertex colours, petals tinted per
## instance (vertex alpha 1).
static func flower() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem_c := Color(0.30, 0.65, 0.28, 0.0)
	var h := 0.24
	for rot in [0.0, PI * 0.5]:
		var s := Vector3(cos(rot), 0, sin(rot)) * 0.012
		for v in [-s, s, s + Vector3(0, h, 0), -s, s + Vector3(0, h, 0), -s + Vector3(0, h, 0)]:
			st.set_color(stem_c); st.set_normal(Vector3(0, 0, 1).rotated(Vector3.UP, rot)); st.add_vertex(v)
	var top := Vector3(0, h, 0)
	for i in 5:
		var a := TAU * i / 5.0
		var d := Vector3(cos(a), 0.35, sin(a)).normalized()
		var sd := Vector3(-sin(a), 0, cos(a))
		var p0 := top + d * 0.015
		var p1 := top + d * 0.09
		var w := 0.038
		var pc := Color(1, 1, 1, 1)
		var nrm := Vector3(0, 1, 0)
		for v in [p0 - sd * w * 0.5, p1 - sd * w, p1 + sd * w, p0 - sd * w * 0.5, p1 + sd * w, p0 + sd * w * 0.5]:
			st.set_color(pc); st.set_normal(nrm); st.add_vertex(v)
		for v in [p1 - sd * w, p1 + d * 0.025, p1 + sd * w]:
			st.set_color(pc); st.set_normal(nrm); st.add_vertex(v)
	var cc := Color(1.0, 0.85, 0.3, 0.0)
	for i in 6:
		var a := TAU * i / 6.0
		var b := TAU * (i + 1) / 6.0
		for v in [top + Vector3(0, 0.012, 0), top + Vector3(cos(a), 0.3, sin(a)) * 0.035, top + Vector3(cos(b), 0.3, sin(b)) * 0.035]:
			st.set_color(cc); st.set_normal(Vector3.UP); st.add_vertex(v)
	return st.commit()
