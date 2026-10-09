## The yarn tower: a giant cotton reel with a chunky strand of wool wound
## round it twice. The course leaves the three layers and spirals up the
## strand, the camera circles with Claude. Gaps, knitting needles that poke
## out of the reel, a pom-pom to bounce on, bobbing buttons. At the top a
## button on a thread: hold on, and ride it all the way down to the stage.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const Geo := preload("res://levels/plush_desk/geo.gd")
const YARN := preload("res://levels/plush_desk/shaders/yarn.gdshader")
const A := "res://levels/plush_desk/audio/"

const TX := 340.0           # the reel's axis
const TZ := -3.25
const RT := 2.6             # wound core radius
const RP := 3.25            # where Claude walks (the top of the strand)
const SR := 0.5             # strand radius
const H := 6.0              # rise per turn
const U_END := 2.0          # turns of strand
const ZIP_A := Vector3(TX + 3.6, 13.35, 0.0)
const ZIP_B := Vector3(364.5, 3.4, 0.0)

var w: Node3D
var root: Node3D
var needles: Array = []      # {"u", "y", "node", "slide", "period", "phase", "k", "high"}
var bobbers: Array = []      # [body, base]
var pom: Node3D
var on_tower := false
var theta := 0.0             # unwrapped angle of Claude around the reel
var _cam_th := 0.0
var _cam_y := 0.0
var _cam_blend := 0.0
var _cam_from := Transform3D()
var _floor_y := 0.0
var _said := {}
# zipline
var zip_button: Node3D
var zip_s := -1.0            # -1 waiting, 0..1 riding, 2 done
var zip_v := 0.0
var _zip_cam_from := Transform3D()
var _zip_t := 0.0
var strand_mat: ShaderMaterial
var _locked := false

func h(u: float) -> float:
	return H * u

## a point on Claude's path at u turns (y = top of the strand + dy)
func at(u: float, dy := 0.0, r := RP) -> Vector3:
	var th := u * TAU
	return Vector3(TX + r * sin(th), h(u) + dy, TZ + r * cos(th))

func build() -> void:
	root = Node3D.new()
	root.name = "Tower"
	w.add_child(root)
	strand_mat = ShaderMaterial.new()
	strand_mat.shader = YARN
	strand_mat.set_shader_parameter("albedo", Kit.MUSTARD)
	strand_mat.set_shader_parameter("albedo2", Color(0.98, 0.85, 0.5))
	strand_mat.set_shader_parameter("two_tone", 1.0)
	strand_mat.set_shader_parameter("plies", 4.0)
	strand_mat.set_shader_parameter("twist", 0.9)
	strand_mat.set_shader_parameter("fibre_tex", Kit.T_KNIT)
	strand_mat.set_shader_parameter("mottle_tex", Kit.T_MOTTLE)
	strand_mat.set_shader_parameter("fibre_scale", 4.0)
	strand_mat.set_shader_parameter("sheen_color", Color(1.0, 0.95, 0.8))
	# the ground in front of the reel
	Kit.block(root, Vector3(334.0, -1.5, 0.0), Vector3(16.0, 3.0, 4.2), Kit.SOIL, Kit.GRASS, 4, true)
	Kit.trim(root, 326.05, 341.95, 0.0, 2.2, Kit.GRASS.darkened(0.12), "pinking")
	Kit.dress_front(root, 326.0, 342.0, 0.0, 2.19, [Kit.SOIL.darkened(0.12), Kit.SOIL.lightened(0.1), Kit.MUSTARD.darkened(0.1)], 7.0)
	w.checkpoint(Vector3(330.5, 0.0, 0.0), 1, Kit.LILAC)
	w.narrate_at(331.0, "The yarn tower. Whoever wound this had a lot of patience. And a lot of yarn.", 3.6)
	_sign()
	_reel()
	# --- the strand, in pieces with gaps between them
	var segs := [[0.0, 0.30], [0.355, 0.64], [0.72, 1.0], [1.2, 1.36], [1.52, U_END + 0.02]]
	for sg in segs:
		_strand(float(sg[0]), float(sg[1]))
	# spools along the way (arcs over the gaps)
	var su := 0.04
	while su < U_END:
		var in_gap := (su > 0.3 and su < 0.355) or (su > 0.64 and su < 0.72) or (su > 1.0 and su < 1.2) or (su > 1.36 and su < 1.52)
		var lift := 0.8
		if in_gap:
			lift = 1.3
		w.spool(at(su, lift))
		su += 0.045 if not in_gap else 0.03
	# --- knitting needles poking out of the reel
	_needle(0.45, 0.35, 2.6, 0.0, false)
	_needle(0.56, 0.35, 2.6, 1.3, false)
	_needle(1.63, 0.85, 2.6, 0.0, true)
	_needle(1.74, 0.35, 2.6, 1.3, false)
	_needle(1.85, 0.85, 2.6, 0.6, true)
	_needle(1.95, 0.35, 2.6, 1.9, false)
	# --- checkpoints on the strand
	w.checkpoint_free(at(0.76, 0.0), at(0.76, -0.25, RT + 0.12), Kit.TEAL, 348.0)
	w.checkpoint_free(at(1.555, 0.0), at(1.555, -0.25, RT + 0.12), Kit.PINK, 356.0)
	# --- the pom-pom over the big gap
	_pompom(1.06)
	# --- bobbing buttons
	for bu: float in [1.41, 1.47]:
		var body := AnimatableBody3D.new()
		body.position = at(bu, -0.15)
		root.add_child(body)
		Kit.button(body, Vector3.ZERO, 0.62, [Kit.CORAL, Kit.TEAL][bobbers.size() % 2], bu * 9.0, false)
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new(); cy.radius = 0.62; cy.height = 0.16
		cs.shape = cy
		cs.position.y = 0.08
		body.add_child(cs)
		# a little shelf of felt under each, so they look stuck on
		bobbers.append([body, body.position])
	# --- the top: a landing pad, a big pin and the zipline
	Kit.block(root, Vector3(TX + 2.0, h(U_END) - 0.3, 0.0), Vector3(4.0, 0.6, 1.7), Kit.LILAC, Kit.CREAM, 2, true)
	var anchor := Kit.pin(root, Vector3(TX + 3.9, h(U_END), -0.45), Kit.CORAL)
	anchor.scale = Vector3.ONE * 0.9
	var line := Geo.sag_line(ZIP_A, ZIP_B, 0.6, 40)
	var lm := MeshInstance3D.new()
	lm.mesh = Geo.tube(line, 0.035, 6)
	lm.material_override = Kit.fabric(Kit.CREAM, Kit.T_KNIT, 12.0, 0.8)
	root.add_child(lm)
	zip_button = Node3D.new()
	zip_button.position = ZIP_A + Vector3(0.6, -0.35, 0)
	root.add_child(zip_button)
	var bt := Kit.button_upright(zip_button, Vector3(0, -0.15, 0.0), 0.32, Kit.MUSTARD)
	bt.rotation.z = 0.0
	var loop := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.07; tm.outer_radius = 0.11; tm.rings = 16; tm.ring_segments = 6
	loop.mesh = tm
	loop.rotation.x = PI * 0.5
	loop.position.y = 0.25
	loop.material_override = Kit.fabric(Kit.CREAM, Kit.T_KNIT, 12.0, 0.8)
	zip_button.add_child(loop)
	for k in 6:
		w.spool(ZIP_A.lerp(ZIP_B, 0.15 + k * 0.14) + Vector3(0, -1.4 - 0.6 * sin((0.15 + k * 0.14) * PI), 0))
	_panorama()

## a cardboard sign at the foot of the tower
func _sign() -> void:
	var n := Node3D.new()
	n.position = Vector3(335.6, 0.0, -1.0)
	n.rotation.y = 0.15
	root.add_child(n)
	Kit.block(n, Vector3(0, 0.6, 0), Vector3(0.12, 1.2, 0.12), Color(0.62, 0.42, 0.3), Kit.CREAM, 0, false)
	Kit.cutout(n, Kit.rect(2.1, 0.75, 0, 1.45), 0.06, Transform3D(Basis(Vector3.FORWARD, 0.04), Vector3.ZERO), Color(0.97, 0.92, 0.8, 1.0))
	Kit.label(n, "THE YARN TOWER", Vector3(0, 1.48, 0.05), 0.0042, Color(0.3, 0.2, 0.32), 64).rotation.z = 0.04
	Kit.label(n, "↑ mind the needles", Vector3(0, 1.22, 0.05), 0.0028, Kit.CORAL.darkened(0.2), 64).rotation.z = 0.04

## the cotton reel: wooden flanges, thread wound round the core, a ball of
## wool on the top with two needles stuck through
func _reel() -> void:
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = RT; cm.bottom_radius = RT; cm.height = 15.0; cm.radial_segments = 48; cm.rings = 8
	core.mesh = cm
	core.position = Vector3(TX, 7.0, TZ)
	var wm := ShaderMaterial.new()
	wm.shader = YARN
	wm.set_shader_parameter("mode", 1.0)
	wm.set_shader_parameter("albedo", Kit.CORAL)
	wm.set_shader_parameter("albedo2", Kit.PINK)
	wm.set_shader_parameter("bands", 2.2)
	wm.set_shader_parameter("wind_pitch", 0.075)
	wm.set_shader_parameter("fibre_tex", Kit.T_KNIT)
	wm.set_shader_parameter("mottle_tex", Kit.T_MOTTLE)
	wm.set_shader_parameter("fibre_scale", 5.0)
	core.material_override = wm
	root.add_child(core)
	var sb := StaticBody3D.new()
	sb.position = core.position
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new(); cy.radius = RT; cy.height = 15.0
	cs.shape = cy
	sb.add_child(cs)
	root.add_child(sb)
	# wooden flange at the foot
	var wood := Kit.card_material(0, Color(0.72, 0.5, 0.32, 0.85))
	var fl := MeshInstance3D.new()
	var fm := CylinderMesh.new(); fm.top_radius = 3.05; fm.bottom_radius = 3.15; fm.height = 0.7; fm.radial_segments = 48
	fl.mesh = fm
	fl.position = Vector3(TX, -0.25, TZ)
	fl.material_override = wood
	root.add_child(fl)
	# the ball of wool on the top
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 3.0; sm.height = 6.0; sm.radial_segments = 48; sm.rings = 24
	ball.mesh = sm
	ball.position = Vector3(TX, 16.6, TZ)
	ball.rotation = Vector3(0.5, 0.3, 0.4)
	var bm := wm.duplicate() as ShaderMaterial
	bm.set_shader_parameter("albedo", Kit.TEAL)
	bm.set_shader_parameter("albedo2", Kit.TEAL.lightened(0.2))
	bm.set_shader_parameter("bands", 1.4)
	ball.material_override = bm
	root.add_child(ball)
	for k in 2:
		# two needles stuck right through the ball, crossed
		var nd := _needle_mesh(7.0, [Kit.PINK, Kit.MUSTARD][k])
		root.add_child(nd)
		nd.basis = Basis(Vector3.UP, 0.6 + k * 1.9) * Basis(Vector3.RIGHT, -0.9 + k * 0.35)
		nd.position = Vector3(TX, 16.8, TZ) - nd.basis.z * -3.4
	# a pom-pom on the very top
	var pp := _fuzzy_ball(0.9, Kit.CREAM)
	pp.position = Vector3(TX + 0.6, 19.4, TZ - 0.3)
	root.add_child(pp)

## a strand of wool from u0 to u1 (turns), walkable on its top
func _strand(u0: float, u1: float) -> void:
	var pts := PackedVector3Array()
	var n := int((u1 - u0) * TAU * RP / 0.22) + 2
	for i in n + 1:
		var u := lerpf(u0, u1, float(i) / n)
		pts.append(at(u, -SR))
	var mesh := Geo.tube(pts, SR, 14)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = strand_mat
	root.add_child(mi)
	# what Claude walks on: a flat ribbon along the top of the strand (a round
	# trimesh has ridges that snag)
	var faces := PackedVector3Array()
	var ua := u0 - (0.02 if u0 < 0.01 else 0.0)
	var m := int((u1 - ua) * TAU * RP / 0.3) + 2
	for k in m:
		var ka := lerpf(ua, u1, float(k) / m)
		var kb := lerpf(ua, u1, float(k + 1) / m)
		var ra := Vector3(sin(ka * TAU), 0, cos(ka * TAU)) * 0.55
		var rb := Vector3(sin(kb * TAU), 0, cos(kb * TAU)) * 0.55
		var ca := at(ka, 0.0)
		var cb := at(kb, 0.0)
		faces.append_array(PackedVector3Array([ca - ra, cb - rb, cb + rb, ca - ra, cb + rb, ca + ra]))
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	cs.shape = shape
	sb.add_child(cs)
	root.add_child(sb)
	# rounded ends, a little frayed
	for e: float in [u0, u1]:
		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = SR * 0.98; sm.height = SR * 1.96; sm.radial_segments = 16; sm.rings = 8
		cap.mesh = sm
		cap.material_override = strand_mat
		cap.position = at(float(e), -SR)
		root.add_child(cap)
		if e > 0.01 and e < U_END:
			for k in 5:
				var f := MeshInstance3D.new()
				var fm := CylinderMesh.new(); fm.top_radius = 0.0; fm.bottom_radius = 0.03; fm.height = 0.35; fm.radial_segments = 4
				f.mesh = fm
				f.material_override = Kit.fabric(Kit.MUSTARD.lightened(0.15), Kit.T_KNIT, 8.0, 0.8)
				var dir := 1.0 if e == u1 else -1.0
				var tang := (at(float(e) + dir * 0.01, -SR) - at(float(e), -SR)).normalized()
				f.position = cap.position + tang * 0.45 + Vector3(0, sin(k * 1.9) * 0.25, cos(k * 2.3) * 0.25)
				f.basis = Basis(Quaternion(Vector3.UP, (tang + Vector3(0, 0.3 * sin(k * 3.1), 0)).normalized()))
				root.add_child(f)

func _needle_mesh(length: float, knob: Color) -> Node3D:
	var n := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.86, 0.68, 0.46)
	wood.roughness = 0.45
	wood.clearcoat_enabled = true
	wood.clearcoat = 0.4
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new(); sm.top_radius = 0.065; sm.bottom_radius = 0.065; sm.height = length - 0.3; sm.radial_segments = 12
	shaft.mesh = sm
	shaft.rotation.x = PI * 0.5
	shaft.position.z = -(length - 0.3) * 0.5 - 0.3
	shaft.material_override = wood
	n.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tmm := CylinderMesh.new(); tmm.top_radius = 0.0; tmm.bottom_radius = 0.065; tmm.height = 0.3; tmm.radial_segments = 12
	tip.mesh = tmm
	tip.rotation.x = -PI * 0.5
	tip.position.z = -0.15
	tip.material_override = wood
	n.add_child(tip)
	var kb := MeshInstance3D.new()
	var km := SphereMesh.new(); km.radius = 0.16; km.height = 0.32
	kb.mesh = km
	kb.position.z = -length
	var kmat := StandardMaterial3D.new()
	kmat.albedo_color = knob
	kmat.roughness = 0.2
	kmat.clearcoat_enabled = true
	kb.material_override = kmat
	n.add_child(kb)
	return n

## a needle that pokes out of the reel across the path at u (turns), dy above the strand
func _needle(u: float, dy: float, period: float, phase: float, high: bool) -> void:
	var holder := Node3D.new()
	var th := u * TAU
	holder.position = Vector3(TX, h(u) + dy, TZ)
	holder.rotation.y = th
	root.add_child(holder)
	var slide := _needle_mesh(2.8, Kit.PINK if high else Kit.TEAL)
	holder.add_child(slide)
	# the hole it comes out of: a darker knot of yarn
	var hole := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.08; tm.outer_radius = 0.2; tm.rings = 16; tm.ring_segments = 8
	hole.mesh = tm
	hole.rotation.x = PI * 0.5
	hole.position.z = RT + 0.02
	hole.material_override = Kit.fabric(Kit.CORAL.darkened(0.35), Kit.T_KNIT, 10.0, 1.0)
	holder.add_child(hole)
	needles.append({"u": u, "y": h(u) + dy, "slide": slide, "period": period, "phase": phase, "k": 0.0, "high": high, "was": false,
		"out": 0.24 if high else 0.34})

func _fuzzy_ball(r: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 24; sm.rings = 12
	mi.mesh = sm
	var mat := Kit.fabric(col, Kit.T_FELT, 4.0, 1.6).duplicate() as ShaderMaterial
	var prev: Material = mat
	for i in 3:
		var f := ShaderMaterial.new()
		f.shader = Kit.FUZZ
		f.set_shader_parameter("albedo", col)
		f.set_shader_parameter("fibre_tex", Kit.T_FELT)
		f.set_shader_parameter("mottle_tex", Kit.T_MOTTLE)
		f.set_shader_parameter("shell", float(i + 1) / 3.0)
		f.set_shader_parameter("fuzz_len", r * 0.22)
		f.set_shader_parameter("density", 3.0)
		prev.next_pass = f
		prev = f
	mi.material_override = mat
	return mi

## a pom-pom on a felt shelf over the big gap: land on it, bounce up
func _pompom(u: float) -> void:
	# its top sits half a metre under the end of the strand: walk off, boing
	var top := h(1.0) - 0.5
	var r := 0.66
	var shelf_c := at(u, 0.0, RP - 0.25)
	shelf_c.y = top - r * 2.0 + 0.1
	var shelf := Kit.block(root, Vector3.ZERO, Vector3(1.2, 0.3, 2.0), Kit.LILAC, Kit.CREAM, 0, false)
	shelf.position = shelf_c
	shelf.rotation.y = u * TAU
	pom = Node3D.new()
	pom.position = at(u, 0.0)
	pom.position.y = top - r
	root.add_child(pom)
	var ball := _fuzzy_ball(r, Kit.PINK)
	pom.add_child(ball)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(1.3, 0.3, 1.3)
	cs.shape = bs
	cs.position.y = r - 0.15
	sb.add_child(cs)
	pom.add_child(sb)
	w.add_bounce(Vector3(pom.position.x, top, pom.position.z), Vector3(1.5, 0.5, 1.5), 11.0, ball)

## felt hills all around the far side, so the camera has something to look at
## when it circles behind the reel
func _panorama() -> void:
	# felt hills all round, except where the course runs through (towards the
	# choice and towards the theatre, which then are the view)
	var cols := [Color(0.5, 0.74, 0.42), Color(0.44, 0.66, 0.52), Color(0.6, 0.66, 0.82)]
	var arcs := [[-1.22, 0.6], [2.17, 4.36]]
	for ring in 3:
		var R := 34.0 + ring * 13.0
		for arc in arcs:
			var a0: float = arc[0]
			var a1: float = arc[1]
			var n := int(ceilf((a1 - a0) * R / (R * 0.36)))
			for i in n:
				var a := lerpf(a0, a1, (float(i) + 0.5) / n)
				var c := Vector3(TX + sin(a) * R, 0.0, TZ + cos(a) * R)
				var half := R * 0.21
				var poly := Kit.hills(-half, half, -30.0, -1.0 + ring * 4.5, 1.4 + ring, 4.0 + ring * 3.0, float(i) * 1.7 + ring + a0)
				var xf := Transform3D(Basis(Vector3.UP, a + PI), c)
				Kit.felt_cutout(root, poly, 0.8, xf, cols[ring], 0.6 if ring > 0 else 0.9)
				if ring == 0 and i % 2 == 0:
					var tree := Node3D.new()
					tree.transform = Transform3D(Basis(Vector3.UP, a + PI), c + Vector3(0, -0.8, 0) - Vector3(sin(a), 0, cos(a)) * 0.8)
					root.add_child(tree)
					Kit.felt_cutout(tree, Kit.rect(0.4, 3.0, 0, 1.5), 0.3, Transform3D(), Color(0.55, 0.38, 0.26))
					Kit.felt_cutout(tree, Kit.blob(1.4, 24, 0.12, float(i)), 0.4, Transform3D(Basis(), Vector3(0, 3.2, 0.1)), Color(0.38, 0.62, 0.36), 1.0)
	for i in 4:
		var a := -0.9 + i * 0.45
		var c := Kit.cloud(root, Vector3(TX + sin(a) * 52.0, 20.0 + 4.0 * sin(i * 1.7), TZ + cos(a) * 52.0), 9.0, false)
		c.scale = Vector3.ONE * 2.2
		c.rotation.y = a + PI

# ------------------------------------------------------------------ per frame
func _theta_of(lp: Vector3) -> float:
	var th := atan2(lp.x - TX, lp.z - TZ)
	return th + TAU * roundf(lp.y / H - th / TAU)

func physics(delta: float) -> void:
	var c: Player = w.claude
	if c.in_flight:
		return
	var lp: Vector3 = w.claude_local()
	# at the foot of the tower and on the pad at the top: one layer only
	var lock := (lp.x > TX - 6.0 and lp.x < TX + 1.0) or (lp.y > 9.0 and lp.x > TX - 1.0 and lp.x < TX + 6.5)
	if lock and not on_tower:
		w.set("lane", 1)
		w.set("lane_lock", true)
		_locked = true
	elif _locked and not on_tower and not lock:
		w.set("lane_lock", false)
		_locked = false
	theta = _theta_of(lp)
	var r := Vector2(lp.x - TX, lp.z - TZ).length()
	var want := theta > 0.0 and theta < U_END * TAU + 0.03 and absf(lp.y - h(theta / TAU)) < 3.6 and absf(r - RP) < 1.3
	if want != on_tower:
		_set_on_tower(want)
	if not on_tower:
		return
	# keep her on the circle, walking along it
	var th := theta
	var radial := Vector3(sin(th), 0.0, cos(th))
	var target := Vector3(TX, lp.y, TZ) + radial * RP
	var gp: Vector3 = w.g(target)
	c.global_position.x = gp.x
	c.global_position.z = gp.z
	var v := c.velocity
	v -= radial * v.dot(radial)
	c.velocity = v
	w.set("input_yaw", th)
	if c.is_on_floor():
		_floor_y = lp.y
	elif lp.y < _floor_y - 2.6:
		w.hurt("fall")

func _set_on_tower(on: bool) -> void:
	on_tower = on
	w.set("radial", on)
	w.set("lane_lock", on)
	if on:
		if not _said.has("music"):
			_said["music"] = true
			Sound.music(A + "tower.ogg", 2.0)
		_cam_th = theta
		_cam_y = w.claude_local().y
		_cam_blend = 0.0
		_cam_from = (w.get("cam") as Camera3D).global_transform
		_floor_y = w.claude_local().y
		w.set("cam_mode", "custom")
		w.set("cam_custom", _orbit_cam)
		w.set("cam_fov", 44.0)
	else:
		w.set("input_yaw", 0.0)
		w.set("lane", 1)
		if w.get("cam_mode") == "custom" and zip_s < 0.0:
			w.set("cam_mode", "follow")
		w.set("cam_fov", 38.0)

func _orbit_cam(delta: float) -> Array:
	var lp: Vector3 = w.claude_local()
	_cam_th = lerpf(_cam_th, theta, 1.0 - exp(-3.5 * delta))
	var c: Player = w.claude
	_cam_y = lerpf(_cam_y, lp.y, 1.0 - exp(-(4.0 if c.is_on_floor() else 1.6) * delta))
	_cam_blend = minf(_cam_blend + delta / 0.8, 1.0)
	var lead := clampf(c.velocity.dot(Vector3(cos(theta), 0, -sin(theta))) * 0.06, -0.25, 0.25)
	var ct := _cam_th + lead
	var radial := Vector3(sin(ct), 0.0, cos(ct))
	var pos := Vector3(TX, _cam_y + 2.4, TZ) + radial * (RP + 9.6)
	var look := Vector3(TX, _cam_y + 0.9, TZ) + radial * (RP - 0.6)
	var gp: Vector3 = w.g(pos)
	var gl: Vector3 = w.g(look)
	var xf := Transform3D(Basis.looking_at(gl - gp, Vector3.UP), gp)
	if _cam_blend < 1.0:
		xf = _cam_from.interpolate_with(xf, smoothstep(0.0, 1.0, _cam_blend))
	return [xf, gp.distance_to(c.global_position)]

func update(delta: float) -> void:
	var lp: Vector3 = w.claude_local()
	var c: Player = w.claude
	var t: float = w.t
	# needles: wiggle, poke out, stay, slide back in
	for nd in needles:
		var ph := fmod(t + float(nd.phase), float(nd.period)) / float(nd.period)
		var k := 0.0
		var wig := 0.0
		var o_end := 0.2 + float(nd.out)
		if ph < 0.12:
			wig = sin(ph / 0.12 * PI * 6.0) * 0.05
		elif ph < 0.2:
			k = smoothstep(0.12, 0.2, ph)
		elif ph < o_end:
			k = 1.0
		elif ph < o_end + 0.12:
			k = 1.0 - smoothstep(o_end, o_end + 0.12, ph)
		nd.k = k
		var slide: Node3D = nd.slide
		slide.position = Vector3(wig, 0.0, lerpf(RT - 0.05, RP + 1.25, k))
		var out := k > 0.5
		if out and not nd.was and absf((theta / TAU - float(nd.u)) * TAU * RP) < 6.0:
			Sound.sfx(A + "click.ogg", -10.0, 0.7)
		nd.was = out
		if on_tower and k > 0.3:
			var arc := (theta / TAU - float(nd.u)) * TAU * RP
			var ny: float = nd.y
			if absf(arc) < 0.32 and lp.y < ny + 0.1 and lp.y + 1.0 > ny - 0.1:
				w.hurt("needle")
	# bobbing buttons
	for i in bobbers.size():
		var body: AnimatableBody3D = bobbers[i][0]
		var base: Vector3 = bobbers[i][1]
		body.position = base + Vector3(0, sin(t * 1.6 + i * PI) * 0.55, 0)
		body.rotation.y = t * 0.4 * (1.0 if i == 0 else -1.0)
	if pom:
		pom.rotation.y = sin(t * 0.8) * 0.3
	# narration on the way up
	if on_tower:
		var u := theta / TAU
		_line(u, 0.33, "up", "Up we go. Round and round. Try not to think about it.", 3.2)
		_line(u, 0.4, "needles", "Knitting needles. They come and go. Jump them, or wait for them.", 3.4)
		_line(u, 0.95, "pom", "A pom-pom. Bouncier than it looks. Which is very bouncy.", 3.0)
		_line(u, 1.58, "rhythm", "The pink ones are too high to jump. Count. One, two... go.", 3.4)
		_line(u, 1.95, "top", "The top. What a view. Now grab that button and hold on tight.", 3.4)
	_zipline(delta, lp)

## a line when Claude passes u; long past it (a pin further up), stay quiet
func _line(u: float, at_u: float, key: String, text: String, hold: float) -> void:
	if u > at_u and not _said.has(key):
		_said[key] = true
		if u < at_u + 0.12:
			w.narrate(text, hold)

# ------------------------------------------------------------------ the zipline
func _zipline(delta: float, lp: Vector3) -> void:
	var c: Player = w.claude
	if zip_s < 0.0:
		var bp := ZIP_A + Vector3(0.6, -0.35 + sin(w.t * 1.7) * 0.04, 0)
		zip_button.position = bp
		var near := absf(lp.x - bp.x) < 1.0 and lp.y > bp.y - 2.2 and lp.y < bp.y + 0.3 and absf(lp.z) < 0.8
		if near:
			w.prompt("E · hold on!")
			if Input.is_action_just_pressed("interact"):
				_grab()
		elif lp.x > TX + 0.5 and lp.y > 10.0:
			w.prompt("")
		return
	if zip_s > 1.5:
		return
	_zip_t += delta
	zip_v = minf(zip_v + delta * 5.5, 13.0)
	var line_len := ZIP_A.distance_to(ZIP_B)
	zip_s = minf(zip_s + zip_v * delta / line_len, 1.0)
	var p := ZIP_A.lerp(ZIP_B, zip_s) + Vector3(0, -0.6 * 4.0 * zip_s * (1.0 - zip_s), 0) + Vector3(0.6, -0.35, 0)
	zip_button.position = p
	zip_button.rotation.z = -0.3 * minf(zip_v / 8.0, 1.0)
	var hang: Vector3 = w.g(p + Vector3(0, -1.25, 0))
	c.global_position = hang
	c.velocity = Vector3.ZERO
	c.rig.rotation = Vector3(0.0, lerp_angle(c.rig.rotation.y, -PI * 0.5 + 0.35, 1.0 - exp(-5.0 * delta)), sin(_zip_t * 2.4) * 0.12 - 0.2)
	c.rig.animate(delta, Vector3(0, 0, -zip_v * 0.2), false)
	if int(_zip_t * 20.0) % 3 == 0:
		w.call("_sparkle", p + Vector3(randf_range(-0.2, 0.2), 0.0, 0.0))
	if zip_s >= 1.0:
		_release()

func _grab() -> void:
	var c: Player = w.claude
	zip_s = 0.0
	zip_v = 2.0
	_zip_t = 0.0
	w.prompt("")
	c.in_flight = true
	c.control_enabled = false
	c.rig.mood = RobotRig.Mood.HAPPY
	Sound.sfx(A + "click.ogg", -4.0, 1.2)
	Sound.sfx(A + "whoosh.ogg", -2.0, 0.8)
	Sound.loop("wind_loop", -9.0, 0.4)
	_zip_cam_from = (w.get("cam") as Camera3D).global_transform
	w.set("cam_mode", "custom")
	w.set("cam_custom", _zip_cam)
	w.set("cam_fov", 50.0)
	w.call("narrate", "Wheeeee! Sorry. That was me.", 2.4)

func _zip_cam(delta: float) -> Array:
	var p := zip_button.position
	var pos := p + Vector3(-3.5, 0.6, 10.5)
	var look := p + Vector3(3.0, -1.6, 0.0)
	var gp: Vector3 = w.g(pos)
	var xf := Transform3D(Basis.looking_at(w.g(look) - gp, Vector3.UP), gp)
	var k := smoothstep(0.0, 1.0, minf(_zip_t / 1.0, 1.0))
	xf = _zip_cam_from.interpolate_with(xf, k)
	return [xf, 10.5]

func _release() -> void:
	var c: Player = w.claude
	zip_s = 2.0
	c.in_flight = false
	c.control_enabled = true
	c.rig.rotation = Vector3.ZERO
	c.velocity = Vector3(5.0, 2.5, 0.0)
	c.rig.mood = RobotRig.Mood.NORMAL
	Sound.loop_stop("wind_loop", 0.5)
	Sound.sfx(A + "pop.ogg", -6.0, 1.3)
	w.set("lane", 1)
	w.set("lane_lock", false)
	w.set("cam_mode", "follow")
	w.set("cam_fov", 38.0)
	var tw := zip_button.create_tween()
	tw.tween_property(zip_button, "position", ZIP_A + Vector3(0.6, -0.35, 0), 2.5).set_delay(1.0)
	tw.tween_callback(func() -> void: zip_s = -1.0)

func on_respawn() -> void:
	var lp: Vector3 = w.claude_local()
	theta = _theta_of(lp)
	_floor_y = lp.y
	if zip_s >= 0.0 and zip_s <= 1.0:
		_release()
