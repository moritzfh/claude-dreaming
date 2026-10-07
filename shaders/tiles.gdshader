// Stone paving in running bond, aligned to the (scaled) path box.
shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform vec3 stone_a : source_color = vec3(0.84, 0.82, 0.86);
uniform vec3 stone_b : source_color = vec3(0.76, 0.73, 0.79);
uniform vec3 grout : source_color = vec3(0.42, 0.39, 0.48);
uniform vec2 tile = vec2(1.15, 0.75);
uniform sampler2D noise_b : filter_linear_mipmap, repeat_enable;

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 scl;
varying vec3 wpos;

void vertex() {
	lpos = VERTEX; lnrm = NORMAL;
	scl = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 q = lpos.xz * scl.xz;
	if (abs(lnrm.y) < 0.5) q = vec2(abs(lnrm.x) > 0.5 ? lpos.z * scl.z : lpos.x * scl.x, lpos.y * scl.y * 3.0);
	float row = floor(q.y / tile.y);
	q.x += mod(row, 2.0) * tile.x * 0.5;
	vec2 id = floor(q / tile);
	vec2 f = fract(q / tile);
	float h = hash(id);
	vec2 e = min(f, 1.0 - f) * tile;
	float edge = min(e.x, e.y);
	float g = smoothstep(0.02, 0.045, edge);
	float n = texture(noise_b, wpos.xz * 0.35).r;
	vec3 st = mix(stone_a, stone_b, h * 0.8 + n * 0.3) * (0.95 + h * 0.08);
	st *= 0.9 + 0.1 * smoothstep(0.0, 0.2, edge);   // worn bevel
	ALBEDO = mix(grout, st, g);
	// bevel normal: tilt towards tile centre near edges
	vec2 dir = vec2(f.x < 0.5 ? -1.0 : 1.0, f.y < 0.5 ? -1.0 : 1.0);
	float bx = 1.0 - smoothstep(0.0, 0.08, e.x);
	float by = 1.0 - smoothstep(0.0, 0.08, e.y);
	NORMAL_MAP = normalize(vec3(0.5 + dir.x * bx * 0.25, 0.5 + dir.y * by * 0.25, 1.0));
	ROUGHNESS = 0.75 - h * 0.1;
	SPECULAR = 0.35;
}
