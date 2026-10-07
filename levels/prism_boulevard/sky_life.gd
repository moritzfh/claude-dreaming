## Prism Boulevard – things that move in the sky: a whale made of stars that
## swims in a slow circle around the course, and comets now and then.
extends Node3D

const LINE := preload("res://levels/prism_boulevard/shaders/star_line.gdshader")
const SPARKLE := preload("res://levels/prism_boulevard/shaders/sparkle.gdshader")
const COMET := preload("res://levels/prism_boulevard/shaders/comet.gdshader")

## the whale's outline in its own plane: x = 0 nose … 1 tail tip, y up
const WHALE := [
	Vector2(0.00, 0.02), Vector2(0.04, 0.11), Vector2(0.13, 0.17), Vector2(0.27, 0.19),
	Vector2(0.42, 0.17), Vector2(0.57, 0.12), Vector2(0.70, 0.07), Vector2(0.80, 0.04),
	Vector2(0.88, 0.03), Vector2(0.95, 0.12), Vector2(1.00, 0.17),       # upper fluke
	Vector2(0.97, 0.03), Vector2(1.00, -0.08), Vector2(0.93, -0.03),     # lower fluke
	Vector2(0.86, -0.02), Vector2(0.72, -0.03), Vector2(0.55, -0.07), Vector2(0.38, -0.12),
	Vector2(0.20, -0.12), Vector2(0.07, -0.08), Vector2(0.00, 0.02),
]
const FIN := [Vector2(0.24, -0.11), Vector2(0.33, -0.25), Vector2(0.36, -0.12)]
const EYE := Vector2(0.09, 0.04)
const LENGTH := 430.0

var center := Vector3(300, 60, 150)
var radius := 820.0
var t := 0.0
var whale: Node3D
var lines: MeshInstance3D
var im: ImmediateMesh
var stars: MultiMesh
var comets: Array = []          # {node, mat, from, to, dur, t}
var _comet_wait := 4.0

func _ready() -> void:
	whale = Node3D.new()
	add_child(whale)
	im = ImmediateMesh.new()
	lines = MeshInstance3D.new()
	lines.mesh = im
	var lm := ShaderMaterial.new()
	lm.shader = LINE
	lines.material_override = lm
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lines.extra_cull_margin = 400.0
	whale.add_child(lines)
	stars = MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.use_custom_data = true
	stars.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var sm := ShaderMaterial.new()
	sm.shader = SPARKLE
	sm.set_shader_parameter("energy", 5.0)
	sm.set_shader_parameter("color", Color(0.85, 0.92, 1.0))
	q.material = sm
	stars.mesh = q
	stars.instance_count = WHALE.size() + FIN.size() + 1
	for i in stars.instance_count:
		stars.set_instance_custom_data(i, Color(randf(), randf(), 0.6, 0))
		stars.set_instance_color(i, Color(1, 1, 1))
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = stars
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.extra_cull_margin = 400.0
	whale.add_child(smi)
	for i in 2:
		var cm := MeshInstance3D.new()
		var cq := QuadMesh.new()
		cq.size = Vector2(1, 1)
		cm.mesh = cq
		var mat := ShaderMaterial.new()
		mat.shader = COMET
		cm.material_override = mat
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cm.extra_cull_margin = 3000.0
		cm.visible = false
		add_child(cm)
		comets.append({"node": cm, "mat": mat, "t": -1.0})

func _shape(p: Vector2) -> Vector3:
	# the tail beats up and down, the body follows a little
	var wave := sin(t * 1.1 - p.x * 3.2) * 0.07 * smoothstep(0.35, 1.0, p.x)
	return Vector3(0, (p.y + wave) * LENGTH, p.x * LENGTH)

func _process(delta: float) -> void:
	t += delta
	# swim: a slow circle, gently rising and sinking
	var a := t * 0.012 + 2.2
	var pos := center + Vector3(cos(a) * radius, 40.0 + sin(t * 0.21) * 25.0, sin(a) * radius)
	var tangent := Vector3(-sin(a), 0.0, cos(a))
	whale.global_transform = Transform3D(Basis.looking_at(tangent, Vector3.UP), pos)
	whale.rotate_object_local(Vector3.RIGHT, sin(t * 0.21 + 1.0) * 0.08)
	# lines (ribbons in the whale's plane) and stars
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var total := WHALE.size() - 1
	for i in total:
		_ribbon(_shape(WHALE[i]), _shape(WHALE[i + 1]), float(i) / total, float(i + 1) / total, 5.0)
	for i in FIN.size() - 1:
		_ribbon(_shape(FIN[i]), _shape(FIN[i + 1]), 0.3, 0.35, 4.0)
	im.surface_end()
	var k := 0
	for p in WHALE:
		stars.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * (26.0 if k % 3 == 0 else 16.0)), _shape(p)))
		k += 1
	for p in FIN:
		stars.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * 18.0), _shape(p)))
		k += 1
	stars.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ONE * 32.0), _shape(EYE)))
	_comets(delta)

func _ribbon(a: Vector3, b: Vector3, u0: float, u1: float, w: float) -> void:
	var d := (b - a).normalized()
	var side := Vector3(1, 0, 0).cross(d).normalized() * w * 0.5   # in the whale's plane (x is its normal)
	for v in [[a - side, u0, 0.0], [b - side, u1, 0.0], [b + side, u1, 1.0], [a - side, u0, 0.0], [b + side, u1, 1.0], [a + side, u0, 1.0]]:
		im.surface_set_uv(Vector2(v[1], v[2]))
		im.surface_set_color(Color(1, 1, 1, 1))
		im.surface_add_vertex(v[0])

func _comets(dt: float) -> void:
	_comet_wait -= dt
	for c in comets:
		var node: MeshInstance3D = c["node"]
		if float(c["t"]) >= 0.0:
			c["t"] = float(c["t"]) + dt
			var u: float = float(c["t"]) / float(c["dur"])
			if u >= 1.0:
				c["t"] = -1.0
				node.visible = false
				continue
			var from: Vector3 = c["from"]
			var to: Vector3 = c["to"]
			var p := from.lerp(to, u)
			var dir := (to - from).normalized()
			var cam := get_viewport().get_camera_3d()
			var view := (cam.global_position - p).normalized() if cam else Vector3.UP
			var up := view.cross(dir).normalized()
			var len := 260.0
			node.global_transform = Transform3D(Basis(dir * len, up * 9.0, dir.cross(up)), p - dir * len * 0.5)
			(c["mat"] as ShaderMaterial).set_shader_parameter("alpha", sin(u * PI))
		elif _comet_wait <= 0.0:
			_comet_wait = randf_range(5.0, 11.0)
			var d0 := Vector3(randf_range(-1, 1), randf_range(0.25, 0.7), randf_range(-1, 1)).normalized()
			var d1 := (d0 + Vector3(randf_range(-0.6, 0.6), randf_range(-0.35, -0.1), randf_range(-0.6, 0.6))).normalized()
			c["from"] = center + d0 * 1900.0
			c["to"] = center + d1 * 1900.0
			c["dur"] = randf_range(2.2, 3.5)
			c["t"] = 0.0
			node.visible = true
			(c["mat"] as ShaderMaterial).set_shader_parameter("tail", [Color(0.5, 0.75, 1.0), Color(1.0, 0.6, 0.85), Color(0.7, 1.0, 0.8)][randi() % 3])
