## After the flight: through the clouds, above the cloud sea, into the
## swirling space with the little planet — and the warp that wakes Claude up.
class_name SpaceStage
extends Node3D

signal woke_up

const ABOVE := Vector3(0.0, 9000.0, 0.0)
const SPACE := Vector3(0.0, 20000.0, 0.0)
const SWIRL_DIR := Vector3(-0.55, 0.28, -0.79)

var director: Node
var player: Player
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var hud: GameHUD
var world: Node3D
var cloud_sea: MeshInstance3D
var planet: MeshInstance3D
var tunnel: MeshInstance3D
var space_sky: ShaderMaterial
var phase := ""
var t := 0.0
var _hold := 0.0
var _drift := Vector3.ZERO
var _pos := Vector3.ZERO
var _cam_dist := 3.4
var _hint_shown := false
var _space_music_swapped := false
var _shake := 0.0
var _key: OmniLight3D
var _burst: MeshInstance3D

func build(p: Player, camera: Camera3D, e: Environment, s: DirectionalLight3D, h: GameHUD, w: Node3D) -> void:
	player = p; cam = camera; env = e; sun = s; hud = h; world = w
	var nt := Tex.noise(91, 0.01, 512, 5)
	# cloud sea
	cloud_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(9000, 9000); pm.subdivide_width = 260; pm.subdivide_depth = 260
	cloud_sea.mesh = pm
	var cm := ShaderMaterial.new(); cm.shader = load("res://shaders/cloud_sea.gdshader"); cm.set_shader_parameter("noise_tex", nt)
	cloud_sea.material_override = cm
	cloud_sea.position = ABOVE + Vector3(0, -120, -1500)
	cloud_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_sea.visible = false
	add_child(cloud_sea)
	# planet
	planet = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 96; sm.rings = 48
	planet.mesh = sm
	var plm := ShaderMaterial.new(); plm.shader = load("res://shaders/planet.gdshader"); plm.set_shader_parameter("noise_tex", Tex.noise(92, 0.02, 512, 5))
	planet.material_override = plm
	planet.scale = Vector3.ONE * 26.0
	planet.position = SPACE + Vector3(42.0, -4.0, -95.0)
	planet.visible = false
	add_child(planet)
	# little floating rocks / moons
	for i in 7:
		var r := MeshInstance3D.new()
		var rs := SphereMesh.new(); rs.radius = randf_range(0.6, 2.2); rs.height = rs.radius * 2.0; rs.radial_segments = 12; rs.rings = 6
		r.mesh = rs
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.85, 0.75, 0.55) if i % 2 == 0 else Color(0.55, 0.85, 0.5); rm.roughness = 0.9
		r.material_override = rm
		r.position = SPACE + Vector3(randf_range(-80, 90), randf_range(-30, 30), randf_range(-160, -50))
		r.visible = false
		r.add_to_group("space_bits")
		add_child(r)
	# warp tunnel
	tunnel = MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 16.0; cy.bottom_radius = 16.0; cy.height = 700.0; cy.cap_top = false; cy.cap_bottom = false; cy.radial_segments = 64
	tunnel.mesh = cy
	var wm := ShaderMaterial.new(); wm.shader = load("res://shaders/warp.gdshader")
	tunnel.material_override = wm
	tunnel.visible = false
	add_child(tunnel)
	# the bright cream heart at the end of the warp
	_burst = MeshInstance3D.new()
	var bq := QuadMesh.new(); bq.size = Vector2(1, 1)
	_burst.mesh = bq
	_burst.material_override = StoryProps.glow_mat(Color(1.0, 0.94, 0.82), 3.0)
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burst.visible = false
	add_child(_burst)
	# sky
	space_sky = ShaderMaterial.new()
	space_sky.shader = load("res://shaders/vangogh_sky.gdshader")
	space_sky.set_shader_parameter("noise_tex", Tex.noise(93, 0.02, 512, 4))

# ------------------------------------------------------------------ above the clouds
func start_above() -> void:
	phase = "above"
	t = 0.0
	world.visible = false
	cloud_sea.visible = true
	env.fog_density = 0.00012
	env.fog_height_density = 0.0
	_pos = ABOVE
	player.global_position = _pos
	cam.global_position = _pos + Vector3(0.0, -2.5, 6.5)
	cam.fov = 70.0

func _process(delta: float) -> void:
	match phase:
		"above": _above(delta)
		"space": _space(delta)
		"warp": _warp(delta)

func _above(delta: float) -> void:
	t += delta
	# rise up out of the clouds, curving towards the sky
	var dir := Vector3(0.0, 0.55, -1.0).normalized().slerp(Vector3.UP, clampf(t / 6.0, 0.0, 1.0) * 0.6)
	_pos += dir * (32.0 + t * 6.0) * delta
	player.global_position = _pos
	player.rig.rotation = Vector3(-1.15 + dir.y * 0.9, 0.0, sin(t * 1.3) * 0.15)
	player.rig.flight = 1.0
	player.rig.animate(delta, Vector3.ZERO, true)
	var tgt := _pos + Vector3(0.0, -2.2, 5.5)
	cam.global_position = cam.global_position.lerp(tgt, 1.0 - exp(-4.0 * delta))
	cam.look_at(_pos + Vector3(0, 1.5, -6.0), Vector3.UP)
	# the sky darkens as we climb
	var k := clampf((t - 2.5) / 3.8, 0.0, 1.0)
	(env.sky.sky_material as ShaderMaterial).set_shader_parameter("brightness", lerpf(1.0, 0.25, k))
	env.ambient_light_energy = lerpf(1.0, 0.5, k)
	if t > 6.2 and t - delta <= 6.2:
		hud.fade_to(Color(0.10, 0.06, 0.25, 1.0), 0.6)
	if t > 6.9:
		start_space()

# ------------------------------------------------------------------ space
func start_space() -> void:
	phase = "space"
	t = 0.0
	cloud_sea.visible = false
	planet.visible = true
	for n in get_tree().get_nodes_in_group("space_bits"): (n as Node3D).visible = true
	env.sky.sky_material = space_sky
	space_sky.set_shader_parameter("swirl_mix", 1.0)
	env.fog_enabled = false
	env.ambient_light_energy = 0.3
	# AgX bleaches the film's deep, saturated violet: space uses a plain curve
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_intensity = 0.3
	# light the planet from the left, the night side on its right, as in the film
	sun.global_transform.basis = Basis.looking_at(Vector3(1.0, -0.15, 0.06), Vector3.UP)
	sun.light_color = Color(1.0, 0.92, 0.85)
	sun.light_energy = 1.15
	_pos = SPACE
	player.global_position = _pos
	player.rig.rotation = Vector3(0.0, PI * 0.15, 0.0)
	player.yaw = -0.2   # the planet sits right of the robot, as in the film
	player.pitch = -0.05
	_drift = Vector3(0.0, 0.0, -0.4)
	hud.fade_to(Color(0.10, 0.06, 0.25, 0.0), 1.4)
	# a warm key light that rides with the camera, so Claude stays warm and
	# readable against the violet night (too short-ranged to touch the planet)
	if _key == null:
		_key = OmniLight3D.new()
		_key.light_color = Color(1.0, 0.86, 0.70)
		_key.light_energy = 1.3
		_key.omni_range = 9.0
		_key.shadow_enabled = false
		cam.add_child(_key)
		_key.position = Vector3(-1.6, 1.2, 0.4)

## skip the arrival (used when stepping in through the attic's painting):
## swirls already calm, camera already in place
func settle() -> void:
	t = 5.0
	space_sky.set_shader_parameter("swirl_mix", 0.0)
	var cb := Basis.from_euler(Vector3(player.pitch, player.yaw, 0.0))
	cam.global_position = _pos + cb * Vector3(1.0, 0.5, _cam_dist)
	cam.look_at(_pos + cb * Vector3(1.0, 0.3, 0.0), Vector3.UP)
	cam.fov = 58.0
	_hint_shown = true
	hud.show_hint("W halten / Leertaste: weiterfliegen", 30.0)

func _space(delta: float) -> void:
	t += delta
	planet.rotate_y(delta * 0.03)
	# the colourful swirls of the arrival calm down to a deep violet night
	space_sky.set_shader_parameter("swirl_mix", lerpf(1.0, 0.0, clampf((t - 1.0) / 4.0, 0.0, 1.0)))
	# zero-g drifting, steered gently
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis_y := Basis(Vector3.UP, player.yaw)
	_drift = _drift.lerp(basis_y * Vector3(inp.x, 0.0, inp.y) * 3.0, 1.0 - exp(-1.2 * delta))
	_pos += _drift * delta
	player.global_position = _pos + Vector3(0.0, sin(t * 0.9) * 0.15, 0.0)
	player.rig.flight = lerpf(player.rig.flight, 0.3, 1.0 - exp(-2.0 * delta))
	player.rig.rotation = player.rig.rotation.lerp(Vector3(sin(t * 0.4) * 0.12, player.yaw + PI * 0.15, sin(t * 0.6) * 0.1), 1.0 - exp(-1.5 * delta))
	player.rig.animate(delta, Vector3.ZERO, true)
	# orbit camera (mouse / right stick drive player.yaw / pitch)
	var cb := Basis.from_euler(Vector3(player.pitch, player.yaw, 0.0))
	var cpos := _pos + cb * Vector3(1.0, 0.5, _cam_dist)
	cam.global_position = cam.global_position.lerp(cpos, 1.0 - exp(-5.0 * delta))
	cam.look_at(_pos + cb * Vector3(1.0, 0.3, 0.0), Vector3.UP)
	cam.fov = lerpf(cam.fov, 58.0, 1.0 - exp(-2.0 * delta))
	if t > 5.0 and not _hint_shown:
		_hint_shown = true
		hud.show_hint("W halten / Leertaste: weiterfliegen", 30.0)
	# when the film cue runs out, keep floating to our own space theme
	if not _space_music_swapped and (Sound.music_name() != "film_flight" or Sound.music_pos() > 41.5):
		_space_music_swapped = true
		Sound.music("space", 3.0)
	# trigger the warp
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("jump"):
		_hold += delta
	else:
		_hold = 0.0
	if t > 2.0 and _hold > 0.8:
		start_warp()

# ------------------------------------------------------------------ warp
func start_warp() -> void:
	phase = "warp"
	t = 0.0
	hud.show_hint("", 0.1)
	Sound.music("film_warp", 0.4)
	Sound.sfx("rocket_ignite", -4.0)
	Sound.loop("rocket_loop", -8.0, 1.0)

func _warp(delta: float) -> void:
	t += delta
	var dir := SWIRL_DIR.normalized()
	space_sky.set_shader_parameter("swirl_mix", lerpf(0.0, 1.0, clampf(t / 2.0, 0.0, 1.0)))
	# turn towards the swirl and accelerate
	var yaw := atan2(-dir.x, -dir.z)
	player.rig.rotation = player.rig.rotation.lerp(Vector3(-1.1, yaw, 0.0), 1.0 - exp(-3.0 * delta))
	player.rig.flight = lerpf(player.rig.flight, 1.0, 1.0 - exp(-3.0 * delta))
	player.rig.animate(delta, Vector3.ZERO, true)
	var spd := 8.0 + maxf(t - 1.5, 0.0) * 40.0
	_pos += dir * spd * delta
	player.global_position = _pos
	var right := dir.cross(Vector3.UP).normalized()
	var up := right.cross(dir)
	_shake = clampf((t - 3.0) / 6.0, 0.0, 1.0) * 0.08 + clampf((t - 10.5) / 4.0, 0.0, 1.0) * 0.12
	var shake := (right * randf_range(-1, 1) + up * randf_range(-1, 1)) * _shake
	cam.global_position = _pos - dir * 3.6 + up * 0.9 + shake
	cam.look_at(_pos + dir * 8.0 + up * 0.4, up)
	cam.fov = lerpf(cam.fov, 58.0 + clampf((t - 1.5) / 3.0, 0.0, 1.0) * 26.0, 1.0 - exp(-2.0 * delta))
	# tunnel of streaks around us
	if t > 1.3:
		tunnel.visible = true
		tunnel.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI * 0.5), _pos + dir * 200.0)
		(tunnel.material_override as ShaderMaterial).set_shader_parameter("intensity", clampf((t - 1.3) / 1.5, 0.0, 1.0))
		_burst.visible = true
		_burst.global_position = _pos + dir * 90.0
		_burst.scale = Vector3.ONE * lerpf(20.0, 75.0, clampf((t - 1.3) / 12.0, 0.0, 1.0))
		# the film paints the warp with thick brush strokes
		hud.set_painterly(clampf((t - 1.3) / 1.5, 0.0, 1.0) * 0.85)
	# reality cracks, coral shatter, white
	hud.set_fx("crack", clampf((t - 10.5) / 4.5, 0.0, 1.0))
	hud.set_fx("coral", clampf((t - 15.4) / 0.4, 0.0, 1.0) * 0.85)
	hud.set_fx("white", clampf((t - 16.0) / 0.4, 0.0, 1.0))
	if t > 16.6 and phase == "warp":
		phase = "done"
		hud.set_painterly(0.0)
		_burst.visible = false
		tunnel.visible = false
		Sound.loop_stop("rocket_loop", 0.3)
		woke_up.emit()
