## The smallest possible gallery level – copy this folder to start your own.
## (See CLAUDE.md in the project root for the rules.)
##
## Your root script extends DreamLevel and overrides build(). Everything you
## need is created in code here; you can just as well build the scene in the
## Godot editor and only spawn Claude from build().
extends DreamLevel

const GOAL_POS := Vector3(0, 3.2, -9)

var goal: Node3D
var _t := 0.0

func build() -> void:
	_environment()
	_island()
	_goal()
	# Claude: the shared player character (walk, run, jump, glide, camera)
	var c := spawn_claude(Vector3(0, 0.5, 6), 0.0)
	c.step_kind = "grass"         # footstep sounds: "grass", "stone" or "wood"
	# music: any .ogg inside your folder loops (or a built-in name like "garden")
	Sound.music("garden", 1.0)
	hint("WASD laufen · Leertaste springen · berühre den Stern", 6.0)
	say("A tiny island … and a star. Let's go!", 3.0)

func _process(delta: float) -> void:
	_t += delta
	if goal == null or claude == null: return
	goal.rotation.y = _t * 1.5
	goal.position.y = GOAL_POS.y + sin(_t * 2.0) * 0.15
	if goal.global_position.distance_to(claude.global_position + Vector3(0, 0.8, 0)) < 1.6:
		goal.queue_free()
		goal = null
		Sound.sfx("orb", -2.0)
		say("Got it!", 2.0)
		complete(2.5)   # marks the painting with a star and returns to the attic

func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.45, 0.85)
	sm.sky_horizon_color = Color(0.95, 0.75, 0.80)
	sm.ground_horizon_color = Color(0.95, 0.75, 0.80)
	sm.ground_bottom_color = Color(0.45, 0.40, 0.70)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.95, 0.85)
	add_child(sun)

func _island() -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.40, 0.75, 0.35)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.62, 0.48, 0.42)
	# the ground: a flat disc on top of a cone of rock
	var top := CylinderMesh.new()
	top.top_radius = 8.0; top.bottom_radius = 7.6; top.height = 1.0
	_solid(top, Vector3(0, -0.5, 0), grass)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 7.6; cm.bottom_radius = 0.5; cm.height = 9.0
	cone.mesh = cm
	cone.material_override = rock
	cone.position.y = -5.5
	add_child(cone)
	# two steps up to the star
	var step1 := BoxMesh.new(); step1.size = Vector3(3, 1.2, 3)
	_solid(step1, Vector3(0, 0.6, -4), rock)
	var step2 := BoxMesh.new(); step2.size = Vector3(3, 2.4, 3)
	_solid(step2, Vector3(0, 1.2, -9), rock)

## A static mesh you can stand on (collision shape made from the mesh).
func _solid(mesh: PrimitiveMesh, pos: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_convex_shape()
	body.add_child(cs)
	add_child(body)

func _goal() -> void:
	goal = Node3D.new()
	goal.position = GOAL_POS
	add_child(goal)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new(); s.radius = 0.45; s.height = 0.9
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.75, 0.25)
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	goal.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.omni_range = 5.0
	goal.add_child(light)
