// Deep space with a glowing galactic band, colourful nebulae and three layers
// of stars. Static (no TIME) so the sky's radiance is computed only once;
// twinkling is done by separate sparkle sprites.
shader_type sky;
render_mode use_debanding;

uniform vec3 zenith : source_color = vec3(0.012, 0.012, 0.055);
uniform vec3 low : source_color = vec3(0.075, 0.035, 0.17);
uniform vec3 neb_a : source_color = vec3(0.95, 0.28, 0.62);
uniform vec3 neb_b : source_color = vec3(0.22, 0.62, 1.0);
uniform vec3 neb_c : source_color = vec3(0.55, 0.30, 1.0);
uniform vec3 band_normal = vec3(0.28, 1.0, 0.42);
uniform float nebula_strength = 1.0;
uniform float star_strength = 1.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
	               mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
	               mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 6; i++) { s += a * vnoise(p); p = p * 2.03 + vec3(1.7, 9.2, 3.1); a *= 0.5; }
	return s;
}
vec3 stars(vec3 d, float scale, float thr, float size, float bright) {
	vec3 p = d * scale;
	vec3 id = floor(p);
	vec3 col = vec3(0.0);
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 c = id + vec3(float(x), float(y), float(z));
		float h = hash13(c);
		if (h > thr) {
			vec3 o = c + 0.5 + (hash33(c) - 0.5) * 0.7;
			// distance on the sphere, in cell units
			vec3 on = normalize(o) * length(p);
			float dist = length(p - on);
			float k = (h - thr) / (1.0 - thr);
			float s = size * (0.5 + k);
			float core = exp(-dist * dist / (s * s) * 2.0);
			vec3 tint = mix(vec3(0.75, 0.85, 1.0), mix(vec3(1.0, 0.85, 0.65), vec3(1.0, 0.7, 0.9), hash13(c + 7.0)), hash13(c + 3.0));
			col += tint * core * bright * (0.4 + 1.2 * k);
		}
	}
	return col;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	// base: deep indigo, a little lighter and more violet below
	vec3 col = mix(low, zenith, smoothstep(-0.55, 0.85, d.y));
	// galactic band
	vec3 bn = normalize(band_normal);
	float b = dot(d, bn);
	float band = exp(-b * b * 9.0);
	float core = exp(-b * b * 40.0);
	float n1 = fbm(d * 2.6 + vec3(3.0, 1.0, 7.0));
	float n2 = fbm(d * 5.5 + vec3(11.0, 4.0, 2.0));
	float n3 = fbm(d * 1.4 + vec3(5.0, 8.0, 1.0));
	vec3 nc = mix(neb_a, neb_b, smoothstep(0.35, 0.65, n2));
	nc = mix(nc, neb_c, smoothstep(0.5, 0.8, n3) * 0.6);
	float cloud = smoothstep(0.38, 0.78, n1 + (n2 - 0.5) * 0.35);
	col += nc * band * cloud * 0.55 * nebula_strength;
	col += vec3(1.0, 0.85, 0.95) * core * cloud * 0.25 * nebula_strength;
	// dark dust lanes inside the band
	float lanes = smoothstep(0.52, 0.7, fbm(d * 8.0 + vec3(2.0, 2.0, 9.0)));
	col *= 1.0 - band * lanes * 0.55;
	// big soft nebulae away from the band
	float big = smoothstep(0.52, 0.85, fbm(d * 1.7 + vec3(21.0, 3.0, 5.0)));
	vec3 bigc = mix(vec3(0.45, 0.10, 0.55), vec3(0.08, 0.30, 0.55), n3);
	col += bigc * big * 0.35 * nebula_strength;
	// stars: many faint ones, denser along the band, and a few bright ones
	vec3 s = stars(d, 110.0, 0.93 - band * 0.06, 0.09, 1.4);
	s += stars(d, 45.0, 0.955, 0.08, 3.0);
	s += stars(d, 18.0, 0.975, 0.06, 7.0);
	col += s * star_strength;
	COLOR = col;
}
