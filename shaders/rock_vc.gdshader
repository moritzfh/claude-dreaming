// Vertex-coloured rock (floating islands) with brush noise.
shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform sampler2D noise_b : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = texture(noise_b, vec2(wpos.x + wpos.z, wpos.y) * vec2(0.05, 0.012)).r;
	ALBEDO = COLOR.rgb * (0.8 + n * 0.4);
	ROUGHNESS = 0.95;
}
