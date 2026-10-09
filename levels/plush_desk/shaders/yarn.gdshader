// Chunky wool: a twisted strand (UV.x = metres along, UV.y = 0..1 around,
// as Geo.tube makes them) or thread wound round and round a core (object y).
shader_type spatial;
render_mode cull_back;

#include "res://levels/plush_desk/shaders/fabric_inc.gdshaderinc"

uniform float mode = 0.0;          // 0 strand, 1 wound
uniform float plies = 3.0;
uniform float twist = 1.1;         // strand: ply turns per metre
uniform float wind_pitch = 0.07;   // wound: thread thickness in metres
uniform vec4 albedo2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float two_tone = 0.0;      // strand: every other ply in albedo2
uniform float bands = 0.0;         // wound: colour bands of albedo2 every N metres

varying vec2 v_uv;

void vertex() {
	FABRIC_VERTEX
	v_uv = UV;
}

void fragment() {
	vec3 alb = albedo.rgb;
	float s;
	if (mode < 0.5) {
		s = (v_uv.y + v_uv.x * twist) * plies;
		if (two_tone > 0.5 && mod(floor(s), 2.0) > 0.5) alb = albedo2.rgb;
	} else {
		float ang = atan(v_opos.x, v_opos.z) / TAU;
		s = v_opos.y / wind_pitch + ang;
		// a second layer wound crosswise shows through here and there
		float cross = v_opos.y / (wind_pitch * 1.3) - ang * 9.0;
		float cr = smoothstep(0.62, 0.7, fract(cross)) * (1.0 - smoothstep(0.92, 1.0, fract(cross)));
		float patchy = texture(mottle_tex, vec2(ang * 3.0, v_opos.y * 0.08)).r;
		s = mix(s, cross, cr * step(0.55, patchy));
		if (bands > 0.0 && mod(floor(v_opos.y / bands), 2.0) > 0.5) alb = albedo2.rgb;
	}
	vec3 n;
	float ao;
	float h = fabric_surface(v_opos, v_onrm, v_o2v, alb, n, ao);
	float g = fract(s);
	float ridge = sin(g * PI);
	alb *= 0.72 + 0.32 * ridge;
	ao *= mix(0.55, 1.0, smoothstep(0.0, 0.45, ridge));
	ALBEDO = alb;
	NORMAL = n;
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = fabric_roughness;
	SPECULAR = 0.12;
}

void light() {
	fabric_light(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, ALBEDO, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
