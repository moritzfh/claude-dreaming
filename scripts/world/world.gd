## Assembles the whole dream world.
class_name DreamWorld
extends Node3D

var terrain_info := {}
var mats := {}

## Builds everything on a worker thread while the attic is shown (the node is
## not in the scene tree yet), plus the textures the space part needs later –
## so stepping into the painting on the easel doesn't have to wait for it.
func prepare_offline() -> void:
	build()
	Tex.noise(91, 0.01, 512, 5)
	Tex.noise(92, 0.02, 512, 5)
	Tex.noise(93, 0.02, 512, 4)

func build() -> void:
	var t0 := Time.get_ticks_msec()
	Terrain.init()
	_make_materials()
	terrain_info = Terrain.build(self, mats.terrain)
	_build_water()
	Landmarks.build_mesa(self, mats.terrain, mats.fall, mats.mist)
	Landmarks.build_mountains(self, mats.terrain)
	Landmarks.build_city(self, mats.building, mats.gold, mats.roof)
	Landmarks.build_islands(self, mats.island)
	Landmarks.build_clouds(self, mats.cloud)
	Garden.build(self, mats)
	print("world built in ", Time.get_ticks_msec() - t0, " ms")

func _shader_mat(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params: m.set_shader_parameter(k, params[k])
	return m

func _make_materials() -> void:
	var na := Tex.noise(1, 0.008, 512, 5)
	var nb := Tex.noise(2, 0.03, 512, 4)
	mats.terrain = _shader_mat("res://shaders/terrain.gdshader", {"noise_a": na, "noise_b": nb, "water_y": Terrain.WATER_Y})
	mats.fall = _shader_mat("res://shaders/waterfall.gdshader", {"streaks": Tex.noise(3, 0.02, 256, 3)})
	mats.mist = _shader_mat("res://shaders/mist.gdshader")
	mats.building = _shader_mat("res://shaders/building.gdshader")
	mats.cloud = _shader_mat("res://shaders/cloud.gdshader")
	mats.island = _shader_mat("res://shaders/rock_vc.gdshader", {"noise_b": nb})
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.72, 0.30); gold.metallic = 0.7; gold.roughness = 0.35
	mats.gold = gold
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.62, 0.50, 0.62); roof.roughness = 0.8
	mats.roof = roof
	var wind := Tex.noise(41, 0.02, 256, 3)
	mats.tiles = _shader_mat("res://shaders/tiles.gdshader", {"noise_b": nb})
	var st := StandardMaterial3D.new()
	st.albedo_color = Color(0.80, 0.77, 0.84); st.roughness = 0.8
	st.albedo_texture = Tex.soft_noise(42, 0.05, 0.82, 1.0)
	st.uv1_triplanar = true; st.uv1_world_triplanar = true; st.uv1_scale = Vector3(0.15, 0.15, 0.15)
	mats.stone = st
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.22, 0.17, 0.16); soil.roughness = 1.0
	mats.soil = soil
	mats.grass_mesh = Garden.grass_clump_mesh()
	mats.grass = _shader_mat("res://shaders/grass.gdshader", {"wind_noise": wind})
	mats.foliage = _shader_mat("res://shaders/grass.gdshader", {"wind_noise": wind, "root_col": Color(0.06, 0.14, 0.10), "mid_col": Color(0.14, 0.30, 0.20), "tip_col": Color(0.30, 0.46, 0.28), "wind_strength": 0.1})
	mats.lavender = _shader_mat("res://shaders/flower.gdshader", {"wind_noise": wind, "kind": 1})
	mats.flower = _shader_mat("res://shaders/flower.gdshader", {"wind_noise": wind, "kind": 0})
	mats.blossom = _shader_mat("res://shaders/blossom.gdshader", {"wind_noise": wind})
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.20, 0.13, 0.15); bark.roughness = 0.9
	mats.bark = bark
	var rip := Tex.normal(51, 0.04, 256, 3.0)
	mats.channel_water = _shader_mat("res://shaders/stream.gdshader", {"ripple": rip, "flow": Vector2(0.0, -1.2), "ripple_scale": 0.5, "ripple_depth": 0.6})
	mats.pool_water = _shader_mat("res://shaders/stream.gdshader", {"ripple": rip, "flow": Vector2(0.05, 0.03), "ripple_scale": 0.2, "ripple_depth": 0.08, "col": Color(0.05, 0.12, 0.16)})

func _build_water() -> void:
	var mn := Terrain.NEAR_MIN
	var size := Terrain.NEAR_MAX - Terrain.NEAR_MIN
	var m := _shader_mat("res://shaders/water.gdshader", {
		"heightmap": terrain_info.htex, "hm_min": mn, "hm_size": size,
		"ripple_a": Tex.normal(31, 0.02, 512, 6.0), "ripple_b": Tex.normal(32, 0.05, 256, 4.0),
		"foam_noise": Tex.noise(33, 0.04, 256, 3), "water_y": Terrain.WATER_Y})
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 8; pm.subdivide_depth = 8
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(mn.x + size.x * 0.5, Terrain.WATER_Y, mn.y + size.y * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mats.water = m
