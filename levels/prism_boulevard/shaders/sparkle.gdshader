// Twinkling cross-shaped sparkle (billboard), additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.95, 0.85);
uniform float energy = 3.0;
uniform float speed = 1.0;
varying vec4 custom;
varying float iid;
void vertex() {
	custom = INSTANCE_CUSTOM;
	iid = float(INSTANCE_ID);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float ph = custom.x * 6.2831 + iid * 1.37;
	float tw = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TIME * speed * (1.0 + custom.y) + ph), 3.0);
	float cross_ = exp(-abs(c.x) * 26.0) * exp(-abs(c.y) * 2.6) + exp(-abs(c.y) * 26.0) * exp(-abs(c.x) * 2.6);
	float core = exp(-dot(c, c) * 18.0);
	float a = (cross_ * 0.8 + core) * tw;
	vec3 tint = mix(color, vec3(0.75, 0.85, 1.0), custom.z);
	ALBEDO = tint * a * energy * COLOR.rgb;
}
