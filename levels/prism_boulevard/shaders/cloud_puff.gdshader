// Big soft cloud puffs (spheres in a MultiMesh). A whole cloud reads as one
// soft mass: the colour comes mostly from how high up in its cloud a puff
// sits (INSTANCE_CUSTOM.y, 0 bottom … 1 top), only a little from its own
// normal; wrap-around light, faint pink rims, a fine fluffy texture.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;
uniform vec3 top_col : source_color = vec3(1.0, 0.95, 0.99);
uniform vec3 mid_col : source_color = vec3(0.84, 0.82, 1.0);
uniform vec3 low_col : source_color = vec3(0.44, 0.38, 0.80);
uniform vec3 rim_col : source_color = vec3(1.0, 0.78, 0.93);
uniform float lumps = 0.07;

varying vec3 wn;
varying vec3 wp;
varying float tint;
varying float hf;

float hash13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz * 0.01;
	float n = vnoise(VERTEX * 2.0 + seed * 7.0) * 0.65 + vnoise(VERTEX * 4.5 + seed * 3.0) * 0.35;
	VERTEX += NORMAL * (n - 0.45) * lumps * 2.0;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = INSTANCE_CUSTOM.x;
	hf = INSTANCE_CUSTOM.y;
}

void fragment() {
	float h = clamp(hf * 0.75 + wn.y * 0.3 + 0.05, 0.0, 1.0);
	vec3 col = mix(low_col, mid_col, smoothstep(0.0, 0.55, h));
	col = mix(col, top_col, smoothstep(0.45, 1.0, h));
	col = mix(col, col * vec3(1.04, 0.94, 1.06), tint);
	// fine fluffy texture
	float fl = vnoise(wp * 0.35) * 0.6 + vnoise(wp * 1.1) * 0.4;
	col *= 0.93 + fl * 0.12;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = col;
	EMISSION = rim_col * fres * 0.22 * (0.4 + hf) + col * 0.16;
}

void light() {
	float w = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * (0.35 + 0.65 * pow(w, 1.3)) * ATTENUATION / 3.14159 * 1.5;
}
