shader_type canvas_item;

// Whatever has already been drawn this frame - the whole screen, sampled back.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

// How far the blur reaches. Zero is no blur at all, which is what it starts at.
uniform float blur : hint_range(0.0, 8.0) = 0.0;

void fragment() {
	COLOR = textureLod(screen, SCREEN_UV, blur);
}
