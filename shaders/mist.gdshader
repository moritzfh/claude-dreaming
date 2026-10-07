// Soft billboard puff for waterfall mist / spray.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, shadows_disabled;

uniform vec3 col : source_color = vec3(1.0, 0.93, 0.88);
uniform float opacity = 0.5;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = dot(c, c);
	float a = exp(-r * 3.0) * (1.0 - smoothstep(0.7, 1.0, r));
	ALBEDO = col;
	EMISSION = col * 0.25;
	ALPHA = a * opacity * COLOR.a;
}
