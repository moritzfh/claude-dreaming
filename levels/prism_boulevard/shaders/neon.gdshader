// Neon tube on the walls: bright, colour flowing along the track.
// UV = (s, side)
shader_type spatial;
render_mode unshaded, cull_back;
uniform float energy = 3.2;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	float s = UV.x;
	float hue = fract(s / 90.0 - TIME * 0.12 + UV.y * 0.08);
	float beat = 0.75 + 0.25 * sin(s * 0.12 - TIME * 6.0);
	ALBEDO = hsv2rgb(vec3(hue, 0.55, 1.0)) * energy * beat;
}
