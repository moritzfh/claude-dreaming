## Prism Boulevard – the set pieces along the road: the start gate with its
## lights, the chequered line, boost pads, ramps, glide rings, star bits, the
## warp gates and the hyperspace tube, the planet in the spiral, the moon in
## the loop, floating crystals, fireworks and sparks.
extends RefCounted

const GEM := preload("res://levels/prism_boulevard/shaders/gem.gdshader")
const PAD := preload("res://levels/prism_boulevard/shaders/pad.gdshader")
const CHECKER := preload("res://levels/prism_boulevard/shaders/checker.gdshader")
const GLOW := preload("res://levels/prism_boulevard/shaders/glow_solid.gdshader")
const VORTEX := preload("res://levels/prism_boulevard/shaders/vortex.gdshader")
const HYPER := preload("res://levels/prism_boulevard/shaders/hyper.gdshader")
const PLANET := preload("res://levels/prism_boulevard/shaders/planet.gdshader")
const SPARK := preload("res://levels/prism_boulevard/shaders/spark.gdshader")
const FONT := preload("res://levels/prism_boulevard/fonts/Fredoka-Bold.woff2")
const BIT_COLORS := [Color(1.0, 0.85, 0.25), Color(1.0, 0.45, 0.7), Color(0.4, 0.75, 1.0), Color(0.55, 1.0, 0.55), Color(0.8, 0.55, 1.0), Color(1.0, 0.6, 0.3)]

var level
var tr
var root: Node3D
var lights: Array = []
var bits: Array = []            # {node, s, x, off}
var rings: Array = []
var spinners: Array = []        # [node, axis, speed]
var fw: Array = []
var fw_on := false
var fw_t := 0.0
var spark_fx: GPUParticles3D
var gate_star: Node3D
var light_rings: Array = []     # [material, s]
var t := 0.0

static func mat(sh: Shader, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in params.keys(): m.set_shader_parameter(k, params[k])
	return m

func _at(s: float, x: float, h: float) -> Transform3D:
	var fr: Transform3D = tr.frame(s)
	return Transform3D(fr.basis, fr.origin + fr.basis.x * x + fr.basis.y * h)

func _mi(mesh: Mesh, m: Material, xf: Transform3D, parent: Node3D = null, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	if not shadow: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else root).add_child(mi)
	mi.transform = xf
	return mi

func build(lvl, track) -> void:
	level = lvl
	tr = track
	root = Node3D.new()
	root.name = "Pieces"
	level.add_child(root)
	_gate()
	_start_line()
	_pads()
	_kicks()
	_rings()
	_bits()
	_warp()
	_planet()
	_crystals()
	_moon()
	_light_rings()
	_fireworks()
	_sparks()

# ------------------------------------------------------------------ start gate
static func star_mesh(r_out: float, r_in: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0))
	for side in [1.0, -1.0]:
		var c := Vector3(0, 0, depth * side)
		for i in 10:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % 10]
			var nrm: Vector3 = (a - c).cross(b - c).normalized() * -side
			var tri := [c, b, a] if side > 0.0 else [c, a, b]
			for p in tri:
				st.set_normal(nrm)
				st.add_vertex(p)
	return st.commit()

func _gate() -> void:
	var w: float = tr.width(0.0)
	var base := _at(0.0, 0.0, 0.0)
	var gate := Node3D.new()
	gate.name = "Gate"
	root.add_child(gate)
	gate.transform = base
	# the big ring the road runs through
	var ring := TorusMesh.new()
	ring.inner_radius = 12.6
	ring.outer_radius = 13.6
	ring.rings = 96
	ring.ring_segments = 16
	var rm := _mi(ring, mat(GLOW, {"color": Color(1.0, 0.9, 1.0), "energy": 1.6, "rainbow": 0.8, "flow": 0.15}),
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.5, 0)), gate)
	var ring2 := TorusMesh.new()
	ring2.inner_radius = 14.1
	ring2.outer_radius = 14.5
	ring2.rings = 96
	ring2.ring_segments = 8
	var r2 := _mi(ring2, mat(GLOW, {"color": Color(1.0, 0.85, 0.5), "energy": 2.2}),
		Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.5, 0.6)), gate)
	spinners.append([r2, Vector3.FORWARD, 0.0])
	# bulbs around the ring
	var bulb := SphereMesh.new()
	bulb.radius = 0.32
	bulb.height = 0.64
	for i in 36:
		var a := TAU * i / 36.0
		var p := Vector3(cos(a) * 13.1, sin(a) * 13.1 + 0.5, 0.75)
		_mi(bulb, mat(GLOW, {"color": [Color(1, 0.6, 0.8), Color(0.6, 0.85, 1), Color(1, 0.95, 0.6)][i % 3], "energy": 3.0}), Transform3D(Basis(), p), gate)
	# crystal pillars
	for sd in [-1.0, 1.0]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.7
		cyl.bottom_radius = 1.25
		cyl.height = 20.0
		cyl.radial_segments = 6
		_mi(cyl, mat(GEM, {"color": Color(0.75, 0.6, 1.0) if sd < 0 else Color(0.55, 0.85, 1.0), "energy": 0.9}),
			Transform3D(Basis(), Vector3(sd * (w * 0.5 + 2.2), 4.0, 0)), gate, true)
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 0.7
		tip.height = 2.4
		tip.radial_segments = 6
		_mi(tip, mat(GEM, {"color": Color(1.0, 0.8, 0.95), "energy": 1.6}), Transform3D(Basis(), Vector3(sd * (w * 0.5 + 2.2), 15.2, 0)), gate)
	# the star on top
	gate_star = _mi(star_mesh(3.2, 1.35, 0.7), mat(GEM, {"color": Color(1.0, 0.82, 0.3), "energy": 1.8}), Transform3D(Basis(), Vector3(0, 17.2, 0)), gate)
	spinners.append([gate_star, Vector3.UP, 0.6])
	# banner + start lights
	var bar := BoxMesh.new()
	bar.size = Vector3(w + 2.0, 1.9, 0.5)
	_mi(bar, mat(PLANET, {"col_a": Color(0.25, 0.15, 0.5), "col_b": Color(0.35, 0.2, 0.6), "col_c": Color(0.5, 0.35, 0.8), "glow": 0.25, "bands": 0.0}),
		Transform3D(Basis(), Vector3(0, 9.6, 0)), gate)
	var lab := Label3D.new()
	lab.text = "PRISM BOULEVARD"
	lab.font = FONT
	lab.font_size = 140
	lab.pixel_size = 0.0085
	lab.outline_size = 28
	lab.modulate = Color(1.0, 0.92, 0.7)
	lab.outline_modulate = Color(0.45, 0.12, 0.45)
	lab.shaded = false
	lab.double_sided = true
	lab.position = Vector3(0, 9.65, 0.3)
	gate.add_child(lab)
	var lamp := SphereMesh.new()
	lamp.radius = 0.62
	lamp.height = 1.24
	for i in 3:
		var lm := _mi(lamp, mat(GLOW, {"color": Color(0.25, 0.15, 0.35), "energy": 1.0}), Transform3D(Basis(), Vector3((i - 1) * 2.0, 7.7, 0.35)), gate)
		lights.append(lm)

## 0 = all off, 1..3 = that many red, 4 = all green
func set_lights(n: int) -> void:
	for i in lights.size():
		var m: ShaderMaterial = (lights[i] as MeshInstance3D).material_override
		if n >= 4:
			m.set_shader_parameter("color", Color(0.4, 1.0, 0.6)); m.set_shader_parameter("energy", 4.0)
		elif i < n:
			m.set_shader_parameter("color", Color(1.0, 0.3, 0.45)); m.set_shader_parameter("energy", 4.0)
		else:
			m.set_shader_parameter("color", Color(0.25, 0.15, 0.35)); m.set_shader_parameter("energy", 1.0)

func _start_line() -> void:
	var pm := PlaneMesh.new()
	var w: float = tr.width(0.0) - 0.7
	pm.size = Vector2(w, 2.2)
	_mi(pm, mat(CHECKER, {"cells_x": 18.0, "cells_y": 2.0}), _at(0.0, 0.0, 0.035))

# ------------------------------------------------------------------ pads, ramps
func _pads() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(3.8, 4.4)
	for pd in tr.pads:
		_mi(pm, mat(PAD, {"count": 3.0, "speed": 2.6}), _at(float(pd["s"]), float(pd["x"]), 0.05))

func _kicks() -> void:
	for k in tr.kicks:
		var s: float = k["s"]
		var w: float = tr.width(s) - 0.8
		var pm := PlaneMesh.new()
		pm.size = Vector2(w, 3.0)
		_mi(pm, mat(PAD, {"count": 2.0, "speed": 1.6, "tint": Color(1.0, 0.85, 0.35), "rainbow": 0.3 if not k["glide"] else 1.0}), _at(s - 1.5, 0.0, 0.05))
		if k["glide"]:
			# two tall beacons at the edge of the glider ramp
			for sd in [-1.0, 1.0]:
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.25
				cyl.bottom_radius = 0.4
				cyl.height = 7.0
				cyl.radial_segments = 8
				_mi(cyl, mat(GEM, {"color": Color(1.0, 0.7, 0.9), "energy": 1.2}), _at(s, sd * (w * 0.5 + 0.9), 3.5))
				var st := _mi(star_mesh(1.1, 0.45, 0.25), mat(GEM, {"color": Color(1.0, 0.9, 0.4), "energy": 2.0}), _at(s, sd * (w * 0.5 + 0.9), 7.8))
				spinners.append([st, Vector3.UP, 1.5])

func _rings() -> void:
	for rg in tr.rings:
		var xf := _at(float(rg["s"]), float(rg["x"]), float(rg["h"]))
		var node := Node3D.new()
		root.add_child(node)
		node.transform = xf
		var tor := TorusMesh.new()
		tor.inner_radius = 2.7
		tor.outer_radius = 3.15
		tor.rings = 48
		tor.ring_segments = 10
		var m := _mi(tor, mat(GLOW, {"color": Color(1, 0.85, 0.5), "energy": 2.6, "rainbow": 0.7, "flow": 0.4}), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), node)
		spinners.append([m, Vector3.UP, 1.2])
		for i in 5:
			var a := TAU * i / 5.0
			var st := _mi(star_mesh(0.5, 0.2, 0.12), mat(GEM, {"color": Color(1.0, 0.9, 0.5), "energy": 2.4}), Transform3D(Basis(), Vector3(cos(a) * 3.6, sin(a) * 3.6, 0)), node)
			spinners.append([st, Vector3.FORWARD, 2.0])
		rings.append(node)

# ------------------------------------------------------------------ star bits
func _gem_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, 0.42, 0)
	var bot := Vector3(0, -0.42, 0)
	var ring: Array = []
	for i in 6:
		var a := TAU * i / 6.0
		ring.append(Vector3(cos(a) * 0.28, 0, sin(a) * 0.28))
	for i in 6:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 6]
		for tri in [[top, b, a], [bot, a, b]]:
			var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for p in tri:
				st.set_normal(-nrm)
				st.add_vertex(p)
	return st.commit()

func _bits() -> void:
	var gm := _gem_mesh()
	var i := 0
	for b in tr.bits:
		var c: Color = BIT_COLORS[i % BIT_COLORS.size()]
		var node := _mi(gm, mat(GEM, {"color": c, "energy": 1.8}), _at(float(b["s"]), float(b["x"]), 0.95))
		node.scale = Vector3.ONE * 1.25
		bits.append({"node": node, "s": float(b["s"]), "x": float(b["x"]), "off": 0.0, "ph": i * 0.7})
		i += 1

func reset_bits() -> void:
	for b in bits:
		b["off"] = 0.0
		(b["node"] as Node3D).visible = true

# ------------------------------------------------------------------ warp
func _warp() -> void:
	var a: Vector2 = tr.section_s("hyper1")
	var b: Vector2 = tr.section_s("hyper2")
	if a == Vector2.ZERO: return
	var s0 := a.x
	var s1 := b.y
	for sp in [s0, s1]:
		var node := Node3D.new()
		root.add_child(node)
		node.transform = _at(sp, 0.0, 2.5)
		var tor := TorusMesh.new()
		tor.inner_radius = 11.6
		tor.outer_radius = 12.8
		tor.rings = 96
		tor.ring_segments = 14
		_mi(tor, mat(GEM, {"color": Color(0.6, 0.45, 1.0), "energy": 1.0}), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), node, true)
		var tor2 := TorusMesh.new()
		tor2.inner_radius = 13.2
		tor2.outer_radius = 13.6
		var t2 := _mi(tor2, mat(GLOW, {"rainbow": 1.0, "flow": 0.5, "energy": 3.0}), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), node)
		spinners.append([t2, Vector3.FORWARD, 0.5])
		var q := QuadMesh.new()
		q.size = Vector2(23.5, 23.5)
		var vx := _mi(q, mat(VORTEX, {"energy": 1.1}), Transform3D(), node)
		spinners.append([vx, Vector3.FORWARD, 0.0])
		# little crystal teeth around the gate
		for i in 12:
			var ang := TAU * i / 12.0
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0
			cyl.bottom_radius = 0.7
			cyl.height = 3.2
			cyl.radial_segments = 6
			var p := Vector3(cos(ang), sin(ang), 0) * 14.6
			var bs := Basis.looking_at(Vector3(0, 0, 1), p.normalized())   # cone's y axis points outwards
			_mi(cyl, mat(GEM, {"color": Color(1.0, 0.7, 0.95), "energy": 1.4}), Transform3D(bs, p), node)
	# the tube between the gates
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEG := 32
	const RAD := 13.0
	var s := s0
	while s < s1:
		var s2 := minf(s + 2.0, s1)
		var f0: Transform3D = tr.frame(s)
		var f1: Transform3D = tr.frame(s2)
		var c0 := f0.origin + f0.basis.y * 2.5
		var c1 := f1.origin + f1.basis.y * 2.5
		for k in SEG:
			var a0 := TAU * k / SEG
			var a1 := TAU * (k + 1) / SEG
			var p00 := c0 + (f0.basis.x * cos(a0) + f0.basis.y * sin(a0)) * RAD
			var p01 := c0 + (f0.basis.x * cos(a1) + f0.basis.y * sin(a1)) * RAD
			var p10 := c1 + (f1.basis.x * cos(a0) + f1.basis.y * sin(a0)) * RAD
			var p11 := c1 + (f1.basis.x * cos(a1) + f1.basis.y * sin(a1)) * RAD
			for v in [[p00, s, k], [p10, s2, k], [p11, s2, k + 1], [p00, s, k], [p11, s2, k + 1], [p01, s, k + 1]]:
				st.set_uv(Vector2(v[1], float(v[2]) / SEG))
				st.set_uv2(Vector2(v[1] - s0, s1 - v[1]))
				st.add_vertex(v[0])
		s = s2
	var tube := MeshInstance3D.new()
	tube.mesh = st.commit()
	tube.material_override = mat(HYPER, {"energy": 1.5})
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tube)

# ------------------------------------------------------------------ planet, moon, crystals
func _section_center(name: String) -> Array:
	var r: Vector2 = tr.section_s(name)
	var c := Vector3.ZERO
	var n := 0
	var s := r.x
	while s < r.y:
		c += tr.P[tr.idx(s)]
		n += 1
		s += 2.0
	c /= maxf(n, 1)
	return [c, r]

func _planet() -> void:
	var cr := _section_center("spiral")
	var c: Vector3 = cr[0]
	var r: Vector2 = cr[1]
	# keep clear of the road
	var md := INF
	var s := r.x
	while s < r.y:
		var p: Vector3 = tr.P[tr.idx(s)]
		md = minf(md, Vector2(p.x - c.x, p.z - c.z).length())
		s += 2.0
	var rad := md - 10.0 - 14.0
	var sp := SphereMesh.new()
	sp.radius = rad
	sp.height = rad * 2.0
	sp.radial_segments = 64
	sp.rings = 32
	var pl := _mi(sp, mat(PLANET, {"col_a": Color(0.55, 0.85, 1.0), "col_b": Color(0.75, 0.55, 1.0), "col_c": Color(1.0, 0.85, 0.95), "atmo": Color(0.7, 0.9, 1.0), "bands": 5.0, "spin": 0.03}),
		Transform3D(Basis.from_euler(Vector3(0.3, 0, 0.2)), c + Vector3(0, -8.0, 0)), null, true)
	pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# its ring, tilted, passing under the road
	var tor := TorusMesh.new()
	tor.inner_radius = rad * 1.35
	tor.outer_radius = rad * 1.75
	tor.rings = 96
	tor.ring_segments = 4
	var ring := _mi(tor, mat(GLOW, {"color": Color(1.0, 0.8, 0.95), "energy": 0.9, "rainbow": 0.6, "flow": 0.02}),
		Transform3D(Basis.from_euler(Vector3(0.18, 0.0, -0.12)).scaled(Vector3(1, 0.05, 1)), c + Vector3(0, -8.0 - rad * 0.55, 0)))
	spinners.append([ring, Vector3.UP, 0.05])

func _moon() -> void:
	var cr := _section_center("loop")
	var c: Vector3 = cr[0]
	var sp := SphereMesh.new()
	sp.radius = 7.5
	sp.height = 15.0
	sp.radial_segments = 48
	sp.rings = 24
	var moon := _mi(sp, mat(PLANET, {"col_a": Color(1.0, 0.95, 0.8), "col_b": Color(0.95, 0.85, 0.95), "col_c": Color(1, 1, 1), "atmo": Color(1.0, 0.95, 0.75), "bands": 0.0, "craters": 1.0, "glow": 0.45}),
		Transform3D(Basis(), c), null, true)
	spinners.append([moon, Vector3.UP, 0.1])

func _crystals() -> void:
	var r: Vector2 = tr.section_s("corkscrew")
	if r == Vector2.ZERO: return
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var cols := [Color(0.75, 0.55, 1.0), Color(0.5, 0.85, 1.0), Color(1.0, 0.6, 0.85), Color(0.6, 1.0, 0.85)]
	var s := r.x - 30.0
	while s < r.y + 30.0:
		var fr: Transform3D = tr.frame(s)
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(16.0, 30.0)
		var center: Vector3 = fr.origin + (fr.basis.x * cos(ang) + fr.basis.y * sin(ang)) * dist
		var cl := Node3D.new()
		root.add_child(cl)
		cl.position = center
		cl.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var col: Color = cols[rng.randi() % cols.size()]
		for k in rng.randi_range(3, 5):
			var len := rng.randf_range(3.0, 8.0)
			var rad := rng.randf_range(0.5, 1.2)
			var cyl := CylinderMesh.new()
			cyl.top_radius = rad
			cyl.bottom_radius = rad
			cyl.height = len
			cyl.radial_segments = 6
			var tip := CylinderMesh.new()
			tip.top_radius = 0.0
			tip.bottom_radius = rad
			tip.height = rad * 1.8
			tip.radial_segments = 6
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.7, 0.7), rng.randf() * TAU, rng.randf_range(-0.7, 0.7)))
			var m := mat(GEM, {"color": col.lerp(Color(1, 1, 1), rng.randf() * 0.3), "energy": 0.8})
			_mi(cyl, m, Transform3D(b, b.y * len * 0.5), cl, true)
			_mi(tip, m, Transform3D(b, b.y * (len + rad * 0.9)), cl)
		spinners.append([cl, Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf_range(0.1, 0.3)])
		s += rng.randf_range(9.0, 16.0)


## a tunnel of glowing rings on the comet run, lit one after another
func _light_rings() -> void:
	var a: Vector2 = tr.section_s("comet1")
	var b: Vector2 = tr.section_s("comet3")
	if a == Vector2.ZERO: return
	var s := a.x + 20.0
	while s < b.y - 10.0:
		var w: float = tr.width(s)
		var tor := TorusMesh.new()
		tor.inner_radius = w * 0.5 + 3.2
		tor.outer_radius = w * 0.5 + 3.9
		tor.rings = 72
		tor.ring_segments = 8
		var m := mat(GLOW, {"color": Color(1, 0.9, 1), "energy": 1.2, "rainbow": 1.0, "flow": 0.25})
		_mi(tor, m, _at(s, 0.0, 1.5) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
		light_rings.append([m, s])
		s += 28.0

# ------------------------------------------------------------------ effects
func _burst(col: Color, amount: int, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -5, 0)
	pm.damping_min = 3.0
	pm.damping_max = 5.0
	var sc := Curve.new(); sc.add_point(Vector2(0, 1)); sc.add_point(Vector2(0.7, 0.8)); sc.add_point(Vector2(1, 0))
	var sct := CurveTexture.new(); sct.curve = sc
	pm.scale_curve = sct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat(SPARK, {"color": col})
	p.draw_pass_1 = q
	root.add_child(p)
	return p

func _fireworks() -> void:
	var cols := [Color(1, 0.4, 0.7), Color(0.4, 0.8, 1.0), Color(1.0, 0.85, 0.3), Color(0.6, 1.0, 0.6), Color(0.8, 0.5, 1.0), Color(1.0, 0.55, 0.3)]
	for c in cols:
		fw.append(_burst(c, 90, 0.9))

func fireworks(on: bool) -> void:
	fw_on = on
	fw_t = 0.0

func _sparks() -> void:
	spark_fx = _burst(Color(1.0, 0.85, 0.5), 24, 0.25)
	spark_fx.lifetime = 0.4
	var pm := spark_fx.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -12, 0)

func wall_sparks(k) -> void:
	if k != level.me: return
	var fr: Transform3D = tr.frame(k.s)
	spark_fx.global_position = k.world_pos + fr.basis.x * signf(k.x) * 0.8 + fr.basis.y * 0.4
	spark_fx.restart()

# ------------------------------------------------------------------ per frame
func update(dt: float, karts: Array, me) -> void:
	t += dt
	for sp in spinners:
		if float(sp[2]) != 0.0:
			(sp[0] as Node3D).rotate_object_local(sp[1], dt * float(sp[2]))
	# star bits: spin, bob, get picked up, come back
	for b in bits:
		var node: Node3D = b["node"]
		if b["off"] > 0.0:
			b["off"] = float(b["off"]) - dt
			if b["off"] <= 0.0: node.visible = true
			continue
		node.rotate_object_local(Vector3.UP, dt * 2.5)
		for k in karts:
			if k.falling or k.h > 1.8: continue
			var ds: float = absf(wrapf(k.s - float(b["s"]), -tr.length * 0.5, tr.length * 0.5))
			if ds < 1.7 and absf(k.x - float(b["x"])) < 1.7:
				node.visible = false
				b["off"] = 12.0
				if k.bits < 10:
					k.bits += 1
				if k == me:
					level.sfx("bit", -6.0, 1.0 + 0.04 * me.bits)
				break
	# the ring tunnel: a wave of light runs through it, brightest around Claude
	for lr in light_rings:
		var m: ShaderMaterial = lr[0]
		var d: float = wrapf(float(lr[1]) - me.s, -tr.length * 0.5, tr.length * 0.5)
		var wave := pow(0.5 + 0.5 * sin(t * 4.0 - float(lr[1]) * 0.08), 4.0)
		m.set_shader_parameter("energy", 0.9 + wave * 2.2 + (1.5 if absf(d) < 30.0 else 0.0))
	# fireworks over the gate
	if fw_on:
		fw_t -= dt
		if fw_t <= 0.0:
			fw_t = randf_range(0.25, 0.6)
			var p: GPUParticles3D = fw[randi() % fw.size()]
			var fr: Transform3D = tr.frame(randf_range(-30.0, 60.0))
			p.global_position = fr.origin + fr.basis.x * randf_range(-30.0, 30.0) + Vector3(0, randf_range(18.0, 40.0), 0)
			p.restart()
			level.sfx("firework", -10.0, randf_range(0.8, 1.2))
