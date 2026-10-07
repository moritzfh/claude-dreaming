## Walk from the lawn up the ramp onto the channel wall and sprint to the end.
extends Node
var main: Node
var t := 0.0
var lg := 0.0
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(delta: float) -> void:
	if main == null or main.get("player") == null or main.player == null: return
	var p: Player = main.player
	t += delta; lg += delta
	if t < 0.2:
		p.teleport(Transform3D(Basis(), Vector3(Garden.CHANNEL_X + 1.75, Terrain.PLATEAU_Y + 0.3, -7.0)))
		p.yaw = 0.0
		return
	Input.action_press("move_forward"); Input.action_press("sprint")
	if lg > 0.5:
		lg = 0.0
		print("t=%.1f pos=%s vel=%s floor=%s" % [t, str(p.global_position.snapped(Vector3(0.01, 0.01, 0.01))), str(p.velocity.snapped(Vector3(0.1, 0.1, 0.1))), p.is_on_floor()])
	if t > 10.0 or p.global_position.y < Terrain.PLATEAU_Y - 3.0:
		print("final ", p.global_position); get_tree().quit()
