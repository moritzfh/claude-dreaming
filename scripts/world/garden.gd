## The garden terrace on top of the plateau: paths, balustrade, flower beds,
## lawn, reflecting pool, the water channel to the waterfall, gazebo and trees.
class_name Garden
extends RefCounted

const Y := Terrain.PLATEAU_Y
const CHANNEL_X := 66.0
const CHANNEL_Z0 := -12.0
const CHANNEL_Z1 := -63.0
const BALU_Z := -53.5

# oriented rects: [center(x,z), half size(x,z), angle(rad)]
static var paths := [
	[Vector2(10.0, -48.0), Vector2(88.0, 4.0), 0.0],          # promenade along the edge
	[Vector2(-10.0, -2.0), Vector2(2.2, 42.0), 0.0],          # main north-south path
	[Vector2(-24.0, 16.0), Vector2(1.8, 22.0), -0.62],        # diagonal path
	[Vector2(20.0, -4.0), Vector2(30.0, 1.8), 0.0],           # east-west path
	[Vector2(52.0, -20.0), Vector2(1.6, 16.0), 0.0],          # path to the pool
]
static var beds := [
	# [center, half size, kind] kind: 0 lavender, 1 mixed, 2 purple/blue tall
	[Vector2(12.0, -37.0), Vector2(9.0, 4.0), 0],
	[Vector2(-38.0, -38.0), Vector2(22.0, 2.6), 0],
	[Vector2(-28.0, -19.0), Vector2(11.0, 7.0), 1],
	[Vector2(25.0, -14.0), Vector2(13.0, 4.5), 1],
	[Vector2(-28.0, -4.0), Vector2(11.0, 2.2), 2],
	[Vector2(3.0, 14.0), Vector2(7.0, 5.0), 1],
	[Vector2(34.0, 8.0), Vector2(8.0, 3.0), 0],
]
static var pool := [Vector2(36.0, -33.0), Vector2(10.0, 6.5)]
static var gazebo := Vector2(-70.0, -40.0)

static func _in_rect(p: Vector2, r: Array, pad := 0.0) -> bool:
	var c: Vector2 = r[0]
	var hs: Vector2 = r[1]
	var ang: float = r[2] if r.size() > 2 and r[2] is float else 0.0
	var q := (p - c).rotated(-ang)
	return absf(q.x) <= hs.x + pad and absf(q.y) <= hs.y + pad

static func is_lawn(p: Vector2) -> bool:
	if p.x < -88 or p.x > 100 or p.y < -52 or p.y > 48: return false
	for r in paths:
		if _in_rect(p, r, 0.15): return false
	for b in beds:
		if _in_rect(p, [b[0], b[1], 0.0], 0.3): return false
	if _in_rect(p, [pool[0], pool[1], 0.0], 0.8): return false
	if absf(p.x - CHANNEL_X) < 2.4 and p.y < CHANNEL_Z0 + 3.5: return false
	if p.distance_to(gazebo) < 5.0: return false
	return true

static func build(parent: Node3D, m: Dictionary) -> void:
	var g := Node3D.new()
	g.name = "Garden"
	parent.add_child(g)
	_build_paths(g, m)
	_build_balustrade(g, m)
	_build_beds(g, m)
	_build_pool(g, m)
	_build_channel(g, m)
	_build_gazebo(g, m)
	_build_trees(g, m)
	_build_grass(g, m)

# ------------------------------------------------------------------ helpers
static func _box(parent: Node3D, nm: String, center: Vector3, size: Vector3, mat: Material, yaw := 0.0, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(size), center)
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = size
		cs.shape = sh
		sb.transform = Transform3D(Basis(Vector3.UP, yaw), center)
		sb.add_child(cs)
		parent.add_child(sb)
	return mi

static func _mm(parent: Node3D, nm: String, mesh: Mesh, xf: Array, cols: Array, custom: Array, mat: Material, vis_end := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = cols.size() > 0
	mm.use_custom_data = custom.size() > 0
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if mm.use_colors: mm.set_instance_color(i, cols[i])
		if mm.use_custom_data: mm.set_instance_custom_data(i, custom[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.material_override = mat
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_end_margin = vis_end * 0.2
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mmi)
	return mmi

# ------------------------------------------------------------------ paths
static func _build_paths(g: Node3D, m: Dictionary) -> void:
	for r in paths:
		var c: Vector2 = r[0]
		var hs: Vector2 = r[1]
		if r == paths[0]:
			# promenade is split by the channel
			var left := Vector2(c.x - hs.x, CHANNEL_X - 2.2)
			var right := Vector2(CHANNEL_X + 2.2, c.x + hs.x)
			_box(g, "Promenade", Vector3((left.x + left.y) * 0.5, Y - 0.1, c.y), Vector3(left.y - left.x, 0.3, hs.y * 2.0), m.tiles)
			_box(g, "Promenade", Vector3((right.x + right.y) * 0.5, Y - 0.1, c.y), Vector3(right.y - right.x, 0.3, hs.y * 2.0), m.tiles)
		else:
			_box(g, "Path", Vector3(c.x, Y - 0.11, c.y), Vector3(hs.x * 2.0, 0.3, hs.y * 2.0), m.tiles, -r[2])

# ------------------------------------------------------------------ balustrade
static func _baluster_mesh() -> ArrayMesh:
	var prof := [[0.0, 0.07], [0.05, 0.07], [0.09, 0.045], [0.2, 0.04], [0.33, 0.075], [0.45, 0.04], [0.56, 0.035], [0.62, 0.06], [0.66, 0.06], [0.66, 0.0]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 10
	for i in prof.size():
		for j in sides:
			var a := TAU * j / sides
			st.add_vertex(Vector3(cos(a) * prof[i][1], prof[i][0], sin(a) * prof[i][1]))
	for i in prof.size() - 1:
		for j in sides:
			var a0 := i * sides + j
			var a1 := i * sides + (j + 1) % sides
			st.add_index(a0); st.add_index(a0 + sides); st.add_index(a1)
			st.add_index(a1); st.add_index(a0 + sides); st.add_index(a1 + sides)
	st.generate_normals()
	return st.commit()

static func _build_balustrade(g: Node3D, m: Dictionary) -> void:
	var segs := [[-80.0, CHANNEL_X - 2.6], [CHANNEL_X + 2.6, 100.0]]
	var xf := []
	for s in segs:
		var x0: float = s[0]
		var x1: float = s[1]
		var len := x1 - x0
		var cx := (x0 + x1) * 0.5
		_box(g, "BaluBase", Vector3(cx, Y + 0.12, BALU_Z), Vector3(len, 0.24, 0.5), m.stone)
		_box(g, "BaluRail", Vector3(cx, Y + 0.98, BALU_Z), Vector3(len, 0.14, 0.42), m.stone, 0.0, false)
		# invisible wall so the player can't just walk off (except over the channel)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(len, 2.0, 0.5); cs.shape = sh
		sb.position = Vector3(cx, Y + 1.0, BALU_Z); sb.add_child(cs); g.add_child(sb)
		var x := x0 + 0.3
		var k := 0
		while x < x1 - 0.2:
			if k % 22 == 0:
				_box(g, "BaluPost", Vector3(x, Y + 0.6, BALU_Z), Vector3(0.5, 1.2, 0.55), m.stone, 0.0, false)
			else:
				xf.append(Transform3D(Basis(), Vector3(x, Y + 0.24, BALU_Z)))
			x += 0.27
			k += 1
	_mm(g, "Balusters", _baluster_mesh(), xf, [], [], m.stone)

# ------------------------------------------------------------------ beds + flowers
static func _build_beds(g: Node3D, m: Dictionary) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 99
	var lav_xf := []; var lav_c := []; var lav_cu := []
	var fl_xf := []; var fl_c := []; var fl_cu := []
	var bush_xf := []; var bush_cu := []
	var mixed := [Color(1.0, 0.55, 0.72), Color(1.0, 0.95, 0.95), Color(0.95, 0.25, 0.22), Color(1.0, 0.82, 0.25), Color(0.75, 0.45, 0.95), Color(1.0, 0.68, 0.80), Color(0.98, 0.98, 0.9)]
	for b in beds:
		var c: Vector2 = b[0]
		var hs: Vector2 = b[1]
		var kind: int = b[2]
		# stone curb + dark soil
		var cw := 0.3
		_box(g, "Curb", Vector3(c.x, Y + 0.18, c.y - hs.y - cw * 0.5), Vector3(hs.x * 2.0 + cw * 2.0, 0.36, cw), m.stone, 0.0, false)
		_box(g, "Curb", Vector3(c.x, Y + 0.18, c.y + hs.y + cw * 0.5), Vector3(hs.x * 2.0 + cw * 2.0, 0.36, cw), m.stone, 0.0, false)
		_box(g, "Curb", Vector3(c.x - hs.x - cw * 0.5, Y + 0.18, c.y), Vector3(cw, 0.36, hs.y * 2.0), m.stone, 0.0, false)
		_box(g, "Curb", Vector3(c.x + hs.x + cw * 0.5, Y + 0.18, c.y), Vector3(cw, 0.36, hs.y * 2.0), m.stone, 0.0, false)
		_box(g, "Soil", Vector3(c.x, Y + 0.08, c.y), Vector3(hs.x * 2.0, 0.2, hs.y * 2.0), m.soil, 0.0, false)
		var area := hs.x * hs.y * 4.0
		if kind == 0 or kind == 2:
			# lavender bushes in rows
			var row := 0.0
			var zz := c.y - hs.y + 0.5
			while zz < c.y + hs.y - 0.3:
				var xx := c.x - hs.x + 0.45 + fmod(row, 2.0) * 0.4
				while xx < c.x + hs.x - 0.3:
					var spikes := rng.randi_range(14, 22)
					var bh := rng.randf_range(0.55, 0.8) * (1.25 if kind == 2 else 1.0)
					for s in spikes:
						var o := Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
						var lean := Vector3(o.x, 0, o.y) * 0.6
						var hgt := bh * rng.randf_range(0.75, 1.1)
						var bs := Basis.looking_at(Vector3(0, 0, 1), (Vector3.UP + lean).normalized()).rotated(Vector3.UP, rng.randf() * TAU)
						bs = bs.scaled(Vector3(hgt * 0.32, hgt, 1.0))
						lav_xf.append(Transform3D(bs, Vector3(xx + o.x, Y + 0.18 + hgt * 0.5, zz + o.y)))
						var lc := Color(0.42, 0.28, 0.82) if kind == 0 else Color(0.30, 0.32, 0.90)
						lav_c.append(lc.lerp(Color(0.62, 0.45, 0.95), rng.randf() * 0.45))
						lav_cu.append(Color(rng.randf(), 0, 0, 0))
					bush_xf.append(Transform3D(Basis().scaled(Vector3(1.3, 0.9, 1.3)), Vector3(xx, Y + 0.15, zz)))
					bush_cu.append(Color(rng.randf(), 0, 0, 0))
					xx += 0.8
				zz += 0.75
				row += 1.0
		else:
			var n := int(area * 22.0)
			for i in n:
				var p := Vector2(rng.randf_range(-hs.x + 0.2, hs.x - 0.2), rng.randf_range(-hs.y + 0.2, hs.y - 0.2)) + c
				var hgt := rng.randf_range(0.35, 0.7)
				var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(hgt * 0.75, hgt, 1.0))
				fl_xf.append(Transform3D(bs, Vector3(p.x, Y + 0.18 + hgt * 0.5, p.y)))
				fl_c.append(mixed[rng.randi() % mixed.size()] * rng.randf_range(0.85, 1.05))
				fl_cu.append(Color(rng.randf(), 0, 0, 0))
			var nb := int(area * 1.6)
			for i in nb:
				var p := Vector2(rng.randf_range(-hs.x, hs.x), rng.randf_range(-hs.y, hs.y)) + c
				bush_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.2, 0.8, 1.2)), Vector3(p.x, Y + 0.15, p.y)))
				bush_cu.append(Color(rng.randf(), 0, 0, 0))
	# wild flowers sprinkled through the lawn
	var wild := [Color(1.0, 0.86, 0.3), Color(1.0, 1.0, 0.95), Color(1.0, 0.6, 0.35), Color(0.95, 0.6, 0.85)]
	for i in 2600:
		var p := Vector2(rng.randf_range(-88, 100), rng.randf_range(-52, 48))
		if not is_lawn(p): continue
		var hgt := rng.randf_range(0.18, 0.32)
		fl_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(hgt * 0.75, hgt, 1.0)), Vector3(p.x, Terrain.height(p.x, p.y) + hgt * 0.5, p.y)))
		fl_c.append(wild[rng.randi() % wild.size()])
		fl_cu.append(Color(rng.randf(), 0, 0, 0))
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	_mm(g, "Lavender", q, lav_xf, lav_c, lav_cu, m.lavender, 140.0)
	_mm(g, "Flowers", q, fl_xf, fl_c, fl_cu, m.flower, 120.0)
	_mm(g, "BedFoliage", m.grass_mesh, bush_xf, [], bush_cu, m.foliage, 140.0)

# ------------------------------------------------------------------ pool
static func _build_pool(g: Node3D, m: Dictionary) -> void:
	var c: Vector2 = pool[0]
	var hs: Vector2 = pool[1]
	var rim := 0.6
	var h := 0.55
	_box(g, "PoolRim", Vector3(c.x, Y + h * 0.5, c.y - hs.y - rim * 0.5), Vector3(hs.x * 2.0 + rim * 2.0, h, rim), m.stone)
	_box(g, "PoolRim", Vector3(c.x, Y + h * 0.5, c.y + hs.y + rim * 0.5), Vector3(hs.x * 2.0 + rim * 2.0, h, rim), m.stone)
	_box(g, "PoolRim", Vector3(c.x - hs.x - rim * 0.5, Y + h * 0.5, c.y), Vector3(rim, h, hs.y * 2.0), m.stone)
	_box(g, "PoolRim", Vector3(c.x + hs.x + rim * 0.5, Y + h * 0.5, c.y), Vector3(rim, h, hs.y * 2.0), m.stone)
	var w := MeshInstance3D.new()
	w.name = "PoolWater"
	var pm := PlaneMesh.new(); pm.size = hs * 2.0
	w.mesh = pm
	w.material_override = m.pool_water
	w.position = Vector3(c.x, Y + h - 0.12, c.y)
	g.add_child(w)

# ------------------------------------------------------------------ channel + waterfall
static func _build_channel(g: Node3D, m: Dictionary) -> void:
	var inner := 1.3      # half width of water
	var wall := 0.9
	var top := Y + 0.42   # top of the masonry
	var walk := Y + 0.68  # top of the crenellation blocks = running surface
	var bottom := Y - 4.5
	var len := CHANNEL_Z0 - CHANNEL_Z1
	var cz := (CHANNEL_Z0 + CHANNEL_Z1) * 0.5
	for side in [-1.0, 1.0]:
		var wx: float = CHANNEL_X + side * (inner + wall * 0.5)
		_box(g, "ChannelWall", Vector3(wx, (top + bottom) * 0.5, cz), Vector3(wall, top - bottom, len), m.stone, 0.0, false)
		# crenellation blocks on top: visual only
		var z := CHANNEL_Z0 - 0.6
		while z > CHANNEL_Z1 + 0.5:
			_box(g, "ChannelBlock", Vector3(wx, (top + walk) * 0.5, z), Vector3(wall + 0.06, walk - top, 1.4), m.stone, 0.0, false)
			z -= 1.75
		# one smooth collider for wall + blocks, so nothing snags while running
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
		sh.size = Vector3(wall + 0.06, walk - bottom, len)
		cs.shape = sh
		sb.position = Vector3(wx, (walk + bottom) * 0.5, cz)
		sb.add_child(cs)
		g.add_child(sb)
		# ramp up onto the wall at the garden end
		var rise := walk - Y
		var rlen := 2.2
		var ang := atan2(rise, rlen)
		var hyp := sqrt(rise * rise + rlen * rlen)
		var ramp := _box(g, "ChannelRamp", Vector3(wx, Y + rise * 0.5 - 0.12, CHANNEL_Z0 + rlen * 0.5), Vector3(wall + 0.06, 0.25, hyp), m.stone, 0.0, false)
		ramp.rotation.x = ang
		var rsb := StaticBody3D.new(); var rcs := CollisionShape3D.new(); var rsh := BoxShape3D.new()
		rsh.size = Vector3(wall + 0.06, 0.25, hyp); rcs.shape = rsh
		rsb.position = ramp.position; rsb.rotation.x = ang
		rsb.add_child(rcs); g.add_child(rsb)
	_box(g, "ChannelEnd", Vector3(CHANNEL_X, (Y + top) * 0.5, CHANNEL_Z0 + 0.45), Vector3(inner * 2.0, top - Y + 0.01, 0.9), m.stone)
	_box(g, "ChannelBed", Vector3(CHANNEL_X, Y - 0.35, cz), Vector3(inner * 2.0, 0.6, len), m.soil)
	var w := MeshInstance3D.new()
	w.name = "ChannelWater"
	var pm := PlaneMesh.new(); pm.size = Vector2(inner * 2.0, len)
	w.mesh = pm
	w.material_override = m.channel_water
	w.position = Vector3(CHANNEL_X, Y + 0.18, cz)
	g.add_child(w)
	# the waterfall off the plateau edge
	Landmarks.build_waterfall(g, Vector3(CHANNEL_X, Y + 0.18, CHANNEL_Z1), Vector3(CHANNEL_X - 0.5, Terrain.WATER_Y, CHANNEL_Z1 - 9.0), inner * 2.0, 4.0, m.fall, m.mist, 0.6)

# ------------------------------------------------------------------ gazebo
static func _build_gazebo(g: Node3D, m: Dictionary) -> void:
	var gz := Node3D.new()
	gz.name = "Gazebo"
	gz.position = Vector3(gazebo.x, Y, gazebo.y)
	g.add_child(gz)
	var base := MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 4.6; cy.bottom_radius = 4.8; cy.height = 0.5
	base.mesh = cy; base.position.y = 0.25; base.material_override = m.stone
	gz.add_child(base)
	for i in 8:
		var a := TAU * i / 8.0
		var col := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.22; cm.bottom_radius = 0.26; cm.height = 3.4
		col.mesh = cm; col.material_override = m.stone
		col.position = Vector3(cos(a) * 3.9, 0.5 + 1.7, sin(a) * 3.9)
		gz.add_child(col)
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new(); rm.top_radius = 4.5; rm.bottom_radius = 4.5; rm.height = 0.5
	ring.mesh = rm; ring.position.y = 4.15; ring.material_override = m.stone
	gz.add_child(ring)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new(); dm.radius = 4.3; dm.height = 4.3; dm.is_hemisphere = true
	dome.mesh = dm; dome.position.y = 4.4; dome.material_override = m.stone
	dome.scale = Vector3(1, 0.7, 1)
	gz.add_child(dome)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new()
	sh.radius = 4.8; sh.height = 0.5; cs.shape = sh; sb.position.y = 0.25; sb.add_child(cs); gz.add_child(sb)

# ------------------------------------------------------------------ trees
static func _build_trees(g: Node3D, m: Dictionary) -> void:
	var pink_a := Color(1.0, 0.70, 0.82); var pink_b := Color(0.92, 0.50, 0.68)
	var lil_a := Color(0.78, 0.66, 1.0); var lil_b := Color(0.60, 0.48, 0.92)
	var gold_a := Color(1.0, 0.84, 0.32); var gold_b := Color(0.95, 0.66, 0.18)
	var defs := [
		[Vector2(-44, -24), 7.5, pink_a, pink_b, 11],
		[Vector2(24, 18), 6.0, pink_a, pink_b, 12],
		[Vector2(-30, 28), 5.5, pink_a, pink_b, 13],
		[Vector2(-56, -47), 6.8, lil_a, lil_b, 14],
		[Vector2(-80, -18), 6.0, lil_a, lil_b, 15],
		[Vector2(58, -36), 6.5, gold_a, gold_b, 16],
		[Vector2(80, 10), 6.0, pink_a, pink_b, 17],
		[Vector2(-62, 20), 6.5, lil_a, lil_b, 18],
	]
	for d in defs:
		var t := TreeGen.make(d[4], d[1], d[2], d[3], m.bark, m.blossom)
		var p: Vector2 = d[0]
		t.position = Vector3(p.x, Terrain.height(p.x, p.y) - 0.1, p.y)
		t.rotation.y = d[4] * 0.9
		g.add_child(t)
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new()
		sh.radius = 0.35; sh.height = 4.0; cs.shape = sh; sb.position = t.position + Vector3(0, 2, 0); sb.add_child(cs); g.add_child(sb)

# ------------------------------------------------------------------ grass
static func grass_clump_mesh(blades := 16, radius := 0.3, seed_v := 5) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vi := 0
	for b in blades:
		var ang := rng.randf() * TAU
		var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * radius
		var hgt := rng.randf_range(0.16, 0.36)
		var wid := rng.randf_range(0.06, 0.11)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var bend := rng.randf_range(0.1, 0.28)
		var segs := 2
		for s in segs + 1:
			var t := float(s) / segs
			var c := off + dir * bend * t * t + Vector3.UP * hgt * t
			var w := wid * (1.0 - t * t * 0.95)
			var n := (dir + Vector3.UP * 0.6).normalized()
			st.set_normal(n); st.set_uv(Vector2(0, t)); st.add_vertex(c - side * w)
			st.set_normal(n); st.set_uv(Vector2(1, t)); st.add_vertex(c + side * w)
		for s in segs:
			var a := vi + s * 2
			st.add_index(a); st.add_index(a + 2); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(a + 2); st.add_index(a + 3)
		vi += (segs + 1) * 2
	return st.commit()

static func _build_grass(g: Node3D, m: Dictionary) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 2024
	var chunk := 24.0
	var x0 := -88.0; var x1 := 100.0; var z0 := -52.0; var z1 := 48.0
	var density := 2.6
	var cx := x0
	while cx < x1:
		var cz := z0
		while cz < z1:
			var xf := []; var cu := []
			var n := int(chunk * chunk * density)
			for i in n:
				var p := Vector2(cx + rng.randf() * chunk, cz + rng.randf() * chunk)
				if p.x > x1 or p.y > z1 or not is_lawn(p): continue
				var s := rng.randf_range(0.8, 1.35)
				xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s)), Vector3(p.x, Terrain.height(p.x, p.y) - 0.02, p.y)))
				cu.append(Color(rng.randf(), 0, 0, 0))
			if xf.size() > 0:
				var mmi := _mm(g, "Grass", m.grass_mesh, xf, [], cu, m.grass, 70.0)
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cz += chunk
		cx += chunk
