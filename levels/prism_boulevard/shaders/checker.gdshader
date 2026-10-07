// The start/finish line: a chequered band with a soft glow.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float cells_x = 16.0;
uniform float cells_y = 2.0;
void fragment() {
	vec2 c = floor(UV * vec2(cells_x, cells_y));
	float k = mod(c.x + c.y, 2.0);
	ALBEDO = mix(vec3(0.08, 0.05, 0.16), vec3(1.0, 0.98, 1.0) * 1.3, k);
}
