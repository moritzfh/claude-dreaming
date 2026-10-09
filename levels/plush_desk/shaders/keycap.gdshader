// Felt keycap cushion for the MultiMesh keyboard.
// INSTANCE_CUSTOM: r = width in key units + 10 x extra depth in rows (the 1u
// mesh is 9-sliced, so the puffy corners stay round), g = legend cell in
// labels.png (-1 = none), b = fairy-light glow 0..1, a = felt colour 0..3.
shader_type spatial;
render_mode cull_back;

#include "res://levels/plush_desk/shaders/fabric_inc.gdshaderinc"

uniform sampler2D labels_tex : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec4 col1 : source_color = vec4(0.85, 0.5, 0.42, 1.0);
uniform vec4 col2 : source_color = vec4(0.42, 0.62, 0.62, 1.0);
uniform vec4 col3 : source_color = vec4(0.9, 0.7, 0.36, 1.0);
uniform vec4 thread1 : source_color = vec4(0.98, 0.94, 0.86, 1.0);
uniform vec4 thread_color : source_color = vec4(0.99, 0.95, 0.86, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float glow_energy = 4.0;
uniform float pitch = 0.5;
uniform float label_size = 0.27;
uniform float stitch_density = 30.0;   // stitches per metre

varying vec4 v_col;
varying vec2 v_label_uv;
varying float v_label_cell;
varying float v_glow;
varying float v_alt;
varying float v_h;

void vertex() {
	float w = mod(INSTANCE_CUSTOM.r, 10.0);
	float dz = floor(INSTANCE_CUSTOM.r / 10.0);
	vec3 o = VERTEX;
	float ext = max(w - 1.0, 0.0) * pitch * 0.5;
	VERTEX.x += clamp(o.x / 0.03, -1.0, 1.0) * ext;
	VERTEX.z += clamp(o.z / 0.03, -1.0, 1.0) * dz * pitch * 0.5;
	// legends sit in the middle of the (stretched) key and keep their shape
	v_label_uv = vec2(VERTEX.x, VERTEX.z) / label_size + 0.5;
	v_label_cell = INSTANCE_CUSTOM.g;
	v_glow = INSTANCE_CUSTOM.b;
	v_alt = INSTANCE_CUSTOM.a;
	v_h = o.y;
	v_col = COLOR;
	FABRIC_VERTEX
}

void fragment() {
	vec3 alb = v_alt < 0.5 ? albedo.rgb : (v_alt < 1.5 ? col1.rgb : (v_alt < 2.5 ? col2.rgb : col3.rgb));
	vec3 thr = v_alt < 0.5 ? thread_color.rgb : thread1.rgb;
	float h;
	vec3 on = fibre_normal(v_opos, normalize(v_onrm), fibre_scale, fibre_strength, h);
	vec3 m = mottle(v_opos + vec3(v_label_cell * 1.7, 0.0, v_label_cell * 0.9), normalize(v_onrm));
	alb *= 1.0 + (m.r - 0.5) * 2.0 * mottle_amount;
	float ao = mix(1.0, smoothstep(0.0, 0.7, h), fibre_ao);
	ao *= 1.0 - v_col.b * v_col.b * 0.4;

	// stitched seam around the top panel
	float top = v_col.g;
	vec2 d2 = min(UV, 1.0 - UV);
	float dd = min(d2.x, d2.y);
	float along = d2.x < d2.y ? v_opos.z : v_opos.x;
	float line = 1.0 - smoothstep(0.012, 0.02, abs(dd - 0.07));
	float t = fract(along * stitch_density);
	float dash = smoothstep(0.1, 0.18, t) * (1.0 - smoothstep(0.6, 0.68, t));
	float st = line * dash * top;
	alb = mix(alb, thr, st);

	// embroidered legend
	float lab = 0.0;
	if (v_label_cell >= 0.0 && top > 0.5) {
		vec2 luv = v_label_uv;
		if (luv.x > 0.0 && luv.x < 1.0 && luv.y > 0.0 && luv.y < 1.0) {
			vec2 cell = vec2(mod(v_label_cell, 10.0), floor(v_label_cell / 10.0));
			vec2 auv = (cell + luv) / 10.0;
			vec4 L = texture(labels_tex, auv);
			lab = smoothstep(0.35, 0.6, L.r);
			float e = 1.0 / 1280.0;
			float gx = texture(labels_tex, auv + vec2(e, 0.0)).g - texture(labels_tex, auv - vec2(e, 0.0)).g;
			float gz = texture(labels_tex, auv + vec2(0.0, e)).g - texture(labels_tex, auv - vec2(0.0, e)).g;
			// satin stitches: fine diagonal thread lines
			float satin = 0.5 + 0.5 * sin((luv.x * 0.7 + luv.y) * 210.0);
			on = normalize(on + vec3(-gx, 0.0, -gz) * 6.0 * top + vec3(0.25, 0.0, 0.25) * (satin - 0.5) * lab);
			alb = mix(alb, thr * (0.86 + 0.14 * satin), lab);
			ao *= 1.0 - (1.0 - lab) * smoothstep(0.2, 0.0, abs(L.g - 0.25)) * 0.25;
		}
	}
	ALBEDO = alb;
	NORMAL = normalize(v_o2v * on);
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = fabric_roughness;
	SPECULAR = 0.15;
	// fairy lights sewn in under the key shine through the felt
	float base = 1.0 - smoothstep(0.0, 0.14, v_h);
	EMISSION = glow_color.rgb * glow_energy * v_glow * (base * base * 0.9 + lab * 0.7 + st * 0.35 + 0.06);
}

void light() {
	fabric_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
