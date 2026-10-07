// Plain glowing material (lamps, rings, star decorations).
shader_type spatial;
render_mode unshaded;
uniform vec3 color : source_color = vec3(1.0, 0.9, 0.6);
uniform float energy = 2.5;
uniform float rainbow = 0.0;
uniform float flow = 0.0;
varying vec3 lp;
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void vertex() { lp = VERTEX; }
void fragment() {
	float a = atan(lp.z, lp.x) / 6.2831;
	vec3 rb = hsv2rgb(vec3(fract(a + TIME * flow), 0.55, 1.0));
	ALBEDO = mix(color, rb, rainbow) * energy;
}
