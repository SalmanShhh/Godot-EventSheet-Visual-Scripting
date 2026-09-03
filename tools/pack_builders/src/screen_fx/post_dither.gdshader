// Dither - the picture is squeezed down to a few levels per channel, and an ordered pattern decides
// which way each pixel rounds. That is how a two-colour screen drew a photograph, and it is what
// makes a modern render read as an old machine.
//
// One of the post stack's own effects. `strength` fades between the full-colour screen and the
// dithered one. It reads the screen, so it costs one screen read per pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How far towards the dithered picture. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// How many levels each channel keeps. 2 is one bit per channel; 8 is a gentle poster effect.
uniform float levels : hint_range(2.0, 32.0) = 4.0;

// How big one cell of the pattern is, in screen pixels - larger for a chunky look on a high
// resolution window.
uniform float dot_size : hint_range(1.0, 8.0) = 1.0;

// The ordered 4 by 4 threshold pattern, built from the cell coordinates rather than from a lookup
// image, so the shader needs no companion texture of its own. The interleave below is the standard
// ordering: the two bits of x and the two bits of y woven together give each cell in the tile its
// own place in the sequence 0 to 15.
float threshold_at(vec2 cell) {
	float x = mod(floor(cell.x), 4.0);
	float y = mod(floor(cell.y), 4.0);
	float x_low = mod(x, 2.0);
	float x_high = floor(x * 0.5);
	float y_low = mod(y, 2.0);
	float y_high = floor(y * 0.5);
	float place = x_low * 8.0 + y_low * 4.0 + x_high * 2.0 + y_high;
	return (place + 0.5) / 16.0;
}

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	vec2 cell = floor(FRAGCOORD.xy / max(dot_size, 1.0));
	float step_count = max(levels - 1.0, 1.0);
	float nudge = (threshold_at(cell) - 0.5) / step_count;
	vec3 dithered = floor(clamp(seen + vec3(nudge), vec3(0.0), vec3(1.0)) * step_count + 0.5) / step_count;
	COLOR = vec4(mix(seen, dithered, clamp(strength, 0.0, 1.0)), 1.0);
}
