## The playable robot: third-person controller with a smoothed orbit camera,
## coyote time / jump buffering, gliding, simple swimming, an optional mid-air
## spin, and gravity that can point anywhere (walk around little planets: add
## GravityField nodes to the level).
##
## Levels can tune it: water_y, kill_y, step_kind, can_spin, spin_sfx …
class_name Player
extends CharacterBody3D

@export var walk_speed := 3.4
@export var run_speed := 7.0
@export var jump_velocity := 6.2
@export var gravity := 18.0
@export var glide_fall_speed := 2.2
@export var mouse_sensitivity := 0.0025

## height of the water surface (swimming below it); -INF = no water
var water_y := Terrain.WATER_Y
## falling below this height respawns (only while world gravity points down)
var kill_y := -20.0
## footstep sounds: "" = the dream garden's grass/stone logic, else "grass", "stone", "wood"
var step_kind := ""
## mid-air spin on the interact button (a little extra height, once per jump)
var can_spin := false
var spin_sfx := ""
## press jump again in the air for a second jump (with a twirl)
var can_double_jump := false
var double_jump_velocity := 0.0      # 0 = 95 % of jump_velocity
var double_jump_sfx := ""
## Mario-style chain: jump again right after landing (while running) for a
## higher second and an even higher third jump with a somersault
var can_triple_jump := false
var triple_jump_sfx := ""

var rig: RobotRig
var cam_yaw_node: Node3D
var cam_pitch_node: Node3D
var spring: SpringArm3D
var camera: Camera3D

var yaw := 0.0
var pitch := -0.22
var control_enabled := true
var in_flight := false
var spawn_xf := Transform3D()

signal arrived
signal respawned
signal spun
## cutscene helper: walk to this point (Vector3) and then face auto_face
var auto_target = null
var auto_face := 0.0
var auto_speed := 2.6

var _coyote := 0.0
var _jump_buf := 0.0
var _gliding := false
var _swimming := false
var _last_cam_input := 0.0
var _facing := 0.0
var _mood_i := 0
var _air_time := 0.0
var _last_step_phase := 0.0
var _was_swimming := false
var _up := Vector3.UP
var _in_field := false
var _frame := Basis()          # y axis = current "up"; carried smoothly between gravity fields
var _spin_t := 0.0
var _spun_in_air := false
var _air_jump_used := false
var _chain := -1                # level of the last ground jump in a chain (0, 1, 2)
var _landed_t := 99.0           # seconds since the last landing
var _was_on_floor := false
var _flip_t := 1.0              # 0..1 while doing the triple-jump somersault
var _jump_held_t := 0.0

const STEP_VARIANTS := {"grass": 4, "stone": 4, "wood": 3}

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 0.98
	cs.shape = cap
	cs.position.y = 0.49
	add_child(cs)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	rig = RobotRig.new()
	rig.name = "Rig"
	add_child(rig)

	cam_yaw_node = Node3D.new(); cam_yaw_node.name = "CamYaw"; cam_yaw_node.top_level = true
	add_child(cam_yaw_node)
	cam_pitch_node = Node3D.new(); cam_pitch_node.name = "CamPitch"
	cam_yaw_node.add_child(cam_pitch_node)
	spring = SpringArm3D.new(); spring.name = "Spring"
	spring.spring_length = 4.3
	spring.margin = 0.3
	var sph := SphereShape3D.new(); sph.radius = 0.25
	spring.shape = sph
	spring.add_excluded_object(get_rid())
	cam_pitch_node.add_child(spring)
	camera = Camera3D.new(); camera.name = "Camera"
	camera.fov = 58.0
	camera.near = 0.08
	camera.far = 6000.0
	spring.add_child(camera)
	cam_yaw_node.global_position = global_position + Vector3(0, 1.1, 0)
	yaw = rotation.y
	_facing = rotation.y
	rotation = Vector3.ZERO
	spawn_xf = global_transform

func make_current() -> void:
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := mouse_sensitivity * Settings.mouse_sens
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * (-1.0 if Settings.invert_y else 1.0), -1.25, 0.6)
		_last_cam_input = 0.0
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## "up" at the current position: away from the closest planet whose gravity
## field we are in, otherwise the world's up
func gravity_up() -> Vector3:
	var best := Vector3.UP
	var bd := INF
	_in_field = false
	for f in get_tree().get_nodes_in_group("gravity_fields"):
		var g := f as GravityField
		if g == null or not g.enabled: continue
		var d := global_position.distance_to(g.global_position)
		if d < g.field_radius:
			var s := d - g.radius
			if s < bd:
				bd = s
				best = (global_position - g.global_position) / maxf(d, 0.001)
				_in_field = true
	return best

func up() -> Vector3:
	return _up

func _update_frame(delta: float, snap := false) -> void:
	var target := gravity_up()
	if snap:
		_up = target
	elif _up.dot(target) < -0.98:
		_up = (_up + _frame.x * 0.2).normalized()
	else:
		_up = _up.slerp(target, 1.0 - exp(-9.0 * delta)).normalized()
	var cur := _frame.y.normalized()
	if cur.dot(_up) < 0.99999:
		var axis := cur.cross(_up)
		if axis.length() > 1e-6:
			_frame = Basis(axis.normalized(), cur.angle_to(_up)) * _frame
	_frame = _frame.orthonormalized()
	up_direction = _up
	global_basis = _frame

func _physics_process(delta: float) -> void:
	if in_flight:
		return
	_update_frame(delta)
	var inp := Vector2.ZERO
	var auto_dir := Vector3.ZERO
	if auto_target != null:
		var to: Vector3 = auto_target - global_position
		to -= _up * to.dot(_up)
		if to.length() < 0.12:
			auto_target = null
			_facing = auto_face
			arrived.emit()
		else:
			auto_dir = to.normalized() * minf(1.0, to.length() * 2.0 + 0.3)
	if control_enabled:
		inp = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var cam_inp := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
		if cam_inp.length() > 0.1:
			yaw -= cam_inp.x * 2.6 * delta * Settings.mouse_sens
			pitch = clampf(pitch - cam_inp.y * 1.8 * delta * Settings.mouse_sens * (-1.0 if Settings.invert_y else 1.0), -1.25, 0.6)
			_last_cam_input = 0.0
	_last_cam_input += delta

	var cam_basis := _frame * Basis(Vector3.UP, yaw)
	var dir := cam_basis * Vector3(inp.x, 0.0, inp.y)
	var speed := run_speed if (control_enabled and Input.is_action_pressed("sprint")) else walk_speed
	if auto_target != null:
		dir = auto_dir
		speed = auto_speed
	_swimming = global_position.y < water_y - 0.45
	if _swimming: speed *= 0.55
	var target := dir * speed
	var on_floor := is_on_floor()
	var accel := 14.0 if on_floor else 5.0
	var v_up := velocity.dot(_up)
	var v_t := velocity - _up * v_up
	v_t = v_t.lerp(target, 1.0 - exp(-accel * delta))

	# landing bookkeeping (double jump refills, jump chain timing)
	if on_floor and not _was_on_floor: _landed_t = 0.0
	_was_on_floor = on_floor
	_landed_t += delta
	if on_floor or _swimming: _air_jump_used = false
	if _landed_t > 0.3 and on_floor: _chain = -1
	# jumping with coyote time + buffer
	_coyote = 0.12 if on_floor or _swimming else _coyote - delta
	var pressed := control_enabled and Input.is_action_just_pressed("jump")
	if pressed and _coyote <= 0.0 and can_double_jump and not _air_jump_used and not _swimming \
			and not (v_up < 0.0 and _ground_near(clampf(-v_up * 0.12, 0.25, 1.4))):
		# second jump in the air (a press just before landing is buffered instead)
		v_up = maxf(v_up, double_jump_velocity if double_jump_velocity > 0.0 else jump_velocity * 0.95)
		_air_jump_used = true
		_chain = -1
		_spin_t = 0.5
		pressed = false
		Sound.sfx("jump", -6.0, 1.25, 0.04)
		if double_jump_sfx != "": Sound.sfx(double_jump_sfx, -5.0, 1.0, 0.04)
	_jump_buf = 0.15 if pressed else _jump_buf - delta
	if _jump_buf > 0.0 and _coyote > 0.0:
		var lvl := 0
		if can_triple_jump and _landed_t < 0.25 and hv_len() > 2.0 and _chain >= 0 and _chain < 2:
			lvl = _chain + 1
		_chain = lvl
		v_up = jump_velocity * [1.0, 1.2, 1.45][lvl] * (0.8 if _swimming else 1.0)
		_jump_buf = 0.0; _coyote = 0.0
		Sound.sfx("jump", -6.0, [1.0, 1.1, 1.22][lvl], 0.04)
		if lvl == 2:
			_flip_t = 0.0
			if triple_jump_sfx != "": Sound.sfx(triple_jump_sfx, -4.0)
	# spin: a little hop in the air, a twirl on the ground
	if on_floor: _spun_in_air = false
	if can_spin and control_enabled and Input.is_action_just_pressed("interact") and _spin_t <= 0.0:
		_spin_t = 0.5
		if not on_floor and not _spun_in_air:
			v_up = maxf(v_up, 3.6)
			_spun_in_air = true
		if spin_sfx != "": Sound.sfx(spin_sfx, -6.0, 1.0, 0.05)
		spun.emit()
	_spin_t -= delta
	# gravity / gliding / swimming
	# gliding needs the button *held* (a quick tap right before landing is a buffered jump)
	_jump_held_t = _jump_held_t + delta if (control_enabled and Input.is_action_pressed("jump")) else 0.0
	_gliding = not on_floor and not _swimming and v_up < 0.0 and _jump_held_t > 0.18
	if _swimming:
		var target_y := water_y - 0.5
		v_up += ((target_y - global_position.y) * 14.0 - v_up * 4.0) * delta
	elif not on_floor:
		v_up -= gravity * delta
		if _gliding: v_up = maxf(v_up, -glide_fall_speed)
	elif _in_field and v_up < 1.0 and _jump_buf <= 0.0 and _coyote > 0.0:
		# on a little planet the ground curves away under our feet (last
		# frame's velocity even points slightly "up" now): keep pressing into
		# it so we stay on the floor instead of skipping off
		v_up = -1.5
	var fall_speed := v_up
	velocity = v_t + _up * v_up
	move_and_slide()
	# --- sounds: landing, footsteps, gliding wind, splashes
	if is_on_floor():
		if _air_time > 0.3 and fall_speed < -4.0:
			Sound.sfx("land", -8.0 + clampf(-fall_speed - 4.0, 0.0, 8.0), 1.0, 0.05)
		_air_time = 0.0
	else:
		_air_time += delta
	if is_on_floor() and hv_len() > 0.6:
		var ph: float = rig._phase
		if floorf(ph / PI) != floorf(_last_step_phase / PI):
			Sound.sfx(_step_sound(), -13.0, 1.0, 0.08)
		_last_step_phase = ph
	if _gliding: Sound.loop("wind_loop", -14.0, 0.3)
	elif not in_flight: Sound.loop_stop("wind_loop", 0.5)
	if _swimming and not _was_swimming: Sound.sfx("splash", -4.0)
	_was_swimming = _swimming

	if (_up.y > 0.9 and global_position.y < kill_y) or (control_enabled and Input.is_action_just_pressed("respawn")):
		respawn()
	if not control_enabled and auto_target == null and hv_len() < 0.3:
		_facing = lerp_angle(_facing, auto_face, 1.0 - exp(-6.0 * delta))
	if control_enabled and Input.is_action_just_pressed("mood"):
		_mood_i = (_mood_i + 1) % 4
		rig.mood = _mood_i
		Sound.sfx("beep", -8.0)

	# face the movement direction (in the local frame)
	var lv := _frame.inverse() * velocity
	if Vector2(lv.x, lv.z).length() > 0.3:
		_facing = lerp_angle(_facing, atan2(-lv.x, -lv.z), 1.0 - exp(-12.0 * delta))
	var spin_a := 0.0
	if _spin_t > 0.0:
		var k := 1.0 - _spin_t / 0.5
		spin_a = TAU * (1.0 - pow(1.0 - k, 2.0))
	rig.rotation.y = _facing + spin_a
	# triple jump: a forward somersault around Claude's middle
	if _flip_t < 1.0:
		_flip_t = minf(_flip_t + delta / 0.7, 1.0)
		if on_floor and _flip_t > 0.3: _flip_t = 1.0
		rig.rotation.x = -TAU * smoothstep(0.0, 1.0, _flip_t)
		var mid := Vector3(0, 0.5, 0)
		rig.position = mid - rig.basis * mid
		if _flip_t >= 1.0:
			rig.rotation.x = 0.0
			rig.position = Vector3.ZERO
	var local_v := rig.global_transform.basis.inverse() * velocity
	rig.animate(delta, local_v, on_floor or _swimming)
	RenderingServer.global_shader_parameter_set("player_pos", global_position)

func _process(delta: float) -> void:
	if in_flight:
		return
	# camera follows smoothly; drifts behind the robot when the player isn't steering it
	var target := global_position + _up * 1.05
	cam_yaw_node.global_position = cam_yaw_node.global_position.lerp(target, 1.0 - exp(-14.0 * delta))
	var lv := _frame.inverse() * velocity
	var hv := Vector2(lv.x, lv.z)
	if _last_cam_input > 1.2 and hv.length() > 1.0:
		yaw = lerp_angle(yaw, _facing, 1.0 - exp(-1.2 * delta))
	cam_yaw_node.global_basis = _frame * Basis(Vector3.UP, yaw)
	cam_pitch_node.rotation = Vector3(pitch, 0, 0)
	camera.fov = lerpf(camera.fov, 58.0 + clampf(hv.length() - 3.5, 0.0, 6.0) * 1.6, 1.0 - exp(-3.0 * delta))

func _step_sound() -> String:
	if step_kind != "":
		return "step_%s_%d" % [step_kind, randi() % int(STEP_VARIANTS.get(step_kind, 3))]
	var p := Vector2(global_position.x, global_position.z)
	var stone := global_position.y > Terrain.PLATEAU_Y + 0.3
	if not stone and absf(global_position.y - Terrain.PLATEAU_Y) < 0.5:
		for r in Garden.paths:
			if Garden._in_rect(p, r, 0.1): stone = true
	return ("step_stone_%d" if stone else "step_grass_%d") % (randi() % 4)

## is there ground within `dist` below Claude's feet?
func _ground_near(dist: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + _up * 0.2, global_position - _up * dist)
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## horizontal speed (in the current gravity frame)
func hv_len() -> float:
	var lv := _frame.inverse() * velocity
	return Vector2(lv.x, lv.z).length()

func feet_positions() -> Array:
	var a := []
	for f in [rig.foot_l, rig.foot_r]:
		if f: a.append((f as Node3D).global_position)
	return a

func respawn() -> void:
	global_transform = Transform3D(Basis(), spawn_xf.origin)
	_frame = Basis()
	_up = Vector3.UP
	_update_frame(0.0, true)
	velocity = Vector3.ZERO
	_reset_moves()
	cam_yaw_node.global_position = global_position + _up * 1.05
	respawned.emit()

func teleport(xf: Transform3D) -> void:
	global_transform = Transform3D(Basis(), xf.origin)
	_frame = Basis()
	_up = Vector3.UP
	_facing = xf.basis.get_euler().y
	yaw = _facing
	velocity = Vector3.ZERO
	_reset_moves()
	_update_frame(0.0, true)   # on a little planet: stand on it right away
	cam_yaw_node.global_position = global_position + _up * 1.05

func _reset_moves() -> void:
	_flip_t = 1.0
	_spin_t = 0.0
	_chain = -1
	_air_jump_used = false
	if rig:
		rig.rotation.x = 0.0
		rig.position = Vector3.ZERO
