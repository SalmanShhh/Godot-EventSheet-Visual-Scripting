// Pixelate - the picture is resampled into big square blocks, so the whole screen goes chunky.
//
// One of the post stack's own effects. `strength` fades between the sharp screen and the blocky one,
// which is what makes it usable as a transition rather than only as a look. It reads the screen, so
// it costs one screen read per pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How far towards blocky. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// How wide one block is at full strength, in screen pixels.
uniform float pixel_size : hint_range(1.0, 64.0) = 8.0;

void fragment() {
	vec3 sharp = texture(screen, SCREEN_UV).rgb;
	// The block size grows with strength, so a fade from 0 reads as the picture coming apart rather
	// than as a cut between two pictures.
	float block = max(mix(1.0, pixel_size, clamp(strength, 0.0, 1.0)), 1.0);
	vec2 in_pixels = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 snapped = (floor(in_pixels / block) + 0.5) * block;
	vec3 chunky = texture(screen, snapped * SCREEN_PIXEL_SIZE).rgb;
	COLOR = vec4(mix(sharp, chunky, clamp(strength, 0.0, 1.0)), 1.0);
}
