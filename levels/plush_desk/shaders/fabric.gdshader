// Generic stuffed fabric (felt, plush, velvet, knit) with optional stitched
// seams along the panel borders (UV 0..1 per panel, colour attribute B = seam).
shader_type spatial;
render_mode cull_back;

#include "res://levels/plush_desk/shaders/fabric_inc.gdshaderinc"

uniform float stitches = 1.0;
uniform vec4 thread_color : source_color = vec4(0.98, 0.93, 0.82, 1.0);
uniform float stitch_inset = 0.05;    // UV distance from the panel border
uniform float stitch_count = 14.0;    // stitches per panel edge
uniform float stitch_width = 0.012;
uniform float seam_shadow = 0.45;     // darkening right at the seam
uniform float use_vertex_seam = 1.0;
uniform float use_panels = 0.0;       // colour the panels by axis: albedo / panel_b / panel_c
uniform vec4 panel_b : source_color = vec4(0.9, 0.85, 0.75, 1.0);
uniform vec4 panel_c : source_color = vec4(0.9, 0.6, 0.4, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;

varying vec4 v_col;

void vertex() {
	FABRIC_VERTEX
	v_col = COLOR;
}

float stitch_mask(vec2 uv, out float groove) {
	vec2 d2 = min(uv, 1.0 - uv);
	float m = 0.0;
	groove = 0.0;
	// along the u borders (dashes run along v) and the v borders
	for (int k = 0; k < 2; k++) {
		float dd = k == 0 ? d2.x : d2.y;
		float along = k == 0 ? uv.y : uv.x;
		float other = k == 0 ? d2.y : d2.x;
		float line = 1.0 - smoothstep(stitch_width * 0.6, stitch_width, abs(dd - stitch_inset));
		float t = fract(along * stitch_count);
		float dash = smoothstep(0.08, 0.16, t) * (1.0 - smoothstep(0.62, 0.7, t));
		float keep = smoothstep(stitch_inset * 0.6, stitch_inset * 1.1, other);
		m = max(m, line * dash * keep);
		groove = max(groove, line * keep * (1.0 - dash) * 0.6);
	}
	return m;
}

void fragment() {
	vec3 alb = albedo.rgb;
	if (use_panels > 0.5) {
		float axis = floor(floor(v_col.r * 16.0 + 0.5) * 0.5);
		alb = axis < 0.5 ? albedo.rgb : (axis < 1.5 ? panel_b.rgb : panel_c.rgb);
	}
	vec3 n;
	float ao;
	float h = fabric_surface(v_opos, v_onrm, v_o2v, alb, n, ao);
	float seam = v_col.b * use_vertex_seam;
	ao *= 1.0 - seam * seam * seam_shadow;
	if (stitches > 0.5) {
		float groove;
		float s = stitch_mask(UV, groove);
		alb = mix(alb * (1.0 - groove * 0.35), thread_color.rgb, s);
		ao *= mix(1.0, 0.85, s * (1.0 - h));
	}
	ALBEDO = alb;
	NORMAL = n;
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = fabric_roughness;
	SPECULAR = 0.15;
	EMISSION = emission_color.rgb * emission_energy;
}

void light() {
	fabric_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
