// Fade - the screen goes to a flat colour and comes back out of it.
//
// One of Scene Flow's transition shaders. Every one of them is driven by ONE dial: `progress` is how
// covered the screen is, 0 for the game showing and 1 for the game hidden. Scene Flow walks it up
// over the first half of the transition, swaps the scene at the top, and walks it back down over the
// second half - so a shader only ever has to answer "how covered am I".
//
// This one reads nothing at all, which is why it is the default: it costs one flat rectangle.
shader_type canvas_item;

// How covered the screen is. 0 is the game, 1 is nothing but the cover colour.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// What the screen is covered WITH. Black for most games, white for a bright cut.
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	COLOR = vec4(cover_color.rgb, cover_color.a * clamp(progress, 0.0, 1.0));
}
