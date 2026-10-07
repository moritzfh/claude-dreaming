shader_type sky;
render_mode use_debanding;

// Sunset palette taken from the reference film
uniform vec3 zenith : source_color = vec3(0.30, 0.27, 0.66);
uniform vec3 upper : source_color = vec3(0.56, 0.45, 0.80);
uniform vec3 horizon_sun : source_color = vec3(1.0, 0.68, 0.38);
uniform vec3 horizon_away : source_color = vec3(0.92, 0.64, 0.66);
uniform vec3 sun_col : source_color = vec3(1.0, 0.72, 0.40);
uniform vec3 ground : source_color = vec3(0.70, 0.62, 0.66);
uniform vec3 streak_col : source_color = vec3(1.0, 0.86, 0.90);
uniform sampler2D streak_noise : filter_linear_mipmap, repeat_enable;
uniform float streak_amount = 0.55;
uniform float brightness = 1.0;

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 L = normalize(LIGHT0_DIRECTION);
	float s = max(dot(d, L), 0.0);
	vec2 dh = normalize(d.xz + vec2(1e-5));
	vec2 lh = normalize(L.xz + vec2(1e-5));
	float az = dot(dh, lh) * 0.5 + 0.5;          // 1 = towards the sun

	vec3 hor = mix(horizon_away, horizon_sun, pow(az, 1.6));
	vec3 col = mix(hor, upper, smoothstep(0.0, 0.32, h));
	col = mix(col, zenith, smoothstep(0.30, 0.95, h));

	// warm glow around the sun, stronger close to the horizon
	float glow = pow(s, 5.0) * 0.45 + pow(s, 40.0) * 0.7 + pow(s, 400.0) * 2.5;
	col += sun_col * glow * (1.0 - smoothstep(0.0, 0.7, h) * 0.5);
	// sun disc
	col += sun_col * smoothstep(0.99955, 0.99975, s) * 30.0;

	// painterly cirrus streaks
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12);
		float n = texture(streak_noise, uv * vec2(0.035, 0.22) + vec2(0.13, 0.4)).r;
		float n2 = texture(streak_noise, uv * vec2(0.09, 0.6) + vec2(0.7, 0.2)).r;
		float st = smoothstep(0.52, 0.82, n * 0.75 + n2 * 0.35);
		st *= smoothstep(0.04, 0.22, h) * (1.0 - smoothstep(0.55, 0.95, h));
		vec3 sc = mix(streak_col, sun_col * 1.2, pow(az, 3.0) * 0.6);
		col = mix(col, sc, st * streak_amount);
	}

	// below horizon: hazy ground colour
	col = mix(col, mix(ground, hor, 0.5), smoothstep(0.0, -0.08, h));
	COLOR = col * brightness;
}
