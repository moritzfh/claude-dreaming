// The oil-paint look, shared by the screen filter (painterly.gdshader, "the
// painting comes alive") and the paintings in the attic (oil_paint.gdshader):
// Kuwahara colour patches, brush strokes that follow the shapes of the image
// (a short line integral of noise along the edge direction), thin dark line
// work on strong edges and a warm varnish. All sizes are in 1080p screen
// pixels, so a painting filling the screen looks exactly like the filtered
// 3D view. Prototype: tools/paint_proto.py.

uniform sampler2D canvas_noise : filter_linear, repeat_enable;
uniform sampler2D stroke_noise : filter_linear, repeat_enable;
uniform int radius = 3;
uniform float stroke = 0.08;
uniform float stroke_len = 9.0;
uniform float lines = 0.3;
uniform float saturation = 0.95;
uniform vec3 varnish = vec3(1.08, 1.0, 0.84);
uniform float contrast = 1.15;

float paint_lumi(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// img: the picture (needs mipmaps) · uv: where in it · unit: one 1080p screen
// pixel in img uv · lod0: the mip level where a texel is one 1080p pixel ·
// suv / sunit: the same position and pixel size in screen uv (noise lives on
// the screen, like the canvas under the paint)
vec3 paint(sampler2D img, vec2 uv, vec2 unit, float lod0, vec2 suv, vec2 sunit, float amount) {
	float wob = texture(canvas_noise, suv * 3.0).r - 0.5;
	uv += vec2(wob, -wob) * 0.0025 * amount / sunit * unit;

	// --- Kuwahara: mean colour of the calmest of four quadrants
	vec2 px = unit * 1.25;
	vec3 m[4];
	vec3 s[4];
	for (int k = 0; k < 4; k++) { m[k] = vec3(0.0); s[k] = vec3(0.0); }
	int r = radius;
	ivec2 offs[4] = ivec2[](ivec2(-r, -r), ivec2(0, -r), ivec2(-r, 0), ivec2(0, 0));
	float cnt = float((r + 1) * (r + 1));
	for (int k = 0; k < 4; k++) {
		for (int j = 0; j <= r; j++) {
			for (int i = 0; i <= r; i++) {
				vec3 c = textureLod(img, uv + vec2(float(offs[k].x + i), float(offs[k].y + j)) * px, lod0).rgb;
				m[k] += c;
				s[k] += c * c;
			}
		}
	}
	float best = 1e9;
	vec3 col = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec3 mean = m[k] / cnt;
		vec3 var_v = abs(s[k] / cnt - mean * mean);
		float v = var_v.r + var_v.g + var_v.b;
		if (v < best) { best = v; col = mean; }
	}

	// --- stroke direction: along the edges (structure tensor of a blurred
	// image, averaged over a small neighbourhood); gently tilted horizontal
	// dabs where the image is flat
	vec2 gu = unit * 6.0;
	float gl = lod0 + 2.5;
	vec3 J = vec3(0.0);
	for (int k = 0; k < 5; k++) {
		vec2 o = k == 0 ? vec2(0.0) : vec2(k == 1 ? 1.0 : (k == 2 ? -1.0 : 0.0), k == 3 ? 1.0 : (k == 4 ? -1.0 : 0.0)) * unit * 9.0;
		float gx = paint_lumi(textureLod(img, uv + o + vec2(gu.x, 0.0), gl).rgb) - paint_lumi(textureLod(img, uv + o - vec2(gu.x, 0.0), gl).rgb);
		float gy = paint_lumi(textureLod(img, uv + o + vec2(0.0, gu.y), gl).rgb) - paint_lumi(textureLod(img, uv + o - vec2(0.0, gu.y), gl).rgb);
		J += vec3(gx * gx, gy * gy, gx * gy);
	}
	J /= 5.0;
	float tr = J.x + J.y;
	vec2 d_edge = -vec2(J.x - J.y, 2.0 * J.z) / max(tr, 1e-8);
	float coh = length(d_edge);
	float a0 = (texture(canvas_noise, suv * vec2(1.0, 0.6) * 0.8).r - 0.5) * 1.2;
	vec2 d_flat = vec2(cos(2.0 * a0), sin(2.0 * a0));
	vec2 d2 = mix(d_flat, d_edge, smoothstep(0.004, 0.05, sqrt(tr)) * coh);
	float ang = 0.5 * atan(d2.y, d2.x);
	vec2 dir = vec2(cos(ang), sin(ang));

	// --- brush texture: average a pixel-sized noise along the stroke
	vec2 nuv = suv / sunit / 256.0;
	float n = 0.0;
	for (int k = -6; k <= 6; k++) {
		n += texture(stroke_noise, nuv + dir * float(k) * (stroke_len / 6.0) / 256.0).r;
	}
	n = clamp((n / 13.0 - 0.5) * 4.5 + 0.5, 0.0, 1.0);
	col *= 1.0 - stroke + 2.0 * stroke * n;

	// --- line work on strong edges
	vec2 lu = unit * 1.5;
	float ll = lod0 + 1.2;
	float ex = paint_lumi(textureLod(img, uv + vec2(lu.x, 0.0), ll).rgb) - paint_lumi(textureLod(img, uv - vec2(lu.x, 0.0), ll).rgb);
	float ey = paint_lumi(textureLod(img, uv + vec2(0.0, lu.y), ll).rgb) - paint_lumi(textureLod(img, uv - vec2(0.0, lu.y), ll).rgb);
	float e = length(vec2(ex, ey));
	col *= 1.0 - lines * clamp((e - 0.055) / 0.125, 0.0, 1.0);

	// --- colour: slightly muted, warm varnish, a touch more contrast
	float l = paint_lumi(col);
	col = mix(vec3(l), col, saturation);
	col *= varnish;
	col = (col - 0.5) * contrast + 0.5;
	return pow(clamp(col, 0.0, 1.0), vec3(1.08));
}
