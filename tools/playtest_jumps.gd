## Measures Claude's jumps in Stardust: single, double, and the triple chain.
## Run: godot --headless --path . --fixed-fps 60 res://scenes/playtest_jumps.tscn
extends Node

var lvl: Node
var t := 0.0
var phase := 0
var base_y := 0.0
var max_y := -INF
var log_heights: Array = []
var presses := 0
var landed_count := 0
var was_floor := true
var rising := false
var _last_chain := -1
const DEBUG := false
var press_t := 0.0
var respawns := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup.call_deferred()

func _setup() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	get_tree().change_scene_to_file("res://levels/stardust/stardust.tscn")

func _tap() -> void:
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")

func _physics_process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not ("claude" in scene) or scene.claude == null: return
	var c: Player = scene.claude
	t += delta
	if t < 6.0: return
	var y := c.global_position.y
	max_y = maxf(max_y, y)
	if c._chain != _last_chain:
		print("  jump level %d at t=%.2f" % [c._chain, t]); _last_chain = c._chain
	match phase:
		0:
			base_y = y; max_y = y; _tap(); phase = 1; t = 6.0
		1:
			if t > 7.8 and c.is_on_floor():
				print("single jump height: %.2f" % (max_y - base_y)); max_y = y; phase = 2; t = 6.0; _tap()
		2:
			if t > 6.25 and presses == 0: presses = 1; _tap()   # second press in the air
			if t > 8.0 and c.is_on_floor():
				print("double jump height: %.2f" % (max_y - base_y)); max_y = y; phase = 3; t = 6.0; presses = 0
				# a big flat test floor far above the level
				var body := StaticBody3D.new()
				var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(300, 1, 300); cs.shape = bx
				body.add_child(cs); scene.add_child(body); body.global_position = Vector3(0, 499.5, 0)
				c.teleport(Transform3D(Basis(), Vector3(0, 500.2, 0)))
		3:
			# run forward and chain three jumps, pressing just before each landing
			Input.action_press("move_right")   # across the island
			if t > 7.0 and presses == 0:
				presses = 1; base_y = y; max_y = y; _tap()
			if c.velocity.y > 2.0: rising = true
			if presses > 0 and presses < 3 and rising and c.velocity.y < -1.0 and not c.is_on_floor():
				var q := PhysicsRayQueryParameters3D.create(c.global_position, c.global_position - Vector3(0, 0.3, 0))
				q.exclude = [c.get_rid()]
				if not c.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					log_heights.append(max_y - base_y); max_y = y; base_y = y
					presses += 1; rising = false; press_t = t; _tap()
			if presses >= 2 and DEBUG:
				print("   t=%.2f p=%d buf=%.2f coy=%.2f landed=%.2f floor=%s vy=%.2f chain=%d" % [t, presses, c._jump_buf, c._coyote, c._landed_t, c.is_on_floor(), c.velocity.y, c._chain])
			if presses == 3 and c.is_on_floor() and t > press_t + 0.5:
				log_heights.append(max_y - base_y)
				print("chain heights: ", log_heights, "  last chain level: ", c._chain, " flip done: ", c._flip_t)
				Input.action_release("move_right")
				# fall into the void next to the start island
				c.respawned.connect(func(): respawns += 1)
				c.teleport(Transform3D(Basis(), Vector3(0, 2, 30)))
				phase = 4; t = 6.0
		4:
			if t > 11.0:
				print("fell off: respawns=%d pos=%s control=%s" % [respawns, c.global_position, c.control_enabled])
				get_tree().quit()
	if t > 20.0 and phase < 4:
		print("timeout in phase ", phase); get_tree().quit()
