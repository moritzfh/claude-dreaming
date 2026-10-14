// Patchwork quilt: big square patches of printed cotton, machine-quilted in
// diamonds (each diamond puffs up), dashed quilting thread, soft folds.
// The mesh is a flat, finely subdivided plane; it is displaced here.
shader_type spatial;
render_mode cull_back;

#include "res://levels/plush_desk/shaders/fabric_inc.gdshaderinc"

uniform vec4 col_a : source_color = vec4(0.76, 0.42, 0.36, 1.0);
uniform vec4 col_b : source_color = vec4(0.93, 0.85, 0.71, 1.0);
uniform vec4 col_c : source_color = vec4(0.36, 0.52, 0.55, 1.0);
uniform vec4 col_d : source_color = vec4(0.86, 0.66, 0.36, 1.0);
uniform vec4 thread_color : source_color = vec4(0.97, 0.92, 0.8, 1.0);
uniform float patch_size = 2.4;
uniform float diamond = 0.8;
uniform float puff = 0.07;
uniform float fold = 0.16;
uniform float fold_scale = 0.045;
uniform float print_scale = 1.0;
uniform float edge_fade = 0.0;      // > 0: the quilt flops down at its border

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float diamond_h(vec2 p) {
	vec2 q = vec2(p.x + p.y, p.x - p.y) / (diamond * 1.41421356);
	vec2 f = fract(q) - 0.5;
	vec2 a = 1.0 - pow(abs(f) * 2.0, vec2(2.2));
	return sqrt(max(a.x * a.y, 0.0));
}

float folds(vec2 p) {
	float n = textureLod(mottle_tex, p * fold_scale, 0.0).b;
	float n2 = textureLod(mottle_tex, p * fold_scale * 2.3 + vec2(0.3, 0.7), 0.0).g;
	float ridge = 1.0 - abs(n * 2.0 - 1.0);
	return (ridge * ridge - 0.5) * fold + (n2 - 0.5) * fold * 0.4;
}

float height(vec2 p) {
	return diamond_h(p) * puff + folds(p);
}

varying vec3 v_wpos;

void vertex() {
	vec2 p = VERTEX.xz;
	VERTEX.y += height(p);
	FABRIC_VERTEX
	v_opos = vec3(p.x, VERTEX.y, p.y);
}

vec3 print_col(vec2 p, vec2 id) {
	float r = hash12(id * 1.37 + 4.1);
	float r2 = hash12(id * 2.11 + 9.7);
	vec3 base = r < 0.3 ? col_a.rgb : (r < 0.55 ? col_b.rgb : (r < 0.8 ? col_c.rgb : col_d.rgb));
	vec3 ink = mix(col_b.rgb, col_a.rgb * 0.7, step(0.55, r) * 0.0 + step(r, 0.55) * step(0.3, r));
	ink = r < 0.3 ? col_b.rgb : (r < 0.55 ? col_a.rgb * 0.92 : (r < 0.8 ? col_b.rgb : col_a.rgb));
	vec2 q = p * print_scale;
	float m = 0.0;
	if (r2 < 0.3) {          // polka dots
		vec2 g = fract(q * 5.0 + vec2(0.5 * floor(mod(q.y * 5.0, 2.0)), 0.0)) - 0.5;
		m = 1.0 - smoothstep(0.17, 0.2, length(g));
	} else if (r2 < 0.55) {  // gingham
		vec2 g = step(0.5, fract(q * 4.0));
		m = (g.x + g.y) * 0.5;
		return mix(base, mix(base, ink, 0.55), m);
	} else if (r2 < 0.75) {  // stripes
		m = step(0.62, fract((q.x + q.y * 0.0) * 6.0));
	} else {                 // solid with tiny flecks
		m = step(0.985, hash12(floor(q * 40.0))) * 0.6;
	}
	return mix(base, ink, m * 0.8);
}

void fragment() {
	vec2 p = v_opos.xz;
	float e = 0.01;
	float h0 = height(p);
	float hx = height(p + vec2(e, 0.0));
	float hz = height(p + vec2(0.0, e));
	vec3 n = normalize(vec3(-(hx - h0) / e, 1.0, -(hz - h0) / e));

	// patches and the seams between them
	vec2 pid = floor(p / patch_size);
	vec2 pf = fract(p / patch_size);
	float pd = min(min(pf.x, 1.0 - pf.x), min(pf.y, 1.0 - pf.y)) * patch_size;
	vec3 alb = print_col(p, pid);

	float fh;
	vec3 on = fibre_normal(v_opos, n, fibre_scale, fibre_strength, fh);
	vec3 m = mottle(v_opos, n);
	alb *= 1.0 + (m.r - 0.5) * 2.0 * mottle_amount;
	float ao = mix(1.0, smoothstep(0.0, 0.7, fh), fibre_ao);
	// seam groove between patches
	ao *= mix(0.62, 1.0, smoothstep(0.0, 0.05, pd));

	// quilting thread along the diamond borders
	vec2 q = vec2(p.x + p.y, p.x - p.y) / (diamond * 1.41421356);
	vec2 f = fract(q) - 0.5;
	vec2 bd = (0.5 - abs(f)) * diamond * 1.41421356 * 0.5;
	float bmin = min(bd.x, bd.y);
	float along = bd.x < bd.y ? q.y : q.x;
	float t = fract(along * 9.0);
	float dash = smoothstep(0.08, 0.16, t) * (1.0 - smoothstep(0.62, 0.7, t));
	float line = 1.0 - smoothstep(0.006, 0.011, bmin);
	float dh = diamond_h(p);
	ao *= mix(0.55, 1.0, smoothstep(0.0, 0.35, dh));
	alb = mix(alb, thread_color.rgb, line * dash);

	ALBEDO = alb;
	NORMAL = normalize(v_o2v * on);
	AO = ao;
	AO_LIGHT_AFFECT = 0.7;
	ROUGHNESS = fabric_roughness;
	SPECULAR = 0.12;
}

void light() {
	fabric_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
