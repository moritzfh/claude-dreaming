## Prism Boulevard – turns the track data into meshes: the glass road, its
## silver sides and dark underside, the low walls with their neon tubes.
## Everything is cut into chunks of CHUNK metres so the GPU can skip what's
## behind the camera.
extends RefCounted

const CHUNK := 64
const LAT := 10            # quads across the road
const THICK := 0.9         # road slab thickness
const WALL_H := 0.55
const WALL_T := 0.35
const TUBE_R := 0.09

static func build_road(tr) -> Dictionary:
	var out := {"glass": [], "river": [], "rim": [], "under": [], "wall": [], "neon": []}
	var n: int = tr.n
	var c0 := 0
	while c0 < n:
		var c1 := mini(c0 + CHUNK, n)
		var g := _top(tr, c0, c1, tr.GLASS)
		if g: out["glass"].append(g)
		var rv := _top(tr, c0, c1, tr.RIVER)
		if rv: out["river"].append(rv)
		var rim := _sides(tr, c0, c1)
		if rim: out["rim"].append(rim)
		var und := _under(tr, c0, c1)
		if und: out["under"].append(und)
		var wl := _walls(tr, c0, c1)
		if wl: out["wall"].append(wl)
		var ne := _neon(tr, c0, c1)
		if ne: out["neon"].append(ne)
		c0 = c1
	return out

## one quad, corners as seen from its front: bottom-left, bottom-right,
## top-left, top-right (Godot's front faces are clockwise)
static func _q(st: SurfaceTool, bl: Vector3, br: Vector3, tl: Vector3, tr_: Vector3,
		nbl: Vector3, nbr: Vector3, ntl: Vector3, ntr: Vector3,
		ubl: Vector2, ubr: Vector2, utl: Vector2, utr: Vector2,
		u2bl := Vector2.ZERO, u2br := Vector2.ZERO, u2tl := Vector2.ZERO, u2tr := Vector2.ZERO) -> void:
	for v in [[bl, nbl, ubl, u2bl], [tl, ntl, utl, u2tl], [tr_, ntr, utr, u2tr],
			[bl, nbl, ubl, u2bl], [tr_, ntr, utr, u2tr], [br, nbr, ubr, u2br]]:
		st.set_normal(v[1]); st.set_uv(v[2]); st.set_uv2(v[3])
		st.add_vertex(v[0])

static func _top(tr, c0: int, c1: int, surf: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in range(c0, c1):
		if tr.SURF[i] != surf: continue
		var j: int = (i + 1) % tr.n
		var s0: float = i * tr.STEP
		var s1: float = s0 + tr.STEP
		var w0: float = tr.W[i]
		var w1: float = tr.W[j]
		for k in LAT:
			var f0 := float(k) / LAT - 0.5
			var f1 := float(k + 1) / LAT - 0.5
			_q(st, tr.P[i] + tr.R[i] * (f0 * w0), tr.P[i] + tr.R[i] * (f1 * w0),
				tr.P[j] + tr.R[j] * (f0 * w1), tr.P[j] + tr.R[j] * (f1 * w1),
				tr.U[i], tr.U[i], tr.U[j], tr.U[j],
				Vector2(s0, f0 * w0), Vector2(s0, f1 * w0), Vector2(s1, f0 * w1), Vector2(s1, f1 * w1),
				Vector2(f0 * 2.0, w0), Vector2(f1 * 2.0, w0), Vector2(f0 * 2.0, w1), Vector2(f1 * 2.0, w1))
			any = true
	if not any: return null
	st.generate_tangents()
	return st.commit()

static func _sides(tr, c0: int, c1: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in range(c0, c1):
		if tr.SURF[i] == tr.GAP: continue
		var j: int = (i + 1) % tr.n
		var s0: float = i * tr.STEP
		var s1: float = s0 + tr.STEP
		# right side, seen from outside: s grows to the right
		var e0: Vector3 = tr.P[i] + tr.R[i] * (tr.W[i] * 0.5)
		var e1: Vector3 = tr.P[j] + tr.R[j] * (tr.W[j] * 0.5)
		var b0: Vector3 = e0 - tr.U[i] * THICK
		var b1: Vector3 = e1 - tr.U[j] * THICK
		_q(st, b0, b1, e0, e1, tr.R[i], tr.R[j], tr.R[i], tr.R[j], Vector2(s0, 1), Vector2(s1, 1), Vector2(s0, 0), Vector2(s1, 0))
		# left side, seen from outside: s grows to the left
		e0 = tr.P[i] - tr.R[i] * (tr.W[i] * 0.5)
		e1 = tr.P[j] - tr.R[j] * (tr.W[j] * 0.5)
		b0 = e0 - tr.U[i] * THICK
		b1 = e1 - tr.U[j] * THICK
		_q(st, b1, b0, e1, e0, -tr.R[j], -tr.R[i], -tr.R[j], -tr.R[i], Vector2(s1, 1), Vector2(s0, 1), Vector2(s1, 0), Vector2(s0, 0))
		any = true
		# end caps where the road stops before a gap or starts after one
		var ends_here: bool = tr.SURF[j] == tr.GAP
		var starts_here: bool = tr.SURF[(i - 1 + tr.n) % tr.n] == tr.GAP
		if ends_here or starts_here:
			var at := j if ends_here else i
			var hl: float = tr.W[at] * 0.5
			var lt: Vector3 = tr.P[at] - tr.R[at] * hl
			var rt: Vector3 = tr.P[at] + tr.R[at] * hl
			var lb: Vector3 = lt - tr.U[at] * THICK
			var rb: Vector3 = rt - tr.U[at] * THICK
			if ends_here:   # faces forward: seen from the front, the road's right is on the left
				var f: Vector3 = tr.T[at]
				_q(st, rb, lb, rt, lt, f, f, f, f, Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0))
			else:
				var f: Vector3 = -tr.T[at]
				_q(st, lb, rb, lt, rt, f, f, f, f, Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0))
	if not any: return null
	return st.commit()

static func _under(tr, c0: int, c1: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in range(c0, c1):
		if tr.SURF[i] == tr.GAP: continue
		var j: int = (i + 1) % tr.n
		var s0: float = i * tr.STEP
		var hw0: float = tr.W[i] * 0.5
		var hw1: float = tr.W[j] * 0.5
		var d0: Vector3 = tr.P[i] - tr.U[i] * THICK
		var d1: Vector3 = tr.P[j] - tr.U[j] * THICK
		# seen from below the road's right is on the left
		_q(st, d0 + tr.R[i] * hw0, d0 - tr.R[i] * hw0, d1 + tr.R[j] * hw1, d1 - tr.R[j] * hw1,
			-tr.U[i], -tr.U[i], -tr.U[j], -tr.U[j],
			Vector2(s0, hw0), Vector2(s0, -hw0), Vector2(s0 + 1, hw1), Vector2(s0 + 1, -hw1),
			Vector2(1, hw0 * 2), Vector2(-1, hw0 * 2), Vector2(1, hw1 * 2), Vector2(-1, hw1 * 2))
		any = true
	if not any: return null
	return st.commit()

## low walls along the edges: inner face (UV2.x = 0), top (1), outer face (2)
static func _walls(tr, c0: int, c1: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in range(c0, c1):
		if tr.SURF[i] == tr.GAP: continue
		var j: int = (i + 1) % tr.n
		var s0: float = i * tr.STEP
		var s1: float = s0 + tr.STEP
		for side in [-1, 1]:
			var arr: PackedByteArray = tr.RAIL_R if side > 0 else tr.RAIL_L
			if arr[i] == 0 or arr[j] == 0: continue
			var sd := float(side)
			var o0: Vector3 = tr.P[i] + tr.R[i] * (sd * tr.W[i] * 0.5)
			var o1: Vector3 = tr.P[j] + tr.R[j] * (sd * tr.W[j] * 0.5)
			var in0: Vector3 = o0 - tr.R[i] * (sd * WALL_T)
			var in1: Vector3 = o1 - tr.R[j] * (sd * WALL_T)
			var up0: Vector3 = tr.U[i] * WALL_H
			var up1: Vector3 = tr.U[j] * WALL_H
			var r0: Vector3 = tr.R[i]
			var r1: Vector3 = tr.R[j]
			var z := Vector2.ZERO
			var top := Vector2(1, 0)
			var outer := Vector2(2, 0)
			if side > 0:
				# inner face looks to -R: s grows to the left
				_q(st, in1, in0, in1 + up1, in0 + up0, -r1, -r0, -r1, -r0, Vector2(s1, 0), Vector2(s0, 0), Vector2(s1, 1), Vector2(s0, 1), z, z, z, z)
				_q(st, in0 + up0, o0 + up0, in1 + up1, o1 + up1, tr.U[i], tr.U[i], tr.U[j], tr.U[j], Vector2(s0, 1), Vector2(s0, 1.4), Vector2(s1, 1), Vector2(s1, 1.4), top, top, top, top)
				_q(st, o0, o1, o0 + up0, o1 + up1, r0, r1, r0, r1, Vector2(s0, 0), Vector2(s1, 0), Vector2(s0, 1), Vector2(s1, 1), outer, outer, outer, outer)
			else:
				_q(st, in0, in1, in0 + up0, in1 + up1, r0, r1, r0, r1, Vector2(s0, 0), Vector2(s1, 0), Vector2(s0, 1), Vector2(s1, 1), z, z, z, z)
				_q(st, o0 + up0, in0 + up0, o1 + up1, in1 + up1, tr.U[i], tr.U[i], tr.U[j], tr.U[j], Vector2(s0, 1.4), Vector2(s0, 1), Vector2(s1, 1.4), Vector2(s1, 1), top, top, top, top)
				_q(st, o1, o0, o1 + up1, o0 + up0, -r1, -r0, -r1, -r0, Vector2(s1, 0), Vector2(s0, 0), Vector2(s1, 1), Vector2(s0, 1), outer, outer, outer, outer)
			any = true
	if not any: return null
	return st.commit()

## the glowing tube on top of each wall (UV.y = side)
static func _neon(tr, c0: int, c1: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	const SIDES := 6
	for i in range(c0, c1):
		if tr.SURF[i] == tr.GAP: continue
		var j: int = (i + 1) % tr.n
		var s0: float = i * tr.STEP
		var s1: float = s0 + tr.STEP
		for side in [-1, 1]:
			var arr: PackedByteArray = tr.RAIL_R if side > 0 else tr.RAIL_L
			if arr[i] == 0 or arr[j] == 0: continue
			var sd := float(side)
			var c_0: Vector3 = tr.P[i] + tr.R[i] * (sd * (tr.W[i] * 0.5 - WALL_T * 0.5)) + tr.U[i] * (WALL_H + TUBE_R * 0.6)
			var c_1: Vector3 = tr.P[j] + tr.R[j] * (sd * (tr.W[j] * 0.5 - WALL_T * 0.5)) + tr.U[j] * (WALL_H + TUBE_R * 0.6)
			for k in SIDES:
				var a0 := TAU * k / SIDES
				var a1 := TAU * (k + 1) / SIDES
				var d00: Vector3 = tr.R[i] * cos(a0) + tr.U[i] * sin(a0)
				var d01: Vector3 = tr.R[i] * cos(a1) + tr.U[i] * sin(a1)
				var d10: Vector3 = tr.R[j] * cos(a0) + tr.U[j] * sin(a0)
				var d11: Vector3 = tr.R[j] * cos(a1) + tr.U[j] * sin(a1)
				_q(st, c_0 + d00 * TUBE_R, c_1 + d10 * TUBE_R, c_0 + d01 * TUBE_R, c_1 + d11 * TUBE_R, d00, d10, d01, d11,
					Vector2(s0, sd), Vector2(s1, sd), Vector2(s0, sd), Vector2(s1, sd))
			any = true
	if not any: return null
	return st.commit()
