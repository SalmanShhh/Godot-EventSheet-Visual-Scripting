// Correct Colours For - the screen redrawn so that a player with one of the three common kinds of
// colour blindness can tell apart the colours that would otherwise land on top of each other. This
// one is FOR THE PLAYER: it belongs behind a settings row, not on by default.
//
// How it works: the colour is first put through the same simulation See As uses, the difference
// between what was drawn and what would be seen is the information that would be lost, and that
// difference is then pushed into the channels this viewer can still tell apart. The picture stops
// being accurate and starts being readable, which is the trade the setting is making.
//
// One of the post stack's own effects. `strength` fades the correction in. It reads the screen, so
// it costs one screen read per pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How far the correction goes. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// Which kind of vision to correct for: 0 none, 1 protanopia, 2 deuteranopia, 3 tritanopia. The
// order is the one the pack's own word list uses.
uniform int vision : hint_range(0, 3) = 0;

// How much of the lost information is pushed into each of the two channels that are left. The usual
// values, and worth turning down if the result is too lurid for the art.
uniform float spread_green : hint_range(0.0, 2.0) = 0.7;
uniform float spread_blue : hint_range(0.0, 2.0) = 0.7;

vec3 seen_as(vec3 colour, int kind) {
	if (kind == 1) {
		return vec3(
			dot(colour, vec3(0.567, 0.433, 0.0)),
			dot(colour, vec3(0.558, 0.442, 0.0)),
			dot(colour, vec3(0.0, 0.242, 0.758)));
	}
	if (kind == 2) {
		return vec3(
			dot(colour, vec3(0.625, 0.375, 0.0)),
			dot(colour, vec3(0.7, 0.3, 0.0)),
			dot(colour, vec3(0.0, 0.3, 0.7)));
	}
	if (kind == 3) {
		return vec3(
			dot(colour, vec3(0.95, 0.05, 0.0)),
			dot(colour, vec3(0.0, 0.433, 0.567)),
			dot(colour, vec3(0.0, 0.475, 0.525)));
	}
	return colour;
}

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	if (vision == 0) {
		COLOR = vec4(seen, 1.0);
	} else {
		vec3 lost = seen - seen_as(seen, vision);
		vec3 pushed = vec3(
			0.0,
			lost.r * spread_green + lost.g,
			lost.r * spread_blue + lost.b);
		vec3 readable = clamp(seen + pushed, vec3(0.0), vec3(1.0));
		COLOR = vec4(mix(seen, readable, clamp(strength, 0.0, 1.0)), 1.0);
	}
}
