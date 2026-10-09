## Little lives all along the way: felt butterflies, a snail on the trim, a
## ladybird on the hedge, windmills on the hills behind, a patchwork balloon
## drifting by, birds, a cottage with a cotton-wool chimney smoke.
## Nothing here matters for the game – it is there to be noticed.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")

var w: Node3D
var root: Node3D
var butterflies: Array = []   # [node, home, phase, wing_l, wing_r, speed]
var snails: Array = []        # [node, x0, x1, speed, z]
var bugs: Array = []          # [node, centre, r, speed, phase]
var mills: Array = []         # [blades node, speed]
var balloons: Array = []      # [node, base, speed]
var birds: Array = []         # [node, base, speed, phase, wing_l, wing_r]
var smoke: Array = []         # [puff, base, phase]

func build() -> void:
	root = Node3D.new()
	root.name = "Life"
	w.add_child(root)
	var cols := [Kit.PINK, Kit.MUSTARD, Kit.SKY, Kit.LILAC, Kit.CORAL, Kit.CREAM]
	var spots := [14.0, 19.0, 27.0, 33.0, 41.0, 47.0, 53.0, 64.0, 70.0, 77.0, 133.0, 160.0, 277.0, 284.0, 323.0, 331.0, 367.0, 389.0]
	for i in spots.size():
		var z: float = [2.2, -1.9, 1.6, -2.3][i % 4]
		var y := 1.2 + 0.6 * sin(i * 1.7)
		var sx: float = spots[i]
		if sx > 360.0:
			y = 2.2
			z = 1.8
		_butterfly(Vector3(sx, y, z), cols[i % cols.size()], i)
	_snail(14.0, 24.0, 0.0)
	_snail(48.6, 55.4, 3.4)
	_snail(158.0, 166.0, 0.0)
	_ladybird(Vector3(35.0, 1.8, 2.3), 0.5)
	_ladybird(Vector3(37.6, 0.9, 2.3), 0.35)
	_ladybird(Vector3(282.0, 1.3, -0.9), 0.25)
	# on the hills behind
	_windmill(Vector3(58.0, 3.6, -19.6), 1.0)
	_windmill(Vector3(214.0, 3.0, -19.6), 0.8)
	_windmill(Vector3(352.0, 3.4, -19.6), 0.9)
	_cottage(Vector3(128.0, 2.4, -19.4))
	_cottage(Vector3(268.0, 2.8, -19.4))
	_balloon(Vector3(30.0, 16.0, -34.0), 0.35)
	_balloon(Vector3(190.0, 19.0, -40.0), 0.25)
	_balloon(Vector3(300.0, 15.0, -30.0), 0.3)
	for i in 4:
		_birds(Vector3(40.0 + i * 85.0, 14.0 + 3.0 * sin(i * 2.1), -14.0), i)

func _wing_poly(big: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in 18:
		var a := PI * k / 17.0 - PI * 0.5
		var r := big * (0.8 + 0.35 * cos(a * 2.0))
		p.append(Vector2(cos(a) * r * 1.1, sin(a) * r))
	p.append(Vector2(0, 0))
	return p

func _butterfly(home: Vector3, col: Color, i: int) -> void:
	var n := Node3D.new()
	n.position = home
	root.add_child(n)
	var wl := Node3D.new()
	var wr := Node3D.new()
	n.add_child(wl)
	n.add_child(wr)
	Kit.felt_cutout(wl, _wing_poly(0.16), 0.012, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO), col, 6.0)
	Kit.felt_cutout(wl, Kit.circle(0.035, 8, 0.08, 0.05), 0.012, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.007, 0, 0)), Kit.CREAM, 6.0)
	Kit.felt_cutout(wr, _wing_poly(0.16), 0.012, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), col, 6.0)
	Kit.felt_cutout(wr, Kit.circle(0.035, 8, -0.08, 0.05), 0.012, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.007, 0, 0)), Kit.CREAM, 6.0)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = 0.025; cm.height = 0.2
	body.mesh = cm
	body.rotation.x = PI * 0.5
	body.material_override = Kit.fabric(Kit.NAVY, Kit.T_FELT, 8.0, 1.0)
	n.add_child(body)
	for s: float in [-1.0, 1.0]:
		var ant := MeshInstance3D.new()
		var am := CylinderMesh.new(); am.top_radius = 0.004; am.bottom_radius = 0.004; am.height = 0.1
		ant.mesh = am
		ant.position = Vector3(s * 0.02, 0.03, -0.12)
		ant.rotation = Vector3(-0.9, 0, s * 0.4)
		ant.material_override = body.material_override
		n.add_child(ant)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	butterflies.append([n, home, i * 1.37, wl, wr, 0.6 + 0.25 * sin(i * 3.1)])

func _snail(x0: float, x1: float, top: float) -> void:
	var n := Node3D.new()
	root.add_child(n)
	var shell := PackedVector2Array()
	for k in 40:
		var a := TAU * k / 40.0
		shell.append(Vector2(cos(a) * 0.14, 0.14 + sin(a) * 0.13))
	Kit.felt_cutout(n, shell, 0.08, Transform3D(), Kit.CORAL.lightened(0.1), 6.0)
	# a stitched spiral on the shell
	var sp := PackedVector3Array()
	for k in 30:
		var a := k * 0.5
		var r := 0.11 * (1.0 - k / 30.0)
		sp.append(Vector3(cos(a) * r, 0.14 + sin(a) * r, 0.045))
	var spm := MeshInstance3D.new()
	spm.mesh = (load("res://levels/plush_desk/geo.gd") as GDScript).call("tube", sp, 0.008, 4)
	spm.material_override = Kit.fabric(Kit.CREAM, Kit.T_KNIT, 10.0, 0.8)
	n.add_child(spm)
	var foot := PackedVector2Array([Vector2(-0.16, 0.0), Vector2(0.18, 0.0), Vector2(0.26, 0.05), Vector2(0.24, 0.12),
		Vector2(0.18, 0.1), Vector2(0.12, 0.04), Vector2(-0.16, 0.03)])
	Kit.felt_cutout(n, foot, 0.06, Transform3D(Basis(), Vector3(0, 0, -0.01)), Color(0.95, 0.85, 0.6), 6.0)
	for s: float in [0.0, 1.0]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new(); em.radius = 0.018; em.height = 0.036
		e.mesh = em
		e.position = Vector3(0.24 + s * 0.02, 0.2, 0.0 + s * 0.02)
		var dm := StandardMaterial3D.new(); dm.albedo_color = Color(0.15, 0.12, 0.15)
		e.material_override = dm
		n.add_child(e)
	n.scale = Vector3.ONE * 1.3
	snails.append([n, x0, x1, 0.12, top])

func _ladybird(c: Vector3, r: float) -> void:
	var n := Node3D.new()
	n.position = c
	root.add_child(n)
	Kit.felt_cutout(n, Kit.circle(0.09, 20), 0.05, Transform3D(), Color(0.85, 0.2, 0.2), 6.0)
	Kit.felt_cutout(n, Kit.circle(0.045, 12, 0.08, 0.0), 0.05, Transform3D(Basis(), Vector3(0, 0, -0.005)), Color(0.15, 0.12, 0.15), 6.0)
	for d in [[-0.03, 0.04], [0.02, -0.04], [-0.04, -0.02], [0.03, 0.03]]:
		Kit.felt_cutout(n, Kit.circle(0.017, 8, d[0], d[1]), 0.01, Transform3D(Basis(), Vector3(0, 0, 0.03)), Color(0.15, 0.12, 0.15), 6.0)
	bugs.append([n, c, r, 0.4, randf() * TAU])

func _windmill(p: Vector3, s: float) -> void:
	var n := Node3D.new()
	n.position = p
	n.scale = Vector3.ONE * s
	root.add_child(n)
	Kit.felt_cutout(n, PackedVector2Array([Vector2(-0.9, 0), Vector2(0.9, 0), Vector2(0.55, 4.2), Vector2(-0.55, 4.2)]), 0.4, Transform3D(), Kit.CREAM, 1.2)
	Kit.felt_cutout(n, PackedVector2Array([Vector2(-0.8, 4.1), Vector2(0.8, 4.1), Vector2(0.0, 5.2)]), 0.45, Transform3D(), Kit.CORAL, 1.2)
	Kit.felt_cutout(n, Kit.rect(0.45, 0.8, 0, 0.4), 0.45, Transform3D(Basis(), Vector3(0, 0, 0.02)), Kit.SOIL, 1.2)
	var blades := Node3D.new()
	blades.position = Vector3(0, 3.9, 0.35)
	n.add_child(blades)
	for k in 4:
		var bl := PackedVector2Array([Vector2(0.1, -0.12), Vector2(2.6, -0.32), Vector2(2.6, 0.32), Vector2(0.1, 0.12)])
		Kit.felt_cutout(blades, bl, 0.06, Transform3D(Basis(Vector3.BACK, k * PI * 0.5), Vector3.ZERO), [Kit.MUSTARD, Kit.CREAM][k % 2], 2.0)
	Kit.felt_cutout(blades, Kit.circle(0.25, 12), 0.1, Transform3D(Basis(), Vector3(0, 0, 0.05)), Kit.CORAL, 2.0)
	mills.append([blades, 0.4 + 0.2 * s])

func _cottage(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	root.add_child(n)
	Kit.felt_cutout(n, Kit.rect(3.0, 2.0, 0, 1.0), 0.4, Transform3D(), Kit.CREAM.lightened(0.05), 1.2)
	Kit.felt_cutout(n, PackedVector2Array([Vector2(-1.8, 1.9), Vector2(1.8, 1.9), Vector2(0, 3.4)]), 0.45, Transform3D(), Kit.CORAL.darkened(0.1), 1.2)
	Kit.felt_cutout(n, Kit.rect(0.4, 0.9, 0.9, 2.9), 0.4, Transform3D(Basis(), Vector3(0, 0, -0.05)), Kit.SOIL, 1.2)
	Kit.felt_cutout(n, Kit.rect(0.6, 1.0, -0.6, 0.5), 0.42, Transform3D(Basis(), Vector3(0, 0, 0.02)), Kit.TEAL, 1.2)
	Kit.felt_cutout(n, Kit.rect(0.6, 0.55, 0.65, 1.15), 0.42, Transform3D(Basis(), Vector3(0, 0, 0.02)), Color(1.0, 0.88, 0.55), 1.2)
	for i in 4:
		var puff := Kit.cloud(n, Vector3(0.9, 3.6 + i * 0.6, 0.1), 0.6, false)
		puff.scale = Vector3.ONE * (0.4 + i * 0.15)
		smoke.append([puff, Vector3(0.9, 3.6, 0.1), i * 0.25])

func _balloon(p: Vector3, speed: float) -> void:
	var n := Node3D.new()
	n.position = p
	root.add_child(n)
	var cols := [Kit.CORAL, Kit.MUSTARD, Kit.TEAL, Kit.PINK, Kit.LILAC, Kit.CREAM]
	# patchwork envelope: wedges of felt
	for k in 6:
		var wedge := PackedVector2Array()
		for j in 9:
			var aa := lerpf(-PI + PI * k / 6.0, -PI + PI * (k + 1) / 6.0, j / 8.0)
			wedge.append(Vector2(cos(aa) * 2.2, -sin(aa) * 2.4 + 0.2))
		wedge.append(Vector2(0, -2.5))
		Kit.felt_cutout(n, wedge, 0.5, Transform3D(), cols[k], 0.8)
	Kit.felt_cutout(n, Kit.rect(0.9, 0.7, 0, -3.5), 0.5, Transform3D(), Color(0.7, 0.5, 0.32), 0.8)
	for s: float in [-0.35, 0.35]:
		Kit.felt_cutout(n, Kit.rect(0.05, 0.9, s, -2.9), 0.05, Transform3D(Basis(), Vector3(0, 0, 0.3)), Kit.CREAM, 0.8)
	balloons.append([n, p, speed])

func _birds(p: Vector3, i: int) -> void:
	for k in 3:
		var n := Node3D.new()
		n.position = p + Vector3(-k * 1.1, -absf(k - 1.0) * 0.4 + (0.4 if k == 1 else 0.0), 0)
		root.add_child(n)
		var wl := Node3D.new()
		var wr := Node3D.new()
		n.add_child(wl)
		n.add_child(wr)
		var wing := PackedVector2Array([Vector2(0, 0), Vector2(0.55, 0.18), Vector2(0.5, 0.05)])
		Kit.felt_cutout(wl, wing, 0.03, Transform3D(), Kit.NAVY.lightened(0.2), 4.0)
		var wing2 := PackedVector2Array([Vector2(0, 0), Vector2(-0.5, 0.05), Vector2(-0.55, 0.18)])
		Kit.felt_cutout(wr, wing2, 0.03, Transform3D(), Kit.NAVY.lightened(0.2), 4.0)
		birds.append([n, n.position, 0.9, i * 1.3 + k * 0.4, wl, wr])

func update(delta: float) -> void:
	var t: float = w.t
	var lp: Vector3 = w.claude_local()
	for b in butterflies:
		var n: Node3D = b[0]
		var home: Vector3 = b[1]
		if absf(home.x - lp.x) > 40.0:
			continue
		var ph: float = b[2]
		var sp: float = b[5]
		var p := home + Vector3(sin(t * 0.5 * sp + ph) * 1.6, sin(t * 1.3 * sp + ph * 2.0) * 0.45, cos(t * 0.37 * sp + ph) * 0.7)
		# they flutter away a little when Claude comes close
		var away := p - (lp + Vector3(0, 0.8, 0))
		if away.length() < 1.6:
			p += away.normalized() * (1.6 - away.length())
		var dir := p - n.position
		n.position = p
		if dir.length() > 0.001:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-dir.x, -dir.z), 0.2)
		var flap := sin(t * 18.0 * sp + ph) * 0.9
		(b[3] as Node3D).rotation.z = flap
		(b[4] as Node3D).rotation.z = -flap
	for s in snails:
		var n2: Node3D = s[0]
		var x0: float = s[1]
		var x1: float = s[2]
		var span := x1 - x0
		var k := fmod(t * float(s[3]), span * 2.0)
		var x := x0 + (k if k < span else span * 2.0 - k)
		var face := 1.0 if k < span else -1.0
		n2.position = Vector3(x, float(s[4]) + 0.0, 2.32)
		n2.scale = Vector3(1.3 * face, 1.3 + sin(t * 3.0) * 0.04, 1.3)
	for g in bugs:
		var n3: Node3D = g[0]
		var c: Vector3 = g[1]
		var r: float = g[2]
		var a := t * float(g[3]) + float(g[4])
		n3.position = c + Vector3(cos(a) * r, sin(a * 1.3) * r * 0.5, 0)
		n3.rotation.z = a + PI * 0.5
	for m in mills:
		(m[0] as Node3D).rotation.z -= delta * float(m[1])
	for bl in balloons:
		var n4: Node3D = bl[0]
		var base: Vector3 = bl[1]
		n4.position = base + Vector3(t * float(bl[2]), sin(t * 0.3 + base.x) * 0.8, 0)
		n4.rotation.z = sin(t * 0.5 + base.x) * 0.04
	for bd in birds:
		var n5: Node3D = bd[0]
		var base2: Vector3 = bd[1]
		n5.position = base2 + Vector3(fmod(t * float(bd[2]), 120.0), sin(t * 0.8 + float(bd[3])) * 0.3, 0)
		var f := sin(t * 7.0 + float(bd[3])) * 0.7
		(bd[4] as Node3D).rotation.z = f
		(bd[5] as Node3D).rotation.z = -f
	for sm in smoke:
		var puff: Node3D = sm[0]
		var base3: Vector3 = sm[1]
		var k2 := fmod(t * 0.25 + float(sm[2]), 1.0)
		puff.position = base3 + Vector3(k2 * 1.2 + sin(t + k2 * 5.0) * 0.1, k2 * 2.6, 0)
		puff.scale = Vector3.ONE * (0.3 + k2 * 0.8)
