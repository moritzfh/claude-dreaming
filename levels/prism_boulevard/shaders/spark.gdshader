// Drift spark (billboard particle, additive), coloured by the mini-turbo level.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(0.35, 0.75, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float core = exp(-dot(c, c) * 6.0);
	float cross_ = exp(-abs(c.x) * 14.0) * exp(-abs(c.y) * 2.0) + exp(-abs(c.y) * 14.0) * exp(-abs(c.x) * 2.0);
	ALBEDO = (color * 2.5 + vec3(1.0) * core) * (core + cross_ * 0.6) * 1.6;
}
