// The sky of "Work in Progress": five looks, one per stage, from a finished
// painting to a pencil sketch. stage_f is the stage (fractional while the
// camera pans to the next one: the new look is wiped in from the right, with
// a ragged, glitchy edge).
shader_type sky;

uniform float stage_f = 0.0;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }

// a = (azimuth, elevation) in degrees; 0,0 = straight ahead (-Z)
float hills(float az, float base, float amp, float ph) {
	return base + amp * (sin(az * 0.11 + ph) * 0.6 + sin(az * 0.27 + ph * 2.3) * 0.3 + sin(az * 0.63 + ph * 0.7) * 0.1);
}

vec3 painted(vec2 a) {
	float h = a.y + 6.0;
	vec3 c = mix(lin(vec3(1.0, 0.80, 0.66)), lin(vec3(0.66, 0.76, 0.96)), smoothstep(-1.0, 7.0, h));
	c = mix(c, lin(vec3(0.34, 0.50, 0.88)), smoothstep(7.0, 20.0, h));
	// the sun, low on the right
	float sd = length((a - vec2(16.0, -1.0)) * vec2(1.0, 1.15));
	c += lin(vec3(1.0, 0.80, 0.52)) * (exp(-sd * 0.25) * 0.6 + smoothstep(1.9, 1.3, sd) * 0.9);
	// painted clouds: soft bands, darker pink undersides
	vec2 cp = vec2(a.x * 0.075, a.y * 0.24);
	float n = fbm(cp * vec2(1.0, 2.0) + vec2(3.0, 1.0));
	float band = smoothstep(-2.0, 2.5, h) * (1.0 - smoothstep(14.0, 22.0, h));
	float cl = smoothstep(0.50, 0.66, n) * band;
	float under = smoothstep(0.66, 0.50, fbm(cp * vec2(1.0, 2.0) + vec2(3.0, 0.82)));
	vec3 ccol = mix(lin(vec3(1.0, 0.95, 0.92)), lin(vec3(0.93, 0.70, 0.80)), under * 0.7);
	c = mix(c, ccol, cl * 0.9);
	// far hills (blue), nearer hills (green-blue), the misty valley below
	float h1 = hills(a.x, -8.5, 3.0, 1.0);
	float h2 = hills(a.x + 40.0, -12.0, 2.4, 4.0);
	vec3 far_c = mix(lin(vec3(0.62, 0.66, 0.90)), lin(vec3(0.80, 0.78, 0.93)), smoothstep(h1 - 3.0, h1, a.y));
	c = mix(c, far_c, smoothstep(h1 + 0.12, h1 - 0.12, a.y));
	vec3 near_c = mix(lin(vec3(0.36, 0.58, 0.58)), lin(vec3(0.52, 0.72, 0.62)), smoothstep(h2 - 4.0, h2, a.y));
	near_c *= 0.92 + 0.12 * noise(a * vec2(0.8, 1.6));
	c = mix(c, near_c, smoothstep(h2 + 0.12, h2 - 0.12, a.y));
	float mist = smoothstep(-14.0, -24.0, a.y);
	c = mix(c, lin(vec3(0.62, 0.52, 0.78)), mist * 0.85);
	// further down: a deep, dusky abyss (falling in there is not a good idea)
	c = mix(c, lin(vec3(0.24, 0.16, 0.34)), smoothstep(-17.0, -30.0, a.y));
	// a little canvas grain
	c *= 0.97 + 0.06 * noise(a * 9.0);
	return c;
}

vec3 checker(vec2 a, float sz) {
	float k = mod(floor(a.x / sz) + floor(a.y / sz), 2.0);
	return mix(vec3(0.0), vec3(1.0, 0.0, 1.0), k);
}

vec3 missing(vec2 a) {
	// the painting with holes: tiles where the texture didn't load
	vec2 tile = floor(a / vec2(9.0, 6.0));
	float r = hash12(tile + 17.0);
	float hole = step(r, 0.3);
	// the ground half is entirely missing
	hole = max(hole, step(a.y, -12.0 + 2.0 * hash12(vec2(tile.x, 3.0))));
	vec3 c = mix(painted(a), checker(a, 1.6), hole);
	// a glitchy horizontal tear now and then
	float tear = step(0.93, hash12(vec2(floor(a.y * 1.4), 7.0)));
	c = mix(c, checker(a + vec2(2.0, 0.0), 0.8) * 0.8, tear);
	return c;
}

vec3 proto(vec2 a) {
	// what every empty project shows: the default procedural sky
	vec3 top = lin(vec3(0.385, 0.454, 0.55));
	vec3 hor = lin(vec3(0.6463, 0.6558, 0.6708));
	vec3 gnd = lin(vec3(0.2, 0.169, 0.133));
	float el = radians(a.y + 5.0);
	vec3 c;
	if (el >= 0.0) {
		float k = clamp(1.0 - pow(1.0 - el / (PI * 0.5), 1.0 / 0.15), 0.0, 1.0);
		c = mix(hor, top, k);
	} else {
		float k = clamp(1.0 - pow(1.0 - (-el) / (PI * 0.5), 1.0 / 0.02), 0.0, 1.0);
		c = mix(hor, gnd, k);
	}
	return c;
}

vec3 wire(vec2 a) {
	vec3 c = lin(vec3(0.115, 0.125, 0.15));
	vec2 g = abs(fract(a / 2.0 + 0.5) - 0.5) * 2.0;
	float minor = 1.0 - smoothstep(0.0, 0.06, min(g.x, g.y));
	vec2 G = abs(fract(a / 10.0 + 0.5) - 0.5) * 10.0;
	float major = 1.0 - smoothstep(0.0, 0.07, min(G.x, G.y));
	c = mix(c, lin(vec3(0.19, 0.20, 0.24)), minor * 0.8);
	c = mix(c, lin(vec3(0.25, 0.27, 0.32)), major);
	// the red X axis along the horizon
	c = mix(c, lin(vec3(0.85, 0.25, 0.28)), 1.0 - smoothstep(0.05, 0.12, abs(a.y + 6.0)));
	// soft vignette
	c *= 1.0 - 0.35 * smoothstep(10.0, 30.0, length(a * vec2(0.8, 1.4)));
	return c;
}

vec3 sketch(vec2 a) {
	vec3 paper = lin(vec3(0.965, 0.94, 0.875));
	vec3 c = paper * (0.965 + 0.05 * noise(a * 14.0) + 0.02 * noise(a * 2.0));
	// ruled lines and a red margin, like a school notebook
	c = mix(c, lin(vec3(0.70, 0.80, 0.93)), (1.0 - smoothstep(0.03, 0.07, abs(fract(a.y / 2.2 + 0.5) - 0.5) * 2.2)) * 0.55);
	c = mix(c, lin(vec3(0.93, 0.55, 0.55)), (1.0 - smoothstep(0.05, 0.1, abs(a.x + 21.5))) * 0.7);
	// pencil hills: two loose, broken strokes
	vec3 lead = lin(vec3(0.33, 0.33, 0.36));
	for (int i = 0; i < 2; i++) {
		float hh = hills(a.x + float(i) * 2.5, -9.0 - float(i) * 0.25, 3.0, 1.0 + float(i) * 0.3);
		float gap = smoothstep(0.25, 0.4, noise(vec2(a.x * 0.35 + float(i) * 9.0, 1.0)));
		c = mix(c, lead, (1.0 - smoothstep(0.03, 0.11, abs(a.y - hh))) * gap * 0.75);
	}
	// a quick hatching under the hills
	float hh = hills(a.x, -9.0, 3.0, 1.0);
	float hatch = 1.0 - smoothstep(0.05, 0.16, abs(fract((a.x + a.y) * 0.9) - 0.5) * 2.0 - 0.0);
	float under = smoothstep(hh, hh - 1.0, a.y) * smoothstep(hh - 3.5, hh - 1.5, a.y);
	c = mix(c, lead, hatch * under * 0.18 * smoothstep(0.3, 0.6, noise(a * 0.5)));
	// a little sun, circled twice
	float sd = length(a - vec2(15.0, 1.0));
	c = mix(c, lead, (1.0 - smoothstep(0.04, 0.12, abs(sd - 2.0))) * 0.7);
	c = mix(c, lead, (1.0 - smoothstep(0.03, 0.10, abs(length(a - vec2(15.3, 0.8)) - 2.15))) * 0.35);
	return c;
}

vec3 look(int i, vec2 a) {
	if (i <= 0) return painted(a);
	if (i == 1) return missing(a);
	if (i == 2) return proto(a);
	if (i == 3) return wire(a);
	return sketch(a);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec2 a = vec2(degrees(atan(d.x, -d.z)), degrees(asin(clamp(d.y, -1.0, 1.0))));
	int k = int(floor(stage_f));
	float t = stage_f - float(k);
	vec3 c = look(k, a);
	if (t > 0.001) {
		// wipe from the right (the side the camera moves to), ragged edge
		float u = a.x / 52.0 + 0.5;
		float jag = (noise(vec2(a.y * 0.9, 3.0)) - 0.5) * 0.18 + (hash12(floor(a * vec2(0.6, 1.2))) - 0.5) * 0.09;
		float w = step(1.0 - t * 1.6 + jag, u);
		c = mix(c, look(k + 1, a), w);
	}
	COLOR = c;
}
