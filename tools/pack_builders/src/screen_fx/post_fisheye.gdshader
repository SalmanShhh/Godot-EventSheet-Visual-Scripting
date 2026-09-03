// Fisheye - the picture bulges out of the middle the way a very wide lens sees, or pinches into it
// when the amount goes the other way.
//
// One of the post stack's own effects. `strength` is how far it bends; 0 is the flat screen. It
// reads the screen, so it costs one screen read per pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How far the picture bends. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// Which way, and how far in the picture is pulled to hide the edges the bend uncovers. A negative
// bulge pinches instead.
uniform float bulge : hint_range(-1.0, 1.0) = 1.0;
uniform float zoom : hint_range(0.8, 1.4) = 1.05;

void fragment() {
	vec2 from_middle = SCREEN_UV - vec2(0.5);
	float out_from_middle = length(from_middle) * 2.0;
	// The bend grows with the square of the distance out, which is what a lens does and is why the
	// middle of the picture stays where it was.
	float bent = 1.0 + bulge * strength * 0.35 * out_from_middle * out_from_middle;
	vec2 looked_up = vec2(0.5) + from_middle * bent / mix(1.0, zoom, clamp(strength, 0.0, 1.0));
	// Off the edge is the edge, rather than a wrapped copy of the far side of the screen.
	COLOR = vec4(texture(screen, clamp(looked_up, vec2(0.0), vec2(1.0))).rgb, 1.0);
}
