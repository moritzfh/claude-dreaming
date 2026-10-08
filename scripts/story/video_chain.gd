## Plays a film segment that was split into several Theora chunks, with the
## soundtrack as a separate continuous stream. Skippable (hold Enter, or the
## pause menu). Pauses with the game.
class_name VideoChain
extends CanvasLayer

signal finished(last_frame: Texture2D)

var files: Array = []
## length of every chunk in seconds (to keep the soundtrack in sync)
var durations: Array = []
## true if the player skipped it
var skipped := false
var _ends: Array = []
var _clock := 0.0
var music_name := ""
var music_from := 0.0
var _players: Array[VideoStreamPlayer] = []
var _idx := 0
var _active := 0
var _bg: ColorRect
var _box: AspectRatioContainer
var _done := false
var _skip_hold := 0.0
var _hint: Label
var _switching := false

func _ready() -> void:
	layer = 20
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_box = AspectRatioContainer.new()
	_box.ratio = 16.0 / 9.0
	_box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_box)
	for i in 2:
		var v := VideoStreamPlayer.new()
		v.expand = true
		v.volume_db = -80.0
		v.visible = false
		_box.add_child(v)
		v.finished.connect(_on_chunk_finished.bind(i))
		_players.append(v)
	_hint = Label.new()
	_hint.text = "Hold Enter: skip  ·  Esc: menu"
	_hint.add_theme_font_override("font", load("res://assets/fonts/EBGaramond-Italic.woff2"))
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 0.55))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -560; _hint.offset_top = -50; _hint.offset_right = -24; _hint.offset_bottom = -16
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate.a = 0.0
	add_child(_hint)

## clen: the length of each chunk, one number for all or an Array with one per chunk
func play_chain(paths: Array, music: String, from := 0.0, clen: Variant = 15.25) -> void:
	files = paths
	music_name = music
	music_from = from
	durations = []
	_ends = []
	var end := 0.0
	for i in paths.size():
		durations.append(float(clen[mini(i, clen.size() - 1)]) if clen is Array else float(clen))
		end += float(durations[i])
		_ends.append(end)
	_idx = 0
	_active = 0
	_clock = 0.0
	_load(0, files[0])
	_players[0].visible = true
	_players[0].play()
	if files.size() > 1: _load(1, files[1])
	if music != "": Sound.music(music, 0.0, from)
	create_tween().tween_property(_hint, "modulate:a", 1.0, 1.0).set_delay(2.0)

func _load(slot: int, path: String) -> void:
	_players[slot].stream = load(path)

func _on_chunk_finished(slot: int) -> void:
	# the chunks are switched by the clock (see _process); only the very last
	# one ends the film when it is over
	if not _done and slot == _active and _idx == files.size() - 1:
		_finish()

## The chunks follow one clock, so the small gaps at every switch don't add
## up: after 15 switches the picture would otherwise lag behind the music.
func _next_chunk() -> void:
	_idx += 1
	var nxt := 1 - _active
	_players[nxt].visible = true
	_players[nxt].play()
	_switching = true
	# keep showing the old chunk's last frame until the new one has a frame
	await get_tree().process_frame
	await get_tree().process_frame
	_players[_active].stop()
	_players[_active].visible = false
	_switching = false
	_active = nxt
	# re-sync the soundtrack if it drifted (e.g. after a hitch)
	if music_name != "" and Sound.music_name() == music_name:
		var expect := music_from + _clock
		var pos := Sound.music_pos()
		if pos >= 0.0 and absf(pos - expect) > 0.12:
			Sound.music_seek(expect)
	if _idx + 1 < files.size():
		_load(1 - _active, files[_idx + 1])

func _process(delta: float) -> void:
	if _done: return
	_clock += delta
	if not _switching:
		if _idx < files.size() - 1 and _clock >= float(_ends[_idx]):
			_next_chunk()
		elif _idx == files.size() - 1 and _clock >= float(_ends[_idx]) + 0.3:
			_finish()   # in case the last chunk never says it is finished
	if Input.is_action_pressed("skip"):
		_skip_hold += delta
		if _skip_hold > 0.6:
			skip()
	else:
		_skip_hold = 0.0

func skip() -> void:
	if _done: return
	for p in _players: p.stop()
	_finish(true)

func _finish(was_skipped := false) -> void:
	_done = true
	skipped = was_skipped
	var tex: Texture2D = null
	var v := _players[_active]
	if not was_skipped and v.get_video_texture():
		var img := v.get_video_texture().get_image()
		if img: tex = ImageTexture.create_from_image(img)
	finished.emit(tex)

func close(fade := 0.0) -> void:
	if fade <= 0.0:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 0.0, fade)
	tw.parallel().tween_property(_box, "modulate:a", 0.0, fade)
	tw.tween_callback(queue_free)
