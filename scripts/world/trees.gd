## Procedural blossom trees (cherry / jacaranda / ginkgo look).
class_name TreeGen
extends RefCounted

static func make(seed_v: int, height: float, col_a: Color, col_b: Color, bark_mat: Material, blossom_mat: Material, density := 1.0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var root := Node3D.new()
	root.name = "Tree"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clusters := []
	var lean := Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.15, 0.15)).normalized()
	_branch(st, rng, Vector3.ZERO, lean, height * 0.42, height * 0.05, 0, clusters)
	st.generate_normals()
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.mesh = st.commit()
	trunk.material_override = bark_mat
	root.add_child(trunk)

	# crown centre for coherent shading
	var cc := Vector3.ZERO
	for c in clusters: cc += c[0]
	cc /= maxf(clusters.size(), 1)
	var crown_r := 0.0
	for c in clusters: crown_r = maxf(crown_r, (c[0] - cc).length())
	crown_r = maxf(crown_r, 1.0)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	mm.mesh = q
	var per := int(85 * density)
	mm.instance_count = clusters.size() * per
	var k := 0
	for c in clusters:
		var cp: Vector3 = c[0]
		var cr: float = c[1]
		for i in per:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
			var p := cp + d * cr * pow(rng.randf(), 0.45)
			var sz := rng.randf_range(0.55, 0.95) * height / 6.5
			var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(sz, sz, sz))
			mm.set_instance_transform(k, Transform3D(b, p))
			var t := rng.randf()
			var col := col_a.lerp(col_b, t) * rng.randf_range(0.9, 1.08)
			col.a = 1.0
			mm.set_instance_color(k, col)
			var nrm := ((p - cc) / crown_r + (p - cp) / cr * 0.6).normalized()
			mm.set_instance_custom_data(k, Color(rng.randf(), nrm.x, nrm.y, nrm.z))
			k += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Blossoms"
	mmi.multimesh = mm
	mmi.material_override = blossom_mat
	root.add_child(mmi)
	return root

static func _frame(dir: Vector3) -> Array:
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var a := dir.cross(up).normalized()
	var b := dir.cross(a).normalized()
	return [a, b]

static func _branch(st: SurfaceTool, rng: RandomNumberGenerator, start: Vector3, dir: Vector3, length: float, radius: float, depth: int, clusters: Array) -> void:
	var segs := 4
	var sides := 7
	var p := start
	var d := dir
	var base: int = st.get_meta("vcount", 0)
	var pts := []
	for s in segs + 1:
		pts.append([p, d, radius * lerpf(1.0, 0.62, float(s) / segs)])
		if s < segs:
			d = (d + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.05, 0.15), rng.randf_range(-0.25, 0.25))).normalized()
			p += d * length / segs
	for s in pts.size():
		var c: Vector3 = pts[s][0]
		var fr := _frame(pts[s][1])
		var r: float = pts[s][2]
		for j in sides:
			var a := TAU * j / sides
			st.add_vertex(c + (fr[0] * cos(a) + fr[1] * sin(a)) * r)
	for s in segs:
		for j in sides:
			var a0: int = base + s * sides + j
			var a1: int = base + s * sides + (j + 1) % sides
			st.add_index(a0); st.add_index(a0 + sides); st.add_index(a1)
			st.add_index(a1); st.add_index(a0 + sides); st.add_index(a1 + sides)
	st.set_meta("vcount", base + (segs + 1) * sides)
	var end: Vector3 = pts[segs][0]
	if depth >= 3:
		clusters.append([end, length * rng.randf_range(1.1, 1.5)])
		return
	if depth >= 2 and rng.randf() < 0.5:
		clusters.append([p.lerp(start, 0.4), length * 0.9])
	var kids := 3 if depth == 0 else rng.randi_range(2, 3)
	var spin := rng.randf() * TAU
	for i in kids:
		var az := spin + TAU * i / kids + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(az), 0, sin(az))
		var tilt := rng.randf_range(0.5, 0.95) if depth == 0 else rng.randf_range(0.35, 0.8)
		var nd := (d * (1.0 - tilt) + out * tilt + Vector3(0, 0.25, 0)).normalized()
		_branch(st, rng, end - d * radius * 0.5, nd, length * rng.randf_range(0.6, 0.78), radius * 0.62, depth + 1, clusters)
