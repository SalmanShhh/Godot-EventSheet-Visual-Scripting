// Scanlines - dark horizontal lines across the picture, the way a tube television drew one.
//
// One of the post stack's own effects. `strength` is how dark the lines are; 0 hands the screen back
// untouched. It reads the screen, so it costs one screen read per pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How dark the lines go. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// How many lines fit down the screen, and how fast they crawl. A roll_speed of 0 holds them still,
// which is what a pixel-art game usually wants.
uniform float line_count : hint_range(20.0, 1200.0) = 240.0;
uniform float roll_speed : hint_range(-4.0, 4.0) = 0.0;

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	float phase = SCREEN_UV.y * line_count + TIME * roll_speed;
	// A soft wave rather than hard bars, so the lines survive being scaled to any window size.
	float line = 0.5 + 0.5 * cos(phase * 6.2831853);
	COLOR = vec4(seen * (1.0 - line * strength), 1.0);
}
