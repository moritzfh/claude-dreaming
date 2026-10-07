## Visual robot: loads the Blender model, drives the LED face and all procedural animation.
class_name RobotRig
extends Node3D

const MODEL := preload("res://assets/models/robot.glb")
const FACE_SHADER := preload("res://shaders/robot_face.gdshader")

enum Mood { NORMAL, SPARKLE, DETERMINED, HAPPY, CLOSED }

var mood: int = Mood.NORMAL:
	set(v):
		mood = v
		if face_mat: face_mat.set_shader_parameter("mood", v)

var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var antenna: Node3D
var face_mat: ShaderMaterial

var _base := {}
var _phase := 0.0
var _t := 0.0
var _blink_timer := 2.5
var _blink := 0.0
var _ant := Vector2.ZERO
var _ant_v := Vector2.ZERO
var _prev_vel := Vector3.ZERO
var _air := 0.0
var _move_amt := 0.0

## extra rotations for cutscenes (sniffing, looking up …)
var head_extra := Vector3.ZERO
var body_extra := Vector3.ZERO
## 0 = normal, 1 = superman flight pose
var flight := 0.0
var foot_l: Node3D
var foot_r: Node3D

func _ready() -> void:
	var model := MODEL.instantiate()
	model.name = "Model"
	add_child(model)
	body = model.find_child("Body", true, false)
	head = model.find_child("Head", true, false)
	arm_l = model.find_child("ArmL", true, false)
	arm_r = model.find_child("ArmR", true, false)
	leg_l = model.find_child("LegL", true, false)
	leg_r = model.find_child("LegR", true, false)
	antenna = model.find_child("Antenna", true, false)
	foot_l = model.find_child("LegLFoot", true, false)
	foot_r = model.find_child("LegRFoot", true, false)
	for n in [body, head, arm_l, arm_r, leg_l, leg_r, antenna]:
		if n: _base[n] = n.transform
	var screen := model.find_child("Screen", true, false) as MeshInstance3D
	face_mat = ShaderMaterial.new()
	face_mat.shader = FACE_SHADER
	if screen: screen.material_override = face_mat
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _pose(n: Node3D, rot: Vector3, offs := Vector3.ZERO) -> void:
	if n == null: return
	var b: Transform3D = _base[n]
	n.transform = Transform3D(b.basis * Basis.from_euler(rot), b.origin + offs)

## velocity in robot-local space (x right, z backward), grounded flag
func animate(delta: float, local_vel: Vector3, grounded: bool) -> void:
	_t += delta
	var hs := Vector2(local_vel.x, local_vel.z).length()
	var target_amt := clampf(hs / 3.0, 0.0, 1.6)
	_move_amt = lerpf(_move_amt, target_amt, 1.0 - exp(-10.0 * delta))
	_air = lerpf(_air, 0.0 if grounded else 1.0, 1.0 - exp(-12.0 * delta))
	_phase += delta * (4.0 + hs * 2.4) * (1.0 if hs > 0.05 else 0.0)

	var amt := minf(_move_amt, 1.2)
	var s := sin(_phase)
	var swing := s * 0.75 * amt * (1.0 - _air)
	var bob := absf(sin(_phase)) * 0.045 * amt * (1.0 - _air)
	var breathe := sin(_t * 2.2) * 0.008 * (1.0 - amt)

	var fl := flight
	var air := _air * (1.0 - fl)
	var kick := sin(_t * 14.0) * 0.08 * fl
	# legs + arms
	_pose(leg_l, Vector3(lerpf(swing + air * 0.6, -0.25 + kick, fl), 0, 0))
	_pose(leg_r, Vector3(lerpf(-swing + air * 0.3, -0.25 - kick, fl), 0, 0))
	_pose(arm_l, Vector3(lerpf(-swing * 0.9 - air * 1.6, 0.35, fl), 0, lerpf(-air * 0.5, -0.9, fl)))
	_pose(arm_r, Vector3(lerpf(swing * 0.9 - air * 1.6, 0.35, fl), 0, lerpf(air * 0.5, 0.9, fl)))
	# torso: bob, lean into motion, slight waddle
	var lean := -0.16 * amt
	_pose(body, Vector3(lean, sin(_phase) * 0.06 * amt, sin(_phase) * 0.07 * amt) + body_extra, Vector3(0, bob + breathe, 0))
	# head: counter-rotate a bit so the face stays readable, little nod per step
	_pose(head, Vector3(-lean * 0.6 + sin(_phase * 2.0) * 0.03 * amt + sin(_t * 0.9) * 0.02 * (1.0 - fl) + fl * 0.75, sin(_t * 0.6) * 0.06 * (1.0 - amt) * (1.0 - fl), -sin(_phase) * 0.04 * amt) + head_extra)

	# antenna: damped spring driven by acceleration
	var acc := (local_vel - _prev_vel) / maxf(delta, 0.0001)
	_prev_vel = local_vel
	var force := Vector2(acc.z, -acc.x) * 0.004 + Vector2(bob * 6.0, 0.0)
	_ant_v += (force - _ant * 90.0 - _ant_v * 7.0) * delta
	_ant += _ant_v * delta
	_ant = _ant.clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
	_pose(antenna, Vector3(_ant.x, 0, _ant.y))

	# blinking
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(2.0, 5.0)
		_blink = 1.0
	_blink = maxf(_blink - delta * 7.0, 0.0)
	var b := sin(_blink * PI) if _blink > 0.0 else 0.0
	if face_mat:
		face_mat.set_shader_parameter("blink", b)
