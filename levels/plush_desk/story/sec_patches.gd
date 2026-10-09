## "Mind the gap. Then fill it." Felt patches lie around; Claude picks one up
## (E), carries it over her head and sews it into a dashed "sew here" outline,
## where it becomes solid. Two guided ones, then a free puzzle: three patches,
## five outlines, make your own way up. Keepsake 3 is a cardboard switch.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const OUTLINE := preload("res://levels/plush_desk/shaders/sew_outline.gdshader")
const Geo := preload("res://levels/plush_desk/geo.gd")
const A := "res://levels/plush_desk/audio/"

var w: Node3D
var root: Node3D
var patches: Array = []      # {"node", "home", "state", "lane"}
var outlines: Array = []     # {"c", "s", "lane", "node", "done", "col", "pat"}
var carried: Dictionary = {}
var needle: Node3D
var _sew: Dictionary = {}
var _sew_t := -1.0
var _outline_mat: ShaderMaterial
var switch_node: Node3D
var switch_lever: Node3D
var lights: Array = []
var _switched := false
var _said_e := false

func _ground(x0: float, x1: float, top: float, col := Kit.TEAL, col2 := Kit.CREAM, pattern := 2) -> void:
	Kit.block(root, Vector3((x0 + x1) * 0.5, top - 1.5, 0.0), Vector3(x1 - x0, 3.0, 4.2), col, col2, pattern, true)

func build() -> void:
	root = Node3D.new()
	root.name = "Patches"
	w.add_child(root)
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OUTLINE
	var M: float = w.lane_z(1)
	var B: float = w.lane_z(2)
	var F: float = w.lane_z(0)
	# --- landing ground after the clouds
	_ground(128.0, 141.0, 0.0, Color(0.36, 0.55, 0.62), Kit.CREAM, 2)
	w.checkpoint(Vector3(132.5, 0.0, 0.0), 1, Kit.LILAC)
	w.narrate_at(133.5, "In most worlds, you play the levels. In this one, you fix them. Sometimes, you make them.", 4.2)
	# tutorial 1: a gap with a bridge outline
	_patch(Vector3(137.6, 0.0, M), Kit.MUSTARD, 2)
	_outline(Vector3(142.7, -0.2, M), Vector3(3.4, 0.4, 1.3), 1, Kit.MUSTARD, 2)
	w.key_sign(Vector3(136.0, 0.0, B - 0.65), KEY_E, "")
	w.spool_arc(Vector3(141.4, 1.0, M), Vector3(144.2, 1.0, M), 3, 0.3)
	_ground(144.4, 156.0, 0.0, Color(0.36, 0.55, 0.62), Kit.CREAM, 2)
	# tutorial 2: a wall, a patch in the back, an outline as a step
	Kit.block(root, Vector3(153.0, 1.2, 0.0), Vector3(3.0, 2.4, 4.2), Kit.CORAL, Kit.CREAM, 1, true)
	_patch(Vector3(147.0, 0.0, B), Kit.LILAC, 5)
	_outline(Vector3(150.85, 0.625, M), Vector3(1.3, 1.25, 1.3), 1, Kit.LILAC, 5)
	for i in 3:
		w.spool(Vector3(147.0 + i * 0.0, 0.8 + i * 0.6, B))
	w.checkpoint(Vector3(157.4, 0.0, 0.0), 1, Kit.MUSTARD)
	# --- the free puzzle: a high shelf, three patches, five outlines
	_ground(156.0, 182.0, 0.0, Color(0.36, 0.55, 0.62), Kit.CREAM, 2)
	_patch(Vector3(160.6, 0.0, F), Kit.PINK, 1)
	_patch(Vector3(162.2, 0.0, M), Kit.TEAL, 3)
	_patch(Vector3(163.8, 0.0, B), Kit.MUSTARD, 5)
	_outline(Vector3(166.2, 0.95, F), Vector3(1.6, 0.4, 1.3), 0, Kit.PINK, 1)
	_outline(Vector3(168.4, 2.1, B), Vector3(1.6, 0.4, 1.3), 2, Kit.TEAL, 3)
	_outline(Vector3(171.2, 3.25, M), Vector3(1.6, 0.4, 1.3), 1, Kit.MUSTARD, 5)
	_outline(Vector3(168.4, 2.1, F), Vector3(1.6, 0.4, 1.3), 0, Kit.LILAC, 2)
	_outline(Vector3(166.2, 0.95, B), Vector3(1.6, 0.4, 1.3), 2, Kit.CORAL, 0)
	# the shelf with its prize
	Kit.block(root, Vector3(176.6, 4.15, 0.0), Vector3(6.0, 0.8, 4.2), Kit.LILAC, Kit.CREAM, 5, true)
	for i in 6:
		w.spool(Vector3(174.4 + i * 0.85, 5.3, M))
	w.narrate_at(159.0, "Three patches. No instructions. Make your own way up.", 3.2)
	# --- keepsake 3: a cardboard switch, wired with wool to a string of lights
	switch_node = Node3D.new()
	switch_node.position = Vector3(178.8, 4.55, B)
	root.add_child(switch_node)
	Kit.cutout(switch_node, Kit.rect(0.5, 0.7, 0, 0.35), 0.08, Transform3D(), Color(0.95, 0.88, 0.74, 1.0))
	switch_lever = Node3D.new()
	switch_lever.position = Vector3(0, 0.35, 0.08)
	switch_node.add_child(switch_lever)
	Kit.cutout(switch_lever, Kit.rect(0.1, 0.32, 0, 0.13), 0.06, Transform3D(), Color(0.86, 0.45, 0.38, 1.0))
	var pts := PackedVector3Array()
	for i in 13:
		var k := i / 12.0
		pts.append(Vector3(178.8 - k * 6.0, 6.4 + sin(k * PI) * -0.5, B - 0.4))
	var cable := MeshInstance3D.new()
	cable.mesh = Geo.tube(pts, 0.035, 6)
	cable.material_override = Kit.fabric(Kit.MUSTARD, Kit.T_KNIT, 12.0, 1.0)
	root.add_child(cable)
	for i in 7:
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.11; sm.height = 0.26
		bulb.mesh = sm
		var bm := StandardMaterial3D.new()
		bm.albedo_color = [Kit.CORAL, Kit.MUSTARD, Kit.TEAL, Kit.PINK][i % 4]
		bm.emission_enabled = true
		bm.emission = bm.albedo_color
		bm.emission_energy_multiplier = 0.0
		bulb.material_override = bm
		bulb.position = pts[i * 2] + Vector3(0, -0.15, 0)
		root.add_child(bulb)
		lights.append(bm)
	# a slide down to the sewing machine's table
	var slide := Kit.block(root, Vector3(183.3, 2.3, 0.0), Vector3(8.4, 0.5, 4.2), Kit.MUSTARD, Kit.CREAM, 3, false)
	slide.rotation.z = -0.5
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(8.4, 0.5, 4.2)
	cs.shape = bs
	sb.position = slide.position
	sb.rotation.z = -0.5
	sb.add_child(cs)
	root.add_child(sb)
	# the needle that sews
	needle = Node3D.new()
	root.add_child(needle)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.84, 0.88); steel.metallic = 1.0; steel.roughness = 0.2
	var nd := MeshInstance3D.new()
	var nm := CylinderMesh.new(); nm.top_radius = 0.035; nm.bottom_radius = 0.004; nm.height = 1.0
	nd.mesh = nm
	nd.material_override = steel
	nd.position.y = 0.5
	needle.add_child(nd)
	needle.visible = false

func _patch(p: Vector3, col: Color, pat: int) -> void:
	var n := Node3D.new()
	n.position = p + Vector3(0, 0.08, 0)
	root.add_child(n)
	Kit.block(n, Vector3.ZERO, Vector3(0.9, 0.12, 0.9), col, Kit.CREAM, pat, false)
	patches.append({"node": n, "home": n.position, "state": "ground", "col": col, "pat": pat})

func _outline(c: Vector3, s: Vector3, ln: int, col: Color, pat: int) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = _outline_mat
	mi.set_instance_shader_parameter("half_size", s * 0.5)
	mi.position = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	outlines.append({"c": c, "s": s, "lane": ln, "node": mi, "done": false, "col": col, "pat": pat})

func update(delta: float) -> void:
	var lp: Vector3 = w.claude_local()
	var c: Player = w.claude
	var x_in := lp.x > 130.0 and lp.x < 184.0
	# carried patch floats over Claude's head
	if not carried.is_empty():
		var n: Node3D = carried.node
		n.position = n.position.lerp(lp + Vector3(0, 1.55, 0), 1.0 - exp(-18.0 * delta))
		n.rotation.y += delta * 1.5
		n.rotation.z = sin(w.t * 3.0) * 0.12
	if _sew_t >= 0.0:
		_sewing(delta)
		return
	if not x_in:
		return
	var best_o := -1
	var best_d := 99.0
	for i in outlines.size():
		var o: Dictionary = outlines[i]
		var hot := 0.0
		if not o.done and not carried.is_empty():
			var oc: Vector3 = o.c
			# the layer next to it counts too (you sew from the patch you stand on)
			var d := Vector3(lp.x - oc.x, (lp.y + 0.6) - oc.y, (lp.z - oc.z) * 0.8).length()
			if d < 2.6 and absf(lp.z - oc.z) < 1.4:
				hot = 1.0
				if d < best_d:
					best_d = d
					best_o = i
		(o.node as GeometryInstance3D).set_instance_shader_parameter("hot", hot)
	if carried.is_empty():
		# pick up the nearest patch
		var best_p := -1
		var bd := 99.0
		for i in patches.size():
			var p: Dictionary = patches[i]
			if p.state != "ground":
				continue
			var pn: Node3D = p.node
			var d := Vector2(lp.x - pn.position.x, lp.y - pn.position.y).length()
			if d < 1.3 and absf(lp.z - pn.position.z) < 0.7 and d < bd:
				bd = d
				best_p = i
		if best_p >= 0:
			w.prompt("E · pick up the patch")
			if not _said_e:
				_said_e = true
				w.narrate("Pick up a patch with E, then sew it in where the dotted line is.", 3.4)
			if Input.is_action_just_pressed("interact"):
				carried = patches[best_p]
				carried.state = "carried"
				Sound.sfx(A + "squish.ogg", -6.0, 1.4)
				Sound.sfx(A + "rustle.ogg", -12.0, 1.4)
		else:
			w.prompt("")
	else:
		if best_o >= 0:
			w.prompt("E · sew it in")
			if Input.is_action_just_pressed("interact"):
				_start_sew(best_o)
		else:
			w.prompt("E · put it down")
			if Input.is_action_just_pressed("interact") and c.is_on_floor():
				var n: Node3D = carried.node
				n.position = lp + Vector3(0.7 * signf(c.velocity.x + 0.001), 0.08, 0.0)
				n.rotation = Vector3.ZERO
				carried.state = "ground"
				carried = {}
				Sound.sfx(A + "squish.ogg", -8.0, 1.2)
	_switch(lp)

func _start_sew(i: int) -> void:
	_sew = {"o": outlines[i], "p": carried}
	carried = {}
	_sew_t = 0.0
	needle.visible = true
	w.prompt("")
	Sound.sfx(A + "whoosh.ogg", -8.0, 1.6)

func _sewing(delta: float) -> void:
	_sew_t += delta
	var o: Dictionary = _sew.o
	var p: Dictionary = _sew.p
	var pn: Node3D = p.node
	var oc: Vector3 = o.c
	var os: Vector3 = o.s
	# the patch flies to the outline and stretches to fit it
	var k := clampf(_sew_t / 0.35, 0.0, 1.0)
	pn.position = pn.position.lerp(oc, 1.0 - exp(-14.0 * delta))
	pn.rotation = pn.rotation.lerp(Vector3.ZERO, 1.0 - exp(-14.0 * delta))
	pn.scale = Vector3.ONE.lerp(Vector3(os.x / 0.9, os.y / 0.12, os.z / 0.9), smoothstep(0.0, 1.0, k))
	# the needle runs round the outline, stitching
	var per := (os.x + os.z) * 2.0
	var s := clampf((_sew_t - 0.3) / 0.8, 0.0, 1.0) * per
	var hx := os.x * 0.5
	var hz := os.z * 0.5
	var q := Vector3()
	if s < os.x: q = Vector3(-hx + s, 0, hz)
	elif s < os.x + os.z: q = Vector3(hx, 0, hz - (s - os.x))
	elif s < os.x * 2.0 + os.z: q = Vector3(hx - (s - os.x - os.z), 0, -hz)
	else: q = Vector3(-hx, 0, -hz + (s - os.x * 2.0 - os.z))
	needle.position = oc + q + Vector3(0, os.y * 0.5 + 0.05 + absf(sin(_sew_t * 40.0)) * 0.25, 0)
	if _sew_t > 0.3 and fmod(_sew_t, 0.07) < delta:
		Sound.sfx(A + "click.ogg", -16.0, randf_range(1.6, 2.0))
	if _sew_t > 1.15:
		_sew_t = -1.0
		needle.visible = false
		o.done = true
		(o.node as Node3D).visible = false
		pn.visible = false
		p.state = "sewn"
		var blk := Kit.block(root, oc, os, o.col, Kit.CREAM, o.pat, true)
		blk.scale = Vector3(1.1, 1.3, 1.1)
		var tw := blk.create_tween()
		tw.tween_property(blk, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sound.sfx(A + "thunk.ogg", -6.0, 1.3)
		Sound.sfx(A + "twinkle.ogg", -6.0, 1.2)
		w.shake(0.12)

func _switch(lp: Vector3) -> void:
	if _switched:
		return
	var sp := switch_node.position
	if Vector2(lp.x - sp.x, lp.y - sp.y).length() < 1.3 and absf(lp.z - sp.z) < 0.7:
		w.prompt("E · flip the switch")
		if Input.is_action_just_pressed("interact"):
			_switched = true
			w.prompt("")
			switch_lever.rotation.z = -0.6
			Sound.sfx(A + "click.ogg", -2.0, 0.9)
			for i in lights.size():
				var m: StandardMaterial3D = lights[i]
				var tw := switch_node.create_tween()
				tw.tween_interval(0.12 * i)
				tw.tween_property(m, "emission_energy_multiplier", 3.0, 0.15)
				tw.tween_callback(func() -> void: Sound.sfx(A + "twinkle.ogg", -10.0, 1.0 + i * 0.12))
			w.got_keepsake(2)
			w.narrate("The first time a switch did what you told it to. Remember that feeling.", 3.6)

## respawn: carried patches go home
func on_respawn() -> void:
	if not carried.is_empty():
		var n: Node3D = carried.node
		n.position = carried.home
		n.rotation = Vector3.ZERO
		carried.state = "ground"
		carried = {}
