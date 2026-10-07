// Falling water sheet: bright streaks scrolling downwards, soft edges.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_lambert_wrap;

uniform sampler2D streaks : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.92, 0.95, 1.0);
uniform vec3 shade : source_color = vec3(0.55, 0.70, 0.80);
uniform float speed = 0.9;
uniform float emission = 0.35;

void fragment() {
	float t = TIME * speed;
	float s1 = texture(streaks, vec2(UV.x * 3.0, UV.y * 0.6 - t)).r;
	float s2 = texture(streaks, vec2(UV.x * 7.0 + 0.3, UV.y * 1.2 - t * 1.6)).r;
	float s = s1 * 0.6 + s2 * 0.6;
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float top = smoothstep(0.0, 0.03, UV.y);
	float a = clamp((0.45 + s * 0.7) * edge * top, 0.0, 1.0);
	vec3 c = mix(shade, tint, smoothstep(0.3, 0.8, s));
	ALBEDO = c;
	EMISSION = c * emission;
	ALPHA = a;
	ROUGHNESS = 0.3;
}
