## Prism Boulevard – the race track as data.
##
## The track is a closed ribbon, built by a "turtle" that drives through a
## list of commands (go 80 m, turn 60° left, climb 10°, bank 15°, twist …).
## Every metre the turtle leaves a sample: centre, forward, up (with banking),
## right, width and what is there (glass, starlight river, a gap, rails).
## The karts don't use the physics engine at all – they live in track space
## (s = metres along the track, x = metres to the right, h = height above the
## road). That makes loops, corkscrews and upside-down driving trivial.
extends RefCounted

const STEP := 1.0
enum { GLASS, RIVER, GAP }

var n := 0
var length := 0.0
var P := PackedVector3Array()      # centre
var T := PackedVector3Array()      # forward
var U := PackedVector3Array()      # road up (banked)
var R := PackedVector3Array()      # right
var W := PackedFloat32Array()      # width
var BANK := PackedFloat32Array()   # bank angle (deg, + = right side up)
var KG := PackedFloat32Array()     # turn curvature, + = turning right (1/m)
var KN := PackedFloat32Array()     # vertical curvature, + = valley/loop (1/m)
var SURF := PackedByteArray()
var RAIL_L := PackedByteArray()
var RAIL_R := PackedByteArray()
var HYPER := PackedByteArray()
var SEC := PackedInt32Array()
var LINE := PackedFloat32Array()   # racing line (x) for the AI
var sections: Array = []           # {name, s0, s1}
var pads: Array = []               # boost pads {s, x}
var kicks: Array = []              # ramps {s, power, glide}
var bits: Array = []               # star bits {s, x}
var rings: Array = []              # glide rings {s, x, h}

var _up_path := PackedVector3Array()   # unbanked up (internal)

## cmds: Array of Dictionaries –
##   len (m), yaw (deg, + = left), pitch (deg, + = up), bank (deg at the end,
##   + = right side up = banked for a left turn), w (width at the end),
##   ease (m, how soft curvature starts/stops; 0 = constant), surf,
##   rails ("both"/"left"/"right"/"none"), hyper, name,
##   pads [[frac, x], …], bits [[frac, x, count], …], kick {at, power, glide},
##   rings [[frac, x, h], …]
func build(cmds: Array, start_w := 18.0) -> void:
	var p := Vector3.ZERO
	var t := Vector3(0, 0, -1)
	var u := Vector3.UP
	var bank := 0.0
	var w := start_w
	for ci in cmds.size():
		var c: Dictionary = cmds[ci]
		var steps := maxi(1, int(round(float(c["len"]) / STEP)))
		var yaw := deg_to_rad(float(c.get("yaw", 0.0)))
		var pitch := deg_to_rad(float(c.get("pitch", 0.0)))
		var b0 := bank
		var b1 := float(c.get("bank", bank))
		var w0 := w
		var w1 := float(c.get("w", w))
		var ease := minf(float(c.get("ease", 18.0)), float(steps) * STEP * 0.45)
		var weights := PackedFloat32Array()
		weights.resize(steps)
		var sumw := 0.0
		for k in steps:
			var x := (k + 0.5) * STEP
			var wk := 1.0
			if ease > 0.0:
				wk = smoothstep(0.0, ease, x) * smoothstep(0.0, ease, steps * STEP - x)
			weights[k] = wk
			sumw += wk
		var s0 := P.size() * STEP
		var surf := GLASS
		match String(c.get("surf", "glass")):
			"river": surf = RIVER
			"gap": surf = GAP
		var rails := String(c.get("rails", "both"))
		var hyper := 1 if c.get("hyper", false) else 0
		# turns go around the world's up axis (so slopes stay slopes); inside a
		# loop that axis is useless, there "yaw_local" turns around the road's up
		var local_yaw: bool = c.get("yaw_local", false)
		var shift := float(c.get("shift", 0.0))     # sideways drift (m), e.g. so a loop doesn't meet itself
		for k in steps:
			var f := float(k) / float(steps)
			var e := smoothstep(0.0, 1.0, f)
			_push(p, t, u, lerpf(b0, b1, e), lerpf(w0, w1, e), surf, rails, hyper, ci)
			var dy := yaw * weights[k] / sumw
			var dp := pitch * weights[k] / sumw
			var r := t.cross(u).normalized()
			t = t.rotated(r, dp)
			u = u.rotated(r, dp)
			var ax := u if local_yaw else Vector3.UP
			t = t.rotated(ax, dy)
			u = u.rotated(ax, dy)
			r = t.cross(u).normalized()
			u = r.cross(t).normalized()
			t = t.normalized()
			p += t * STEP
			if shift != 0.0:
				var e2 := smoothstep(0.0, 1.0, float(k + 1) / float(steps))
				p += r * shift * (e2 - e)
		bank = b1
		if absf(bank) >= 359.9: bank -= signf(bank) * 360.0   # a full twist is "no bank" again
		w = w1
		var s1 := P.size() * STEP
		sections.append({"name": c.get("name", ""), "s0": s0, "s1": s1})
		var span := s1 - s0
		for pd in c.get("pads", []):
			pads.append({"s": s0 + span * float(pd[0]), "x": float(pd[1])})
		for bt in c.get("bits", []):
			var cnt := int(bt[2]) if bt.size() > 2 else 1
			for j in cnt:
				bits.append({"s": s0 + span * float(bt[0]) + j * 4.0, "x": float(bt[1])})
		for rg in c.get("rings", []):
			rings.append({"s": s0 + span * float(rg[0]), "x": float(rg[1]), "h": float(rg[2])})
		if c.has("kick"):
			var kk: Dictionary = c["kick"]
			kicks.append({"s": s0 + span * float(kk.get("at", 1.0)) - 1.0, "power": float(kk.get("power", 9.0)), "glide": kk.get("glide", false)})
	_close(p, t, u, bank, w)
	_finish()

func _push(p: Vector3, t: Vector3, u: Vector3, bank: float, w: float, surf: int, rails: String, hyper: int, sec: int) -> void:
	P.append(p); T.append(t); _up_path.append(u)
	BANK.append(bank); W.append(w); SURF.append(surf)
	RAIL_L.append(1 if rails == "both" or rails == "left" else 0)
	RAIL_R.append(1 if rails == "both" or rails == "right" else 0)
	HYPER.append(hyper); SEC.append(sec)

## the turtle ends near the start: join the two with a Hermite curve whose
## up vector is carried along and untwisted to match the start
func _close(p_end: Vector3, t_end: Vector3, u_end: Vector3, bank_end: float, w_end: float) -> void:
	var p1 := P[0]
	var t1 := T[0]
	var d := p_end.distance_to(p1)
	if d < STEP * 1.5: return
	var m0 := t_end * d * 1.15
	var m1 := t1 * d * 1.15
	var fine := 2000
	var pts := PackedVector3Array()
	var acc := PackedFloat32Array()
	var tot := 0.0
	for i in fine + 1:
		var tau := float(i) / fine
		var q := _herm(p_end, m0, p1, m1, tau)
		if i > 0: tot += q.distance_to(pts[i - 1])
		pts.append(q)
		acc.append(tot)
	var count := maxi(2, int(round(tot / STEP)))
	var u := u_end
	var prev_t := t_end
	var new_p := PackedVector3Array()
	var new_t := PackedVector3Array()
	var new_u := PackedVector3Array()
	var j := 0
	for k in range(1, count):
		var target := tot * k / count
		while j < fine - 1 and acc[j + 1] < target: j += 1
		var f := (target - acc[j]) / maxf(acc[j + 1] - acc[j], 1e-6)
		var q := pts[j].lerp(pts[j + 1], f)
		var tq := (pts[j + 1] - pts[j]).normalized()
		# parallel transport of the up vector
		var axis := prev_t.cross(tq)
		if axis.length() > 1e-7:
			u = u.rotated(axis.normalized(), prev_t.angle_to(tq))
		u = (u - tq * u.dot(tq)).normalized()
		prev_t = tq
		new_p.append(q); new_t.append(tq); new_u.append(u)
	# untwist: rotate so the last up matches the start's up
	var u_start := _up_path[0]
	var last_t := t1
	var last_u := u.rotated(prev_t.cross(last_t).normalized(), prev_t.angle_to(last_t)) if prev_t.cross(last_t).length() > 1e-7 else u
	var twist := last_u.signed_angle_to(u_start, last_t)
	for k in new_p.size():
		var f := float(k + 1) / float(count)
		var e := smoothstep(0.0, 1.0, f)
		var uu := new_u[k].rotated(new_t[k], twist * e)
		_push(new_p[k], new_t[k], uu, lerpf(bank_end, BANK[0], e), lerpf(w_end, W[0], e), GLASS, "both", 0, -1)
	sections.append({"name": "closing", "s0": (P.size() - new_p.size()) * STEP, "s1": P.size() * STEP})

func _herm(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return p0 * (2 * t3 - 3 * t2 + 1) + m0 * (t3 - 2 * t2 + t) + p1 * (-2 * t3 + 3 * t2) + m1 * (t3 - t2)

func _finish() -> void:
	n = P.size()
	length = n * STEP
	U.resize(n); R.resize(n); KG.resize(n); KN.resize(n); LINE.resize(n)
	# the real direction of travel (sideways drifts and the closing curve
	# included), then the up vectors made square to it again
	var tt := PackedVector3Array()
	tt.resize(n)
	for i in n:
		tt[i] = (P[(i + 1) % n] - P[(i - 1 + n) % n]).normalized()
	T = tt
	for i in n:
		var t := T[i]
		var up := (_up_path[i] - t * _up_path[i].dot(t)).normalized()
		var u := up.rotated(t, -deg_to_rad(BANK[i]))
		var r := t.cross(u).normalized()
		u = r.cross(t).normalized()
		U[i] = u
		R[i] = r
	for i in n:
		var dt := (T[(i + 1) % n] - T[(i - 1 + n) % n]) / (2.0 * STEP)
		KG[i] = dt.dot(R[i])
		KN[i] = dt.dot(U[i])
	# racing line: towards the inside of upcoming turns
	var sm := PackedFloat32Array()
	sm.resize(n)
	for i in n:
		var a := 0.0
		var c := 0
		for k in range(-25, 45, 2):
			a += KG[(i + k + n) % n]
			c += 1
		sm[i] = a / c
	for i in n:
		var lim := W[i] * 0.5 - 2.6
		LINE[i] = clampf(sm[i] * 75.0, -1.0, 1.0) * lim

# ------------------------------------------------------------------ sampling
func wrap_s(s: float) -> float:
	return fposmod(s, length)

func idx(s: float) -> int:
	return int(floorf(wrap_s(s) / STEP)) % n

## the road frame at s: basis (x = right, y = up, z = backwards), origin = centre
func frame(s: float) -> Transform3D:
	var ss := wrap_s(s) / STEP
	var i := int(floorf(ss)) % n
	var j := (i + 1) % n
	var f := ss - floorf(ss)
	var p := P[i].lerp(P[j], f)
	var t := T[i].lerp(T[j], f).normalized()
	var u := U[i].lerp(U[j], f)
	var r := t.cross(u).normalized()
	u = r.cross(t).normalized()
	return Transform3D(Basis(r, u, -t), p)

func point(s: float, x: float, h := 0.0) -> Vector3:
	var fr := frame(s)
	return fr.origin + fr.basis.x * x + fr.basis.y * h

func lerp_f(arr: PackedFloat32Array, s: float) -> float:
	var ss := wrap_s(s) / STEP
	var i := int(floorf(ss)) % n
	return lerpf(arr[i], arr[(i + 1) % n], ss - floorf(ss))

func width(s: float) -> float: return lerp_f(W, s)
func kg(s: float) -> float: return lerp_f(KG, s)
func kn(s: float) -> float: return lerp_f(KN, s)
func line(s: float) -> float: return lerp_f(LINE, s)
func surf(s: float) -> int: return SURF[idx(s)]
func rail(s: float, side: int) -> bool:
	return (RAIL_R if side > 0 else RAIL_L)[idx(s)] == 1
func is_hyper(s: float) -> bool: return HYPER[idx(s)] == 1
func section_at(s: float) -> String:
	var i := SEC[idx(s)]
	return String(sections[i]["name"]) if i >= 0 else "closing"
func section_s(name: String) -> Vector2:
	for sc in sections:
		if sc["name"] == name: return Vector2(sc["s0"], sc["s1"])
	return Vector2.ZERO

## nearest s to a world point (brute force on a coarse grid, then refined)
func nearest_s(p: Vector3, hint := -1.0, window := 60.0) -> float:
	var best := 0
	var bd := INF
	if hint < 0.0:
		for i in range(0, n, 4):
			var d := P[i].distance_squared_to(p)
			if d < bd: bd = d; best = i
	else:
		var c := idx(hint)
		for k in range(-int(window), int(window)):
			var i := (c + k + n) % n
			var d := P[i].distance_squared_to(p)
			if d < bd: bd = d; best = i
	for k in range(-4, 5):
		var i := (best + k + n) % n
		var d := P[i].distance_squared_to(p)
		if d < bd: bd = d; best = i
	return best * STEP
