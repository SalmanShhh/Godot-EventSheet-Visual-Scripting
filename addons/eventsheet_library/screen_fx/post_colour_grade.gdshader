// Colour grade - every colour on the screen is looked up in an image and replaced by what that
// image says it should be. One picture is the whole grade: warm, cold, bleached, night.
//
// The image is a colour lookup table laid out as a strip of squares: `lut_size` squares across, each
// one lut_size by lut_size, blue stepping one square at a time. That is the layout every grading
// tool exports, so a table made elsewhere drops straight in.
//
// AN UNSET TABLE IS NOT A GUESS. lut_size rests at 0, which means no table has been given, and the
// shader hands the screen back untouched however high strength is - rather than mapping every pixel
// through a blank white image and painting the screen white.
//
// It reads the screen, so it costs one screen read per pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How far towards the graded colours. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// The lookup table, and how many steps it holds per channel (16 and 32 are the usual ones). 0 means
// no table has been set yet.
uniform sampler2D grade_table : source_color, filter_linear;
uniform float lut_size : hint_range(0.0, 64.0) = 0.0;

// One colour, looked up in the strip. The two neighbouring blue squares are read and mixed, which is
// what stops a 16-step table banding.
vec3 graded(vec3 colour, float steps) {
	vec3 held = clamp(colour, vec3(0.0), vec3(1.0));
	float last = steps - 1.0;
	float blue = held.b * last;
	float low = floor(blue);
	float high = min(low + 1.0, last);
	// Where inside one square this colour sits: red across, green down, both pulled half a texel in
	// so the edges of a square are never sampled from its neighbour.
	vec2 inside = vec2(held.r, held.g) * (last / steps) + vec2(0.5 / steps);
	vec3 lower = texture(grade_table, vec2((low + inside.x) / steps, inside.y)).rgb;
	vec3 upper = texture(grade_table, vec2((high + inside.x) / steps, inside.y)).rgb;
	return mix(lower, upper, blue - low);
}

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	if (lut_size < 2.0) {
		COLOR = vec4(seen, 1.0);
	} else {
		COLOR = vec4(mix(seen, graded(seen, lut_size), clamp(strength, 0.0, 1.0)), 1.0);
	}
}
