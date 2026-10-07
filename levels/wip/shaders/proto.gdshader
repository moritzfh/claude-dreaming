// Prototype ("grey-box") material: a 1 m grid with faint quarter lines and a
// soft checker, the way levels look before anyone paints them. Orange for the
// placeholder pieces the player puts down.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 base : source_color = vec3(0.70, 0.71, 0.73);
uniform vec3 line_col : source_color = vec3(0.42, 0.43, 0.46);
uniform float checker = 0.05;
uniform vec3 shadow_tint : source_color = vec3(0.55, 0.56, 0.68);
uniform float glow = 0.0;
// shift the grid so a placed 1 m block shows exactly one square per face
uniform vec3 grid_offset = vec3(0.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 p, float every, float width) {
	vec2 q = p / every;
	vec2 g = abs(fract(q - 0.5) - 0.5) / fwidth(q);
	return 1.0 - clamp(min(g.x, g.y) - width, 0.0, 1.0);
}

void fragment() {
	vec3 n = abs(wnorm);
	vec3 w = wpos + grid_offset;
	vec2 p = n.y > 0.6 ? w.xz : (n.x > 0.6 ? w.zy : w.xy);
	float chk = mod(floor(p.x + 0.001) + floor(p.y + 0.001), 2.0);
	vec3 col = base * (1.0 - checker * chk);
	col = mix(col, line_col, grid_line(p, 0.25, 0.0) * 0.18);
	col = mix(col, line_col, grid_line(p, 1.0, 0.6) * 0.85);
	// top faces a touch lighter, like the usual prototype textures
	col *= 1.0 + 0.06 * step(0.6, wnorm.y);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	EMISSION = col * glow;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.05, 0.25, ndl) * mix(0.35, 1.0, ATTENUATION);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * mix(shadow_tint * 0.85, vec3(1.0), t) / PI;
}
