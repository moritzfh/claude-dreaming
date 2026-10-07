// Painterly terrain: lush grass, lavender-grey rock on steep slopes, sandy river banks,
// striped flower terraces in the valley.
shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform sampler2D noise_a : filter_linear_mipmap, repeat_enable;   // large variation
uniform sampler2D noise_b : filter_linear_mipmap, repeat_enable;   // brush detail
uniform vec3 grass_a : source_color = vec3(0.30, 0.52, 0.16);
uniform vec3 grass_b : source_color = vec3(0.56, 0.68, 0.24);
uniform vec3 grass_c : source_color = vec3(0.26, 0.46, 0.22);
uniform vec3 rock_a : source_color = vec3(0.40, 0.42, 0.42);
uniform vec3 rock_b : source_color = vec3(0.25, 0.28, 0.30);
uniform vec3 sand : source_color = vec3(0.60, 0.52, 0.44);
uniform vec3 field_pink : source_color = vec3(0.86, 0.58, 0.70);
uniform vec3 field_purple : source_color = vec3(0.55, 0.42, 0.75);
uniform float water_y = 0.4;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = wpos.xz;
	float na = texture(noise_a, p * 0.0025).r;
	float nb = texture(noise_b, p * 0.045).r;
	float nc = texture(noise_b, p * 0.22 + vec2(0.3, 0.7)).r;
	float dist = length(wpos - CAMERA_POSITION_WORLD);

	// grass with large patches + brush detail
	vec3 g = mix(grass_c, grass_a, smoothstep(0.25, 0.6, na));
	g = mix(g, grass_b, smoothstep(0.55, 0.85, na + nb * 0.3 - 0.1));
	g *= 0.88 + nc * 0.24 * (1.0 - smoothstep(30.0, 200.0, dist));
	// tiny wild-flower specks on meadows near the camera
	float speck = step(0.985, hash(floor(p * 3.0))) * (1.0 - smoothstep(10.0, 60.0, dist));

	// flower terraces in the valley (left side), soft pink/purple stripes
	float terr_mask = smoothstep(-40.0, -90.0, p.x) * smoothstep(-80.0, -100.0, p.y) * (1.0 - smoothstep(-200.0, -230.0, p.y)) * (1.0 - smoothstep(-260.0, -300.0, p.x));
	terr_mask *= smoothstep(12.0, 6.0, wpos.y);
	float stripe = smoothstep(0.35, 0.5, fract(p.y * 0.12 + na * 2.0)) * (1.0 - smoothstep(0.75, 0.9, fract(p.y * 0.12 + na * 2.0)));
	vec3 fc = mix(field_pink, field_purple, smoothstep(0.4, 0.7, nb));
	g = mix(g, mix(g * 0.85, fc, stripe), terr_mask);

	// rock on steep slopes, with vertical striations
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float stri = texture(noise_b, vec2(p.x + p.y, wpos.y * 0.15) * vec2(0.08, 0.02)).r;
	vec3 r = mix(rock_b, rock_a, smoothstep(0.3, 0.7, stri + nb * 0.3));
	float rock_t = smoothstep(0.32, 0.5, slope + (nb - 0.5) * 0.15);
	vec3 col = mix(g, r, rock_t);
	// mossy tops of rock
	col = mix(col, grass_c * 0.9, rock_t * smoothstep(0.55, 0.8, stri) * 0.4);

	// sandy banks near the water line
	float bank = 1.0 - smoothstep(water_y + 0.2, water_y + 1.0 + nb * 0.8, wpos.y);
	col = mix(col, sand * (0.9 + nb * 0.2), bank * (1.0 - rock_t * 0.5));
	col = mix(col, sand * 0.6, 1.0 - smoothstep(water_y - 2.0, water_y, wpos.y));

	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
