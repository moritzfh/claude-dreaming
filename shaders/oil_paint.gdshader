// A picture painted in oil: the same look as the screen filter, with brush
// strokes the size they have on screen – so a painting that fills the whole
// screen looks exactly like the filtered 3D view behind it.
shader_type canvas_item;

#include "res://shaders/painterly_core.gdshaderinc"

uniform sampler2D src : filter_linear_mipmap;   // the picture, with mipmaps
uniform vec2 src_size = vec2(1280.0, 720.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 sunit = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) / 1080.0;
	// picture uv per screen pixel → per 1080p pixel
	vec2 duv = vec2(abs(dFdx(UV.x)), abs(dFdy(UV.y)));
	vec2 unit = duv / (SCREEN_PIXEL_SIZE.y * 1080.0);
	float lod0 = max(0.0, log2(unit.y * src_size.y));
	vec3 col = paint(src, UV, unit, lod0, SCREEN_UV, sunit, amount);
	vec3 orig = textureLod(src, UV, max(0.0, log2(duv.y * src_size.y))).rgb;
	COLOR = vec4(mix(orig, col, amount), COLOR.a);
}
