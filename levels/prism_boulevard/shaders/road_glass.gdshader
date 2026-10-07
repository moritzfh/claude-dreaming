// The road: big rounded tiles of opalescent glass. Every tile is a slightly
// different pastel, marbled like thin oil film, shifting with the view
// angle; dark grout lines, a silver-white checker rim along the edges with
// glowing studs, a little glitter, and now and then a wave of light that
// runs along the whole track.
// UV = (s metres along, x metres to the right), UV2 = (x / half width, width)
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float tile_len = 3.9;
uniform float tile_w = 3.0;
uniform float grout = 0.075;
uniform float hue_period = 300.0;
uniform float sat = 0.62;
uniform float glow = 0.42;
uniform float edge_band = 0.9;
uniform float pulse_speed = 85.0;
uniform float pulse_gap = 520.0;
uniform vec3 grout_col : source_color = vec3(0.10, 0.08, 0.20);
uniform vec3 rim_a : source_color = vec3(0.97, 0.96, 1.0);
uniform vec3 rim_b : source_color = vec3(0.62, 0.58, 0.86);

varying vec2 tc;
varying float halfw;

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	tc = UV;
	halfw = UV2.y * 0.5;
}

void fragment() {
	float ax = abs(tc.y);
	float inner = halfw - edge_band;
	// --- tiles (rows along the track, every other row shifted half a tile)
	vec2 p = vec2(tc.x / tile_len, (tc.y + halfw) / tile_w);
	float row = floor(p.x);
	p.y += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = (fract(p) - 0.5) * vec2(tile_len, tile_w);
	vec2 hs = vec2(tile_len, tile_w) * 0.5 - grout - 0.35;
	vec2 q = abs(f) - hs;
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.35;
	float aa = fwidth(d) * 1.2 + 0.004;
	float tile = 1.0 - smoothstep(-aa, aa, d);
	float bevel = smoothstep(-0.32, 0.0, d) * tile;          // bright lip near the grout
	float h = hash12(cell + 0.37);
	// --- opal film inside the tile
	vec2 mp = tc * vec2(0.16, 0.28) + h * 23.0;
	float m = vnoise(mp) * 0.55 + vnoise(mp * 2.6 + 3.1) * 0.3 + vnoise(mp * 6.3 + 7.7) * 0.15;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float hue = tc.x / hue_period + h * 0.38 + m * 0.34 + fres * 0.3 + tc.y * 0.004;
	vec3 c1 = hsv2rgb(vec3(fract(hue), sat, 1.0));
	vec3 c2 = hsv2rgb(vec3(fract(hue + 0.28 + m * 0.25), sat * 0.75, 1.0));
	vec3 col = mix(c1, c2, smoothstep(0.42, 0.78, m) * 0.55);
	col = mix(col, vec3(1.0, 0.97, 1.0), smoothstep(0.68, 0.95, m) * 0.4 + bevel * 0.35);
	// a soft diagonal sheen across each tile (like light on glass)
	float sheen = smoothstep(0.25, 0.0, abs(f.x / tile_len + f.y / tile_w * 0.6 - (h - 0.5) * 0.6));
	col *= 0.9 + h * 0.2;
	col += vec3(1.0, 0.95, 1.0) * sheen * 0.18;
	// --- a wave of light every few seconds
	float pd = fract((tc.x - TIME * pulse_speed) / pulse_gap) * pulse_gap;
	float pulse = exp(-(pulse_gap - pd) * 0.15) + exp(-pd * 0.05) * 0.5;
	pulse *= 0.5;
	// --- glitter
	vec2 gp = tc * 2.8;
	vec2 gc = floor(gp);
	float gh = hash12(gc + 11.0);
	float gd = length(fract(gp) - 0.5 - (vec2(hash12(gc + 3.0), hash12(gc + 5.0)) - 0.5) * 0.6);
	float glit = step(0.93, gh) * smoothstep(0.12, 0.0, gd) * pow(0.5 + 0.5 * sin(TIME * (2.0 + gh * 5.0) + gh * 60.0), 6.0);
	vec3 tile_alb = col * 0.72;
	vec3 tile_em = col * (glow + pulse) + vec3(1.0) * glit * 2.5;
	// --- checker rim along both edges, with glowing studs
	float rim = smoothstep(inner - 0.03, inner + 0.03, ax);
	float rl = (ax - inner) / edge_band;
	float chk = mod(floor(tc.x / 1.2) + floor(rl * 2.0), 2.0);
	vec3 rim_alb = mix(rim_a, rim_b, chk);
	float stud_d = length(vec2(fract(tc.x / 3.0) - 0.5, (rl - 0.5) * 0.45) * vec2(3.0, 2.0));
	float stud = smoothstep(0.32, 0.18, stud_d);
	vec3 stud_col = hsv2rgb(vec3(fract(tc.x / 60.0 - TIME * 0.15), 0.55, 1.0));
	float rim_line = smoothstep(0.06, 0.0, abs(ax - inner)) ;
	// --- combine
	vec3 alb = mix(grout_col, tile_alb, tile);
	vec3 em = tile_em * tile + grout_col * 0.4 * (1.0 - tile);
	alb = mix(alb, rim_alb, rim);
	em = mix(em, rim_alb * 0.12 + stud_col * stud * 3.0, rim);
	em += vec3(1.0, 0.95, 1.0) * rim_line * 1.2;
	ALBEDO = alb;
	EMISSION = em;
	ROUGHNESS = mix(mix(0.55, 0.08, tile), 0.3, rim);
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
