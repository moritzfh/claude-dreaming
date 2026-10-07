## Die Werkstatt: what moves, glows and can be used in the workshop. The
## right half is only sketched until "Work in Progress" is finished – then
## room_done.png is laid over it. (The pictures come from
## source/make_room.py.)
extends DreamRoom

const DONE_TEX := preload("res://rooms/werkstatt/room_done.png")
const SCREEN := Rect2i(149, 91, 33, 22)     # inside of the monitor
const BOX := Vector2(143, 147)              # the box of bugs
const COMMITS := [
	"feat: Work in Progress – a level that isn't finished. On purpose.",
	"fix: the stutter when stepping into a painting. Completely.",
	"feat: Claude has arms now.",
	"feat: the first dream is already painted on the easel.",
	"feat: menus. Everywhere.",
	"chore: delete final_final_v3 (there was a final_final_v4).",
	"fix: Claude no longer walks through walls. Mostly.",
]
const CODE_COLS := [Color(0.5, 0.85, 1.0), Color(0.85, 0.6, 1.0), Color(0.55, 0.95, 0.6), Color(1.0, 0.8, 0.45), Color(0.75, 0.78, 0.82)]

var done := false
var _code: Node2D
var _lines: Array = []          # [indent, length, colour index]
var _scroll := 0.0
var _caret := 0.0
var _led: Sprite2D
var _mon_glow: Sprite2D
var _lamp_glow: Sprite2D
var _steam: Array = []
var _steam_t := 0.0
var _cursor: Sprite2D
var _dabs: Array = []
var _dab_t := 0.0
var _bugs: Array = []           # [sprite, x, dir, age, life]
var _next_bug := 6.0
var _commit_i := 0
var _hearts: Array = []

func build() -> void:
	done = GameState.completed.has("wip")
	if done: add_sprite(DONE_TEX, Vector2.ZERO)
	# light
	_mon_glow = add_glow(Vector2(165, 102), 34, Color(0.45, 0.85, 1.0, 0.22))
	_lamp_glow = add_glow(Vector2(141, 118), 18, Color(1.0, 0.75, 0.45, 0.45))
	add_glow(Vector2(92, 58), 16, Color(1.0, 0.85, 0.55, 0.35))
	if done: add_glow(Vector2(322, 64), 26, Color(0.45, 0.5, 1.0, 0.15))
	# the monitor: code scrolls by
	_code = Node2D.new()
	_code.draw.connect(_draw_code)
	add_child(_code)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 60:
		_lines.append([rng.randi_range(0, 3) * 3, rng.randi_range(4, 24), rng.randi() % CODE_COLS.size()])
	_led = add_sprite(DreamRoom.pixels(["#"], {"#": Color(0.25, 1.0, 0.45)}), Vector2(196, 150))
	# the cursor that paints the room (until it's finished)
	_cursor = add_sprite(DreamRoom.pixels([
		"X...........",
		"XX..........",
		"XOX.........",
		"XOOX........",
		"XOOOX.......",
		"XOOOOX......",
		"XOOOOOX.....",
		"XOOOOOOX....",
		"XOOOOOOOX...",
		"XOOOOOOOOX..",
		"XOOOOOOXXXXX",
		"XOOOXOOX....",
		"XOOX.XOOX...",
		"XOX..XOOX...",
		"XX....XOOX..",
		"......XOOX..",
		".......XX...",
	], {"X": Color(0.08, 0.07, 0.12), "O": Color(1.0, 0.98, 0.94)}), Vector2(236, 70))
	_cursor.visible = not done
	# things Claude can use
	add_object("todo", Vector2(36, 168), "TODO-Liste", _todo_lines, Callable(), 18, 0)
	add_object("bugs", Vector2(143, 170), "Kiste mit Bugs", ["A box full of bugs.", "They're friendly. Mostly."], _release_bug, 12, 3)
	add_object("monitor", Vector2(168, 168), "Monitor", _monitor_lines, Callable(), 14, 0)
	add_object("duck", Vector2(203, 170), "Gummiente", ["A rubber duck.", "You explain your bug to it, line by line …", "… and suddenly you see it yourself."], _squeak, 12, 1)
	if done:
		add_object("blueprint", Vector2(233, 168), "Bauplan", ["A blueprint of … me?", "The antenna is a bit crooked. I like it."], Callable(), 12, 2)
		add_object("shelf", Vector2(271, 170), "Bücherregal", ["Books about shaders, sound and pixel art.", "And one about knitting. Hm."], Callable(), 16, 0)
		add_object("beanbag", Vector2(320, 172), "Sitzsack", ["A bean bag.", "This is where the other Claude thinks. Probably."], Callable(), 20, 1)
	else:
		add_object("cursor", Vector2(242, 170), "Mauszeiger", ["The cursor.", "It paints this room while nobody's looking.", "Slowly. Very slowly."], Callable(), 14, 3)
		add_object("sketch", Vector2(302, 172), "Skizze", ["This part is only sketched.", "A bookshelf, a window, a bean bag …", "Maybe it gets finished when the painting next door is."], Callable(), 22, 0)

func _todo_lines() -> Array:
	var out := ["The to-do list.", "\"Give Claude arms.\" – done.", "\"Remove the stutter. Completely.\" – done."]
	if GameState.completed.has("wip"):
		out.append("\"Finish painting this room.\" – done! When did that happen?")
	else:
		out.append("\"Finish painting this room.\" – … still open.")
	return out

func _monitor_lines() -> Array:
	var out := ["The other Claude's terminal. git log:"]
	for k in 2:
		out.append("\"%s\"" % COMMITS[(_commit_i + k) % COMMITS.size()])
	_commit_i = (_commit_i + 2) % COMMITS.size()
	var st: Dictionary = GameState.stats.get("wip", {})
	if st.has("falls") and _commit_i == 0:
		out.append("Somebody wrote: \"Claude fell %d times. Working as intended.\"" % int(st["falls"]))
	return out

func _draw_code() -> void:
	var r := SCREEN
	var row_h := 2
	var first := int(_scroll)
	for i in r.size.y / row_h:
		var l: Array = _lines[(first + i) % _lines.size()]
		var y := r.position.y + i * row_h
		var x0: int = r.position.x + int(l[0])
		var x1: int = mini(x0 + int(l[1]), r.end.x)
		if x1 > x0:
			_code.draw_rect(Rect2(x0, y, x1 - x0, 1), Color(CODE_COLS[int(l[2])], 0.85))
	# the caret on the last line
	if fmod(_caret, 1.0) < 0.55:
		var l: Array = _lines[(first + r.size.y / row_h - 1) % _lines.size()]
		var cx: int = mini(r.position.x + int(l[0]) + int(l[1]) + 1, r.end.x - 1)
		_code.draw_rect(Rect2(cx, r.position.y + (r.size.y / row_h - 1) * row_h - 1, 1, 2), Color(0.9, 1.0, 0.95))

func _release_bug() -> void:
	for k in 2:
		_spawn_bug(-1.0 if k == 0 else 1.0)

func _spawn_bug(dir: float) -> void:
	var s := add_sprite(DreamRoom.pixels([".#.#", "####", "#.#."], {"#": Color(0.25, 0.75, 0.3)}), BOX)
	s.z_index = 1
	_bugs.append([s, BOX.x, dir, 0.0, randf_range(3.0, 5.0)])

func _squeak() -> void:
	Sound.sfx("beep", -6.0, 2.2)
	var h := add_sprite(DreamRoom.pixels([".#.#.", "#####", ".###.", "..#.."], {"#": Color(1.0, 0.55, 0.65)}), Vector2(203, 108))
	h.set_meta("age", 0.0)
	_hearts.append(h)

func _process(delta: float) -> void:
	t += delta
	# code scrolls in little bursts, like someone typing
	_scroll += delta * (2.5 + 2.0 * maxf(0.0, sin(t * 0.7)))
	_caret += delta * 1.6
	_code.queue_redraw()
	_mon_glow.modulate.a = 0.2 + 0.03 * sin(t * 7.0) + 0.02 * sin(t * 2.3)
	_lamp_glow.modulate.a = 0.42 + 0.04 * sin(t * 1.7)
	var on := fmod(t, 1.3) < 0.9 or fmod(t * 7.0, 1.0) < 0.5
	_led.modulate = Color(1, 1, 1) if on else Color(0.15, 0.25, 0.18)
	# steam from the mug
	_steam_t -= delta
	if _steam_t <= 0.0:
		_steam_t = 0.45
		var s := add_sprite(DreamRoom.pixels(["#"], {"#": Color(1, 1, 1, 0.55)}), Vector2(197, 115))
		s.set_meta("age", 0.0)
		_steam.append(s)
	for sp in _steam.duplicate():
		var s: Sprite2D = sp
		var age: float = float(s.get_meta("age")) + delta
		s.set_meta("age", age)
		s.position = Vector2(round(197 + sin(age * 4.0 + s.get_instance_id()) * 1.2), round(115 - age * 7.0))
		s.modulate.a = clampf(1.0 - age / 1.6, 0.0, 1.0)
		if age > 1.6:
			_steam.erase(s)
			s.queue_free()
	# the cursor wanders along the edge of the paint and dabs at it
	if not done:
		var p := Vector2(226 + 10.0 * sin(t * 0.37), 66 + 34.0 * (0.5 + 0.5 * sin(t * 0.23)))
		_cursor.position = p.round()
		_dab_t -= delta
		if _dab_t <= 0.0:
			_dab_t = randf_range(0.5, 1.1)
			var col: Color = [Color(0.2, 0.33, 0.33), Color(0.24, 0.38, 0.37), Color(0.29, 0.43, 0.41)][randi() % 3]
			var d := add_sprite(DreamRoom.pixels(["##"], {"#": col}), (p + Vector2(-3, 0)).round())
			d.set_meta("age", 0.0)
			_dabs.append(d)
		for dd in _dabs.duplicate():
			var d: Sprite2D = dd
			var age: float = float(d.get_meta("age")) + delta
			d.set_meta("age", age)
			d.modulate.a = clampf(1.0 - (age - 2.0) / 1.5, 0.0, 1.0)
			if age > 3.5:
				_dabs.erase(d)
				d.queue_free()
	# a bug escapes now and then (and always when you open the box)
	_next_bug -= delta
	if _next_bug <= 0.0:
		_next_bug = randf_range(9.0, 16.0)
		_spawn_bug(-1.0 if randf() < 0.5 else 1.0)
	for b in _bugs.duplicate():
		var s: Sprite2D = b[0]
		b[3] += delta
		var age: float = b[3]
		var life: float = b[4]
		var dir: float = b[2]
		var x: float = BOX.x + dir * 22.0 * (age if age < life * 0.5 else life - age)
		var y := 157.0 + (2.0 if age > 0.3 else 0.0) * minf(age / 0.3, 1.0)
		s.position = Vector2(round(x), round(lerpf(BOX.y, y, minf(age / 0.4, 1.0))))
		s.flip_h = (dir < 0.0) == (age < life * 0.5)
		s.visible = fmod(age * 9.0, 1.0) < 0.85 or age < 0.4
		if age >= life:
			_bugs.erase(b)
			s.queue_free()
	# a little heart over the rubber duck when it squeaks
	for hh in _hearts.duplicate():
		var h: Sprite2D = hh
		var age: float = float(h.get_meta("age")) + delta
		h.set_meta("age", age)
		h.position = Vector2(203, round(108 - age * 8.0))
		h.modulate.a = clampf(1.5 - age, 0.0, 1.0)
		if age > 1.5:
			_hearts.erase(h)
			h.queue_free()
