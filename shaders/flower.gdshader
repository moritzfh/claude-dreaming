// Procedural flower cards (alpha scissor). kind 0 = round blossom, 1 = lavender spike.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform int kind = 0;
uniform vec3 stem_col : source_color = vec3(0.24, 0.42, 0.16);
uniform sampler2D wind_noise : filter_linear_mipmap, repeat_enable;
varying vec4 icol;
varying float rnd;

void vertex() {
	icol = COLOR;
	rnd = INSTANCE_CUSTOM.x;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wn = texture(wind_noise, w.xz * 0.02 + vec2(TIME * 0.05, TIME * 0.03)).r;
	float h = 1.0 - UV.y;
	VERTEX.x += (wn - 0.4) * 0.2 * h * h;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.5));
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	vec3 col = stem_col;
	float a = 0.0;
	float glow = 0.0;
	if (kind == 0) {
		vec2 c = uv - vec2(0.5, 0.28);
		float r = length(c);
		float th = atan(c.y, c.x);
		float petals = 0.2 + 0.06 * cos(th * (5.0 + floor(rnd * 3.0)));
		float head = step(r, petals);
		float centre = step(r, 0.065);
		float stem = step(abs(uv.x - 0.5 - (uv.y - 0.5) * 0.05), 0.022) * step(0.4, uv.y);
		float leaf = step(length((uv - vec2(0.62, 0.72)) * vec2(1.0, 2.6)), 0.09);
		a = max(max(head, stem), leaf);
		col = mix(stem_col, icol.rgb * (0.85 + 0.3 * (1.0 - r / 0.26)), head);
		col = mix(col, vec3(1.0, 0.82, 0.25), centre);
	} else {
		// lavender: column of small buds on top, thin stem below
		float stem = step(abs(uv.x - 0.5), 0.02) * step(0.5, uv.y);
		float buds = 0.0;
		for (int i = 0; i < 9; i++) {
			float y = 0.05 + float(i) * 0.055;
			float side = mod(float(i), 2.0) * 2.0 - 1.0;
			vec2 p = vec2(0.5 + side * 0.07 * (1.0 - float(i) / 12.0), y);
			buds = max(buds, step(length((uv - p) * vec2(1.0, 1.25)), 0.085 - float(8 - i) * 0.004));
		}
		a = max(stem, buds);
		col = mix(stem_col, icol.rgb * (0.75 + 0.5 * (1.0 - uv.y)), buds);
	}
	if (a < 0.5) discard;
	ALBEDO = col;
	ROUGHNESS = 0.7;
	BACKLIGHT = col * 0.5;
}
