// "Texture not found": the classic magenta/black checkerboard, in world space,
// with plain lighting so the shapes still read.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float squares_per_m = 2.0;
uniform vec3 color_a : source_color = vec3(1.0, 0.0, 1.0);
uniform vec3 color_b : source_color = vec3(0.02, 0.0, 0.03);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnorm);
	vec2 p = n.y > 0.6 ? wpos.xz : (n.x > 0.6 ? wpos.zy : wpos.xy);
	float k = mod(floor(p.x * squares_per_m + 0.001) + floor(p.y * squares_per_m + 0.001), 2.0);
	vec3 col = mix(color_b, color_a, k);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = col * 0.18;
}
