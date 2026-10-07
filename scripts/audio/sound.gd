## Music (with cross-fades), looping ambiences and one-shot sound effects.
## Runs as the autoload "Audio"; call the static functions: Sound.music(…).
## Names refer to the built-in tracks/effects; levels can pass their own
## "res://…" paths instead (music loops by default).
class_name Sound
extends Node

static var inst: Sound

const MUSIC := {
	"film_a": "res://assets/audio/film/film_a.ogg",
	"film_pool": "res://assets/audio/film/film_pool.ogg",
	"film_flight": "res://assets/audio/film/film_flight.ogg",
	"film_warp": "res://assets/audio/film/film_warp.ogg",
	"film_b": "res://assets/audio/film/film_b.ogg",
	"film_full": "res://assets/audio/film/film_full.ogg",
	"garden": "res://assets/audio/music/garden.ogg",
	"space": "res://assets/audio/music/space.ogg",
	"hub": "res://assets/audio/music/hub.ogg",
}
const LOOPING := ["garden", "space", "hub"]

var _players: Array[AudioStreamPlayer] = []
var _cur := 0
var _cur_name := ""
var _loops := {}
var _cache := {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _tweens := {}
var _ui: AudioStreamPlayer
## while a scene is built ahead of time (SceneSwap), its music/loop calls are
## kept here and played when the scene is switched on
var _capturing := false
var _captured: Array = []

func _ready() -> void:
	inst = self
	# the fades keep running in the pause menu, the sound itself pauses with
	# the game (the players are PAUSABLE) – only the menu clicks (ui()) don't
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings._ensure_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		p.bus = "Music"
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		_players.append(p)
	for i in 24:
		var s := AudioStreamPlayer.new()
		s.bus = "SFX"
		s.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(s)
		_sfx_pool.append(s)
	_ui = AudioStreamPlayer.new()
	_ui.bus = "SFX"
	add_child(_ui)

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

static func music(name: String, fade := 1.5, from := 0.0, vol_db := 0.0) -> void:
	if inst == null: return
	if inst._capturing:
		inst._stream(name if name.begins_with("res://") else MUSIC[name])   # load it now
		inst._captured.append(["music", name, fade, from, vol_db]); return
	inst._music(name, fade, from, vol_db)

func _music(name: String, fade: float, from: float, vol_db: float) -> void:
	var old := _players[_cur]
	_cur = 1 - _cur
	var p := _players[_cur]
	var path: String = name if name.begins_with("res://") else MUSIC[name]
	var st := _stream(path) as AudioStreamOggVorbis
	if st: st.loop = name in LOOPING or name.begins_with("res://")
	p.stream = st
	p.stream_paused = false
	p.volume_db = -60.0 if fade > 0.01 else vol_db
	p.play(from)
	_cur_name = name
	_fade(p, vol_db, fade)
	_fade(old, -80.0, fade, true)

func _fade(p: AudioStreamPlayer, to_db: float, dur: float, stop_after := false) -> void:
	if _tweens.has(p) and (_tweens[p] as Tween).is_valid(): (_tweens[p] as Tween).kill()
	if dur <= 0.01:
		p.volume_db = to_db
		if stop_after: p.stop()
		return
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(p, "volume_db", to_db, dur).set_trans(Tween.TRANS_SINE if to_db > p.volume_db else Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT if to_db > p.volume_db else Tween.EASE_IN)
	if stop_after: tw.tween_callback(p.stop)
	_tweens[p] = tw

static func stop_music(fade := 1.5) -> void:
	if inst == null: return
	if inst._capturing:
		inst._captured.append(["stop_music", fade]); return
	inst._fade(inst._players[inst._cur], -80.0, fade, true)
	inst._cur_name = ""

static func music_name() -> String:
	return inst._cur_name if inst else ""

static func music_pos() -> float:
	if inst == null: return 0.0
	var p := inst._players[inst._cur]
	return p.get_playback_position() + AudioServer.get_time_since_last_mix() if p.playing else -1.0

static func music_seek(t: float) -> void:
	if inst: inst._players[inst._cur].seek(t)

static func sfx(name: String, vol_db := 0.0, pitch := 1.0, rand := 0.0) -> void:
	if inst == null or inst._capturing: return
	var st := inst._stream(name if name.begins_with("res://") else "res://assets/audio/sfx/%s.ogg" % name)
	for p in inst._sfx_pool:
		if not p.playing:
			p.stream = st
			p.volume_db = vol_db
			p.pitch_scale = pitch * (1.0 + randf_range(-rand, rand))
			p.play()
			return

static func loop(name: String, vol_db := 0.0, fade := 0.8) -> void:
	if inst == null: return
	if inst._capturing:
		inst._stream(name if name.begins_with("res://") else "res://assets/audio/sfx/%s.ogg" % name)
		inst._captured.append(["loop", name, vol_db, fade]); return
	var p: AudioStreamPlayer
	if inst._loops.has(name):
		p = inst._loops[name]
	else:
		p = AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		var st := inst._stream(name if name.begins_with("res://") else "res://assets/audio/sfx/%s.ogg" % name) as AudioStreamOggVorbis
		st.loop = true
		p.stream = st
		p.volume_db = -80.0
		inst.add_child(p)
		inst._loops[name] = p
	if not p.playing: p.play()
	inst._fade(p, vol_db, fade)

static func loop_stop(name: String, fade := 0.8) -> void:
	if inst and inst._capturing:
		inst._captured.append(["loop_stop", name, fade]); return
	if inst and inst._loops.has(name):
		inst._fade(inst._loops[name], -80.0, fade, true)

## a menu sound – also plays while the game is paused
static func ui(name: String, vol_db := -8.0, pitch := 1.0) -> void:
	if inst == null: return
	inst._ui.stream = inst._stream("res://assets/audio/sfx/%s.ogg" % name)
	inst._ui.volume_db = vol_db
	inst._ui.pitch_scale = pitch
	inst._ui.play()

## Stop the music and every loop (used when leaving a level).
static func stop_all(fade := 0.0) -> void:
	if inst == null: return
	if inst._capturing:
		inst._captured.append(["stop_all", fade]); return
	stop_music(fade)
	for n in inst._loops.keys(): loop_stop(n, fade)

## load a track now, so playing it later doesn't have to wait for the file
static func warm(name: String) -> void:
	if inst: inst._stream(name if name.begins_with("res://") else MUSIC[name])

## SceneSwap: start/stop keeping the music calls of a scene built ahead of
## time; capture(false) returns them for replay()
static func capture(on: bool) -> Array:
	if inst == null: return []
	inst._capturing = on
	var out := inst._captured
	if on: inst._captured = []
	else: inst._captured = []
	return [] if on else out

static func replay(calls: Array) -> void:
	for c in calls:
		match c[0]:
			"music": music(c[1], c[2], c[3], c[4])
			"stop_music": stop_music(c[1])
			"loop": loop(c[1], c[2], c[3])
			"loop_stop": loop_stop(c[1], c[2])
			"stop_all": stop_all(c[1])
