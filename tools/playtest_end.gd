## Headless run of the ending: space -> warp -> wake up -> film part 2 -> hub.
extends Node
var main: Node
var t := 0.0
var lg := 0.0
var last := ""
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(delta: float) -> void:
	if main == null or main.get("director") == null or main.director == null: return
	t += delta; lg += delta
	var d: Director = main.director
	var sp: SpaceStage = d.space
	var hub: AtticHub = main.hub
	var v = main.get("video")
	var s := "space=%s hub=%s video=%s music=%s@%.1f" % [sp.phase, hub.state, "yes" if (v != null and is_instance_valid(v)) else "no", Sound.music_name(), Sound.music_pos()]
	if t > 2.0 and t < 3.5: Input.action_press("move_forward")
	else: Input.action_release("move_forward")
	if s.split(" music")[0] != last or lg > 4.0:
		lg = 0.0
		last = s.split(" music")[0]
		print("t=%.1f %s" % [t, s])
	if hub.state == "play":
		print("HUB PLAYABLE at t=%.1f, robot at %s" % [t, hub.pos])
		get_tree().quit()
	if t > 90.0:
		print("TIMEOUT"); get_tree().quit()
