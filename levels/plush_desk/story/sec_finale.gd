## The end of chapter one: a little felt theatre. The curtains open on an
## embroidery hoop, and the run Claude just played is sewn into the linen,
## stitch by stitch (a gold knot for every spool, a red cross for every
## tumble, a star for every keepsake, her name in thread underneath). The
## spools are wound onto a big reel, the score goes up on a felt board, and a
## badge is sewn onto Claude's belly. Strike a pose, take a postcard. Then the
## linen turns clear and behind it hangs a quilt: a thank-you to the little
## planet that came before this world. Three zipper pockets lead on.
extends RefCounted

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const Geo := preload("res://levels/plush_desk/geo.gd")
const HOOP_SHADER := preload("res://levels/plush_desk/shaders/hoop.gdshader")
const YARN := preload("res://levels/plush_desk/shaders/yarn.gdshader")
const OUTLINE := preload("res://levels/plush_desk/shaders/sew_outline.gdshader")
const A := "res://levels/plush_desk/audio/"

const SX0 := 362.0
const SX1 := 394.0
const FLOOR := 0.6
const MID := 378.0
const HOOP_C := Vector3(378.0, 4.7, -3.0)
const HOOP_R := 3.0
const QUILT_C := Vector3(378.0, 6.6, -14.0)
const QW := 13.4
const QH := 8.6
const RUSTYS_BEST := 96
const STITCH_PX := 1024
const HOOP_SHOT_POS := Vector3(377.0, 3.7, 9.6)
const HOOP_SHOT_LOOK := Vector3(377.3, 3.85, -3.0)
## the course is folded into four rows on the linen, like lines of a page
const ROWS := [[-12.0, 82.0], [82.0, 186.0], [186.0, 290.0], [290.0, 372.0]]
const U0 := 0.12
const U1 := 0.88
const V0 := 0.215
const ROW_H := 0.145
const ROW_GAP := 0.012

var w: Node3D
var root: Node3D
var phase := "wait"
var pt := 0.0
var curtain_l: Node3D
var curtain_r: Node3D
var back_curtain: Node3D
var hoop_mat: ShaderMaterial
var hoop_title: Label3D
var hoop_sign: Label3D
var figure: Node3D
var spots: Array = []
var confetti: GPUParticles3D
var big_thread: MeshInstance3D
var board_vals := {}
var board_best: Label3D
var pockets: Array = []      # {"id", "x", "node", "pull", "flap", "glow"}
var keep_slots: Array = []   # quilt nodes per keepsake: [found_node, missing_node]
var quilt_light: SpotLight3D
var walls: Array = []
var foot_mat: StandardMaterial3D
# the run, as stitches
var map_pts: Array = []      # [Vector2 uv] for every recorded point
var map_t: PackedFloat32Array
var ev_list: Array = []      # [{"t", "kind", "uv"}]
var _ev_i := 0
var _click_t := 0.0
# score
var total_spools := 0
var score := 0
var medal := "bronze"
var _tally := {}
var _fly: Array = []         # [node, from, to, t, dur]
var badge: Node3D
var _photo_wait := 0
var _photo_taken := false
var postcard_layer: CanvasLayer
# camera
var _cam_pos := Vector3()
var _cam_look := Vector3()
var _shot := {}
var _cam_k := 4.0
var _cam_path := {}          # an optional straight move: {"a", "b", "la", "lb", "dur", "t"}
var _said := {}
var _exit_busy := false
var _ff := ""                # test runs: fast-forward to this phase

func build() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pd_ff="):
			_ff = a.substr(8)
	root = Node3D.new()
	root.name = "Finale"
	w.add_child(root)
	# the stage floor (and the floor behind it, all the way back to the quilt)
	Kit.block(root, Vector3((SX0 + SX1) * 0.5, FLOOR - 1.5, -6.4), Vector3(SX1 - SX0, 3.0, 17.0), Color(0.72, 0.5, 0.34), Color(0.62, 0.42, 0.28), 3, true)
	# a felt skirt with bunting along the front edge
	_bunting(Vector3(SX0 + 0.3, FLOOR - 0.05, 2.12), Vector3(SX1 - 0.3, FLOOR - 0.05, 2.12), 18)
	_footlights()
	w.checkpoint(Vector3(367.0, FLOOR, 0.0), 1, Kit.MUSTARD)
	for wx: float in [SX0 + 0.8, SX1 - 0.8]:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = Vector3(0.4, 8.0, 6.0)
		cs.shape = bs
		sb.position = Vector3(wx, FLOOR + 4.0, 0.0)
		sb.add_child(cs)
		root.add_child(sb)
	_proscenium()
	_curtains()
	_hoop()
	_big_spool()
	_board()
	_quilt()
	_pockets()
	_lights()

# ------------------------------------------------------------------ the theatre
func _bunting(a: Vector3, b: Vector3, n: int) -> void:
	var line := Geo.sag_line(a, b, 0.0, 4)
	var lm := MeshInstance3D.new()
	lm.mesh = Geo.tube(line, 0.025, 5)
	lm.material_override = Kit.fabric(Kit.CREAM, Kit.T_KNIT, 12.0, 0.8)
	root.add_child(lm)
	var cols := [Kit.CORAL, Kit.MUSTARD, Kit.TEAL, Kit.PINK, Kit.LILAC]
	for i in n:
		var p := a.lerp(b, (float(i) + 0.5) / n)
		var tri := PackedVector2Array([Vector2(-0.38, 0.0), Vector2(0.38, 0.0), Vector2(0.0, -0.6)])
		Kit.felt_cutout(root, tri, 0.03, Transform3D(Basis(), p), cols[i % cols.size()], 3.0)

## little cardboard footlights along the front edge of the stage
func _footlights() -> void:
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(1.0, 0.9, 0.6)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.78, 0.4)
	bulb.emission_energy_multiplier = 0.4
	foot_mat = bulb
	for i in 11:
		var x := MID - 10.0 + i * 2.0
		var cup := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.2; cm.bottom_radius = 0.14; cm.height = 0.2; cm.radial_segments = 12
		cup.mesh = cm
		cup.position = Vector3(x, FLOOR + 0.1, 1.8)
		cup.rotation.x = -0.5
		cup.material_override = Kit.card_material(0, Color(0.3, 0.22, 0.2, 0.9))
		root.add_child(cup)
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.12; sm.height = 0.24
		b.mesh = sm
		b.position = Vector3(x, FLOOR + 0.2, 1.75)
		b.material_override = bulb
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(b)

func _proscenium() -> void:
	var pr := Node3D.new()
	pr.name = "Proscenium"
	root.add_child(pr)
	var velvet := Color(0.6, 0.14, 0.2)
	for side: float in [-1.0, 1.0]:
		var x := MID + side * 12.4
		Kit.block(pr, Vector3(x, FLOOR + 4.6, 1.6), Vector3(1.3, 9.2, 0.9), velvet, Kit.MUSTARD, 3, true)
		# golden cord with a tassel
		var tas := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.05; cm.bottom_radius = 0.22; cm.height = 0.5; cm.radial_segments = 10
		tas.mesh = cm
		tas.position = Vector3(x - side * 0.75, FLOOR + 3.4, 1.5)
		tas.material_override = Kit.fabric(Kit.MUSTARD, Kit.T_KNIT, 10.0, 1.0)
		pr.add_child(tas)
	# the valance: a scalloped felt band across the top with the chapter title
	var val := PackedVector2Array()
	val.append(Vector2(-13.2, 1.2))
	val.append(Vector2(13.2, 1.2))
	for i in 45:
		var x := 13.2 - 26.4 * i / 44.0
		val.append(Vector2(x, -0.55 + 0.32 * absf(sin(x * PI / 2.2))))
	Kit.felt_cutout(pr, val, 0.3, Transform3D(Basis(), Vector3(MID, FLOOR + 8.6, 1.7)), velvet, 1.4)
	var trim := val.duplicate()
	for i in trim.size():
		trim[i] = trim[i] + Vector2(0, -0.1)
	Kit.felt_cutout(pr, trim, 0.26, Transform3D(Basis(), Vector3(MID, FLOOR + 8.6, 1.62)), Kit.MUSTARD, 1.4)
	var title := Kit.label(pr, "FIRST STITCHES", Vector3(MID, FLOOR + 9.15, 1.9), 0.012, Color(1.0, 0.86, 0.5), 96)
	title.outline_size = 18
	title.outline_modulate = Color(0.36, 0.08, 0.12)
	for side: float in [-1.0, 1.0]:
		var star := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0 + PI * 0.5
			var r := 0.45 if i % 2 == 0 else 0.2
			star.append(Vector2(cos(a) * r, sin(a) * r))
		Kit.felt_cutout(pr, star, 0.08, Transform3D(Basis(), Vector3(MID + side * 5.4, FLOOR + 9.15, 1.9)), Kit.MUSTARD, 3.0)
	_no_shadow(pr)

func _no_shadow(n: Node) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## a pleated velvet curtain, `wd` wide and `ht` tall, hanging down from its top edge
func _curtain_mesh(wd: float, ht: float, pleats: int, to_left := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := pleats * 8
	var ny := 6
	for j in ny:
		for i in nx:
			var q := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var u: float = float(c[0]) / nx
				var v: float = float(c[1]) / ny
				var x := -u * wd if not to_left else u * wd
				var ph := u * pleats * TAU
				var z := sin(ph) * 0.16
				var n := Vector3(-cos(ph) * 0.16 * pleats * TAU / wd, 0, 1).normalized()
				q.append([Vector3(x, -v * ht, z), n, Vector2(u * wd, v * ht)])
			for k in ([0, 1, 2, 0, 2, 3] if to_left else [0, 2, 1, 0, 3, 2]):
				var e: Array = q[k]
				st.set_normal(e[1])
				st.set_uv(e[2])
				st.add_vertex(e[0])
	return st.commit()

func _curtains() -> void:
	var velvet := Kit.fabric(Color(0.66, 0.15, 0.22), Kit.T_FELT, 3.0, 0.7).duplicate() as ShaderMaterial
	velvet.set_shader_parameter("sheen", 1.6)
	velvet.set_shader_parameter("sheen_color", Color(1.0, 0.55, 0.6))
	velvet.set_shader_parameter("translucency", 0.05)
	var mesh := _curtain_mesh(12.0, 8.2, 9)
	var mesh_l := _curtain_mesh(12.0, 8.2, 9, true)
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(MID + side * 11.9, FLOOR + 8.2, -1.95)
		root.add_child(pivot)
		var mi := MeshInstance3D.new()
		# the left half hangs to the right of its pivot, the right half to the left
		mi.mesh = mesh_l if side < 0.0 else mesh
		mi.material_override = velvet
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		if side < 0.0:
			curtain_l = pivot
		else:
			curtain_r = pivot
	# the back curtain, deep blue, between the hoop and the quilt
	var blue := Kit.fabric(Color(0.2, 0.22, 0.42), Kit.T_FELT, 3.0, 0.7).duplicate() as ShaderMaterial
	blue.set_shader_parameter("sheen", 1.4)
	blue.set_shader_parameter("sheen_color", Color(0.6, 0.65, 1.0))
	back_curtain = Node3D.new()
	back_curtain.position = Vector3(MID - 12.0, FLOOR + 11.4, -7.5)
	root.add_child(back_curtain)
	var bm := MeshInstance3D.new()
	bm.mesh = _curtain_mesh(24.0, 11.4, 16, true)
	bm.material_override = blue
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back_curtain.add_child(bm)
	# little felt stars sewn onto it
	for i in 26:
		var p := Vector3(1.0 + fmod(i * 7.3, 22.0), -1.0 - fmod(i * 3.7, 9.6), 0.25)
		var star := PackedVector2Array()
		for k in 10:
			var a := TAU * k / 10.0 + PI * 0.5
			var r := (0.16 if k % 2 == 0 else 0.07) * (1.0 + 0.4 * sin(i * 1.3))
			star.append(Vector2(cos(a) * r, sin(a) * r))
		Kit.felt_cutout(back_curtain, star, 0.03, Transform3D(Basis(), p), Color(1.0, 0.86, 0.5), 3.0)

## the embroidery hoop on its stand, with the linen that the run is sewn into
func _hoop() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.86, 0.66, 0.44)
	wood.roughness = 0.5
	wood.clearcoat_enabled = true
	wood.clearcoat = 0.5
	for k in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = HOOP_R - 0.02 + k * 0.1
		tm.outer_radius = HOOP_R + 0.2 + k * 0.1
		tm.rings = 96
		tm.ring_segments = 12
		ring.mesh = tm
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3(1, 1.8, 1)
		ring.position = HOOP_C + Vector3(0, 0, -0.03 + k * 0.08)
		ring.material_override = wood
		root.add_child(ring)
	# the brass screw at the top
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.86, 0.68, 0.32)
	brass.metallic = 1.0
	brass.roughness = 0.3
	var clamp_n := MeshInstance3D.new()
	var bxm := BoxMesh.new(); bxm.size = Vector3(0.36, 0.3, 0.4)
	clamp_n.mesh = bxm
	clamp_n.position = HOOP_C + Vector3(0, HOOP_R + 0.32, 0.02)
	clamp_n.material_override = wood
	root.add_child(clamp_n)
	var screw := MeshInstance3D.new()
	var scm := CylinderMesh.new(); scm.top_radius = 0.07; scm.bottom_radius = 0.07; scm.height = 0.7
	screw.mesh = scm
	screw.rotation.z = PI * 0.5
	screw.position = HOOP_C + Vector3(0, HOOP_R + 0.32, 0.02)
	screw.material_override = brass
	root.add_child(screw)
	# the stand: two legs and a foot
	for side: float in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new(); lm.top_radius = 0.09; lm.bottom_radius = 0.12; lm.height = HOOP_C.y - FLOOR - HOOP_R + 0.6
		leg.mesh = lm
		leg.position = Vector3(MID + side * 0.8, FLOOR + lm.height * 0.5, HOOP_C.z - 0.1)
		leg.rotation.z = side * 0.18
		leg.material_override = wood
		root.add_child(leg)
	Kit.block(root, Vector3(MID, FLOOR + 0.12, HOOP_C.z - 0.1), Vector3(2.6, 0.24, 0.9), Color(0.72, 0.5, 0.34), Kit.CREAM, 0, false)
	# the linen
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(HOOP_R * 2.0, HOOP_R * 2.0)
	q.mesh = qm
	q.position = HOOP_C
	hoop_mat = ShaderMaterial.new()
	hoop_mat.shader = HOOP_SHADER
	hoop_mat.set_shader_parameter("weave_tex", Kit.T_WEAVE)
	hoop_mat.set_shader_parameter("mottle_tex", Kit.T_MOTTLE)
	hoop_mat.set_shader_parameter("reveal", 0.0)
	var blank := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	hoop_mat.set_shader_parameter("stitch_tex", ImageTexture.create_from_image(blank))
	q.material_override = hoop_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)
	hoop_title = Kit.label(root, "First Stitches", _uv_to_local(Vector2(0.5, 0.15)) + Vector3(0, 0, 0.02), 0.0055, Color(0.32, 0.6, 0.62), 64)
	hoop_title.render_priority = 2
	hoop_title.modulate.a = 0.0
	hoop_sign = Kit.label(root, "", _uv_to_local(Vector2(0.62, 0.87)) + Vector3(0, 0, 0.02), 0.0042, Color(0.86, 0.36, 0.33), 64)
	hoop_sign.render_priority = 2
	hoop_sign.modulate.a = 0.0
	# the little felt Claude that runs along the stitches
	figure = Node3D.new()
	root.add_child(figure)
	Kit.cutout(figure, Kit.rect(0.16, 0.2, 0, 0.1), 0.04, Transform3D(), Color(1, 1, 1, 0))
	for ex: float in [-0.035, 0.035]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new(); em.radius = 0.016; em.height = 0.032
		eye.mesh = em
		eye.position = Vector3(ex, 0.13, 0.03)
		var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.12, 0.1, 0.12)
		eye.material_override = dark
		figure.add_child(eye)
	figure.visible = false

func _uv_to_local(uv: Vector2) -> Vector3:
	return HOOP_C + Vector3((uv.x - 0.5) * HOOP_R * 2.0, (0.5 - uv.y) * HOOP_R * 2.0, 0.03)

func _big_spool() -> void:
	var n := Node3D.new()
	n.position = Vector3(371.2, FLOOR, -2.6)
	root.add_child(n)
	var wood := Kit.card_material(0, Color(0.78, 0.56, 0.36, 0.9))
	for y: float in [0.08, 1.72]:
		var f := MeshInstance3D.new()
		var fm := CylinderMesh.new(); fm.top_radius = 0.95; fm.bottom_radius = 0.95; fm.height = 0.16; fm.radial_segments = 32
		f.mesh = fm
		f.position.y = y
		f.material_override = wood
		n.add_child(f)
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.42; cm.bottom_radius = 0.42; cm.height = 1.5; cm.radial_segments = 24
	core.mesh = cm
	core.position.y = 0.9
	core.material_override = wood
	n.add_child(core)
	big_thread = MeshInstance3D.new()
	var tm := CylinderMesh.new(); tm.top_radius = 1.0; tm.bottom_radius = 1.0; tm.height = 1.46; tm.radial_segments = 32
	big_thread.mesh = tm
	big_thread.position.y = 0.9
	var ym := ShaderMaterial.new()
	ym.shader = YARN
	ym.set_shader_parameter("mode", 1.0)
	ym.set_shader_parameter("albedo", Kit.CORAL)
	ym.set_shader_parameter("albedo2", Kit.MUSTARD)
	ym.set_shader_parameter("bands", 0.25)
	ym.set_shader_parameter("wind_pitch", 0.03)
	ym.set_shader_parameter("fibre_tex", Kit.T_KNIT)
	ym.set_shader_parameter("mottle_tex", Kit.T_MOTTLE)
	ym.set_shader_parameter("fibre_scale", 8.0)
	big_thread.material_override = ym
	big_thread.scale = Vector3(0.43, 1, 0.43)
	n.add_child(big_thread)
	_tally["spool_node"] = n

func _board() -> void:
	var n := Node3D.new()
	n.position = Vector3(384.7, FLOOR, -2.75)
	n.rotation.y = -0.18
	root.add_child(n)
	for lx: float in [-1.25, 1.25]:
		Kit.block(n, Vector3(lx, 1.1, -0.05), Vector3(0.14, 2.2, 0.14), Color(0.62, 0.42, 0.3), Kit.CREAM, 0, false)
	Kit.block(n, Vector3(0, 2.6, 0), Vector3(3.3, 2.7, 0.2), Kit.NAVY.lightened(0.1), Kit.CREAM, 0, false)
	Kit.block(n, Vector3(0, 2.6, 0.06), Vector3(3.0, 2.4, 0.12), Color(0.3, 0.42, 0.36), Kit.CREAM, 0, false)
	var rows := [["SPOOLS", "spools"], ["KEEPSAKES", "keeps"], ["OOPS", "oops"]]
	for i in rows.size():
		var y := 3.45 - i * 0.48
		var l := Kit.label(n, rows[i][0], Vector3(-1.3, y, 0.25), 0.0042, Kit.CREAM, 64)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var v := Kit.label(n, "", Vector3(1.3, y, 0.25), 0.0042, Color(1.0, 0.86, 0.5), 64)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		board_vals[rows[i][1]] = v
	Kit.block(n, Vector3(0, 2.13, 0.2), Vector3(2.7, 0.04, 0.02), Kit.CREAM, Kit.CREAM, 0, false)
	var sl := Kit.label(n, "SCORE", Vector3(-1.3, 1.75, 0.25), 0.006, Kit.CREAM, 64)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sv := Kit.label(n, "", Vector3(1.3, 1.75, 0.25), 0.0075, Color(1.0, 0.86, 0.5), 64)
	sv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board_vals["score"] = sv
	board_best = Kit.label(n, "Rusty's best: %d" % RUSTYS_BEST, Vector3(0, 1.38, 0.25), 0.0034, Kit.CREAM.darkened(0.1), 64)
	board_best.modulate.a = 0.0
	_tally["board"] = n

# ------------------------------------------------------------------ the quilt
func _quilt() -> void:
	var q := Node3D.new()
	q.name = "ThankYouQuilt"
	q.position = QUILT_C
	root.add_child(q)
	# a wooden rod with fabric loops; it hangs from two strings
	var rod := MeshInstance3D.new()
	var rm := CylinderMesh.new(); rm.top_radius = 0.09; rm.bottom_radius = 0.09; rm.height = QW + 1.2
	rod.mesh = rm
	rod.rotation.z = PI * 0.5
	rod.position = Vector3(0, QH * 0.5 + 0.25, 0.05)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.7, 0.5, 0.32); wood.roughness = 0.5
	rod.material_override = wood
	q.add_child(rod)
	for side: float in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var km := SphereMesh.new(); km.radius = 0.16; km.height = 0.32
		knob.mesh = km
		knob.position = Vector3(side * (QW * 0.5 + 0.6), QH * 0.5 + 0.25, 0.05)
		knob.material_override = wood
		q.add_child(knob)
		var string := MeshInstance3D.new()
		string.mesh = Geo.tube(PackedVector3Array([Vector3(side * (QW * 0.5 + 0.3), QH * 0.5 + 0.3, 0.05), Vector3(side * 2.0, QH * 0.5 + 6.0, 0.05)]), 0.02, 5)
		string.material_override = Kit.fabric(Kit.CREAM, Kit.T_KNIT, 12.0, 0.8)
		q.add_child(string)
	for i in 7:
		var lx := -QW * 0.5 + 0.8 + i * (QW - 1.6) / 6.0
		Kit.block(q, Vector3(lx, QH * 0.5 + 0.2, 0.06), Vector3(0.5, 0.5, 0.12), Kit.CORAL, Kit.CREAM, 0, false)
	# binding and backing
	Kit.block(q, Vector3(0, 0, -0.05), Vector3(QW + 0.3, QH + 0.3, 0.1), Kit.CORAL, Kit.CREAM, 1, false)
	Kit.block(q, Vector3(0, 0, 0.0), Vector3(QW, QH, 0.14), Kit.CREAM, Kit.CREAM, 0, false)
	var ink := Color(0.3, 0.2, 0.32)
	# the top banner
	var top_y := QH * 0.5 - 0.72
	Kit.block(q, Vector3(0, top_y, 0.1), Vector3(QW - 0.6, 0.95, 0.12), Kit.MUSTARD, Kit.CREAM, 0, false)
	var tl := Kit.label(q, "For the little planet that made us makers.", Vector3(0, top_y, 0.28), 0.0078, ink, 64)
	tl.render_priority = 1
	# the grid of patches
	var cw := (QW - 0.6 - 3.0 * 0.15) / 4.0
	var gy0 := top_y - 0.475 - 0.18
	var fine_h := 0.42
	var ch := (gy0 - (-QH * 0.5 + 0.25 + fine_h) - 2.0 * 0.15) / 3.0
	var cells := {}
	for r in 3:
		for c in 4:
			cells[Vector2i(c, r)] = Vector3(-QW * 0.5 + 0.3 + cw * 0.5 + c * (cw + 0.15), gy0 - ch * 0.5 - r * (ch + 0.15), 0.1)
	var texts := {
		Vector2i(0, 0): ["2011 – 2014.\nThree friends. One couch.\nThousands of levels.", Kit.TEAL.lightened(0.45)],
		Vector2i(1, 0): ["Levels drawn on paper at his place, built together at mine.", Kit.PINK.lightened(0.3)],
		Vector2i(2, 0): ["My first circuit was made of cardboard and logic.", Color(0.8, 0.88, 0.7)],
		Vector2i(3, 0): ["Worlds made by strangers we never met, played until 3 a.m.", Kit.LILAC.lightened(0.4)],
		Vector2i(0, 2): ["Sleepyhead.\nStill. Every single time.", Kit.SKY.lightened(0.35)],
		Vector2i(3, 2): ["The seed for everything I want to make.", Color(0.98, 0.84, 0.62)],
	}
	for cell in texts:
		var p: Vector3 = cells[cell]
		Kit.block(q, p, Vector3(cw, ch, 0.12), texts[cell][1], Kit.CREAM, 0, false)
		_patch_text(q, texts[cell][0], p, cw, ink, 0.0047)
	# the dedication, two patches wide, in the middle
	var dp: Vector3 = (cells[Vector2i(1, 1)] + cells[Vector2i(2, 1)]) * 0.5
	Kit.block(q, dp, Vector3(cw * 2.0 + 0.15, ch, 0.12), Color(0.97, 0.93, 0.85), Kit.CORAL, 2, false)
	Kit.block(q, dp + Vector3(0, 0, 0.04), Vector3(cw * 2.0 - 0.3, ch - 0.36, 0.12), Color(0.99, 0.96, 0.9), Kit.CREAM, 0, false)
	var ded := "This world exists because of one that came before it.\nInspired by LittleBigPlanet, made by Media Molecule.\nThank you for the levels, the laughter,\nand two friends on a couch.\nYou planted the seed. This is what grew.\n— Rusty"
	_patch_text(q, ded, dp + Vector3(0, 0, 0.06), cw * 2.0 - 0.2, ink, 0.0036)
	# a little felt couch with three controllers on it
	var cp: Vector3 = cells[Vector2i(1, 2)]
	Kit.block(q, cp, Vector3(cw, ch, 0.12), Kit.CORAL.lightened(0.15), Kit.CREAM, 5, false)
	_couch(q, cp + Vector3(0, -0.15, 0.1))
	# the three keepsakes (sewn on if found, an empty outline if not)
	var kcells := [Vector2i(0, 1), Vector2i(3, 1), Vector2i(2, 2)]
	var ktexts := ["Drawn on Friday. Built on Saturday.", "There were always three of us.", "The first time a switch did what I told it to."]
	for i in 3:
		var p: Vector3 = cells[kcells[i]]
		Kit.block(q, p, Vector3(cw, ch, 0.12), Color(0.95, 0.9, 0.8), Kit.MUSTARD, 1, false)
		var found := Node3D.new()
		q.add_child(found)
		var item := Node3D.new()
		item.position = p + Vector3(0, 0.38, 0.2)
		found.add_child(item)
		match i:
			0: _drawing(item)
			1: _controller(item)
			2: _switch(item)
		_patch_text(found, ktexts[i], p + Vector3(0, -ch * 0.27, 0.0), cw, ink, 0.0039)
		var missing := Node3D.new()
		q.add_child(missing)
		var ol := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(cw * 0.6, ch * 0.55, 0.04)
		ol.mesh = bm
		var om := ShaderMaterial.new()
		om.shader = OUTLINE
		ol.material_override = om
		ol.set_instance_shader_parameter("half_size", bm.size * 0.5)
		ol.position = p + Vector3(0, 0.15, 0.12)
		missing.add_child(ol)
		var qm := Kit.label(missing, "?", p + Vector3(0, 0.15, 0.27), 0.012, Kit.MUSTARD.darkened(0.2), 64)
		qm.render_priority = 1
		_patch_text(missing, "A keepsake is still out there somewhere.", p + Vector3(0, -ch * 0.3, 0.0), cw, ink.lightened(0.3), 0.0038)
		keep_slots.append([found, missing])
	# the fine print along the bottom
	var fy := -QH * 0.5 + 0.25 + fine_h * 0.5
	var fp := Kit.label(q, "An unofficial fan homage. Not affiliated with or endorsed by Sony Interactive Entertainment or Media Molecule.",
		Vector3(0, fy, 0.2), 0.0036, ink.lightened(0.25), 64)
	fp.render_priority = 1

func _patch_text(parent: Node3D, text: String, p: Vector3, wd: float, col: Color, px: float) -> Label3D:
	var l := Kit.label(parent, text, p + Vector3(0, 0, 0.17), px, col, 64)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = (wd - 0.35) / px
	l.line_spacing = 2.0
	l.render_priority = 1
	return l

func _drawing(n: Node3D) -> void:
	Kit.cutout(n, Kit.rect(1.2, 0.8), 0.02, Transform3D(Basis(Vector3.BACK, 0.06), Vector3.ZERO), Color(0.99, 0.98, 0.94, 1.0))
	var pencil := Color(0.35, 0.36, 0.42)
	var pts := [Vector2(-0.5, -0.25), Vector2(-0.2, -0.25), Vector2(-0.2, -0.05), Vector2(0.05, -0.05), Vector2(0.05, 0.15), Vector2(0.45, 0.15)]
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mid := (a + b) * 0.5
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(a.distance_to(b) + 0.02, 0.018, 0.01)
		seg.mesh = bm
		seg.position = Vector3(mid.x, mid.y, 0.02)
		seg.rotation.z = (b - a).angle()
		var m := StandardMaterial3D.new(); m.albedo_color = pencil
		seg.material_override = m
		n.add_child(seg)
	Kit.felt_cutout(n, Kit.circle(0.05, 10, 0.3, 0.25), 0.02, Transform3D(Basis(), Vector3(0, 0, 0.02)), Kit.MUSTARD, 6.0)

func _controller(n: Node3D) -> void:
	var body := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var x := cos(a) * 0.5
		var y := sin(a) * 0.26
		if y < 0.0:
			y *= 1.0 + 0.9 * pow(absf(x) / 0.5, 4.0)
		body.append(Vector2(x, y))
	Kit.felt_cutout(n, body, 0.06, Transform3D(), Kit.NAVY.lightened(0.15), 4.0)
	Kit.felt_cutout(n, Kit.circle(0.08, 14, -0.25, 0.02), 0.03, Transform3D(Basis(), Vector3(0, 0, 0.04)), Kit.CREAM, 4.0)
	for b in [[0.23, 0.08, Kit.CORAL], [0.32, -0.02, Kit.MUSTARD], [0.14, -0.02, Kit.TEAL], [0.23, -0.11, Kit.PINK]]:
		Kit.felt_cutout(n, Kit.circle(0.04, 10, b[0], b[1]), 0.03, Transform3D(Basis(), Vector3(0, 0, 0.04)), b[2], 4.0)

func _switch(n: Node3D) -> void:
	Kit.cutout(n, Kit.rect(0.5, 0.42, -0.25, 0.0), 0.06, Transform3D(), Color(1, 1, 1, 0))
	Kit.cutout(n, Kit.rect(0.1, 0.2, -0.25, 0.05), 0.08, Transform3D(Basis(Vector3.BACK, -0.4), Vector3(0, 0, 0.03)), Kit.CORAL)
	var cable := PackedVector3Array()
	for i in 12:
		var k := i / 11.0
		cable.append(Vector3(lerpf(0.0, 0.45, k), -0.1 + sin(k * PI * 2.0) * 0.08, 0.02))
	var cm := MeshInstance3D.new()
	cm.mesh = Geo.tube(cable, 0.018, 5)
	cm.material_override = Kit.fabric(Kit.TEAL, Kit.T_KNIT, 10.0, 0.8)
	n.add_child(cm)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.08; sm.height = 0.16
	bulb.mesh = sm
	bulb.position = Vector3(0.5, -0.05, 0.04)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.9, 0.55)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.8, 0.4)
	bmat.emission_energy_multiplier = 2.5
	bulb.material_override = bmat
	n.add_child(bulb)

func _couch(q: Node3D, p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	q.add_child(n)
	var sofa := Color(0.32, 0.5, 0.6)
	Kit.felt_cutout(n, Kit.rect(1.9, 0.55, 0, 0.45), 0.06, Transform3D(), sofa, 4.0)
	Kit.felt_cutout(n, Kit.rect(2.1, 0.32, 0, 0.05), 0.06, Transform3D(Basis(), Vector3(0, 0, 0.03)), sofa.lightened(0.12), 4.0)
	for sx: float in [-1.05, 1.05]:
		Kit.felt_cutout(n, Kit.rect(0.25, 0.5, sx, 0.2), 0.06, Transform3D(Basis(), Vector3(0, 0, 0.05)), sofa.darkened(0.12), 4.0)
	for i in 3:
		var c := Node3D.new()
		c.position = Vector3(-0.6 + i * 0.6, 0.32, 0.08)
		c.scale = Vector3.ONE * 0.42
		c.rotation.z = (i - 1) * 0.2
		n.add_child(c)
		_controller(c)
	Kit.felt_cutout(n, Kit.rect(0.08, 0.2, -0.85, -0.2), 0.04, Transform3D(Basis(), Vector3(0, 0, 0.02)), Color(0.55, 0.38, 0.26), 4.0)
	Kit.felt_cutout(n, Kit.rect(0.08, 0.2, 0.85, -0.2), 0.04, Transform3D(Basis(), Vector3(0, 0, 0.02)), Color(0.55, 0.38, 0.26), 4.0)

# ------------------------------------------------------------------ the zipper pockets
func _pockets() -> void:
	var spec := [["again", 372.5, "PLAY AGAIN", Kit.TEAL], ["desk", 378.0, "BACK TO\nTHE DESK", Kit.CORAL], ["moon", 383.5, "YOUR MOON", Kit.LILAC]]
	for s in spec:
		var n := Node3D.new()
		n.position = Vector3(s[1], FLOOR, -1.45)
		root.add_child(n)
		var col: Color = s[3]
		Kit.block(n, Vector3(0, 0.95, 0), Vector3(1.6, 1.9, 0.3), col.darkened(0.15), Kit.CREAM, 0, false)
		var flap := Node3D.new()
		flap.position = Vector3(0, 1.62, 0.17)
		n.add_child(flap)
		Kit.block(flap, Vector3(0, -0.62, 0), Vector3(1.4, 1.24, 0.12), col, Kit.CREAM, 2 if s[0] == "desk" else (1 if s[0] == "again" else 0), false)
		# zipper teeth along the top of the pocket
		var teeth := MeshInstance3D.new()
		var tb := BoxMesh.new(); tb.size = Vector3(1.4, 0.07, 0.06)
		teeth.mesh = tb
		teeth.position = Vector3(0, 1.66, 0.19)
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.85, 0.82, 0.78)
		tm.metallic = 0.8
		tm.roughness = 0.35
		teeth.material_override = tm
		n.add_child(teeth)
		var pull := Node3D.new()
		pull.position = Vector3(-0.66, 1.66, 0.24)
		n.add_child(pull)
		var pm := MeshInstance3D.new()
		var pb := BoxMesh.new(); pb.size = Vector3(0.09, 0.22, 0.03)
		pm.mesh = pb
		pm.position.y = -0.1
		pm.material_override = tm
		pull.add_child(pm)
		var lab := Kit.label(n, s[2], Vector3(0, 0.95, 0.32), 0.0042, Kit.CREAM, 64)
		lab.outline_size = 10
		lab.outline_modulate = col.darkened(0.45)
		lab.render_priority = 1
		var glow := OmniLight3D.new()
		glow.position = Vector3(0, 1.3, 0.6)
		glow.light_color = col.lightened(0.4)
		glow.light_energy = 0.0
		glow.omni_range = 2.5
		n.add_child(glow)
		if s[0] == "moon":
			# sewn shut: big cross stitches over the zipper, and a little tag
			for k in 3:
				for d: float in [-1.0, 1.0]:
					var st := MeshInstance3D.new()
					var sb := BoxMesh.new(); sb.size = Vector3(0.26, 0.035, 0.03)
					st.mesh = sb
					st.position = Vector3(-0.45 + k * 0.45, 1.66, 0.25)
					st.rotation.z = d * 0.8
					st.material_override = Kit.fabric(Kit.CREAM, Kit.T_KNIT, 10.0, 0.8)
					n.add_child(st)
			var tag := Kit.label(n, "coming soon", Vector3(0.45, 0.42, 0.32), 0.0028, Kit.CREAM, 64)
			tag.rotation.z = -0.12
			tag.render_priority = 1
			# a felt moon
			var moon := PackedVector2Array()
			for k in 24:
				var a := PI * 0.3 + PI * 1.4 * k / 23.0
				moon.append(Vector2(cos(a) * 0.22, sin(a) * 0.22))
			for k in 24:
				var a := PI * 1.7 - PI * 1.4 * k / 23.0
				moon.append(Vector2(0.08 + cos(a) * 0.17, sin(a) * 0.17))
			Kit.felt_cutout(n, moon, 0.04, Transform3D(Basis(), Vector3(-0.4, 0.45, 0.3)), Color(1.0, 0.9, 0.6), 4.0)
		n.visible = false
		n.scale = Vector3(1, 0.02, 1)
		pockets.append({"id": s[0], "x": s[1], "node": n, "pull": pull, "flap": flap, "glow": glow})

func _lights() -> void:
	for side: float in [-1.0, 1.0]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(MID + side * 6.0, 11.0, 7.0)
		sp.light_color = Color(1.0, 0.88, 0.7)
		sp.light_energy = 0.0
		sp.spot_range = 22.0
		sp.spot_angle = 24.0
		sp.shadow_enabled = false
		root.add_child(sp)
		sp.look_at_from_position(sp.position, Vector3(MID - side * 1.0, FLOOR + 1.0, -1.0))
		spots.append(sp)
	quilt_light = SpotLight3D.new()
	quilt_light.position = QUILT_C + Vector3(0, 6.0, 9.0)
	quilt_light.light_color = Color(1.0, 0.92, 0.8)
	quilt_light.light_energy = 0.0
	quilt_light.spot_range = 22.0
	quilt_light.spot_angle = 32.0
	root.add_child(quilt_light)
	quilt_light.look_at_from_position(quilt_light.position, QUILT_C)
	confetti = GPUParticles3D.new()
	confetti.amount = 160
	confetti.lifetime = 4.0
	confetti.one_shot = true
	confetti.explosiveness = 0.85
	confetti.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.0, 0.2, 1.5)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -1.6, 0)
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.hue_variation_min = -0.5
	pm.hue_variation_max = 0.5
	pm.color = Color(0.95, 0.55, 0.5)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	confetti.process_material = pm
	var cq := QuadMesh.new(); cq.size = Vector2(0.12, 0.08)
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.roughness = 0.9
	cq.material = cmat
	confetti.draw_pass_1 = cq
	confetti.position = Vector3(MID, FLOOR + 8.0, 0.0)
	confetti.visibility_aabb = AABB(Vector3(-14, -10, -4), Vector3(28, 12, 8))
	root.add_child(confetti)

# ------------------------------------------------------------------ the run, stitched
func _row_of(x: float) -> int:
	for i in ROWS.size():
		if x < float(ROWS[i][1]):
			return i
	return ROWS.size() - 1

func _map(p: Vector2) -> Vector2:
	var r := _row_of(p.x)
	var x0: float = ROWS[r][0]
	var x1: float = ROWS[r][1]
	var k := clampf((p.x - x0) / (x1 - x0), 0.0, 1.0)
	if r % 2 == 1:
		k = 1.0 - k
	var u := lerpf(U0, U1, k)
	var vy := clampf((p.y + 2.0) / 16.0, 0.0, 1.0)
	var v := V0 + r * (ROW_H + ROW_GAP) + ROW_H * (1.0 - vy)
	return Vector2(u, v)

## a made-up run, for test starts that skip the course
func _demo_run() -> void:
	var path: Array = []
	var events: Array = []
	var x := -2.0
	var k := 0
	while x < 336.0:
		var y := 0.2 + 1.8 * maxf(sin(x * 0.21) + 0.4 * sin(x * 0.63), 0.0)
		if x > 80.0 and x < 125.0:
			y = 2.0 + 2.5 * absf(sin(x * 0.12))
		if x > 288.0 and x < 318.0:
			y = 1.0 + 3.0 * absf(sin(x * 0.4))
		path.append(Vector2(x, y))
		if k % 7 == 0:
			events.append({"t": "spool", "p": Vector2(x, y + 0.8), "i": path.size()})
		x += 0.45
		k += 1
	for i in 170:
		var u := i / 85.0
		path.append(Vector2(340.0 + 3.25 * sin(u * TAU), 6.0 * u))
		if i % 6 == 0:
			events.append({"t": "spool", "p": Vector2(340.0 + 3.25 * sin(u * TAU), 6.0 * u + 0.8), "i": path.size()})
	x = 342.0
	while x < 368.0:
		path.append(Vector2(x, lerpf(12.0, 0.6, (x - 342.0) / 26.0)))
		x += 0.6
	var n := path.size()
	for e in [[60.0, 7.0, "keep", 0], [112.0, 9.5, "keep", 1], [178.0, 4.5, "keep", 2], [150.0, 0.5, "death", 0], [246.0, 0.5, "death", 0]]:
		var best := 0
		for i in n:
			if absf((path[i] as Vector2).x - float(e[0])) < 0.5:
				best = i
				break
		events.append({"t": e[2], "p": Vector2(e[0], e[1]), "i": best, "k": e[3]})
	w.set("path", path)
	w.set("events", events)
	w.set("spools", 140)
	w.set("keepsakes", [true, false, true])
	w.set("deaths", 2)
	if String(w.get("choice")) == "":
		w.set("choice", "castle")
	if String(w.get("player_name")) == "Claude":
		w.set("player_name", "Rusty")

func _build_stitches() -> void:
	if (w.get("path") as Array).size() < 200:
		_demo_run()
	var path: Array = w.get("path")
	var events: Array = w.get("events")
	var n := path.size()
	var img := Image.create(STITCH_PX, STITCH_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	map_pts.clear()
	map_t = PackedFloat32Array()
	map_t.resize(n)
	for i in n:
		map_pts.append(_map(path[i]))
		map_t[i] = float(i) / maxf(n - 1, 1)
	# running stitch: 9 px on, 5 px off, broken where Claude was teleported
	var on := true
	var left := 11.0
	var px := float(STITCH_PX)
	var cur := Vector2()
	var start := Vector2()
	var t_start := 0.0
	for i in n:
		var p: Vector2 = map_pts[i] * px
		if i == 0:
			cur = p
			start = p
			continue
		var prev_course: Vector2 = path[i - 1]
		var this_course: Vector2 = path[i]
		var r0 := _row_of(prev_course.x)
		var r1 := _row_of(this_course.x)
		if prev_course.distance_to(this_course) > 4.0:
			# teleported back to a pin: no thread in between
			cur = p
			start = p
			on = true
			left = 11.0
			continue
		var segs: Array = []
		if r0 != r1:
			# turn the corner to the next row with a little loop
			var a: Vector2 = cur
			var b: Vector2 = p
			var side := U1 if (mini(r0, r1) % 2 == 0) else U0
			var ca := Vector2(side * px, a.y)
			var cb := Vector2(side * px, b.y)
			var bulge := (1.0 if side > 0.5 else -1.0) * 0.045 * px
			segs.append(ca)
			for k in 7:
				var ang := PI * (float(k) + 1.0) / 8.0
				var mid := (ca + cb) * 0.5
				var rad := (cb - ca) * 0.5
				segs.append(mid - rad * cos(ang) + Vector2(bulge * sin(ang), 0))
			segs.append(cb)
			segs.append(b)
		else:
			segs.append(p)
		for target in segs:
			var tp: Vector2 = target
			var seg_len := cur.distance_to(tp)
			var pos := 0.0
			while pos < seg_len - 0.001:
				var step := minf(left, seg_len - pos)
				var np := cur.lerp(tp, (pos + step) / maxf(seg_len, 0.001))
				pos += step
				left -= step
				if left <= 0.001:
					if on:
						_line(img, start, np, 2.8, map_t[i], 0.0)
					on = not on
					left = 11.0 if on else 6.0
					start = np
				if not on:
					start = np
			cur = tp
	# events: gold knots, red crosses, keepsake stars
	ev_list.clear()
	total_spools = (w.get("spool_pos") as Array).size()
	for e in events:
		var ep: Vector2 = e.p
		var uv := _map(ep) * px
		var et: float = clampf(float(e.get("i", 0)) / maxf(n - 1, 1), 0.0, 1.0)
		match String(e.t):
			"spool":
				_disc(img, uv + Vector2(0, -4.0), 4.4, et, 0.2)
			"death":
				_line(img, uv + Vector2(-8, -8), uv + Vector2(8, 8), 2.6, et, 0.4)
				_line(img, uv + Vector2(-8, 8), uv + Vector2(8, -8), 2.6, et, 0.4)
			"keep":
				for k in 5:
					var a := TAU * k / 5.0 - PI * 0.5
					_line(img, uv, uv + Vector2(cos(a), sin(a)) * 16.0, 3.0, et, 0.6)
				_disc(img, uv, 5.5, et, 0.6)
		ev_list.append({"t": et, "kind": String(e.t)})
	ev_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	# the choice, sewn into the gap where it was made
	var ch: String = w.get("choice")
	if ch != "":
		var c := _map(Vector2(303.0, 7.0)) * px
		var ct := 0.0
		for i in n:
			if (path[i] as Vector2).x > 300.0:
				ct = map_t[i]
				break
		match ch:
			"castle":
				var pts := [Vector2(-16, 8), Vector2(-16, -8), Vector2(-9, -8), Vector2(-9, -3), Vector2(-3, -3), Vector2(-3, -8),
					Vector2(3, -8), Vector2(3, -3), Vector2(9, -3), Vector2(9, -8), Vector2(16, -8), Vector2(16, 8), Vector2(-16, 8)]
				for k in pts.size() - 1:
					_line(img, c + pts[k], c + pts[k + 1], 1.8, ct, 0.8)
				hoop_mat.set_shader_parameter("c_icon", Kit.PINK.darkened(0.1))
			"river":
				for row in 3:
					var prev := c + Vector2(-16, -6 + row * 6)
					for k in 9:
						var q := c + Vector2(-16 + (k + 1) * 4, -6 + row * 6 + sin((k + 1) * 1.2) * 2.5)
						_line(img, prev, q, 1.8, ct, 0.8)
						prev = q
				hoop_mat.set_shader_parameter("c_icon", Kit.SKY.darkened(0.2))
			"cliff":
				_line(img, c + Vector2(-16, 8), c + Vector2(16, 8), 1.8, ct, 0.8)
				_line(img, c + Vector2(16, 8), c + Vector2(10, -10), 1.8, ct, 0.8)
				_line(img, c + Vector2(10, -10), c + Vector2(-16, 8), 1.8, ct, 0.8)
				for k in 3:
					_line(img, c + Vector2(-22, -8 + k * 5), c + Vector2(-10, -10 + k * 5), 1.5, ct, 0.8)
				hoop_mat.set_shader_parameter("c_icon", Kit.MUSTARD.darkened(0.15))
	hoop_mat.set_shader_parameter("stitch_tex", ImageTexture.create_from_image(img))
	hoop_mat.set_shader_parameter("texel", Vector2(1.0 / px, 1.0 / px))

## a thick line into the stitch image: R = thread profile, G = time, B = palette
func _line(img: Image, a: Vector2, b: Vector2, wd: float, t: float, kind: float) -> void:
	var x0 := int(floorf(minf(a.x, b.x) - wd - 1.0))
	var x1 := int(ceilf(maxf(a.x, b.x) + wd + 1.0))
	var y0 := int(floorf(minf(a.y, b.y) - wd - 1.0))
	var y1 := int(ceilf(maxf(a.y, b.y) + wd + 1.0))
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 0.0001)
	for y in range(maxi(y0, 0), mini(y1, STITCH_PX - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, STITCH_PX - 1) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var s := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			var d := p.distance_to(a + ab * s)
			if d < wd:
				var prof := 1.0 - (d / wd) * (d / wd)
				# the ends of a stitch dip into the fabric
				prof *= smoothstep(0.0, 0.25, s) * smoothstep(1.0, 0.75, s) * 0.4 + 0.6
				_plot(img, x, y, prof, t, kind)

func _disc(img: Image, c: Vector2, r: float, t: float, kind: float) -> void:
	for y in range(maxi(int(c.y - r - 1.0), 0), mini(int(c.y + r + 1.0), STITCH_PX - 1) + 1):
		for x in range(maxi(int(c.x - r - 1.0), 0), mini(int(c.x + r + 1.0), STITCH_PX - 1) + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d < r:
				_plot(img, x, y, 1.0 - (d / r) * (d / r) * 0.8, t, kind)

func _plot(img: Image, x: int, y: int, prof: float, t: float, kind: float) -> void:
	var old := img.get_pixel(x, y)
	if old.a > 0.0 and old.r >= prof and kind <= old.b:
		return
	img.set_pixel(x, y, Color(prof, t, kind, 1.0))

# ------------------------------------------------------------------ flow
func skip_to(at: float) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pd_finale="):
			_debug_phase.call_deferred(a.substr(12))

## test starts: jump straight to a moment of the finale, for screenshots
func _debug_phase(which: String) -> void:
	var c: Player = w.claude
	phase = "debug"
	c.global_position = w.g(Vector3(MID - 3.6, FLOOR, 0.0))
	c.control_enabled = false
	w.set("cam_mode", "custom")
	w.set("cam_custom", _camera)
	curtain_l.scale = Vector3(0.24, 1.0, 2.4)
	curtain_r.scale = Vector3(0.24, 1.0, 2.4)
	for sp in spots:
		(sp as SpotLight3D).light_energy = 2.2
	foot_mat.emission_energy_multiplier = 3.0
	_build_stitches()
	hoop_mat.set_shader_parameter("reveal", 1.0 if which != "stitch" else 0.55)
	hoop_title.modulate.a = 1.0
	var d := Time.get_date_dict_from_system()
	hoop_sign.text = "— %s, %02d.%02d.%d" % [String(w.get("player_name")), int(d.day), int(d.month), int(d.year)]
	hoop_sign.modulate.a = 1.0 if which != "stitch" else 0.0
	if which == "stitch":
		figure.visible = true
		figure.position = _uv_to_local(map_pts[int(map_pts.size() * 0.55)]) + Vector3(0, 0, 0.02)
	var parts := _score_parts()
	score = parts[3]
	medal = "gold" if score >= 90 else ("silver" if score >= 70 else "bronze")
	(board_vals.spools as Label3D).text = "%d / %d" % [int(parts[0]), total_spools]
	(board_vals.keeps as Label3D).text = "%d / 3" % int(parts[1])
	(board_vals.oops as Label3D).text = str(parts[2])
	(board_vals.score as Label3D).text = str(score)
	board_best.modulate.a = 1.0
	big_thread.scale = Vector3(0.43 + 0.5 * float(parts[0]) / maxf(total_spools, 1), 1, 0.43 + 0.5 * float(parts[0]) / maxf(total_spools, 1))
	if which in ["tally", "badge", "quilt", "exits"]:
		badge = attach_badge(c.rig, medal)
	var shots := {
		"stage": [Vector3(MID, 5.6, 15.5), Vector3(MID, 4.6, -2.0), 44.0],
		"stitch": [HOOP_SHOT_POS, HOOP_SHOT_LOOK, 42.0],
		"hoop": [HOOP_SHOT_POS, HOOP_SHOT_LOOK, 42.0],
		"tally": [Vector3(MID, 4.6, 13.5), Vector3(MID, 3.2, -1.2), 44.0],
		"badge": [Vector3(MID - 3.6 + 1.1, FLOOR + 1.3, 4.2), Vector3(MID - 3.6 + 0.2, FLOOR + 0.75, 0.0), 34.0],
		"quilt": [Vector3(MID, 6.6, -4.2), Vector3(MID, 6.6, -14.0), 52.0],
		"dedication": [Vector3(MID, 6.1, -8.6), Vector3(MID, 6.1, -14.0), 40.0],
		"exits": [Vector3(MID, 3.3, 10.8), Vector3(MID, 2.9, -3.0), 46.0],
	}
	if which == "exits":
		for pk in pockets:
			(pk.node as Node3D).visible = true
			(pk.node as Node3D).scale = Vector3.ONE
	if which in ["quilt", "dedication", "exits"]:
		back_curtain.position.y += 13.5
		hoop_mat.set_shader_parameter("clear", 1.0)
		hoop_title.modulate.a = 0.0
		hoop_sign.modulate.a = 0.0
		quilt_light.light_energy = 2.6
		_update_keepsakes()
	var sh: Array = shots.get(which, shots.stage)
	_cam_pos = sh[0]
	_cam_look = sh[1]
	_set_shot(sh[0], sh[1], sh[2], 50.0)
	(w.get("cam") as Camera3D).fov = sh[2]

func update(delta: float) -> void:
	var lp: Vector3 = w.claude_local()
	var c: Player = w.claude
	pt += delta
	if _ff != "" and phase != "wait":
		Engine.time_scale = 1.0 if phase == _ff else 6.0
	_update_fly(delta)
	match phase:
		"wait":
			if lp.x > 364.8 and c.is_on_floor() and not c.in_flight and lp.y > FLOOR - 0.2:
				_begin()
		"arrive":
			_arrive()
		"stitch":
			_stitch(delta)
		"tally":
			_tally_step(delta)
		"badge":
			_badge_step()
		"photo":
			_photo_step()
		"reveal":
			_reveal_step()
		"quilt":
			_quilt_step()
		"exits":
			_exits_step(lp)
	# the curtains sway a little
	for cn in [curtain_l, curtain_r]:
		if cn:
			(cn as Node3D).rotation.z = sin(w.t * 0.7 + (cn as Node3D).position.x) * 0.004

func _go(p: String) -> void:
	phase = p
	pt = 0.0

func _say(key: String, text: String, hold := 3.2) -> void:
	if not _said.has(key):
		_said[key] = true
		w.narrate(text, hold)

func _begin() -> void:
	var c: Player = w.claude
	_go("arrive")
	c.control_enabled = false
	c.auto_target = w.g(Vector3(MID - 3.6, FLOOR, 0.0))
	c.auto_face = PI - 0.35
	w.set("lane_lock", true)
	w.set("lane", 1)
	w.set("cam_mode", "custom")
	w.set("cam_custom", _camera)
	var cam: Camera3D = w.get("cam")
	_cam_pos = w.to_local(cam.global_position)
	_cam_look = w.to_local(cam.global_position - cam.global_basis.z * 10.0)
	if _cam_pos.distance_to(Vector3(MID, 4.0, 8.0)) > 40.0:
		# (a test start: the camera has not been anywhere near yet)
		_cam_pos = Vector3(MID - 8.0, 3.0, 12.0)
		_cam_look = Vector3(MID - 8.0, 2.0, 0.0)
	_set_shot(Vector3(MID, 5.6, 15.5), Vector3(MID, 4.6, -2.0), 44.0, 2.0)
	# chapter one is done: the painting in the attic gets its star now
	var lvl: Node = w.get("level")
	var lid: String = lvl.get("level_id")
	GameState.completed[lid] = true
	GameState.save()
	Sound.stop_music(1.2)

func _arrive() -> void:
	var name: String = w.get("player_name")
	if pt > 0.3 and not _said.has("end"):
		_say("end", "And that, %s, was chapter one." % name, 3.0)
	if pt > 0.6 and not _said.has("fanfare"):
		_said["fanfare"] = true
		Sound.sfx(A + "fanfare.ogg", -2.0)
		confetti.restart()
		confetti.emitting = true
		for sp in spots:
			var tw := (sp as SpotLight3D).create_tween()
			tw.tween_property(sp, "light_energy", 2.2, 1.2)
		var tw3 := root.create_tween()
		tw3.tween_property(foot_mat, "emission_energy_multiplier", 3.0, 0.8)
		Sound.sfx(A + "rustle.ogg", -4.0, 0.7)
		for k in 2:
			var cn: Node3D = [curtain_l, curtain_r][k]
			var tw2 := cn.create_tween().set_parallel(true)
			tw2.tween_property(cn, "scale", Vector3(0.24, 1.0, 2.4), 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if pt > 3.2:
		_build_stitches()
		_set_shot(HOOP_SHOT_POS, HOOP_SHOT_LOOK, 42.0, 1.6)
		Sound.music(A + "finale.ogg", 2.0)
		_go("stitch")

func _stitch(delta: float) -> void:
	var dur := 8.0
	if pt < 1.0:
		hoop_title.modulate.a = pt
		return
	hoop_title.modulate.a = 1.0
	var k := clampf((pt - 1.0) / dur, 0.0, 1.0)
	var rv := k * k * (3.0 - 2.0 * k)
	hoop_mat.set_shader_parameter("reveal", rv)
	_click_t -= delta
	if _click_t <= 0.0 and k < 1.0:
		_click_t = 0.13
		Sound.sfx(A + "click.ogg", -22.0, randf_range(1.6, 2.2))
	while _ev_i < ev_list.size() and float(ev_list[_ev_i].t) <= rv:
		var kind: String = ev_list[_ev_i].kind
		if kind == "death":
			Sound.sfx(A + "pop.ogg", -14.0, 1.4)
		elif kind == "keep":
			Sound.sfx(A + "chime.ogg", -8.0, 1.2)
		elif kind == "spool" and _ev_i % 3 == 0:
			Sound.sfx(A + "twinkle.ogg", -20.0, randf_range(1.0, 1.6))
		_ev_i += 1
	# the little felt Claude runs along the needle
	if map_pts.size() > 1 and k < 1.0:
		figure.visible = true
		var idx := clampi(int(rv * (map_pts.size() - 1)), 0, map_pts.size() - 1)
		var uv: Vector2 = map_pts[idx]
		figure.position = _uv_to_local(uv) + Vector3(0, 0, 0.02)
		figure.rotation.z = sin(pt * 18.0) * 0.15
	if k >= 1.0:
		figure.visible = false
		if not _said.has("sign"):
			_said["sign"] = true
			var name: String = w.get("player_name")
			var d := Time.get_date_dict_from_system()
			hoop_sign.text = "— %s, %02d.%02d.%d" % [name, int(d.day), int(d.month), int(d.year)]
			var tw := hoop_sign.create_tween()
			tw.tween_property(hoop_sign, "modulate:a", 1.0, 1.2)
			Sound.sfx(A + "chime.ogg", -6.0, 0.9)
			_say("stitched", "Every stitch of that is you. Every knot, every tumble, every detour.", 3.6)
	if pt > dur + 4.4:
		_tally = _tally.merged({"t": 0.0, "shown": 0, "keeps": 0, "stage": 0, "score_shown": 0.0, "fly_t": 0.0, "note": 0})
		_set_shot(Vector3(MID, 4.6, 13.5), Vector3(MID, 3.2, -1.2), 44.0, 1.8)
		_go("tally")

func _score_parts() -> Array:
	var spools: int = w.get("spools")
	var keeps: Array = w.get("keepsakes")
	var deaths: int = w.get("deaths")
	var kc := 0
	for k in keeps:
		if k:
			kc += 1
	var sp := int(round(60.0 * float(spools) / maxf(total_spools, 1)))
	var kp := kc * 8
	var op := maxi(16 - 2 * deaths, 0)
	return [spools, kc, deaths, sp + kp + op]

func _tally_step(delta: float) -> void:
	var parts := _score_parts()
	var spools: int = parts[0]
	var kc: int = parts[1]
	var deaths: int = parts[2]
	score = parts[3]
	var c: Player = w.claude
	var spool_node: Node3D = _tally.spool_node
	# 1) the spools fly from Claude onto the big reel
	if pt > 0.6:
		var dur := clampf(spools * 0.03, 1.2, 4.0)
		var k := clampf((pt - 0.6) / dur, 0.0, 1.0)
		var target := int(round(spools * k))
		while int(_tally.shown) < target:
			_tally.shown = int(_tally.shown) + 1
			var sh: int = _tally.shown
			if sh % 2 == 0 or sh == target:
				var from: Vector3 = w.to_local(c.global_position) + Vector3(0, 0.8, 0)
				_launch_spool(from, spool_node.position + Vector3(0, 1.0, 0))
			if sh % 3 == 0:
				var scale := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31]
				var note: int = scale[mini(int(_tally.note), scale.size() - 1)]
				_tally.note = int(_tally.note) + 1
				Sound.sfx(A + "twinkle.ogg", -10.0, pow(2.0, (note - 7) / 12.0))
		(board_vals.spools as Label3D).text = "%d / %d" % [int(_tally.shown), total_spools]
		var fill := float(_tally.shown) / maxf(total_spools, 1)
		big_thread.scale = Vector3(0.43 + 0.5 * fill, 1, 0.43 + 0.5 * fill)
		spool_node.rotation.y += delta * 6.0 * (1.0 - k)
		if k >= 1.0 and int(_tally.stage) == 0:
			_tally.stage = 1
			_tally.t = pt
	# 2) keepsakes, one by one
	if int(_tally.stage) == 1 and pt > float(_tally.t) + 0.6:
		var shown_k := int((pt - float(_tally.t) - 0.6) / 0.45)
		shown_k = mini(shown_k, 3)
		if shown_k > int(_tally.keeps):
			_tally.keeps = shown_k
			var have := 0
			var keeps: Array = w.get("keepsakes")
			for i in shown_k:
				if keeps[i]:
					have += 1
			Sound.sfx(A + ("chime.ogg" if keeps[shown_k - 1] else "click.ogg"), -8.0, 1.0 + shown_k * 0.12)
			(board_vals.keeps as Label3D).text = "%d / 3" % have
		if shown_k >= 3:
			_tally.stage = 2
			_tally.t = pt
	# 3) the tumbles
	if int(_tally.stage) == 2 and pt > float(_tally.t) + 0.5:
		(board_vals.oops as Label3D).text = str(deaths)
		Sound.sfx(A + "pop.ogg", -8.0, 1.2 if deaths == 0 else 0.8)
		if deaths == 0:
			_say("noops", "Not a single tumble. Show-off.", 2.6)
		_tally.stage = 3
		_tally.t = pt
	# 4) the score counts up
	if int(_tally.stage) == 3 and pt > float(_tally.t) + 0.7:
		var k2 := clampf((pt - float(_tally.t) - 0.7) / 1.6, 0.0, 1.0)
		var s := int(round(score * k2))
		if s != int(_tally.score_shown):
			_tally.score_shown = s
			if s % 4 == 0:
				Sound.sfx("blip", -14.0, 0.8 + 0.6 * k2)
		(board_vals.score as Label3D).text = str(s)
		if k2 >= 1.0:
			Sound.sfx(A + "chime.ogg", -4.0)
			var tw := board_best.create_tween()
			tw.tween_property(board_best, "modulate:a", 1.0, 0.6)
			medal = "gold" if score >= 90 else ("silver" if score >= 70 else "bronze")
			_save_result(spools, kc, deaths)
			_tally.stage = 4
			_tally.t = pt
	if int(_tally.stage) == 4 and pt > float(_tally.t) + 1.4:
		var cp: Vector3 = w.to_local(c.global_position)
		_set_shot(cp + Vector3(1.1, 1.3, 4.2), cp + Vector3(0.2, 0.75, 0), 34.0, 1.6)
		_make_badge()
		_go("badge")

func _launch_spool(from: Vector3, to: Vector3) -> void:
	var s := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.12; cm.bottom_radius = 0.12; cm.height = 0.2; cm.radial_segments = 10
	s.mesh = cm
	var cols := [Kit.CORAL, Kit.MUSTARD, Kit.TEAL, Kit.LILAC, Kit.PINK]
	s.material_override = Kit.fabric(cols[randi() % cols.size()], Kit.T_KNIT, 10.0, 1.0)
	s.position = from
	root.add_child(s)
	_fly.append([s, from, to, 0.0, randf_range(0.55, 0.8)])

func _update_fly(delta: float) -> void:
	for i in range(_fly.size() - 1, -1, -1):
		var f: Array = _fly[i]
		var n: Node3D = f[0]
		f[3] = float(f[3]) + delta
		var k := clampf(float(f[3]) / float(f[4]), 0.0, 1.0)
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		n.position = a.lerp(b, k) + Vector3(0, sin(k * PI) * 1.6, 0)
		n.rotation = Vector3(k * 7.0, k * 4.0, 0)
		if k >= 1.0:
			n.queue_free()
			_fly.remove_at(i)

func _save_result(spools: int, kc: int, deaths: int) -> void:
	var lvl: Node = w.get("level")
	var notes: Dictionary = lvl.call("notes")
	notes["runs"] = int(notes.get("runs", 0)) + 1
	var best := int(notes.get("best_score", 0))
	if score > best:
		notes["best_score"] = score
	var order := {"bronze": 0, "silver": 1, "gold": 2}
	var old: String = notes.get("badge", "")
	if old == "" or int(order[medal]) > int(order.get(old, -1)):
		notes["badge"] = medal
	notes["best_spools"] = maxi(int(notes.get("best_spools", 0)), spools)
	var keeps: Array = w.get("keepsakes")
	var ever: Array = notes.get("keepsakes", [false, false, false])
	for i in 3:
		ever[i] = bool(ever[i]) or bool(keeps[i])
	notes["keepsakes"] = ever
	notes["name"] = w.get("player_name")
	notes["choice_" + String(w.get("choice"))] = true
	GameState.save()

## the badge: a felt disc with a star, flown over from the board and sewn on
static func badge_node(kind: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Badge"
	var rim := {"gold": Color(0.96, 0.74, 0.28), "silver": Color(0.8, 0.83, 0.88), "bronze": Color(0.8, 0.52, 0.34)}
	var col: Color = rim.get(kind, rim.bronze)
	Kit.felt_cutout(n, Kit.circle(0.12, 28), 0.025, Transform3D(), col, 8.0)
	Kit.felt_cutout(n, Kit.circle(0.092, 28), 0.02, Transform3D(Basis(), Vector3(0, 0, 0.012)), Color(0.98, 0.94, 0.86), 8.0)
	var star := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 + PI * 0.5
		var r := 0.07 if i % 2 == 0 else 0.03
		star.append(Vector2(cos(a) * r, sin(a) * r))
	Kit.felt_cutout(n, star, 0.015, Transform3D(Basis(), Vector3(0, 0, 0.022)), col, 8.0)
	# blanket stitches round the rim
	for i in 16:
		var a := TAU * i / 16.0
		var st := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.006, 0.03, 0.006)
		st.mesh = bm
		st.position = Vector3(cos(a) * 0.112, sin(a) * 0.112, 0.016)
		st.rotation.z = a + PI * 0.5
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.3, 0.2, 0.32)
		st.material_override = m
		n.add_child(st)
	return n

## where the badge sits on Claude: on the belly, a little to one side
static func attach_badge(rig: Node3D, kind: String) -> Node3D:
	var old := rig.find_child("Badge", true, false)
	if old:
		old.queue_free()
	var body: Node3D = rig.get("body")
	if body == null:
		body = rig
	var belly: MeshInstance3D = null
	for m in rig.find_children("*", "MeshInstance3D", true, false):
		if String(m.name) == "Belly":
			belly = m
	var n := badge_node(kind)
	body.add_child(n)
	if belly and belly.mesh:
		var aabb: AABB = body.global_transform.affine_inverse() * belly.global_transform * belly.mesh.get_aabb()
		n.position = Vector3(aabb.position.x + aabb.size.x * 0.72, aabb.position.y + aabb.size.y * 0.3, aabb.position.z - 0.012)
	else:
		n.position = Vector3(0.08, 0.45, -0.2)
	n.rotation.y = PI
	n.scale = Vector3.ONE * 0.85
	return n

func _make_badge() -> void:
	var board: Node3D = _tally.board
	badge = badge_node(medal)
	root.add_child(badge)
	badge.position = board.position + Vector3(0, 1.3, 0.3)
	badge.scale = Vector3.ONE * 3.0
	_tally.badge_from = badge.position

func _badge_step() -> void:
	var c: Player = w.claude
	var k := clampf((pt - 0.4) / 1.2, 0.0, 1.0)
	if badge and badge.get_parent() == root:
		var e := k * k * (3.0 - 2.0 * k)
		var to: Vector3 = w.to_local(c.global_position) + Vector3(0, 0.55, 0.4)
		var from: Vector3 = _tally.badge_from
		badge.position = from.lerp(to, e) + Vector3(0, sin(e * PI) * 1.4, 0)
		badge.scale = Vector3.ONE * lerpf(3.0, 0.85, e)
		badge.rotation.y = e * TAU
		if k >= 1.0:
			badge.queue_free()
			badge = attach_badge(c.rig, medal)
			Sound.sfx(A + "thunk.ogg", -6.0, 1.4)
			w.call("_sparkle", w.to_local(badge.global_position))
			c.rig.mood = RobotRig.Mood.SPARKLE
			_tally.sew_t = pt
	if _tally.has("sew_t"):
		var st: float = pt - float(_tally.sew_t)
		if st < 1.2 and int(st * 10.0) != int((st - 0.016) * 10.0):
			Sound.sfx(A + "click.ogg", -12.0, randf_range(1.8, 2.4))
		if st > 0.5:
			var lines := {"gold": "Gold. Sewn on for good. I'm not crying, you're crying.",
				"silver": "Silver. Shiny, and a little room to grow.",
				"bronze": "Bronze. Every maker starts somewhere. This is somewhere."}
			_say("medal", lines[medal], 3.4)
		if st > 3.8 and not _said.has("rusty"):
			_said["rusty"] = true
			if score > RUSTYS_BEST:
				w.narrate("And you beat Rusty's best. He'll be thrilled. Mostly.", 3.0)
			elif score == 100:
				w.narrate("A perfect hundred. Nobody does that.", 2.6)
		if st > 4.6:
			_set_shot(Vector3(MID - 1.0, 2.6, 7.2), Vector3(MID - 1.4, 1.4, 0.0), 40.0, 1.4)
			c.control_enabled = true
			w.set("lane_lock", false)
			w.prompt("Q · strike a pose      E · take a photo")
			_say("pose", "Now, a postcard for the fridge. Strike a pose!", 2.8)
			_go("photo")

func _photo_step() -> void:
	var c: Player = w.claude
	var cp: Vector3 = w.to_local(c.global_position)
	_set_shot(Vector3(cp.x + 0.4, 2.7, 7.0), Vector3(cp.x - 0.1, 1.45, 0.0), 40.0, 3.0)
	if not _photo_taken:
		var ff_skip := _ff != "" and _ff != "photo" and pt > 1.0
		if _photo_wait == 0 and (Input.is_action_just_pressed("interact") or pt > 40.0 or ff_skip):
			_photo_wait = 1
			w.prompt("")
			(w.get("narrator") as CanvasLayer).visible = false
			(w.get("hud") as CanvasLayer).visible = false
		elif _photo_wait > 0:
			_photo_wait += 1
			if _photo_wait == 4:
				_take_photo()
		return
	if pt > 4.5:
		(w.get("narrator") as CanvasLayer).visible = true
		c.control_enabled = false
		c.auto_target = w.g(Vector3(MID - 3.6, FLOOR, 0.0))
		Sound.music(A + "quilt.ogg", 3.0)
		_go("reveal")

func _take_photo() -> void:
	var img := w.get_viewport().get_texture().get_image()
	(w.get("hud") as CanvasLayer).visible = true
	var lvl: Node = w.get("level")
	var hud: GameHUD = lvl.get("hud")
	var tw := w.create_tween()
	tw.tween_method(func(v: float) -> void: hud.set_fx("white", v), 0.9, 0.0, 0.6)
	Sound.sfx(A + "click.ogg", -2.0, 0.8)
	Sound.sfx(A + "pop.ogg", -10.0, 1.6)
	_photo_taken = true
	pt = 0.0
	if img == null:
		return
	_show_postcard(img)
	_save_postcard(img)

## the postcard as a picture file: the photo in a cream border, with a caption
func _postcard_card(img: Image, k: float, footer: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88)
	sb.set_corner_radius_all(int(6 * k / 0.36))
	sb.content_margin_left = 16.0 * k / 0.36; sb.content_margin_right = 16.0 * k / 0.36
	sb.content_margin_top = 16.0 * k / 0.36; sb.content_margin_bottom = 12.0 * k / 0.36
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	card.add_child(v)
	var small := img.duplicate() as Image
	small.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_BILINEAR)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(small)
	v.add_child(tr)
	var cap := Label.new()
	var name: String = w.get("player_name")
	cap.text = "%s  ·  First Stitches  ·  %d / 100" % [name, score]
	cap.add_theme_font_override("font", Kit.FONT)
	cap.add_theme_font_size_override("font_size", int(24 * k / 0.36))
	cap.add_theme_color_override("font_color", Color(0.3, 0.2, 0.32))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var foot := Label.new()
	foot.text = footer
	foot.add_theme_font_override("font", Kit.FONT)
	foot.add_theme_font_size_override("font_size", int(16 * k / 0.36))
	foot.add_theme_color_override("font_color", Color(0.3, 0.6, 0.62))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	return card

func _save_postcard(img: Image) -> void:
	var k := 0.6
	var sv := SubViewport.new()
	sv.size = Vector2i(int(img.get_width() * k) + 64, int(img.get_height() * k) + 150)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	w.add_child(sv)
	var bg := ColorRect.new()
	bg.color = Color(0.32, 0.6, 0.62)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	sv.add_child(bg)
	var d := Time.get_date_dict_from_system()
	var card := _postcard_card(img, k, "a Plush Desk dream  ·  %02d.%02d.%d" % [int(d.day), int(d.month), int(d.year)])
	card.position = Vector2(16, 16)
	sv.add_child(card)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(sv):
		return
	var out := sv.get_texture().get_image()
	sv.queue_free()
	if out == null:
		return
	DirAccess.make_dir_recursive_absolute("user://postcards")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	out.save_png("user://postcards/first_stitches_%s.png" % stamp)

func _show_postcard(img: Image) -> void:
	postcard_layer = CanvasLayer.new()
	postcard_layer.layer = 13
	w.add_child(postcard_layer)
	var card := _postcard_card(img, 0.36, "postcard saved")
	var sb := card.get_theme_stylebox("panel") as StyleBoxFlat
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 14
	postcard_layer.add_child(card)
	var small_w := int(img.get_width() * 0.36)
	var small_h := int(img.get_height() * 0.36)
	var vs := w.get_viewport().get_visible_rect().size
	card.pivot_offset = Vector2(small_w * 0.5 + 16, small_h * 0.5 + 30)
	card.position = Vector2(vs.x * 0.5 - card.pivot_offset.x, -small_h - 120.0)
	card.rotation = -0.3
	var tw := card.create_tween()
	tw.tween_property(card, "position:y", vs.y * 0.5 - card.pivot_offset.y, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "rotation", 0.05, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(card, "position", Vector2(vs.x - card.pivot_offset.x * 2.0 * 0.45 - 30.0, vs.y - card.pivot_offset.y * 2.0 * 0.45 - 30.0), 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(card, "scale", Vector2.ONE * 0.45, 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(card, "rotation", -0.06, 0.8)
	tw.tween_interval(3.0)
	tw.tween_property(card, "modulate:a", 0.0, 1.0)
	tw.tween_callback(postcard_layer.queue_free)

func _reveal_step() -> void:
	if pt < 0.1:
		# wherever the postcard was taken: back in front of the hoop first
		_set_shot(Vector3(MID, 4.9, 8.6), Vector3(MID, 4.6, -3.0), 40.0, 3.5)
		var c0: Player = w.claude
		c0.auto_target = w.g(Vector3(MID - 3.6, FLOOR, 0.0))
	_say("before", "Every world has a world before it.", 3.2)
	if pt > 1.5 and not _said.has("rise"):
		_said["rise"] = true
		Sound.sfx(A + "whoosh.ogg", -8.0, 0.6)
		var tw := back_curtain.create_tween()
		tw.tween_property(back_curtain, "position:y", back_curtain.position.y + 13.5, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var tw2 := quilt_light.create_tween()
		tw2.tween_property(quilt_light, "light_energy", 2.6, 4.0)
		for sp in spots:
			(sp as SpotLight3D).create_tween().tween_property(sp, "light_energy", 0.8, 3.0)
		_update_keepsakes()
	if pt > 2.5:
		hoop_mat.set_shader_parameter("clear", clampf((pt - 2.5) / 3.0, 0.0, 1.0))
		hoop_title.modulate.a = 1.0 - clampf((pt - 2.5) / 2.0, 0.0, 1.0)
		hoop_sign.modulate.a = hoop_title.modulate.a
	if pt > 4.0 and not _cam_path.has("a"):
		# through the hoop to the quilt
		_cam_path = {"a": Vector3(MID, 4.9, 8.6), "b": Vector3(MID, 6.6, -4.2), "la": Vector3(MID, 4.6, -3.0), "lb": Vector3(MID, 6.6, -14.0),
			"dur": 6.0, "t": 0.0, "fa": 40.0, "fb": 52.0}
	if pt > 11.0:
		_go("quilt")

func _update_keepsakes() -> void:
	var lvl: Node = w.get("level")
	var notes: Dictionary = lvl.call("notes")
	var ever: Array = notes.get("keepsakes", [false, false, false])
	var now: Array = w.get("keepsakes")
	for i in 3:
		var have := bool(ever[i]) or bool(now[i])
		(keep_slots[i][0] as Node3D).visible = have
		(keep_slots[i][1] as Node3D).visible = not have

func _quilt_step() -> void:
	if pt > 0.5:
		_say("couch", "Once, three kids shared one couch and a planet full of cardboard. They drew levels on paper, and then they built them.", 6.0)
	if pt > 1.0 and not _cam_path.has("q2"):
		_cam_path = {"a": _cam_pos, "b": Vector3(MID, 6.1, -8.6), "la": _cam_look, "lb": Vector3(MID, 6.1, -14.0), "dur": 9.0, "t": 0.0,
			"fa": 52.0, "fb": 40.0, "q2": true}
	if pt > 10.0:
		_say("them", "This one is for them.", 3.2)
	if pt > 11.0 and not _cam_path.has("q3"):
		_cam_path = {"a": _cam_pos, "b": Vector3(MID, 6.6, -4.2), "la": _cam_look, "lb": Vector3(MID, 6.6, -14.0), "dur": 4.0, "t": 0.0,
			"fa": 40.0, "fb": 52.0, "q3": true}
	if pt > 17.5 and not _cam_path.has("q4"):
		# back out through the hoop to the stage and the pockets
		_cam_path = {"a": _cam_pos, "b": Vector3(MID, 3.3, 10.8), "la": _cam_look, "lb": Vector3(MID, 2.9, -3.0), "dur": 5.0, "t": 0.0,
			"fa": 52.0, "fb": 46.0, "q4": true}
	if pt > 23.0:
		_cam_path = {}
		_set_shot(Vector3(MID, 3.3, 10.8), Vector3(MID, 2.9, -3.0), 46.0, 2.0)
		var c: Player = w.claude
		c.control_enabled = true
		c.rig.mood = RobotRig.Mood.NORMAL
		_say("pockets", "Three pockets. Play it again, go back to the desk, or... well. That one isn't finished yet.", 4.4)
		_pop_pockets()
		_go("exits")

## the pockets pop up out of the stage floor, one after the other
func _pop_pockets() -> void:
	for i in pockets.size():
		var n: Node3D = pockets[i].node
		var tw := n.create_tween()
		tw.tween_interval(0.25 + i * 0.22)
		tw.tween_callback(func() -> void:
			n.visible = true
			Sound.sfx(A + "pop.ogg", -6.0, 1.1 + i * 0.12))
		tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _exits_step(lp: Vector3) -> void:
	var c: Player = w.claude
	_set_shot(Vector3(clampf(lp.x, 374.0, 382.0), 3.3, 10.8), Vector3(clampf(lp.x, 374.0, 382.0), 2.9, -3.0), 46.0, 2.0)
	if _exit_busy:
		return
	var near: Dictionary = {}
	for p in pockets:
		var g: OmniLight3D = p.glow
		var d := absf(lp.x - float(p.x))
		g.light_energy = lerpf(g.light_energy, 1.4 if d < 1.0 else 0.0, 0.1)
		if d < 1.0 and lp.y < FLOOR + 1.0:
			near = p
	if near.is_empty():
		w.prompt("")
		return
	var labels := {"again": "E · play it again", "desk": "E · back to the desk", "moon": "E · your moon"}
	w.prompt(labels[near.id])
	if Input.is_action_just_pressed("interact"):
		_open_pocket(near)

func _open_pocket(p: Dictionary) -> void:
	var c: Player = w.claude
	var pull: Node3D = p.pull
	if p.id == "moon":
		var tw := pull.create_tween()
		for k in 3:
			tw.tween_property(pull, "position:x", -0.55, 0.06)
			tw.tween_property(pull, "position:x", -0.66, 0.06)
		Sound.sfx(A + "wiggle.ogg", -4.0)
		w.narrate("Not yet. That one is yours to make.", 3.0)
		return
	_exit_busy = true
	w.prompt("")
	c.control_enabled = false
	var tw2 := pull.create_tween()
	tw2.tween_property(pull, "position:x", 0.66, 0.6).set_trans(Tween.TRANS_SINE)
	Sound.sfx(A + "swish.ogg", -2.0, 0.6)
	var flap: Node3D = p.flap
	var tw3 := flap.create_tween()
	tw3.tween_interval(0.5)
	tw3.tween_property(flap, "rotation:x", 1.2, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(p.glow as OmniLight3D).light_energy = 3.0
	# Claude hops in
	var node: Node3D = p.node
	var into: Vector3 = w.g(node.position + Vector3(0, 1.3, 0.2))
	var tw4 := c.create_tween()
	tw4.tween_interval(1.1)
	tw4.tween_callback(func() -> void:
		c.in_flight = true
		Sound.sfx("jump", -4.0, 1.1))
	tw4.tween_property(c, "global_position", into + Vector3(0, 0.8, 0), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw4.parallel().tween_property(c.rig, "scale", Vector3.ONE * 0.6, 0.35)
	tw4.tween_property(c, "global_position", into, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw4.parallel().tween_property(c.rig, "scale", Vector3.ONE * 0.05, 0.25)
	tw4.tween_callback(func() -> void: Sound.sfx(A + "pop.ogg", -4.0, 1.2))
	var lvl: Node = w.get("level")
	var hud: GameHUD = lvl.get("hud")
	tw4.tween_method(func(v: float) -> void: hud.set_fx("white", v), 0.0, 1.0, 0.5)
	tw4.tween_callback(func() -> void:
		c.in_flight = false
		c.rig.scale = Vector3.ONE
		if p.id == "again":
			lvl.call_deferred("restart_story")
		else:
			lvl.call_deferred("exit_story", "desk"))

## a shot to ease the camera to (local positions)
func _set_shot(pos: Vector3, look: Vector3, fov: float, speed := 2.0) -> void:
	_shot = {"pos": pos, "look": look}
	_cam_k = speed
	w.set("cam_fov", fov)

func _camera(delta: float) -> Array:
	if _cam_path.has("a") and float(_cam_path.t) < float(_cam_path.dur):
		_cam_path.t = float(_cam_path.t) + delta
		var k := clampf(float(_cam_path.t) / float(_cam_path.dur), 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var a: Vector3 = _cam_path.a
		var b: Vector3 = _cam_path.b
		var la: Vector3 = _cam_path.la
		var lb: Vector3 = _cam_path.lb
		_cam_pos = a.lerp(b, e)
		_cam_look = la.lerp(lb, e)
		w.set("cam_fov", lerpf(float(_cam_path.fa), float(_cam_path.fb), e))
		_shot = {"pos": _cam_pos, "look": _cam_look}
	elif _shot.has("pos"):
		var f := 1.0 - exp(-_cam_k * delta)
		_cam_pos = _cam_pos.lerp(_shot.pos, f)
		_cam_look = _cam_look.lerp(_shot.look, f)
	var gp: Vector3 = w.g(_cam_pos)
	var gl: Vector3 = w.g(_cam_look)
	var xf := Transform3D(Basis.looking_at(gl - gp, Vector3.UP), gp)
	return [xf, gp.distance_to(gl) * 0.9]

func on_respawn() -> void:
	pass
