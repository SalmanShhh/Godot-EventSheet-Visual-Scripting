// Iris - a circle closes over the picture, and opens again on the next one.
//
// One of Scene Flow's transition shaders, driven by the one `progress` dial: 0 is the game showing,
// 1 is the game hidden. The circle is round on any window shape, because the distance is measured
// with the viewport's aspect applied rather than in UV space.
shader_type canvas_item;

// How covered the screen is. 0 is the game, 1 is nothing but the cover colour.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// What the screen is covered with.
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Where the circle closes onto, in screen fractions - the middle by default, but a hero, a door or a
// keyhole is often the better spot.
uniform vec2 centre = vec2(0.5, 0.5);

// How soft the circle's edge is.
uniform float softness : hint_range(0.0, 0.5) = 0.02;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float out_from_centre = length((UV - centre) * vec2(aspect, 1.0));
	// The hole starts wider than any corner and closes past nothing, so both ends are complete.
	float hole = mix(1.5, -softness, clamp(progress, 0.0, 1.0));
	float covered = smoothstep(hole, hole + softness, out_from_centre);
	COLOR = vec4(cover_color.rgb, cover_color.a * covered);
}
