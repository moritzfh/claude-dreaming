## Turns the normal robot rig into cardboard Claude: swaps every part's mesh
## for its cardboard version (models/cardboard.glb, same local spaces) and
## puts a marker-drawn face on the screen. The rig's animation is untouched.
extends RefCounted

const CB_SCENE := preload("res://levels/plush_desk/models/cardboard.glb")
const SHADER := preload("res://levels/plush_desk/shaders/cardboard.gdshader")
const FACE := preload("res://levels/plush_desk/shaders/marker_face.gdshader")
const T_KRAFT := preload("res://levels/plush_desk/textures/kraft.png")
const T_MOTTLE := preload("res://levels/plush_desk/textures/mottle.png")

const KINDS := {"kraft": 0, "flute": 1, "tape": 2, "tube": 3, "tubein": 4, "paper": 5,
	"straw": 6, "brass": 7, "steel": 8, "yellow": 9}
## robot parts without a cardboard version are hidden
const HIDE := ["ArmLCuff", "ArmRCuff", "Emblem", "Bezel", "AntBase"]

static var _mats := {}

static func material(kind_name: String) -> ShaderMaterial:
	if _mats.has(kind_name):
		return _mats[kind_name]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("kind", KINDS.get(kind_name, 0))
	m.set_shader_parameter("kraft_tex", T_KRAFT)
	m.set_shader_parameter("mottle_tex", T_MOTTLE)
	_mats[kind_name] = m
	return m

static func meshes() -> Dictionary:
	var out := {}
	var inst := CB_SCENE.instantiate()
	for mi in inst.find_children("CB_*", "MeshInstance3D", true, false):
		out[String(mi.name).substr(3)] = (mi as MeshInstance3D).mesh
	inst.free()
	return out

static func apply_surfaces(mi: MeshInstance3D, override := {}) -> void:
	var mesh := mi.mesh
	for i in mesh.get_surface_count():
		var src := mesh.surface_get_material(i)
		var nm := src.resource_name if src else "kraft"
		mi.set_surface_override_material(i, override.get(nm, material(nm)))

## returns the marker face material (also set as rig.face_mat)
static func apply(rig: Node3D) -> ShaderMaterial:
	var cb := meshes()
	var model := rig.get_node("Model")
	var belly := material("paper").duplicate() as ShaderMaterial
	belly.set_shader_parameter("emblem", 1.0)
	var face := ShaderMaterial.new()
	face.shader = FACE
	face.set_shader_parameter("mottle_tex", T_MOTTLE)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		mi.material_override = null
		if cb.has(nm):
			mi.mesh = cb[nm]
			if nm == "Screen":
				mi.material_override = face
			elif nm == "Belly":
				apply_surfaces(mi, {"paper": belly})
			else:
				apply_surfaces(mi)
		elif nm in HIDE:
			mi.mesh = null
	rig.set("face_mat", face)
	face.set_shader_parameter("mood", rig.get("mood"))
	return face

## the USB stick, hinge at the origin, pointing up (+Y)
static func usb_stick() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "USB"
	mi.mesh = meshes()["USB"]
	apply_surfaces(mi)
	return mi
