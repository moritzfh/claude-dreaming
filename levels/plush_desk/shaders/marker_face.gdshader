// Cardboard Claude's face: drawn with a black marker on a ruled index card.
// Same moods as the LED face (0 normal, 1 sparkle, 2 determined, 3 happy,
// 4 closed) and the same blink, so the rig drives it unchanged.
shader_type spatial;
render_mode cull_disabled;

uniform int mood = 0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform vec2 look = vec2(0.0);
uniform sampler2D mottle_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 paper_col : source_color = vec3(0.96, 0.94, 0.88);
uniform vec3 ink_col : source_color = vec3(0.06, 0.055, 0.08);
uniform vec3 line_col : source_color = vec3(0.55, 0.68, 0.9);
uniform vec3 blush_col : source_color = vec3(0.95, 0.5, 0.52);
uniform float flip_v = 0.0;
const float ASPECT = 1.42;

float sd_round_box(vec2 q, vec2 b, float r) {
	vec2 d = abs(q) - b + vec2(r);
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

float eye_sdf(vec2 q, float side) {
	float sy = max(1.0 - blink, 0.08);
	if (mood == 1) {
		float dia = (abs(q.x) + abs(q.y) * 0.95 - 0.165) * 0.7;
		float plus = min(sd_round_box(q, vec2(0.205, 0.035), 0.02), sd_round_box(q, vec2(0.035, 0.205), 0.02));
		return min(dia, plus);
	} else if (mood == 2) {
		vec2 qq = vec2(q.x, q.y / sy);
		float b = sd_round_box(qq, vec2(0.11, 0.2), 0.08);
		float cut = (qq.y - (0.08 - 0.85 * side * qq.x)) * 0.75;
		return max(b, cut);
	} else if (mood == 3) {
		vec2 c = q - vec2(0.0, -0.07);
		float ring = abs(length(c) - 0.12) - 0.032;
		return max(ring, -c.y - 0.01);
	} else if (mood == 4) {
		return sd_round_box(q, vec2(0.12, 0.022), 0.02);
	}
	vec2 qq = vec2(q.x, q.y / sy);
	return sd_round_box(qq, vec2(0.1, 0.2), 0.1) * min(sy * 1.5, 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x, mix(UV.y, 1.0 - UV.y, flip_v));
	vec3 mt = texture(mottle_tex, p * 1.7).rgb;
	vec3 col = paper_col * (0.95 + 0.07 * mt.r);
	// ruled lines and the red margin of an index card
	float ly = fract(p.y * 7.0);
	col = mix(col, line_col, (1.0 - smoothstep(0.0, 0.035, abs(ly - 0.5))) * 0.35);
	col = mix(col, vec3(0.9, 0.4, 0.42), (1.0 - smoothstep(0.0, 0.006, abs(p.x - 0.09))) * 0.4);
	// the eyes, with a shaky hand
	float wob = (texture(mottle_tex, p * 5.0).g - 0.5) * 0.03;
	vec2 l = (p - vec2(0.32, 0.53) - look) * vec2(ASPECT, 1.0);
	vec2 r = (p - vec2(0.68, 0.53) - look) * vec2(ASPECT, 1.0);
	float d = min(eye_sdf(l, 1.0), eye_sdf(r, -1.0)) + wob;
	float ink = 1.0 - smoothstep(-0.004, 0.006, d);
	// marker strokes: the fill is a little streaky, the outline darker
	float strokes = 0.8 + 0.2 * sin((p.x * 0.5 + p.y) * 180.0 + mt.b * 6.0);
	float rim = smoothstep(-0.03, -0.004, d);
	vec3 inkc = mix(ink_col * (1.6 - strokes * 0.6), ink_col * 0.6, rim);
	// a glint left on the paper (eyes look alive)
	float glint = 1.0 - smoothstep(0.018, 0.026, min(length((p - vec2(0.345, 0.6) - look) * vec2(ASPECT, 1.0)),
		length((p - vec2(0.705, 0.6) - look) * vec2(ASPECT, 1.0))));
	if (mood != 0) glint = 0.0;
	ink *= 1.0 - glint * step(blink, 0.3);
	// pencil blush, hatched
	float bl = min(length((p - vec2(0.16, 0.33)) * vec2(ASPECT, 1.6)), length((p - vec2(0.84, 0.33)) * vec2(ASPECT, 1.6)));
	float hatch = step(0.45, fract((p.x + p.y) * 70.0));
	col = mix(col, blush_col, (1.0 - smoothstep(0.07, 0.1, bl)) * hatch * 0.55);
	col = mix(col, inkc, ink);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.45, ink);
	SPECULAR = mix(0.3, 0.5, ink);
}
