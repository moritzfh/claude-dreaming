// Butterfly wing (alpha scissor), blue with dark veins and edge.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
uniform vec3 inner : source_color = vec3(0.45, 0.70, 1.0);
uniform vec3 outer : source_color = vec3(0.30, 0.38, 0.95);
void fragment() {
	vec2 p = UV * vec2(1.0, 1.0);
	// two lobes: big upper wing, small lower wing (wing root at x=0)
	float up = length((p - vec2(0.45, 0.35)) * vec2(1.0, 1.25));
	float lo = length((p - vec2(0.32, 0.78)) * vec2(1.25, 1.6));
	float shape = min(up - 0.42, lo - 0.28);
	if (shape > 0.0) discard;
	float vein = smoothstep(0.02, 0.0, abs(fract(atan(p.y - 0.5, p.x) * 3.0) - 0.5) - 0.46);
	vec3 c = mix(inner, outer, smoothstep(0.0, 0.5, p.x));
	c = mix(c, vec3(0.05, 0.05, 0.12), smoothstep(-0.05, -0.0, shape) + vein * 0.5);
	ALBEDO = c;
	EMISSION = c * 0.6;
	ROUGHNESS = 0.4;
	BACKLIGHT = c * 0.5;
}
