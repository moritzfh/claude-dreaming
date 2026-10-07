// Exhaust flame: a cone pointing backwards, flickering, blue-white normally,
// pink-orange during a boost. UV.y runs along the cone (0 at the tip).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float hot = 0.0;
uniform float power = 0.5;
varying vec3 lp;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	float along = clamp(0.5 - lp.y, 0.0, 1.0);        // 0 tip … 1 base (at the pipe)
	float r = length(lp.xz) / (0.13 * along + 0.001);
	float flick = 0.75 + 0.25 * sin(TIME * 40.0 + lp.y * 20.0) * sin(TIME * 23.0);
	float core = pow(along, 1.5) * (1.0 - smoothstep(0.2, 1.0, r * 0.8));
	vec3 cold = mix(vec3(0.3, 0.55, 1.0), vec3(0.85, 0.95, 1.0), along);
	vec3 warm = mix(vec3(1.0, 0.25, 0.75), vec3(1.0, 0.9, 0.6), along);
	ALBEDO = mix(cold, warm, hot) * core * flick * (1.2 + hot * 2.0) * (0.4 + power);
}
