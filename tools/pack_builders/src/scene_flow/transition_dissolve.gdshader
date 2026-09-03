// Dissolve - the screen breaks up into speckles and the speckles fill in.
//
// One of Scene Flow's transition shaders, driven by the one `progress` dial: 0 is the game showing,
// 1 is the game hidden. The noise is generated rather than sampled, so this transition needs no
// image and reads nothing back.
shader_type canvas_item;

// How covered the screen is. 0 is the game, 1 is nothing but the cover colour.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// What the screen is covered with.
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// How big one speckle is (higher is finer) and how soft its edge is.
uniform float noise_scale : hint_range(4.0, 400.0) = 90.0;
uniform float softness : hint_range(0.0, 0.5) = 0.12;

// A stable speckle per cell: the same cell gets the same number every frame, so the dissolve fills
// in rather than boiling.
float speckle(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float order = speckle(floor(UV * noise_scale));
	float covered = smoothstep(order, order + softness, clamp(progress, 0.0, 1.0) * (1.0 + softness));
	COLOR = vec4(cover_color.rgb, cover_color.a * covered);
}
