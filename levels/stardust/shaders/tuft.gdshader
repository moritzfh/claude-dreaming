// Chunky cartoon grass tufts (MultiMesh). Work on any surface: the mesh's
// local Y is "up". Gentle wind sway, toon light like the ground.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform vec3 root_col : source_color = vec3(0.20, 0.55, 0.22);
uniform vec3 tip_col : source_color = vec3(0.70, 0.95, 0.40);
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.36, 0.78);
uniform float sway = 0.08;
varying float hgt;
varying vec3 tint;
void vertex() {
	hgt = UV.y;
	tint = INSTANCE_CUSTOM.rgb;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 1.7 + w.x * 0.35 + w.z * 0.27) + 0.5 * sin(TIME * 2.9 + w.y * 0.5);
	VERTEX.x += s * sway * hgt * hgt;
	VERTEX.z += s * sway * 0.6 * hgt * hgt;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.75));
}
void fragment() {
	vec3 c = mix(root_col, tip_col, hgt) * tint;
	ALBEDO = c;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.7, 1.0, 0.6) * fres * 0.15 * hgt;
}
void light() {
	float t = smoothstep(-0.02, 0.12, dot(NORMAL, LIGHT)) * ATTENUATION;
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), t) * LIGHT_COLOR / PI;
}
