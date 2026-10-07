// Hyperspace tunnel from the film: dense, opaque paint streaks in hot pink,
// orange, cyan, violet and gold rushing past on a dark navy ground (drawn on
// the inside of a long cylinder around the flight path).
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, shadows_disabled;
uniform float intensity = 0.0;
uniform float speed = 2.5;
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }
vec3 palette(float t) {
	vec3 c;
	if (t < 0.2) c = vec3(1.0, 0.42, 0.72);       // hot pink
	else if (t < 0.4) c = vec3(1.0, 0.62, 0.28);  // orange
	else if (t < 0.6) c = vec3(0.30, 0.85, 0.90); // cyan
	else if (t < 0.8) c = vec3(0.56, 0.36, 0.95); // violet
	else c = vec3(1.0, 0.86, 0.45);               // gold
	return lin(c);
}
// one layer of streak lanes; returns colour (rgb) and coverage (a)
vec4 layer(vec2 uv, float lanes, float seed, float spd) {
	float lane = floor(uv.x * lanes);
	float h = hash(lane + seed);
	float h2 = hash(lane + seed + 31.0);
	float h3 = hash(lane + seed + 57.0);
	float len = 0.12 + h2 * 0.35;
	float z = fract(uv.y * (0.5 + h * 0.9) + TIME * spd * (0.45 + h * 0.9) + h * 7.0);
	// ragged, brushy head and tail
	float s = smoothstep(0.0, 0.015 + h3 * 0.02, z) * (1.0 - smoothstep(len * 0.5, len, z));
	float fx = fract(uv.x * lanes);
	float w = 0.6 + h3 * 0.45;
	float edge = 1.0 - smoothstep(w * 0.6, w, abs(fx - 0.5) * 2.0);
	s *= edge * step(0.1, h2);
	vec3 col = palette(h) * (0.75 + 0.5 * h3);
	return vec4(col, s);
}
void fragment() {
	float fade = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.65, UV.y);
	float k = intensity * fade;
	vec3 col = lin(vec3(0.10, 0.07, 0.24));
	float a = 0.85 * k;
	vec4 l1 = layer(UV, 90.0, 0.0, speed);
	vec4 l2 = layer(UV + vec2(0.37, 0.0), 160.0, 11.0, speed * 1.2);
	vec4 l3 = layer(UV + vec2(0.71, 0.0), 260.0, 23.0, speed * 1.5);
	col = mix(col, l3.rgb, l3.a);
	col = mix(col, l2.rgb, l2.a);
	col = mix(col, l1.rgb, l1.a);
	a = max(a, max(l1.a, max(l2.a, l3.a)) * k);
	ALBEDO = col * 1.6;
	ALPHA = clamp(a, 0.0, 1.0);
}
