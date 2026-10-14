// The plush mouse: velvet body, felt buttons that squash when the real mouse
// buttons are pressed, the split seam between them.
shader_type spatial;
render_mode cull_back;

#include "res://levels/plush_desk/shaders/fabric_inc.gdshaderinc"

uniform vec4 btn_col : source_color = vec4(0.93, 0.85, 0.72, 1.0);
uniform float btn_l = 0.0;
uniform float btn_r = 0.0;
uniform float glow = 0.0;
uniform vec4 glow_col : source_color = vec4(1.0, 0.7, 0.4, 1.0);

varying vec4 v_col;
varying float v_btn;

float btn_mask(vec3 p) {
	return smoothstep(-0.05, -0.3, p.z) * smoothstep(0.42, 0.62, p.y);
}

void vertex() {
	float m = btn_mask(VERTEX);
	float side = VERTEX.x < 0.0 ? btn_l : btn_r;
	VERTEX.y -= m * side * 0.08 * smoothstep(0.0, 0.12, abs(VERTEX.x));
	v_btn = m;
	v_col = COLOR;
	FABRIC_VERTEX
}

void fragment() {
	vec3 alb = albedo.rgb;
	vec3 n;
	float ao;
	float b = smoothstep(0.45, 0.55, v_btn);
	alb = mix(alb, btn_col.rgb, b);
	float h = fabric_surface(v_opos, v_onrm, v_o2v, alb, n, ao);
	ao *= 1.0 - v_col.b * v_col.b * 0.55;
	// the edge where the buttons are sewn onto the body
	ao *= 1.0 - (1.0 - smoothstep(0.0, 0.08, abs(v_btn - 0.5))) * 0.3;
	ALBEDO = alb;
	NORMAL = n;
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = fabric_roughness;
	SPECULAR = 0.15;
	EMISSION = glow_col.rgb * glow * (1.0 - smoothstep(0.0, 0.12, v_opos.y)) * 2.0;
}

void light() {
	fabric_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
