// Soft vertical light column (marks the channel run).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 col : source_color = vec3(1.0, 0.82, 0.45);
uniform float energy = 1.2;
void fragment() {
	float fres = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float h = UV.y;
	float flick = 0.85 + 0.15 * sin(TIME * 3.0 + UV.x * 30.0);
	ALBEDO = col * energy * pow(fres, 2.0) * smoothstep(0.0, 0.25, h) * (1.0 - smoothstep(0.3, 1.0, 1.0 - h)) * flick;
}
