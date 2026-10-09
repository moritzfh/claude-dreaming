## A test pilot for the STORY world: plays "First Stitches" from the first
## page to the zipper pockets with simulated input, logs where Claude is and
## every tumble, and reports when it gets stuck. Used to check that the
## chapter can be finished, and to record the preview clip.
##   godot --path . -- --level=plush_desk --pd_story --pd_bot[=castle|river|cliff] [--pd_bot_exit=again|desk]
extends Node

var lvl: Node3D
var story: Node3D
var c: Player
var steps: Array = []
var i := 0
var st := 0.0
var t := 0.0
var held := {}
var _tap := {}
var _log_t := 0.0
var choice := "castle"
var exit_to := "desk"
var marks: Array = []        # [step index, x]
var _jumped := {}
var _done := false
var deaths_seen := 0
var stuck_x := 0.0
var stuck_t := 0.0
var _blocked := 0.0

const TX := 340.0

func _ready() -> void:
	process_physics_priority = -20
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pd_bot="):
			choice = a.substr(9)
		if a.begins_with("--pd_bot_exit="):
			exit_to = a.substr(14)
	story = lvl.get("story")
	c = lvl.get("claude")
	if OS.get_cmdline_user_args().has("--pd_count"):
		var geo := story.find_children("*", "GeometryInstance3D", true, false)
		var mm := 0
		var lab := 0
		for g in geo:
			if g is MultiMeshInstance3D: mm += 1
			if g is Label3D: lab += 1
		_log("story nodes: %d geometry (%d multimesh, %d labels), %d lights" % [geo.size(), mm, lab, story.find_children("*", "Light3D", true, false).size()])
	c.respawned.connect(_on_respawn)
	_route()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pd_bot_from="):
			var fx := float(a.substr(14))
			for m in marks:
				if float(m[1]) >= fx - 0.5:
					i = int(m[0])
					break

func sec(name: String) -> Object:
	for s in story.get("sections"):
		if String((s as Object).get_script().resource_path).ends_with("sec_%s.gd" % name):
			return s
	return null

func lp() -> Vector3:
	return story.to_local(c.global_position)

func _log(msg: String) -> void:
	print("[bot %6.1f] %s" % [t, msg])

# ------------------------------------------------------------------ the route
func go(x: float, opt := {}) -> void:
	var d := {"t": "go", "x": x}
	d.merge(opt)
	steps.append(d)

func s(kind: String, opt := {}) -> void:
	var d := {"t": kind}
	d.merge(opt)
	steps.append(d)

func mark(x: float) -> void:
	marks.append([steps.size(), x])

func _route() -> void:
	# --- the book and the guestbook
	s("until", {"f": func() -> bool: return bool(story.get("active")) and lp().y < 0.5 and c.control_enabled and c.is_on_floor(), "timeout": 15.0})
	go(5.6)
	s("tap", {"a": "interact"})
	s("until", {"f": func() -> bool: return story.get("typing_target") != null, "timeout": 3.0})
	s("type", {"text": "Rusty"})
	s("wait", {"s": 2.5})
	# --- the meadow
	go(25.0, {"jumps": [[19.1, 0.1], [21.0, 0.1]]})
	go(30.5, {"jumps": [[25.1, 0.5]], "sprint": true})
	mark(30.0)
	go(32.4, {"lane": 2})
	go(40.0, {"lane": 2})
	go(43.6, {"lane": 1})
	go(50.5, {"jumps": [[43.7, 0.1]]})
	s("until", {"f": func() -> bool: return c.is_on_floor(), "timeout": 4.0})
	go(53.0, {"lane": 2})
	go(58.4)
	s("until", {"f": func() -> bool: return c.is_on_floor(), "timeout": 4.0})
	go(59.4)
	go(61.2, {"lane": 1})
	s("until", {"f": func() -> bool: return c.is_on_floor() and lp().y < 0.5, "timeout": 4.0})
	go(73.0, {"jumps": [[60.8, 0.2], [63.1, 0.2], [65.6, 0.2], [68.1, 0.2], [70.6, 0.25]]})
	mark(74.0)
	# --- cotton clouds
	go(81.0, {"jumps": [[79.2, 0.1]]})
	go(83.6, {"jumps": [[81.6, 0.15]]})
	go(84.4, {"lane": 2})
	go(86.6, {"jumps": [[84.7, 0.15]]})
	go(89.2, {"jumps": [[87.3, 0.15]]})
	go(98.0, {"jumps": [[90.4, 6.0]], "land": true})
	mark(100.0)
	go(102.8, {"lane": 0})
	go(104.4, {"lane": 0})
	s("hop", {"lane": 2, "x": 107.2})
	s("hop", {"lane": 1, "x": 109.4})
	# keepsake 2: down to the hidden fan in the back, up to the little cloud
	s("lane", {"to": 2})
	s("until", {"f": func() -> bool: return lp().y > 10.0, "timeout": 5.0})
	go(111.0, {"hold_jump": true, "land": true, "tol": 0.5})
	go(112.6)
	go(114.4, {"jumps": [[112.7, 9.0]], "land": true})
	go(115.3)
	go(117.0, {"jumps": [[115.4, 0.2]], "lane": 1, "land": true})
	go(122.6, {"jumps": [[119.2, 0.4]], "land": true})
	go(129.0, {"jumps": [[123.7, 4.0]], "land": true})
	# --- patches
	mark(132.5)
	go(137.6)
	s("tap", {"a": "interact"})
	go(140.5)
	s("tap", {"a": "interact"})
	s("until", {"f": func() -> bool: return float(sec("patches").get("_sew_t")) < 0.0, "timeout": 6.0})
	go(145.0)
	go(147.0, {"lane": 2})
	s("tap", {"a": "interact"})
	go(149.5, {"lane": 1})
	s("tap", {"a": "interact"})
	s("until", {"f": func() -> bool: return float(sec("patches").get("_sew_t")) < 0.0, "timeout": 6.0})
	go(155.6, {"jumps": [[149.85, 0.1], [151.15, 0.1]]})
	mark(157.4)
	go(160.6, {"lane": 0})
	s("tap", {"a": "interact"})
	go(165.0, {"lane": 0})
	s("tap", {"a": "interact"})
	s("until", {"f": func() -> bool: return float(sec("patches").get("_sew_t")) < 0.0, "timeout": 6.0})
	go(162.2, {"lane": 1})
	s("tap", {"a": "interact"})
	go(164.6, {"lane": 0})
	go(166.4, {"jumps": [[164.85, 0.1]]})
	s("until", {"f": func() -> bool: return c.is_on_floor(), "timeout": 3.0})
	s("tap", {"a": "interact"})
	s("until", {"f": func() -> bool: return float(sec("patches").get("_sew_t")) < 0.0, "timeout": 6.0})
	s("lane", {"to": 1})
	s("until", {"f": func() -> bool: return c.is_on_floor() and lp().y < 0.5, "timeout": 3.0})
	go(163.8, {"lane": 2})
	s("tap", {"a": "interact"})
	go(164.6, {"lane": 0})
	go(166.4, {"jumps": [[164.85, 0.1]]})
	s("until", {"f": func() -> bool: return c.is_on_floor(), "timeout": 3.0})
	go(169.0, {"jumps": [[167.05, 0.1]]})
	s("until", {"f": func() -> bool: return c.is_on_floor(), "timeout": 3.0})
	s("tap", {"a": "interact"})
	s("until", {"f": func() -> bool: return float(sec("patches").get("_sew_t")) < 0.0, "timeout": 6.0})
	s("jump_lane", {"lane": 1})
	go(171.4, {"hold_jump": true})
	s("until", {"f": func() -> bool: return c.is_on_floor(), "timeout": 3.0})
	go(175.0, {"jumps": [[171.7, 0.3]]})
	s("until", {"f": func() -> bool: return c.is_on_floor(), "timeout": 3.0})
	go(178.6, {"lane": 2})
	s("tap", {"a": "interact"})
	s("wait", {"s": 0.5})
	go(179.0, {"lane": 1})
	# --- the sewing machine
	go(188.0)
	mark(189.0)
	s("chase")
	# --- you choose
	mark(268.0)
	go(275.0)
	go({"castle": 279.4, "river": 281.7, "cliff": 284.0}[choice])
	s("tap", {"a": "interact"})
	s("wait", {"s": 5.0})
	mark(286.4)
	match choice:
		"castle":
			go(318.5, {"jumps": [[287.4, 0.1]]})
		"river":
			s("river")
		"cliff":
			s("cliff")
	# --- the yarn tower
	go(330.0)
	mark(330.5)
	s("tower")
	go(TX + 4.0)
	s("until", {"f": func() -> bool: return c.is_on_floor(), "timeout": 3.0})
	s("tap", {"a": "interact"})
	s("until", {"f": func() -> bool: return String(sec("finale").get("phase")) != "wait", "timeout": 20.0})
	# --- the finale
	s("until", {"f": func() -> bool: return String(sec("finale").get("phase")) == "photo", "timeout": 60.0})
	s("wait", {"s": 1.5})
	s("hold", {"a": "mood", "s": 0.05})
	s("wait", {"s": 0.6})
	s("tap", {"a": "interact"})
	s("until", {"f": func() -> bool: return String(sec("finale").get("phase")) == "exits", "timeout": 60.0})
	s("wait", {"s": 2.0})
	go(383.5)
	s("tap", {"a": "interact"})
	s("wait", {"s": 3.0})
	go({"again": 372.5, "desk": 378.0}[exit_to])
	s("tap", {"a": "interact"})
	s("wait", {"s": 4.0})
	s("end")

# ------------------------------------------------------------------ running it
func _want(a: String) -> void:
	held[a] = true

func _tap_now(a: String) -> void:
	_tap[a] = 2

func _apply() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back", "jump", "sprint", "interact", "mood"]:
		var on: bool = held.get(a, false) or int(_tap.get(a, 0)) == 2
		if on and not Input.is_action_pressed(a):
			Input.action_press(a)
		elif not on and Input.is_action_pressed(a):
			Input.action_release(a)
	for k in _tap.keys():
		_tap[k] = int(_tap[k]) - 1
		if int(_tap[k]) <= 0:
			_tap.erase(k)
	held.clear()

func _next() -> void:
	i += 1
	st = 0.0
	_jumped.clear()

func _physics_process(delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(story):
		# "play it again": a fresh world
		story = lvl.get("story")
		_log("the story was restarted: %s, Claude at %s" % [str(story.get("active")), str(lp())])
		_done = true
		get_tree().create_timer(2.0).timeout.connect(get_tree().quit)
		return
	t += delta
	if t > 1500.0:
		_log("GAVE UP at step %d" % i)
		_done = true
		get_tree().quit()
		return
	st += delta
	_log_t -= delta
	var p := lp()
	if _log_t <= 0.0:
		_log_t = 2.0
		var fin: Object = sec("finale")
		var pa: Object = sec("patches")
		if OS.get_cmdline_user_args().has("--pd_bot_debug"):
			_log("control %s auto %s v %s" % [str(c.control_enabled), str(c.auto_target), str(c.velocity)])
		_log("step %d %s  pos (%.1f, %.1f, %.1f) lane %d  spools %d  deaths %d  %s  carry %s sew %.1f  keep %s" % [i, steps[mini(i, steps.size() - 1)].t, p.x, p.y, p.z,
			int(story.get("lane")), int(story.get("spools")), int(story.get("deaths")), String(fin.get("phase")) if fin else "",
			str(not (pa.get("carried") as Dictionary).is_empty()), float(pa.get("_sew_t")), str(story.get("keepsakes"))])
		if absf(p.x - stuck_x) < 0.2 and steps[mini(i, steps.size() - 1)].t == "go":
			stuck_t += 2.0
			if stuck_t >= 10.0:
				_log("STUCK at %.1f, %.1f, %.1f (step %d)" % [p.x, p.y, p.z, i])
				stuck_t = 0.0
				_next()
		else:
			stuck_t = 0.0
		stuck_x = p.x
	if i >= steps.size():
		_apply()
		return
	var stp: Dictionary = steps[i]
	match String(stp.t):
		"go":
			_go(stp, p)
		"wait":
			if st >= float(stp.s):
				_next()
		"tap":
			_tap_now(stp.a)
			_next()
		"hold":
			_want(stp.a)
			if st >= float(stp.s):
				_next()
		"until":
			var f: Callable = stp.f
			if f.call():
				_next()
			elif st > float(stp.get("timeout", 10.0)):
				_log("TIMEOUT waiting (step %d)" % i)
				_next()
		"lane":
			if int(story.get("lane")) != int(stp.to):
				if int(st * 60.0) % 8 == 0:
					_tap_now("move_forward" if int(stp.to) > int(story.get("lane")) else "move_back")
			else:
				_next()
			if st > 3.0:
				_log("could not change lane (step %d)" % i)
				_next()
		"hop":
			# jump, change layer in the air, land at x
			if st < 0.02:
				_tap_now("jump")
			if st < 0.25:
				_want("jump")
			if st > 0.12 and int(story.get("lane")) != int(stp.lane) and int(st * 60.0) % 4 == 0:
				_tap_now("move_forward" if int(stp.lane) > int(story.get("lane")) else "move_back")
			var hx: float = stp.x
			if absf(hx - p.x) > 0.2:
				_want("move_right" if hx > p.x else "move_left")
			if st > 0.3 and c.is_on_floor():
				_next()
			elif st > 4.0:
				_log("hop failed (step %d)" % i)
				_next()
		"jump_lane":
			_tap_now("jump")
			_tap_now("move_forward" if int(stp.lane) > int(story.get("lane")) else "move_back")
			_want("jump")
			_next()
		"type":
			# one letter every 0.18 s, like a person typing
			var txt := String(stp.text)
			var n := int(st / 0.18)
			var typed: int = stp.get("typed", 0)
			while typed < mini(n, txt.length()):
				_type_key(txt[typed])
				typed += 1
			stp["typed"] = typed
			if typed >= txt.length() and st > 0.18 * txt.length() + 0.5:
				_type_key("\n")
				_next()
		"chase":
			_chase(p)
		"tower":
			_tower(p)
		"river":
			_river(p)
		"cliff":
			_cliff(p)
		"end":
			_log("END  spools %d / %d  deaths %d  keepsakes %s  score %d  completed %s" % [int(story.get("spools")),
				(story.get("spool_pos") as Array).size(), int(story.get("deaths")), str(story.get("keepsakes")),
				int(sec("finale").get("score")), str(GameState.completed.get("plush_desk", false))])
			_done = true
			get_tree().quit()
	_apply()

func _go(stp: Dictionary, p: Vector3) -> void:
	var x: float = stp.x
	if stp.has("lane") and int(story.get("lane")) != int(stp.lane) and int(st * 60.0) % 8 == 0:
		_tap_now("move_forward" if int(stp.lane) > int(story.get("lane")) else "move_back")
	var dx := x - p.x
	var tol: float = stp.get("tol", 0.25)
	if stp.get("sprint", false):
		_want("sprint")
	if stp.get("hold_jump", false):
		_want("jump")
	for j in stp.get("jumps", []):
		var jx: float = j[0]
		var key := "%.2f" % jx
		if not _jumped.has(key) and ((dx > 0.0 and p.x >= jx) or (dx < 0.0 and p.x <= jx)):
			_jumped[key] = st
			_tap_now("jump")
		if _jumped.has(key) and st - float(_jumped[key]) < float(j[1]):
			_want("jump")
	if absf(dx) < tol and (not stp.has("lane") or int(story.get("lane")) == int(stp.lane)):
		if stp.get("land", false) and not c.is_on_floor():
			if stp.get("hold_jump", false) or _jump_holding(stp):
				_want("jump")
			return
		_next()
		return
	_want("move_right" if dx > 0.0 else "move_left")
	# walked into something: hop
	if c.is_on_floor() and absf(c.velocity.x) < 0.3 and absf(dx) > 0.5:
		_blocked += get_physics_process_delta_time()
		if _blocked > 0.3:
			_blocked = 0.0
			_tap_now("jump")
			_log("hop at %.1f" % p.x)
	else:
		_blocked = 0.0

func _jump_holding(stp: Dictionary) -> bool:
	for j in stp.get("jumps", []):
		var key := "%.2f" % float(j[0])
		if _jumped.has(key) and st - float(_jumped[key]) < float(j[1]):
			return true
	return false

func _type_key(ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	if ch == "\n":
		ev.keycode = KEY_ENTER
	else:
		ev.unicode = ch.unicode_at(0)
		ev.keycode = OS.find_keycode_from_string(ch.to_upper())
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)

func _type(text: String) -> void:
	for ch in text:
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = ch.unicode_at(0)
		ev.keycode = OS.find_keycode_from_string(ch.to_upper())
		Input.parse_input_event(ev)
		var up := ev.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
	var en := InputEventKey.new()
	en.pressed = true
	en.keycode = KEY_ENTER
	Input.parse_input_event(en)
	var en_up := en.duplicate() as InputEventKey
	en_up.pressed = false
	Input.parse_input_event(en_up)

## the sewing machine chase: sprint, keep out of the pins' layers, hop the
## gaps between the tables and the rolling spools
func _chase(p: Vector3) -> void:
	var m: Object = sec("machine")
	if bool(m.get("stopped")):
		_next()
		return
	_want("sprint")
	_want("move_right")
	var rows := [[201.0, 2], [212.5, 0], [218.0, 2], [225.5, 0], [238.0, 1], [243.5, 2], [258.0, 0]]
	var want_lane := int(story.get("lane"))
	for r in rows:
		if p.x < float(r[0]) + 0.5 and p.x > float(r[0]) - 5.0:
			want_lane = int(r[1])
			break
	if want_lane != int(story.get("lane")) and int(st * 60.0) % 6 == 0:
		_tap_now("move_forward" if want_lane > int(story.get("lane")) else "move_back")
	for gx in [206.6, 230.7, 251.7]:
		if p.x > gx and p.x < gx + 0.5 and c.is_on_floor():
			_tap_now("jump")
			_want("jump")
	for r in m.get("rollers"):
		if r.on and int(r.lane) == int(story.get("lane")):
			var ahead: float = float(r.x) - p.x
			if ahead > 0.4 and ahead < 2.3 and c.is_on_floor():
				_tap_now("jump")
	if p.x > 264.2 and int(st * 60.0) % 10 == 0:
		_tap_now("interact")

## up the yarn tower: run, hop the gaps, the pom-pom and the needles
func _tower(p: Vector3) -> void:
	var tw: Object = sec("tower")
	var on: bool = tw.get("on_tower")
	var th: float = tw.get("theta")
	var u := th / TAU
	if OS.get_cmdline_user_args().has("--pd_bot_debug") and int(st * 60.0) % 15 == 0:
		_log("tower on %s u %.3f p %s v %s floor %s yaw %.2f input %.2f" % [str(on), u, str(p), str(c.velocity), str(c.is_on_floor()), c.yaw, float(story.get("input_yaw"))])
		for k in c.get_slide_collision_count():
			var col := c.get_slide_collision(k)
			var cn := col.get_collider() as Node
			_log("   hit %s (%s) n %s at %s" % [cn.name, cn.get_parent().name, str(col.get_normal()), str(story.to_local(col.get_position()))])
	if not on and p.x > TX + 1.0 and p.y > 11.0:
		_next()
		return
	var go_on := true
	var jump := false
	if on:
		for gu in [0.293, 0.632, 1.352, 1.432, 1.49]:
			if u > gu and u < gu + 0.02:
				jump = true
		# glide after the pom-pom throws us up
		if u > 1.06 and u < 1.22 and not c.is_on_floor():
			_want("jump")
		for nd in tw.get("needles"):
			var arc := (float(nd.u) - u) * TAU * 3.25
			var k: float = nd.k
			var ph := fmod(float(story.get("t")) + float(nd.phase), float(nd.period)) / float(nd.period)
			if arc > 0.0 and arc < 1.4:
				if nd.high:
					# wait until it has slid back in and will stay in
					if not (ph > 0.2 + float(nd.out) + 0.12 or ph < 0.03):
						if arc < 1.0:
							go_on = false
				else:
					if (k > 0.2 or ph < 0.2) and arc < 1.15 and arc > 0.6 and c.is_on_floor():
						jump = true
					elif k > 0.05 and arc <= 0.6 and c.is_on_floor():
						jump = true
	if go_on and on and c.is_on_floor() and c.velocity.length() < 0.5:
		_blocked += get_physics_process_delta_time()
		if _blocked > 0.25:
			_blocked = 0.0
			jump = true
	if jump and c.is_on_floor():
		_tap_now("jump")
	if go_on:
		_want("move_right")

func _river(p: Vector3) -> void:
	if p.x > 318.5:
		_next()
		return
	if OS.get_cmdline_user_args().has("--pd_bot_debug") and c.velocity.y > 7.5:
		_log("FAST UP v %s at %s floor %s" % [str(c.velocity), str(p), str(c.is_on_floor())])
		for k in c.get_slide_collision_count():
			var col := c.get_slide_collision(k)
			_log("   hit %s / %s" % [(col.get_collider() as Node).name, (col.get_collider() as Node).get_parent().name])
	_want("move_right")
	var ch: Object = sec("choice")
	# hop from leaf to leaf: jump when the next leaf is in reach
	if c.is_on_floor():
		for l in ch.get("leaves"):
			var body: Node3D = l[0]
			var dx := body.position.x - p.x
			if dx > 1.2 and dx < 3.2:
				var ln := 0
				for k in 3:
					if absf(body.position.z - float(story.call("lane_z", k))) < 0.3:
						ln = k
				if ln != int(story.get("lane")):
					_tap_now("move_forward" if ln > int(story.get("lane")) else "move_back")
				_tap_now("jump")
				_want("jump")
				break
		if p.x > 315.0:
			_tap_now("jump")

func _cliff(p: Vector3) -> void:
	if p.x > 318.5:
		_next()
		return
	var ch: Object = sec("choice")
	var gust: bool = ch.get("_gust_on")
	_want("move_right")
	if gust and c.is_on_floor() and p.x > 290.0:
		held.erase("move_right")
	if c.is_on_floor() and absf(c.velocity.x) < 0.3 and not gust:
		_blocked += get_physics_process_delta_time()
		if _blocked > 0.3:
			_blocked = 0.0
			_tap_now("jump")
	for jx in [287.5, 292.9, 296.9, 300.9, 304.9, 309.6]:
		if p.x > jx and p.x < jx + 0.4 and c.is_on_floor():
			_tap_now("jump")
	if p.x > 309.5 and p.x < 313.0:
		_want("jump")

func _on_respawn() -> void:
	var p := lp()
	_log("RESPAWN at (%.1f, %.1f, %.1f), deaths now %d" % [p.x, p.y, p.z, int(story.get("deaths"))])
	# go back to the last mark at or before where we came back
	var best := -1
	for m in marks:
		if float(m[1]) <= p.x + 0.5 and int(m[0]) <= i:
			best = int(m[0])
	if best >= 0:
		i = best
		st = 0.0
		_jumped.clear()
