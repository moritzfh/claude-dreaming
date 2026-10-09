// A stuffed felt block of any size: the 1 x 1 x 1 cushion (models/block.glb)
// is 9-sliced here, so the puffy edges keep their shape. Per-instance size,
// colours and print. Stitches run at a fixed distance from every edge.
//   pattern 0 felt, 1 gingham, 2 polka dots, 3 stripes, 4 felt with a
//   different top (grass on soil), 5 cotton print with tiny flowers,
//   6 kitchen sponge (pores, no stitches)
shader_type spatial;
render_mode cull_back;

#include "res://levels/plush_desk/shaders/fabric_inc.gdshaderinc"

instance uniform vec3 size = vec3(1.0);
instance uniform vec4 tint : source_color = vec4(0.85, 0.45, 0.4, 1.0);
instance uniform vec4 tint2 : source_color = vec4(0.95, 0.88, 0.76, 1.0);
instance uniform float pattern = 0.0;
instance uniform float glow = 0.0;
uniform vec4 thread_color : source_color = vec4(0.98, 0.93, 0.82, 1.0);
uniform float margin = 0.14;
uniform float inset = 0.075;
uniform float stitch_density = 11.0;
uniform float print_scale = 2.4;

varying vec3 v_edge;
varying vec4 v_col;

void vertex() {
	vec3 H = size * 0.5;
	vec3 o = VERTEX;
	vec3 a = abs(o);
	vec3 sg = sign(o);
	float inner = 0.5 - margin;
	vec3 p;
	vec3 s;
	for (int i = 0; i < 3; i++) {
		if (a[i] > inner) {
			p[i] = sg[i] * (H[i] - (0.5 - a[i]));
			s[i] = 1.0;
		} else {
			p[i] = o[i] / inner * max(H[i] - margin, 0.001);
			s[i] = max(H[i] - margin, 0.001) / inner;
		}
	}
	VERTEX = p;
	NORMAL = normalize(NORMAL / s);
	v_edge = H - abs(p);
	v_col = COLOR;
	FABRIC_VERTEX
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// panel ids come from Blender (+X 0, -X 1, +Y 2, -Y 3, +Z 4, -Z 5); in Godot
// Blender's Y is depth and Blender's Z is up. axis: 0 = x, 1 = y (up), 2 = z
float panel_axis(float pid) {
	return pid < 1.5 ? 0.0 : (pid < 3.5 ? 2.0 : 1.0);
}

vec2 face_uv(vec3 p, float axis) {
	return axis < 0.5 ? p.zy : (axis < 1.5 ? p.xz : p.xy);
}

void fragment() {
	float pid = floor(v_col.r * 16.0 + 0.5);
	float axis = panel_axis(pid);
	bool top = pid > 3.5 && pid < 4.5;    // Blender +Z = the top
	vec2 fp = face_uv(v_opos, axis) * print_scale;
	vec3 alb = tint.rgb;
	if (pattern > 0.5 && pattern < 1.5) {
		vec2 g = step(0.5, fract(fp * 1.6));
		alb = mix(tint.rgb, mix(tint.rgb, tint2.rgb, 0.6), (g.x + g.y) * 0.5);
	} else if (pattern > 1.5 && pattern < 2.5) {
		vec2 g = fract(fp * 2.0 + vec2(0.5 * floor(mod(fp.y * 2.0, 2.0)), 0.0)) - 0.5;
		alb = mix(tint.rgb, tint2.rgb, 1.0 - smoothstep(0.16, 0.2, length(g)));
	} else if (pattern > 2.5 && pattern < 3.5) {
		alb = mix(tint.rgb, tint2.rgb, step(0.6, fract((fp.x + fp.y) * 1.5)));
	} else if (pattern > 3.5 && pattern < 4.5) {
		// soil-coloured sides, a green felt top that folds over the edge
		alb = top ? tint2.rgb : tint.rgb;
		if (!top && v_edge.y < 0.16 && v_opos.y > 0.0) alb = tint2.rgb;
	} else if (pattern > 5.5) {
		vec2 c = fract(fp * 3.0) - 0.5;
		vec2 id = floor(fp * 3.0);
		vec2 off = vec2(hash12(id), hash12(id + 7.0)) - 0.5;
		float r = length(c - off * 0.4);
		float pore = 1.0 - smoothstep(0.08, 0.14, r * (0.7 + hash12(id + 2.0)));
		alb = mix(tint.rgb, tint.rgb * 0.55, pore);
	} else if (pattern > 4.5) {
		vec2 c = fract(fp * 1.3) - 0.5;
		vec2 id = floor(fp * 1.3);
		float r = length(c);
		float ang = atan(c.y, c.x);
		float petal = 0.12 + 0.05 * cos(ang * 5.0 + hash12(id) * 6.0);
		float fl = (1.0 - smoothstep(petal, petal + 0.02, r)) * step(hash12(id + 3.0), 0.55);
		alb = mix(tint.rgb, tint2.rgb, fl);
		alb = mix(alb, vec3(1.0, 0.85, 0.35), (1.0 - smoothstep(0.03, 0.045, r)) * fl);
	}
	vec3 n;
	float ao;
	float h = fabric_surface(v_opos, v_onrm, v_o2v, alb, n, ao);
	ao *= 1.0 - v_col.b * v_col.b * 0.5;
	// stitches at a fixed distance from the edges of this panel
	vec2 e2 = axis < 0.5 ? v_edge.zy : (axis < 1.5 ? v_edge.xz : v_edge.xy);
	vec2 q2 = face_uv(v_opos, axis);
	float d = min(e2.x, e2.y);
	float along = e2.x < e2.y ? q2.y : q2.x;
	float line = 1.0 - smoothstep(0.009, 0.016, abs(d - inset));
	float t = fract(along * stitch_density);
	float dash = smoothstep(0.08, 0.16, t) * (1.0 - smoothstep(0.62, 0.7, t));
	float st = line * dash * step(pattern, 5.5);
	alb = mix(alb, thread_color.rgb, st);
	ao *= 1.0 - line * (1.0 - dash) * 0.25;
	ALBEDO = alb;
	NORMAL = n;
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = fabric_roughness;
	SPECULAR = 0.15;
	EMISSION = tint.rgb * glow;
}

void light() {
	fabric_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
