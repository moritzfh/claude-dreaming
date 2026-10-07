// Boost pad / ramp strip: rainbow chevrons racing forward.
// UV.x across (0..1), UV.y along (0 = back … 1 = front)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float count = 3.0;
uniform float speed = 2.2;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float energy = 2.2;
uniform float rainbow = 1.0;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float x = abs(uv.x - 0.5) * 2.0;
	float y = uv.y * count - TIME * speed + x * 0.6;
	float chev = smoothstep(0.08, 0.0, abs(fract(y) - 0.5) - 0.18);
	float border = smoothstep(0.92, 1.0, x) + smoothstep(0.06, 0.0, uv.y) + smoothstep(0.94, 1.0, uv.y);
	vec3 col = mix(tint, hsv2rgb(vec3(fract(uv.y * 0.5 - TIME * 0.4), 0.6, 1.0)), rainbow);
	float a = chev * (1.0 - smoothstep(0.85, 1.0, x)) + border * 0.6 + 0.12;
	ALBEDO = col * a * energy;
}
