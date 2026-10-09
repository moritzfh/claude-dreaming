## The Plush Desk – a world sewn from fabric, with a cardboard Claude.
##
## A felt keyboard and a plush mouse on a quilted desk mirror your real
## keyboard and mouse. Walk Claude to the USB port, press E: she jumps, flips
## a USB stick out of her head and plugs herself in head-first. The fairy
## lights wake up and the planet mobile above the desk becomes the world
## select: spin it, zoom in, dive into a planet.
##
## Test options (after --): --pd_auto (plays itself, for recording),
## --pd_capture=wide|tall (fixed cameras for 16:9 / 9:16 clips),
## --pd_type (fake typing on the keyboard), --pd_focus=<m>, --pd_nodof,
## --pd_state=plugged (start plugged in), --pd_quiet (no hints or lines),
## --pd_test=dive|unplug (with --pd_auto: dives in / unplugs by itself).
extends DreamLevel

const Cardboard := preload("res://levels/plush_desk/cardboard_claude.gd")
const Keyboard := preload("res://levels/plush_desk/keyboard.gd")
const Mobile := preload("res://levels/plush_desk/mobile.gd")
const Props := preload("res://levels/plush_desk/props.gd")
const Story := preload("res://levels/plush_desk/story/story.gd")
const Finale := preload("res://levels/plush_desk/story/sec_finale.gd")
const QUILT := preload("res://levels/plush_desk/shaders/quilt.gdshader")
const T_WEAVE := preload("res://levels/plush_desk/textures/weave.png")
const T_MOTTLE := preload("res://levels/plush_desk/textures/mottle.png")
const A := "res://levels/plush_desk/audio/"

enum S { WALK, APPROACH, PLUG, PLUGGED, DIVE, UNPLUG, STORY }

const SPAWN := Vector3(-7.4, 0.05, 4.4)
const MOBILE_POS := Vector3(0.6, 0.0, -4.6)
const PAD_POS := Vector3(9.8, 0.0, 0.8)

var env: Environment
var cam_attr: CameraAttributesPractical
var kb: Keyboard
var mobile: Mobile
var props: Props
var cine: Camera3D
var usb: MeshInstance3D
var face: ShaderMaterial
var state := S.WALK
var _t := 0.0
var _st := 0.0               # time in the current state
var _seq: Dictionary = {}
var _cam_from := Transform3D()
var _focus := 6.0
var _zoom := 0.0
var _zoom_t := 0.0
var _spin_in := 0.0
var _drag := 0.0
var _front := 0
var _dive_i := -1
var _shake := 0.0
var _auto := false
var _capture := ""
var _fake_type := false
var _type_t := 0.0
var _type_key := -1
var _prompt := ""
var _said_keys := false
var _said_mouse := false
var _focus_fixed := false
var _path: Array = []
var _quiet := false
var _test := ""
var story: Story
var we: WorldEnvironment
var desk_lights: Array = []
var keycap_mesh: Mesh
var _story_start := ""

# ------------------------------------------------------------------ build
func build() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--pd_auto": _auto = true
		if a.begins_with("--pd_capture="): _capture = a.substr(13)
		if a == "--pd_type": _fake_type = true
		if a == "--pd_quiet": _quiet = true
		if a.begins_with("--pd_test="): _test = a.substr(10)
		if a == "--pd_story": _story_start = "0"
		if a.begins_with("--pd_story_x="): _story_start = a.substr(13)
	_environment()
	_desk()
	kb = Keyboard.new()
	kb.name = "Keyboard"
	add_child(kb)
	keycap_mesh = _glb_mesh("keycap")
	kb.build(_glb_mesh("kb_base"), keycap_mesh)
	props = Props.new()
	props.name = "Props"
	add_child(props)
	props.build_mouse(_glb_mesh("mouse"), _glb_mesh("pad"), PAD_POS, kb.to_global(Vector3(kb.size.x * 0.35, 0.2, -kb.size.z * 0.5)))
	desk_lights.append(props.build_lamp(Vector3(-13.0, 0.0, -6.5), Vector3(-3.0, 0.0, 1.6)))
	props.build_backdrop(-13.0, 96.0, 30.0)
	props.build_sewing(_glb_mesh("planet"))
	mobile = Mobile.new()
	mobile.name = "Mobile"
	mobile.position = MOBILE_POS
	add_child(mobile)
	mobile.build(_glb_mesh("planet"), _glb_mesh("keycap"))
	_show_results()

	# the recording run starts on the keys and walks across them
	var c := spawn_claude(SPAWN if not _auto else kb.to_global(Vector3(3.2, 0.75, 0.25)), -0.75 if not _auto else PI * 0.5)
	c.step_kind = "grass"
	c.auto_face = -0.75 if not _auto else PI * 0.5
	c.kill_y = -6.0
	face = Cardboard.apply(c.rig)
	usb = Cardboard.usb_stick()
	var head := c.rig.get("head") as Node3D
	head.add_child(usb)
	usb.position = Vector3(0, 0.39, -0.04)
	usb.rotation = Vector3(PI * 0.5, 0, 0)
	usb.visible = false
	c.spring.spring_length = 3.9
	c.pitch = -0.42

	# the world inside the STORY planet, built now so the dive never stalls
	story = Story.new()
	add_child(story)
	story.claude = c
	story.setup(self)
	c.respawned.connect(func() -> void:
		if state == S.STORY: story._on_respawned())
	# the badge from the end of chapter one stays sewn on
	var badge: String = notes().get("badge", "")
	if badge != "":
		Finale.attach_badge(c.rig, badge)
	for a in OS.get_cmdline_user_args():
		if a == "--pd_bot" or a.begins_with("--pd_bot="):
			var bot: Node = (load("res://levels/plush_desk/source/story_bot.gd") as GDScript).new()
			bot.set("lvl", self)
			add_child(bot)

	cine = Camera3D.new()
	cine.name = "Cine"
	cine.fov = 50.0
	cine.near = 0.05
	cine.far = 400.0
	add_child(cine)

	Sound.music(A + "lullaby.ogg", 2.0)
	for a in OS.get_cmdline_user_args():
		if a == "--pd_state=plugged":
			call_deferred("_skip_to_plugged")
	if _story_start != "":
		call_deferred("enter_story", float(_story_start))
	intro_finished.connect(_on_intro)

func _glb_mesh(file: String) -> Mesh:
	var ps: PackedScene = load("res://levels/plush_desk/models/" + file + ".glb")
	var inst := ps.instantiate()
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var m := mi.mesh
	inst.free()
	return m

func _environment() -> void:
	we = WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type sky;
void sky() {
	float up = EYEDIR.y * 0.5 + 0.5;
	vec3 c = mix(vec3(0.03, 0.03, 0.08), vec3(0.08, 0.09, 0.2), up);
	vec3 lamp = normalize(vec3(-0.6, 0.55, -0.35));
	c += vec3(1.0, 0.7, 0.4) * pow(max(dot(EYEDIR, lamp), 0.0), 24.0) * 2.0;
	c += vec3(0.4, 0.5, 1.0) * pow(max(dot(EYEDIR, normalize(vec3(0.3, 0.4, -1.0))), 0.0), 8.0) * 0.3;
	COLOR = c;
}"""
	sm.shader = sh
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.42, 0.58)
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.8
	env.ssao_detail = 0.8
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(1.0, 0.92, 0.85)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 40.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.04
	we.environment = env
	cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_near_enabled = true
	cam_attr.dof_blur_amount = 0.09
	set_focus(6.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pd_focus="):
			set_focus(float(a.substr(11)))
			_focus_fixed = true
		if a == "--pd_nodof":
			cam_attr.dof_blur_far_enabled = false
			cam_attr.dof_blur_near_enabled = false
	we.camera_attributes = cam_attr
	add_child(we)
	# cool moonlight from behind (the lamp's spot light is the one with shadows)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-30, 160, 0)
	moon.light_color = Color(0.55, 0.66, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = false
	moon.light_volumetric_fog_energy = 0.0
	add_child(moon)
	desk_lights.append(moon)
	# soft fill from the front so cardboard Claude never turns into a silhouette
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 15, 0)
	fill.light_color = Color(1.0, 0.86, 0.75)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.0
	fill.light_specular = 0.2
	add_child(fill)
	desk_lights.append(fill)

## tilt-shift look: sharp around the focus distance, soft in front and behind
func set_focus(d: float) -> void:
	_focus = d
	cam_attr.dof_blur_near_distance = d * 0.5
	cam_attr.dof_blur_near_transition = d * 0.35
	cam_attr.dof_blur_far_distance = d * 1.35
	cam_attr.dof_blur_far_transition = d * 1.0

func _desk() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 36)
	pm.subdivide_width = 420
	pm.subdivide_depth = 220
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(0, 0, 4.6)
	var m := ShaderMaterial.new()
	m.shader = QUILT
	m.set_shader_parameter("fibre_tex", T_WEAVE)
	m.set_shader_parameter("mottle_tex", T_MOTTLE)
	m.set_shader_parameter("fibre_scale", 3.0)
	m.set_shader_parameter("fibre_strength", 0.8)
	m.set_shader_parameter("sheen", 0.5)
	m.set_shader_parameter("fold", 0.12)
	mi.material_override = m
	mi.extra_cull_margin = 1.0
	add_child(mi)
	var body := StaticBody3D.new()
	add_child(body)
	var shapes := [[Vector3(44, 1, 32), Vector3(0, -0.5, 2.5)],
		[Vector3(1, 6, 32), Vector3(-17.5, 3, 2.5)], [Vector3(1, 6, 32), Vector3(17.5, 3, 2.5)],
		[Vector3(44, 6, 1), Vector3(0, 3, -12.6)], [Vector3(44, 6, 1), Vector3(0, 3, 13.5)]]
	for s in shapes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[0]
		cs.shape = bs
		cs.position = s[1]
		body.add_child(cs)

# ------------------------------------------------------------------ flow
func _on_intro() -> void:
	if _capture != "" or "--lshot_noui" in OS.get_cmdline_user_args():
		var dev := get_node_or_null("/root/Dev")
		if dev is CanvasLayer:
			(dev as CanvasLayer).visible = false
	if state == S.WALK and _capture == "" and not _quiet:
		hint("Every key you press presses a felt key · find the USB port", 7.0)
		say("Everything here is soft. Except me.", 3.0)
	if _auto and state == S.WALK:
		_start_approach()

func _skip_to_plugged() -> void:
	_start_plug(true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var k := event as InputEventKey
		var hit: bool = kb.set_real(k.physical_keycode, k.location, k.pressed)
		if hit and k.pressed and not _said_keys and state == S.WALK and _st > 2.0:
			_said_keys = true
			say("Wait … that's YOUR keyboard!", 2.4)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		props.mouse_move(mm.relative)
		if state == S.PLUGGED:
			_spin_in += -mm.relative.x * 0.004
			_drag += mm.relative.length()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			props.mouse_button(0, mb.pressed)
			if state == S.PLUGGED:
				if mb.pressed:
					_drag = 0.0
				elif _drag < 12.0:
					_dive()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			props.mouse_button(1, mb.pressed)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var d := 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			props.mouse_wheel(d)
			if state == S.PLUGGED:
				_zoom_t = clampf(_zoom_t + d * 0.18, 0.0, 1.0)

func _set_state(s: int) -> void:
	state = s
	_st = 0.0

func _process(delta: float) -> void:
	_t += delta
	_st += delta
	if claude == null:
		return
	if _fake_type:
		_fake_typing(delta)
	match state:
		S.WALK: _walk(delta)
		S.APPROACH: _approach(delta)
		S.PLUG: _plug(delta)
		S.PLUGGED: _plugged(delta)
		S.DIVE: _diving(delta)
		S.STORY: pass
		S.UNPLUG: _unplug(delta)
	# Claude's feet push down the felt keys
	var feet: Array = []
	var on_keys := false
	if not claude.in_flight and claude.is_on_floor():
		var lp: Vector3 = kb.to_local(claude.global_position)
		on_keys = lp.y > kb.base_top + 0.05 and kb.key_rect.has_point(Vector2(lp.x, lp.z))
		for f in claude.feet_positions():
			feet.append(kb.to_local(f))
	kb.set_feet(feet, on_keys)
	props.set_glow(kb.lit)
	_update_camera(delta)
	if hud and state != S.STORY:
		hud.set_prompt(_prompt if _capture == "" else "")

func _port_world() -> Vector3:
	return kb.to_global(kb.port_pos)

func _launch_spot() -> Vector3:
	var P := _port_world()
	return Vector3(P.x - 1.9, 0.05, P.z + 1.1)

func _walk(_delta: float) -> void:
	var to: Vector3 = _port_world() - claude.global_position
	var near := Vector2(to.x, to.z).length() < 3.2
	_prompt = "E · plug in" if near else ""
	if near and Input.is_action_just_pressed("interact"):
		_start_approach()
	if not _said_mouse and props.mouse_off.length() > 0.6 and _st > 3.0:
		_said_mouse = true
		say("The mouse moves when you move yours!", 2.6)

func _start_approach() -> void:
	_set_state(S.APPROACH)
	claude.control_enabled = false
	_path = [_launch_spot()]
	if _auto:
		_path.push_front(kb.to_global(Vector3(kb.key_rect.position.x + 0.5, 0.6, 0.3)))
	claude.auto_target = _path.pop_front()
	claude.auto_face = _yaw_to_camera(_launch_spot())
	_prompt = ""

## Claude turns to face the camera before the cartwheel (face stays readable)
func _yaw_to_camera(from: Vector3) -> float:
	var cam := _port_world() + Vector3(2.9, 1.5, 4.5)
	var d := cam - from
	return atan2(-d.x, -d.z)

func _approach(_delta: float) -> void:
	if claude.auto_target == null and not _path.is_empty():
		claude.auto_target = _path.pop_front()
	elif claude.auto_target == null and claude.hv_len() < 0.4:
		_start_plug(false)
	elif _st > 9.0:
		claude.auto_target = null
		_start_plug(false)

func _start_plug(skip: bool) -> void:
	_set_state(S.PLUG)
	claude.auto_target = null
	claude.control_enabled = false
	claude.in_flight = true
	claude.velocity = Vector3.ZERO
	var P := _port_world()
	var start := claude.global_position
	if skip:
		start = _launch_spot()
	var yaw := _yaw_to_camera(start)
	var end := P + Vector3(0, 1.11, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.05)
	_seq = {"start": start, "yaw": yaw, "P": P, "apex": start.lerp(end, 0.62) + Vector3(0, 3.0 - (end.y - start.y) * 0.62, 0),
		"end": end, "clicked": false, "thunk": false, "lights": false, "wig": false}
	_cam_from = _current_cam_xf()
	cine.global_transform = _cam_from
	cine.make_current()
	claude.rig.rotation = Vector3.ZERO
	claude.global_transform = Transform3D(Basis(Vector3.UP, yaw), start)
	if skip:
		_st = 7.0
		usb.visible = true
		usb.rotation = Vector3.ZERO
		_seq.clicked = true; _seq.thunk = true; _seq.lights = true; _seq.wig = true; _seq.jumped = true
		kb.light_wave()
		mobile.drive = 0.12
	else:
		Sound.sfx(A + "creak.ogg", -4.0)

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

func _ease_in(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 2.2)

func _plug(delta: float) -> void:
	var t := _st
	var rig: Node3D = claude.rig
	var yaw: float = _seq.yaw
	var start: Vector3 = _seq.start
	var apex: Vector3 = _seq.apex
	var end: Vector3 = _seq.end
	var pos := start
	var b := Basis(Vector3.UP, yaw)
	var sq := Vector3.ONE
	if t < 0.38:
		# crouch, cardboard creaking
		var k := sin(clampf(t / 0.38, 0.0, 1.0) * PI * 0.5)
		sq = Vector3(1.0 + 0.1 * k, 1.0 - 0.2 * k, 1.0 + 0.1 * k)
		rig.set("mood", 2)
	elif t < 1.08:
		if not _seq.has("jumped"):
			_seq.jumped = true
			Sound.sfx(A + "whoosh.ogg", -2.0)
			Sound.sfx("jump", -6.0)
		var k := (t - 0.38) / 0.7
		var e := _ease_out(k)
		pos = start.lerp(apex, e)
		b = Basis(Vector3.UP, yaw + TAU * _ease_out(minf(k * 1.1, 1.0)))
		var s := 1.0 + 0.14 * (1.0 - k)
		sq = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
		if t > 0.72 and not _seq.clicked:
			_seq.clicked = true
			usb.visible = true
			var tw := create_tween()
			tw.tween_property(usb, "rotation:x", -0.25, 0.12).set_trans(Tween.TRANS_BACK)
			tw.tween_property(usb, "rotation:x", 0.0, 0.1)
			Sound.sfx(A + "click.ogg", -1.0)
			rig.set("mood", 1)
	elif t < 1.4:
		# hang at the top and tip over, head first
		var k := (t - 1.08) / 0.32
		pos = apex.lerp(Vector3(end.x, apex.y + 0.15, end.z), _ease_out(k))
		var flip := smoothstep(0.0, 1.0, k) * PI
		b = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, flip)
	elif t < 1.62:
		var k := (t - 1.4) / 0.22
		pos = Vector3(end.x, apex.y + 0.15, end.z).lerp(end, _ease_in(k))
		b = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI)
		sq = Vector3(0.94, 1.08, 0.94)
	else:
		pos = end
		b = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI)
		if not _seq.thunk:
			_seq.thunk = true
			Sound.sfx(A + "thunk.ogg", 0.0)
			Sound.sfx(A + "squish.ogg", -3.0)
			_shake = 0.35
			rig.set("mood", 1)
		var k := t - 1.62
		var bounce := exp(-k * 7.0) * sin(k * 30.0)
		sq = Vector3(1.0 + bounce * 0.12, 1.0 - bounce * 0.16, 1.0 + bounce * 0.12)
		if k > 0.3 and not _seq.wig:
			_seq.wig = true
			Sound.sfx(A + "wiggle.ogg", -3.0)
		if k > 0.75 and not _seq.lights:
			_seq.lights = true
			kb.light_wave()
			Sound.sfx(A + "chime.ogg", -4.0)
			mobile.drive = 0.12
	claude.global_transform = Transform3D(b, pos)
	rig.scale = sq
	claude.rig.animate(delta, Vector3.ZERO, true)
	_legs_pose(t)
	if t > 6.6:
		_set_state(S.PLUGGED)
		_zoom_t = 0.15
		if _capture == "":
			hint("A/D or mouse · spin    W/S or wheel · zoom    E or click · dive in    R · unplug", 9.0)
		say("I'm in! Which world first?", 2.6)

func _legs_pose(t: float) -> void:
	var rig: Node3D = claude.rig
	var ll := rig.get("leg_l") as Node3D
	var lr := rig.get("leg_r") as Node3D
	if ll == null or t < 1.62:
		return
	var k := t - 1.62
	var w := 0.0
	if k > 0.3 and k < 1.2:
		w = sin((k - 0.3) * 26.0) * 0.55 * (1.0 - (k - 0.3) / 0.9)
	elif k > 1.2:
		w = sin(_t * 2.2) * 0.12 + (sin(_t * 9.0) * 0.4 if fmod(_t, 4.0) < 0.5 else 0.0)
	# legs up in a V, kicking
	var splay := 0.75 + 0.12 * sin(_t * 5.0)
	ll.rotation = Vector3(w, 0.0, -splay)
	lr.rotation = Vector3(-w, 0.0, splay)
	var al := rig.get("arm_l") as Node3D
	var ar := rig.get("arm_r") as Node3D
	if al and ar:
		var flap := sin(_t * 7.0) * 0.25 if k < 1.4 else sin(_t * 2.5) * 0.12
		al.rotation = Vector3(0.0, 0.0, -0.9 - flap)
		ar.rotation = Vector3(0.0, 0.0, 0.9 + flap)

func _plugged(delta: float) -> void:
	claude.rig.animate(delta, Vector3.ZERO, true)
	_legs_pose(_st + 7.0)
	var inp := 0.0
	if Input.is_action_pressed("move_left"): inp += 1.0
	if Input.is_action_pressed("move_right"): inp -= 1.0
	if _auto:
		inp = 0.6 if fmod(_st, 9.0) < 4.0 else 0.0
		_zoom_t = 0.15 + 0.5 * smoothstep(4.0, 7.0, fmod(_st, 9.0))
	var target_spin := inp * 1.1 + _spin_in / maxf(delta, 0.001) * 0.6
	_spin_in = 0.0
	mobile.spin = lerpf(mobile.spin, clampf(target_spin, -3.0, 3.0), 1.0 - exp(-4.0 * delta))
	if absf(mobile.spin) > 0.6 and fmod(_t, 0.9) < delta:
		Sound.sfx(A + "swish.ogg", -16.0, 1.0, 0.2)
	if Input.is_action_pressed("move_forward"): _zoom_t = minf(_zoom_t + delta * 0.8, 1.0)
	if Input.is_action_pressed("move_back"): _zoom_t = maxf(_zoom_t - delta * 0.8, 0.0)
	_zoom = lerpf(_zoom, _zoom_t, 1.0 - exp(-4.0 * delta))
	var f: int = mobile.front_index(cine.global_position)
	if f != _front:
		_front = f
		Sound.sfx(A + "twinkle.ogg", -14.0, 1.5)
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"):
		_dive()
	if Input.is_action_just_pressed("respawn"):
		_start_unplug()
	# test runs: --pd_test=dive / --pd_test=unplug
	if _test != "" and _st > 3.0 and state == S.PLUGGED:
		if _test == "dive": _dive()
		else:
			_test = ""
			_start_unplug()
	if state == S.PLUGGED:
		var title: String = mobile.planets[_front].title
		_prompt = "E · dive into " + title.capitalize()

func _dive() -> void:
	if state != S.PLUGGED:
		return
	_dive_i = _front
	_set_state(S.DIVE)
	_cam_from = cine.global_transform
	Sound.sfx(A + "dive.ogg", -1.0)
	_prompt = ""

func _diving(delta: float) -> void:
	claude.rig.animate(delta, Vector3.ZERO, true)
	_legs_pose(_st + 9.0)
	mobile.spin = lerpf(mobile.spin, 0.0, 1.0 - exp(-6.0 * delta))
	var k := _st / 1.6
	hud.set_fx("white", smoothstep(0.55, 1.0, k))
	if _st > 1.7 and not _seq.has("done"):
		_seq.done = true
		var p: Dictionary = mobile.planets[_dive_i]
		print("[plush_desk] dived into ", p.id)
		if p.id == "story":
			enter_story(0.0)
			return
		# the other worlds are still being sewn: back out to the mobile
		say("This world is still being sewn … soon!", 2.6)
		_cam_from = cine.global_transform
		_set_state(S.PLUGGED)
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: hud.set_fx("white", v), 1.0, 0.0, 0.7)

## the planet tags show the best result of each world
func _show_results() -> void:
	var n := notes()
	if n.has("best_score"):
		mobile.set_result("story", int(n.best_score), String(n.get("badge", "")))

## the level's saved notes (best spools, badge, the name in the guestbook …)
func notes() -> Dictionary:
	if not GameState.stats.has(level_id) or not (GameState.stats[level_id] is Dictionary):
		GameState.stats[level_id] = {}
	return GameState.stats[level_id]

## dive through the fabric into the world inside the STORY planet
func enter_story(at := 0.0) -> void:
	_set_state(S.STORY)
	_prompt = ""
	hud.set_prompt("")
	for l in desk_lights:
		(l as Light3D).visible = false
	we.environment = story.env
	usb.visible = false
	usb.rotation = Vector3(PI * 0.5, 0, 0)
	claude.rig.scale = Vector3.ONE
	claude.rig.rotation = Vector3.ZERO
	claude.rig.set("mood", 0)
	claude.in_flight = false
	claude.control_enabled = true
	claude.auto_target = null
	story.start()
	story.begin(at)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: hud.set_fx("white", v), 1.0, 0.0, 0.9)

## the "play it again" pocket: a fresh copy of the world, from the first page
func restart_story() -> void:
	story.stop()
	story.queue_free()
	story = Story.new()
	add_child(story)
	story.claude = claude
	story.setup(self)
	enter_story(0.0)

## leave the story world: "desk" = back to the mobile, "attic" = back to the hub
func exit_story(mode: String) -> void:
	story.stop()
	_show_results()
	Sound.music(A + "lullaby.ogg", 2.0)
	for l in desk_lights:
		(l as Light3D).visible = true
	we.environment = env
	if mode == "attic":
		_set_state(S.PLUGGED)
		back_to_hub()
		return
	_start_plug(true)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: hud.set_fx("white", v), 1.0, 0.0, 0.9)

func _start_unplug() -> void:
	_set_state(S.UNPLUG)
	Sound.sfx(A + "pop.ogg", -1.0)
	_prompt = ""
	kb.lights_off()
	mobile.drive = 0.0

func _unplug(delta: float) -> void:
	var t := _st
	var yaw: float = _seq.yaw
	var land: Vector3 = _launch_spot() + Vector3(-0.4, 0, 0.6)
	var endp: Vector3 = _seq.end
	var q_in := (Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI)).get_rotation_quaternion()
	var q_back := (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)).get_rotation_quaternion()
	var q_up := Basis(Vector3.UP, yaw).get_rotation_quaternion()
	var pos: Vector3
	var q: Quaternion
	if t < 0.8:
		var k := t / 0.8
		pos = endp.lerp(land + Vector3(0, 0.28, 0), k) + Vector3(0, sin(k * PI) * 1.8, 0)
		q = q_in.slerp(q_back, smoothstep(0.0, 1.0, k))
	elif t < 1.5:
		var k := t - 0.8
		pos = land + Vector3(0, 0.28 + absf(sin(k * 9.0)) * 0.12 * exp(-k * 5.0), 0)
		q = q_back
		if not _seq.has("landed"):
			_seq.landed = true
			Sound.sfx(A + "rustle.ogg", -2.0)
			claude.rig.set("mood", 4)
	else:
		var k := clampf((t - 1.5) / 0.45, 0.0, 1.0)
		pos = land + Vector3(0, 0.28 * (1.0 - k), 0)
		q = q_back.slerp(q_up, smoothstep(0.0, 1.0, k))
		if not _seq.has("folded"):
			_seq.folded = true
			var tw := create_tween()
			tw.tween_property(usb, "rotation:x", PI * 0.5, 0.18)
			tw.tween_callback(func(): usb.visible = false)
			Sound.sfx(A + "click.ogg", -6.0, 0.8)
			Sound.sfx(A + "creak.ogg", -8.0, 1.2)
	claude.global_transform = Transform3D(Basis(q), pos)
	claude.rig.scale = Vector3.ONE
	claude.rig.animate(delta, Vector3.ZERO, true)
	if t > 2.0:
		claude.teleport(Transform3D(Basis(Vector3.UP, yaw), land))
		claude.in_flight = false
		claude.control_enabled = true
		claude.auto_face = yaw
		claude.rig.set("mood", 0)
		claude.make_current()
		_set_state(S.WALK)
		print("[plush_desk] unplugged, walking again")
		say("Phew. Again?", 2.0)

# ------------------------------------------------------------------ camera
func _current_cam_xf() -> Transform3D:
	var cam := get_viewport().get_camera_3d()
	return cam.global_transform if cam else Transform3D()

func _look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)

## the plug-in shot: follow the jump from the side, push in on the legs
## sticking out of the port while the lights run, then rise to the mobile
func _plug_shot(t: float, tall: bool) -> Transform3D:
	var P := _port_world()
	var side_off := Vector3(1.5, 1.6, 4.6) if tall else Vector3(2.9, 1.5, 4.5)
	var close_off := Vector3(0.7, 0.95, 2.2) if tall else Vector3(1.5, 0.95, 2.5)
	var c := claude.global_position + Vector3(0, 0.6, 0)
	if t < 1.62:
		var at := (P + Vector3(-0.3, 1.2, 0.2)).lerp(c, 0.45)
		return _look(P + side_off, at)
	var k := smoothstep(1.7, 4.3, t)
	var low := _look(P + side_off.lerp(close_off, k), (P + Vector3(-0.3, 1.2, 0.2)).lerp(P + Vector3(0, 0.85, 0.05), smoothstep(1.62, 2.4, t)))
	if t < 4.3:
		return low
	return low.interpolate_with(_mobile_shot(tall), smoothstep(4.3, 6.6, t))

func _mobile_shot(tall: bool) -> Transform3D:
	if tall:
		return _look(MOBILE_POS + Vector3(-0.3, 3.6, 13.5), MOBILE_POS + Vector3(0, 6.2, 0))
	return _look(MOBILE_POS + Vector3(0.0, 4.0, 13.0), MOBILE_POS + Vector3(0.0, 6.0, 0.0))

func _update_camera(delta: float) -> void:
	if state == S.STORY:
		return
	var target_focus := _focus
	var tall := _capture == "tall"
	if _capture != "":
		cine.fov = 60.0 if tall else 48.0
		if not cine.current and state != S.DIVE:
			cine.make_current()
	if _capture != "" and (state == S.WALK or state == S.APPROACH):
		# tracking shot beside Claude, the keyboard behind her
		var c := claude.global_position
		var off := Vector3(1.2, 2.3, 3.7) if tall else Vector3(2.4, 2.5, 4.6)
		var xf := _look(c + off, c + Vector3(0.2, 0.45, -0.7))
		cine.global_transform = xf if _st < 0.05 and state == S.WALK else cine.global_transform.interpolate_with(xf, 1.0 - exp(-4.0 * delta))
		target_focus = cine.global_position.distance_to(c + Vector3(0, 0.6, 0))
	elif state == S.WALK or state == S.APPROACH:
		target_focus = claude.camera.global_position.distance_to(claude.global_position + Vector3(0, 0.6, 0))
	elif state == S.PLUG:
		var xf := _plug_shot(_st, tall)
		if _capture == "" and _st < 0.9:
			xf = _cam_from.interpolate_with(xf, smoothstep(0.0, 0.9, _st))
		if _capture != "" and _st < 0.6:
			xf = cine.global_transform.interpolate_with(xf, 1.0 - exp(-6.0 * delta))
		cine.global_transform = xf
		target_focus = cine.global_position.distance_to(claude.global_position + Vector3(0, 0.6, 0)) if _st < 4.6 else 13.0
	elif state == S.PLUGGED:
		var fp: Vector3 = mobile.planet_pos(_front)
		var base := _mobile_shot(tall).origin
		var near := fp + (base - fp).normalized() * (5.5 if tall else 4.2)
		var from := base.lerp(near, _zoom * 0.85)
		var at := (MOBILE_POS + Vector3(0, 6.0, 0)).lerp(fp, smoothstep(0.0, 0.6, _zoom))
		cine.global_transform = cine.global_transform.interpolate_with(_look(from, at), 1.0 - exp(-5.0 * delta))
		target_focus = cine.global_position.distance_to(fp)
	elif state == S.DIVE:
		var fp: Vector3 = mobile.planet_pos(_dive_i)
		var r: float = mobile.planets[_dive_i].r
		var k := _ease_in(_st / 1.6)
		var from := _cam_from.origin.lerp(fp + (_cam_from.origin - fp).normalized() * r * 0.9, k)
		cine.global_transform = _look(from, fp)
		target_focus = maxf(cine.global_position.distance_to(fp) - r, 0.5)
	elif state == S.UNPLUG:
		var P := _port_world()
		cine.global_transform = cine.global_transform.interpolate_with(_look(P + Vector3(2.0, 2.5, 6.5), P + Vector3(-1.0, 0.6, 0.6)), 1.0 - exp(-3.0 * delta))
		target_focus = cine.global_position.distance_to(claude.global_position)
	if _shake > 0.0 and cine.current:
		_shake = maxf(_shake - delta, 0.0)
		cine.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.06
	if not _focus_fixed:
		set_focus(lerpf(_focus, target_focus, 1.0 - exp(-6.0 * delta)))

# ------------------------------------------------------------------ test helpers
func _fake_typing(delta: float) -> void:
	_type_t -= delta
	if _type_t > 0.0:
		return
	if _type_key >= 0:
		var k: Dictionary = kb.keys[_type_key]
		kb.set_real(k.phys, k.loc, false)
		_type_key = -1
		_type_t = randf_range(0.03, 0.12)
		return
	var word := "hello claude dreaming "
	var ch := word[int(_t * 7.0) % word.length()]
	var phys: int = KEY_SPACE if ch == " " else OS.find_keycode_from_string(ch.to_upper())
	for i in kb.keys.size():
		if kb.keys[i].phys == phys:
			_type_key = i
			kb.set_real(phys, 0, true)
			break
	_type_t = randf_range(0.06, 0.14)
