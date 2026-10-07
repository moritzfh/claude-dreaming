// "Colour without a name": an iridescent, shifting glow orb.
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 base : source_color = vec3(1.0, 0.5, 0.8);
uniform float energy = 4.0;
varying vec3 lpos;
void vertex() { lpos = VERTEX; }
vec3 hue(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float swirl = sin(lpos.y * 9.0 + TIME * 2.0 + sin(lpos.x * 7.0 + TIME) * 2.0) * 0.5 + 0.5;
	vec3 iri = hue(fract(swirl * 0.35 + fres * 0.6 + TIME * 0.07));
	vec3 c = mix(base, iri, 0.45 + fres * 0.4);
	ALBEDO = c;
	EMISSION = c * energy * (0.7 + swirl * 0.5) + vec3(1.0) * fres * energy * 0.4;
}
