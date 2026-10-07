// Lush grass blades with wind and back-lighting.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 root_col : source_color = vec3(0.10, 0.24, 0.07);
uniform vec3 mid_col : source_color = vec3(0.26, 0.50, 0.14);
uniform vec3 tip_col : source_color = vec3(0.46, 0.68, 0.22);
uniform sampler2D wind_noise : filter_linear_mipmap, repeat_enable;
uniform float wind_strength = 0.22;
global uniform vec3 player_pos;

varying float hgt;
varying float var_c;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hgt = UV.y;
	var_c = INSTANCE_CUSTOM.x;
	float wn = texture(wind_noise, w.xz * 0.02 + vec2(TIME * 0.05, TIME * 0.03)).r;
	float sway = (wn - 0.4) * wind_strength * hgt * hgt;
	vec3 offs = vec3(sway, 0.0, sway * 0.6);
	// bend away from the player
	vec3 d = w - player_pos;
	float pd = length(d.xz);
	offs.xz += normalize(d.xz + 1e-4) * (1.0 - smoothstep(0.3, 1.0, pd)) * 0.35 * hgt;
	offs.y -= (1.0 - smoothstep(0.3, 1.0, pd)) * 0.15 * hgt;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offs, 0.0)).xyz;
	// round-ish normals so clumps shade like volume
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6));
}

void fragment() {
	vec3 tip = mix(tip_col, vec3(0.80, 0.80, 0.32), smoothstep(0.8, 1.0, var_c) * 0.5);
	vec3 c = mix(root_col, mid_col, smoothstep(0.0, 0.45, hgt));
	c = mix(c, tip, smoothstep(0.45, 1.0, hgt));
	c *= 0.85 + var_c * 0.3;
	ALBEDO = c;
	ROUGHNESS = 0.6;
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.35;
	AO = mix(0.35, 1.0, hgt);
	AO_LIGHT_AFFECT = 0.4;
}
