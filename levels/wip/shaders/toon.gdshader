// Bright toon shading for islands, planets and platforms: two-tone light
// with purple shadows, a coloured rim, and (mode 0) grass caps over layered
// earth, (mode 1) plain colour with soft stripes, (mode 2) candy swirl.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform int mode = 0;
uniform vec3 grass_a : source_color = vec3(0.36, 0.82, 0.30);
uniform vec3 grass_b : source_color = vec3(0.62, 0.92, 0.34);
uniform vec3 earth_a : source_color = vec3(0.62, 0.40, 0.26);
uniform vec3 earth_b : source_color = vec3(0.80, 0.55, 0.34);
uniform vec3 base_col : source_color = vec3(1.0, 0.55, 0.75);
uniform vec3 stripe_col : source_color = vec3(1.0, 0.95, 0.98);
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.36, 0.78);
uniform vec3 rim_col : source_color = vec3(0.65, 0.85, 1.0);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.55;
uniform bool spherical = false;
uniform vec3 center = vec3(0.0);
uniform float grass_level = 0.35;
uniform float stripe_scale = 2.4;
uniform float glow = 0.0;
// mode 0 extras: bare earth patches and a winding path band (planets)
uniform float patchiness = 0.0;
uniform vec3 band_normal = vec3(0.0);
uniform float band_width = 0.0;
// mode 3 (platform tops): radius of the disc in local units
uniform float disc_radius = 2.0;
// (Work in Progress) the earth fades into a dusky colour further down
uniform float fade_top = -1000.0;
uniform float fade_bottom = -1001.0;
uniform vec3 fade_col : source_color = vec3(0.32, 0.22, 0.42);

varying vec3 wpos;
varying vec3 wnorm;

float hash13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 up = spherical ? normalize(wpos - center) : vec3(0.0, 1.0, 0.0);
	float n = vnoise(wpos * 0.55);
	float n2 = vnoise(wpos * 2.1 + 5.0);
	vec3 col;
	if (mode == 0) {
		float u = dot(normalize(wnorm), up);
		float g = smoothstep(grass_level - 0.03, grass_level + 0.03, u + (n - 0.5) * 0.22 + (n2 - 0.5) * 0.06);
		float patches = smoothstep(0.32, 0.68, vnoise(wpos * 0.28 + 2.0) * 0.7 + vnoise(wpos * 0.9 + 9.0) * 0.3);
		vec3 gc = mix(grass_a, grass_b, patches);
		gc *= 0.9 + n2 * 0.16;
		float h = spherical ? length(wpos - center) : wpos.y;
		float strata = 0.5 + 0.5 * sin(h * stripe_scale + n * 4.0);
		vec3 ec = mix(earth_a, earth_b, smoothstep(0.35, 0.65, strata));
		// light grass lip right at the edge
		float lip = smoothstep(grass_level - 0.03, grass_level + 0.03, u + (n - 0.5) * 0.22 + 0.05) - g;
		if (patchiness > 0.0) {
			float pn = vnoise(wpos * 0.42 + 13.0) * 0.75 + vnoise(wpos * 1.3) * 0.25;
			g *= smoothstep(patchiness, patchiness + 0.04, pn);
		}
		if (band_width > 0.0) {
			vec3 dn = normalize(wpos - center);
			float wav = dot(dn, normalize(band_normal)) + 0.12 * sin(dn.x * 7.0 + dn.z * 5.0);
			g *= smoothstep(band_width, band_width + 0.03, abs(wav));
		}
		col = mix(ec, gc, g);
		col = mix(col, grass_b * 1.15, clamp(lip, 0.0, 1.0) * 0.8);
	} else if (mode == 1) {
		vec3 lp = (inverse(MODEL_MATRIX) * vec4(wpos, 1.0)).xyz;
		float st = smoothstep(0.45, 0.55, fract(lp.y * stripe_scale));
		col = mix(base_col, stripe_col, st * 0.85);
		col *= 0.95 + n2 * 0.08;
	} else if (mode == 3) {
		// platform top: pastel disc, white rim ring, a star in the middle
		vec3 lp = (inverse(MODEL_MATRIX) * vec4(wpos, 1.0)).xyz;
		float r = length(lp.xz) / disc_radius;
		float a = atan(lp.z, lp.x);
		col = base_col;
		float rings = smoothstep(0.80, 0.82, r) * (1.0 - smoothstep(0.90, 0.92, r));
		float dots = step(0.5, fract(a / 6.2831 * 16.0)) * smoothstep(0.66, 0.68, r) * (1.0 - smoothstep(0.73, 0.75, r));
		float star_r = 0.38 + 0.16 * cos(5.0 * (a + 1.5708));
		float star = 1.0 - smoothstep(star_r - 0.02, star_r, r);
		col = mix(col, stripe_col, max(rings, dots * 0.9));
		col = mix(col, mix(stripe_col, vec3(1.0, 0.9, 0.5), 0.6), star);
		col = mix(col, base_col * 0.8, step(0.96, r));
	} else {
		// candy swirl around the up axis
		vec3 lp = normalize(wpos - center);
		float a = atan(lp.z, lp.x);
		float s = fract((a / 6.2831) * 6.0 + lp.y * 1.6);
		col = mix(base_col, stripe_col, smoothstep(0.45, 0.5, s) - smoothstep(0.95, 1.0, s));
	}
	col = mix(col, fade_col, smoothstep(fade_top, fade_bottom, wpos.y) * 0.9);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_col * fres * rim_strength + col * glow;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.02, 0.12, ndl) * ATTENUATION;
	vec3 shade = mix(shadow_tint, vec3(1.0), t);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * shade / PI;
}
