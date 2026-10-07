// Glossy candy paint for the karts: soft two-tone light, a bright rim and
// a hint of pearl that shifts with the view.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 base : source_color = vec3(1.0, 0.5, 0.3);
uniform float metal = 0.3;
uniform float rough = 0.3;
uniform float emit = 0.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 pearl = vec3(0.5 + 0.5 * cos(6.2831 * (fres * 0.6 + vec3(0.0, 0.33, 0.67))));
	ALBEDO = base;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = base * emit + mix(vec3(1.0, 0.85, 1.0), pearl, 0.4) * fres * 0.35;
}
