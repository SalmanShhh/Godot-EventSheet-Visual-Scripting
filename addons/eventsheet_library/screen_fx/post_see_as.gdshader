// See As - the screen redrawn the way a player with one of the three common kinds of colour
// blindness sees it. This one is FOR THE DESIGNER: turn it on, walk the level, and the health bar
// that vanishes into the background is the bug you came to find.
//
// The three matrices are the usual published approximation for a viewer missing one cone type
// entirely. They are approximations of a thing that varies between people, which is why the row that
// turns this on is a check and not a certificate.
//
// One of the post stack's own effects. `strength` fades between the true screen and the simulated
// one, so half way is a useful comparison. It reads the screen, so it costs one screen read per
// pixel of the viewport.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;

// How far towards the simulation. 0 is the true screen.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// Which kind of vision: 0 normal, 1 protanopia (no red cone), 2 deuteranopia (no green cone),
// 3 tritanopia (no blue cone). The order is the one the pack's own word list uses.
uniform int vision : hint_range(0, 3) = 0;

// What one of the three kinds of vision makes of a colour.
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
	vec3 simulated = seen_as(seen, vision);
	COLOR = vec4(mix(seen, simulated, clamp(strength, 0.0, 1.0)), 1.0);
}
