## Walks Claude through the attic: left into the gallery, back, checks
## collisions and that every interaction spot is reachable. Run with --hub.
extends Node
var main: Node
var t := 0.0
var shots := {2.5: "walk_a", 6.5: "walk_b"}
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _process(delta: float) -> void:
	if main == null or main.get("hub") == null or main.hub == null: return
	var hub: AtticHub = main.hub
	if hub.state != "play" and hub.state != "talk": return
	t += delta
	Input.action_release("move_left"); Input.action_release("move_right"); Input.action_release("move_forward"); Input.action_release("move_back")
	if t < 6.0: Input.action_press("move_left")
	elif t < 7.0: Input.action_press("move_forward")
	elif t < 9.0: Input.action_press("move_right")
	for k in shots.keys():
		if t >= float(k) and t - delta < float(k):
			get_viewport().get_texture().get_image().save_png("/home/claude/shots/%s.png" % shots[k])
			print("shot %s at %s pos=%s" % [shots[k], t, hub.pos])
	if int(t * 2.0) != int((t - delta) * 2.0):
		print("t=%.1f pos=%s near=%s" % [t, hub.pos, hub._nearest_spot()])
	if t > 9.5:
		# every spot must be walkable
		for k in AtticHub.SPOTS:
			print("spot %s walkable=%s" % [k, hub._walkable(AtticHub.SPOTS[k][0])])
		get_tree().quit()
