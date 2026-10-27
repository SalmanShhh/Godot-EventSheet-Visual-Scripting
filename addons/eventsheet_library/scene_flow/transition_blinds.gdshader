// Blinds - bars close across the screen like a shutter.
//
// One of Scene Flow's transition shaders, driven by the one `progress` dial: 0 is the game showing,
// 1 is the game hidden. It reads nothing back.
shader_type canvas_item;

// How covered the screen is. 0 is the game, 1 is nothing but the cover colour.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// What the screen is covered with.
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// How many bars there are, whether they run across or up and down, and how soft each edge is.
uniform float bars : hint_range(1.0, 60.0) = 12.0;
uniform float vertical : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.0, 0.5) = 0.03;

void fragment() {
	float along = mix(UV.y, UV.x, clamp(vertical, 0.0, 1.0));
	// Where in its own bar this pixel sits: every bar therefore closes at the same time as the rest.
	float in_bar = fract(along * bars);
	float covered = smoothstep(in_bar, in_bar + softness, clamp(progress, 0.0, 1.0) * (1.0 + softness));
	COLOR = vec4(cover_color.rgb, cover_color.a * covered);
}
