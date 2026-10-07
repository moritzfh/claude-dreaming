// The road's sides: polished silver/white checker with a row of light studs
// that chase along the track. UV = (s, 0 at the top … 1 at the bottom)
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 col_a : source_color = vec3(0.95, 0.94, 1.0);
uniform vec3 col_b : source_color = vec3(0.45, 0.40, 0.75);

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	float s = UV.x;
	float v = UV.y;
	float chk = mod(floor(s / 1.2) + floor(v * 2.0), 2.0);
	vec3 col = mix(col_a, col_b, chk);
	// light studs in the middle band, chasing forward
	float st = length(vec2((fract(s / 2.0) - 0.5) * 2.0, (v - 0.5) * 4.0));
	float stud = smoothstep(0.55, 0.25, st);
	float chase = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(s * 0.35 - TIME * 9.0), 4.0);
	vec3 sc = hsv2rgb(vec3(fract(s / 80.0 + TIME * 0.05), 0.5, 1.0));
	// thin bright lines at the top and bottom edge
	float lines = smoothstep(0.08, 0.0, v) + smoothstep(0.92, 1.0, v);
	ALBEDO = col * (1.0 - stud * 0.5);
	ROUGHNESS = 0.25;
	METALLIC = 0.6;
	EMISSION = sc * stud * chase * 3.0 + vec3(0.9, 0.85, 1.0) * lines * 0.6 + col * 0.05;
}
