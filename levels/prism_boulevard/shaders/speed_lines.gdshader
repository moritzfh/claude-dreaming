// Full-screen speed lines (radial streaks from the centre) for boosts.
shader_type canvas_item;
uniform float amount = 0.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 c = UV - vec2(0.5, 0.52);
	c.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float a = atan(c.y, c.x);
	float r = length(c);
	float k = floor(a / 6.2831 * 120.0);
	float h = hash(k);
	float speed = 1.5 + h * 2.0;
	float ph = fract(h * 7.0 + TIME * speed);
	float streak = smoothstep(0.0, 0.04, r - (0.25 + ph * 0.6)) * smoothstep(0.18, 0.0, r - (0.25 + ph * 0.6));
	float thin = smoothstep(0.5, 0.0, abs(fract(a / 6.2831 * 120.0) - 0.5) * 2.0 - 0.1);
	float vis = step(0.55, h) * streak * thin * smoothstep(0.22, 0.5, r);
	COLOR = vec4(1.0, 0.97, 1.0, vis * amount * 0.55);
}
