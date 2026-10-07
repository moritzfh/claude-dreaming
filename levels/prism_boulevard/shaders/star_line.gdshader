// Constellation lines: soft glowing ribbons, a pulse of light runs along them.
// UV.x = along the line (0..1 over the whole figure), UV.y = across (0..1)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(0.65, 0.85, 1.0);
uniform float energy = 2.6;
void fragment() {
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float core = pow(across, 3.0);
	float pulse = 0.6 + 0.4 * sin(UV.x * 25.0 - TIME * 3.0);
	ALBEDO = color * core * energy * pulse * COLOR.a;
}
