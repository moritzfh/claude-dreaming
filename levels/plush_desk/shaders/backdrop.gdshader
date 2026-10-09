// The night-sky quilt hanging behind the desk: puffy navy squares, a crescent
// moon appliqué, gold embroidered stars and sequins that flash as you move.
shader_type spatial;
render_mode cull_back;

#include "res://levels/plush_desk/shaders/fabric_inc.gdshaderinc"

uniform vec4 navy2 : source_color = vec4(0.07, 0.08, 0.22, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.78, 0.36, 1.0);
uniform vec4 moon_col : source_color = vec4(0.96, 0.88, 0.68, 1.0);
uniform vec4 thread_color : source_color = vec4(0.86, 0.78, 0.6, 1.0);
uniform float cell = 3.2;
uniform vec2 moon_pos = vec2(-9.0, 15.0);
uniform float moon_r = 2.6;

varying float v_seq;
varying float v_rough;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float puff(vec2 p) {
	vec2 f = fract(p / cell) - 0.5;
	vec2 a = 1.0 - pow(abs(f) * 2.0, vec2(3.0));
	return sqrt(max(a.x * a.y, 0.0));
}
float sd_sparkle(vec2 p, float r) {
	p = abs(p);
	float d = (p.x + p.y) * 0.7071 - r * 0.38;
	float a = max(p.x - r * 0.16, p.y - r);
	float b = max(p.y - r * 0.16, p.x - r);
	return min(min(a, b), d);
}

void vertex() {
	FABRIC_VERTEX
}

void fragment() {
	vec2 p = v_opos.xy;
	float e = 0.02;
	float h0 = puff(p);
	vec3 n = normalize(vec3(-(puff(p + vec2(e, 0)) - h0) / e * 0.12, -(puff(p + vec2(0, e)) - h0) / e * 0.12, 1.0));
	vec2 cid = floor(p / cell);
	vec3 alb = mix(albedo.rgb, navy2.rgb, step(0.5, hash12(cid + 3.0)));
	float ao = mix(0.55, 1.0, smoothstep(0.0, 0.4, h0));
	// quilting thread around each square
	vec2 f = fract(p / cell);
	vec2 bd = min(f, 1.0 - f) * cell;
	float line = 1.0 - smoothstep(0.012, 0.022, abs(min(bd.x, bd.y) - 0.07));
	float along = bd.x < bd.y ? p.y : p.x;
	float dash = step(0.45, fract(along * 5.0));
	float thread = line * dash;

	// crescent moon appliqué with blanket stitches
	vec2 mp = p - moon_pos;
	float dm = max(length(mp) - moon_r, -(length(mp - vec2(moon_r * 0.45, moon_r * 0.25)) - moon_r * 0.82));
	float moon = 1.0 - smoothstep(-0.01, 0.01, dm);
	float mstitch = (1.0 - smoothstep(0.015, 0.03, abs(dm + 0.12))) * step(0.5, fract(atan(mp.y, mp.x) * 18.0));
	// embroidered gold stars
	vec2 sg = p / 2.2;
	vec2 sid = floor(sg);
	vec2 so = hash22(sid) * 0.6 + 0.2;
	float sr = mix(0.12, 0.3, hash12(sid + 7.0));
	float sd = sd_sparkle((fract(sg) - so) * 2.2, sr * 1.3);
	float star = (1.0 - smoothstep(-0.005, 0.01, sd)) * step(hash12(sid + 1.7), 0.22) * (1.0 - moon);
	float satin = 0.5 + 0.5 * sin((p.x + p.y * 0.4) * 160.0);
	// sequins
	vec2 qg = p / 0.42;
	vec2 qid = floor(qg);
	vec2 qo = hash22(qid + 5.0) * 0.5 + 0.25;
	float qd = length(fract(qg) - qo);
	float has = step(hash12(qid + 9.1), 0.07) * (1.0 - moon) * (1.0 - star);
	float seq = (1.0 - smoothstep(0.13, 0.15, qd)) * has;
	float hole = 1.0 - smoothstep(0.025, 0.035, qd);
	vec2 tilt = (hash22(qid + 2.3) - 0.5) * 1.6;

	float fh;
	vec3 on = fibre_normal(v_opos, n, fibre_scale, fibre_strength, fh);
	alb *= 1.0 + (fh - 0.5) * 0.2;
	alb = mix(alb, moon_col.rgb * (0.95 + 0.05 * fh), moon);
	alb = mix(alb, thread_color.rgb, max(thread * (1.0 - moon), mstitch));
	alb = mix(alb, gold.rgb * (0.8 + 0.2 * satin), star);
	vec3 seq_col = mix(vec3(0.75, 0.8, 0.95), gold.rgb, step(0.6, hash12(qid + 4.4)));
	alb = mix(alb, seq_col * (1.0 - hole * 0.8), seq);
	on = normalize(mix(on, normalize(vec3(tilt, 1.0)), seq));
	on = normalize(on + vec3(0.25, 0.0, 0.0) * (satin - 0.5) * star);
	ALBEDO = alb;
	NORMAL = normalize(v_o2v * on);
	AO = ao * mix(1.0, 0.8, moon * (1.0 - smoothstep(-0.25, 0.0, dm)));
	ROUGHNESS = mix(0.95, 0.15, seq);
	METALLIC = seq;
	EMISSION = alb * seq * 0.06 + gold.rgb * star * 0.04;
}

void light() {
	if (METALLIC > 0.5) {
		gloss_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO * 6.0, 0.18, SPECULAR_LIGHT);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * max(dot(NORMAL, LIGHT), 0.0) * 0.1 / PI;
	} else {
		fabric_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, DIFFUSE_LIGHT, SPECULAR_LIGHT);
	}
}
