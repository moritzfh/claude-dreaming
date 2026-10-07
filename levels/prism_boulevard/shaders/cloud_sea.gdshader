// The sea of clouds far below the track: billowing tops with soft light,
// fading into the sky's glow at the horizon.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform vec3 top_col : source_color = vec3(0.92, 0.82, 1.0);
uniform vec3 shade_col : source_color = vec3(0.30, 0.22, 0.62);
uniform vec3 far_col : source_color = vec3(0.28, 0.14, 0.42);
uniform float scale = 0.004;
uniform float fade_dist = 2600.0;

varying vec3 wpos;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.03 + 1.7; a *= 0.5; } return s; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale + vec2(TIME * 0.004, TIME * 0.002);
	float n = fbm(p);
	float n2 = fbm(p * 2.3 + n * 1.5 + 4.0);
	// billows: bright tops, shaded valleys; light from one side
	float hgt = n * 0.7 + n2 * 0.3;
	float lx = fbm(p + vec2(0.02, 0.0)) - n;
	float shade = clamp(0.55 + lx * 18.0 + (hgt - 0.5) * 1.6, 0.0, 1.0);
	vec3 col = mix(shade_col, top_col, shade);
	col += vec3(1.0, 0.7, 0.9) * pow(n2, 4.0) * 0.4;
	float d = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	float fade = smoothstep(fade_dist * 0.35, fade_dist, d);
	ALBEDO = mix(col, far_col, fade);
}
