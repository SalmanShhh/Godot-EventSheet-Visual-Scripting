// Letterbox - solid bars close in from the top and the bottom, so the picture sits in a wider frame.
// That is the cutscene shape, and walking the bars in and out is the cheapest way to say "this bit
// is a film".
//
// One of the post stack's own effects. `strength` is how far the bars have closed: 0 is no bars at
// all, 1 is the full frame. It reads the screen, so it costs one screen read per pixel of the
// viewport while it is on.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How far the bars have closed. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// How deep each bar is at full strength, as a fraction of the screen height, and what colour it is.
// Two soft edges rather than two hard ones when `feather` is turned up.
uniform float bar_depth : hint_range(0.0, 0.45) = 0.12;
uniform vec4 bar_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float feather : hint_range(0.0, 0.1) = 0.0;

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	float depth = bar_depth * clamp(strength, 0.0, 1.0);
	float edge = max(feather, 0.0005);
	// How far into a bar this pixel is, from whichever of the two edges is nearer.
	float from_top = smoothstep(depth, depth - edge, SCREEN_UV.y);
	float from_bottom = smoothstep(1.0 - depth, 1.0 - depth + edge, SCREEN_UV.y);
	float covered = clamp(from_top + from_bottom, 0.0, 1.0) * bar_colour.a;
	COLOR = vec4(mix(seen, bar_colour.rgb, covered), 1.0);
}
