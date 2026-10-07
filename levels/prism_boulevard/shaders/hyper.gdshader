// Inside the hyperspace tube: streaks of coloured light rushing past.
// UV = (s along the track, angle 0..1 around the tube)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float energy = 1.4;
float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	float lanes = 70.0;
	float l = floor(UV.y * lanes);
	float h = hash12(vec2(l, 3.0));
	float sp = 60.0 + h * 90.0;
	float y = (UV.x + TIME * sp) / (14.0 + h * 30.0);
	float seg = fract(y + h * 13.0);
	float streak = smoothstep(0.0, 0.05, seg) * smoothstep(0.45, 0.05, seg) * step(0.35, hash12(vec2(l, floor(y + h * 13.0))));
	float thin = 1.0 - abs(fract(UV.y * lanes) - 0.5) * 2.0;
	thin = smoothstep(0.2, 1.0, thin);
	vec3 col = hsv2rgb(vec3(fract(h + UV.x / 400.0), 0.55, 1.0));
	float fade = smoothstep(0.0, 20.0, UV2.x) * smoothstep(0.0, 20.0, UV2.y);
	ALBEDO = col * streak * thin * energy * fade + col * 0.04 * fade;
}
