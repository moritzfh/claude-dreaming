## Lighting, sky, fog and post-processing — the "look" of the film.
class_name DreamEnv
extends RefCounted

static func setup(root: Node3D) -> Dictionary:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var e := Environment.new()

	# --- sky
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	nt.noise = fn
	nt.width = 512; nt.height = 512; nt.seamless = true; nt.generate_mipmaps = true
	sm.set_shader_parameter("streak_noise", nt)
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	e.background_mode = Environment.BG_SKY
	e.sky = sky

	# --- ambient: lavender sky fill so shadows go purple like in the film
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 1.0
	e.ambient_light_energy = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# --- tonemapping / grading
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.tonemap_agx_contrast = 1.35
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.3
	e.adjustment_contrast = 1.04

	# --- bloom: only real highlights (sun, LED eyes, water sparkle)
	e.glow_enabled = true
	e.glow_intensity = 0.3
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.1
	e.glow_hdr_scale = 2.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 0.7)
	e.set_glow_level(2, 0.5)
	e.set_glow_level(3, 0.3)
	e.set_glow_level(4, 0.15)

	# --- atmospheric haze (the big one for the dreamy depth)
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = Color(0.93, 0.72, 0.58)
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = 0.3
	e.fog_density = 0.0005
	e.fog_aerial_perspective = 0.55
	e.fog_sky_affect = 0.15
	e.fog_height = 6.0
	e.fog_height_density = 0.00035

	# --- screen space effects
	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 1.6
	e.ssao_power = 1.4
	e.ssr_enabled = true
	e.ssr_max_steps = 128
	e.ssr_fade_in = 0.05
	e.ssr_fade_out = 1.0
	e.ssr_depth_tolerance = 0.6

	we.environment = e
	root.add_child(we)

	# --- the sun: low, behind the floating islands, slightly left
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-11.0, 203.0, 0.0)
	sun.light_color = Color(1.0, 0.76, 0.52)
	sun.light_energy = 1.8
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_split_1 = 0.05
	sun.directional_shadow_split_2 = 0.15
	sun.directional_shadow_split_3 = 0.4
	sun.directional_shadow_blend_splits = true
	sun.light_specular = 0.6
	root.add_child(sun)

	# --- cool fill light from the opposite side (sky bounce)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	fill.light_color = Color(0.62, 0.58, 0.95)
	fill.light_energy = 0.25
	fill.light_specular = 0.0
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	root.add_child(fill)

	return {"env": e, "sun": sun, "world_env": we}
