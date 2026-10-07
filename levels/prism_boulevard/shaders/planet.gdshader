// Toon planet: soft pastel bands that swirl a little, purple shadows, a
// glowing atmosphere rim. Used for the planet in the spiral and the moon.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec3 col_a : source_color = vec3(1.0, 0.72, 0.55);
uniform vec3 col_b : source_color = vec3(0.95, 0.45, 0.65);
uniform vec3 col_c : source_color = vec3(1.0, 0.92, 0.75);
uniform vec3 shadow_tint : source_color = vec3(0.35, 0.25, 0.7);
uniform vec3 atmo : source_color = vec3(1.0, 0.8, 0.95);
uniform float bands = 6.0;
uniform float spin = 0.02;
uniform float glow = 0.12;
uniform float craters = 0.0;
varying vec3 lp;
float hash13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { lp = normalize(VERTEX); }
void fragment() {
	float a = atan(lp.z, lp.x) + TIME * spin;
	vec3 q = vec3(cos(a), lp.y, sin(a));
	float n = vnoise(q * 3.0) * 0.6 + vnoise(q * 7.0) * 0.4;
	float b = 0.5 + 0.5 * sin((lp.y + (n - 0.5) * 0.25) * bands * 3.14159);
	vec3 col = mix(col_a, col_b, smoothstep(0.3, 0.7, b));
	col = mix(col, col_c, smoothstep(0.75, 0.95, b) * 0.7);
	if (craters > 0.0) {
		float c = vnoise(lp * 9.0);
		col *= 1.0 - smoothstep(0.62, 0.7, c) * 0.25 * craters;
		col = mix(col, col_c, smoothstep(0.7, 0.75, c) * 0.4 * craters);
	}
	ALBEDO = col;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = atmo * fres * 0.9 + col * glow;
}
void light() {
	float t = smoothstep(-0.15, 0.25, dot(NORMAL, LIGHT)) * ATTENUATION;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * mix(shadow_tint, vec3(1.0), t) / 3.14159;
}
