// The linen in the embroidery hoop. The stitch texture holds the run:
// R = thread profile (1 in the middle of a stitch), G = when it is sewn
// (0..1 along the run), B = which thread (palette), A = covered.
// `reveal` sews it in; a blue tracing line shows where the needle will go.
// `clear` turns the linen see-through at the end (the quilt shows behind).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;

uniform sampler2D stitch_tex : filter_linear, repeat_disable;
uniform sampler2D weave_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D mottle_tex : filter_linear_mipmap, repeat_enable;
uniform float reveal = 0.0;
uniform float clear = 0.0;
uniform float tracing = 1.0;
uniform vec4 linen : source_color = vec4(0.96, 0.92, 0.84, 1.0);
uniform vec4 c_path : source_color = vec4(0.86, 0.36, 0.33, 1.0);
uniform vec4 c_knot : source_color = vec4(0.96, 0.74, 0.28, 1.0);
uniform vec4 c_cross : source_color = vec4(0.78, 0.16, 0.2, 1.0);
uniform vec4 c_star : source_color = vec4(1.0, 0.86, 0.36, 1.0);
uniform vec4 c_icon : source_color = vec4(0.32, 0.6, 0.62, 1.0);
uniform vec2 texel = vec2(0.0009765625, 0.0009765625);

vec3 palette(float b) {
	if (b < 0.1) return c_path.rgb;
	if (b < 0.3) return c_knot.rgb;
	if (b < 0.5) return c_cross.rgb;
	if (b < 0.7) return c_star.rgb;
	return c_icon.rgb;
}

void fragment() {
	vec2 uv = UV;
	float r = length(uv - 0.5);
	if (r > 0.5) discard;
	vec4 s = texture(stitch_tex, uv);
	// linen weave and a little puckering towards the ring
	float wv = texture(weave_tex, uv * 9.0).b;
	vec3 base = linen.rgb * (0.9 + 0.12 * wv);
	base *= 1.0 + (texture(mottle_tex, uv * 0.7).r - 0.5) * 0.08;
	base *= 1.0 - smoothstep(0.38, 0.5, r) * 0.12 * (0.5 + 0.5 * sin(atan(uv.y - 0.5, uv.x - 0.5) * 40.0));
	vec3 col = base;
	float thread = 0.0;
	vec3 nrm = vec3(0.0, 0.0, 1.0);
	if (s.a > 0.02) {
		float sewn = step(s.g, reveal);
		if (sewn > 0.5) {
			float hx = texture(stitch_tex, uv + vec2(texel.x, 0.0)).r - texture(stitch_tex, uv - vec2(texel.x, 0.0)).r;
			float hy = texture(stitch_tex, uv + vec2(0.0, texel.y)).r - texture(stitch_tex, uv - vec2(0.0, texel.y)).r;
			nrm = normalize(vec3(-hx * 2.2, hy * 2.2, 1.0));
			thread = smoothstep(0.05, 0.3, s.r);
			vec3 tc = palette(s.b);
			// twisted thread: fine diagonal lines
			float tw = 0.5 + 0.5 * sin((uv.x + uv.y) * 1400.0);
			tc *= 0.82 + 0.18 * tw + 0.25 * s.r;
			col = mix(col * 0.8, tc, thread);
		} else {
			// the washable blue pen line where the needle will go
			float pen = smoothstep(0.25, 0.6, s.r) * tracing * step(s.b, 0.1);
			col = mix(col, vec3(0.45, 0.6, 0.85), pen * 0.55);
		}
	}
	ALBEDO = col;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nrm * 0.5 + 0.5, thread);
	ROUGHNESS = mix(0.9, 0.55, thread);
	SPECULAR = mix(0.1, 0.4, thread);
	ALPHA = mix(1.0, thread * 0.9 + 0.04, clear);
}
