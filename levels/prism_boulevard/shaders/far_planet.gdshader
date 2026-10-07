// Distant planets in the backdrop: soft banded gradient, terminator and a
// glowing atmosphere rim. Unshaded so they read like a painted backdrop.
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec3 col_a : source_color = vec3(0.95, 0.55, 0.40);
uniform vec3 col_b : source_color = vec3(0.65, 0.30, 0.55);
uniform vec3 atmo : source_color = vec3(1.0, 0.75, 0.6);
uniform vec3 light_dir = vec3(-0.6, 0.4, 0.5);
uniform float bands = 7.0;
varying vec3 lpos;
float h(float x) { return fract(sin(x * 91.7) * 4375.5); }
void vertex() { lpos = normalize(VERTEX); }
void fragment() {
	float wob = sin(lpos.x * 9.0 + lpos.z * 4.0) * 0.04;
	float b = 0.5 + 0.5 * sin((lpos.y + wob) * bands * 3.14159);
	vec3 c = mix(col_a, col_b, smoothstep(0.25, 0.75, b));
	vec3 wn = normalize((MODEL_MATRIX * vec4(lpos, 0.0)).xyz);
	float l = dot(wn, normalize(light_dir));
	float lit = smoothstep(-0.25, 0.35, l);
	c *= mix(0.12, 1.0, lit);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	c += atmo * fres * (0.25 + 0.75 * lit);
	ALBEDO = c;
}
