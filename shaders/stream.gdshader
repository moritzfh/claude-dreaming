// Water for the garden channel and reflecting pool.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 flow = vec2(0.0, -0.6);
uniform float ripple_scale = 0.35;
uniform float ripple_depth = 0.35;
uniform vec3 col : source_color = vec3(0.10, 0.30, 0.34);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * ripple_scale;
	vec3 n1 = texture(ripple, p + flow * TIME * ripple_scale).rgb;
	vec3 n2 = texture(ripple, p * 1.9 - flow * TIME * ripple_scale * 0.7 + vec2(0.37, 0.11)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = ripple_depth;
	ALBEDO = col;
	ROUGHNESS = 0.02;
	SPECULAR = 0.6;
}
