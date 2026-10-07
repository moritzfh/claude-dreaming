## Automated run through Stardust Islands: launch stars, planet gravity,
## springs, star chips, the Dream Star and the return to the hub.
## Run: godot --path . res://scenes/playtest_stardust.tscn
extends Node

var lvl: Node
var step := 0
var t := 0.0
var st := 0.0
var shots := true
var floor_frames := 0
var total_frames := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shots = DisplayServer.get_name() != "headless"
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	get_tree().change_scene_to_file("res://levels/stardust/stardust.tscn")

func _press(a: String, on: bool) -> void:
	if on: Input.action_press(a)
	else: Input.action_release(a)

func _tap(a: String) -> void:
	Input.action_press(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(a)

func _shot(name: String) -> void:
	if shots: get_viewport().get_texture().get_image().save_png("/home/claude/shots/pt_%s.png" % name)

func _log(s: String) -> void:
	print("[t=%5.1f] %s" % [t, s])

func _next() -> void:
	step += 1
	st = 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stop_after=") and step > int(a.substr(13)):
			_log("stopping after step %d" % (step - 1))
			get_tree().quit()

func _process(delta: float) -> void:
	t += delta
	st += delta
	var scene := get_tree().current_scene
	if scene == null: return
	if scene.name == "Main":
		if st > 2.0:
			_log("back in main: mode=%s hub_state=%s pos=%s completed=%s" % [scene.mode, scene.hub.state, scene.hub.pos, GameState.completed])
			_shot("hub_return")
			get_tree().quit()
		return
	lvl = scene
	var c: Player = lvl.claude
	if c == null: return
	match step:
		0:
			if st > 6.0:
				_log("spawned at %s, bits=%d" % [c.global_position, lvl.bits.size()])
				_shot("start")
				_next()
		1:
			# walk forward (towards the launch star) collecting bits
			_press("move_forward", true)
			if lvl._prompt_star != null or st > 9.0:
				_press("move_forward", false)
				_log("near launch star: %s  bits collected=%d" % [lvl._prompt_star != null, lvl.bit_count])
				_tap("jump")
				_next()
		2:
			if lvl._flying and shots:
				var k := int(st * 30.0)
				if k == 30 or k == 45 or k == 60: _shot("flight_%d" % k)
			if st > 1.0 and not lvl._flying:
				_log("landed at %s (target %s)" % [c.global_position, lvl.PATH_LAND])
				_shot("path")
				_next()
		3:
			# hop across: teleport onto the last platform, launch to the planet
			if st > 1.5:
				var ls: Dictionary = lvl.launch_stars[1]
				c.teleport(Transform3D(Basis(), (ls["node"] as Node3D).global_position + Vector3(0, -0.6, 1.2)))
				_next()
		4:
			if st > 0.8:
				_log("at launch star 2: prompt=%s" % (lvl._prompt_star != null))
				_tap("interact")
				_next()
		5:
			if st > 1.0 and not lvl._flying:
				_log("landed on planet A at %s, dist=%.2f up=%s" % [c.global_position, c.global_position.distance_to(lvl.PLANET_A), c.up()])
				_shot("planet")
				_next()
		6:
			# walk around the planet for a while: must stay on it
			_press("move_forward", true)
			total_frames += 1
			if c.is_on_floor(): floor_frames += 1
			if total_frames == 60: _shot("planet_walk_mid")
			if total_frames < 25 and not shots:
				var info := ""
				for i in c.get_slide_collision_count():
					var col := c.get_slide_collision(i)
					info += " n·up=%.3f" % col.get_normal().dot(c.up_direction)
				_log("  f%d floor=%s wall=%s ceil=%s vup=%.2f up·r=%.4f%s" % [total_frames, c.is_on_floor(), c.is_on_wall(), c.is_on_ceiling(), c.velocity.dot(c.up_direction), c.up_direction.dot((c.global_position - lvl.PLANET_A).normalized()), info])
			if int(st * 10) % 10 == 0 and st > 0.5:
				_log("  walk: dist=%.2f floor=%s vel=%.2f" % [c.global_position.distance_to(lvl.PLANET_A), c.is_on_floor(), c.velocity.length()])
			if st > 5.0:
				_press("move_forward", false)
				_log("after walking: dist=%.2f up=%s on_floor=%s (floor %d/%d frames)" % [c.global_position.distance_to(lvl.PLANET_A), c.up(), c.is_on_floor(), floor_frames, total_frames])
				_shot("planet_walk")
				_next()
		7:
			# spring to planet B
			var sp: Dictionary = lvl.springs[0]
			c.teleport(Transform3D(Basis(), (sp["node"] as Node3D).global_position + (sp["up"] as Vector3) * 1.3))
			_next()
		8:
			if absf(st - 0.7) < 0.017: _shot("spring_flight")
			if int(st * 30) % 6 == 0 and not shots:
				_log("  spring: dA=%.2f dB=%.2f v=%s vlen=%.2f floor=%s up=%s" % [c.global_position.distance_to(lvl.PLANET_A), c.global_position.distance_to(lvl.PLANET_B), c.velocity, c.velocity.length(), c.is_on_floor(), c.up()])
			if st > 3.0:
				_log("after spring: dist A=%.2f dist B=%.2f up=%s" % [c.global_position.distance_to(lvl.PLANET_A), c.global_position.distance_to(lvl.PLANET_B), c.up()])
				_shot("planet_b")
				_next()
		9:
			# collect all chips
			for ch in lvl.chips:
				if (ch as Node3D).visible:
					c.global_position = (ch as Node3D).global_position - (ch.get_meta("up") as Vector3) * 0.6
					return
			if lvl.chip_count == 5:
				_log("all chips collected")
				_next()
		10:
			if st > 4.5:
				var ls: Dictionary = lvl.launch_stars[2]
				_log("launch star 3 active=%s visible=%s" % [ls["active"], (ls["node"] as Node3D).visible])
				c.teleport(Transform3D(Basis(), (ls["node"] as Node3D).global_position))
				_next()
		11:
			if st > 0.6:
				_shot("star3")
				_tap("jump")
				_next()
		12:
			if st > 1.0 and not lvl._flying:
				_log("landed on summit at %s" % c.global_position)
				_shot("summit")
				_next()
		13:
			if st > 1.0:
				c.teleport(Transform3D(Basis(), lvl.dream_star.global_position - Vector3(0, 1.6, 0)))
				_next()
		14:
			if st > 3.0 and st < 3.1: _shot("win")
			if st > 20.0:
				_log("TIMEOUT waiting for hub")
				get_tree().quit()
