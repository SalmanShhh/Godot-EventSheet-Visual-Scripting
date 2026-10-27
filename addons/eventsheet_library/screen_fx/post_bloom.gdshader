// Bloom - the bright parts of the picture spill light into what is next to them.
//
// One of the post stack's own effects: the stack gives every entry its own full-screen rectangle
// wearing one of these files, and turns `strength` from the rows. At 0 the screen arrives back
// exactly as it was drawn, which is the value an entry rests at.
//
// THIS IS THE CHEAP KIND OF BLOOM, and it says so rather than pretending: the bright parts are
// gathered from eight taps around each pixel instead of from a proper downsampled chain, so a very
// small highlight can shimmer when the camera moves. It costs those taps plus the middle one - nine
// screen reads per pixel of the viewport while it is on, which is the most expensive entry the stack
// ships. A game that wants film-grade bloom wants a WorldEnvironment glow; a game that wants a win
// to feel bright wants this one row.
shader_type canvas_item;

// Whatever has already been drawn this frame, including every post effect under this one.
uniform sampler2D screen : hint_screen_texture, filter_linear;

// How much of the spill is added back. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// How bright a pixel has to be before it spills at all, and how far the spill reaches in screen
// widths. A high threshold blooms only lamps and sparks; a low one blooms the whole picture.
uniform float threshold : hint_range(0.0, 1.0) = 0.6;
uniform float spread : hint_range(0.0, 0.05) = 0.006;

// Only the part of a colour that is over the threshold, which is what is allowed to spill.
vec3 over_threshold(vec3 seen) {
	float bright = max(seen.r, max(seen.g, seen.b));
	return seen * max(bright - threshold, 0.0) / max(bright, 0.0001);
}

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	// Eight taps on a ring around the pixel, plus the pixel itself: the diagonals are pulled in by
	// 0.7 so every tap sits about the same distance away rather than the corners reaching further.
	vec3 spill = over_threshold(seen);
	spill += over_threshold(texture(screen, SCREEN_UV + vec2(spread, 0.0)).rgb);
	spill += over_threshold(texture(screen, SCREEN_UV - vec2(spread, 0.0)).rgb);
	spill += over_threshold(texture(screen, SCREEN_UV + vec2(0.0, spread)).rgb);
	spill += over_threshold(texture(screen, SCREEN_UV - vec2(0.0, spread)).rgb);
	vec2 corner = vec2(spread, spread) * 0.7;
	spill += over_threshold(texture(screen, SCREEN_UV + corner).rgb);
	spill += over_threshold(texture(screen, SCREEN_UV - corner).rgb);
	spill += over_threshold(texture(screen, SCREEN_UV + vec2(corner.x, -corner.y)).rgb);
	spill += over_threshold(texture(screen, SCREEN_UV + vec2(-corner.x, corner.y)).rgb);
	COLOR = vec4(seen + spill * (strength / 9.0) * 2.0, 1.0);
}
