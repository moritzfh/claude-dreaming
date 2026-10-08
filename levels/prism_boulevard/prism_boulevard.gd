## Prism Boulevard – a kart race on a road of rainbow glass, high above a sea
## of clouds. Claude races seven other dreaming Claudes over three laps.
##
## The karts don't use the physics engine: they live in "track space"
## (metres along the track, metres to the side, height above the road), see
## track.gd and kart.gd. That's what makes the loop, the corkscrew and the
## upside-down parts simple. Want to build a racer of your own? Start from
## course.gd (the layout as a list of turtle commands) and track.gd.
extends DreamLevel

const DIR := "res://levels/prism_boulevard/"
const TRACK := preload("res://levels/prism_boulevard/track.gd")
const COURSE := preload("res://levels/prism_boulevard/course.gd")
const SCN := preload("res://levels/prism_boulevard/scenery.gd")
const PIECES := preload("res://levels/prism_boulevard/pieces.gd")
const LIFE := preload("res://levels/prism_boulevard/sky_life.gd")
const KART := preload("res://levels/prism_boulevard/kart.gd")
const HUD := preload("res://levels/prism_boulevard/race_hud.gd")
const FONT := preload("res://levels/prism_boulevard/fonts/Fredoka-Bold.woff2")

const LAPS := 3
const SEA_Y := -120.0
const PLAYER_SLOT := 5
const RIVALS := [
	["Nova", Color(0.35, 0.95, 0.65), Color(1, 1, 1)],
	["Pixel", Color(0.35, 0.65, 1.0), Color(1.0, 0.95, 0.5)],
	["Mochi", Color(1.0, 0.5, 0.75), Color(1, 1, 1)],
	["Comet", Color(0.62, 0.42, 1.0), Color(0.6, 1.0, 1.0)],
	["Sunny", Color(1.0, 0.82, 0.22), Color(1.0, 0.45, 0.3)],
	["Echo", Color(0.2, 0.8, 0.85), Color(1.0, 0.7, 0.9)],
	["Ember", Color(1.0, 0.32, 0.3), Color(1.0, 0.9, 0.6)],
]
const SKILLS := [0.995, 0.985, 0.975, 0.965, 0.955, 0.945, 0.93]

var track
var env: Environment
var sun: DirectionalLight3D
var karts: Array = []
var me                          # the player's kart
var ui: Control
var pieces                      # the set pieces (pads, bits, gate …)
var cam: Camera3D
var state := "intro"            # intro, title, countdown, race, finished
var race_time := 0.0
var finish_order: Array = []
var _count_t := 0.0
var _count_step := 4
var _rocket_press := -1.0
var _cam_up := Vector3.UP
var _cam_pos := Vector3.ZERO
var _cam_fwd := Vector3.FORWARD
var _shake := 0.0
var _boost_fov := 0.0
var _engine: AudioStreamPlayer
var _drift_snd: AudioStreamPlayer
var _final_lap := false
var _results_shown := false
var _finish_t := 0.0
var _t := 0.0
var _audio_ok := {}
var _lines := 0.0
var _res_shift := 0.0

# =================================================================== build
func build() -> void:
	track = TRACK.new()
	track.build(COURSE.commands())
	var e := SCN.environment(self)
	env = e[0]
	sun = e[1]
	SCN.road(self, track)
	SCN.cloud_sea(self, SEA_Y)
	SCN.cloud_towers(self, track, SEA_Y, 35 if Settings.low_quality else 70, 7, 18 if Settings.low_quality else 24)
	SCN.sea_billows(self, Vector3(300, 0, 150), SEA_Y, 60 if Settings.low_quality else 140)
	SCN.wisps(self, track, 70 if Settings.low_quality else 160)
	SCN.backdrop(self, track)
	add_child(LIFE.new())
	pieces = PIECES.new()
	pieces.build(self, track)
	_build_karts()
	_build_ui()
	_build_audio()
	cam = claude.camera
	cam.top_level = true
	cam.fov = 70.0
	cam.far = 9000.0
	_snap_camera()
	intro_finished.connect(_on_intro, CONNECT_ONE_SHOT)
	# dev: -- --pb_lap=2 starts on the last lap, --pb_s=1700 somewhere else
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pb_s="):
			for k in karts: k.s = track.wrap_s(float(a.substr(7)) - 6.0 * karts.find(k)); k.safe_s = k.s; k._prev_s = k.s
		if a.begins_with("--pb_auto"):
			_autopilot = true
			_weak = a == "--pb_auto=weak"
		if a.begins_with("--pb_lap="):
			for k in karts:
				k.lap = int(a.substr(9)) - 1
				k.halfway = true
				k.progress = k.lap * track.length + k.s
		if a.begins_with("--pb_log"):
			_log = true
		if a.begins_with("--pb_quick"):
			_quick = true
	if _quick:
		info = null          # no glide out of the painting
		_go.call_deferred()

var _autopilot := false
var _log := false
var _quick := false
var _weak := false
var _weak_t := 0.0
var _log_t := 0.0

func _build_karts() -> void:
	var order: Array = []
	for i in RIVALS.size(): order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var skills: Array = SKILLS.duplicate()
	for slot in RIVALS.size() + 1:
		var k := KART.new()
		k.name = "Kart%d" % slot
		add_child(k)
		if slot == PLAYER_SLOT:
			k.setup(track, self, true, "Claude", Color(0.86, 0.45, 0.30), Color(1.0, 0.93, 0.8))
			me = k
		else:
			var ri: int = order.pop_front()
			var r: Array = RIVALS[ri]
			k.setup(track, self, false, r[0], r[1], r[2])
			k.skill = skills.pop_at(rng.randi() % skills.size())
			k.lane = rng.randf_range(-2.5, 2.5)
			k.face_mood = [RobotRig.Mood.NORMAL, RobotRig.Mood.HAPPY, RobotRig.Mood.DETERMINED][rng.randi() % 3]
		karts.append(k)
	_place_grid()
	# Claude herself sits in the player's kart
	var c := spawn_claude(me.global_position + Vector3(0, 0.4, 0), 0.0)
	c.in_flight = true
	c.control_enabled = false
	c.set_process(false)
	c.set_physics_process(false)
	c.set_process_unhandled_input(false)
	c.collision_layer = 0
	c.collision_mask = 0
	me.seat_claude(c, c.rig)
	me._place_visual(0.016)

func _place_grid() -> void:
	var L: float = track.length
	for i in karts.size():
		var k = karts[i]
		k.s = L - 9.0 - i * 4.2
		k.x = -3.4 if i % 2 == 0 else 3.4
		k.h = 0.0; k.v = 0.0; k.psi = 0.0; k.vh = 0.0
		k.lap = -1           # crossing the line at the start begins lap 0
		k.halfway = true
		k.safe_s = k.s
		k._prev_s = k.s
		k.progress = k.s - L
		k.finished = false
		k.controls = false
		k.bits = 0
		k.boost_t = 0.0
		k.falling = false
		k.air = false
		k._end_drift()
		k._place_visual(0.016)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	ui = HUD.new()
	layer.add_child(ui)
	ui.build(track, karts, me)
	ui.modulate.a = 0.0

func _build_audio() -> void:
	if _has_audio("engine"):
		_engine = AudioStreamPlayer.new()
		_engine.bus = "SFX"
		var st := load(DIR + "audio/engine.ogg") as AudioStreamOggVorbis
		st.loop = true
		_engine.stream = st
		_engine.volume_db = -80.0
		add_child(_engine)
	if _has_audio("drift"):
		_drift_snd = AudioStreamPlayer.new()
		_drift_snd.bus = "SFX"
		var st2 := load(DIR + "audio/drift.ogg") as AudioStreamOggVorbis
		st2.loop = true
		_drift_snd.stream = st2
		_drift_snd.volume_db = -80.0
		add_child(_drift_snd)

func _has_audio(n: String) -> bool:
	if not _audio_ok.has(n):
		_audio_ok[n] = ResourceLoader.exists(DIR + "audio/%s.ogg" % n)
	return _audio_ok[n]

func sfx(n: String, vol := 0.0, pitch := 1.0, rand := 0.0) -> void:
	if _has_audio(n): Sound.sfx(DIR + "audio/%s.ogg" % n, vol, pitch, rand)

# =================================================================== flow
func _on_intro() -> void:
	if _quick:
		ui.modulate.a = 1.0
		return
	state = "title"
	_show_title()

func _show_title() -> void:
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", -6)
	var t: Label = ui._label(120, Color(1.0, 0.9, 0.6), 24)
	t.text = info.title if info else "Prism Boulevard"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t)
	var s: Label = ui._label(40, Color(0.85, 0.9, 1.0), 10, ui.FONT_SB)
	s.text = "Grand Prix · %d laps · 8 racers" % LAPS
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(s)
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.offset_top -= 70
	root.offset_bottom -= 70
	root.modulate.a = 0.0
	sfx("fanfare_start", -4.0)
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(ui, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.8)
	tw.tween_property(root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		root.queue_free()
		hint("Claude accelerates on her own · A/D steer · S brake\nHold Space or Shift + steer = drift → mini-turbo\nIn the air Space/E = trick · R = back on the track", 9.0)
		_start_countdown())

func _start_countdown() -> void:
	state = "countdown"
	_count_t = 0.0
	_count_step = 4
	_rocket_press = -1.0
	pieces.set_lights(0)

func _countdown(dt: float) -> void:
	_count_t += dt
	var step := 3 - int(floor(_count_t - 0.6))
	if _count_t < 0.6: step = 4
	if step != _count_step and step <= 3:
		_count_step = step
		if step > 0:
			ui.show_count(str(step), [Color(1, 0.4, 0.5), Color(1, 0.8, 0.3), Color(0.5, 0.9, 1.0)][3 - step])
			pieces.set_lights(4 - step)
			sfx("count", -3.0)
		else:
			ui.show_count("GO!", Color(0.6, 1.0, 0.6))
			pieces.set_lights(4)
			sfx("go", -2.0)
			_go()
	# rocket start: press hop just before GO and keep holding it
	if _hop_pressed() and _rocket_press < 0.0:
		_rocket_press = _count_t

func _go() -> void:
	state = "race"
	race_time = 0.0
	for k in karts:
		k.controls = true
		if not k.is_player:
			# rivals: a few get a rocket start too
			if randf() < 0.45: k.boost(0.8, KART.BOOST_MULT)
	var go_t := 3.6
	if _rocket_press >= 0.0 and _hop_held():
		if _rocket_press > go_t - 0.55:
			me.boost(1.3, KART.BOOST_MULT)
			sfx("turbo", -2.0)
			ui.show_banner("ROCKET START!", "", 0.9, Color(1, 0.7, 0.9))
		elif _rocket_press < go_t - 1.2:
			me.stun = 0.9          # too early: wheels spin
	if _has_audio("race"): Sound.music(DIR + "audio/race.ogg", 0.2)
	if _engine: _engine.play()
	if _drift_snd: _drift_snd.play()
	say("Let's race!", 1.6)

func lap_done(k) -> void:
	if _log: print("[pb] %6.2f lap %d done: %s (place %d)" % [race_time, k.lap, k.racer_name, k.place])
	if k.lap <= 0:
		return            # the first crossing is the start
	if k.lap >= LAPS and not k.finished:
		k.finished = true
		k.finish_time = race_time
		k.controls = false
		finish_order.append(k)
		if k.is_player: _player_finished()
		return
	if k.is_player:
		if k.lap == LAPS - 1:
			_final_lap = true
			ui.show_banner("FINAL LAP!", "", 1.6, Color(1, 0.55, 0.75))
			sfx("final_lap", -2.0)
			if _has_audio("race_fast"):
				Sound.stop_music(0.3)
				get_tree().create_timer(1.6).timeout.connect(func():
					if state == "race": Sound.music(DIR + "audio/race_fast.ogg", 0.2))
		else:
			ui.show_banner("LAP %d" % (k.lap + 1), "", 1.0, Color(0.7, 0.95, 1.0))
			sfx("lap", -4.0)

func _player_finished() -> void:
	state = "finished"
	_finish_t = 0.0
	var p: int = me.place
	Sound.stop_music(0.6)
	if p == 1:
		ui.show_banner("YOU WIN!", "1st place · " + HUD.fmt_time(race_time), 0.0, Color(1, 0.85, 0.3))
		sfx("win", 0.0)
		claude.rig.mood = RobotRig.Mood.SPARKLE
	else:
		ui.show_banner("FINISH!", "%d%s place · %s" % [p, HUD.ordinal_suffix(p), HUD.fmt_time(race_time)], 0.0, HUD.place_color(p))
		sfx("finish", -1.0)
		claude.rig.mood = RobotRig.Mood.HAPPY if p <= 3 else RobotRig.Mood.NORMAL
	pieces.fireworks(true)
	if _engine: _engine.volume_db = -20.0

func _show_results() -> void:
	_results_shown = true
	ui.hide_banner()
	var rows: Array = []
	var rest: Array = karts.filter(func(k): return not k.finished)
	rest.sort_custom(func(a, b): return a.progress > b.progress)
	var all: Array = finish_order + rest
	for i in all.size():
		var k = all[i]
		var tm := HUD.fmt_time(k.finish_time) if k.finished else "--:--.--"
		if not k.finished:
			# estimate from the remaining distance
			var left: float = LAPS * track.length - k.progress
			tm = HUD.fmt_time(race_time + left / maxf(k.V_MAX * 0.95, 1.0))
		rows.append([i + 1, k.racer_name, tm, k.is_player, k.paint])
	var p: int = me.place
	ui.show_results(rows, "Prism Boulevard GP" if p > 1 else "Champion of the Boulevard!")
	if p == 1: say("I won?! I'm framing this one.", 3.0)
	elif p <= 3: say("On the podium! Not bad for a dreamer.", 3.0)
	else: say("Next time I'll drift more.", 3.0)

func _restart() -> void:
	ui.clear_results()
	ui.hide_banner()
	_results_shown = false
	_res_shift = 0.0
	finish_order.clear()
	_final_lap = false
	pieces.fireworks(false)
	pieces.reset_bits()
	_place_grid()
	claude.rig.mood = RobotRig.Mood.NORMAL
	if _engine: _engine.stop()
	_snap_camera()
	_start_countdown()

# =================================================================== input
func _hop_pressed() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("sprint")

func _hop_held() -> bool:
	return Input.is_action_pressed("jump") or Input.is_action_pressed("sprint")

func _player_input() -> Dictionary:
	if _autopilot or state == "finished":
		var ai: Dictionary = me.ai_input(0.016, karts)
		if _weak and state != "finished":
			# dev: a clumsy driver – late, wobbly steering, no drifts or tricks
			_weak_t += 0.016
			ai["steer"] = clampf(float(ai["steer"]) * 0.8 + sin(_weak_t * 1.7) * 0.35 + sin(_weak_t * 4.3) * 0.2, -1.0, 1.0)
			ai["hop_pressed"] = false
			ai["hop_held"] = false
		return ai
	var inp := {
		"steer": Input.get_axis("move_left", "move_right"),
		"brake": Input.is_action_pressed("move_back") and not me.gliding,
		"hop_pressed": _hop_pressed() or (Input.is_action_just_pressed("interact") and me.air),
		"hop_held": _hop_held(),
	}
	if Input.is_action_just_pressed("respawn") and not me.falling and state == "race":
		me.rescue()
	return inp

# =================================================================== update
func _process(delta: float) -> void:
	if _parked: return
	var dt := minf(delta, 1.0 / 30.0)
	_t += dt
	match state:
		"countdown": _countdown(dt)
		"race":
			race_time += dt
			if _log:
				_log_t += dt
				if _log_t > 5.0:
					_log_t = 0.0
					print("[pb] %6.2f me s=%.0f x=%.1f v=%.1f place %d sec %s air %s" % [race_time, me.s, me.x, me.v, me.place, track.section_at(me.s), me.air])
		"finished":
			race_time += dt
			_finish_t += dt
			if _finish_t > 2.6 and not _results_shown:
				_show_results()
				if _log:
					for k in karts: print("[pb] result %s place %d time %.2f bits %d" % [k.racer_name, k.place, k.finish_time, k.bits])
					get_tree().quit()
			if _results_shown:
				if Input.is_action_just_pressed("jump"):
					state = "done"
					complete(0.6)
				elif Input.is_action_just_pressed("respawn"):
					_restart()
	if state in ["race", "finished", "done", "countdown"]:
		for k in karts:
			var inp: Dictionary
			if k == me: inp = _player_input()
			else: inp = k.ai_input(dt, karts)
			k.step(dt, inp)
		_collide(dt)
		_rank()
		pieces.update(dt, karts, me)
	_update_camera(dt)
	_update_audio(dt)
	ui.update_race(me, karts, LAPS, race_time, dt)
	var lines := 0.0
	if state == "race" and (me.boost_t > 0.0 or track.is_hyper(me.s)): lines = 1.0
	_lines = lerpf(_lines, lines, 1.0 - exp(-6.0 * dt))
	ui.set_speed_lines(_lines)

func _collide(_dt: float) -> void:
	var L: float = track.length
	for i in karts.size():
		var a = karts[i]
		if a.falling: continue
		for j in range(i + 1, karts.size()):
			var b = karts[j]
			if b.falling: continue
			var ds: float = wrapf(b.s - a.s, -L * 0.5, L * 0.5)
			if absf(ds) > 1.9: continue
			var dx: float = b.x - a.x
			if absf(dx) > 1.45 or absf(a.h - b.h) > 1.2: continue
			# push apart sideways, the one behind loses a little speed
			var push := (1.45 - absf(dx)) * 0.5
			var sg := signf(dx) if dx != 0.0 else 1.0
			a.x -= sg * push
			b.x += sg * push
			var back = a if ds > 0.0 else b
			var front = b if ds > 0.0 else a
			if back.v > front.v:
				var dv: float = back.v - front.v
				back.v -= dv * 0.5
				front.v += dv * 0.25
			a.psi -= sg * 0.08
			b.psi += sg * 0.08
			if (a == me or b == me) and me.bump_cool <= 0.0:
				me.bump_cool = 0.3
				sfx("bump", -6.0, randf_range(0.9, 1.1))
				_shake = maxf(_shake, 0.25)

func _rank() -> void:
	var order: Array = karts.duplicate()
	order.sort_custom(func(a, b):
		if a.finished != b.finished: return a.finished
		if a.finished: return a.finish_time < b.finish_time
		return a.progress > b.progress)
	for i in order.size():
		order[i].place = i + 1

func rubber_band(k) -> float:
	if me == null: return 1.0
	var gap: float = me.progress - k.progress     # > 0: the rival is behind Claude
	return clampf(1.0 + gap / 900.0, 0.94, 1.07)

# =================================================================== camera
func _chase_target() -> Array:
	var fr: Transform3D = track.frame(me.s)
	var up: Vector3 = fr.basis.y
	var fwd: Vector3 = (-fr.basis.z).rotated(up, -me.psi * 0.55 - float(me.drift_dir) * 0.12)
	var pos: Vector3 = me.world_pos
	var dist := 5.4 + _boost_fov * 0.05
	var eye := pos - fwd * dist + up * 2.05
	var look := pos + fwd * 4.0 + up * 0.85
	return [eye, look, up, fwd]

func _snap_camera() -> void:
	var t := _chase_target()
	_cam_pos = t[0]
	_cam_up = t[2]
	cam.global_transform = Transform3D(Basis.looking_at(t[1] - t[0], t[2]), t[0])

func _update_camera(dt: float) -> void:
	if intro_running or cam == null: return
	if me.falling:
		cam.look_at(me.world_pos, _cam_up)
		return
	var t := _chase_target()
	var eye: Vector3 = t[0]
	var look: Vector3 = t[1]
	_cam_up = _cam_up.slerp(t[2], 1.0 - exp(-6.0 * dt)).normalized()
	_cam_pos = _cam_pos.lerp(eye, 1.0 - exp(-14.0 * dt))
	var p := _cam_pos
	if state == "finished" or state == "done":
		# swing round to the front of the kart
		var a := clampf(_finish_t / 3.0, 0.0, 1.0)
		var fwd: Vector3 = t[3]
		var side := fwd.cross(_cam_up).normalized()
		var front: Vector3 = me.world_pos + fwd * 6.0 + side * 2.5 + _cam_up * 1.6
		p = _cam_pos.lerp(front, smoothstep(0.0, 1.0, a))
		# Claude on the left of the picture, the results on the right
		_res_shift = lerpf(_res_shift, 2.4 if _results_shown else 0.0, 1.0 - exp(-2.5 * dt))
		look = look.lerp(me.world_pos + _cam_up * 0.9 - side * _res_shift, a)
	if _shake > 0.0:
		_shake = maxf(_shake - dt * 1.5, 0.0)
		p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.15
	cam.global_transform = Transform3D(Basis.looking_at(look - p, _cam_up), p)
	var spd: float = clampf(me.v / KART.V_MAX, 0.0, 1.5)
	var target_fov := 66.0 + spd * 8.0 + (10.0 if me.boost_t > 0.0 else 0.0) + (8.0 if track.is_hyper(me.s) else 0.0)
	_boost_fov = lerpf(_boost_fov, target_fov - 66.0, 1.0 - exp(-4.0 * dt))
	cam.fov = 66.0 + _boost_fov

# =================================================================== audio
func _update_audio(dt: float) -> void:
	if _engine and _engine.playing:
		var spd: float = clampf(absf(me.v) / KART.V_MAX, 0.0, 1.6)
		_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.55 + spd * 0.75 + (0.12 if me.boost_t > 0.0 else 0.0) + (0.1 if me.air else 0.0), 1.0 - exp(-6.0 * dt))
		_engine.volume_db = lerpf(_engine.volume_db, -14.0 if state != "finished" else -24.0, 1.0 - exp(-3.0 * dt))
	if _drift_snd and _drift_snd.playing:
		var on: bool = me.drift_dir != 0 and not me.air
		_drift_snd.volume_db = lerpf(_drift_snd.volume_db, -12.0 if on else -60.0, 1.0 - exp(-12.0 * dt))
		_drift_snd.pitch_scale = 0.9 + 0.12 * me.mt_level

# =================================================================== callbacks from the karts
func wall_hit(k, impact: float) -> void:
	if k == me:
		sfx("bump", -8.0 + clampf(impact * 0.4, 0.0, 6.0), randf_range(0.85, 1.05))
		_shake = maxf(_shake, clampf(impact / 25.0, 0.1, 0.5))
	pieces.wall_sparks(k)

func boost_fx(_t_: float) -> void:
	ui.do_flash(0.12, 0.25)

func trick_fx() -> void:
	pass

func ring_passed(k, _rg) -> void:
	if k == me: ui.do_flash(0.18, 0.3)

func rescued(k) -> void:
	if _log: print("[pb] %6.2f rescued %s at s=%.0f (%s)" % [race_time, k.racer_name, k.s, track.section_at(k.s)])
	if k == me:
		ui.do_flash(0.5, 0.6)
		sfx("rescue", -6.0)
		_snap_camera()
