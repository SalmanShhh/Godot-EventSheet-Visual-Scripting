// Glitch - horizontal bands of the picture jump sideways and their colour channels come apart, the
// way a broken signal looks. A short one reads as damage; a held one reads as a machine failing.
//
// One of the post stack's own effects. `strength` is how badly it breaks; 0 is the clean screen. It
// reads the screen, so it costs one screen read per pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How badly the picture breaks. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// How tall one band is (as a fraction of the screen), how far a band can jump, and how far the
// colour channels come apart.
uniform float band_height : hint_range(0.005, 0.5) = 0.04;
uniform float jump : hint_range(0.0, 0.3) = 0.06;
uniform float colour_split : hint_range(0.0, 0.1) = 0.01;

// How often the pattern of bands is replaced. Low is a slow, sick roll; high is a hard stutter.
uniform float glitch_speed : hint_range(0.0, 40.0) = 12.0;

float band_noise(float band, float frame) {
	return fract(sin(band * 91.7 + frame * 37.13) * 43758.5453) - 0.5;
}

void fragment() {
	float frame = floor(TIME * max(glitch_speed, 0.001));
	float band = floor(SCREEN_UV.y / max(band_height, 0.001));
	// Only some bands move, so the picture stays readable between the tears.
	float picked = step(0.6 - strength * 0.4, fract(sin(band * 12.9898 + frame * 7.31) * 43758.5453));
	float shift = band_noise(band, frame) * jump * strength * picked;
	vec2 looked_up = clamp(SCREEN_UV + vec2(shift, 0.0), vec2(0.0), vec2(1.0));
	vec2 apart = vec2(colour_split * strength, 0.0);
	COLOR = vec4(
		texture(screen, clamp(looked_up + apart, vec2(0.0), vec2(1.0))).r,
		texture(screen, looked_up).g,
		texture(screen, clamp(looked_up - apart, vec2(0.0), vec2(1.0))).b,
		1.0);
}
