// Pencil sketch on paper: wobbly graphite edges (mode 0: a box of `size`
// centred on the origin, mode 1: an outline for round things) and diagonal
// hatching that gets denser on the faces turned away from the light.
shader_type spatial;
render_mode unshaded, specular_disabled, shadows_disabled;

uniform vec3 size = vec3(1.0);
uniform int mode = 0;
uniform vec3 paper : source_color = vec3(0.965, 0.94, 0.875);
uniform vec3 lead : source_color = vec3(0.28, 0.28, 0.32);
uniform vec3 tint : source_color = vec3(1.0);
uniform float hatch = 1.0;
uniform float edge = 1.0;

varying vec3 lpos;
varying vec3 wpos;
varying vec3 wnorm;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = paper * tint * (0.97 + 0.05 * noise(wpos.xy * 23.0));
	// hatching: none on top, light on the front, more on the sides and below
	float dark = wnorm.y > 0.5 ? 0.0 : (wnorm.y < -0.5 ? 0.9 : (abs(wnorm.z) > 0.5 ? 0.42 : 0.7));
	vec2 hp = abs(wnorm.z) > 0.5 ? wpos.xy : (abs(wnorm.x) > 0.5 ? wpos.zy : wpos.xz);
	float ln = abs(fract((hp.x + hp.y) * 4.5 + noise(hp * 2.0) * 0.4) - 0.5) * 2.0;
	float h = (1.0 - smoothstep(0.08, 0.38, ln)) * dark * hatch * smoothstep(0.15, 0.55, noise(hp * 1.3 + 4.0) * 0.6 + 0.4);
	// cross hatching where it's darkest
	float ln2 = abs(fract((hp.x - hp.y) * 4.5) - 0.5) * 2.0;
	h += (1.0 - smoothstep(0.08, 0.3, ln2)) * smoothstep(0.6, 0.9, dark) * hatch * 0.6;
	col = mix(col, lead, clamp(h, 0.0, 1.0) * 0.42);
	float e = 0.0;
	if (mode == 0) {
		vec3 d = size * 0.5 - abs(lpos);
		float mn = min(d.x, min(d.y, d.z));
		float mx = max(d.x, max(d.y, d.z));
		float second = d.x + d.y + d.z - mn - mx;
		float w = 0.022 + 0.022 * noise(wpos.xy * 5.0 + wpos.z);
		e = 1.0 - smoothstep(w, w + fwidth(second) * 1.5, second);
		// a second, lighter stroke a little off the edge (sketchy)
		float w2 = 0.07 + 0.03 * noise(wpos.yx * 3.0);
		e = max(e, (1.0 - smoothstep(0.012, 0.012 + fwidth(second) * 1.5, abs(second - w2))) * 0.45 * step(0.45, noise(wpos.xy * 1.7 + 2.0)));
	} else {
		float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		e = smoothstep(0.62, 0.78, f + (noise(wpos.xy * 6.0) - 0.5) * 0.15);
	}
	col = mix(col, lead, e * 0.9 * edge);
	ALBEDO = col;
}
