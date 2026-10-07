// The low walls: pearly white panels with a checker band, the top lit by the
// neon tube. UV = (s, 0 bottom … 1 top), UV2.x = 0 inner / 1 top / 2 outer
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	float s = UV.x;
	float v = UV.y;
	float face = UV2.x;
	float chk = mod(floor(s / 0.9) + floor(v * 2.0), 2.0);
	vec3 pearl = mix(vec3(0.98, 0.96, 1.0), vec3(0.86, 0.9, 1.0), 0.5 + 0.5 * sin(s * 0.2));
	vec3 col = mix(pearl, vec3(0.38, 0.30, 0.62), chk * step(face, 0.5) * step(v, 0.55) * step(0.2, v));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 sheen = hsv2rgb(vec3(fract(s / 120.0 + fres * 0.4), 0.45, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.18;
	METALLIC = 0.2;
	EMISSION = sheen * fres * 0.35 + col * 0.06 + vec3(1.0, 0.9, 1.0) * smoothstep(0.85, 1.0, v) * 0.25;
}
