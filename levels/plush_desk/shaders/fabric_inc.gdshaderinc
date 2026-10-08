// Shared fabric shading for the Plush Desk.
// Object-space triplanar fibre normals (so the texture sticks to moving and
// stretched things), wrapped diffuse, a "Charlie" sheen lobe for the fuzz that
// catches light at grazing angles, and soft back-light through thin felt.

uniform vec4 albedo : source_color = vec4(0.8, 0.3, 0.3, 1.0);
uniform sampler2D fibre_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mottle_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float fibre_scale = 2.5;      // texture tiles per metre
uniform float fibre_strength = 1.0;
uniform float fibre_ao = 0.35;        // darken the valleys between fibres
uniform float mottle_scale = 0.35;
uniform float mottle_amount = 0.14;
uniform vec4 sheen_color : source_color = vec4(1.0, 0.92, 0.85, 1.0);
uniform float sheen = 0.9;
uniform float sheen_roughness : hint_range(0.07, 1.0) = 0.45;
uniform float wrap = 0.45;            // wrapped diffuse: soft, stuffed look
uniform float translucency = 0.12;
uniform float fabric_roughness = 0.92;

varying vec3 v_opos;
varying vec3 v_onrm;
varying mat3 v_o2v;     // object -> view rotation (includes MultiMesh instance)

// use in vertex(), after any change to VERTEX / NORMAL
#define FABRIC_VERTEX v_opos = VERTEX; v_onrm = NORMAL; v_o2v = mat3(MODELVIEW_MATRIX);

// whiteout-blended triplanar normal in object space; h = fibre height
vec3 fibre_normal(vec3 p, vec3 n, float sc, float strength, out float h) {
	vec3 bw = pow(abs(n), vec3(4.0));
	bw /= max(bw.x + bw.y + bw.z, 1e-4);
	vec3 tx = texture(fibre_tex, p.zy * sc).rgb;
	vec3 ty = texture(fibre_tex, p.xz * sc + vec2(0.37, 0.11)).rgb;
	vec3 tz = texture(fibre_tex, p.xy * sc + vec2(0.71, 0.53)).rgb;
	h = tx.b * bw.x + ty.b * bw.y + tz.b * bw.z;
	vec2 nx = (tx.rg * 2.0 - 1.0) * strength;
	vec2 ny = (ty.rg * 2.0 - 1.0) * strength;
	vec2 nz = (tz.rg * 2.0 - 1.0) * strength;
	vec3 a = vec3(nx + n.zy, abs(n.x));
	vec3 b = vec3(ny + n.xz, abs(n.y));
	vec3 c = vec3(nz + n.xy, abs(n.z));
	a.z *= sign(n.x) == 0.0 ? 1.0 : sign(n.x);
	b.z *= sign(n.y) == 0.0 ? 1.0 : sign(n.y);
	c.z *= sign(n.z) == 0.0 ? 1.0 : sign(n.z);
	return normalize(a.zyx * bw.x + b.xzy * bw.y + c.xyz * bw.z);
}

vec3 mottle(vec3 p, vec3 n) {
	vec3 bw = abs(n) / max(abs(n.x) + abs(n.y) + abs(n.z), 1e-4);
	vec3 m = texture(mottle_tex, p.zy * mottle_scale).rgb * bw.x
		+ texture(mottle_tex, p.xz * mottle_scale).rgb * bw.y
		+ texture(mottle_tex, p.xy * mottle_scale).rgb * bw.z;
	return m;
}

// standard fabric surface: sets the shading normal, returns fibre height
float fabric_surface(vec3 p, vec3 nrm, mat3 o2v, inout vec3 alb, out vec3 view_n, out float ao_out) {
	float h;
	vec3 on = fibre_normal(p, normalize(nrm), fibre_scale, fibre_strength, h);
	view_n = normalize(o2v * on);
	vec3 m = mottle(p, normalize(nrm));
	alb *= 1.0 + (m.r - 0.5) * 2.0 * mottle_amount;
	alb = mix(alb, alb * vec3(1.04, 0.98, 0.95), (m.g - 0.5) * mottle_amount * 2.0);
	ao_out = mix(1.0, smoothstep(0.0, 0.7, h), fibre_ao);
	return h;
}

float charlie_d(float roughness, float noh) {
	float inv_r = 1.0 / roughness;
	float sin2 = max(1.0 - noh * noh, 0.0078125);
	return (2.0 + inv_r) * pow(sin2, inv_r * 0.5) / (2.0 * PI);
}

float ashikhmin_v(float nov, float nol) {
	return clamp(1.0 / (4.0 * (nol + nov - nol * nov)), 0.0, 1.0);
}

// a glossy lobe for the non-fabric bits (sequins, buttons): GGX-ish
void gloss_light(vec3 N, vec3 V, vec3 L, vec3 lcol, float att, vec3 f0, float rough, inout vec3 specular) {
	vec3 H = normalize(L + V);
	float noh = clamp(dot(N, H), 0.0, 1.0);
	float nol = clamp(dot(N, L), 0.0, 1.0);
	float a = rough * rough;
	float a2 = a * a;
	float d = noh * noh * (a2 - 1.0) + 1.0;
	float D = a2 / (PI * d * d);
	specular += lcol * att * f0 * D * nol * 0.25;
}

// call from light()
void fabric_light(vec3 N, vec3 V, vec3 L, vec3 lcol, float att, vec3 alb,
		inout vec3 diffuse, inout vec3 specular) {
	float ndl = dot(N, L);
	float w = (ndl + wrap) / ((1.0 + wrap) * (1.0 + wrap));
	float d = max(w, 0.0);
	// a warm shift in the wrapped terminator, like light scattering in fibres
	vec3 term = mix(vec3(1.0), vec3(1.0, 0.82, 0.78), clamp(1.0 - abs(ndl) * 2.0, 0.0, 1.0) * 0.5);
	diffuse += lcol * att * d * term / PI;
	// thin fabric lets some light through from behind
	diffuse += lcol * att * max(-ndl, 0.0) * translucency / PI;
	vec3 H = normalize(L + V);
	float noh = clamp(dot(N, H), 0.0, 1.0);
	float nov = clamp(dot(N, V), 1e-3, 1.0);
	float nol = clamp(ndl, 0.0, 1.0);
	float sh = charlie_d(sheen_roughness, noh) * ashikhmin_v(nov, nol) * nol;
	specular += lcol * att * sh * sheen * sheen_color.rgb * mix(vec3(1.0), alb * 2.0, 0.35);
}
