// Launch stars / chips / the Dream Star: warm gold with a bright core, soft
// rim and slow inner shimmer.
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 color_a : source_color = vec3(1.0, 0.82, 0.25);
uniform vec3 color_b : source_color = vec3(1.0, 0.55, 0.15);
uniform vec3 rim : source_color = vec3(1.0, 0.95, 0.75);
uniform float energy = 0.9;
varying vec3 lpos;
void vertex() { lpos = VERTEX; }
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float r = length(lpos.xy);
	vec3 c = mix(color_a, color_b, smoothstep(0.2, 1.0, r));
	float sh = 0.5 + 0.5 * sin(TIME * 2.0 + r * 6.0);
	ALBEDO = c;
	ROUGHNESS = 0.25;
	METALLIC = 0.35;
	EMISSION = c * energy * (0.8 + 0.2 * sh) + rim * fres * 1.2;
}
