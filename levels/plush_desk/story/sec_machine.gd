## The sewing machine chase. A big plush sewing machine starts up behind
## Claude and sews its way along the table, faster and faster, leaving a fresh
## seam behind. Pins block layers, spools roll towards you, there are gaps to
## jump. At the far end its plug sits in a socket: pull it.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const A := "res://levels/plush_desk/audio/"

const X_TRIGGER := 192.5
const X_PLUG := 265.0

var w: Node3D
var root: Node3D
var machine: Node3D
var needle_bar: Node3D
var wheel: Node3D
var seam: MeshInstance3D
var cable: MeshInstance3D
var riser: MeshInstance3D
var plug: Node3D
var mx := 182.0           # machine front (the needle) in local x
var start_x := 182.0
var running := false
var stopped := false
var _wait := 0.0
var _speed := 0.0
var pins: Array = []      # [x, lane]
var rollers: Array = []   # {"n", "x", "lane", "on"}
var _roll_t := 0.0
var _seam_from := 182.0
var _hum := false
var _said_run := false

func build() -> void:
	root = Node3D.new()
	root.name = "Machine"
	w.add_child(root)
	# --- the sewing table: gingham strips with gaps
	var parts := [[186.0, 207.0], [209.6, 231.0], [233.4, 252.0], [254.4, 272.0]]
	for p in parts:
		var x0: float = p[0]
		var x1: float = p[1]
		Kit.block(root, Vector3((x0 + x1) * 0.5, -1.5, 0.0), Vector3(x1 - x0, 3.0, 4.2), Color(0.86, 0.45, 0.4), Kit.CREAM, 1, true)
	w.checkpoint(Vector3(189.0, 0.0, 0.0), 1, Kit.TEAL)
	w.key_sign(Vector3(190.6, 0.0, w.lane_z(2) - 0.65), KEY_SHIFT, "shift", 2.25)
	w.narrate_at(190.4, "That's the sewing machine. It has never once stopped for anybody. Don't take it personally.", 4.0)
	# pins stuck in the table, blocking layers
	var rows := [[201.0, [1, 0]], [212.5, [2, 1]], [218.0, [0, 1]], [225.5, [1, 2]], [238.0, [0, 2]], [243.5, [1, 0]], [258.0, [2, 1]]]
	for r in rows:
		for ln in r[1]:
			_pin(r[0], ln)
	w.checkpoint(Vector3(221.5, 0.0, 0.0), 2, Kit.CORAL)
	w.checkpoint(Vector3(246.5, 0.0, 0.0), 0, Kit.MUSTARD)
	for i in 10:
		w.spool(Vector3(195.0 + i * 1.6, 0.8, w.lane_z(1)))
	for i in 8:
		w.spool(Vector3(228.0 + i * 1.3, 0.8, w.lane_z(0) if i < 4 else w.lane_z(2)))
	w.spool_arc(Vector3(206.0, 1.0, w.lane_z(1)), Vector3(210.6, 1.0, w.lane_z(1)), 4, 1.0)
	w.spool_arc(Vector3(230.4, 1.0, w.lane_z(1)), Vector3(234.4, 1.0, w.lane_z(1)), 4, 1.0)
	w.spool_arc(Vector3(251.4, 1.0, w.lane_z(1)), Vector3(255.4, 1.0, w.lane_z(1)), 4, 1.0)
	_build_machine()
	_build_socket()
	for i in 5:
		var n := _roller()
		rollers.append({"n": n, "x": 0.0, "lane": 1, "on": false})
	# seam the machine leaves behind
	seam = MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(1.0, 0.03, 0.06)
	seam.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Kit.CREAM
	seam.material_override = sm
	seam.visible = false
	root.add_child(seam)

func _pin(x: float, ln: int) -> void:
	var z: float = w.lane_z(ln)
	var n := Node3D.new()
	n.position = Vector3(x, 0.0, z)
	n.rotation = Vector3(0.12 * sin(x), 0.0, -0.1 * cos(x * 1.3))
	root.add_child(n)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.84, 0.88); steel.metallic = 1.0; steel.roughness = 0.22
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.04; cm.bottom_radius = 0.012; cm.height = 1.7
	shaft.mesh = cm
	shaft.position.y = 0.85
	shaft.material_override = steel
	n.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = 0.2; hm.height = 0.4
	head.mesh = hm
	head.position.y = 1.75
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = [Kit.CORAL, Kit.MUSTARD, Kit.TEAL, Kit.PINK, Kit.LILAC][int(x) % 5]
	hmat.roughness = 0.15
	hmat.clearcoat_enabled = true
	head.material_override = hmat
	n.add_child(head)
	pins.append([x, ln])

func _build_machine() -> void:
	machine = Node3D.new()
	machine.name = "SewingMachine"
	root.add_child(machine)
	var body := Kit.TEAL
	var trim := Kit.CREAM
	# base, pillar, arm, head – a big plush toy machine; local x = 0 is the needle
	Kit.block(machine, Vector3(-2.6, 0.55, 0.0), Vector3(6.2, 1.1, 4.4), body, trim, 0, false)
	Kit.block(machine, Vector3(-5.0, 2.9, -0.3), Vector3(1.6, 3.8, 2.4), body, trim, 0, false)
	Kit.block(machine, Vector3(-2.6, 4.55, -0.3), Vector3(6.0, 1.5, 2.4), body, trim, 0, false)
	Kit.block(machine, Vector3(-0.3, 3.6, -0.3), Vector3(1.6, 3.2, 2.4), body.lightened(0.08), trim, 0, false)
	# a cream stripe and stitched name plate
	Kit.block(machine, Vector3(-2.6, 4.55, 0.92), Vector3(5.4, 0.4, 0.06), trim, trim, 0, false)
	Kit.label(machine, "STITCH-O-MATIC", Vector3(-2.6, 4.55, 0.97), 0.007, Color(0.3, 0.2, 0.32), 64)
	# button eyes: it's a friendly machine, just a busy one
	for ex in [-0.65, 0.05]:
		Kit.button_upright(machine, Vector3(ex, 4.4, 0.95), 0.26, Kit.CREAM)
		Kit.button_upright(machine, Vector3(ex, 4.4, 1.0), 0.12, Kit.NAVY)
	# the hand wheel at the back, a spool of thread on top
	wheel = Node3D.new()
	wheel.position = Vector3(-6.0, 4.4, -0.3)
	machine.add_child(wheel)
	Kit.button_upright(wheel, Vector3.ZERO, 1.0, Kit.MUSTARD).rotation = Vector3(0, 0, PI * 0.5)
	var spool := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.4; cm.bottom_radius = 0.4; cm.height = 0.9
	spool.mesh = cm
	spool.material_override = Kit.fabric(Kit.CORAL, Kit.T_KNIT, 14.0, 1.2)
	spool.position = Vector3(-3.8, 5.75, -0.3)
	machine.add_child(spool)
	# the needle bar and the needle, stamping
	needle_bar = Node3D.new()
	needle_bar.position = Vector3(0.0, 2.0, 0.0)
	machine.add_child(needle_bar)
	Kit.block(needle_bar, Vector3(0, 0.6, 0.0), Vector3(0.35, 1.2, 0.35), Color(0.82, 0.84, 0.88), trim, 0, false)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.85, 0.87, 0.9); steel.metallic = 1.0; steel.roughness = 0.18
	var nd := MeshInstance3D.new()
	var nm := CylinderMesh.new(); nm.top_radius = 0.07; nm.bottom_radius = 0.01; nm.height = 1.6
	nd.mesh = nm
	nd.position.y = -0.8
	nd.material_override = steel
	needle_bar.add_child(nd)
	# the presser foot runs across all three layers: that's where it gets you
	Kit.block(machine, Vector3(0.1, 1.25, 0.0), Vector3(0.9, 0.2, 4.0), Color(0.82, 0.84, 0.88), trim, 0, false)
	machine.position = Vector3(start_x, 0.0, 0.0)

func _build_socket() -> void:
	# a felt wall plate with a socket; the machine's yarn cable plugs into it
	var px := X_PLUG + 1.4
	Kit.block(root, Vector3(px, 1.4, -2.3), Vector3(1.5, 2.0, 0.3), Kit.CREAM, Kit.CREAM, 0, false)
	plug = Node3D.new()
	plug.position = Vector3(px, 1.2, -2.05)
	root.add_child(plug)
	Kit.block(plug, Vector3(0, 0, 0.12), Vector3(0.55, 0.55, 0.3), Kit.MUSTARD, Kit.CREAM, 0, false)
	cable = MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.09; cm.bottom_radius = 0.09; cm.height = 1.0; cm.radial_segments = 10
	cable.mesh = cm
	cable.material_override = Kit.fabric(Kit.MUSTARD, Kit.T_KNIT, 10.0, 1.0)
	root.add_child(cable)
	riser = MeshInstance3D.new()
	riser.mesh = cm
	riser.material_override = cable.material_override
	root.add_child(riser)

func _roller() -> Node3D:
	var n := Node3D.new()
	n.visible = false
	root.add_child(n)
	var thr := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.42; cm.bottom_radius = 0.42; cm.height = 0.9
	thr.mesh = cm
	thr.rotation = Vector3(PI * 0.5, 0, 0)
	thr.material_override = Kit.fabric([Kit.LILAC, Kit.PINK, Kit.MUSTARD][randi() % 3], Kit.T_KNIT, 12.0, 1.3)
	n.add_child(thr)
	for s in [-0.5, 0.5]:
		var e := MeshInstance3D.new()
		var em := CylinderMesh.new(); em.top_radius = 0.55; em.bottom_radius = 0.55; em.height = 0.1
		e.mesh = em
		e.rotation = Vector3(PI * 0.5, 0, 0)
		e.position.z = s
		e.material_override = Kit.fabric(Kit.CREAM, Kit.T_FELT, 3.0, 1.0)
		n.add_child(e)
	return n

func update(delta: float) -> void:
	var lp: Vector3 = w.claude_local()
	if not running and not stopped and lp.x > X_TRIGGER and lp.x < X_PLUG:
		running = true
		_wait = 0.0
		_speed = 2.6
		Sound.sfx(A + "creak.ogg", 0.0, 0.6)
		w.shake(0.3)
		Sound.loop(A + "hum.ogg", -8.0, 0.3)
		Sound.music(A + "chase.ogg", 0.6)
		_hum = true
		seam.visible = true
		_seam_from = mx
		w.set("cam_dist", 12.5)
		w.set("cam_fov", 44.0)
		if not _said_run:
			_said_run = true
			w.narrate("Run! Shift helps.", 1.6)
	if running:
		if _wait > 0.0:
			_wait -= delta
		else:
			var target := clampf(3.0 + (mx - 190.0) * 0.035, 3.0, 5.9)
			_speed = lerpf(_speed, target, 1.0 - exp(-1.5 * delta))
			mx += _speed * delta
		if lp.x < mx + 0.45 and lp.x > mx - 7.0 and lp.y < 3.4:
			w.hurt()
	# animate the machine
	machine.position.x = mx
	var stamp := absf(sin(w.t * (16.0 if running else 2.0)))
	needle_bar.position.y = 2.0 - stamp * (0.9 if running else 0.15)
	wheel.rotation.z += delta * (8.0 if running else 0.5)
	machine.position.y = (sin(w.t * 30.0) * 0.03) if running else 0.0
	if seam.visible:
		var seam_len := maxf(mx - _seam_from, 0.01)
		seam.scale = Vector3(seam_len, 1.0, 1.0)
		seam.position = Vector3(_seam_from + seam_len * 0.5, 0.05, 0.0)
	# the cable from the machine's back, along the back of the table, up into the socket
	var a := Vector3(mx - 6.4, 0.1, -1.92)
	var b := Vector3(plug.position.x - 0.9, 0.1, -1.92)
	_stretch(cable, a, b)
	_stretch(riser, b, plug.position + Vector3(-0.15, -0.1, 0.1))
	# pins hurt
	for p in pins:
		var px: float = p[0]
		if absf(lp.x - px) < 0.3 and absf(lp.z - w.lane_z(p[1])) < 0.5 and lp.y < 1.6:
			w.hurt()
	_rollers(delta, lp)
	# the plug
	if running and lp.x > X_PLUG - 1.0:
		w.prompt("E · pull the plug!")
		if Input.is_action_just_pressed("interact"):
			_unplug()
	elif not running and not stopped:
		w.prompt("")

func _stretch(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	if d.length() < 0.01:
		d = Vector3(0.01, 0, 0)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized())) * Basis.from_scale(Vector3(1.0, d.length(), 1.0))
	mi.position = (a + b) * 0.5

func _rollers(delta: float, lp: Vector3) -> void:
	_roll_t -= delta
	if running and _wait <= 0.0 and _roll_t <= 0.0 and lp.x < X_PLUG - 12.0:
		_roll_t = randf_range(1.6, 2.6)
		for r in rollers:
			if not r.on:
				r.on = true
				r.x = lp.x + 15.0
				r.lane = randi() % 3
				(r.n as Node3D).visible = true
				break
	for r in rollers:
		if not r.on:
			continue
		r.x -= 3.4 * delta
		var n: Node3D = r.n
		n.position = Vector3(r.x, 0.55, w.lane_z(r.lane))
		n.rotation.z += 3.4 * delta / 0.55
		if r.x < mx + 0.5 or r.x < lp.x - 14.0:
			r.on = false
			n.visible = false
		elif absf(lp.x - r.x) < 0.6 and absf(lp.z - n.position.z) < 0.6 and lp.y < 0.95:
			w.hurt()

func _unplug() -> void:
	running = false
	stopped = true
	w.prompt("")
	Sound.sfx(A + "pop.ogg", 0.0, 0.8)
	Sound.loop_stop(A + "hum.ogg", 1.2)
	Sound.music(A + "story.ogg", 2.5)
	_hum = false
	var tw := plug.create_tween()
	tw.tween_property(plug, "position", plug.position + Vector3(-0.8, -0.9, 1.0), 0.45).set_trans(Tween.TRANS_BACK)
	for r in rollers:
		r.on = false
		(r.n as Node3D).visible = false
	w.shake(0.2)
	w.set("cam_dist", 9.8)
	w.set("cam_fov", 38.0)
	w.narrate("Peace and quiet. Nobody saw that.", 2.8)
	w.checkpoint(Vector3(X_PLUG + 3.0, 0.0, 0.0), 1, Kit.LILAC)

func on_respawn() -> void:
	if running:
		var sx: float = w.to_local(w.claude.spawn_xf.origin).x
		mx = sx - 8.5
		_seam_from = mx
		_wait = 1.4
		_speed = 2.6
		for r in rollers:
			r.on = false
			(r.n as Node3D).visible = false
