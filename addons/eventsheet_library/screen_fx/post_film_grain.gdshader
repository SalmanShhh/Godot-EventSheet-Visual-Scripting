// Film grain - a fine, moving speckle over the whole picture, the way film stock looks.
//
// One of the post stack's own effects. `strength` is how visible the speckle is; 0 hands the screen
// back untouched. It reads the screen, so it costs one screen read per pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How visible the grain is. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// How big one speck is, in screen pixels, and how fast the pattern is replaced. A grain_size of 1
// is per-pixel noise; 3 or 4 reads as film rather than as a broken screen.
uniform float grain_size : hint_range(1.0, 8.0) = 2.0;
uniform float grain_speed : hint_range(0.0, 60.0) = 24.0;

// A cheap, stable hash: the same cell asked for the same frame always answers the same, so the
// grain does not shimmer within one frame.
float speck(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	vec2 cell = floor(FRAGCOORD.xy / max(grain_size, 1.0));
	// The frame number rather than the clock, so the pattern steps rather than sliding.
	float frame = floor(TIME * max(grain_speed, 0.001));
	float noise = speck(cell + vec2(frame, frame * 1.7)) - 0.5;
	COLOR = vec4(clamp(seen + vec3(noise) * strength * 0.5, vec3(0.0), vec3(1.0)), 1.0);
}
