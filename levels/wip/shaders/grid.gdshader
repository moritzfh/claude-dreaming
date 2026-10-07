// The editor grid on the walking plane (visible in the empty cells while the
// level is paused), brightest around the cursor, and the outline of the cell
// the cursor points at.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec2 cursor = vec2(0.0);
uniform float amount = 1.0;
uniform vec4 col : source_color = vec4(1.0, 1.0, 1.0, 0.3);
uniform vec4 hover : source_color = vec4(1.0, 0.62, 0.2, 1.0);
uniform vec2 hover_cell = vec2(-999.0);
uniform vec2 hover_size = vec2(1.0);
uniform float hover_on = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xy;
	vec2 f = abs(fract(p - 0.5) - 0.5) / fwidth(p);
	float l = 1.0 - clamp(min(f.x, f.y) - 0.4, 0.0, 1.0);
	vec2 dc = p - cursor;
	float fade = exp(-dot(dc, dc) / 22.0) * 0.85 + 0.15;
	float a = l * col.a * fade * amount;
	vec2 lc = p - hover_cell;
	float inside = step(0.0, lc.x) * step(0.0, lc.y) * step(lc.x, hover_size.x) * step(lc.y, hover_size.y);
	float edge = min(min(lc.x, hover_size.x - lc.x), min(lc.y, hover_size.y - lc.y));
	float ho = inside * (1.0 - smoothstep(0.035, 0.035 + fwidth(edge) * 1.5, edge)) * hover_on;
	float fill = inside * hover_on * 0.10;
	ALBEDO = mix(col.rgb, hover.rgb * 1.3, max(ho, step(0.001, fill)));
	ALPHA = max(max(a, ho * hover.a), fill);
}
