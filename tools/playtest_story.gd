## Headless run through the whole opening: intro, flower, pool, channel, flight.
extends Node

var main: Node
var t := 0.0
var phase := 0
var last_state := -1
var ph_t := 0.0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)

func _press(a: String) -> void:
	Input.action_press(a)
	get_tree().create_timer(0.1).timeout.connect(func(): Input.action_release(a))

func _process(delta: float) -> void:
	if main == null or main.get("director") == null: return
	var d: Director = main.director
	if d == null: return
	t += delta
	ph_t += delta
	if d.state != last_state:
		print("t=%.1f state=%s pos=%s found=%d" % [t, Director.S.keys()[d.state], str(main.player.global_position.snapped(Vector3(0.1, 0.1, 0.1))), d.found])
		last_state = d.state
	var p: Player = main.player
	match phase:
		0:
			if d.state == Director.S.FREE:
				phase = 1; ph_t = 0.0
				p.teleport(Transform3D(Basis(), Director.FLOWER_POS + Vector3(-1.0, 0.3, 0.5)))
		1:
			if ph_t > 0.5 and ph_t < 0.6: _press("interact")
			if ph_t > 1.0 and d.state == Director.S.FREE:
				print("  butterfly landed=", d.butterfly.landed if d.butterfly else "none")
				phase = 2; ph_t = 0.0
				p.teleport(Transform3D(Basis(), Director.POOL_APPROACH + Vector3(1.0, 0.3, -1.0)))
		2:
			if ph_t > 0.5 and ph_t < 0.6: _press("interact")
			if ph_t > 1.0 and d.state == Director.S.FREE:
				print("  robot on rim at ", p.global_position.snapped(Vector3(0.01, 0.01, 0.01)), " beacon=", d.beacon.visible)
				phase = 3; ph_t = 0.0
				p.teleport(Transform3D(Basis(), main.WATERFALL_START))
				p.yaw = 0.0
		3:
			Input.action_press("move_forward"); Input.action_press("sprint")
			if d.state != Director.S.FREE:
				Input.action_release("move_forward"); Input.action_release("sprint")
				phase = 4
		4:
			if int(t * 2.0) % 6 == 0 and d.state == Director.S.FLIGHT and ph_t > 2.0:
				ph_t = 0.0
				print("   flight s=%.0f/%.0f pos=%s found=%d" % [d.flight.s, d.flight.length, str(p.global_position.snapped(Vector3(1, 1, 1))), d.found])
			if d.state == Director.S.END:
				print("END at t=%.1f found %d/%d" % [t, d.found, d.total])
				get_tree().quit()
	if t > 200.0:
		print("TIMEOUT"); get_tree().quit()
