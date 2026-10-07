// Paintings while stepping in or out of them: the picture with an adjustable
// saturation (the attic paints its tiny pictures a touch more colourful).
shader_type canvas_item;

uniform float sat = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(l), c.rgb, sat), c.a) * COLOR;
}
