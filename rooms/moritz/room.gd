## Moritz' Sternwarte: what moves, glows and can be used in the observatory.
## (The room's picture is room.png, made by source/make_room.py.)
extends DreamRoom

const THEME := "res://levels/stardust/audio/stardust_theme.ogg"
const WIN := Vector2(88, 82)          # centre of the round window
const WIN_R := 30.0
const MOBILE_X := 170.0
const HORN := Vector2(43, 97)

var _arms: Array = []        # [sprite, string, angle offset, hang length]
var _bar: Line2D
var _bar2: Line2D
var _angle := 0.0
var _spin := 0.0
var _twinkles: Array = []
var _comet: Line2D
var _comet_t := -1.0
var _next_comet := 7.0
var _lamp_glow: Sprite2D
var _jar_glow: Sprite2D
var _notes: Array = []
var _note_t := 0.0
var _playing := false

func build() -> void:
	# light: the star lamp, the window, the jar of star bits
	_lamp_glow = add_glow(Vector2(30, 50), 20, Color(1.0, 0.82, 0.4, 0.5))
	add_glow(WIN, 52, Color(0.35, 0.45, 1.0, 0.14))
	_jar_glow = add_glow(Vector2(301, 98), 11, Color(1.0, 0.7, 1.0, 0.35))
	# stars twinkling in the window
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tw_tex := DreamRoom.pixels([".#.", "#O#", ".#."], {"#": Color(0.75, 0.8, 1.0, 0.7), "O": Color(1, 1, 0.95)})
	for i in 12:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (WIN_R - 4.0)
		var s := add_sprite(tw_tex, (WIN + Vector2(cos(a), sin(a)) * r - Vector2(1, 1)).round())
		s.set_meta("ph", rng.randf() * TAU)
		s.set_meta("sp", rng.randf_range(1.5, 3.5))
		_twinkles.append(s)
	# a shooting star (inside the window)
	_comet = Line2D.new()
	_comet.width = 1.0
	_comet.default_color = Color(0.85, 0.95, 1.0)
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.9, 1.0, 0.0))
	g.set_color(1, Color(1, 1, 1, 1))
	_comet.gradient = g
	_comet.visible = false
	add_child(_comet)
	_build_mobile()
	# things Claude can use
	add_object("gramophone", Vector2(30, 168), "Grammophon", func() -> Array:
		return ["Let the stars rest for a bit."] if _playing else ["A gramophone.", "It plays a waltz for the stars."], _toggle_music, 16, 1)
	add_object("window", Vector2(88, 168), "Fenster", ["Planets, close enough to touch.", "Somewhere out there floats a candy planet."], Callable(), 22, 2)
	add_object("telescope", Vector2(146, 170), "Teleskop", ["Let's see …", "A shooting star! Make a wish."], _launch_comet, 16, 3)
	add_object("jar", Vector2(301, 168), "Sternsplitter", _jar_lines, Callable(), 12, 1)

func _build_mobile() -> void:
	# a little hanging planet mobile, turning slowly (faster when Claude walks under it)
	var wire := Line2D.new()
	wire.width = 1.0
	wire.default_color = Color(0.25, 0.18, 0.1)
	wire.points = PackedVector2Array([Vector2(MOBILE_X, 24), Vector2(MOBILE_X, 38)])
	add_child(wire)
	_bar = _line(Color(0.95, 0.75, 0.35))
	_bar2 = _line(Color(0.85, 0.62, 0.28))
	var ringed := DreamRoom.pixels([
		"..ooo..",
		"#oOOOo#",
		".#ooo#.",
		"..ooo..",
	], {"o": Color(0.93, 0.55, 0.25), "O": Color(1.0, 0.78, 0.45), "#": Color(0.98, 0.85, 0.45)})
	var green := DreamRoom.pixels([".gg.", "gGgg", "gggd", ".gd."], {"g": Color(0.35, 0.75, 0.35), "G": Color(0.7, 0.95, 0.5), "d": Color(0.15, 0.45, 0.25)})
	var pink := DreamRoom.pixels([".p.", "pPp", ".p."], {"p": Color(0.95, 0.45, 0.7), "P": Color(1.0, 0.75, 0.88)})
	var star := DreamRoom.pixels(["..#..", "#####", ".###.", ".#.#."], {"#": Color(1.0, 0.86, 0.35)})
	var items := [[ringed, 0.0, 26.0], [green, PI * 0.5, 19.0], [pink, PI, 31.0], [star, PI * 1.5, 23.0]]
	for it in items:
		var string_line := _line(Color(0.35, 0.28, 0.2, 0.9))
		var s := add_sprite(it[0], Vector2.ZERO)
		_arms.append([s, string_line, it[1], it[2]])

func _line(c: Color) -> Line2D:
	var l := Line2D.new()
	l.width = 1.0
	l.default_color = c
	l.antialiased = false
	add_child(l)
	return l

func _process(delta: float) -> void:
	t += delta
	for s in _twinkles:
		var sp: Sprite2D = s
		sp.modulate.a = clampf(0.25 + 0.75 * sin(t * float(sp.get_meta("sp")) + float(sp.get_meta("ph"))), 0.0, 1.0)
	_lamp_glow.modulate.a = 0.42 + 0.12 * sin(t * 2.1)
	_jar_glow.modulate.a = 0.25 + 0.15 * sin(t * 3.3 + 1.0)
	# the mobile
	if is_claude_inside() and absf(claude_pos().x - MOBILE_X) < 12.0:
		_spin = maxf(_spin, 1.6)
	_spin = maxf(0.0, _spin - delta * 0.5)
	_angle += delta * (0.5 + _spin)
	for k in 2:
		var a := _angle + k * PI * 0.5
		var dx := cos(a) * 14.0
		(_bar if k == 0 else _bar2).points = PackedVector2Array([Vector2(MOBILE_X - dx, 38 + k), Vector2(MOBILE_X + dx, 38 + k)])
	for arm in _arms:
		var a: float = _angle + float(arm[2])
		var x := MOBILE_X + cos(a) * 14.0
		var depth := sin(a)
		var y0 := 38.0 + (1.0 if absf(cos(float(arm[2]))) < 0.5 else 0.0)
		var y1 := y0 + float(arm[3]) + sin(t * 1.3 + float(arm[2])) * 0.6
		var s: Sprite2D = arm[0]
		s.position = Vector2(round(x - s.texture.get_width() * 0.5), round(y1))
		s.z_index = 1 if depth > 0.0 else 0
		s.modulate = Color(1, 1, 1).lerp(Color(0.6, 0.62, 0.85), clampf(-depth, 0.0, 1.0) * 0.6)
		(arm[1] as Line2D).points = PackedVector2Array([Vector2(round(x), y0), Vector2(round(x), round(y1))])
	# shooting stars now and then
	_next_comet -= delta
	if _next_comet <= 0.0: _launch_comet()
	if _comet_t >= 0.0:
		_comet_t += delta / 0.9
		var a := WIN + Vector2(-24, -14)
		var b := WIN + Vector2(18, 16)
		var head := a.lerp(b, _comet_t)
		var tail := a.lerp(b, maxf(0.0, _comet_t - 0.25))
		_comet.points = PackedVector2Array([tail.round(), head.round()])
		_comet.modulate.a = sin(clampf(_comet_t, 0.0, 1.0) * PI)
		if _comet_t >= 1.0:
			_comet_t = -1.0
			_comet.visible = false
	# music notes from the gramophone
	if _playing:
		_note_t -= delta
		if _note_t <= 0.0:
			_note_t = 0.7
			var n := add_sprite(DreamRoom.pixels(["..##", "..#.", "###.", "##.."], {"#": Color(1.0, 0.9, 0.5)}), HORN)
			n.set_meta("age", 0.0)
			n.set_meta("dx", randf_range(-0.4, 0.8))
			_notes.append(n)
	for n in _notes.duplicate():
		var s: Sprite2D = n
		var age: float = float(s.get_meta("age")) + delta
		s.set_meta("age", age)
		s.position = (HORN + Vector2(float(s.get_meta("dx")) * age * 6.0 + sin(age * 3.0) * 2.0, -age * 9.0)).round()
		s.modulate.a = clampf(1.0 - age / 2.2, 0.0, 1.0)
		if age > 2.2:
			_notes.erase(s)
			s.queue_free()

func _launch_comet() -> void:
	_comet_t = 0.0
	_comet.visible = true
	_next_comet = randf_range(9.0, 15.0)
	Sound.sfx("sparkle", -10.0, 1.3)

func _toggle_music() -> void:
	_playing = not _playing
	if _playing:
		Sound.music(THEME, 1.2)
	else:
		Sound.music("hub", 1.5)

func _jar_lines() -> Array:
	var n := int((GameState.stats.get("stardust", {}) as Dictionary).get("bits", 0))
	if n > 0:
		return ["A jar of star bits.", "%d of them, from Stardust Islands." % n, "They glow a little when no one is looking."]
	return ["An empty jar.", "Star bits from Stardust Islands would look nice in here."]
