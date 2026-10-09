## Building kit for the story planet: stuffed felt blocks of any size,
## cardboard cut-outs (painted or plain), sewing buttons, pins with flags,
## cotton clouds, labels. Everything static – plain functions.
extends RefCounted

const BLOCK_SHADER := preload("res://levels/plush_desk/shaders/felt_block.gdshader")
const CARD_SHADER := preload("res://levels/plush_desk/shaders/cardboard.gdshader")
const FABRIC := preload("res://levels/plush_desk/shaders/fabric.gdshader")
const FUZZ := preload("res://levels/plush_desk/shaders/fuzz.gdshader")
const T_FELT := preload("res://levels/plush_desk/textures/felt.png")
const T_KNIT := preload("res://levels/plush_desk/textures/knit.png")
const T_WEAVE := preload("res://levels/plush_desk/textures/weave.png")
const T_MOTTLE := preload("res://levels/plush_desk/textures/mottle.png")
const T_KRAFT := preload("res://levels/plush_desk/textures/kraft.png")
const FONT := preload("res://levels/plush_desk/fonts/Fredoka-Bold.woff2")
const BLOCK_SCENE := preload("res://levels/plush_desk/models/block.glb")

# a few colours that go together (felt)
const CREAM := Color(0.95, 0.88, 0.74)
const CORAL := Color(0.88, 0.45, 0.38)
const MUSTARD := Color(0.93, 0.7, 0.32)
const TEAL := Color(0.32, 0.6, 0.62)
const LILAC := Color(0.62, 0.5, 0.75)
const GRASS := Color(0.52, 0.72, 0.36)
const SOIL := Color(0.62, 0.42, 0.3)
const SKY := Color(0.55, 0.75, 0.92)
const PINK := Color(0.95, 0.62, 0.68)
const NAVY := Color(0.2, 0.22, 0.42)

static var _block_mesh: Mesh
static var _block_mat: ShaderMaterial
static var _mats := {}

static func block_mesh() -> Mesh:
	if _block_mesh == null:
		var inst := BLOCK_SCENE.instantiate()
		_block_mesh = (inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		inst.free()
	return _block_mesh

static func block_material() -> ShaderMaterial:
	if _block_mat == null:
		_block_mat = ShaderMaterial.new()
		_block_mat.shader = BLOCK_SHADER
		_block_mat.set_shader_parameter("fibre_tex", T_FELT)
		_block_mat.set_shader_parameter("mottle_tex", T_MOTTLE)
		_block_mat.set_shader_parameter("fibre_scale", 2.4)
		_block_mat.set_shader_parameter("fibre_strength", 1.2)
		_block_mat.set_shader_parameter("sheen", 0.9)
		_block_mat.set_shader_parameter("sheen_color", Color(1.0, 0.95, 0.88))
	return _block_mat

## A stuffed felt block centred at `center`. pattern: 0 felt, 1 gingham,
## 2 dots, 3 stripes, 4 grass top on soil, 5 flower print, 6 sponge.
static func block(parent: Node3D, center: Vector3, size: Vector3, tint: Color, tint2 := CREAM,
		pattern := 0, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = block_mesh()
	mi.material_override = block_material()
	mi.position = center
	mi.set_instance_shader_parameter("size", size)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("tint2", tint2)
	mi.set_instance_shader_parameter("pattern", float(pattern))
	mi.custom_aabb = AABB(-size * 0.5 - Vector3.ONE * 0.2, size + Vector3.ONE * 0.4)
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.position = center
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		parent.add_child(body)
		mi.set_meta("body", body)
	return mi

## a block that moves (an AnimatableBody3D carries mesh and collision)
static func moving_block(parent: Node3D, center: Vector3, size: Vector3, tint: Color, tint2 := CREAM, pattern := 0) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.position = center
	body.sync_to_physics = true
	parent.add_child(body)
	block(body, Vector3.ZERO, size, tint, tint2, pattern, false)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	return body

static func fabric(col: Color, tex: Texture2D = T_FELT, sc := 2.4, strength := 1.0) -> ShaderMaterial:
	var key := "%s|%s|%.2f|%.2f" % [col.to_html(), tex.resource_path, sc, strength]
	if _mats.has(key):
		return _mats[key]
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
	_mats[key] = m
	return m

static func card_material(kind: int, paint := Color(1, 1, 1, 0)) -> ShaderMaterial:
	var key := "card|%d|%s" % [kind, paint.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = CARD_SHADER
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("kraft_tex", T_KRAFT)
	m.set_shader_parameter("mottle_tex", T_MOTTLE)
	m.set_shader_parameter("paint", paint)
	_mats[key] = m
	return m

## A flat piece of corrugated board cut to `poly` (metres, in the XY plane,
## any winding), `thick` deep along Z. Surface 0 = the board, 1 = the cut edge.
static func slab_mesh(poly: PackedVector2Array, thick: float) -> ArrayMesh:
	var pts := poly
	if Geometry2D.is_polygon_clockwise(pts):
		pts = pts.duplicate()
		pts.reverse()
	var tris := Geometry2D.triangulate_polygon(pts)
	var mesh := ArrayMesh.new()
	var hz := thick * 0.5
	# faces
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		var n := Vector3(0, 0, side)
		for i in range(0, tris.size(), 3):
			var idx := [tris[i], tris[i + 1], tris[i + 2]]
			if side > 0.0:
				idx = [tris[i], tris[i + 2], tris[i + 1]]
			for j in idx:
				var p: Vector2 = pts[j]
				st.set_normal(n)
				st.set_uv(p)
				st.add_vertex(Vector3(p.x, p.y, hz * side))
	st.generate_tangents()
	st.commit(mesh)
	# cut edge
	var se := SurfaceTool.new()
	se.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc := 0.0
	var n_pts := pts.size()
	for i in n_pts:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n_pts]
		var seg := a.distance_to(b)
		var d := (b - a).normalized()
		var nn := Vector3(d.y, -d.x, 0.0)
		var q := [[Vector3(a.x, a.y, hz), Vector2(acc, 0.0)], [Vector3(b.x, b.y, hz), Vector2(acc + seg, 0.0)],
			[Vector3(b.x, b.y, -hz), Vector2(acc + seg, 1.0)], [Vector3(a.x, a.y, -hz), Vector2(acc, 1.0)]]
		for k in [0, 2, 1, 0, 3, 2]:
			var e: Array = q[k]
			se.set_normal(nn)
			se.set_uv(e[1])
			se.add_vertex(e[0])
		acc += seg
	se.generate_tangents()
	se.commit(mesh)
	return mesh

## A cardboard cut-out; `paint` colours the board (alpha = coverage).
static func cutout(parent: Node3D, poly: PackedVector2Array, thick: float, xf: Transform3D,
		paint := Color(1, 1, 1, 0), collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = slab_mesh(poly, thick)
	mi.set_surface_override_material(0, card_material(0, paint))
	mi.set_surface_override_material(1, card_material(1))
	mi.transform = xf
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.transform = xf
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for p in poly:
			pts.append(Vector3(p.x, p.y, thick * 0.5))
			pts.append(Vector3(p.x, p.y, -thick * 0.5))
		sh.points = pts
		cs.shape = sh
		body.add_child(cs)
		parent.add_child(body)
	return mi

## a flat felt shape (hills, leaves, letters): the cut-out mesh in fabric
static func felt_cutout(parent: Node3D, poly: PackedVector2Array, thick: float, xf: Transform3D, col: Color,
		sc := 1.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = slab_mesh(poly, thick)
	var m := fabric(col, T_FELT, sc, 1.2)
	mi.set_surface_override_material(0, m)
	mi.set_surface_override_material(1, fabric(col.darkened(0.12), T_FELT, sc * 2.0, 1.0))
	mi.transform = xf
	parent.add_child(mi)
	return mi

## rolling hills: a long wavy band from x0 to x1 with its top at about `top`
static func hills(x0: float, x1: float, base: float, top: float, amp: float, wl: float, seed: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(Vector2(x0, base))
	var n := int((x1 - x0) / 1.5)
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var y := top + amp * (0.6 * sin(x / wl + seed) + 0.4 * sin(x / (wl * 0.43) + seed * 1.7))
		out.append(Vector2(x, y))
	out.append(Vector2(x1, base))
	return out

## a felt flower on a stem; pivot at the bottom
static func flower(parent: Node3D, pos: Vector3, s: float, col: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	block(n, Vector3(0, s * 0.5, 0), Vector3(0.05, s, 0.05), GRASS.darkened(0.25), CREAM, 0, false)
	var petals := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		var r := s * (0.32 + 0.12 * cos(a * 5.0))
		petals.append(Vector2(cos(a) * r, sin(a) * r + s))
	felt_cutout(n, petals, 0.05, Transform3D(), col, 3.0)
	felt_cutout(n, circle(s * 0.11, 12, 0, s), 0.05, Transform3D(Basis(), Vector3(0, 0, 0.035)), Color(1.0, 0.85, 0.42), 3.0)
	var leaf := PackedVector2Array([Vector2(0, 0), Vector2(s * 0.25, s * 0.12), Vector2(s * 0.3, s * 0.28), Vector2(s * 0.05, s * 0.18)])
	felt_cutout(n, leaf, 0.03, Transform3D(Basis(), Vector3(0.02, s * 0.3, 0)), GRASS, 3.0)
	return n

## a round felt bush standing up (decoration)
static func bush(parent: Node3D, pos: Vector3, r: float, col: Color, seed := 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	felt_cutout(n, blob(r, 26, 0.13, seed, true), 0.35, Transform3D(Basis(), Vector3(0, r * 0.7, 0)), col, 1.4)
	felt_cutout(n, blob(r * 0.6, 20, 0.15, seed + 2.0, true), 0.2, Transform3D(Basis(), Vector3(r * 0.35, r * 0.9, 0.2)), col.lightened(0.12), 1.4)
	return n

## a felt fan blowing straight up (cardboard blades turn); returns the blades
static func fan(parent: Node3D, pos: Vector3, r: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	block(n, Vector3(0, 0.25, 0), Vector3(r * 2.2, 0.5, 1.1), TEAL, CREAM, 3, true)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = r * 0.92; tm.outer_radius = r * 1.08; tm.rings = 32; tm.ring_segments = 8
	ring.mesh = tm
	ring.position.y = 0.55
	ring.material_override = fabric(MUSTARD, T_KNIT, 6.0, 1.0)
	n.add_child(ring)
	var blades := Node3D.new()
	blades.name = "Blades"
	blades.position.y = 0.6
	n.add_child(blades)
	for i in 4:
		var bl := PackedVector2Array([Vector2(0.05, -0.12), Vector2(r * 0.9, -0.2), Vector2(r * 0.95, 0.12), Vector2(0.05, 0.1)])
		var xf := Transform3D(Basis(Vector3.UP, i * PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.RIGHT, 0.35), Vector3.ZERO)
		cutout(blades, bl, 0.04, xf, Color(0.95, 0.88, 0.74, 1.0))
	return blades

static func circle(r: float, n := 24, cx := 0.0, cy := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return out

static func rect(w: float, h: float, cx := 0.0, cy := 0.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - w * 0.5, cy - h * 0.5), Vector2(cx + w * 0.5, cy - h * 0.5),
		Vector2(cx + w * 0.5, cy + h * 0.5), Vector2(cx - w * 0.5, cy + h * 0.5)])

## wobbly round shape (bushes, hills, clouds) – r varies with a few sines
static func blob(r: float, n := 28, wob := 0.12, seed := 1.0, flat_bottom := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var rr := r * (1.0 + wob * sin(a * 3.0 + seed) + wob * 0.6 * sin(a * 5.0 + seed * 2.3))
		var p := Vector2(cos(a) * rr, sin(a) * rr)
		if flat_bottom:
			p.y = maxf(p.y, -r * 0.15)
		out.append(p)
	return out

## a big sewing button lying flat (top up), standable
static func button(parent: Node3D, pos: Vector3, r: float, col: Color, rot := 0.0, collide := true) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = Vector3(0.0, rot, 0.0)
	parent.add_child(n)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.3
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.7
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.97; cm.bottom_radius = r; cm.height = r * 0.24; cm.radial_segments = 40
	body.mesh = cm
	body.position.y = r * 0.12
	body.material_override = mat
	n.add_child(body)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.8; tm.outer_radius = r * 0.98; tm.rings = 40; tm.ring_segments = 10
	rim.mesh = tm
	rim.scale = Vector3(1, 0.6, 1)
	rim.position.y = r * 0.24
	rim.material_override = mat
	n.add_child(rim)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = col.darkened(0.65)
	for i in 4:
		var h := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = r * 0.08; hm.bottom_radius = r * 0.08; hm.height = 0.02; hm.radial_segments = 12
		h.mesh = hm
		h.position = Vector3(cos(i * PI * 0.5 + 0.785) * r * 0.24, r * 0.245, sin(i * PI * 0.5 + 0.785) * r * 0.24)
		h.material_override = dark
		n.add_child(h)
	# thread crossing the holes
	var thr := StandardMaterial3D.new()
	thr.albedo_color = CREAM
	thr.roughness = 0.9
	for k in 2:
		var t := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r * 0.62, 0.025, 0.035)
		t.mesh = bm
		t.position.y = r * 0.255
		t.rotation.y = 0.785 + k * PI * 0.5
		t.material_override = thr
		n.add_child(t)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new(); cy.radius = r; cy.height = r * 0.26
		cs.shape = cy
		cs.position.y = r * 0.13
		sb.add_child(cs)
		n.add_child(sb)
	return n

## a sewing button standing on its edge (a wheel / a sign)
static func button_upright(parent: Node3D, pos: Vector3, r: float, col: Color) -> Node3D:
	var n := button(parent, Vector3.ZERO, r, col, 0.0, false)
	n.position = pos
	n.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	return n

static func label(parent: Node3D, text: String, pos: Vector3, px := 0.006, col := Color(0.3, 0.2, 0.32), size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	parent.add_child(l)
	return l

## a big dressmaker's pin with a felt flag: the checkpoint
static func pin(parent: Node3D, pos: Vector3, head_col: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.84, 0.88); steel.metallic = 1.0; steel.roughness = 0.22
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new(); sm.top_radius = 0.035; sm.bottom_radius = 0.01; sm.height = 2.3
	shaft.mesh = sm
	shaft.position.y = 1.0
	shaft.material_override = steel
	n.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = 0.2; hm.height = 0.4
	head.mesh = hm
	head.position.y = 2.18
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = head_col; hmat.roughness = 0.18; hmat.clearcoat_enabled = true
	head.material_override = hmat
	n.add_child(head)
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0.0, 1.95, 0.0)
	n.add_child(flag)
	var fl := block(flag, Vector3(0.38, -0.2, 0.0), Vector3(0.7, 0.42, 0.06), head_col, CREAM, 0, false)
	fl.name = "Cloth"
	n.set_meta("head_mat", hmat)
	return n

## cotton wool cloud: puffs of cotton (fuzzy), a flat top to stand on
static func cloud(parent: Node3D, pos: Vector3, w: float, collide := true) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var mat := ShaderMaterial.new()
	mat.shader = FABRIC
	mat.set_shader_parameter("albedo", Color(0.98, 0.97, 0.95))
	mat.set_shader_parameter("fibre_tex", T_FELT)
	mat.set_shader_parameter("mottle_tex", T_MOTTLE)
	mat.set_shader_parameter("fibre_scale", 4.0)
	mat.set_shader_parameter("fibre_strength", 1.6)
	mat.set_shader_parameter("sheen", 1.2)
	mat.set_shader_parameter("sheen_color", Color(1, 1, 1))
	mat.set_shader_parameter("stitches", 0.0)
	mat.set_shader_parameter("use_vertex_seam", 0.0)
	mat.set_shader_parameter("translucency", 0.35)
	var prev: Material = mat
	for i in 3:
		var f := ShaderMaterial.new()
		f.shader = FUZZ
		f.set_shader_parameter("albedo", Color(0.98, 0.97, 0.95))
		f.set_shader_parameter("fibre_tex", T_FELT)
		f.set_shader_parameter("mottle_tex", T_MOTTLE)
		f.set_shader_parameter("shell", float(i + 1) / 3.0)
		f.set_shader_parameter("fuzz_len", 0.12)
		f.set_shader_parameter("density", 2.5)
		prev.next_pass = f
		prev = f
	var count := int(clampf(w / 0.7, 2.0, 9.0))
	for i in count:
		var t := (float(i) + 0.5) / count
		var r := 0.45 + 0.3 * sin(t * PI) + 0.08 * sin(i * 2.7)
		var s := MeshInstance3D.new()
		var sp := SphereMesh.new(); sp.radius = r; sp.height = r * 1.6; sp.radial_segments = 24; sp.rings = 12
		s.mesh = sp
		s.material_override = mat
		s.position = Vector3((t - 0.5) * w, 0.0 + 0.1 * sin(i * 1.9), 0.25 * sin(i * 2.3))
		n.add_child(s)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = Vector3(w, 0.5, 1.4)
		cs.shape = bs
		cs.position.y = 0.2
		sb.add_child(cs)
		n.add_child(sb)
	return n

## a trim sewn along the top of a block's front face (x0..x1, at height top,
## in front of z): "pinking" (zigzag, like cut with pinking shears),
## "scallop" (a lace edge) or "ricrac" (a wavy braid)
static func trim(parent: Node3D, x0: float, x1: float, top: float, z: float, col: Color, style := "pinking") -> void:
	var x := x0
	while x < x1 - 0.05:
		var xe := minf(x + 8.0, x1)
		var poly := PackedVector2Array()
		match style:
			"pinking":
				poly.append(Vector2(x, top + 0.02))
				poly.append(Vector2(xe, top + 0.02))
				var n := maxi(int((xe - x) / 0.2), 1)
				for i in n + 1:
					var px := xe - (xe - x) * i / n
					poly.append(Vector2(px, top - 0.13 if i % 2 == 0 else top - 0.22))
			"scallop":
				poly.append(Vector2(x, top + 0.02))
				poly.append(Vector2(xe, top + 0.02))
				var n2 := maxi(int((xe - x) / 0.3), 1)
				var sw := (xe - x) / n2
				for i in n2:
					var cx := xe - sw * (i + 0.5)
					for k in 7:
						var a := PI * k / 6.0
						poly.append(Vector2(cx + cos(a) * sw * 0.5, top - 0.08 - sin(a) * sw * 0.42))
				poly.append(Vector2(x, top - 0.08))
			_:
				var n3 := maxi(int((xe - x) / 0.06), 2)
				for i in n3 + 1:
					var px2 := lerpf(x, xe, float(i) / n3)
					poly.append(Vector2(px2, top - 0.1 + sin(px2 * 18.0) * 0.045 + 0.035))
				for i in n3 + 1:
					var px3 := lerpf(xe, x, float(i) / n3)
					poly.append(Vector2(px3, top - 0.1 + sin(px3 * 18.0) * 0.045 - 0.035))
		var mi := felt_cutout(parent, poly, 0.025, Transform3D(Basis(), Vector3(0, 0, z)), col, 3.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if style == "scallop":
			# the eyelets of the lace
			var n4 := maxi(int((xe - x) / 0.3), 1)
			var sw2 := (xe - x) / n4
			for i in n4:
				var e := felt_cutout(parent, circle(0.035, 8, xe - sw2 * (i + 0.5), top - 0.12), 0.01,
					Transform3D(Basis(), Vector3(0, 0, z + 0.016)), col.darkened(0.3), 4.0)
				e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		x = xe

## patches and buttons sewn onto the front of a long block, so it isn't bare
static func dress_front(parent: Node3D, x0: float, x1: float, top: float, z: float, cols: Array, seed := 1.0) -> void:
	var x := x0 + 1.2 + fposmod(seed * 3.7, 2.0)
	var k := int(seed * 7.0)
	while x < x1 - 1.0:
		var r := fposmod(sin(x * 12.9898 + seed) * 43758.5453, 1.0)
		var wd := 0.7 + r * 0.8
		var ht := 0.5 + fposmod(r * 7.31, 1.0) * 0.6
		var y := top - 0.55 - ht * 0.5 - fposmod(r * 3.17, 1.0) * 1.0
		var p := block(parent, Vector3(x, y, z + 0.0), Vector3(wd, ht, 0.03), cols[k % cols.size()], CREAM, [0, 1, 2, 5][k % 4], false)
		p.rotation.z = (r - 0.5) * 0.25
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k % 2 == 0:
			var b := button(parent, Vector3(x + wd * 0.5 + 0.35, top - 0.5 - r * 0.6, z + 0.02), 0.13, [CORAL, TEAL, MUSTARD, LILAC][k % 4], r, false)
			b.rotation = Vector3(PI * 0.5, 0, r)
		x += 3.5 + r * 4.0
		k += 1

## a running stitch along a polyline in the XY plane (one mesh, many dashes)
static func stitch_line(pts: PackedVector2Array, z: float, dash := 0.35, gap := 0.25, wd := 0.06, col := CREAM) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var on := true
	var left := dash
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg - 0.0001:
			var stp := minf(left, seg - pos)
			if on:
				var p0 := a.lerp(b, pos / seg)
				var p1 := a.lerp(b, (pos + stp) / seg)
				var nrm := (p1 - p0).orthogonal().normalized() * wd * 0.5
				var q := [p0 - nrm, p1 - nrm, p1 + nrm, p0 + nrm]
				for k in [0, 1, 2, 0, 2, 3]:
					var v: Vector2 = q[k]
					st.set_normal(Vector3(0, 0, 1))
					st.add_vertex(Vector3(v.x, v.y, z))
			pos += stp
			left -= stp
			if left <= 0.0001:
				on = not on
				left = dash if on else gap
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## a tailor's tape measure pinned along a front face, with ticks and numbers
static func tape_measure(parent: Node3D, x0: float, x1: float, y: float, z: float, start_cm := 0) -> void:
	var tape := block(parent, Vector3((x0 + x1) * 0.5, y, z), Vector3(x1 - x0, 0.2, 0.025), Color(0.98, 0.86, 0.38), CREAM, 0, false)
	tape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int((x1 - x0) / 0.1)
	for i in n + 1:
		var x := x0 + i * 0.1
		var h := 0.09 if i % 10 == 0 else (0.06 if i % 5 == 0 else 0.035)
		var q := [Vector3(x - 0.006, y + 0.1 - h, 0), Vector3(x + 0.006, y + 0.1 - h, 0), Vector3(x + 0.006, y + 0.1, 0), Vector3(x - 0.006, y + 0.1, 0)]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(q[k] + Vector3(0, 0, z + 0.03))
	var ticks := MeshInstance3D.new()
	ticks.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.2, 0.22)
	ticks.material_override = m
	ticks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ticks)
	var cm := start_cm
	var x2 := x0 + 1.0
	while x2 < x1 - 0.2:
		cm = cm % 150 + 10
		var l := label(parent, str(cm), Vector3(x2, y - 0.04, z + 0.035), 0.0022, Color(0.25, 0.2, 0.22), 64)
		l.shaded = false
		x2 += 1.0
