// "Sew here": a dashed, softly pulsing outline of a box where a patch goes.
// Draws only near the box's edges; the faces stay almost clear.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

instance uniform vec3 half_size = vec3(0.5);
instance uniform float hot = 0.0;      // 1 while Claude carries a patch nearby
uniform vec4 col : source_color = vec4(1.0, 0.95, 0.85, 1.0);

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 e = half_size - abs(lp);
	// the two smallest distances tell how close we are to an edge
	float a = min(e.x, min(e.y, e.z));
	float b = e.x + e.y + e.z - a - max(e.x, max(e.y, e.z));
	float edge = 1.0 - smoothstep(0.025, 0.05, b);
	float along = lp.x + lp.y + lp.z;
	float dash = step(0.45, fract(along * 4.0 - TIME * 0.8));
	float pulse = 0.55 + 0.45 * sin(TIME * 4.0);
	float alpha = edge * dash * (0.55 + 0.45 * hot) * pulse;
	alpha += 0.06 * (0.5 + 0.5 * hot) * pulse;
	ALBEDO = mix(col.rgb, vec3(1.0, 0.85, 0.4), hot);
	ALPHA = alpha;
}
