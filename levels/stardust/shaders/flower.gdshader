// Little flowers (MultiMesh): petal colour per instance (INSTANCE_CUSTOM),
// centre and stem from vertex colours (alpha 0 = not tinted).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform vec3 shadow_tint : source_color = vec3(0.45, 0.40, 0.80);
varying vec4 vcol;
varying vec3 petal;
void vertex() {
	vcol = COLOR;
	petal = INSTANCE_CUSTOM.rgb;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 1.5 + w.x * 0.4 + w.z * 0.3);
	VERTEX.x += s * 0.04 * VERTEX.y;
}
void fragment() {
	vec3 c = vcol.a > 0.5 ? petal * vcol.rgb : vcol.rgb;
	ALBEDO = c;
	EMISSION = c * (vcol.a > 0.5 ? 0.18 : 0.05);
}
void light() {
	float t = smoothstep(-0.02, 0.12, dot(NORMAL, LIGHT)) * ATTENUATION;
	DIFFUSE_LIGHT += mix(shadow_tint, vec3(1.0), t) * LIGHT_COLOR / PI;
}
