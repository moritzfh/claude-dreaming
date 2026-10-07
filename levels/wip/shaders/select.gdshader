// Editor selection: corner brackets of a box (like the editor's own gizmo),
// drawn on top of everything.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.62, 0.2, 1.0);
uniform vec3 size = vec3(1.0);
uniform float corner = 0.28;
uniform float edge_w = 0.045;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX * size;     // the mesh is a unit box, scaled to `size`
}

void fragment() {
	vec3 d = size * 0.5 - abs(lpos);
	float mn = min(d.x, min(d.y, d.z));
	float mx = max(d.x, max(d.y, d.z));
	float second = d.x + d.y + d.z - mn - mx;
	float e = 1.0 - smoothstep(edge_w, edge_w + fwidth(second) * 1.5, second);
	// only near the corners: the largest distance to a face is small there
	float c = 1.0 - smoothstep(corner, corner + 0.02, mx);
	ALBEDO = color.rgb * 1.4;
	ALPHA = e * max(c, 0.18) * color.a;
}
