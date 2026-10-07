// Glider sail: a translucent, softly glowing membrane with star ribs.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque, shadows_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.9);
void fragment() {
	float ribs = smoothstep(0.04, 0.0, abs(fract(UV.x * 4.0) - 0.5) - 0.44);
	float edge = smoothstep(0.85, 1.0, UV.x);
	vec3 col = mix(tint, vec3(1.0), ribs * 0.7 + edge * 0.5);
	ALBEDO = col * 1.3;
	ALPHA = 0.55 + ribs * 0.35 + edge * 0.3;
}
