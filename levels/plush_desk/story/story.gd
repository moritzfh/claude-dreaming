## The world inside the STORY planet: a 2.5D side-scrolling craft world with
## three depth layers. Built ahead of time far away from the desk and switched
## on when Claude dives into the planet.
##
## Sections (story/sec_*.gd) build their part of the course along +X and get
## update() every frame. The world handles the layers, the side camera,
## spools, checkpoints, the narrator, deaths and the recorded path (the finale
## embroiders it).
extends Node3D

const Kit := preload("res://levels/plush_desk/story/kit.gd")
const Narrator := preload("res://levels/plush_desk/story/narrator.gd")
const SPOOL_SHADER := preload("res://levels/plush_desk/shaders/spool.gdshader")
const A := "res://levels/plush_desk/audio/"
const FONT := preload("res://levels/plush_desk/fonts/Fredoka-Bold.woff2")
const KEYCAP := preload("res://levels/plush_desk/shaders/keycap.gdshader")
const Keyboard := preload("res://levels/plush_desk/keyboard.gd")

const ORIGIN := Vector3(4000.0, 0.0, 0.0)
## depth layers: 0 front, 1 middle, 2 back (z in the world)
const LANES := [1.25, 0.0, -1.25]
const SECTION_SCRIPTS := [
	"res://levels/plush_desk/story/sec_arrival.gd",
	"res://levels/plush_desk/story/sec_meadow.gd",
	"res://levels/plush_desk/story/sec_clouds.gd",
	"res://levels/plush_desk/story/sec_patches.gd",
	"res://levels/plush_desk/story/sec_machine.gd",
	"res://levels/plush_desk/story/sec_choice.gd",
	"res://levels/plush_desk/story/sec_tower.gd",
	"res://levels/plush_desk/story/sec_finale.gd",
	"res://levels/plush_desk/story/sec_life.gd",
]

var level: Node3D            # the DreamLevel (plush_desk.gd)
var claude: Player
var cam: Camera3D
var cam_attr: CameraAttributesPractical
var env: Environment
var lights: Array = []
var narrator: CanvasLayer
var hud: CanvasLayer
var spool_label: Label
var keep_icons: Array = []
var active := false
var sections: Array = []

# layers
var lane := 1
var lane_lock := false        # sections can switch off the layer control (tower, cutscenes)
var free_move := false        # no layer clamp at all (choice breakout, finale)
var radial := false           # a section keeps Claude on its own path (the yarn tower)
var input_yaw := 0.0          # which way "right" walks (0 = +X; the tower turns it)
var _face_dir := 1.0
var _lane_z := 0.0

# camera
var cam_mode := "follow"      # follow | fixed | custom
var cam_xf := Transform3D()   # target for fixed
var cam_custom: Callable      # returns [Transform3D, focus]
var cam_dist := 9.8
var cam_height := 1.7
var cam_fov := 38.0
var _cam_pos := Vector3()
var _cam_look := Vector3()
var _ground_y := 0.0
var _shake := 0.0

# spools
var spool_mm: MultiMesh
var spool_pos: Array = []      # local positions
var spool_got: Array = []
var spools := 0
var _chain := 0
var _chain_t := 0.0
var _counter_pop := 0.0

# checkpoints, keepsakes, record
var checkpoints: Array = []
var keepsakes := [false, false, false]
var deaths := 0
var path: Array = []           # [Vector2(x, y), …] local course coordinates
var events: Array = []         # [{"t": "spool"/"death"/"keep", "p": Vector2}, …]
var _rec_t := 0.0
var t := 0.0
var player_name := "Claude"
var choice := ""
var _narrated := {}
var _hurt_t := 0.0
var _from_hurt := false
var _last_floor := Vector3()
var typing_target: Object = null
var bouncers: Array = []       # {"c": Vector3, "s": Vector3, "v": float, "node": Node3D, "sq": float}
var updrafts: Array = []       # {"c": Vector3, "s": Vector3, "v": float}
var walk_speed := 4.0
var jump_velocity := 6.8
var signs: Array = []          # felt key signs that press with the real keys
var _sign_mat: ShaderMaterial
var _prompt := ""

func setup(lvl: Node3D) -> void:
	level = lvl
	name = "Story"
	position = ORIGIN
	process_physics_priority = 100
	visible = false
	_build_env()
	_build_backdrop()
	spool_mm = MultiMesh.new()
	spool_mm.transform_format = MultiMesh.TRANSFORM_3D
	spool_mm.use_colors = true
	spool_mm.use_custom_data = true
	spool_mm.mesh = _spool_mesh()
	for path_s in SECTION_SCRIPTS:
		if not ResourceLoader.exists(path_s):
			continue
		var sec: Object = (load(path_s) as GDScript).new()
		sec.set("w", self)
		sec.call("build")
		sections.append(sec)
	_finish_spools()
	narrator = Narrator.new()
	narrator.visible = false
	add_child(narrator)
	_build_hud()
	set_process(false)
	set_physics_process(false)

## runs before every node's physics: the mouse must not turn Claude's walking
## direction (she walks along the course, whatever the camera does)
func _before_physics() -> void:
	if active and claude:
		claude.yaw = input_yaw

# ------------------------------------------------------------------ helpers for sections
func prompt(text: String) -> void:
	if text != _prompt:
		_prompt = text
		if level and level.get("hud"):
			(level.get("hud") as GameHUD).set_prompt(text)

## a felt key on a little post showing which key to press; it squashes when
## the real key is pressed (physical key, legend follows the layout)
func key_sign(p: Vector3, phys: int, fixed := "", width := 1.0) -> void:
	if _sign_mat == null:
		_sign_mat = ShaderMaterial.new()
		_sign_mat.shader = KEYCAP
		_sign_mat.set_shader_parameter("albedo", Color(0.9, 0.84, 0.74))
		_sign_mat.set_shader_parameter("col1", Kit.CORAL)
		_sign_mat.set_shader_parameter("col2", Kit.TEAL)
		_sign_mat.set_shader_parameter("col3", Kit.MUSTARD)
		_sign_mat.set_shader_parameter("thread_color", Color(0.3, 0.22, 0.34))
		_sign_mat.set_shader_parameter("thread1", Color(0.99, 0.95, 0.87))
		_sign_mat.set_shader_parameter("fibre_tex", Kit.T_FELT)
		_sign_mat.set_shader_parameter("mottle_tex", Kit.T_MOTTLE)
		_sign_mat.set_shader_parameter("labels_tex", load("res://levels/plush_desk/textures/labels.png"))
		_sign_mat.set_shader_parameter("fibre_scale", 2.6)
		_sign_mat.set_shader_parameter("pitch", 0.55)
	var root := Node3D.new()
	root.position = p
	add_child(root)
	# post
	Kit.block(root, Vector3(0, 0.45, 0), Vector3(0.12, 0.9, 0.12), Color(0.62, 0.42, 0.3), Kit.CREAM, 0, false)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = level.get("keycap_mesh")
	mm.instance_count = 1
	var cell := _label_cell(phys, fixed)
	var colour := 3.0 if phys == KEY_SPACE else (1.0 if phys in [KEY_W, KEY_S] else (2.0 if phys == KEY_E else 0.0))
	mm.set_instance_custom_data(0, Color(width, float(cell), 0.0, colour))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _sign_mat
	mmi.position = Vector3(0, 0.95, 0)
	mmi.rotation = Vector3(PI * 0.5 - 0.35, 0, 0)   # tilted towards the camera
	mmi.scale = Vector3.ONE * 1.25
	root.add_child(mmi)
	mmi.custom_aabb = AABB(Vector3(-2, -1, -1), Vector3(4, 2, 2))
	signs.append({"mm": mm, "phys": phys, "press": 0.0, "down": false})

func _label_cell(phys: int, fixed: String) -> int:
	var labels: Array = Keyboard.LABELS
	if fixed != "":
		return labels.find(fixed)
	if phys == KEY_SPACE:
		return -1
	var code := phys
	if DisplayServer.get_name() != "headless":
		var l := DisplayServer.keyboard_get_label_from_physical(phys)
		if l != KEY_NONE:
			code = l
	if code > 0 and code < 0x400000:
		return labels.find(String.chr(code).to_upper())
	return -1

func _input(event: InputEvent) -> void:
	if not active:
		return
	# no keyboard? any gamepad button signs the book (as "Claude" if nothing was typed)
	if typing_target != null and event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		typing_target.call("type_done")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.echo:
		var k := event as InputEventKey
		for sgn in signs:
			if sgn.phys == k.physical_keycode:
				sgn.down = k.pressed
		if typing_target != null and k.pressed:
			if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
				typing_target.call("type_done")
			elif k.keycode == KEY_DELETE or k.keycode == KEY_LEFT:
				typing_target.call("type_erase")
			elif k.unicode > 31 and k.unicode < 0x2000:
				var ch := String.chr(k.unicode)
				if ch.strip_edges() != "" or ch == " ":
					typing_target.call("type_char", ch)
			get_viewport().set_input_as_handled()

func _update_signs(delta: float) -> void:
	for sgn in signs:
		var target := 1.0 if sgn.down else 0.0
		sgn.press = lerpf(sgn.press, target, 1.0 - exp(-(30.0 if target > sgn.press else 10.0) * delta))
		var p: float = sgn.press
		var mm: MultiMesh = sgn.mm
		mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(1.0 + p * 0.06, 1.0 - p * 0.3, 1.0 + p * 0.06)), Vector3.ZERO))

## start the chapter: at the beginning (the drop into the book) or, for tests,
## at the last pin before `at`
func begin(at: float) -> void:
	if at <= 0.0:
		for sec in sections:
			if sec.has_method("arrive"):
				sec.call("arrive")
		return
	var best := {"p": Vector3(0, 1, 0), "lane": 1}
	var best_x := -INF
	for cp in checkpoints:
		var cx: float = cp.get("cx", (cp.p as Vector3).x)
		if cx <= at:
			cp.on = true
			if cx >= best_x:
				best_x = cx
				best = cp
	for k in _narrated:
		if float(_narrated[k].x) < at:
			_narrated[k].done = true
	for sec in sections:
		if sec.has_method("skip_to"):
			sec.call("skip_to", at)
	place_claude(best.p, best.lane, 1.0, best.has("near"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pd_place="):
			# screenshots: put Claude exactly here (x,y,layer)
			var v := a.substr(11).split(",")
			place_claude(Vector3(float(v[0]), float(v[1]), 0.0), int(v[2]) if v.size() > 2 else 1)

func lane_z(i: int) -> float:
	return LANES[clampi(i, 0, 2)]

func g(local: Vector3) -> Vector3:
	return to_global(local)

## a spool to collect at a local position
func spool(p: Vector3) -> void:
	spool_pos.append(p)

## spools along a parabola from a to b (for jumps), or a straight line
func spool_arc(a: Vector3, b: Vector3, n: int, h := 1.2) -> void:
	for i in n:
		var k := (float(i) + 0.5) / n
		spool(a.lerp(b, k) + Vector3(0, 4.0 * h * k * (1.0 - k), 0))

func checkpoint(p: Vector3, ln := 1, col := Color(0.88, 0.45, 0.38)) -> void:
	var n := Kit.pin(self, Vector3(p.x - 0.7, p.y, lane_z(ln) - 0.75 if ln < 2 else lane_z(ln) - 0.6), col)
	checkpoints.append({"p": Vector3(p.x, p.y + 0.3, lane_z(ln)), "lane": ln, "node": n, "on": false})

## a pin anywhere (off the layers, e.g. on the yarn tower): Claude comes back
## to `p`; it switches on when she gets near it. `cx` orders it along the course.
func checkpoint_free(p: Vector3, pin_p: Vector3, col: Color, cx: float, near := 1.8) -> void:
	var n := Kit.pin(self, pin_p, col)
	checkpoints.append({"p": p + Vector3(0, 0.3, 0), "lane": 1, "node": n, "on": false, "near": near, "cx": cx})

## a narrator line the first time Claude passes x (local)
func narrate_at(x: float, text: String, hold := 3.0, key := "") -> void:
	var k := key if key != "" else "x%.1f" % x
	_narrated[k] = {"x": x, "text": text, "hold": hold, "done": false}

func narrate(text: String, hold := 3.0) -> void:
	narrator.line(text, hold)

func claude_local() -> Vector3:
	return to_local(claude.global_position)

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

## caught by a hazard: a puff of cotton, a "plop", back to the last pin
func hurt(reason := "") -> void:
	if _hurt_t > 0.0:
		return
	if OS.get_cmdline_user_args().has("--pd_bot_debug"):
		print("HURT by %s at %s" % [reason, str(claude_local())])
	_hurt_t = 0.6
	deaths += 1
	var lp := claude_local()
	events.append({"t": "death", "p": Vector2(lp.x, lp.y), "i": path.size()})
	_puff(lp + Vector3(0, 0.6, 0))
	Sound.sfx(A + "pop.ogg", -2.0, 0.9)
	_from_hurt = true
	claude.respawn()

# ------------------------------------------------------------------ build
func _build_env() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type sky;
void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(vec3(1.0, 0.84, 0.64), vec3(0.62, 0.79, 0.96), smoothstep(-0.02, 0.22, y));
	c = mix(c, vec3(0.36, 0.55, 0.88), smoothstep(0.25, 0.75, y));
	c = mix(c, vec3(0.62, 0.76, 0.56), smoothstep(0.0, -0.2, y));
	// a faint woven texture so the sky reads as fabric too
	float wv = sin(EYEDIR.x * 900.0) * sin(EYEDIR.y * 900.0 + EYEDIR.z * 600.0);
	c *= 0.985 + 0.02 * wv;
	COLOR = c;
}"""
	sm.shader = sh
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.1
	env.fog_enabled = false
	# a warm sun from the upper left, cast shadows on the layers behind
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 45.0
	sun.visible = false
	add_child(sun)
	lights.append(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	fill.visible = false
	add_child(fill)
	lights.append(fill)
	cam = Camera3D.new()
	cam.name = "StoryCam"
	cam.fov = cam_fov
	cam.near = 0.1
	cam.far = 500.0
	cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_near_enabled = true
	cam_attr.dof_blur_amount = 0.06
	cam.attributes = cam_attr
	add_child(cam)

## the sky quilt, a felt sun and layers of felt hills far behind the course
func _build_backdrop() -> void:
	var back := Node3D.new()
	back.name = "Backdrop"
	add_child(back)
	var sky := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1600.0, 220.0)
	sky.mesh = qm
	sky.position = Vector3(500.0, 60.0, -90.0)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D weave : filter_linear_mipmap, repeat_enable;
uniform sampler2D mottle : filter_linear_mipmap, repeat_enable;
varying vec3 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	float wy = wp.y + 60.0;
	vec3 low = vec3(1.0, 0.84, 0.66);
	vec3 mid = vec3(0.58, 0.77, 0.96);
	vec3 top = vec3(0.33, 0.53, 0.88);
	vec3 c = mix(low, mid, smoothstep(2.0, 16.0, wy));
	c = mix(c, top, smoothstep(18.0, 60.0, wy));
	float w = texture(weave, wp.xy * 0.4).b;
	float m = texture(mottle, wp.xy * 0.004).r;
	c *= 0.93 + 0.08 * w + (m - 0.5) * 0.06;
	ALBEDO = c;
}"""
	var skm := ShaderMaterial.new()
	skm.shader = sh
	skm.set_shader_parameter("weave", Kit.T_WEAVE)
	skm.set_shader_parameter("mottle", Kit.T_MOTTLE)
	sky.material_override = skm
	back.add_child(sky)
	# a felt sun with blanket stitches and cotton clouds pinned to the sky
	var sun := Node3D.new()
	sun.position = Vector3(60.0, 34.0, -80.0)
	back.add_child(sun)
	var rays := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var r := 9.0 if i % 2 == 0 else 7.0
		rays.append(Vector2(cos(a) * r, sin(a) * r))
	Kit.felt_cutout(sun, rays, 0.6, Transform3D(), Color(1.0, 0.72, 0.32), 0.3)
	Kit.felt_cutout(sun, Kit.circle(5.6, 40), 0.6, Transform3D(Basis(), Vector3(0, 0, 0.4)), Color(1.0, 0.86, 0.45), 0.3)
	# three layers of hills, each a different felt, the far ones bluer
	var layers := [[-9.0, -1.5, 1.2, 1.6, 9.0, Color(0.5, 0.74, 0.42), 0.0],
		[-20.0, 2.0, 2.4, 3.2, 17.0, Color(0.42, 0.66, 0.5), 2.0],
		[-38.0, 7.0, 4.0, 6.0, 29.0, Color(0.55, 0.62, 0.78), 4.0],
		[-58.0, 14.0, 5.0, 9.0, 41.0, Color(0.7, 0.72, 0.88), 6.0]]
	for L in layers:
		var z: float = L[0]
		var poly := Kit.hills(-60.0, 520.0, -30.0, L[1], L[2], L[4], L[6])
		# the band is long: cut it into pieces so culling and triangulation stay simple
		var step := 60.0
		var x := -60.0
		while x < 520.0:
			var piece := Kit.hills(x, x + step + 0.5, -30.0, L[1], L[2], L[4], L[6])
			Kit.felt_cutout(back, piece, 1.0, Transform3D(Basis(), Vector3(0, 0, z)), L[5], 0.4 if z < -15.0 else 0.9)
			# a running stitch just under the top edge, like an appliqué
			var top := PackedVector2Array()
			for k in range(1, piece.size() - 1):
				top.append(piece[k] + Vector2(0, -0.35 - absf(z) * 0.012))
			var far := absf(z) / 20.0
			back.add_child(Kit.stitch_line(top, z + 0.52, 0.3 * far + 0.25, 0.22 * far + 0.18, 0.05 * far + 0.05,
				(L[5] as Color).lightened(0.45)))
			x += step
		if z > -15.0:
			# felt trees and bushes on the nearest hills
			var tx := -40.0
			var k := 0
			while tx < 500.0:
				var hy: float = L[1] + L[2] * (0.6 * sin(tx / L[4] + L[6]) + 0.4 * sin(tx / (L[4] * 0.43) + L[6] * 1.7))
				var tree := Node3D.new()
				tree.position = Vector3(tx, hy - 0.3, z + 0.7)
				back.add_child(tree)
				var th := 2.2 + 1.4 * absf(sin(k * 1.7))
				Kit.felt_cutout(tree, Kit.rect(0.35, th, 0, th * 0.5), 0.3, Transform3D(), Color(0.55, 0.38, 0.26))
				var cols := [Color(0.38, 0.62, 0.36), Color(0.56, 0.75, 0.38), Color(0.3, 0.55, 0.45)]
				Kit.felt_cutout(tree, Kit.blob(th * 0.42, 24, 0.12, k * 1.3), 0.4,
					Transform3D(Basis(), Vector3(0, th, 0.1)), cols[k % 3], 1.0)
				tx += 7.0 + 6.0 * absf(sin(k * 2.3))
				k += 1
	# a felt meadow far below everything, so looking down never shows a void
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(560.0, 160.0)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(200.0, -9.0, -30.0)
	floor_mi.material_override = Kit.fabric(Color(0.5, 0.7, 0.42), Kit.T_FELT, 0.5, 0.6)
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back.add_child(floor_mi)
	# cotton clouds on the sky
	for i in 9:
		var c := Kit.cloud(back, Vector3(-10.0 + i * 55.0, 20.0 + 6.0 * sin(i * 1.3), -66.0), 9.0 + 4.0 * sin(i), false)
		c.scale = Vector3.ONE * 2.2

func _spool_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 16
	var parts := [[0.11, -0.1, 0.1, 1.0], [0.16, -0.135, -0.1, 0.0], [0.16, 0.1, 0.135, 0.0]]
	for p in parts:
		var r: float = p[0]
		var y0: float = p[1]
		var y1: float = p[2]
		var th: float = p[3]
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var c0 := Vector3(cos(a0), 0, sin(a0))
			var c1 := Vector3(cos(a1), 0, sin(a1))
			var q := [[c0 * r + Vector3(0, y0, 0), c0], [c1 * r + Vector3(0, y0, 0), c1],
				[c1 * r + Vector3(0, y1, 0), c1], [c0 * r + Vector3(0, y1, 0), c0]]
			for k in [0, 2, 1, 0, 3, 2]:
				var e: Array = q[k]
				st.set_color(Color(1, 1, 1, th))
				st.set_normal(e[1])
				st.add_vertex(e[0])
			for cap in [[y1, Vector3.UP], [y0, Vector3.DOWN]]:
				var cy: float = cap[0]
				var nn: Vector3 = cap[1]
				var tri := [Vector3(0, cy, 0), c0 * r + Vector3(0, cy, 0), c1 * r + Vector3(0, cy, 0)]
				if nn.y > 0.0:
					tri = [tri[0], tri[2], tri[1]]
				for v in tri:
					st.set_color(Color(1, 1, 1, th))
					st.set_normal(nn)
					st.add_vertex(v)
	return st.commit()

func _finish_spools() -> void:
	spool_mm.instance_count = spool_pos.size()
	var cols := [Kit.CORAL, Kit.MUSTARD, Kit.TEAL, Kit.LILAC, Kit.PINK, Color(0.5, 0.75, 0.45)]
	for i in spool_pos.size():
		spool_mm.set_instance_transform(i, Transform3D(Basis(), spool_pos[i]))
		spool_mm.set_instance_color(i, cols[i % cols.size()])
		spool_mm.set_instance_custom_data(i, Color(randf(), 0, 0, 0))
		spool_got.append(false)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = spool_mm
	var m := ShaderMaterial.new()
	m.shader = SPOOL_SHADER
	mmi.material_override = m
	mmi.name = "Spools"
	add_child(mmi)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 11
	hud.visible = false
	add_child(hud)
	# a warm vignette, like the edges of an old photo
	var vg := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.08, 1.08)
	gt.width = 256
	gt.height = 256
	var gr := Gradient.new()
	gr.set_color(0, Color(0.25, 0.14, 0.12, 0.0))
	gr.set_color(1, Color(0.25, 0.14, 0.12, 0.42))
	gr.add_point(0.55, Color(0.25, 0.14, 0.12, 0.0))
	gt.gradient = gr
	vg.texture = gt
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vg)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.88, 0.74, 0.95)
	sb.border_color = Color(0.32, 0.6, 0.62)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 22; sb.content_margin_right = 26
	sb.content_margin_top = 8; sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(32, 26)
	hud.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)
	var icon := Label.new()
	icon.text = "◉"
	icon.add_theme_font_size_override("font_size", 30)
	icon.add_theme_color_override("font_color", Color(0.88, 0.45, 0.38))
	h.add_child(icon)
	spool_label = Label.new()
	spool_label.text = "0"
	spool_label.add_theme_font_override("font", FONT)
	spool_label.add_theme_font_size_override("font_size", 34)
	spool_label.add_theme_color_override("font_color", Color(0.3, 0.2, 0.32))
	h.add_child(spool_label)
	for i in 3:
		var k := Label.new()
		k.text = "✦"
		k.add_theme_font_size_override("font_size", 26)
		k.add_theme_color_override("font_color", Color(0.3, 0.2, 0.32, 0.22))
		h.add_child(k)
		keep_icons.append(k)

# ------------------------------------------------------------------ start / stop
func start() -> void:
	active = true
	visible = true
	for l in lights:
		(l as Light3D).visible = true
	narrator.visible = true
	hud.visible = true
	set_process(true)
	set_physics_process(true)
	cam.make_current()
	if not get_tree().physics_frame.is_connected(_before_physics):
		get_tree().physics_frame.connect(_before_physics)
	lane = 1
	input_yaw = 0.0
	Sound.music(A + "story.ogg", 1.5)
	claude.walk_speed = walk_speed
	claude.jump_velocity = jump_velocity
	for sec in sections:
		if sec.has_method("on_start"):
			sec.call("on_start")
	_cam_pos = Vector3.INF

func stop() -> void:
	active = false
	Engine.time_scale = 1.0
	claude.walk_speed = 3.4
	claude.jump_velocity = 6.2
	visible = false
	for l in lights:
		(l as Light3D).visible = false
	narrator.visible = false
	narrator.clear()
	hud.visible = false
	set_process(false)
	set_physics_process(false)

## put Claude at a local position (and layer) and make the pin there the checkpoint
func place_claude(p: Vector3, ln := 1, face := 1.0, free_z := false) -> void:
	lane = ln
	var gp := g(Vector3(p.x, p.y, p.z if free_z else lane_z(ln)))
	claude.teleport(Transform3D(Basis(Vector3.UP, -PI * 0.5 * face), gp))
	claude.spawn_xf = Transform3D(Basis(), gp)
	claude.kill_y = ORIGIN.y - 14.0
	_face_dir = face
	_cam_pos = Vector3.INF

# ------------------------------------------------------------------ per frame
func _physics_process(delta: float) -> void:
	if not active or claude == null:
		return
	if claude.in_flight:
		return
	for sec in sections:
		if sec.has_method("physics"):
			sec.call("physics", delta)
	if not free_move:
		if not radial:
			_lanes(delta)
		_facing(delta)
	_bounce_and_wind(delta)
	claude.yaw = input_yaw

func _lanes(delta: float) -> void:
	var lp := claude_local()
	if not lane_lock and claude.control_enabled:
		var want := lane
		if Input.is_action_just_pressed("move_forward"): want = lane + 1
		if Input.is_action_just_pressed("move_back"): want = lane - 1
		want = clampi(want, 0, 2)
		if want != lane:
			if _lane_free(lp, want):
				lane = want
				Sound.sfx(A + "swish.ogg", -14.0, 1.4)
			else:
				Sound.sfx(A + "squish.ogg", -12.0, 1.3)
	var tz: float = lane_z(lane)
	var nz := lerpf(lp.z, tz, 1.0 - exp(-16.0 * delta))
	if absf(nz - tz) < 0.01:
		nz = tz
	claude.global_position.z = to_global(Vector3(lp.x, lp.y, nz)).z
	claude.velocity.z = 0.0

## a springy surface (sponge, trampoline): landing on its top throws Claude up
func add_bounce(top_center: Vector3, size: Vector3, v: float, node: Node3D = null) -> Dictionary:
	var d := {"c": top_center, "s": size, "v": v, "node": node, "sq": 0.0, "cool": 0.0, "on": true}
	bouncers.append(d)
	return d

## a column of rising air (felt fans): in the air inside it, Claude floats up
func add_updraft(center: Vector3, size: Vector3, v: float) -> Dictionary:
	var d := {"c": center, "s": size, "v": v, "on": true}
	updrafts.append(d)
	return d

func _bounce_and_wind(delta: float) -> void:
	var lp := claude_local()
	for b in bouncers:
		if not b.on:
			continue
		b.cool = maxf(b.cool - delta, 0.0)
		var c: Vector3 = b.c
		var sz: Vector3 = b.s
		if absf(lp.x - c.x) < sz.x * 0.5 + 0.15 and absf(lp.z - c.z) < sz.z * 0.5 + 0.2 \
				and lp.y > c.y - 0.3 and lp.y < c.y + 0.35 and claude.velocity.y <= 0.5 and b.cool <= 0.0:
			claude.velocity.y = b.v
			b.cool = 0.3
			b.sq = 1.0
			Sound.sfx(A + "squish.ogg", -2.0, 0.7 + randf() * 0.15)
			Sound.sfx("jump", -6.0, 0.8)
		b.sq = maxf(b.sq - delta * 3.0, 0.0)
		if b.node:
			var nd: Node3D = b.node
			var k: float = b.sq
			nd.scale = Vector3(1.0 + 0.12 * k, 1.0 - 0.35 * k * (1.0 + sin(k * 9.0) * 0.3), 1.0 + 0.12 * k)
	if claude.is_on_floor():
		return
	for u in updrafts:
		if not u.on:
			continue
		var c: Vector3 = u.c
		var sz: Vector3 = u.s
		if absf(lp.x - c.x) < sz.x * 0.5 and absf(lp.z - c.z) < sz.z * 0.5 and absf(lp.y - c.y) < sz.y * 0.5:
			var v: float = u.v
			claude.velocity.y = lerpf(claude.velocity.y, v, 1.0 - exp(-3.5 * delta)) + claude.gravity * delta * 0.85

func _lane_free(lp: Vector3, ln: int) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.26
	cap.height = 0.9
	q.shape = cap
	q.transform = Transform3D(Basis(), g(Vector3(lp.x, lp.y + 0.6, lane_z(ln))))
	q.exclude = [claude.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

## Claude faces where she walks, turned a little towards the camera so her
## drawn-on face stays visible (like a puppet on a stage)
func _facing(delta: float) -> void:
	var tangent := Vector3(cos(input_yaw), 0.0, -sin(input_yaw))
	var vx := claude.velocity.dot(tangent)
	if absf(vx) > 0.4:
		_face_dir = signf(vx)
	var side := input_yaw - PI * 0.5 * _face_dir
	var target := lerp_angle(side, input_yaw + PI, 0.38)
	if absf(vx) < 0.4 and claude.is_on_floor():
		target = lerp_angle(side, input_yaw + PI, 0.6)
	_lane_z = lerp_angle(_lane_z, target, 1.0 - exp(-10.0 * delta))
	claude.rig.rotation.y = _lane_z

func _process(delta: float) -> void:
	if not active or claude == null:
		return
	if not cam.current:
		cam.make_current()
	claude.yaw = input_yaw
	t += delta
	_hurt_t -= delta
	var lp := claude_local()
	for sec in sections:
		sec.call("update", delta)
	_update_signs(delta)
	_collect(lp, delta)
	_checkpoints(lp)
	for k in _narrated:
		var n: Dictionary = _narrated[k]
		if not n.done and lp.x >= n.x:
			n.done = true
			narrator.line(n.text, n.hold)
	if claude.is_on_floor():
		_last_floor = lp
	_rec_t -= delta
	if _rec_t <= 0.0:
		_rec_t = 0.12
		path.append(Vector2(lp.x, lp.y))
	_update_camera(delta)

func _collect(lp: Vector3, delta: float) -> void:
	_chain_t -= delta
	if _chain_t <= 0.0:
		_chain = 0
	var c := lp + Vector3(0, 0.6, 0)
	for i in spool_pos.size():
		if spool_got[i]:
			continue
		var p: Vector3 = spool_pos[i]
		if absf(p.x - c.x) < 0.75 and absf(p.y - c.y) < 0.9 and absf(p.z - c.z) < 0.7:
			spool_got[i] = true
			spools += 1
			events.append({"t": "spool", "p": Vector2(p.x, p.y), "i": path.size()})
			spool_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), p))
			var notes := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
			var st: int = notes[mini(_chain, notes.size() - 1)]
			Sound.sfx(A + "twinkle.ogg", -9.0, pow(2.0, (st - 5) / 12.0))
			_chain += 1
			_chain_t = 0.9
			_counter_pop = 1.0
			_sparkle(p)
			if _chain >= 3:
				_float_text(p + Vector3(0, 0.45, 0.2), "x%d" % _chain, Color(1.0, 0.86, 0.5).lerp(Kit.CORAL, minf((_chain - 3) / 8.0, 1.0)))
	spool_label.text = str(spools)
	_counter_pop = maxf(_counter_pop - delta * 4.0, 0.0)
	spool_label.scale = Vector2.ONE * (1.0 + 0.35 * _counter_pop)

func got_keepsake(i: int) -> void:
	if keepsakes[i]:
		return
	keepsakes[i] = true
	var lp := claude_local()
	events.append({"t": "keep", "p": Vector2(lp.x, lp.y), "i": path.size(), "k": i})
	(keep_icons[i] as Label).add_theme_color_override("font_color", Color(0.93, 0.7, 0.32))
	Sound.sfx(A + "chime.ogg", -3.0)
	shake(0.1)

func _checkpoints(lp: Vector3) -> void:
	for cp in checkpoints:
		if cp.on:
			continue
		var p: Vector3 = cp.p
		var reached := lp.x > p.x - 0.6 and absf(lp.y - p.y) < 3.0
		if cp.has("near"):
			reached = lp.distance_to(p) < float(cp.near)
		if reached:
			cp.on = true
			claude.spawn_xf = Transform3D(Basis(), g(p))
			var n: Node3D = cp.node
			var flag := n.get_node("Flag") as Node3D
			var tw := create_tween()
			flag.rotation.z = -1.2
			tw.tween_property(flag, "rotation:z", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			Sound.sfx(A + "twinkle.ogg", -6.0, 0.75)
			_sparkle(p + Vector3(0, 2.0, -0.7))
	if claude.global_position.y < claude.kill_y + 0.5:
		pass

func _on_respawned() -> void:
	if not _from_hurt:
		# fell off: that counts too (a red cross where she was last standing)
		deaths += 1
		events.append({"t": "death", "p": Vector2(_last_floor.x + 0.6 * _face_dir, _last_floor.y), "i": path.size()})
		Sound.sfx(A + "pop.ogg", -4.0, 0.8)
	_from_hurt = false
	for sec in sections:
		if sec.has_method("on_respawn"):
			sec.call("on_respawn")
	var lp := claude_local()
	var best := 1
	var bd := 99.0
	for i in 3:
		var d := absf(lp.z - lane_z(i))
		if d < bd:
			bd = d
			best = i
	lane = best
	# back out of the pin with a little pop
	claude.rig.scale = Vector3.ONE * 0.15
	var tw := claude.rig.create_tween()
	tw.tween_property(claude.rig, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sparkle(lp + Vector3(0, 0.7, 0))
	Sound.sfx(A + "squish.ogg", -8.0, 1.5)

## a little number that floats up and fades (spool chains)
func _float_text(p: Vector3, text: String, col: Color) -> void:
	var l := Kit.label(self, text, p, 0.0045, col, 64)
	l.outline_size = 14
	l.outline_modulate = Color(0.3, 0.2, 0.32)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", p.y + 0.9, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.55)
	tw.chain().tween_callback(l.queue_free)

## a felt sign on a stick at the start of a part of the course
func section_sign(p: Vector3, text: String, col: Color) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = 0.12
	add_child(n)
	Kit.block(n, Vector3(0, 0.75, 0), Vector3(0.1, 1.5, 0.1), Color(0.62, 0.42, 0.3), Kit.CREAM, 0, false)
	var w := 0.5 + text.length() * 0.2
	Kit.block(n, Vector3(0, 1.7, 0.02), Vector3(w, 0.62, 0.1), col, Kit.CREAM, 0, false)
	var l := Kit.label(n, text, Vector3(0, 1.7, 0.16), 0.0042, Kit.CREAM, 64)
	l.outline_size = 10
	l.outline_modulate = col.darkened(0.45)
	# a tiny felt flag on top
	Kit.felt_cutout(n, PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0.1), Vector2(0, 0.2)]), 0.02,
		Transform3D(Basis(), Vector3(w * 0.5 - 0.05, 2.0, 0.02)), Kit.MUSTARD, 4.0)

# ------------------------------------------------------------------ camera
func _update_camera(delta: float) -> void:
	var lp := claude_local()
	var focus := cam_dist
	var target_pos: Vector3
	var target_look: Vector3
	if cam_mode == "custom" and cam_custom.is_valid():
		var r: Array = cam_custom.call(delta)
		var xf: Transform3D = r[0]
		cam.global_transform = xf
		focus = r[1]
		_cam_pos = to_local(xf.origin)
		_cam_look = to_local(xf.origin - xf.basis.z * focus)
	else:
		if claude.is_on_floor():
			_ground_y = lerpf(_ground_y, lp.y, 1.0 - exp(-4.0 * delta))
		else:
			_ground_y = lerpf(_ground_y, minf(lp.y, _ground_y + 4.0), 1.0 - exp(-1.5 * delta))
			if lp.y < _ground_y - 0.5:
				_ground_y = lerpf(_ground_y, lp.y, 1.0 - exp(-6.0 * delta))
		var ahead := clampf(claude.velocity.x * 0.35, -2.2, 2.2)
		var mid_z: float = LANES[1]
		target_look = Vector3(lp.x + ahead, _ground_y + 0.9, mid_z - 0.4)
		target_pos = Vector3(lp.x + ahead, _ground_y + cam_height, mid_z + cam_dist)
		if cam_mode == "fixed":
			target_pos = to_local(cam_xf.origin)
			target_look = to_local(cam_xf.origin - cam_xf.basis.z * 10.0)
		if _cam_pos == Vector3.INF:
			_cam_pos = target_pos
			_cam_look = target_look
		_cam_pos = _cam_pos.lerp(target_pos, 1.0 - exp(-5.0 * delta))
		_cam_look = _cam_look.lerp(target_look, 1.0 - exp(-6.0 * delta))
		var p := g(_cam_pos)
		if _shake > 0.0:
			_shake = maxf(_shake - delta, 0.0)
			p += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.25
		cam.global_transform = Transform3D(Basis.looking_at(g(_cam_look) - p, Vector3.UP), p)
		focus = cam.global_position.distance_to(claude.global_position + Vector3(0, 0.6, 0))
	cam.fov = lerpf(cam.fov, cam_fov, 1.0 - exp(-3.0 * delta))
	cam_attr.dof_blur_near_distance = focus * 0.45
	cam_attr.dof_blur_near_transition = focus * 0.3
	cam_attr.dof_blur_far_distance = focus * 1.25
	cam_attr.dof_blur_far_transition = focus * 1.4

# ------------------------------------------------------------------ little effects
func _sparkle(p: Vector3) -> void:
	var s := GPUParticles3D.new()
	s.amount = 10
	s.lifetime = 0.6
	s.one_shot = true
	s.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	s.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	q.material = _sparkle_mat()
	s.draw_pass_1 = q
	s.position = p
	add_child(s)
	s.emitting = true
	get_tree().create_timer(1.2).timeout.connect(s.queue_free)

var _spark_mat: StandardMaterial3D
## a soft four-pointed twinkle
func _sparkle_mat() -> StandardMaterial3D:
	if _spark_mat:
		return _spark_mat
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5) / 31.5
			var core := clampf(1.0 - d.length() * 2.2, 0.0, 1.0)
			var rays := clampf(1.0 - absf(d.x) * 9.0, 0.0, 1.0) * clampf(1.0 - absf(d.y), 0.0, 1.0)
			rays = maxf(rays, clampf(1.0 - absf(d.y) * 9.0, 0.0, 1.0) * clampf(1.0 - absf(d.x), 0.0, 1.0))
			var a := clampf(core * core + rays * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.albedo_texture = ImageTexture.create_from_image(img)
	_spark_mat.albedo_color = Color(1.0, 0.85, 0.45)
	_spark_mat.vertex_color_use_as_albedo = true
	return _spark_mat

func _puff(p: Vector3) -> void:
	var s := GPUParticles3D.new()
	s.amount = 14
	s.lifetime = 0.8
	s.one_shot = true
	s.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, 0.5, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	s.process_material = pm
	var sp := SphereMesh.new()
	sp.radius = 0.18; sp.height = 0.36; sp.radial_segments = 10; sp.rings = 6
	sp.material = Kit.fabric(Color(0.98, 0.97, 0.95), Kit.T_FELT, 5.0, 1.4)
	s.draw_pass_1 = sp
	s.position = p
	add_child(s)
	s.emitting = true
	get_tree().create_timer(1.5).timeout.connect(s.queue_free)
