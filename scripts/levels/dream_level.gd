## Base class for every level (painting) in the gallery.
##
## Make your level's root script `extends DreamLevel` and override `build()`.
## Everything else is optional. See levels/_template for a minimal example
## and CLAUDE.md for the rules.
##
##   func build() -> void:
##       var claude := spawn_claude(Vector3(0, 1, 0))
##       ...
##       # when the goal is reached:
##       complete()
class_name DreamLevel
extends Node3D

## the folder name under res://levels/
var level_id := ""
var info: LevelInfo
var hud: GameHUD
var claude: Player
## true while the "stepping out of the painting" intro runs (Claude can't move yet)
var intro_running := false
signal intro_finished
var _done := false
var _leaving := false
## built ahead of time by the attic (SceneSwap), waiting to be switched on
var _parked := false
const MAIN_SCENE := "res://scenes/main.tscn"

func _ready() -> void:
	InputSetup.setup()
	_parked = SceneSwap.parking
	if not _parked: get_viewport().disable_3d = false
	level_id = scene_file_path.get_base_dir().get_file()
	if ResourceLoader.exists("res://levels/%s/level.tres" % level_id):
		info = load("res://levels/%s/level.tres" % level_id) as LevelInfo
	hud = GameHUD.new()
	hud.name = "HUD"
	add_child(hud)
	var w := _LeaveWatcher.new()
	w.level = self
	add_child(w)
	build()
	if Settings.low_quality: set_low_quality(true)
	if not _parked: _enter()

## SceneSwap: the attic has reached the painting – go
func _unparked() -> void:
	_parked = false
	get_viewport().disable_3d = false
	_enter()

## SceneSwap.warm_up: look like the first frame after the switch
func _warming_up(on: bool) -> void:
	hud.set_painterly(1.0 if on else 0.0)

## where the attic's camera dives in: [Transform3D, fov] (for SceneSwap.warm_up)
func painting_view() -> Array:
	if info and info.has_painting_cam():
		var xf := Transform3D(Basis.looking_at(info.painting_cam_look - info.painting_cam_pos, Vector3.UP), info.painting_cam_pos)
		return [xf, info.painting_cam_fov]
	if claude: return [claude.camera.global_transform, claude.camera.fov]
	return [Transform3D(), 60.0]

func _exit_tree() -> void:
	SceneSwap.discard(self)

## Override: create your world, call spawn_claude(), start your music …
func build() -> void:
	pass

## Claude, ready to play, with the camera made current.
func spawn_claude(pos: Vector3, yaw := 0.0) -> Player:
	claude = Player.new()
	claude.name = "Claude"
	claude.water_y = -INF
	claude.kill_y = pos.y - 40.0
	claude.step_kind = "grass"
	add_child(claude)
	claude.teleport(Transform3D(Basis(Vector3.UP, yaw), pos))
	claude.spawn_xf = Transform3D(Basis(), pos)
	claude.make_current()
	return claude

## Falling off / pressing R brings Claude back here.
func set_checkpoint(pos: Vector3) -> void:
	if claude: claude.spawn_xf = Transform3D(Basis(), pos)

## Subtitle at the bottom of the screen (Claude's thoughts – English).
func say(text: String, hold := 2.6) -> void:
	hud.say(text, hold)

## Small instruction text (German, like the rest of the UI).
func hint(text: String, duration := 6.0) -> void:
	hud.show_hint(text, duration)

## Call when the level's goal is reached: marks the painting in the hub
## with a star and goes back after `delay` seconds.
func complete(delay := 4.0) -> void:
	if _done: return
	_done = true
	GameState.completed[level_id] = true
	GameState.save()
	await get_tree().create_timer(delay).timeout
	back_to_hub()

## Leave the dream: the camera flies back to where the painting was painted
## from, the paint gets wet again – and the attic zooms out of the picture.
func back_to_hub() -> void:
	if _leaving: return
	_leaving = true
	_done = true
	if claude: claude.control_enabled = false
	Sound.stop_music(1.8)
	# build the attic now, while the camera is still at rest – switching to it
	# at the end of the move then costs nothing
	GameState.next_mode = "hub"
	GameState.hub_return = level_id
	GameState.save()
	SceneSwap.prepare(load(MAIN_SCENE) as PackedScene, self)
	if info and info.has_painting_cam():
		var cam := _painting_camera()
		var to := cam.global_transform
		var to_fov := cam.fov
		var cur := get_viewport().get_camera_3d()
		if cur and cur != cam:
			cam.global_transform = cur.global_transform
			cam.fov = cur.fov
		cam.current = true
		# accelerate back into the picture; the attic carries the motion on
		await _glide(cam, func() -> Array: return [to, to_fov], 1.8, 0.0, 1.0, false)
	else:
		var tw := create_tween()
		tw.tween_method(hud.set_painterly, 0.0, 1.0, 0.8)
		await tw.finished
	PaintingPortal.capture(get_viewport())
	Sound.stop_all(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if SceneSwap.parked_by == self:
		SceneSwap.swap()
	else:
		GameState.next_mode = "hub"
		GameState.hub_return = level_id
		get_tree().change_scene_to_file(MAIN_SCENE)

## Stepping out of the painting: the attic's last frame melts into the same
## picture alive (the painting's camera, painterly filter on), and without
## stopping the camera glides on to Claude while the paint dries.
func _enter() -> void:
	intro_running = true
	var had_control := claude.control_enabled if claude else false
	if claude: claude.control_enabled = false
	hud.set_painterly(1.0)
	if info and info.has_painting_cam() and claude:
		var cam := _painting_camera()
		cam.current = true
		PaintingPortal.follow_shot(self, 0.22, cam, info.painting_cam_look)
		await _glide(cam, func() -> Array: return [claude.camera.global_transform, claude.camera.fov], 2.4, 1.0, 0.0, true)
		claude.make_current()
		cam.queue_free()
	else:
		PaintingPortal.fade_shot(self, 0.3, PaintingPortal.zoom_rate)
		var tw := create_tween()
		tw.tween_method(hud.set_painterly, 1.0, 0.0, 1.6)
		await tw.finished
	if claude and not _done: claude.control_enabled = had_control
	intro_running = false
	intro_finished.emit()

func _painting_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "PaintingCamera"
	cam.fov = info.painting_cam_fov
	cam.near = 0.05
	cam.far = 8000.0
	add_child(cam)
	cam.look_at_from_position(info.painting_cam_pos, info.painting_cam_look)
	return cam

## move `cam` to target() = [Transform3D, fov] (the target may move);
## ease_out: start fast and settle (entering), else start slow and speed up
func _glide(cam: Camera3D, target: Callable, dur: float, paint_from: float, paint_to: float, ease_out: bool) -> void:
	var from := cam.global_transform
	var f0 := cam.fov
	var t := 0.0
	while t < dur:
		if get_tree().paused:   # the pause menu is open
			await get_tree().process_frame
			continue
		t += get_process_delta_time()
		var u := clampf(t / dur, 0.0, 1.0)
		var k := sin(u * PI * 0.5) if ease_out else u * u
		var to: Array = target.call()
		cam.global_transform = from.interpolate_with(to[0], k)
		cam.fov = lerpf(f0, to[1], k)
		cam.current = true
		hud.set_painterly(lerpf(paint_from, paint_to, smoothstep(0.0, 1.0, u)))
		await get_tree().process_frame

## Fewer effects for slower computers (settings menu: "Grafik: niedrig"):
## switches off the expensive screen effects of the level's environments.
func set_low_quality(on: bool) -> void:
	for n in find_children("*", "WorldEnvironment", true, false):
		var e := (n as WorldEnvironment).environment
		if e == null: continue
		if not e.has_meta("hq"):
			e.set_meta("hq", [e.ssao_enabled, e.ssr_enabled, e.ssil_enabled, e.sdfgi_enabled, e.volumetric_fog_enabled])
		var hq: Array = e.get_meta("hq")
		e.ssao_enabled = hq[0] and not on
		e.ssr_enabled = hq[1] and not on
		e.ssil_enabled = hq[2] and not on
		e.sdfgi_enabled = hq[3] and not on
		e.volumetric_fog_enabled = hq[4] and not on

## hold Backspace to leave the dream early (a child node, so levels can use
## _process freely)
class _LeaveWatcher extends Node:
	var level: DreamLevel
	var hold := 0.0
	func _process(delta: float) -> void:
		if Input.is_action_pressed("leave"):
			hold += delta
			level.hud.set_prompt("Zurück in den Dachboden …" if hold < 1.0 else "")
			if hold >= 1.0 and not level._done:
				level._done = true
				level.back_to_hub()
		elif hold > 0.0:
			hold = 0.0
			level.hud.set_prompt("")
