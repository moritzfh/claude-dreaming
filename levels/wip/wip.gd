## Work in Progress – a painting that isn't finished yet.
##
## Claude walks on her own here (her controls are still a TODO), and the
## player is the level editor: pause time, put down placeholder blocks, ramps
## and springs, give wireframes their collision – and in the end drag the
## game's own UI under Claude's feet. Five stages, each a bit less finished:
## painted → missing textures → grey-box → wireframe → pencil sketch.
##
## If you want to build a level that isn't a platformer, this is the example:
## Claude's input is off (control_enabled = false), the level steers her with
## `auto_target`, freezes her by switching her process_mode, and moves her
## camera rig itself. editor.gd is the editor's UI and input, stages.gd the
## maps, world.gd the meshes and materials.
extends DreamLevel

const ST := preload("res://levels/wip/stages.gd")
const WB := preload("res://levels/wip/world.gd")
const ED := preload("res://levels/wip/editor.gd")
const SKY := preload("res://levels/wip/shaders/sky.gdshader")
const GRID := preload("res://levels/wip/shaders/grid.gdshader")
const MONO := preload("res://levels/wip/fonts/JetBrainsMono-Regular.woff2")
const MONO_B := preload("res://levels/wip/fonts/JetBrainsMono-Bold.woff2")
const SERIF := preload("res://assets/fonts/EBGaramond-Italic.woff2")
const DIR := "res://levels/wip/"

const W := ST.W
const CAM_D := 22.0
const CAM_FOV := 30.0
const CAM_TILT := 0.17
const WALK := 2.8
const SPRING_V := 11.0
const FALL_Y := -1.4
const PX := 1.0 / 91.6          # one screen pixel (at 1080p) on the walking plane
const INV_KEY := {"block": "block", "ramp_r": "ramp", "ramp_l": "ramp", "spring": "spring", "col_add": "col_add", "col_del": "col_del"}
const TOOL_ORDER := ["block", "ramp_r", "ramp_l", "spring", "col_add", "col_del"]

var stage := 0
var playing := false
## the editor doesn't react (intro, falling, the finale)
var locked := true
var dir := 1.0
var inv := {}
## Vector2i -> {kind: ground | decor | piece | wire | panel, …}
var cells := {}
var pieces: Array = []
var wires: Array = []
var panels: Array = []
var starts: Array = []
var editor: Node
var falls := 0
var edit_view := 0.0            # 0 while playing, 1 while paused (editor overlays fade with it)

var _sky: ShaderMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _grid: MeshInstance3D
var _grid_mat: ShaderMaterial
var _cam_focus := Vector3.ZERO
var _stage_f := 0.0
var _turn_cd := 0.0
var _spring_cd := 0.0
var _falling := false
var _stop_at := 1e9
var _won := false
var _goal: Node3D
var _goal_pos := Vector3.ZERO
var _left_wall: StaticBody3D
var _wall_said := false
var _subtitle_moved := false
var _t := 0.0
var _decor: Array = []          # [char, cell, stage]
var _wire_cells := {}           # "stage:letter" -> Array of Vector2i
var _bobbers: Array = []        # [node, base y, speed]
var _invisible: Array = []      # meshes shown only while paused
var _dev_stage := 0
var _leaving_wip := false

# ================================================================== build
func build() -> void:
	_parse()
	_environment()
	for i in ST.N: _build_stage(i)
	_build_walls()
	_build_grid()
	_build_goal()
	var c := spawn_claude(start_pos(0), PI)
	c.kill_y = -1e9                    # falling is handled here
	c.control_enabled = false          # her controls are a TODO …
	c.auto_speed = WALK
	c.step_kind = ST.STAGES[0]["steps"]
	c.set_process(false)               # the camera is ours
	c.set_process_unhandled_input(false)   # the mouse is the editor's
	c.axis_lock_linear_z = true
	c.camera.fov = CAM_FOV
	c.spring.spring_length = CAM_D
	c.spring.collision_mask = 0
	c.camera.position = Vector3(0, 0, CAM_D)
	c.rig.rotation.y = PI              # looking at you
	_cam_focus = _focus(0)
	_apply_cam()
	_freeze(true)
	inv = (ST.STAGES[0]["inv"] as Dictionary).duplicate()
	editor = ED.new()
	editor.name = "Editor"
	editor.level = self
	add_child(editor)
	# for testing: -- --wip_stage=3 starts in the fourth stage
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wip_stage="): _dev_stage = clampi(int(a.substr(12)), 0, ST.N - 1)
	if _dev_stage > 0:
		_setup_stage(_dev_stage)
		_cam_focus = _focus(_dev_stage)
		_stage_f = _dev_stage
		_grid.position.x = _dev_stage * W + W * 0.5
		_apply_look(_dev_stage, 0.0)
		claude.teleport(Transform3D(Basis(Vector3.UP, PI), start_pos(_dev_stage)))
		_stop_at = 1e9
		_apply_cam()
	Sound.music(DIR + "audio/wip_%d.ogg" % _dev_stage, 1.0)
	intro_finished.connect(_on_intro, CONNECT_ONE_SHOT)

func _parse() -> void:
	for i in ST.N:
		var m: Array = ST.STAGES[i]["map"]
		var rows := m.size()
		starts.append(Vector2i(i * W + 2, 3))
		for li in rows:
			var r := rows - 1 - li
			var line: String = m[li]
			for c in line.length():
				var ch := line[c]
				var cell := Vector2i(i * W + c, r)
				match ch:
					"#": cells[cell] = {"kind": "ground"}
					"S": starts[i] = cell
					"G": _goal_pos = Vector3(cell.x + 0.5, r + 0.7, 0)
					"t", "b", "f", "n", "d", "E": _decor.append([ch, cell, i])
					"A", "B", "C", "D", "I":
						var key := "%d:%s" % [i, ch]
						if not _wire_cells.has(key): _wire_cells[key] = []
						(_wire_cells[key] as Array).append(cell)

func _focus(i: int) -> Vector3:
	return Vector3(i * W + 12.0, 4.6, 0.0)

func start_pos(i: int) -> Vector3:
	var s: Vector2i = starts[i]
	return Vector3(s.x + 0.5, s.y + 0.02, 0.0)

func _environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	var sky := Sky.new()
	_sky = ShaderMaterial.new()
	_sky.shader = SKY
	sky.sky_material = _sky
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.58, 0.52, 0.78)
	_env.ambient_light_energy = 0.55
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_exposure = 1.05
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_hdr_threshold = 1.1
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.12
	_env.ssao_enabled = true
	_env.ssao_intensity = 1.0
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	_sun.light_color = Color(1.0, 0.92, 0.80)
	_sun.light_energy = 1.25
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.2
	_sun.directional_shadow_max_distance = 70.0
	add_child(_sun)

## the ground of a stage as boxes: grow each one up first, then right
func _rects(i: int) -> Array:
	var seen := {}
	var out: Array = []
	for c in range(i * W, (i + 1) * W):
		for r in 12:
			var cell := Vector2i(c, r)
			if seen.has(cell) or not _is_ground(cell): continue
			var h := 0
			while _is_ground(Vector2i(c, r + h)) and not seen.has(Vector2i(c, r + h)): h += 1
			var w := 1
			while c + w < (i + 1) * W:
				var ok := true
				for k in h:
					var q := Vector2i(c + w, r + k)
					if not _is_ground(q) or seen.has(q): ok = false; break
				if not ok: break
				w += 1
			for x in w:
				for y in h: seen[Vector2i(c + x, r + y)] = true
			out.append(Rect2i(c, r, w, h))
	return out

func _is_ground(cell: Vector2i) -> bool:
	return cells.has(cell) and cells[cell]["kind"] == "ground"

func _build_stage(i: int) -> void:
	var look: String = ST.STAGES[i]["look"]
	var root := Node3D.new()
	root.name = "Stage%d" % i
	add_child(root)
	for r in _rects(i):
		_ground_box(root, r, look)
	if look == "painted": _grass(root, i)
	for d in _decor:
		if int(d[2]) == i: _build_decor(root, d[0], d[1], look)
	for key in _wire_cells:
		if int((key as String).get_slice(":", 0)) == i:
			_build_wire(root, (key as String).get_slice(":", 1), _wire_cells[key])
	_signs(root, i)

func _ground_box(root: Node3D, r: Rect2i, look: String) -> void:
	var size := Vector3(r.size.x, r.size.y, WB.DEPTH)
	var center := Vector3(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, 0.0)
	var body := StaticBody3D.new()
	body.position = center
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	root.add_child(body)
	# the picture reaches down out of view (cliffs instead of floating
	# slabs) and further back than Claude's path (room for trees)
	var deep := 5.0 if r.position.y == 0 else 0.0
	var vs := Vector3(size.x, size.y + deep, WB.VIS_DEPTH)
	var off := Vector3(0, -deep * 0.5, WB.VIS_Z)
	match look:
		"painted":
			body.add_child(WB.mesh_node(WB.box(vs), WB.grass_mat(), off))
			body.add_child(WB.mesh_node(WB.box(Vector3(size.x + 0.08, 0.2, WB.VIS_DEPTH + 0.08)), WB.cap_mat(), Vector3(0, size.y * 0.5 - 0.07, WB.VIS_Z)))
		"missing":
			# the grass on top loaded, the rest didn't
			body.add_child(WB.mesh_node(WB.box(vs), WB.missing_mat(), off))
			body.add_child(WB.mesh_node(WB.box(Vector3(size.x + 0.08, 0.2, WB.VIS_DEPTH + 0.08)), WB.cap_mat(), Vector3(0, size.y * 0.5 - 0.07, WB.VIS_Z)))
		"proto":
			body.add_child(WB.mesh_node(WB.box(vs), WB.proto_mat(), off))
		"wire":
			body.add_child(WB.mesh_node(WB.box(vs), WB.wire_mat(vs, 0.3), off))
		"sketch":
			body.add_child(WB.mesh_node(WB.box(vs), WB.sketch_mat(vs), off))

## grass tufts and little flowers on top of the painted ground
func _grass(root: Node3D, i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + i
	var tufts: Array = []
	var flowers: Array = []
	for cell in cells:
		var cl: Vector2i = cell
		if cl.x < i * W or cl.x >= (i + 1) * W or not _is_ground(cl) or _is_ground(cl + Vector2i(0, 1)): continue
		for k in 9:
			var z := rng.randf_range(-2.5, 0.82) if k > 2 else rng.randf_range(0.55, 0.86)
			tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), Vector3(cl.x + rng.randf(), cl.y + 1.02, z)))
		if rng.randf() < 0.55:
			for k in rng.randi_range(1, 3):
				flowers.append([Vector3(cl.x + rng.randf(), cl.y + 1.1, rng.randf_range(-2.4, 0.75)), [Color(1.0, 0.55, 0.72), Color(1.0, 0.9, 0.45), Color(1.0, 1.0, 0.95), Color(0.7, 0.62, 1.0)][rng.randi() % 4]])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = WB.tuft_mesh()
	mm.instance_count = tufts.size()
	for k in tufts.size(): mm.set_instance_transform(k, tufts[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = WB.vcol_mat()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.06; sm.height = 0.1; sm.radial_segments = 8; sm.rings = 4
	fm.mesh = sm
	fm.instance_count = flowers.size()
	for k in flowers.size():
		fm.set_instance_transform(k, Transform3D(Basis(), flowers[k][0]))
		fm.set_instance_color(k, flowers[k][1])
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.emission_enabled = true
	fmat.emission = Color(0.25, 0.2, 0.2)
	fmi.material_override = fmat
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fmi)

func _block_cells(cell: Vector2i, h: int) -> void:
	for k in h:
		if not cells.has(cell + Vector2i(0, k)): cells[cell + Vector2i(0, k)] = {"kind": "decor"}

func _build_decor(root: Node3D, ch: String, cell: Vector2i, look: String) -> void:
	var base := Vector3(cell.x + 0.5, cell.y, -1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = cell.x * 31 + cell.y
	match ch:
		"t":
			_block_cells(cell, 3)
			root.add_child(_tree(base + Vector3(0, 0, -0.55), look, rng))
		"b":
			_block_cells(cell, 1)
			var n := Node3D.new()
			n.position = base
			for k in 3:
				var s := SphereMesh.new()
				var r := rng.randf_range(0.3, 0.42)
				s.radius = r; s.height = r * 1.8
				n.add_child(WB.mesh_node(s, _foliage(look, Color(0.36, 0.7, 0.36)), Vector3((k - 1) * 0.32, r * 0.75, rng.randf_range(-0.1, 0.1))))
			root.add_child(n)
		"f":
			# a little bunch of flowers on stems (only where the ground is painted)
			for k in 6:
				var p := base + Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(0.2, 1.7))
				var stem := CylinderMesh.new()
				stem.top_radius = 0.012; stem.bottom_radius = 0.015; stem.height = 0.32
				root.add_child(WB.mesh_node(stem, WB.plain(Color(0.3, 0.6, 0.3)), p + Vector3(0, 0.16, 0)))
				var head := SphereMesh.new()
				head.radius = 0.07; head.height = 0.1
				var col: Color = [Color(1.0, 0.5, 0.65), Color(1.0, 0.85, 0.35), Color(0.75, 0.6, 1.0)][k % 3]
				root.add_child(WB.mesh_node(head, WB.plain(col, Color(1, 1, 1)) if look == "painted" else WB.missing_mat(8.0), p + Vector3(0, 0.33, 0)))
		"n":
			_block_cells(cell, 2)
			_sign(root, base + Vector3(0, 0, 0.1), "# TODO: add controls", look)
		"d":
			_block_cells(cell, 2)
			root.add_child(_dummy(base))
		"E":
			_block_cells(cell, 2)
			var l := _label3d("ERROR", MONO_B, 110, Color(1.0, 0.12, 0.1))
			l.outline_modulate = Color(0.25, 0.0, 0.0)
			l.position = Vector3(cell.x + 1.5, cell.y + 3.9, 0.9)
			root.add_child(l)
			_bobbers.append([l, l.position.y, 1.3])

func _foliage(look: String, col: Color) -> Material:
	match look:
		"missing": return WB.missing_mat(3.0)
		"proto": return WB.proto_mat(Color(0.62, 0.66, 0.6))
		"wire": return WB.wire_round(Vector2(12, 6))
		"sketch": return WB.sketch_round(Color(0.92, 1.0, 0.9))
	return WB.toon({"mode": 1, "base_col": col, "stripe_col": col, "stripe_scale": 1.0,
		"rim_col": Color(1.0, 0.95, 0.7), "rim_strength": 0.55, "shadow_tint": Color(0.3, 0.35, 0.7)})

func _tree(base: Vector3, look: String, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	n.position = base
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.1; trunk.bottom_radius = 0.17; trunk.height = 1.5
	var tmat: Material
	match look:
		"proto": tmat = WB.proto_mat()
		"wire": tmat = WB.wire_round(Vector2(8, 4))
		"sketch": tmat = WB.sketch_round(Color(1.0, 0.95, 0.88))
		_: tmat = WB.plain(Color(0.55, 0.36, 0.26))
	n.add_child(WB.mesh_node(trunk, tmat, Vector3(0, 0.75, 0)))
	var leaf := _foliage(look, Color(0.32, 0.66, 0.34))
	if look == "proto":
		var s := SphereMesh.new()
		s.radius = 0.75; s.height = 1.5
		n.add_child(WB.mesh_node(s, leaf, Vector3(0, 2.0, 0)))
		var l := _label3d("TODO: tree", MONO, 30, Color(0.15, 0.15, 0.18))
		l.outline_modulate = Color(1, 1, 1, 0.8)
		l.position = Vector3(0, 2.0, 0.8)
		n.add_child(l)
		return n
	var blobs := [[Vector3(0, 1.85, 0), 0.72], [Vector3(-0.42, 1.55, 0.12), 0.5], [Vector3(0.45, 1.6, -0.05), 0.55], [Vector3(0.05, 2.35, -0.1), 0.48]]
	for b in blobs:
		var s := SphereMesh.new()
		var r: float = float(b[1]) * rng.randf_range(0.92, 1.08)
		s.radius = r; s.height = r * 2.0
		n.add_child(WB.mesh_node(s, leaf, b[0]))
	return n

## a T-posing grey mannequin, the placeholder of every NPC
func _dummy(base: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = base
	var m := WB.proto_mat(Color(0.78, 0.78, 0.8))
	var body := CapsuleMesh.new()
	body.radius = 0.22; body.height = 0.95
	n.add_child(WB.mesh_node(body, m, Vector3(0, 0.95, 0)))
	var head := SphereMesh.new()
	head.radius = 0.19; head.height = 0.38
	n.add_child(WB.mesh_node(head, m, Vector3(0, 1.62, 0)))
	var arms := WB.box(Vector3(1.5, 0.13, 0.13))
	n.add_child(WB.mesh_node(arms, m, Vector3(0, 1.28, 0)))
	for s in [-1.0, 1.0]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.08; leg.height = 0.7
		n.add_child(WB.mesh_node(leg, m, Vector3(s * 0.11, 0.35, 0)))
	var l := _label3d("npc_dummy.tscn", MONO, 28, Color(0.15, 0.15, 0.18))
	l.outline_modulate = Color(1, 1, 1, 0.85)
	l.position = Vector3(0, 2.05, 0.3)
	n.add_child(l)
	return n

func _sign(root: Node3D, pos: Vector3, text: String, look: String) -> void:
	var n := Node3D.new()
	n.position = pos
	root.add_child(n)
	var wood := WB.plain(Color(0.6, 0.42, 0.28)) if look == "painted" else WB.proto_mat()
	var post := CylinderMesh.new()
	post.top_radius = 0.05; post.bottom_radius = 0.06; post.height = 1.3
	n.add_child(WB.mesh_node(post, wood, Vector3(0, 0.65, -0.05)))
	var board := WB.box(Vector3(4.6, 0.62, 0.06))
	n.add_child(WB.mesh_node(board, WB.plain(Color(0.16, 0.17, 0.21), Color(0.5, 0.6, 0.9)), Vector3(0, 1.25, 0)))
	var l := _label3d(text, MONO, 28, Color(0.55, 0.85, 0.5))
	l.outline_size = 0
	l.position = Vector3(0, 1.25, 0.04)
	n.add_child(l)

func _label3d(text: String, font: Font, size: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = PX
	l.modulate = col
	l.outline_size = 8
	l.outline_modulate = Color(0.08, 0.06, 0.12, 0.85)
	l.shaded = false
	l.double_sided = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return l

## the jokes that are written on the walls
func _signs(root: Node3D, i: int) -> void:
	var x0 := i * W
	var notes: Array = []
	match i:
		1:
			notes = [["texture_not_found.png", MONO, 30, Color(1.0, 0.45, 1.0), Vector3(x0 + 8.5, 7.6, 0.4)],
				["missing: res://grass_final.png", MONO, 24, Color(1.0, 0.6, 1.0), Vector3(x0 + 18.5, 5.6, 0.4)]]
		2:
			notes = [["placeholder_final_v2_FINAL.tscn", MONO, 30, Color(0.18, 0.18, 0.2), Vector3(x0 + 10.5, 8.6, 0.4)]]
		3:
			notes = [["⚠ Node has no collision shape", MONO, 26, Color(1.0, 0.82, 0.3), Vector3(x0 + 8.0, 4.7, 0.9)],
				["⚠ Node has no collision shape", MONO, 26, Color(1.0, 0.82, 0.3), Vector3(x0 + 14.0, 3.55 + 3.2, 0.9)],
				["Node3D", MONO, 24, Color(0.85, 0.9, 1.0), Vector3(x0 + 3.2, 8.3, 0.4)]]
			# the move gizmo of a lonely Node3D: red x, green y, blue z
			var g := Node3D.new()
			g.position = Vector3(x0 + 3.2, 7.0, 0.0)
			root.add_child(g)
			for ax in [[Vector3.RIGHT, Color(0.95, 0.3, 0.32)], [Vector3.UP, Color(0.45, 0.9, 0.3)], [Vector3.BACK, Color(0.35, 0.55, 1.0)]]:
				var d: Vector3 = ax[0]
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = ax[1]
				var shaft := WB.mesh_node(WB.box(Vector3(0.06, 0.06, 0.06) + d.abs() * 0.84), m, d * 0.45)
				g.add_child(shaft)
				var tip := CylinderMesh.new()
				tip.top_radius = 0.0; tip.bottom_radius = 0.12; tip.height = 0.3
				var tn := WB.mesh_node(tip, m, d * 1.0)
				if d == Vector3.RIGHT: tn.rotation_degrees = Vector3(0, 0, -90)
				elif d == Vector3.BACK: tn.rotation_degrees = Vector3(90, 0, 0)
				g.add_child(tn)
		4:
			notes = [["nothing here yet …", SERIF, 44, Color(0.3, 0.3, 0.34), Vector3(x0 + 11.5, 6.8, 0.2)],
				["Goal? →", SERIF, 40, Color(0.3, 0.3, 0.34), Vector3(x0 + 18.3, 3.2, 0.2)],
				["TODO: bridge", SERIF, 36, Color(0.75, 0.3, 0.3), Vector3(x0 + 7.0, 0.2, 0.2)]]
	for nt in notes:
		var l := _label3d(nt[0], nt[1], nt[2], nt[3])
		l.position = nt[4]
		if i == 4 or i == 2: l.outline_size = 0
		root.add_child(l)
		if i == 1: _bobbers.append([l, l.position.y, 0.9])

func _build_wire(root: Node3D, letter: String, cl: Array) -> void:
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := Vector2i(-(1 << 20), -(1 << 20))
	for c in cl:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var size := Vector3(mx.x - mn.x + 1, mx.y - mn.y + 1, WB.DEPTH)
	var invisible := letter == "I"
	var body := StaticBody3D.new()
	body.position = Vector3(mn.x + size.x * 0.5, mn.y + size.y * 0.5, 0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.disabled = not invisible
	body.add_child(cs)
	root.add_child(body)
	# objects standing on the ground reach down out of view like the ground
	var deep := 5.0 if mn.y == 0 else 0.0
	var vs := Vector3(size.x, size.y + deep, WB.VIS_DEPTH if mn.y == 0 else size.z)
	var mat := WB.wire_mat(vs, 0.0)
	if invisible:
		mat.set_shader_parameter("line_col", Color(0.55, 0.85, 1.0, 0.0))
		mat.set_shader_parameter("fill_col", Color(0.3, 0.75, 0.95, 0.0))
		mat.set_shader_parameter("stripes", 1.0)
	var mi := WB.mesh_node(WB.box(vs), mat, Vector3(0, -deep * 0.5, WB.VIS_Z if mn.y == 0 else 0.0))
	body.add_child(mi)
	var w := {"id": letter, "body": body, "shape": cs, "mat": mat, "mesh": mi, "base": invisible, "col": invisible,
		"invisible": invisible, "size": vs, "rect": Rect2i(mn, mx - mn + Vector2i.ONE)}
	if invisible: _invisible.append(w)
	wires.append(w)
	for c in cl: cells[c] = {"kind": "wire", "wire": w}

func _build_walls() -> void:
	_left_wall = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 60.0, 4.0)
	cs.shape = bs
	_left_wall.add_child(cs)
	_left_wall.position = Vector3(-0.5, 20.0, 0.0)
	add_child(_left_wall)
	var right := StaticBody3D.new()
	var cs2 := CollisionShape3D.new()
	cs2.shape = bs
	right.add_child(cs2)
	right.position = Vector3(ST.N * W + 0.5, 20.0, 0.0)
	add_child(right)

func _build_grid() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(W, 11.0)
	_grid_mat = WB.shader_mat(GRID)
	_grid = WB.mesh_node(q, _grid_mat, Vector3(W * 0.5, 5.5, 0.0))
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)

func _build_goal() -> void:
	_goal = Node3D.new()
	_goal.position = _goal_pos
	add_child(_goal)
	var m := WB.toon({"mode": 1, "base_col": Color(1.0, 0.8, 0.25), "stripe_col": Color(1.0, 0.92, 0.55), "stripe_scale": 4.0,
		"rim_col": Color(1.0, 1.0, 0.8), "rim_strength": 0.9, "glow": 0.55, "shadow_tint": Color(0.85, 0.5, 0.3)})
	_goal.add_child(WB.mesh_node(WB.star_mesh(), m))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.45)
	light.omni_range = 4.0
	light.light_energy = 1.4
	_goal.add_child(light)
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7
	p.gravity = Vector3(0, 0.4, 0)
	p.initial_velocity_min = 0.1; p.initial_velocity_max = 0.35
	var pm := SphereMesh.new()
	pm.radius = 0.04; pm.height = 0.08
	p.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1.0, 0.95, 0.6)
	pmat.emission_enabled = true
	pmat.emission = Color(1.0, 0.85, 0.4)
	pmat.emission_energy_multiplier = 2.0
	p.material_override = pmat
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	_goal.add_child(p)

# ================================================================== pieces (the editor's API)
func stage_cols() -> Vector2i:
	return Vector2i(stage * W, stage * W + W - 1)

## the cell under a point on the screen (the walking plane z = 0)
func screen_to_world(pos: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return Vector3.ZERO
	var o := cam.project_ray_origin(pos)
	var d := cam.project_ray_normal(pos)
	if absf(d.z) < 1e-4: return o
	var t := -o.z / d.z
	return o + d * t

func screen_to_cell(pos: Vector2) -> Vector2i:
	var p := screen_to_world(pos)
	return Vector2i(floori(p.x), floori(p.y))

func world_to_screen(p: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(p) if cam else Vector2.ZERO

func tools() -> Array:
	var out: Array = []
	var stage_inv: Dictionary = ST.STAGES[stage]["inv"]
	for t in TOOL_ORDER:
		if stage_inv.has(INV_KEY[t]): out.append(t)
	return out

func inv_count(tool: String) -> int:
	return int(inv.get(INV_KEY.get(tool, tool), 0))

func _claude_cells() -> Array:
	var out: Array = []
	if claude == null: return out
	var p := claude.global_position
	for x in range(floori(p.x - 0.32), floori(p.x + 0.32) + 1):
		for y in range(floori(p.y + 0.02), floori(p.y + 1.05) + 1):
			out.append(Vector2i(x, y))
	return out

## may something be put into `cell`? (ignore = a piece or panel being moved)
func cell_free(cell: Vector2i, ignore = null) -> bool:
	var cols := stage_cols()
	if cell.x < cols.x or cell.x > cols.y or cell.y < 0 or cell.y > 8: return false
	if cells.has(cell):
		var e: Dictionary = cells[cell]
		if ignore == null: return false
		if e.get("piece") != ignore and e.get("panel") != ignore: return false
	var s: Vector2i = starts[stage]
	if cell == s or cell == s + Vector2i(0, 1): return false
	if Vector2i(floori(_goal_pos.x), floori(_goal_pos.y)) == cell: return false
	if cell in _claude_cells(): return false
	return true

func can_place(tool: String, cell: Vector2i) -> bool:
	if not tool in ["block", "ramp_r", "ramp_l", "spring"]: return false
	return inv_count(tool) > 0 and cell_free(cell)

func what_at(cell: Vector2i) -> Dictionary:
	if not cells.has(cell): return {}
	var e: Dictionary = cells[cell]
	var cols := stage_cols()
	if cell.x < cols.x or cell.x > cols.y: return {}
	return e

func place(tool: String, cell: Vector2i) -> Dictionary:
	if not can_place(tool, cell): return {}
	inv[INV_KEY[tool]] = inv_count(tool) - 1
	var p := {"kind": tool, "cell": cell, "stage": stage}
	_make_piece(p)
	_occupy(p, cell)
	pieces.append(p)
	_pop(p["node"])
	return p

func _make_piece(p: Dictionary) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	body.add_child(cs)
	match p["kind"]:
		"block":
			var bs := BoxShape3D.new()
			bs.size = Vector3(1, 1, WB.DEPTH)
			cs.shape = bs
			body.add_child(WB.mesh_node(WB.box(Vector3(1, 1, WB.DEPTH)), WB.orange_mat()))
		"ramp_r", "ramp_l":
			var r := WB.ramp(1.0 if p["kind"] == "ramp_r" else -1.0)
			var cv := ConvexPolygonShape3D.new()
			cv.points = r[1]
			cs.shape = cv
			body.add_child(WB.mesh_node(r[0], WB.orange_mat()))
		"spring":
			var bs := BoxShape3D.new()
			bs.size = Vector3(1, 0.05, WB.DEPTH)
			cs.shape = bs
			cs.position = Vector3(0, -0.475, 0)
			body.add_child(_spring_mesh())
	add_child(body)
	body.position = Vector3(p["cell"].x + 0.5, p["cell"].y + 0.5, 0)
	p["node"] = body
	p["shape"] = cs

func _spring_mesh() -> Node3D:
	var n := Node3D.new()
	n.name = "Spring"
	n.add_child(WB.mesh_node(WB.box(Vector3(0.94, 0.1, 1.2)), WB.orange_mat(), Vector3(0, -0.45, 0)))
	var coil := Node3D.new()
	coil.name = "Coil"
	coil.position = Vector3(0, -0.4, 0)
	n.add_child(coil)
	var steel := WB.toon({"mode": 1, "base_col": Color(0.75, 0.78, 0.84), "stripe_col": Color(0.9, 0.92, 0.96), "stripe_scale": 0.001, "rim_col": Color(1, 1, 1), "rim_strength": 0.6})
	for k in 4:
		var t := TorusMesh.new()
		t.inner_radius = 0.2; t.outer_radius = 0.27
		coil.add_child(WB.mesh_node(t, steel, Vector3(0, 0.05 + k * 0.08, 0)))
	var pad := CylinderMesh.new()
	pad.top_radius = 0.38; pad.bottom_radius = 0.38; pad.height = 0.08
	var red := WB.toon({"mode": 1, "base_col": Color(0.95, 0.3, 0.3), "stripe_col": Color(1.0, 0.95, 0.95), "stripe_scale": 0.001, "rim_col": Color(1, 0.9, 0.9), "rim_strength": 0.5})
	var padn := WB.mesh_node(pad, red, Vector3(0, -0.04, 0))
	padn.name = "Pad"
	n.add_child(padn)
	return n

func _occupy(p: Dictionary, cell: Vector2i) -> void:
	p["cell"] = cell
	cells[cell] = {"kind": "piece", "piece": p}

func _vacate(p: Dictionary) -> void:
	var c: Vector2i = p["cell"]
	if cells.has(c) and cells[c].get("piece") == p: cells.erase(c)

## the editor picks a piece up (it follows the cursor, no collision meanwhile)
func pick(p: Dictionary) -> void:
	_vacate(p)
	(p["shape"] as CollisionShape3D).disabled = true

func drop(p: Dictionary, cell: Vector2i) -> bool:
	var ok := cell_free(cell)
	var at: Vector2i = cell if ok else p["cell"]
	_occupy(p, at)
	(p["node"] as Node3D).position = Vector3(at.x + 0.5, at.y + 0.5, 0)
	(p["shape"] as CollisionShape3D).disabled = false
	if ok: _pop(p["node"])
	return ok

func remove(p: Dictionary) -> void:
	_vacate(p)
	pieces.erase(p)
	inv[INV_KEY[p["kind"]]] = inv_count(p["kind"]) + 1
	var n: Node3D = p["node"]
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(0.05, 0.05, 0.05), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)

## put a removed piece back (undo)
func restore(p: Dictionary) -> bool:
	if inv_count(p["kind"]) <= 0 or not cell_free(p["cell"]): return false
	inv[INV_KEY[p["kind"]]] = inv_count(p["kind"]) - 1
	_make_piece(p)
	_occupy(p, p["cell"])
	pieces.append(p)
	_pop(p["node"])
	return true

func _pop(n: Node3D) -> void:
	n.scale = Vector3(0.7, 0.7, 0.7)
	create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## collision tools on a wireframe: add (+) or remove (−); returns success
func wire_tool(w: Dictionary, add: bool) -> bool:
	var key := "col_add" if add else "col_del"
	if inv_count(key) <= 0 or bool(w["col"]) == add or w.has("changed"): return false
	if not add and claude and (w["body"] as Node3D) == _standing_on(): return false
	inv[key] = inv_count(key) - 1
	w["changed"] = key
	_set_wire_col(w, add)
	return true

## undo what a collision tool did (refund)
func wire_revert(w: Dictionary) -> bool:
	if not w.has("changed"): return false
	var key: String = w["changed"]
	inv[key] = inv_count(key) + 1
	w.erase("changed")
	_set_wire_col(w, bool(w["base"]))
	return true

func _set_wire_col(w: Dictionary, on: bool) -> void:
	w["col"] = on
	(w["shape"] as CollisionShape3D).disabled = not on
	var mat: ShaderMaterial = w["mat"]
	if bool(w["invisible"]):
		return            # its look follows the edit view (see _process)
	var tw := create_tween()
	tw.tween_method(func(a: float): mat.set_shader_parameter("fill_col", Color(0.2, 0.7, 0.85, a)), 0.0 if on else 0.3, 0.3 if on else 0.0, 0.3)
	if on:
		Sound.sfx("sparkle", -6.0, 1.4)

func _standing_on() -> Object:
	if claude == null or not claude.is_on_floor(): return null
	for i in claude.get_slide_collision_count():
		var col := claude.get_slide_collision(i)
		if col.get_normal().y > 0.6: return col.get_collider()
	return null

# ================================================================== flow
func _on_intro() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if _dev_stage > 0:
		editor.reveal()
		editor.stage_changed()
		locked = false
		_arrived()
		if _dev_stage == ST.N - 1: _show_panels()
		return
	await _wait(0.5)
	say("Ooh, a fresh painting!", 1.4)
	await _wait(2.4)
	claude.rig.mood = RobotRig.Mood.NORMAL
	_set_playing(true)
	await _wait(1.0)
	say("Wait … why am I walking?", 1.2)

func _wait(t: float) -> Signal:
	var tw := create_tween()
	tw.tween_interval(t)
	return tw.finished

func _set_playing(on: bool) -> void:
	playing = on
	_freeze(not on)
	if editor: editor.mode_changed(on)

func _freeze(on: bool) -> void:
	claude.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT

## the editor's play / pause button
func toggle_play() -> void:
	if locked or _won: return
	_set_playing(not playing)
	Sound.sfx("blip", -6.0, 1.25 if playing else 0.85)

## the editor's ↺ button: Claude back to the start of the stage
func reset_claude() -> void:
	if locked or _won: return
	_respawn()
	Sound.sfx("whoosh", -8.0, 1.2)

func _respawn() -> void:
	claude.teleport(Transform3D(Basis(Vector3.UP, PI), start_pos(stage)))
	claude.auto_target = null
	claude.velocity = Vector3.ZERO
	dir = 1.0
	_set_playing(false)
	claude.rig.rotation.y = PI

func _physics_process(delta: float) -> void:
	if claude == null or intro_running: return
	_turn_cd -= delta
	_spring_cd -= delta
	var p := claude.global_position
	if playing and not _won and not _falling:
		_steer(p)
		if p.x >= _stop_at and claude.is_on_floor():
			_stop_at = 1e9
			_arrived()
	if not _falling and not _won and p.y < FALL_Y:
		_fall()
	if not _falling and stage + 1 < ST.N and p.x > (stage + 1) * W + 0.6:
		_enter_stage(stage + 1)
	if not _won and stage == ST.N - 1 and p.distance_to(_goal_pos - Vector3(0, 0.5, 0)) < 0.9:
		_win()

## walk on in the current direction, turn around at walls, jump off springs
func _steer(p: Vector3) -> void:
	if _turn_cd <= 0.0:
		for i in claude.get_slide_collision_count():
			var col := claude.get_slide_collision(i)
			if col.get_normal().x * dir < -0.9:
				dir = -dir
				_turn_cd = 0.3
				_bumped(col.get_collider())
				break
	claude.auto_target = Vector3(p.x + dir * 4.0, p.y, 0.0)
	if _spring_cd <= 0.0 and claude.is_on_floor():
		var e: Dictionary = cells.get(Vector2i(floori(p.x), floori(p.y + 0.03)), {})
		if e.get("kind") == "piece" and (e["piece"] as Dictionary)["kind"] == "spring":
			_spring_cd = 0.4
			claude.velocity = Vector3(dir * WALK, SPRING_V, 0.0)
			_boing(e["piece"])

func _bumped(what: Object) -> void:
	for w in _invisible:
		if w["body"] == what and not _wall_said:
			_wall_said = true
			say("Ow! There's something here … an invisible wall?", 2.2)
			editor.log_line("W  Invisible wall at x = %d" % int(w["rect"].position.x), "warn")

func _boing(p: Dictionary) -> void:
	Sound.sfx(DIR + "audio/boing.ogg", -3.0)
	var sp: Node3D = (p["node"] as Node).get_node("Spring")
	var coil: Node3D = sp.get_node("Coil")
	var pad: Node3D = sp.get_node("Pad")
	var tw := create_tween().set_parallel()
	coil.scale = Vector3(1, 0.4, 1)
	pad.position.y = -0.3
	tw.tween_property(coil, "scale", Vector3(1, 1.6, 1), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(pad, "position:y", 0.02, 0.12).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(coil, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pad, "position:y", -0.04, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _fall() -> void:
	_falling = true
	locked = true
	falls += 1
	editor.cancel_hold()
	editor.log_line("E  Claude fell out of the world (y < %.1f)" % FALL_Y, "error")
	Sound.sfx(DIR + "audio/fall.ogg", -4.0)
	await _wait(0.9)
	editor.show_error("Claude fell out of the world.", "position.y < kill_y   (stage %d, attempt %d)" % [stage + 1, falls])
	await editor.error_closed
	_respawn()
	_falling = false
	if not editor.revealed:
		await _tutorial()
	else:
		var line: String = ST.FALL_LINES[(falls - 1) % ST.FALL_LINES.size()]
		if stage == 3 and not editor.flags.has("wire_fall"):
			editor.flags["wire_fall"] = true
			line = "You're absolutely right! Wireframes are not floors."
		say(line, 2.0)
	locked = false

func _tutorial() -> void:
	say(ST.FALL_LINES[0], 2.0)
	await _wait(3.6)
	say("My controls aren't hooked up yet. There's a TODO where my legs should be.", 2.4)
	await _wait(4.6)
	editor.reveal()
	say("Hey … you. Yes, you, with the mouse. Could you build me a bridge?", 3.0)
	hint("Time stands still – you are the editor now.\nClick / E: place a block  ·  Right-click / Shift: take it back\nSpace: play / pause  ·  R: Claude back to the start", 16.0)

func _setup_stage(i: int) -> void:
	stage = i
	inv = (ST.STAGES[i]["inv"] as Dictionary).duplicate()
	claude.step_kind = ST.STAGES[i]["steps"]
	_left_wall.position.x = i * W - 0.5
	_stop_at = start_pos(i).x
	editor.stage_changed()

func _enter_stage(i: int) -> void:
	_setup_stage(i)
	Sound.music(DIR + "audio/wip_%d.ogg" % i, 2.5, maxf(Sound.music_pos(), 0.0))
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_cam_focus", _focus(i), 1.6)
	tw.tween_property(self, "_stage_f", float(i), 1.6)
	_apply_look(i, 1.6)
	tw.tween_property(_grid, "position:x", i * W + W * 0.5, 0.01).set_delay(1.6)
	if i == ST.N - 1:
		tw.chain().tween_callback(_show_panels)

## light and ambience of a stage
func _apply_look(i: int, dur: float) -> void:
	var looks := [[Color(1.0, 0.92, 0.80), 1.25, Color(0.58, 0.52, 0.78), 0.55],
		[Color(1.0, 0.92, 0.85), 1.2, Color(0.6, 0.5, 0.7), 0.55],
		[Color(1.0, 1.0, 1.0), 1.15, Color(0.62, 0.64, 0.7), 0.6],
		[Color(0.75, 0.82, 1.0), 0.8, Color(0.4, 0.45, 0.6), 0.5],
		[Color(1.0, 0.98, 0.94), 1.1, Color(0.75, 0.72, 0.7), 0.7]]
	var lk: Array = looks[i]
	if dur <= 0.0:
		_sun.light_color = lk[0]; _sun.light_energy = lk[1]
		_env.ambient_light_color = lk[2]; _env.ambient_light_energy = lk[3]
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sun, "light_color", lk[0], dur)
	tw.tween_property(_sun, "light_energy", lk[1], dur)
	tw.tween_property(_env, "ambient_light_color", lk[2], dur)
	tw.tween_property(_env, "ambient_light_energy", lk[3], dur)

## she arrived where the stage begins: time stops, she says something
func _arrived() -> void:
	_set_playing(false)
	editor.log_line("■  Stage %d: %s" % [stage + 1, ["fully painted", "missing textures", "grey box", "wireframe", "sketch"][stage]], "info")
	if stage == ST.N - 1: return     # the subtitle says it
	var lines: Array = ST.INTRO[stage]
	if ST.HINTS[stage] != "": hint(ST.HINTS[stage], 14.0)
	for l in lines:
		say(l[0], l[1])
		await _wait(float(l[1]) + 1.9)

func _process(delta: float) -> void:
	_t += delta
	_apply_cam()
	if _sky: _sky.set_shader_parameter("stage_f", _stage_f)
	edit_view = move_toward(edit_view, 0.0 if playing or locked else 1.0, delta * 4.0)
	if _grid_mat: _grid_mat.set_shader_parameter("amount", edit_view)
	for w in _invisible:
		var m: ShaderMaterial = w["mat"]
		var a := edit_view if bool(w["col"]) else edit_view * 0.35
		m.set_shader_parameter("line_col", Color(0.55, 0.85, 1.0, a))
		m.set_shader_parameter("fill_col", Color(0.3, 0.75, 0.95, 0.28 * a))
	if _goal and not _won:
		_goal.rotation.y = _t * 1.4
		_goal.position.y = _goal_pos.y + sin(_t * 2.2) * 0.12
	for b in _bobbers:
		var n: Node3D = b[0]
		if is_instance_valid(n): n.position.y = float(b[1]) + sin(_t * float(b[2]) + float(b[1])) * 0.08

func _apply_cam() -> void:
	if claude == null: return
	claude.cam_yaw_node.global_transform = Transform3D(Basis(Vector3.RIGHT, -CAM_TILT), _cam_focus)
	claude.cam_pitch_node.rotation = Vector3.ZERO

# ================================================================== the sketch: UI as platforms
func _build_panel(id: String, w: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Panel_" + id
	root.visible = false
	add_child(root)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 0.3, WB.DEPTH)
	cs.shape = bs
	cs.position = Vector3(0, -0.15, 0)
	cs.disabled = true
	body.add_child(cs)
	root.add_child(body)
	var vis := Node3D.new()
	vis.name = "Vis"
	root.add_child(vis)
	var center := Vector3.ZERO     # where the visual's middle is, relative to the top
	var mats: Array = []           # [material, alpha] – faded in when the panel appears
	match id:
		"subtitle":
			var l := _label3d("Is that … my subtitle?", SERIF, 46, Color(1.0, 0.90, 0.68))
			l.outline_size = 12
			l.outline_modulate = Color(0.12, 0.05, 0.18, 0.8)
			l.position = Vector3(0, -0.32, 0.05)
			vis.add_child(l)
			center = l.position
		"hint":
			var l := _label3d("Tip: drag me!", SERIF, 28, Color(1.0, 0.97, 0.92))
			l.outline_size = 8
			l.outline_modulate = Color(0.12, 0.05, 0.18, 0.8)
			l.position = Vector3(0, -0.22, 0.05)
			vis.add_child(l)
			center = l.position
		"toolbox":
			var bg := QuadMesh.new()
			bg.size = Vector2(w - 0.1, 1.2)
			var bm := StandardMaterial3D.new()
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.albedo_color = Color(0.13, 0.14, 0.17, 0.94)
			vis.add_child(WB.mesh_node(bg, bm, Vector3(0, -0.6, 0.02)))
			mats.append([bm, 0.94])
			for k in 4:
				var slot := QuadMesh.new()
				slot.size = Vector2(0.96, 0.96)
				var sm := StandardMaterial3D.new()
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sm.albedo_color = Color(0.22, 0.24, 0.29, 1.0)
				vis.add_child(WB.mesh_node(slot, sm, Vector3(-1.8 + k * 1.2, -0.6, 0.03)))
				mats.append([sm, 1.0])
			var l := _label3d("(empty)", MONO, 22, Color(0.62, 0.65, 0.72))
			l.outline_size = 0
			l.render_priority = 2
			l.position = Vector3(0, -0.6, 0.08)
			vis.add_child(l)
			center = Vector3(0, -0.6, 0)
	# the walkable top edge, shown once the panel is part of the world
	var edge := QuadMesh.new()
	edge.size = Vector2(w, 0.05)
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.albedo_color = Color(1.0, 0.85, 0.5, 0.0)
	var en := WB.mesh_node(edge, em, Vector3(0, -0.02, 0.1))
	root.add_child(en)
	var p := {"id": id, "w": w, "node": root, "shape": cs, "cell": Vector2i(-99, -99), "placed": false, "center": center, "edge": em, "mats": mats}
	panels.append(p)
	return p

## stage 5 begins: the subtitle, the hint and the toolbox stop being UI
func _show_panels() -> void:
	if panels.is_empty():
		_build_panel("subtitle", 6)
		_build_panel("hint", 4)
		_build_panel("toolbox", 5)
	var vs := get_viewport().get_visible_rect().size
	var spots := {"subtitle": Vector2(vs.x * 0.5, vs.y - 140.0), "hint": Vector2(36.0 + 105.0, 48.0), "toolbox": editor.hotbar_center()}
	var k := 0
	for p in panels:
		var n: Node3D = p["node"]
		n.position = screen_to_world(spots[p["id"]]) - (p["center"] as Vector3)
		p["hud_pos"] = n.position
		n.visible = true
		var vis: Node3D = n.get_node("Vis")
		var tw := create_tween().set_parallel()
		for l in vis.get_children():
			if l is Label3D:
				(l as Label3D).modulate.a = 0.0
				tw.tween_property(l, "modulate:a", 1.0, 0.8).set_delay(0.3 + k * 0.5)
		for m in p["mats"]:
			var mat: StandardMaterial3D = m[0]
			mat.albedo_color.a = 0.0
			tw.tween_property(mat, "albedo_color:a", float(m[1]), 0.4).set_delay(0.3 + k * 0.5)
		if p["id"] == "toolbox":
			tw.tween_callback(editor.hide_hotbar).set_delay(0.3 + k * 0.5)
		k += 1
	await _wait(6.0)
	if not _subtitle_moved:
		editor.log_line("Tip: you can grab the interface – drag it under Claude.", "warn")

func panel_at(cell: Vector2i) -> Dictionary:
	var e: Dictionary = what_at(cell)
	if e.get("kind") == "panel": return e["panel"]
	return {}

## panels that are still HUD (not placed yet) are found by their screen rect
func panel_on_screen(pos: Vector2) -> Dictionary:
	for p in panels:
		if bool(p["placed"]) or not (p["node"] as Node3D).visible: continue
		var n: Node3D = p["node"]
		var a := world_to_screen(n.position + (p["center"] as Vector3) - Vector3(float(p["w"]) * 0.5, 0.45, 0))
		var b := world_to_screen(n.position + (p["center"] as Vector3) + Vector3(float(p["w"]) * 0.5, 0.45, 0))
		if Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()).grow(10).has_point(pos): return p
	return {}

func panel_cells(p: Dictionary, left: Vector2i) -> Array:
	var out: Array = []
	for k in int(p["w"]): out.append(left + Vector2i(k, 0))
	return out

func panel_fits(p: Dictionary, left: Vector2i) -> bool:
	for c in panel_cells(p, left):
		if not cell_free(c, p): return false
	return true

func panel_pick(p: Dictionary) -> void:
	if bool(p["placed"]):
		for c in panel_cells(p, p["cell"]):
			if cells.has(c) and cells[c].get("panel") == p: cells.erase(c)
	(p["shape"] as CollisionShape3D).disabled = true

## follow the cursor while held
func panel_hover(p: Dictionary, left: Vector2i) -> void:
	var n: Node3D = p["node"]
	n.position = n.position.lerp(Vector3(left.x + float(p["w"]) * 0.5, left.y + 1.0, 0.0), 0.5)

func panel_drop(p: Dictionary, left: Vector2i) -> bool:
	var ok := panel_fits(p, left)
	if ok:
		p["cell"] = left
		if not bool(p["placed"]):
			p["placed"] = true
			create_tween().tween_property(p["edge"], "albedo_color:a", 0.75, 0.4)
	if bool(p["placed"]):
		var at: Vector2i = p["cell"]
		for c in panel_cells(p, at): cells[c] = {"kind": "panel", "panel": p}
		(p["shape"] as CollisionShape3D).disabled = false
		var n: Node3D = p["node"]
		n.position = Vector3(at.x + float(p["w"]) * 0.5, at.y + 1.0, 0.0)
	else:
		(p["node"] as Node3D).position = p["hud_pos"]       # back into the UI
	if ok and p["id"] == "subtitle" and not _subtitle_moved:
		_subtitle_moved = true
		_after_subtitle()
	return ok

func _after_subtitle() -> void:
	await _wait(0.8)
	say("Did you just … pick up my subtitle?", 2.0)
	await _wait(4.2)
	say("I'm going to walk on my own words, aren't I?", 2.4)

# ================================================================== the end
## leaving (finished, Esc menu or holding Backspace): the editor goes away and
## the world turns back into the painting it came from
func back_to_hub() -> void:
	if not _leaving_wip:
		_leaving_wip = true
		locked = true
		if editor: editor.hide_all()
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "_stage_f", 0.0, 1.5)
		_apply_look(0, 1.5)
	super()

func _win() -> void:
	_won = true
	locked = true
	editor.cancel_hold()
	claude.auto_target = null
	claude.rig.mood = RobotRig.Mood.HAPPY
	Sound.sfx(DIR + "audio/fanfare.ogg", -2.0)
	editor.log_line("✔  Goal reached", "ok")
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_goal, "scale", Vector3(1.8, 1.8, 1.8), 0.5)
	tw.tween_property(_goal, "position:y", _goal_pos.y + 1.2, 0.6)
	tw.chain().tween_property(_goal, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.6)
	await _wait(0.9)
	say("The star! Let me just … commit this.", 2.0)
	await _wait(3.4)
	await editor.commit_sequence()
	say("There. Now it's finished.", 2.0)
	GameState.stats[level_id] = {"done": true, "falls": falls}
	complete(3.6)
