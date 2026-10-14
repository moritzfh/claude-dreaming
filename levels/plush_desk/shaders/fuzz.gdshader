// Plush fuzz: one shell of a shell-fur stack. The planets get a few of these
// as next passes, each pushed out a little further along the normal; fibres
// are cut from the felt texture, thinner towards the tips.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://levels/plush_desk/shaders/fabric_inc.gdshaderinc"

uniform float shell = 0.5;          // 0 = root, 1 = tip
uniform float fuzz_len = 0.03;      // fuzz length in object units
uniform float density = 7.0;        // fibre texture tiles per unit
uniform float use_panels = 0.0;
uniform vec4 panel_b : source_color = vec4(0.9, 0.85, 0.75, 1.0);
uniform vec4 panel_c : source_color = vec4(0.9, 0.6, 0.4, 1.0);

varying vec4 v_col;

void vertex() {
	VERTEX += NORMAL * fuzz_len * shell;
	v_col = COLOR;
	FABRIC_VERTEX
}

void fragment() {
	vec3 n = normalize(v_onrm);
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	float f = texture(fibre_tex, v_opos.zy * density).b * bw.x
		+ texture(fibre_tex, v_opos.xz * density + vec2(0.3, 0.7)).b * bw.y
		+ texture(fibre_tex, v_opos.xy * density + vec2(0.6, 0.2)).b * bw.z;
	if (f < 0.5 + shell * 0.38) {
		discard;
	}
	vec3 base = albedo.rgb;
	if (use_panels > 0.5) {
		float axis = floor(floor(v_col.r * 16.0 + 0.5) * 0.5);
		base = axis < 0.5 ? albedo.rgb : (axis < 1.5 ? panel_b.rgb : panel_c.rgb);
	}
	vec3 alb = base * mix(0.75, 1.12, shell);
	ALBEDO = alb;
	NORMAL = normalize(v_o2v * n);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	AO = mix(0.7, 1.0, shell);
}

void light() {
	fabric_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
