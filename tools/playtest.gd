## Headless play test: drives the player with simulated input and prints positions.
extends Node

var main: Node
var t := 0.0
var step := 0
var log_t := 0.0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)

func _physics_process(delta: float) -> void:
	if main == null or main.get("player") == null: return
	var p: Player = main.player
	t += delta
	log_t += delta
	match step:
		0:
			Input.action_press("move_forward")
			if t > 3.0: step = 1; Input.action_press("jump")
		1:
			if t > 3.1: Input.action_release("jump")
			if t > 4.5:
				Input.action_release("move_forward")
				step = 2
				p.teleport(Transform3D(Basis(), main.WATERFALL_START))
				print("--- teleported to channel")
		2:
			Input.action_press("move_forward")
			Input.action_press("sprint")
			if t > 14.0: step = 3; Input.action_release("move_forward"); Input.action_release("sprint")
		3:
			if t > 17.0:
				print("done"); get_tree().quit()
	if log_t > 0.5:
		log_t = 0.0
		print("t=%.1f pos=%s floor=%s vel=%s" % [t, str(p.global_position.snapped(Vector3(0.01, 0.01, 0.01))), p.is_on_floor(), str(p.velocity.snapped(Vector3(0.1, 0.1, 0.1)))])
