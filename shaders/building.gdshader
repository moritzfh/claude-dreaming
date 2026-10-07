// Cliff-city blocks: cream stone with procedural windows, recessed doors and
// occasional coloured awnings. Works on scaled unit cubes (MultiMesh).
shader_type spatial;
render_mode diffuse_lambert_wrap;

uniform vec3 window_col : source_color = vec3(0.24, 0.20, 0.30);
uniform vec3 trim_col : source_color = vec3(0.78, 0.70, 0.66);
uniform vec3 awning_col : source_color = vec3(0.80, 0.32, 0.30);

varying vec3 lpos;
varying vec3 lnrm;
varying vec3 scl;
varying vec3 wpos;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	scl = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 col = base;
	if (abs(lnrm.y) < 0.5) {
		float u = abs(lnrm.x) > 0.5 ? lpos.z * scl.z : lpos.x * scl.x;
		float v = (lpos.y + 0.5) * scl.y;
		vec2 cell = vec2(2.4, 3.4);
		vec2 id = floor(vec2(u, v) / cell);
		vec2 f = fract(vec2(u, v) / cell);
		float h = hash(id + floor(wpos.xz * 0.37));
		float win = step(0.32, f.x) * step(f.x, 0.68) * step(0.30, f.y) * step(f.y, 0.78);
		win *= step(0.5, v) * step(v, scl.y - 1.2) * step(0.22, h);
		// arched top of windows
		float arch = 1.0 - smoothstep(0.0, 0.02, length(vec2((f.x - 0.5) * 1.4, max(f.y - 0.7, 0.0))) - 0.18);
		col = mix(col, window_col, win);
		// horizontal trim band per floor
		float band = smoothstep(0.03, 0.0, abs(f.y - 0.05));
		col = mix(col, trim_col * base, band * 0.5);
		// a few coloured awnings above windows
		float aw = step(0.93, h) * step(0.78, f.y) * step(f.y, 0.88) * step(0.26, f.x) * step(f.x, 0.74) * step(1.0, v);
		col = mix(col, awning_col, aw);
		// grime towards the ground
		col *= 0.86 + 0.14 * smoothstep(0.0, 6.0, v);
	} else {
		col = base * 0.92;
	}
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
