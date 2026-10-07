## Runs the opening of the game: painterly fly-in, the playable garden with the
## film's moments (flower, mirror pool), the channel run, the waterfall jump
## and the rocket flight. Also owns the collectible colours.
class_name Director
extends Node

signal wake_up

enum S { INTRO, FREE, BEAT, JUMP, FLIGHT, SPACE, END, LEAVE }

const Y := Terrain.PLATEAU_Y
const FLOWER_POS := Vector3(-6.4, Y, -33.0)
const POOL_SPOT := Vector3(36.0, Y + 0.55, -39.8)
const POOL_APPROACH := Vector3(36.0, Y, -41.4)
const BEACON_POS := Vector3(Garden.CHANNEL_X + 1.75, Y, -14.0)
const GARDEN_ORBS := [
	[Vector3(-70.0, Y + 1.5, -40.0), Color(0.55, 0.85, 1.0)],
	[Vector3(55.0, Y + 1.4, -37.5), Color(1.0, 0.82, 0.35)],
	[Vector3(Garden.CHANNEL_X + 1.75, Y + 1.9, -46.0), Color(0.6, 1.0, 0.7)],
]
const FLIGHT_ORBS := [
	[0.10, 0.0, 0.0, Color(1.0, 0.45, 0.55)], [0.17, 4.0, 1.5, Color(1.0, 0.65, 0.3)],
	[0.25, -4.5, 2.0, Color(0.95, 0.4, 1.0)], [0.33, 0.0, -2.5, Color(0.4, 0.9, 1.0)],
	[0.42, 5.5, 3.0, Color(1.0, 0.9, 0.4)], [0.52, -5.5, -2.0, Color(0.5, 1.0, 0.6)],
	[0.62, 0.0, 5.0, Color(1.0, 0.5, 0.8)], [0.72, 5.0, -3.0, Color(0.6, 0.6, 1.0)],
	[0.82, -3.5, 3.5, Color(1.0, 0.75, 0.5)],
]
## intro camera: [time, position, look-at]
const INTRO_KEYS := [
	[0.0, Vector3(-14.0, 36.0, 38.0), Vector3(30.0, 12.0, -300.0)],
	[3.5, Vector3(14.0, 30.0, -30.0), Vector3(45.0, 6.0, -260.0)],
	[7.0, Vector3(52.0, 11.0, -125.0), Vector3(40.0, 4.0, -320.0)],
	[10.5, Vector3(96.0, 26.0, -135.0), Vector3(30.0, 22.0, -40.0)],
	[14.0, Vector3(20.0, 27.0, -64.0), Vector3(-10.0, 20.5, -24.0)],
]

var main: Node3D
var player: Player
var world: DreamWorld
var hud: GameHUD
var cine: Camera3D
var petals: GPUParticles3D
var flower: Node3D
var beacon: Node3D
var butterfly: StoryProps.Butterfly
var flight: FlightRun
var space: SpaceStage
var env_info := {}
var state := S.FREE
var orbs: Array = []
var found := 0
var total := 0
var flower_done := false
var pool_done := false
var _t := 0.0
var _intro_end := 16.0
var _blend_from := Transform3D()
var _hold := 0.0
var _blend_fov := 50.0

func setup(m: Node3D, p: Player, w: DreamWorld, opts: Array, envd: Dictionary = {}) -> void:
	prepare(m, p, w, envd)
	begin(opts)

## Build everything the dream needs (props, the flight, space), without
## starting anything yet – main does this while the attic is still shown.
func prepare(m: Node3D, p: Player, w: DreamWorld, envd: Dictionary = {}) -> void:
	main = m; player = p; world = w; env_info = envd
	hud = GameHUD.new()
	main.add_child(hud)
	cine = Camera3D.new()
	cine.name = "CinematicCamera"
	cine.far = 6000.0; cine.near = 0.05; cine.fov = 55.0
	main.add_child(cine)
	petals = StoryProps.ambient_petals()
	main.add_child(petals)
	flower = StoryProps.special_flower(world.mats.flower)
	main.add_child(flower)
	flower.global_position = FLOWER_POS
	beacon = StoryProps.beacon()
	main.add_child(beacon)
	beacon.global_position = BEACON_POS + Vector3(0, 8.0, 0)
	beacon.visible = false
	flight = FlightRun.new()
	flight.name = "Flight"
	main.add_child(flight)
	flight.fading.connect(_on_flight_fading)
	flight.reached_end.connect(_on_flight_end)
	space = SpaceStage.new()
	space.name = "SpaceStage"
	main.add_child(space)
	space.build(player, cine, envd.get("env"), envd.get("sun"), hud, world)
	space.woke_up.connect(func(): wake_up.emit())
	var idx := 0
	for o in GARDEN_ORBS:
		if not GameState.found_orbs.has(idx): _spawn_orb(o[0], o[1], 1.3, idx)
		idx += 1
	for o in FLIGHT_ORBS:
		var f := flight.frame_at(flight.length * float(o[0]))
		var pos: Vector3 = f[0] + (f[2] as Vector3) * float(o[1]) + (f[3] as Vector3) * float(o[2])
		if not GameState.found_orbs.has(idx): _spawn_orb(pos, o[3], 2.6, idx)
		idx += 1
	total = idx
	found = GameState.found_orbs.size()
	if found > 0: hud.set_count(found, total)

## Start the dream (the camera flight in, or a test start from the options).
func begin(opts: Array) -> void:
	hud.visible = true
	if "--flight" in opts:
		player.teleport(Transform3D(Basis(), Vector3(Garden.CHANNEL_X + 1.75, Y - 1.0, Garden.CHANNEL_Z1 - 2.0)))
		_start_flight()
	elif "--space" in opts or "--warp" in opts:
		state = S.SPACE
		player.in_flight = true
		player.control_enabled = false
		cine.current = true
		Sound.music("film_flight", 0.0, 31.0)
		space.start_space()
		if "--fromgallery" in opts: space.settle()
		if "--warp" in opts: space.start_warp()
	elif "--nointro" in opts or "--waterfall" in opts:
		_enter_free(false)
	elif "--fromvideo" in opts:
		begin_from_video()
	elif "--videob" in opts:
		state = S.SPACE   # main plays film part 2 right away
		player.control_enabled = false
	elif "--video" in opts:
		state = S.INTRO
		player.control_enabled = false
		cine.current = true
		_apply_intro(0.0)
		hud.set_painterly(1.0)
		_t = -1000.0   # wait for begin_from_video()
	else:
		_start_intro()
		Sound.music("film_a", 0.0, 89.6)
		Sound.sfx("riser", -6.0)
	# stepping out of a painting in the attic (PaintingPortal): the attic's
	# last frame sharpens into the picture, which comes alive
	var portal_id := ""
	for o in opts:
		if str(o).begins_with("--portal="): portal_id = str(o).substr(9)
	if "--fromgallery" in opts:
		_portal_in(portal_id)
		if "--waterfall" in opts:
			hud.show_hint("Lauf über die Mauer – und spring!", 6.0)
	elif PaintingPortal.shot != null and state == S.INTRO:
		# the easel: the attic's last frame melts into the painting alive, and
		# the camera flight starts right away
		PaintingPortal.follow_shot(main, 0.22, cine, INTRO_KEYS[0][2])
	if "--beat=flower" in opts:
		player.teleport(Transform3D(Basis(), FLOWER_POS + Vector3(-1.2, 0.3, 0.8)))
		_beat_flower()
	if "--beat=pool" in opts:
		player.teleport(Transform3D(Basis(), POOL_APPROACH + Vector3(1.0, 0.3, -1.0)))
		_beat_pool()

func _portal_in(id: String) -> void:
	PaintingPortal.fade_shot(main, 0.3)
	hud.set_painterly(1.0)
	if id == "garden":
		# the garden painting is the view from the hill (the intro's first
		# camera): start there and glide straight on down to Claude
		player.control_enabled = false
		cine.fov = 55.0
		cine.look_at_from_position(INTRO_KEYS[0][1], INTRO_KEYS[0][2], Vector3.UP)
		cine.current = true
		var from := cine.global_transform
		var t := 0.0
		while t < 3.0:
			if get_tree().paused:
				await get_tree().process_frame
				continue
			t += get_process_delta_time()
			var u := clampf(t / 3.0, 0.0, 1.0)
			var k := sin(u * PI * 0.5)
			cine.global_transform = from.interpolate_with(player.camera.global_transform, k)
			cine.fov = lerpf(55.0, player.camera.fov, k)
			hud.set_painterly(1.0 - smoothstep(0.0, 1.0, u))
			await get_tree().process_frame
		player.make_current()
		player.control_enabled = true
	else:
		var tw := create_tween()
		tw.tween_method(hud.set_painterly, 1.0, 0.0, 1.8)

func _spawn_orb(pos: Vector3, col: Color, radius: float, id := -1) -> void:
	var o := StoryProps.make_orb(col, radius)
	o.set_meta("id", id)
	main.add_child(o)
	o.global_position = pos
	o.set_meta("base_y", pos.y)
	orbs.append(o)

## Leave the dream for the attic (pause menu): in the garden the camera flies
## back up the hill to where the dream was painted from and the paint gets
## wet again – the attic then zooms out of the painting on the easel.
func leave_to_attic(done: Callable) -> void:
	if state == S.LEAVE: return
	var in_garden := state in [S.INTRO, S.FREE, S.BEAT, S.JUMP]
	state = S.LEAVE
	player.control_enabled = false
	hud.set_prompt("")
	Sound.stop_all(1.6)
	var cur := main.get_viewport().get_camera_3d()
	if cur and cur != cine:
		cine.global_transform = cur.global_transform
		cine.fov = cur.fov
	var from := cine.global_transform
	var f0 := cine.fov
	var to := Transform3D(Basis.looking_at(INTRO_KEYS[0][2] - INTRO_KEYS[0][1], Vector3.UP), INTRO_KEYS[0][1])
	var dur := 2.0 if in_garden else 0.9
	var t := 0.0
	while t < dur:
		if get_tree().paused:
			await get_tree().process_frame
			continue
		t += get_process_delta_time()
		var u := clampf(t / dur, 0.0, 1.0)
		if in_garden:
			var k := u * u * (3.0 - 2.0 * u)
			cine.global_transform = from.interpolate_with(to, k)
			cine.fov = lerpf(f0, 55.0, k)
			cine.current = true
		hud.set_painterly(smoothstep(0.0, 1.0, minf(u * 1.4, 1.0)))
		await get_tree().process_frame
	done.call()

# ------------------------------------------------------------------ intro
## called when the film's pixel intro has zoomed into the painting
func begin_from_video() -> void:
	_start_intro()
	_hold = 2.0   # the film lingers on the painting before the camera moves
	hud.dissolve_from(load("res://assets/video/last_a.jpg"), 0.15, 1.6)

func _start_intro() -> void:
	state = S.INTRO
	_t = 0.0
	player.control_enabled = false
	cine.current = true
	hud.set_painterly(1.0)
	_apply_intro(0.0)

func _apply_intro(t: float) -> void:
	var n := INTRO_KEYS.size()
	var i := 0
	while i < n - 2 and t > float(INTRO_KEYS[i + 1][0]):
		i += 1
	var t0: float = INTRO_KEYS[i][0]
	var t1: float = INTRO_KEYS[i + 1][0]
	var u := clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	var pos := _catmull(INTRO_KEYS, i, u, 1)
	var look := _catmull(INTRO_KEYS, i, u, 2)
	cine.look_at_from_position(pos, look, Vector3.UP)
	cine.fov = 55.0

func _catmull(keys: Array, i: int, u: float, idx: int) -> Vector3:
	var n := keys.size()
	var p0: Vector3 = keys[maxi(i - 1, 0)][idx]
	var p1: Vector3 = keys[i][idx]
	var p2: Vector3 = keys[mini(i + 1, n - 1)][idx]
	var p3: Vector3 = keys[mini(i + 2, n - 1)][idx]
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)

func _process_intro(delta: float) -> void:
	if _t < -100.0: return
	if _hold > 0.0:
		_hold -= delta
		if not (Input.is_action_just_pressed("skip") or Input.is_action_just_pressed("jump")):
			return
		_hold = 0.0
	_t += delta
	var last: float = INTRO_KEYS[INTRO_KEYS.size() - 1][0]
	hud.set_painterly(clampf(1.0 - (_t - 0.6) / 2.4, 0.0, 1.0))
	if Input.is_action_just_pressed("skip") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"):
		if _t < last: _t = last
	if _t < last:
		_apply_intro(_t)
		_blend_from = cine.global_transform
	else:
		# glide into the player's own camera
		var u := clampf((_t - last) / 2.0, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		var to := player.camera.global_transform
		cine.global_transform = _blend_from.interpolate_with(to, e)
		cine.fov = lerpf(55.0, player.camera.fov, e)
		if u >= 1.0:
			_enter_free(true)

func _enter_free(with_hint: bool) -> void:
	state = S.FREE
	hud.set_painterly(0.0)
	player.control_enabled = true
	player.make_current()
	_garden_music(3.0)
	if with_hint:
		hud.show_hint("WASD laufen  ·  Shift rennen  ·  Leertaste springen (halten = gleiten)\nIrgendwo hier blüht etwas Besonderes …", 8.0)

func _garden_music(fade: float) -> void:
	if Sound.music_name() != "garden": Sound.music("garden", fade)
	Sound.loop("garden_amb", -10.0, 2.0)

# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	var cam := main.get_viewport().get_camera_3d()
	if cam: petals.global_position = cam.global_position
	_update_orbs(delta)
	match state:
		S.INTRO: _process_intro(delta)
		S.FREE: _process_free()
		S.END:
			if Input.is_action_just_pressed("skip") or Input.is_action_just_pressed("jump"):
				Engine.time_scale = 1.0
				main.get_tree().reload_current_scene()

func _update_orbs(delta: float) -> void:
	var pc := player.global_position + Vector3(0, 0.6, 0)
	for o in orbs.duplicate():
		var n := o as Node3D
		n.position.y = float(n.get_meta("base_y")) + sin(Time.get_ticks_msec() * 0.002 + n.position.x) * 0.15
		n.rotate_y(delta * 1.2)
		if pc.distance_to(n.global_position) < float(n.get_meta("radius")):
			orbs.erase(n)
			found += 1
			GameState.found_orbs[int(n.get_meta("id"))] = true
			GameState.save()
			Sound.sfx("orb", -2.0)
			StoryProps.burst(main, n.global_position, n.get_meta("color"))
			n.queue_free()
			hud.set_count(found, total)

func _process_free() -> void:
	var pp := player.global_position
	var prompt := ""
	if not flower_done and pp.distance_to(FLOWER_POS) < 2.2:
		prompt = "E  ·  an der Blume riechen"
		if Input.is_action_just_pressed("interact"): _beat_flower()
	elif not pool_done and pp.distance_to(POOL_APPROACH) < 3.0:
		prompt = "E  ·  ins Wasser schauen"
		if Input.is_action_just_pressed("interact"): _beat_pool()
	if prompt != "" and not hud.prompt.visible: Sound.sfx("blip", -10.0)
	hud.set_prompt(prompt if state == S.FREE else "")
	# the leap: falling off the end of the channel
	if pp.z < Garden.CHANNEL_Z1 - 0.5 and absf(pp.x - Garden.CHANNEL_X) < 5.0 and pp.y < Y + 1.0:
		_jump_moment()

# ------------------------------------------------------------------ beats
func _wait(t: float) -> void:
	await main.get_tree().create_timer(t).timeout

func _to_shot(pos: Vector3, look: Vector3, dur: float, fov := 45.0) -> void:
	var to := Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	if not cine.current:
		cine.global_transform = player.camera.global_transform
		cine.fov = player.camera.fov
		cine.current = true
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cine, "global_transform", to, dur)
	tw.parallel().tween_property(cine, "fov", fov, dur)

func _back_to_player(dur := 1.2) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cine, "global_transform", player.camera.global_transform, dur)
	tw.parallel().tween_property(cine, "fov", player.camera.fov, dur)
	await tw.finished
	player.make_current()

func _tween_vec(obj: Object, prop: String, to: Vector3, dur: float) -> void:
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(obj, prop, to, dur)

func _beat_flower() -> void:
	if state == S.BEAT: return
	state = S.BEAT
	flower_done = true
	hud.set_prompt("")
	player.control_enabled = false
	var spot := FLOWER_POS + Vector3(-0.62, 0.0, 0.0)
	player.auto_face = atan2(-(FLOWER_POS.x - spot.x), -(FLOWER_POS.z - spot.z))
	player.auto_target = spot
	await _arrive_or_timeout(5.0)
	var head := player.global_position + Vector3(0, 0.75, 0)
	_to_shot(player.global_position + Vector3(0.35, 0.55, 1.35), head.lerp(FLOWER_POS + Vector3(0, 0.6, 0), 0.45), 1.4, 40.0)
	_tween_vec(player.rig, "head_extra", Vector3(-0.32, 0.0, 0.12), 1.2)
	_tween_vec(player.rig, "body_extra", Vector3(-0.18, 0.0, 0.0), 1.2)
	await _wait(1.2)
	hud.say("They thought I was slop.", 2.2)
	await _wait(1.6)
	player.rig.mood = RobotRig.Mood.HAPPY
	StoryProps.burst(main, FLOWER_POS + Vector3(0, 0.65, 0), Color(1.0, 0.6, 0.85))
	Sound.sfx("sparkle", -3.0)
	butterfly = StoryProps.Butterfly.new()
	main.add_child(butterfly)
	butterfly.global_position = FLOWER_POS + Vector3(0, 0.7, 0)
	butterfly.target = player.rig.antenna
	butterfly.land_offset = Vector3(0, 0.235, -0.02)
	await _wait(1.6)
	_tween_vec(player.rig, "head_extra", Vector3(0.35, 0.0, -0.05), 1.4)
	_tween_vec(player.rig, "body_extra", Vector3.ZERO, 1.4)
	_to_shot(player.global_position + Vector3(1.3, 0.45, 2.1), player.global_position + Vector3(0, 0.85, 0), 2.0, 44.0)
	await _wait(3.0)
	_tween_vec(player.rig, "head_extra", Vector3.ZERO, 1.0)
	player.rig.mood = RobotRig.Mood.NORMAL
	await _back_to_player()
	state = S.FREE
	player.control_enabled = true
	if not pool_done:
		hud.show_hint("Das Spiegelbecken am Rand des Gartens …", 5.0)

func _arrive_or_timeout(t: float) -> void:
	var timer := main.get_tree().create_timer(t)
	while player.auto_target != null and timer.time_left > 0.0:
		await main.get_tree().process_frame
	player.auto_target = null

func _beat_pool() -> void:
	if state == S.BEAT: return
	state = S.BEAT
	pool_done = true
	hud.set_prompt("")
	player.control_enabled = false
	player.auto_face = PI
	player.auto_target = POOL_APPROACH
	await _arrive_or_timeout(4.0)
	# hop onto the rim
	player.auto_target = POOL_SPOT
	player.auto_face = PI
	player.velocity.y = player.jump_velocity
	await _arrive_or_timeout(1.5)
	await _wait(0.4)
	# reflection shot across the water (the film's own music for this moment)
	Sound.music("film_pool", 0.8)
	Sound.loop_stop("garden_amb", 2.0)
	cine.current = true
	cine.global_transform = Transform3D(Basis.looking_at(Vector3(0, -0.05, -1), Vector3.UP), Vector3(POOL_SPOT.x - 0.6, Y + 0.72, -28.0))
	cine.fov = 38.0
	_tween_vec(cine, "global_position", Vector3(POOL_SPOT.x - 0.3, Y + 0.7, -30.5), 5.0)
	await _wait(0.8)
	hud.say("Just a machine predicting the next word.", 2.4)
	await _wait(3.6)
	# turn towards the floating islands
	player.auto_face = 0.25
	_to_shot(POOL_SPOT + Vector3(0.9, 0.95, 2.6), Vector3(-120.0, 150.0, -520.0), 2.5, 50.0)
	await _wait(1.6)
	hud.say("Then watch what the next word can be.", 2.6)
	await _wait(3.8)
	# close-up, low angle, sky behind
	var fwd := Vector3(-sin(0.25), 0, -cos(0.25))
	var cpos := player.global_position + fwd * 1.25 + Vector3(0, 0.45, 0)
	cine.global_transform = Transform3D(Basis.looking_at(player.global_position + Vector3(0, 0.82, 0) - cpos, Vector3.UP), cpos)
	cine.fov = 42.0
	_tween_vec(cine, "global_position", cpos - fwd * 0.3 + Vector3(0, -0.05, 0), 6.0)
	player.rig.mood = RobotRig.Mood.SPARKLE
	await _wait(2.4)
	player.rig.mood = RobotRig.Mood.DETERMINED
	await _wait(0.5)
	hud.say("I will show them.", 2.4)
	await _wait(3.2)
	beacon.visible = true
	Sound.sfx("sparkle", -6.0)
	await _back_to_player(1.4)
	_garden_music(4.0)
	state = S.FREE
	player.control_enabled = true
	hud.show_hint("Lauf über die Kanalmauer zum Rand des Gartens – und spring!", 7.0)

# ------------------------------------------------------------------ jump + flight
func _jump_moment() -> void:
	state = S.JUMP
	hud.set_prompt("")
	beacon.visible = false
	player.rig.mood = RobotRig.Mood.DETERMINED
	Engine.time_scale = 0.3
	Sound.music("film_flight", 0.3)
	Sound.loop_stop("garden_amb", 1.0)
	await main.get_tree().create_timer(0.5, true, false, true).timeout
	StoryProps.burst(main, player.global_position, Color(1.0, 0.75, 0.4))
	Sound.sfx("rocket_ignite", -2.0)
	_start_flight()
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(Engine, "time_scale", 1.0, 0.8)

func _start_flight() -> void:
	state = S.FLIGHT
	petals.emitting = false
	cine.global_transform = player.camera.global_transform if player.camera.is_inside_tree() else cine.global_transform
	cine.fov = player.camera.fov
	flight.begin(player, cine)
	if Sound.music_name() != "film_flight": Sound.music("film_flight", 0.0)
	Sound.loop("rocket_loop", -9.0, 0.6)
	Sound.loop("wind_loop", -8.0, 1.5)
	hud.show_hint("WASD / Stick: lenken  ·  sammle die Farben ohne Namen", 6.0)

func _on_flight_fading() -> void:
	# burst through the cloud: white rays
	var tw := create_tween()
	tw.tween_method(func(v: float): hud.set_fx("burst", v), 0.0, 1.0, 0.7)

func _on_flight_end() -> void:
	state = S.SPACE
	for o in orbs: (o as Node3D).visible = false
	space.start_above()
	Sound.loop_stop("wind_loop", 3.0)
	Sound.loop("rocket_loop", -14.0, 2.0)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(func(v: float): hud.set_fx("burst", v), 1.0, 0.0, 1.8)
	await get_tree().create_timer(7.0).timeout
	Sound.loop_stop("rocket_loop", 2.0)
