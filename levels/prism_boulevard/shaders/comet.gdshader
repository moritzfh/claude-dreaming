// A comet: bright head at UV.x = 1, a long tail fading to UV.x = 0.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 head : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 tail : source_color = vec3(0.5, 0.75, 1.0);
uniform float alpha = 1.0;
void fragment() {
	float y = abs(UV.y - 0.5) * 2.0;
	float x = UV.x;
	float width = mix(0.05, 1.0, pow(x, 3.0));
	float body = smoothstep(width, width * 0.2, y) * pow(x, 2.2);
	float h = exp(-pow((1.0 - x) * 18.0, 2.0) - y * y * 6.0);
	vec3 col = mix(tail, head, x) * body + head * h * 3.0;
	ALBEDO = col * alpha * 1.6;
}
