// A distant spiral galaxy (billboard quad), additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 col_core : source_color = vec3(1.0, 0.9, 0.75);
uniform vec3 col_arm : source_color = vec3(0.55, 0.65, 1.0);
uniform float tilt = 0.45;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	c.y /= tilt;
	float r = length(c);
	float a = atan(c.y, c.x);
	float arms = 0.5 + 0.5 * cos(2.0 * (a - log(r + 0.02) * 2.6));
	float disk = exp(-r * 3.2);
	float core = exp(-r * r * 60.0);
	vec3 col = col_arm * disk * pow(arms, 3.0) * 0.9 + col_core * (core * 2.5 + disk * 0.25);
	col *= smoothstep(1.0, 0.7, r);
	ALBEDO = col * 1.4;
}
