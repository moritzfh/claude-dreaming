// Editor wireframe: glowing edges of a box (mode 0, local box of `size`
// centred on the origin) or a lat/long grid (mode 1, spheres and cylinders),
// faint 1 m lines on the faces, and an optional see-through fill – the
// light blue of a collision shape.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 line_col : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 fill_col : source_color = vec4(0.2, 0.7, 0.85, 0.0);
uniform vec3 size = vec3(1.0);
uniform int mode = 0;
uniform float edge_w = 0.035;
uniform float grid_a = 0.25;
uniform float stripes = 0.0;
uniform float bright = 1.35;
uniform vec2 uv_lines = vec2(16.0, 8.0);

varying vec3 lpos;
varying vec3 wpos;

void vertex() {
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float e = 0.0;
	float g = 0.0;
	if (mode == 0) {
		vec3 d = size * 0.5 - abs(lpos);
		float mn = min(d.x, min(d.y, d.z));
		float mx = max(d.x, max(d.y, d.z));
		float second = d.x + d.y + d.z - mn - mx;
		e = 1.0 - smoothstep(edge_w, edge_w + fwidth(second) * 1.5, second);
		vec3 q = lpos + size * 0.5;
		float gx = 1.0 - smoothstep(0.0, fwidth(q.x) * 1.5 + 0.006, abs(fract(q.x + 0.5) - 0.5));
		float gy = 1.0 - smoothstep(0.0, fwidth(q.y) * 1.5 + 0.006, abs(fract(q.y + 0.5) - 0.5));
		if (d.z <= d.x && d.z <= d.y) g = max(gx, gy);
		else if (d.y <= d.x) g = gx;
		else g = gy;
	} else {
		vec2 uv = UV * uv_lines;
		vec2 f = abs(fract(uv + 0.5) - 0.5) / fwidth(uv);
		e = 1.0 - clamp(min(f.x, f.y) - 0.6, 0.0, 1.0);
	}
	float s = stripes * step(0.55, fract((wpos.x + wpos.y) * 2.2));
	float l = max(e, g * grid_a);
	ALBEDO = mix(fill_col.rgb, line_col.rgb * bright, clamp(l * 1.4, 0.0, 1.0));
	ALPHA = clamp(max(l * line_col.a, fill_col.a * (1.0 + s * 0.9)), 0.0, 1.0);
}
