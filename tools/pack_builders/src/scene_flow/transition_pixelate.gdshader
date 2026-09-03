// Pixelate out - the picture comes apart into blocks and the blocks go to the cover colour.
//
// One of Scene Flow's transition shaders, driven by the one `progress` dial: 0 is the game showing,
// 1 is the game hidden.
//
// THIS ONE READS THE SCREEN BACK, unlike the flat transitions beside it: it costs one screen read
// per pixel of the viewport while it runs. It runs for as long as a transition lasts and no longer,
// so it is a beat of expense rather than a standing one.
shader_type canvas_item;

// Whatever has already been drawn this frame - the game the transition is covering.
uniform sampler2D screen : hint_screen_texture, filter_nearest;

// How covered the screen is. 0 is the game, 1 is nothing but the cover colour.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// What the blocks fade to.
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// How wide one block is at full progress, in screen pixels.
uniform float block_size : hint_range(2.0, 256.0) = 64.0;

void fragment() {
	float walk = clamp(progress, 0.0, 1.0);
	float block = max(mix(1.0, block_size, walk), 1.0);
	vec2 in_pixels = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 snapped = (floor(in_pixels / block) + 0.5) * block;
	vec3 chunky = texture(screen, snapped * SCREEN_PIXEL_SIZE).rgb;
	// The blocks grow first and drain to the cover colour late, so the picture is recognisable for
	// most of the walk and gone by the end of it.
	COLOR = vec4(mix(chunky, cover_color.rgb, walk * walk), step(0.001, walk));
}
