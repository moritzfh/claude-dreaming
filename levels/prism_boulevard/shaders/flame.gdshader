// Exhaust flame puff (billboard particle, additive): blue-white normally,
// hot pink-orange during a boost.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float hot = 0.0;
varying float age;
void vertex() {
	age = INSTANCE_CUSTOM.y;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float d = dot(c, c);
	float a = exp(-d * 3.0);
	vec3 cold = mix(vec3(0.75, 0.9, 1.0), vec3(0.3, 0.55, 1.0), age);
	vec3 warm = mix(vec3(1.0, 0.95, 0.75), mix(vec3(1.0, 0.5, 0.2), vec3(1.0, 0.25, 0.8), age), smoothstep(0.0, 0.5, age));
	vec3 col = mix(cold, warm, hot);
	ALBEDO = col * a * (1.0 - age * 0.7) * (1.4 + hot * 2.0);
}
