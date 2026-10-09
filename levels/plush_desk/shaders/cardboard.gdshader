// Cardboard Claude: one shader, the surface kind picks the look.
//  0 kraft board   1 corrugated cut edge   2 packing tape   3 paper tube
//  4 tube inside   5 paper sticker         6 striped straw  7 brass
//  8 steel         9 star coloured in with yellow marker
shader_type spatial;
render_mode cull_back;

uniform int kind = 0;
uniform sampler2D kraft_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mottle_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float flute_pitch = 0.02;
uniform float emblem = 0.0;            // paper sticker: draw the coral sparkle
uniform vec4 marker_col : source_color = vec4(0.97, 0.6, 0.22, 1.0);
// poster paint on the board (alpha = how well it covers); brush strokes show
uniform vec4 paint : source_color = vec4(1.0, 1.0, 1.0, 0.0);

varying vec3 v_opos;
varying vec3 v_onrm;

void vertex() {
	v_opos = VERTEX;
	v_onrm = NORMAL;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 kraft(vec2 uv) {
	return texture(kraft_tex, uv * 2.2).rgb;
}

// a four-pointed star with curved sides
float sd_sparkle(vec2 p, float r) {
	p = abs(p) / r;
	return (sqrt(p.x) + sqrt(p.y) - 1.0) * r * 0.5;
}

void fragment() {
	vec3 alb = kraft(UV) * tint.rgb;
	float rough = 0.86;
	float spec = 0.3;
	float metal = 0.0;
	vec3 nmap = vec3(0.5, 0.5, 1.0);
	float ao = 1.0;
	vec3 m = texture(mottle_tex, UV * 0.8).rgb;

	if (kind == 0) {
		// faint flutes showing through the liner + scuffs and dents
		float f = sin(UV.x / flute_pitch * TAU);
		nmap = vec3(0.5 + 0.06 * cos(UV.x / flute_pitch * TAU), 0.5, 1.0);
		alb *= 0.97 + 0.03 * f;
		alb *= 0.92 + 0.16 * m.r;
		if (paint.a > 0.0) {
			float stroke = texture(mottle_tex, vec2(UV.x * 0.35, UV.y * 2.5)).g;
			float cover = clamp(paint.a * (0.82 + 0.35 * stroke) - m.b * 0.12, 0.0, 1.0);
			vec3 pc = paint.rgb * (0.9 + 0.12 * stroke);
			alb = mix(alb, pc, smoothstep(0.35, 0.75, cover));
			rough = mix(rough, 0.6, cover);
		}
	} else if (kind == 1) {
		float v = UV.y;
		float wave = 0.5 + 0.3 * sin(UV.x / flute_pitch * TAU);
		float liner = step(v, 0.13) + step(0.87, v);
		float medium = 1.0 - smoothstep(0.06, 0.1, abs(v - wave));
		float paper = clamp(liner + medium, 0.0, 1.0);
		vec3 hole = vec3(0.13, 0.08, 0.045) * (0.6 + 0.4 * abs(v - 0.5) * 2.0);
		alb = mix(hole, kraft(UV * 3.0) * 1.08, paper);
		ao = mix(0.4, 1.0, paper);
		rough = 0.95;
	} else if (kind == 2) {
		float streak = texture(mottle_tex, vec2(UV.x * 0.4, UV.y * 0.08)).b;
		float wrinkle = sin(UV.x * 90.0 + streak * 12.0);
		alb = vec3(0.66, 0.43, 0.2) * (0.9 + 0.1 * m.g);
		nmap = vec3(0.5 + 0.12 * wrinkle * smoothstep(0.3, 0.7, streak), 0.5, 1.0);
		rough = 0.22;
		spec = 0.6;
	} else if (kind == 3) {
		alb = kraft(UV * vec2(0.3, 1.0)) * vec3(0.95, 0.9, 0.86);
		float s = fract(UV.x * 1.0 + UV.y * 2.6);
		float seam = 1.0 - smoothstep(0.0, 0.02, min(s, 1.0 - s));
		alb *= 1.0 - seam * 0.35;
		nmap = vec3(0.5 + seam * 0.25, 0.5, 1.0);
	} else if (kind == 4) {
		alb = vec3(0.16, 0.1, 0.06) * (0.8 + 0.4 * m.r);
		rough = 1.0;
		ao = 0.6;
	} else if (kind == 5) {
		alb = vec3(0.94, 0.93, 0.89) * (0.96 + 0.06 * m.r);
		rough = 0.8;
		if (emblem > 0.5) {
			vec2 p = (UV - 0.5) * 2.0;
			float wob = (texture(mottle_tex, UV * 3.0).g - 0.5) * 0.06;
			float d = sd_sparkle(p, 0.8) + wob;
			float ink = 1.0 - smoothstep(-0.01, 0.02, d);
			float edge = smoothstep(-0.09, -0.01, d) * ink;
			float strokes = 0.85 + 0.15 * sin((p.x * 0.6 + p.y) * 70.0);
			alb = mix(alb, marker_col.rgb * strokes * (1.0 - edge * 0.25), ink);
		}
	} else if (kind == 6) {
		float st = step(0.5, fract(UV.x * 3.0 + UV.y * 9.0));
		alb = mix(vec3(0.95, 0.93, 0.88), vec3(0.86, 0.2, 0.22), st);
		rough = 0.7;
	} else if (kind == 7) {
		alb = vec3(0.86, 0.62, 0.3);
		metal = 1.0;
		rough = 0.32;
	} else if (kind == 8) {
		alb = vec3(0.78, 0.8, 0.83);
		metal = 1.0;
		rough = 0.28;
	} else if (kind == 9) {
		vec2 p = v_opos.xy * 60.0;
		float strokes = 0.88 + 0.12 * sin(p.x * 0.7 + p.y * 1.6);
		float gaps = smoothstep(0.75, 0.95, texture(mottle_tex, v_opos.xy * 4.0).r);
		alb = mix(vec3(1.0, 0.78, 0.16) * strokes, kraft(UV), gaps * 0.5) * alb / max(kraft(UV), vec3(0.01));
		alb = mix(vec3(1.0, 0.78, 0.16) * strokes, kraft(UV), gaps * 0.5);
		rough = 0.7;
	}
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
	NORMAL_MAP = nmap;
	AO = ao;
	AO_LIGHT_AFFECT = 0.5;
}
