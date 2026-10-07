// Puffy cumulus made of spheres: very soft wrap lighting, lavender undersides.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, shadows_disabled;

uniform vec3 lit : source_color = vec3(1.0, 0.95, 0.92);
uniform vec3 under : source_color = vec3(0.62, 0.58, 0.78);
varying vec3 wn;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float up = wn.y * 0.5 + 0.5;
	ALBEDO = mix(under, lit, smoothstep(0.15, 0.85, up));
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.6, 0.45, 0.4);
}
