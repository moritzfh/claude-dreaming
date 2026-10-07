// The warp gate's swirling vortex (a disc, additive).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float energy = 1.6;
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float sw = a + log(r + 0.02) * 2.5 - TIME * 2.4;
	float arms = 0.5 + 0.5 * sin(sw * 5.0);
	vec3 col = hsv2rgb(vec3(fract(r * 0.8 - TIME * 0.15 + a / 6.2831), 0.6, 1.0));
	float core = exp(-r * r * 9.0);
	float edge = smoothstep(1.0, 0.85, r);
	ALBEDO = (col * (0.35 + arms * 0.75) + vec3(1.0) * core * 1.5) * edge * energy * smoothstep(0.0, 0.3, r + core);
}
