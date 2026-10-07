// Soft cloud wisps near the road (billboards in a MultiMesh), lit pink-white
// on top, lavender below, fading at the edges.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 col_top : source_color = vec3(1.0, 0.9, 0.97);
uniform vec3 col_bottom : source_color = vec3(0.55, 0.48, 0.9);
uniform float opacity = 0.75;
varying float seed;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void vertex() {
	seed = MODEL_MATRIX[3].x * 0.013 + MODEL_MATRIX[3].z * 0.007 + MODEL_MATRIX[3].y * 0.011;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float n = noise(UV * 3.5 + seed * 10.0 + TIME * 0.03) * 0.55 + noise(UV * 8.0 - seed * 7.0) * 0.3 + noise(UV * 17.0 + seed) * 0.15;
	// a lumpy top edge, a flatter bottom
	float shape = length(c * vec2(1.0, 1.15)) + (n - 0.5) * 0.55 - max(c.y, 0.0) * 0.15;
	float blob = 1.0 - smoothstep(0.45, 1.0, shape);
	vec3 col = mix(col_bottom, col_top, smoothstep(0.7, -0.5, c.y) * (0.6 + 0.4 * n));
	ALBEDO = col;
	ALPHA = blob * opacity;
}
