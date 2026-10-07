## The rocket flight after the waterfall jump: an on-rails route over the river,
## lake, along the cliff city and up past the floating islands into the clouds.
## The player steers within a tube around the rail and collects colours.
class_name FlightRun
extends Node3D

signal reached_end
signal fading

## the flight is timed to the film's flight cue: we enter the cloud at the
## moment the music bursts (film 175.0s = 22.4s into the cue)
const CUE_START := 0.6
const CLOUD_TIME := 21.8
var _clock := 0.0
var _s0 := 0.0
var _accel := 0.0
const V0 := 18.0
const MAX_OFF := 9.0
## route (world space). Starts at the bottom of the channel waterfall.
const ROUTE := [
	Vector3(66.0, 17.0, -66.0), Vector3(65.0, 7.0, -84.0), Vector3(60.0, 4.2, -110.0),
	Vector3(57.0, 4.2, -140.0), Vector3(46.0, 4.5, -185.0), Vector3(30.0, 5.0, -240.0),
	Vector3(24.0, 6.5, -300.0), Vector3(45.0, 14.0, -360.0), Vector3(82.0, 34.0, -420.0),
	Vector3(118.0, 72.0, -478.0), Vector3(165.0, 122.0, -520.0), Vector3(205.0, 205.0, -545.0),
	Vector3(160.0, 300.0, -650.0), Vector3(90.0, 420.0, -800.0), Vector3(40.0, 520.0, -930.0),
]

var curve := Curve3D.new()
var player: Player
var cam: Camera3D
var s := 0.0
var speed := 16.0
var offs := Vector2.ZERO
var offs_v := Vector2.ZERO
var roll := 0.0
var length := 0.0
var active := false
var _blend := 0.0
var _start_pos := Vector3.ZERO
var _trails: Array = []
var _faded := false
var _fwd := Vector3.FORWARD
var _cam_rel := Vector3.ZERO

func _init() -> void:
	for i in ROUTE.size():
		var p: Vector3 = ROUTE[i]
		var prev: Vector3 = ROUTE[maxi(i - 1, 0)]
		var nxt: Vector3 = ROUTE[mini(i + 1, ROUTE.size() - 1)]
		var h := (nxt - prev) / 6.0
		curve.add_point(p, -h, h)
	curve.bake_interval = 0.5
	length = curve.get_baked_length()

func point_at(d: float) -> Vector3:
	return curve.sample_baked(clampf(d, 0.0, length), true)

func frame_at(d: float) -> Array:
	var p := point_at(d)
	var p2 := point_at(d + 3.0)
	var fwd := (p2 - p).normalized() if p2.distance_to(p) > 0.01 else _fwd
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	return [p, fwd, right, up]

func begin(p: Player, camera: Camera3D) -> void:
	player = p
	cam = camera
	_start_pos = p.global_position
	s = curve.get_closest_offset(_start_pos)
	_s0 = s
	_clock = 0.0
	_accel = 2.0 * (length - _s0 - V0 * CLOUD_TIME) / (CLOUD_TIME * CLOUD_TIME)
	player.in_flight = true
	player.control_enabled = false
	for c in [[Color(1.0, 0.70, 0.15), Color(1.0, 0.25, 0.35)], [Color(1.0, 0.45, 0.15), Color(0.95, 0.30, 0.70)]]:
		var t := StoryProps.RibbonTrail.new()
		t.col_a = c[0]; t.col_b = c[1]
		add_child(t)
		_trails.append(t)
	_cam_rel = cam.global_position - p.global_position
	cam.current = true
	active = true

func _process(delta: float) -> void:
	if not active: return
	# follow the music clock when the film cue is playing
	if Sound.music_name() == "film_flight" and Sound.music_pos() >= 0.0:
		_clock = Sound.music_pos() - CUE_START
	else:
		_clock += delta
	var tc := maxf(_clock, 0.0)
	s = _s0 + V0 * tc + 0.5 * _accel * tc * tc
	speed = V0 + _accel * tc
	var f := frame_at(s)
	var p: Vector3 = f[0]
	var fwd: Vector3 = f[1]
	var right: Vector3 = f[2]
	var up: Vector3 = f[3]
	_fwd = fwd
	var inp := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	offs_v = offs_v.lerp(inp * 13.0, 1.0 - exp(-5.0 * delta))
	offs += offs_v * delta
	if offs.length() > MAX_OFF:
		offs = offs.lerp(offs.normalized() * MAX_OFF, 1.0 - exp(-8.0 * delta))
	var pos := p + right * offs.x + up * offs.y
	# never into the ground / water
	var ground := maxf(Terrain.height(pos.x, pos.z), Terrain.WATER_Y) + 1.6
	if pos.y < ground: pos.y = ground
	# smooth hand-over from the jump
	_blend = minf(_blend + delta / 0.9, 1.0)
	var e := _blend * _blend * (3.0 - 2.0 * _blend)
	pos = _start_pos.lerp(pos, e)
	player.global_position = pos

	# robot pose: superman, banking into the turn
	roll = lerpf(roll, -offs_v.x * 0.07, 1.0 - exp(-6.0 * delta))
	var yaw := atan2(-fwd.x, -fwd.z)
	var pitch := lerpf(0.0, -1.15 + fwd.y * 0.6 - offs_v.y * 0.03, e)
	player.rig.rotation = Vector3(pitch, yaw, roll)
	player.rig.flight = lerpf(player.rig.flight, 1.0, 1.0 - exp(-5.0 * delta))
	player.rig.animate(delta, Vector3.ZERO, true)
	var feet := player.feet_positions()
	for i in mini(feet.size(), _trails.size()):
		(_trails[i] as StoryProps.RibbonTrail).push(feet[i])

	# chase camera
	# camera rides relative to the robot (no lag along the path), only the framing is smoothed
	var rel_target := -fwd * 4.3 + up * 1.35 - right * offs_v.x * 0.06
	_cam_rel = _cam_rel.lerp(rel_target, 1.0 - exp(-3.5 * delta))
	cam.global_position = pos + _cam_rel
	var look := pos + fwd * 7.0 + up * 0.2
	if cam.global_position.distance_to(look) > 0.1:
		cam.look_at(look, Vector3.UP)
	cam.fov = lerpf(cam.fov, 62.0 + minf(speed, 60.0) * 0.3, 1.0 - exp(-2.0 * delta))

	if not _faded and _clock > CLOUD_TIME - 0.7:
		_faded = true
		fading.emit()
	if _clock >= CLOUD_TIME:
		active = false
		for tr in _trails: (tr as Node).queue_free()
		_trails.clear()
		reached_end.emit()
