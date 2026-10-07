// Planet rings: soft bands, fading at the edges.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 col : source_color = vec3(1.0, 0.85, 0.7);
uniform float inner = 0.62;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float band = 0.55 + 0.45 * sin(r * 70.0) * sin(r * 23.0 + 1.0);
	float a = smoothstep(inner, inner + 0.04, r) * (1.0 - smoothstep(0.94, 1.0, r)) * band;
	ALBEDO = col * (0.8 + 0.4 * band);
	ALPHA = a * 0.75;
}
