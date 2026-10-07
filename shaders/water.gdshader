// Opaque stylised water: turquoise with depth from the terrain height map,
// shore foam, scrolling ripples. Reflections come from SSR + sky.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D heightmap : filter_linear;
uniform vec2 hm_min;
uniform vec2 hm_size;
uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow : source_color = vec3(0.42, 0.80, 0.74);
uniform vec3 deep : source_color = vec3(0.08, 0.40, 0.48);
uniform vec3 foam_col : source_color = vec3(0.95, 0.93, 0.92);
uniform vec2 flow = vec2(0.0, 0.02);
uniform float water_y = 0.4;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 huv = (p - hm_min) / hm_size;
	float ground = texture(heightmap, huv).r;
	float depth = clamp(water_y - ground, 0.0, 20.0);
	float t = TIME;
	vec3 n1 = texture(ripple_a, p * 0.045 + flow * t + vec2(t * 0.006, 0.0)).rgb;
	vec3 n2 = texture(ripple_b, p * 0.11 - flow * t * 1.7 + vec2(0.0, t * 0.011)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.55;

	vec3 col = mix(shallow, deep, smoothstep(0.3, 4.5, depth));
	float fn = texture(foam_noise, p * 0.18 + vec2(t * 0.02, -t * 0.015)).r;
	float foam = (1.0 - smoothstep(0.0, 0.55 + fn * 0.5, depth)) * smoothstep(0.35, 0.6, fn + 0.25);
	col = mix(col, foam_col, foam * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.03, 0.4, foam);
	METALLIC = 0.0;
	SPECULAR = 0.55;
}
