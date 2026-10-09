## Cotton wool clouds: steps up through the layers, a big gap you can only
## glide over with the help of a felt fan, clouds that sink when you stand on
## them, and the second keepsake (a third controller) on a cloud high up in
## the back, carried there by a hidden fan.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const A := "res://levels/plush_desk/audio/"

var w: Node3D
var root: Node3D
var fans: Array = []
var sinkers: Array = []       # [body, base, depth]
var keep: Node3D
var keep_pos := Vector3()
var _got := false
var wind: Array = []

## a cloud to stand on in layer `ln`; `deep` clouds reach into the layer behind
## it as well (ln + 1), "all" clouds span every layer
func _cloud(x: float, y: float, ln: int, wd: float, deep := 0) -> Node3D:
	var z: float = w.lane_z(ln)
	if deep == 1:
		z = (w.lane_z(ln) + w.lane_z(ln + 1)) * 0.5
	elif deep == 2:
		z = 0.0
	var n := Kit.cloud(root, Vector3(x, y - 0.25, z), wd, true)
	if deep > 0:
		var sb: StaticBody3D = n.find_children("*", "StaticBody3D", false, false)[0]
		var bs: BoxShape3D = (sb.get_child(0) as CollisionShape3D).shape
		bs.size.z = 2.6 if deep == 1 else 3.9
		# a second row of cotton puffs behind (and a third)
		for k in deep:
			var extra := Kit.cloud(n, Vector3(0.15 * (k + 1), 0.05, -1.25 * (k + 1) + (0.62 if deep == 1 else 1.25)), wd * 0.95, false)
			extra.name = "Puffs%d" % k
		for ch in n.get_children():
			if ch is MeshInstance3D:
				(ch as MeshInstance3D).position.z += 0.62 if deep == 1 else 1.25
	return n

func build() -> void:
	root = Node3D.new()
	root.name = "Clouds"
	w.add_child(root)
	var M: float = w.lane_z(1)
	var B: float = w.lane_z(2)
	var F: float = w.lane_z(0)
	# --- steps up through the layers
	_cloud(81.0, 1.0, 1, 2.4)
	_cloud(83.8, 2.1, 1, 2.6, 1)
	_cloud(86.6, 3.2, 2, 2.4)
	_cloud(89.4, 4.3, 1, 2.8, 1)
	w.spool(Vector3(81.0, 1.8, M)); w.spool(Vector3(83.8, 2.9, B)); w.spool(Vector3(86.6, 4.0, B)); w.spool(Vector3(89.4, 5.1, M))
	w.section_sign(Vector3(77.4, 0.0, -1.6), "COTTON CLOUDS", Kit.SKY.darkened(0.25))
	w.narrate_at(80.0, "Cotton wool clouds. Soft landings, guaranteed. Mostly.", 2.8)
	w.narrate_at(84.4, "Some only grow in the back. W takes you there.", 2.8)
	w.key_sign(Vector3(84.6, 2.1, B - 0.6), KEY_W, "")
	w.key_sign(Vector3(89.0, 4.3, B - 0.6), KEY_SPACE, "", 3.0)
	w.narrate_at(88.6, "Now hold space to glide. Don't look down. Well, you can, it's only cotton.", 3.8)
	# --- the gap and the fan that carries you over it
	var fan_x := 94.6
	_cloud(fan_x, -2.6, 0, 3.4, 2)
	fans.append(Kit.fan(root, Vector3(fan_x, -2.6, 0.0), 1.5))
	w.add_updraft(Vector3(fan_x, 3.0, 0.0), Vector3(3.0, 11.0, 4.0), 5.5)
	_wind_streaks(Vector3(fan_x, -2.0, 0.0), 9.0)
	for i in 6:
		w.spool(Vector3(fan_x, 0.8 + i * 1.0, M))
	w.spool_arc(Vector3(91.0, 5.0, M), Vector3(99.0, 3.8, M), 5, 1.0)
	_cloud(100.6, 2.6, 1, 5.5, 2)
	w.checkpoint(Vector3(100.0, 2.6, 0.0), 1, Kit.MUSTARD)
	w.narrate_at(96.5, "Somebody left the fans on. Use them.", 2.6)
	# --- sinking clouds, across the layers
	var spots := [[104.8, 2.4, 0], [107.2, 2.2, 2], [109.6, 2.6, 1], [112.0, 2.2, 0], [114.4, 2.4, 2]]
	for sp in spots:
		var body := AnimatableBody3D.new()
		body.position = Vector3(sp[0], float(sp[1]) - 0.25, w.lane_z(sp[2]))
		root.add_child(body)
		Kit.cloud(body, Vector3.ZERO, 2.7, false)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = Vector3(2.7, 0.5, 1.4)
		cs.shape = bs
		cs.position.y = 0.2
		body.add_child(cs)
		sinkers.append([body, body.position, 0.0])
		w.spool(Vector3(sp[0], float(sp[1]) + 0.9, w.lane_z(sp[2])))
	w.narrate_at(103.0, "These ones are a little shy. Keep moving. Hop between the layers as you go.", 3.2)
	# --- keepsake 2: a hidden fan in the back layer, a little cloud up high
	var f2x := 109.6
	_cloud(f2x, 0.4, 2, 2.0)
	fans.append(Kit.fan(root, Vector3(f2x, 0.4, B), 0.7))
	w.add_updraft(Vector3(f2x, 5.5, B), Vector3(2.0, 10.0, 1.2), 6.0)
	_wind_streaks(Vector3(f2x, 1.0, B), 8.5)
	_cloud(f2x + 2.0, 9.6, 2, 2.4)
	keep_pos = Vector3(f2x + 2.2, 10.4, B)
	keep = _controller(keep_pos)
	# --- the long glide down to the next chapter
	_cloud(118.0, 3.0, 1, 3.0, 2)
	_cloud(122.8, 1.9, 1, 2.4)
	w.spool_arc(Vector3(119.4, 3.6, M), Vector3(122.6, 2.6, M), 3, 0.5)
	w.spool_arc(Vector3(124.0, 2.6, M), Vector3(131.0, 0.9, M), 6, 0.6)

## a soft felt gamepad (generic, three of them were always on that couch)
func _controller(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	root.add_child(n)
	var body := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var x := cos(a) * 0.55
		var y := sin(a) * 0.28
		if y < 0.0:
			y *= 1.0 + 0.9 * pow(absf(x) / 0.55, 4.0)
		body.append(Vector2(x, y))
	Kit.felt_cutout(n, body, 0.18, Transform3D(), Kit.NAVY.lightened(0.15), 4.0)
	Kit.felt_cutout(n, Kit.circle(0.09, 14, -0.28, 0.02), 0.06, Transform3D(Basis(), Vector3(0, 0, 0.11)), Kit.CREAM, 4.0)
	for b in [[0.25, 0.08, Kit.CORAL], [0.35, -0.02, Kit.MUSTARD], [0.15, -0.02, Kit.TEAL], [0.25, -0.12, Kit.PINK]]:
		Kit.felt_cutout(n, Kit.circle(0.045, 10, b[0], b[1]), 0.06, Transform3D(Basis(), Vector3(0, 0, 0.11)), b[2], 4.0)
	return n

func _wind_streaks(base: Vector3, h: float) -> void:
	var s := GPUParticles3D.new()
	s.amount = 24
	s.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.8, 0.1, 0.3)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 4.0
	pm.initial_velocity_min = h / 1.6 * 0.8
	pm.initial_velocity_max = h / 1.6 * 1.1
	pm.gravity = Vector3.ZERO
	s.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.5)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(1, 1, 1, 0.45)
	q.material = qm
	s.draw_pass_1 = q
	s.position = base
	s.visibility_aabb = AABB(Vector3(-2, -1, -1), Vector3(4, h + 2, 2))
	root.add_child(s)
	wind.append(s)

func update(delta: float) -> void:
	for f in fans:
		(f as Node3D).rotate_y(delta * 14.0)
	var lp: Vector3 = w.claude_local()
	var c: Player = w.claude
	for s in sinkers:
		var body: AnimatableBody3D = s[0]
		var base: Vector3 = s[1]
		var on := c.is_on_floor() and absf(lp.x - body.position.x) < 1.45 and absf(lp.z - body.position.z) < 0.8 \
			and lp.y > body.position.y - 0.2 and lp.y < body.position.y + 1.0
		var d: float = s[2]
		# a moment's grace, then it gives way (and slowly puffs back up)
		var wait: float = s[3] if s.size() > 3 else 0.0
		wait = wait + delta if on else 0.0
		if s.size() > 3:
			s[3] = wait
		else:
			s.append(wait)
		d = minf(d + delta * 0.55, 4.0) if on and wait > 0.35 else maxf(d - delta * 0.7, 0.0)
		s[2] = d
		body.position = base + Vector3(0, -d + sin(w.t * 1.2 + base.x) * 0.08, 0)
	if keep and not _got:
		keep.rotation.y = sin(w.t * 1.3) * 0.5
		keep.position.y = keep_pos.y + sin(w.t * 2.0) * 0.1
		if lp.distance_to(keep_pos - Vector3(0, 0.6, 0)) < 1.1:
			_got = true
			w.got_keepsake(1)
			w.narrate("A third controller. There were always three of them, on one couch.", 3.4)
			var tw := keep.create_tween()
			tw.tween_property(keep, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
