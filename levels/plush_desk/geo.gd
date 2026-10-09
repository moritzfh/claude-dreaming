## Small procedural mesh helpers (tubes along paths, rounded outlines).
extends RefCounted

## A round tube swept along `pts` (open or closed). UV: x = metres along, y = 0..1 around.
static func tube(pts: PackedVector3Array, radius: float, sides := 8, closed := false, radii := PackedFloat32Array()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	if n < 2:
		return ArrayMesh.new()
	var count := n + (1 if closed else 0)
	var along := 0.0
	var prev_up := Vector3.UP
	var rings: Array = []
	var dists: Array = []
	for i in count:
		var p: Vector3 = pts[i % n]
		var a: Vector3 = pts[(i - 1 + n) % n] if (closed or i > 0) else p
		var b: Vector3 = pts[(i + 1) % n] if (closed or i < n - 1) else p
		var t := (b - a).normalized()
		if t.length() < 0.5:
			t = Vector3.FORWARD
		var side := t.cross(prev_up)
		if side.length() < 0.01:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(t).normalized()
		prev_up = up
		if i > 0:
			along += p.distance_to(pts[(i - 1) % n])
		var r := radius if radii.is_empty() else radii[i % n]
		var ring: Array = []
		for k in sides + 1:
			var ang := TAU * k / sides
			var d := side * cos(ang) + up * sin(ang)
			ring.append([p + d * r, d])
		rings.append(ring)
		dists.append(along)
	for i in count - 1:
		for k in sides:
			var a0: Array = rings[i][k]
			var a1: Array = rings[i][k + 1]
			var b0: Array = rings[i + 1][k]
			var b1: Array = rings[i + 1][k + 1]
			var u0: float = dists[i]
			var u1: float = dists[i + 1]
			var v0 := float(k) / sides
			var v1 := float(k + 1) / sides
			# clockwise front faces (Godot)
			for q in [[a0, u0, v0], [b1, u1, v1], [b0, u1, v0], [a0, u0, v0], [a1, u0, v1], [b1, u1, v1]]:
				var e: Array = q[0]
				st.set_normal(e[1])
				st.set_uv(Vector2(q[1], q[2]))
				st.set_color(Color(0, 0, 0, 1))
				st.add_vertex(e[0])
	st.generate_tangents()
	return st.commit()

## Rounded rectangle outline in the XZ plane at height y.
static func rounded_rect(cx: float, cz: float, w: float, d: float, r: float, y: float, seg := 6) -> PackedVector3Array:
	var out := PackedVector3Array()
	var hx := w * 0.5 - r
	var hz := d * 0.5 - r
	var corners := [Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(hx, -hz)]
	for c in 4:
		var cc: Vector2 = corners[c]
		for s in seg + 1:
			var a := PI * 0.5 * c + PI * 0.5 * s / seg
			out.append(Vector3(cx + cc.x + cos(a) * r, y, cz + cc.y + sin(a) * r))
	return out

## A hanging string between a and b that sags by `sag` metres in the middle.
static func sag_line(a: Vector3, b: Vector3, sag: float, steps := 16) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in steps + 1:
		var t := float(i) / steps
		out.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	return out
