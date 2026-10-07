extends Node3D

const Y := Terrain.PLATEAU_Y
## camera presets for comparison shots: [cam pos, look at, fov, robot pos (optional), robot yaw]
const CAMS := {
	"t107": [Vector3(5.0, 26.5, -10.0), Vector3(-4.0, 17.0, -90.0), 52.0, Vector3(-9.5, Y, -30.0), 0.0],
	"t92": [Vector3(-14.0, 36.0, 38.0), Vector3(30.0, 12.0, -300.0), 55.0],
	"t92p": [Vector3(-14.0, 36.0, 38.0), Vector3(30.0, 12.0, -300.0), 55.0, Vector3(-10.0, Y, -26.0), 0.0],
	"t111": [Vector3(-8.9, Y + 0.72, -40.0), Vector3(-10.0, Y + 0.6, -42.2), 50.0, Vector3(-10.0, Y, -42.4), 2.7],
	"t152": [Vector3(67.2, Y + 2.0, -27.0), Vector3(72.0, Y - 3.0, -300.0), 60.0, Vector3(67.75, Y + 0.7, -31.0), 0.0],
	"t158": [Vector3(45.0, 9.0, -150.0), Vector3(40.0, 22.0, -560.0), 60.0],
	"t115": [Vector3(18.0, Y + 1.6, 8.0), Vector3(150.0, 30.0, -220.0), 55.0],
	"tree": [Vector3(-30.0, Y + 3.0, -8.0), Vector3(-44.0, Y + 4.0, -24.0), 60.0],
	"feet": [Vector3(-8.6, Y + 0.25, -42.4), Vector3(-10.0, Y + 0.2, -42.4), 40.0, Vector3(-10.0, Y, -42.4), 0.0],
	"feet2": [Vector3(-10.0, Y + 0.3, -41.0), Vector3(-10.0, Y + 0.2, -42.4), 40.0, Vector3(-10.0, Y, -42.4), 0.0],
	"pa": [Vector3(-30.0, 27.0, 10.0), Vector3(25.0, 10.0, -300.0), 55.0],
	"pb": [Vector3(-18.0, 25.0, -8.0), Vector3(40.0, 8.0, -300.0), 55.0],
	"pc": [Vector3(-52.0, 25.5, -6.0), Vector3(10.0, 12.0, -300.0), 55.0],
	"pd": [Vector3(-38.0, 24.0, -16.0), Vector3(30.0, 10.0, -300.0), 60.0],
	"top": [Vector3(0.0, 700.0, -150.0), Vector3(0.0, 0.0, -151.0), 70.0],
}
const SPAWN := Vector3(-10.0, Y + 0.3, -26.0)
const WATERFALL_START := Vector3(Garden.CHANNEL_X + 1.75, Y + 1.0, -20.0)

var env := {}
var world: DreamWorld
var player: Player
var shot_path := ""
var shot_frames := 12
var cam_name := ""
var _frame := 0
var director: Director
var hub: AtticHub
var video: VideoChain
var mode := "full"
var shot_at := -1.0
var _time := 0.0
var _low_quality := false
## built ahead of time by SceneSwap (back from a level / the dream)
var _parked := false
var _start_after_park := Callable()
## the dream world, built on a worker thread while the attic is shown
var _dream_world: DreamWorld
var _dream_task := -1
var _dream_ready := false
var _dream_wanted := false

func _ready() -> void:
	InputSetup.setup()
	_parked = SceneSwap.parking
	# the root viewport survives scene reloads: the hub may have switched 3D off
	if not _parked: get_viewport().disable_3d = false
	Engine.time_scale = Dev.current_speed()
	var opts := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--frames="): shot_frames = int(a.substr(9))
		elif a.begins_with("--cam="): cam_name = a.substr(6)
		elif a.begins_with("--shot_at="): shot_at = float(a.substr(10))
		else: opts.append(a)
	# which part of the game to start with
	if GameState.next_mode != "":
		mode = GameState.next_mode
		GameState.next_mode = ""
	if not GameState.next_opts.is_empty():
		opts.append_array(GameState.next_opts)
		GameState.next_opts = []
	if mode == "hubfilm":   # the attic right after the film's last frame
		mode = "hub"
		opts.append("--fromfilm")
	if "--hub" in opts: mode = "hub"
	elif "--dream" in opts: mode = "dream"
	elif "--fullstart" in opts: mode = "full"
	for f in ["--nointro", "--waterfall", "--flight", "--space", "--warp", "--beat=flower", "--beat=pool", "--fromvideo", "--videob"]:
		if f in opts: mode = "test"
	if cam_name != "": mode = "shot"
	# the attic is 2D: going there (e.g. back from a gallery level) skips
	# building the dream world, so the attic is there right away. The dream
	# world is then built on a worker thread in the background, for the
	# painting on the easel. The intro film (first start) ends in the attic.
	var attic_only := (mode == "hub" and not ("--hubzoom" in opts)) or mode == "full"
	if not attic_only:
		env = DreamEnv.setup(self)
		if "--nofog" in opts: env.env.fog_enabled = false
		if "--noshadow" in opts: env.sun.shadow_enabled = false
		for o in opts:
			if o.begins_with("--tm="): env.env.tonemap_mode = int(o.substr(5))
			if o.begins_with("--sat="): env.env.adjustment_saturation = float(o.substr(6))
	world = DreamWorld.new()
	world.name = "World"
	add_child(world)
	if not attic_only: world.build()
	for o in opts:
		if o.begins_with("--hide="):
			for n in world.find_children(o.substr(7) + "*", "", true, false): n.visible = false

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = SPAWN
	player.rotation.y = 0.0
	player.spawn_xf = player.global_transform

	if cam_name != "" and CAMS.has(cam_name):
		var c: Array = CAMS[cam_name]
		var cam := Camera3D.new()
		cam.name = "ShotCam"
		cam.fov = c[2]; cam.far = 6000.0; cam.near = 0.05
		add_child(cam)
		cam.look_at_from_position(c[0], c[1])
		cam.current = true
		if c.size() > 3:
			player.teleport(Transform3D(Basis(Vector3.UP, c[4]), c[3]))
			player.control_enabled = false
		else:
			player.visible = false
		if "--painterly" in opts:
			var h := GameHUD.new()
			add_child(h)
			h.set_painterly(1.0)
		if "--painterly" in opts or "--petals" in opts:
			var pt := StoryProps.ambient_petals()
			add_child(pt)
			pt.global_position = c[0]
	elif attic_only:
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
		hub = AtticHub.new()
		hub.name = "Hub"
		add_child(hub)
		hub.dream_requested.connect(_on_dream_requested)
		hub.gallery_requested.connect(_on_gallery_requested)
		hub.dream_soon.connect(_prepare_dream)
		hub.dream_gate = dream_is_ready
		hub.start_opts = opts
		var from_film := "--fromfilm" in opts
		var start := func():
			if mode == "full": _play_intro()
			else: _enter_hub(from_film)
		if _parked: _start_after_park = start
		else: start.call()
		_start_dream_prep()
	else:
		if "--waterfall" in opts: player.teleport(Transform3D(Basis(), WATERFALL_START))
		director = Director.new()
		director.name = "Director"
		add_child(director)
		hub = AtticHub.new()
		hub.name = "Hub"
		add_child(hub)
		hub.dream_requested.connect(_on_dream_requested)
		hub.gallery_requested.connect(_on_gallery_requested)
		director.setup(self, player, world, opts.duplicate(), env)
		director.wake_up.connect(_on_wake_up)
		hub.start_opts = opts
		if "--videob" in opts: _on_wake_up()
		if mode == "hub": _enter_hub("--hubzoom" in opts)
	if Settings.low_quality: set_low_quality(true)

## SceneSwap: this scene was built ahead of time and is switched on now
func _unparked() -> void:
	_parked = false
	if _start_after_park.is_valid(): _start_after_park.call()

## SceneSwap is taking this scene apart: hand over the dream world that is
## still being built (or was never used), so that goes bit by bit as well
func _disposing() -> void:
	if _dream_task >= 0 and _dream_world:
		SceneSwap.adopt(_dream_task, _dream_world)
	elif _dream_world and is_instance_valid(_dream_world) and not _dream_world.is_inside_tree():
		SceneSwap.dispose(_dream_world)
	_dream_task = -1
	_dream_world = null

func _exit_tree() -> void:
	SceneSwap.discard(self)
	_disposing()   # any other way out (a plain scene change): the same, in the background

# ------------------------------------------------------------------ the dream, without a hitch
func _start_dream_prep() -> void:
	if _dream_task >= 0 or _dream_world: return
	_dream_world = DreamWorld.new()
	_dream_world.name = "World"
	_dream_task = WorkerThreadPool.add_task(_dream_world.prepare_offline, true, "dream world")

## Claude starts talking about the painting on the easel: put the dream
## together (once the worker thread is done, and only while nothing on screen
## moves – during the dialog or while Claude waits at the easel), so stepping
## into the painting is free.
func _prepare_dream() -> void:
	if _dream_ready or director: return
	_dream_wanted = true
	if _dream_task < 0 and _dream_world == null: _start_dream_prep()
	_try_finish_dream_prep()

func dream_is_ready() -> bool:
	_prepare_dream()
	return _dream_ready

func _try_finish_dream_prep() -> void:
	if not _dream_wanted or _dream_ready: return
	if _dream_task >= 0:
		if not WorkerThreadPool.is_task_completed(_dream_task): return
		WorkerThreadPool.wait_for_task_completion(_dream_task)
		_dream_task = -1
	if hub.state != "talk" and hub.state != "wait": return
	Sound.warm("film_a")
	var empty := world
	world = _dream_world
	add_child(world)
	move_child(world, empty.get_index())
	empty.queue_free()
	env = DreamEnv.setup(self)
	if Settings.low_quality: set_low_quality(true)
	director = Director.new()
	director.name = "Director"
	add_child(director)
	director.process_mode = Node.PROCESS_MODE_DISABLED
	director.prepare(self, player, world, env)
	director.hud.visible = false
	director.wake_up.connect(_on_wake_up)
	var k: Array = Director.INTRO_KEYS[0]
	director.hud.set_painterly(1.0)
	SceneSwap.warm_up(Transform3D(Basis.looking_at(k[2] - k[1], Vector3.UP), k[1]), 55.0, 8, [director.hud])
	_dream_ready = true

func _begin_dream() -> void:
	mode = "dream"
	GameState.dreams += 1
	hub.visible = false
	get_viewport().disable_3d = false
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	director.process_mode = Node.PROCESS_MODE_INHERIT
	director.begin([])

# ------------------------------------------------------------------ game flow
## The first start: the whole film, from the pixel opening through the 3D
## dream to waking up in the attic – then the attic is playable. (The film's
## 3D middle is the original footage; the playable dream comes later, from
## the painting on the easel.)
func _play_intro() -> void:
	get_viewport().disable_3d = true
	video = VideoChain.new()
	add_child(video)
	var files := []
	var durs := []
	for i in 6:
		files.append("res://assets/video/part_a%d.ogv" % (i + 1))
		durs.append(458.0 / 30.0)
	for i in 8:
		files.append("res://assets/video/part_m%d.ogv" % (i + 1))
		durs.append((445.0 if i == 7 else 448.0) / 30.0)
	files.append("res://assets/video/part_b.ogv")
	durs.append(27.0)
	video.play_chain(files, "film_full", 0.0, durs)
	video.finished.connect(_on_intro_done)
	# coming from the title screen: its last frame melts into the film
	PaintingPortal.fade_shot(video, 1.0)

func _on_intro_done(_tex: Texture2D) -> void:
	GameState.intro_seen = true
	GameState.save()
	# watched to the end: the attic zooms out of the film's last frame
	_enter_hub(not video.skipped)
	video.close(0.6)

func _on_wake_up() -> void:
	video = VideoChain.new()
	add_child(video)
	video.play_chain(["res://assets/video/part_b.ogv"], "film_b", 0.0, 27.0)
	video.finished.connect(_on_video_b_done)
	await get_tree().process_frame
	get_viewport().disable_3d = true
	world.visible = false
	player.visible = false
	director.hud.visible = false
	# the film starts white and black: build the attic for its end now
	await get_tree().process_frame
	GameState.next_mode = "hubfilm"
	SceneSwap.prepare(load(scene_file_path) as PackedScene, self)

func _on_video_b_done(_tex: Texture2D) -> void:
	if SceneSwap.parked_by == self:
		PaintingPortal.capture(get_viewport())
		SceneSwap.swap()
		return
	_enter_hub(true)
	video.close(0.6)

func _enter_hub(from_video: bool) -> void:
	get_viewport().disable_3d = true
	if director: director.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hub.start(from_video)
	if from_video and PaintingPortal.shot != null:
		# the film's last frame (another scene played it) melts into the attic
		PaintingPortal.fade_shot(hub, 0.6)

func _on_gallery_requested(gopts: Array) -> void:
	GameState.next_mode = "test"
	GameState.next_opts = gopts
	GameState.dreams += 1
	get_tree().reload_current_scene()

func _on_dream_requested() -> void:
	if _dream_ready:
		_begin_dream()
		return
	GameState.next_mode = "dream"
	GameState.dreams += 1
	get_tree().reload_current_scene()

func _process(d: float) -> void:
	_frame += 1
	if _dream_wanted and not _dream_ready: _try_finish_dream_prep()
	_time += d / maxf(Engine.time_scale, 0.001)
	if Input.is_action_just_pressed("teleport_waterfall"):
		player.teleport(Transform3D(Basis(), WATERFALL_START))
	if Input.is_action_just_pressed("toggle_quality"):
		set_low_quality(not _low_quality)
	if shot_path != "" and ((shot_at < 0.0 and _frame == shot_frames) or (shot_at >= 0.0 and _time >= shot_at)):
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()

## fewer effects for slower computers (the settings menu calls this too)
func set_low_quality(on: bool) -> void:
	_low_quality = on
	if env.is_empty(): return   # the attic alone (the dream isn't built yet)
	var e: Environment = env.env
	e.ssr_enabled = not on
	e.ssao_enabled = not on
	(env.sun as DirectionalLight3D).directional_shadow_max_distance = 90.0 if on else 220.0
	for g in world.find_children("Grass*", "MultiMeshInstance3D", true, false):
		(g as MultiMeshInstance3D).visibility_range_end = 35.0 if on else 70.0
