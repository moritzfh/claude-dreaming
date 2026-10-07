// Blossom card for trees: a cluster of tiny petals, alpha scissored.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform sampler2D wind_noise : filter_linear_mipmap, repeat_enable;
varying vec4 icol;
varying float rnd;
varying vec3 wn;

void vertex() {
	icol = COLOR;
	rnd = INSTANCE_CUSTOM.x;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(wind_noise, w.xz * 0.03 + vec2(TIME * 0.04, TIME * 0.02)).r;
	VERTEX += (inverse(MODEL_MATRIX) * vec4((n - 0.45) * 0.12, 0.0, (n - 0.45) * 0.08, 0.0)).xyz;
	// normals from cluster centre (stored in INSTANCE_CUSTOM.yzw as world offset) -> soft volumetric shading
	wn = normalize(INSTANCE_CUSTOM.yzw + vec3(0.0, 0.3, 0.0));
}

float hash2(vec2 p) { return fract(sin(dot(p, vec2(27.1, 61.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV * 3.0;
	vec2 id = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float best = 0.0;
	float shade = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 cid = id + o;
			float h = hash2(cid + rnd * 13.0);
			vec2 c = o + vec2(hash2(cid * 1.7 + 3.1), hash2(cid * 2.3 + 7.7)) - 0.5;
			float r = length(f - c);
			float rad = 0.32 + h * 0.18;
			if (r < rad && length(cid / 3.0 - 0.5 + 0.5 / 3.0) < 0.62) { best = 1.0; shade = max(shade, 1.0 - r / rad); }
		}
	}
	if (best < 0.5) discard;
	vec3 c = icol.rgb * (0.82 + shade * 0.3);
	ALBEDO = c;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ROUGHNESS = 0.8;
	BACKLIGHT = c * 0.55;
}
