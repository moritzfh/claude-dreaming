// Underneath the road: deep violet glass with glowing seams and soft
// rainbow light leaking through. UV = (s, x)
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 base : source_color = vec3(0.10, 0.06, 0.22);

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	float s = UV.x;
	float x = UV.y;
	float seam = smoothstep(0.08, 0.0, abs(fract(s / 4.6) - 0.5) * 4.6 - 2.2);
	float mid = smoothstep(0.6, 0.0, abs(x));
	float edges = smoothstep(UV2.y * 0.5 - 1.0, UV2.y * 0.5, abs(x));
	vec3 lc = hsv2rgb(vec3(fract(s / 300.0), 0.6, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = base;
	ROUGHNESS = 0.2;
	EMISSION = lc * (seam * 0.6 + mid * 0.9 + edges * 0.5 + 0.12) + vec3(0.6, 0.4, 1.0) * fres * 0.4;
}
