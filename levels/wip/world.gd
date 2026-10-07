## Meshes and materials for "Work in Progress" (all procedural).
extends RefCounted

const TOON := preload("res://levels/wip/shaders/toon.gdshader")
const MISSING := preload("res://levels/wip/shaders/missing.gdshader")
const PROTO := preload("res://levels/wip/shaders/proto.gdshader")
const WIRE := preload("res://levels/wip/shaders/wire.gdshader")
const SKETCH := preload("res://levels/wip/shaders/sketch.gdshader")
const SELECT := preload("res://levels/wip/shaders/select.gdshader")

const DEPTH := 1.6            # every block reaches from z = -0.8 to 0.8
## the ground is drawn deeper than that, back to z = -2.6 (room for trees)
const VIS_DEPTH := 3.4
const VIS_Z := -0.9
const ORANGE := Color(1.0, 0.56, 0.16)
const ORANGE_LINE := Color(1.0, 0.93, 0.82)

static var _cache := {}

static func shader_mat(sh: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in params: m.set_shader_parameter(k, params[k])
	return m

static func toon(params: Dictionary) -> ShaderMaterial:
	return shader_mat(TOON, params)

static func grass_mat() -> ShaderMaterial:
	if not _cache.has("grass"):
		_cache["grass"] = toon({"mode": 0, "grass_a": Color(0.30, 0.68, 0.30), "grass_b": Color(0.58, 0.86, 0.34),
			"earth_a": Color(0.58, 0.40, 0.31), "earth_b": Color(0.64, 0.45, 0.34), "stripe_scale": 4.0,
			"rim_col": Color(1.0, 0.86, 0.7), "rim_strength": 0.3, "shadow_tint": Color(0.46, 0.38, 0.72),
			"fade_top": 2.2, "fade_bottom": -2.5, "fade_col": Color(0.36, 0.25, 0.45)})
	return _cache["grass"]

static func cap_mat() -> ShaderMaterial:
	if not _cache.has("cap"):
		_cache["cap"] = toon({"mode": 1, "base_col": Color(0.42, 0.78, 0.32), "stripe_col": Color(0.55, 0.88, 0.38),
			"stripe_scale": 5.0, "rim_col": Color(0.9, 1.0, 0.7), "rim_strength": 0.4, "shadow_tint": Color(0.3, 0.42, 0.6)})
	return _cache["cap"]

static func plain(col: Color, rim := Color(1.0, 0.9, 0.8), stripe := 0.0) -> ShaderMaterial:
	return toon({"mode": 1, "base_col": col, "stripe_col": col.lightened(0.12), "stripe_scale": stripe if stripe > 0.0 else 0.001,
		"rim_col": rim, "rim_strength": 0.4, "shadow_tint": Color(0.45, 0.38, 0.72)})

static func missing_mat(sq := 2.0) -> ShaderMaterial:
	var key := "missing%f" % sq
	if not _cache.has(key): _cache[key] = shader_mat(MISSING, {"squares_per_m": sq})
	return _cache[key]

static func proto_mat(base := Color(0.70, 0.71, 0.73), line := Color(0.42, 0.43, 0.46)) -> ShaderMaterial:
	return shader_mat(PROTO, {"base": base, "line_col": line})

static func orange_mat() -> ShaderMaterial:
	if not _cache.has("orange"):
		_cache["orange"] = shader_mat(PROTO, {"base": ORANGE, "line_col": ORANGE_LINE, "checker": 0.0,
			"shadow_tint": Color(0.75, 0.45, 0.45), "glow": 0.08, "grid_offset": Vector3(0.0, 0.0, 0.8)})
	return _cache["orange"]

static func wire_mat(size: Vector3, fill := 0.0, line := Color(0.55, 0.85, 1.0)) -> ShaderMaterial:
	return shader_mat(WIRE, {"size": size, "line_col": line, "fill_col": Color(0.2, 0.7, 0.85, fill)})

static func wire_round(lines := Vector2(16, 8), line := Color(0.55, 0.85, 1.0)) -> ShaderMaterial:
	return shader_mat(WIRE, {"mode": 1, "uv_lines": lines, "line_col": line, "fill_col": Color(0.2, 0.7, 0.85, 0.0)})

static func sketch_mat(size: Vector3, tint := Color(1, 1, 1), hatch := 1.0) -> ShaderMaterial:
	return shader_mat(SKETCH, {"size": size, "tint": tint, "hatch": hatch})

static func sketch_round(tint := Color(1, 1, 1)) -> ShaderMaterial:
	return shader_mat(SKETCH, {"mode": 1, "tint": tint, "hatch": 0.6})

static func select_mat(size: Vector3, col := Color(1.0, 0.62, 0.2)) -> ShaderMaterial:
	return shader_mat(SELECT, {"size": size, "color": col})

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func mesh_node(mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi

## A ramp (wedge) filling one cell, centred on the origin; rises to +x when
## dir = 1, to -x when dir = -1. Returns [mesh, collision points].
static func ramp(dir: float) -> Array:
	var h := DEPTH * 0.5
	var a := [Vector3(-0.5, -0.5, -h), Vector3(0.5, -0.5, -h), Vector3(0.5, -0.5, h), Vector3(-0.5, -0.5, h)]
	var hx := 0.5 * dir
	var top := [Vector3(hx, 0.5, -h), Vector3(hx, 0.5, h)]
	var pts := PackedVector3Array(a + top)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lx := -0.5 * dir
	# bottom
	_quad(st, Vector3(-0.5, -0.5, h), Vector3(0.5, -0.5, h), Vector3(0.5, -0.5, -h), Vector3(-0.5, -0.5, -h), Vector3.DOWN)
	# the tall back face (at the high end)
	_quad(st, Vector3(hx, -0.5, -h), Vector3(hx, -0.5, h), Vector3(hx, 0.5, h), Vector3(hx, 0.5, -h), Vector3(dir, 0, 0))
	# the slope
	var n := Vector3(-dir, 1, 0).normalized()
	_quad(st, Vector3(lx, -0.5, h), Vector3(hx, 0.5, h), Vector3(hx, 0.5, -h), Vector3(lx, -0.5, -h), n)
	# the two triangle sides
	_tri(st, Vector3(lx, -0.5, h), Vector3(hx, -0.5, h), Vector3(hx, 0.5, h), Vector3(0, 0, 1))
	_tri(st, Vector3(lx, -0.5, -h), Vector3(hx, 0.5, -h), Vector3(hx, -0.5, -h), Vector3(0, 0, -1))
	return [st.commit(), pts]

## one quad with a fixed normal; corners in any winding – flipped to face `n`
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot: front faces are clockwise seen from the front – i.e. the
	# triangle's (b - a) x (c - a) points *away* from the viewer
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b; b = c; c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x + v.z, v.y))
		st.add_vertex(v)

## A five-pointed star prism (the goal)
static func star_mesh(r_out := 0.62, r_in := 0.27, thick := 0.24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in 10:
		var a := PI * 0.5 + i * PI / 5.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	var hz := thick * 0.5
	for i in 10:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % 10]
		# front and back fans (a little bulge in the middle)
		_tri(st, Vector3(0, 0, hz + 0.08), Vector3(p.x, p.y, hz), Vector3(q.x, q.y, hz), Vector3(0, 0, 1))
		_tri(st, Vector3(0, 0, -hz - 0.08), Vector3(q.x, q.y, -hz), Vector3(p.x, p.y, -hz), Vector3(0, 0, -1))
		var n := Vector3(q.y - p.y, -(q.x - p.x), 0).normalized()
		_quad(st, Vector3(p.x, p.y, hz), Vector3(q.x, q.y, hz), Vector3(q.x, q.y, -hz), Vector3(p.x, p.y, -hz), n)
	st.generate_normals()
	return st.commit()

## grass tufts: three crossed blades, coloured dark at the root
static func tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * PI / 3.0
		var dx := Vector3(cos(a), 0, sin(a)) * 0.07
		var lean := Vector3(cos(a + 1.0), 0, sin(a + 1.0)) * 0.06
		for v in [[-dx, 0.0], [dx, 0.0], [lean, 1.0]]:
			var p: Vector3 = v[0]
			var top: float = v[1]
			st.set_color(Color(0.16, 0.36, 0.16).lerp(Color(0.42, 0.68, 0.26), top))
			st.set_normal(Vector3.UP)
			st.add_vertex(p + Vector3(0, top * 0.26, 0))
	return st.commit()

static func vcol_mat(cull_off := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	if cull_off: m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
