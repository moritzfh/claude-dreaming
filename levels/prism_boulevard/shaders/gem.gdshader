// Faceted glowing gems: star bits, crystals, the gate's pillars.
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 color : source_color = vec3(1.0, 0.8, 0.3);
uniform float energy = 1.4;
uniform float rim = 1.4;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 hue = vec3(0.5 + 0.5 * cos(6.2831 * (fres * 0.5 + vec3(0.0, 0.33, 0.67))));
	ALBEDO = color * 0.55;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = color * energy * (0.55 + 0.45 * abs(NORMAL.y)) + mix(vec3(1.0), hue, 0.5) * fres * rim;
}
