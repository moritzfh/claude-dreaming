// The starlight river: a flowing, glowing liquid with drifting star sparks.
// UV = (s, x), UV2 = (x / half width, width)
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.05, 0.25, 0.75);
uniform vec3 bright : source_color = vec3(0.35, 0.95, 1.0);
uniform vec3 foam : source_color = vec3(0.85, 0.95, 1.0);
uniform float flow = 9.0;

varying vec2 tc;
varying float halfw;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.07 + 1.3; a *= 0.5; } return s; }

void vertex() {
	tc = UV;
	halfw = UV2.y * 0.5;
	// gentle swell
	VERTEX += NORMAL * (sin(UV.x * 0.35 + TIME * 2.0) * 0.06 + sin(UV.y * 0.9 + TIME * 1.3) * 0.04);
}

void fragment() {
	vec2 p = vec2(tc.x - TIME * flow, tc.y) * vec2(0.09, 0.22);
	float n = fbm(p + fbm(p * 1.7 + TIME * 0.15) * 0.8);
	float n2 = fbm(p * 3.1 + 5.0 - TIME * 0.05);
	float caust = pow(1.0 - abs(n2 - 0.5) * 2.0, 6.0);
	vec3 col = mix(deep, bright, smoothstep(0.3, 0.75, n));
	col += foam * caust * 0.55;
	// shore glow near the edges
	float ax = abs(tc.y);
	float shore = smoothstep(halfw - 1.6, halfw, ax);
	col = mix(col, foam, shore * 0.6);
	// drifting sparks
	vec2 sp = vec2(tc.x - TIME * flow * 1.3, tc.y) * 1.6;
	vec2 sc = floor(sp);
	float sh = hash12(sc);
	float sd = length(fract(sp) - 0.5);
	float spark = step(0.9, sh) * smoothstep(0.18, 0.0, sd) * (0.5 + 0.5 * sin(TIME * 6.0 + sh * 50.0));
	// fake normals from the noise for glints
	vec2 e = vec2(0.05, 0.0);
	float nx = fbm(p + e.xy) - n;
	float ny = fbm(p + e.yx) - n;
	NORMAL = normalize(NORMAL + (TANGENT * nx + BINORMAL * ny) * 6.0);
	ALBEDO = col * 0.5;
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	EMISSION = col * 0.9 + vec3(1.0) * spark * 3.0;
}
