// Dissolve - burns a sprite away along a noise field, with a glowing edge where it is burning.
//
// The noise is generated here rather than sampled from a texture, so the pack ships one file and
// needs no art. It is smoothed value noise: a random number per cell of a grid, blended between
// cells, which is what gives the burn soft blotches instead of television static.
//
// The pack copies this file into your project on attach, so it is yours to edit.
shader_type canvas_item;

// How much of the sprite has burned away. 0 is whole, 1 is gone.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

// The colour the burning edge glows.
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);

// How wide the glowing edge is. 0 burns with a hard edge and no glow at all.
uniform float edge_width : hint_range(0.0, 0.4) = 0.08;

// How large the burn's blotches are. Small numbers burn away in big patches, large numbers in
// speckles.
uniform float noise_scale : hint_range(1.0, 64.0) = 12.0;

// One random number per grid cell, from the cell's own coordinates. Deterministic: the same sprite
// burns the same way every run, which is what makes a burn art-directable.
float cell_value(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

// Smoothed value noise: the four cells around a point, blended with a curve that has no corners.
float burn_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 within = fract(point);
	vec2 blend = within * within * (3.0 - 2.0 * within);
	float bottom = mix(cell_value(cell), cell_value(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(cell_value(cell + vec2(0.0, 1.0)), cell_value(cell + vec2(1.0, 1.0)), blend.x);
	return mix(bottom, top, blend.y);
}

void fragment() {
	vec4 drawn = texture(TEXTURE, UV);
	float burn = burn_noise(UV * noise_scale);
	// The burn front is pushed past 1 so a dissolve of exactly 1 clears even the highest noise
	// value: without the headroom the last speckles never go.
	float front = clamp(dissolve, 0.0, 1.0) * (1.0 + edge_width);
	float gone = step(burn, front - edge_width);
	float glowing = step(burn, front) - gone;
	COLOR.rgb = mix(drawn.rgb, edge_color.rgb, glowing * edge_color.a);
	COLOR.a = drawn.a * (1.0 - gone);
}
