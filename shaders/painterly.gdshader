// Oil-paint screen filter for "the painting comes alive" (the look itself is
// in painterly_core.gdshaderinc, shared with the paintings in the attic).
shader_type canvas_item;

#include "res://shaders/painterly_core.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// one 1080p pixel in uv, and the mip level that matches it
	vec2 unit = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) / 1080.0;
	float lod0 = max(0.0, log2(1.0 / (SCREEN_PIXEL_SIZE.y * 1080.0)));
	vec3 col = paint(screen_tex, SCREEN_UV, unit, lod0, SCREEN_UV, unit, amount);
	vec3 orig = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	COLOR = vec4(mix(orig, col, amount), 1.0);
}
