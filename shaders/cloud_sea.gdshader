// Sunlit sea of clouds seen from above.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float height = 55.0;
varying float h;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(noise_tex, w.xz * 0.0012).r * 0.7 + texture(noise_tex, w.xz * 0.004 + 0.3).r * 0.3;
	h = smoothstep(0.25, 0.85, n);
	VERTEX.y += h * height;
	// normal from finite differences
	float e = 6.0;
	float nx = texture(noise_tex, (w.xz + vec2(e, 0.0)) * 0.0012).r * 0.7 + texture(noise_tex, (w.xz + vec2(e, 0.0)) * 0.004 + 0.3).r * 0.3;
	float nz = texture(noise_tex, (w.xz + vec2(0.0, e)) * 0.0012).r * 0.7 + texture(noise_tex, (w.xz + vec2(0.0, e)) * 0.004 + 0.3).r * 0.3;
	vec3 t1 = vec3(e, (smoothstep(0.25, 0.85, nx) - h) * height, 0.0);
	vec3 t2 = vec3(0.0, (smoothstep(0.25, 0.85, nz) - h) * height, e);
	NORMAL = normalize(cross(t2, t1));
}
void fragment() {
	vec3 lit = vec3(1.0, 0.96, 0.92);
	vec3 shade = vec3(0.62, 0.58, 0.82);
	ALBEDO = mix(shade, lit, smoothstep(0.1, 0.9, h));
	BACKLIGHT = vec3(0.5, 0.4, 0.35);
	ROUGHNESS = 1.0;
}
