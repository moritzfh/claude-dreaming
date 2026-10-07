// Star bits: glowing faceted sweets.
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 color : source_color = vec3(1.0, 0.8, 0.3);
uniform float energy = 1.6;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color * 0.6;
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = color * (energy * (0.55 + 0.45 * abs(NORMAL.y)) + fres * 1.5);
}
