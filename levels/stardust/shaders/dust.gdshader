// Star-dust sparkle for particle trails: a soft dot with a four-point glint,
// tinted by the particle colour, always facing the camera.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float energy = 1.6;

void vertex() {
	// particle billboard that keeps the particle's scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float core = exp(-r * r * 10.0);
	float glint = (exp(-abs(d.x) * 18.0) + exp(-abs(d.y) * 18.0)) * max(0.0, 1.0 - r);
	float a = clamp(core + glint * 0.8, 0.0, 1.0) * COLOR.a;
	ALBEDO = mix(COLOR.rgb, vec3(1.0), core * 0.5) * energy * a;
	ALPHA = a;
}
