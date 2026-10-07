// Rocket ribbon: vertex colour, glowing, soft edges.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float energy = 1.6;
void fragment() {
	float edge = 1.0 - pow(abs(UV.y * 2.0 - 1.0), 2.0);
	ALBEDO = COLOR.rgb * energy;
	ALPHA = clamp(COLOR.a * edge * 1.2, 0.0, 1.0);
}
