// Full-screen effects: radial white burst (through the clouds) and the
// reality crack at the end of the warp.
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float burst = 0.0;
uniform float crack = 0.0;
uniform float coral = 0.0;
uniform float white = 0.0;
float hash(float n) { return fract(sin(n * 91.345) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	c.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(c);
	float a = atan(c.y, c.x);
	// cracks
	float line = 0.0;
	vec2 disp = vec2(0.0);
	for (int k = 0; k < 9; k++) {
		float fk = float(k);
		float ang = fk / 9.0 * 6.2832 + hash(fk) * 0.6;
		float reach = (0.25 + hash(fk + 4.0) * 0.6) * crack * 1.4;
		float wob = sin(r * (18.0 + hash(fk + 2.0) * 20.0) + fk) * 0.08 + sin(r * 63.0 + fk * 3.0) * 0.02;
		float da = abs(mod(a - ang - wob + 3.14159, 6.2832) - 3.14159) * r;
		float on = step(r, reach);
		line = max(line, on * (1.0 - smoothstep(0.0015, 0.006, da)));
		disp += on * vec2(cos(ang + 1.57), sin(ang + 1.57)) * step(da, 0.04) * 0.004 * crack;
	}
	vec3 col;
	col.r = texture(screen_tex, uv + disp * 1.5).r;
	col.g = texture(screen_tex, uv + disp).g;
	col.b = texture(screen_tex, uv + disp * 0.5).b;
	col = mix(col, vec3(1.0), line * crack);
	// burst: white rays from the centre
	float rays = 0.5 + 0.5 * sin(a * 40.0 + hash(floor(a * 6.0)) * 6.0);
	vec3 bcol = mix(vec3(1.0, 0.97, 0.92), vec3(0.95, 0.9, 0.95), rays);
	col = mix(col, bcol, clamp(burst * (0.6 + r * 0.8 + rays * 0.3), 0.0, 1.0));
	// coral shatter, then white
	vec3 cor = vec3(0.92, 0.50, 0.40) * (0.7 + 0.3 * rays);
	col = mix(col, cor, coral);
	col = mix(col, vec3(1.0), white);
	COLOR = vec4(col, 1.0);
}
