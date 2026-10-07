// Swirling "starry night" space from the film: brush strokes flowing around
// luminous swirls on deep violet, with stars.
shader_type sky;
render_mode use_debanding;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float brightness = 1.0;
uniform float swirl_speed = 0.02;
uniform vec3 base_col : source_color = vec3(0.19, 0.06, 0.40);
uniform float swirl_mix = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }

vec3 palette(float t) {
	vec3 lilac = vec3(0.58, 0.42, 0.90);
	vec3 pink = vec3(0.98, 0.56, 0.80);
	vec3 cyan = vec3(0.38, 0.88, 0.92);
	vec3 gold = vec3(1.0, 0.86, 0.48);
	vec3 deep = vec3(0.32, 0.20, 0.70);
	vec3 c;
	if (t < 0.25) c = mix(deep, lilac, t / 0.25);
	else if (t < 0.5) c = mix(lilac, pink, (t - 0.25) / 0.25);
	else if (t < 0.75) c = mix(pink, cyan, (t - 0.5) / 0.25);
	else c = mix(cyan, gold, (t - 0.75) / 0.25);
	return lin(c);
}

// strokes around a swirl centre c (direction); returns (stroke amount, colour index, glow)
vec3 swirl(vec3 d, vec3 c, float tightness, float t) {
	vec3 up = abs(c.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tx = normalize(cross(up, c));
	vec3 ty = cross(c, tx);
	float a = acos(clamp(dot(d, c), -1.0, 1.0));
	vec2 q = vec2(dot(d, tx), dot(d, ty));
	float th = atan(q.y, q.x) + a * tightness + t;
	float r = a;
	float n = texture(noise_tex, vec2(th * 1.2, r * 9.0)).r;
	float n2 = texture(noise_tex, vec2(th * 2.7 + 0.3, r * 22.0)).r;
	float stroke = smoothstep(0.45, 0.62, n * 0.7 + n2 * 0.5);
	return vec3(stroke, fract(r * 2.2 + n * 0.5), exp(-a * 6.0));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float t = TIME * swirl_speed;
	// background flow: long horizontal waves of strokes
	float lon = atan(d.x, -d.z);
	float lat = asin(clamp(d.y, -1.0, 1.0));
	float wave = lat + 0.12 * sin(lon * 3.0 + t * 3.0) + 0.05 * sin(lon * 7.0);
	float bn = texture(noise_tex, vec2(lon * 1.0 + t, wave * 8.0)).r;
	float bn2 = texture(noise_tex, vec2(lon * 2.5 - t, wave * 22.0)).r;
	float bstroke = smoothstep(0.56, 0.74, bn * 0.65 + bn2 * 0.5);
	vec3 col = base_col * (0.7 + bn * 0.6);
	// lighter violet / blue dabs on the deep purple, like the film
	vec3 dab = lin(mix(vec3(0.27, 0.12, 0.58), vec3(0.40, 0.26, 0.74), bn2));
	col = mix(col, dab, bstroke * 0.5);

	vec3 s1 = swirl(d, normalize(vec3(-0.55, 0.28, -0.79)), 3.5, t * 4.0);
	vec3 s2 = swirl(d, normalize(vec3(0.45, -0.02, -0.89)), 5.0, -t * 5.0);
	vec3 s3 = swirl(d, normalize(vec3(0.9, 0.35, 0.25)), 4.0, t * 3.0);
	float w1 = exp(-acos(clamp(dot(d, normalize(vec3(-0.55, 0.28, -0.79))), -1.0, 1.0)) * 2.2);
	float w2 = exp(-acos(clamp(dot(d, normalize(vec3(0.45, -0.02, -0.89))), -1.0, 1.0)) * 2.6);
	float w3 = exp(-acos(clamp(dot(d, normalize(vec3(0.9, 0.35, 0.25))), -1.0, 1.0)) * 3.0);
	col = mix(col, palette(0.55 + s1.y * 0.45), s1.x * w1 * swirl_mix);
	col = mix(col, palette(0.45 + s2.y * 0.4), s2.x * w2 * swirl_mix);
	col = mix(col, palette(0.3 + s3.y * 0.5), s3.x * w3 * 0.8 * swirl_mix);
	// luminous swirl hearts
	col += (vec3(1.0, 0.92, 0.7) * s1.z * 1.4 + vec3(0.7, 1.0, 1.0) * s2.z * 0.5) * swirl_mix;
	// stars
	vec2 sp = vec2(lon * 60.0, lat * 60.0);
	vec2 id = floor(sp);
	float h = hash(id);
	float star = step(0.99, h) * smoothstep(0.22, 0.0, length(fract(sp) - 0.5)) * (1.0 - bstroke);
	col += vec3(1.0, 0.95, 0.85) * star * 2.0;
	COLOR = col * brightness;
}
