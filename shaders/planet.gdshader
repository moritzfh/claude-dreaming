// The little dream world seen from space: painterly green land, teal water,
// a winding river, swirling clouds and a glowing rim.
shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 land_a : source_color = vec3(0.42, 0.68, 0.28);
uniform vec3 land_b : source_color = vec3(0.70, 0.78, 0.32);
uniform vec3 water : source_color = vec3(0.14, 0.42, 0.55);
uniform vec3 rim_col : source_color = vec3(0.85, 0.80, 1.0);
varying vec3 lp;
void vertex() { lp = normalize(VERTEX); }
// triplanar noise (weights from the surface direction, so the result stays a
// plain 0..1 noise value whatever the sampling scale)
float n3(vec3 p) {
	vec3 w = abs(lp) + 1e-4;
	return (texture(noise_tex, p.xy * 0.5 + 0.5).r * w.z + texture(noise_tex, p.xz * 0.5 + 0.5).r * w.y + texture(noise_tex, p.yz * 0.5 + 0.5).r * w.x) / (w.x + w.y + w.z);
}
void fragment() {
	vec3 p = lp;
	float n = n3(p * 0.6);
	float n2 = n3(p * 1.9 + 0.3);
	float land = smoothstep(0.36, 0.39, n + (n2 - 0.5) * 0.15);
	vec3 green = mix(vec3(0.16, 0.38, 0.14), land_a, smoothstep(0.38, 0.5, n2));
	green = mix(green, land_b, smoothstep(0.52, 0.66, n2));
	vec3 col = mix(water, green, land);
	// river: an iso-line of a second noise field
	float rv = abs(n2 - 0.5 + (n - 0.5) * 0.3);
	col = mix(col, vec3(0.25, 0.55, 0.85), (1.0 - smoothstep(0.006, 0.014, rv)) * land);
	// snowy / sandy specks
	col = mix(col, vec3(0.95, 0.85, 0.65), smoothstep(0.64, 0.70, n2) * land * 0.6);
	// clouds
	float c = n3(p * 2.2 + vec3(TIME * 0.01, 0.0, 0.0));
	col = mix(col, vec3(1.0, 0.98, 0.96), smoothstep(0.64, 0.72, c) * 0.75);
	// painted look: short brush dabs modulate the colour
	float dab = n3(p * 5.0 + vec3(n2 * 2.0));
	col *= 0.82 + dab * 0.4;
	col = mix(col, vec3(0.95, 0.72, 0.28), smoothstep(0.66, 0.72, dab) * land * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.8;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_col * fres * 0.5;
}
