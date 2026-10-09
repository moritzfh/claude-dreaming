// Collectible thread spools (one MultiMesh): wound thread in the instance
// colour between two felt ends, bobbing and turning, with a soft glow.
// COLOR.a = 1 on the thread, 0 on the ends. INSTANCE_CUSTOM.r = phase.
shader_type spatial;
render_mode cull_back;

uniform vec4 end_col : source_color = vec4(0.96, 0.9, 0.78, 1.0);
uniform float glow = 0.25;

varying float v_thread;
varying vec3 v_tc;
varying vec3 v_lp;

void vertex() {
	float ph = INSTANCE_CUSTOM.r;
	float a = TIME * 1.8 + ph * 6.283;
	float c = cos(a);
	float s = sin(a);
	VERTEX = vec3(VERTEX.x * c - VERTEX.z * s, VERTEX.y, VERTEX.x * s + VERTEX.z * c);
	NORMAL = vec3(NORMAL.x * c - NORMAL.z * s, NORMAL.y, NORMAL.x * s + NORMAL.z * c);
	VERTEX.y += sin(TIME * 2.4 + ph * 6.283) * 0.06;
	v_lp = VERTEX;
	v_thread = COLOR.a;
	v_tc = COLOR.rgb;     // vertex colour (white) x the instance colour
}

void fragment() {
	float wound = 0.5 + 0.5 * sin(v_lp.y * 260.0 + atan(v_lp.z, v_lp.x) * 2.0);
	vec3 thread = v_tc * (0.82 + 0.25 * wound);
	vec3 alb = mix(end_col.rgb, thread, v_thread);
	ALBEDO = alb;
	ROUGHNESS = mix(0.9, 0.45, v_thread);
	SPECULAR = mix(0.2, 0.55, v_thread);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = v_tc * v_tc * (glow + rim * 0.9) * mix(0.3, 1.0, v_thread);
}
