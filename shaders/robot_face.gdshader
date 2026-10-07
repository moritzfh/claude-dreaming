// Dot-matrix LED face of the robot. Eyes are drawn as a grid of glowing square pixels.
shader_type spatial;
render_mode cull_disabled;

uniform int mood = 0;            // 0 normal, 1 sparkle, 2 determined, 3 happy, 4 closed
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform vec2 look = vec2(0.0);   // eye offset in screen units
uniform vec3 core_col : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 edge_col : source_color = vec3(1.0, 0.52, 0.12);
uniform float glow_energy = 5.0;
uniform vec2 grid = vec2(34.0, 23.0);
const float ASPECT = 1.46;

float sd_round_box(vec2 q, vec2 b, float r) {
	vec2 d = abs(q) - b + vec2(r);
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

float eye_sdf(vec2 q, float side) {
	// q: eye-local, aspect corrected, y up
	float sy = max(1.0 - blink, 0.08);
	if (mood == 1) {
		float dia = (abs(q.x) + abs(q.y) * 0.95 - 0.165) * 0.7;
		float plus = min(sd_round_box(q, vec2(0.205, 0.035), 0.02), sd_round_box(q, vec2(0.035, 0.205), 0.02));
		return min(dia, plus);
	} else if (mood == 2) {
		vec2 qq = vec2(q.x, q.y / sy);
		float b = sd_round_box(qq, vec2(0.125, 0.22), 0.06);
		float cut = (qq.y - (0.09 - 0.85 * side * qq.x)) * 0.75;
		return max(b, cut);
	} else if (mood == 3) {
		vec2 c = q - vec2(0.0, -0.07);
		float ring = abs(length(c) - 0.12) - 0.035;
		return max(ring, -c.y - 0.01);
	} else if (mood == 4) {
		return sd_round_box(q, vec2(0.12, 0.025), 0.02);
	}
	vec2 qq = vec2(q.x, q.y / sy);
	return sd_round_box(qq, vec2(0.115, 0.245), 0.075) * min(sy * 1.5, 1.0);
}

float face_sdf(vec2 p) {
	// p in screen uv (0..1), y up
	vec2 l = (p - vec2(0.31, 0.53) - look) * vec2(ASPECT, 1.0);
	vec2 r = (p - vec2(0.69, 0.53) - look) * vec2(ASPECT, 1.0);
	return min(eye_sdf(l, 1.0), eye_sdf(vec2(r.x, r.y), -1.0));
}

void fragment() {
	vec2 p = vec2(1.0 - UV.x, 1.0 - UV.y);
	vec2 cell = floor(p * grid);
	vec2 cc = (cell + 0.5) / grid;
	vec2 f = fract(p * grid);
	float sq = step(0.13, f.x) * step(f.x, 0.87) * step(0.13, f.y) * step(f.y, 0.87);
	float d = face_sdf(cc);
	float on = step(d, 0.0) * sq;
	// brighter, whiter core towards the inside of each eye
	float inner = clamp(-d * 9.0, 0.0, 1.0);
	vec3 pc = mix(edge_col, core_col, inner);
	// soft halo bleeding around lit pixels
	float halo = exp(-max(face_sdf(p), 0.0) * 38.0) * 0.18;
	// subtle diagonal gloss on the glass
	float gloss = smoothstep(0.02, 0.0, abs((p.x + p.y * 0.8) - 0.42)) * 0.06 + smoothstep(0.015, 0.0, abs((p.x + p.y * 0.8) - 0.5)) * 0.03;
	ALBEDO = vec3(0.012, 0.012, 0.018) + vec3(gloss);
	ROUGHNESS = 0.12;
	SPECULAR = 0.35;
	EMISSION = pc * on * glow_energy + edge_col * halo * glow_energy * 0.6;
}
