// Wave - pushes the picture from side to side in a travelling sine, for water, heat and dizziness.
//
// The push is applied to the texture lookup rather than to the node, so nothing moves in the world:
// collisions, positions and physics are untouched and only the drawing ripples.
//
// The pack copies this file into your project on attach, so it is yours to edit.
shader_type canvas_item;

// How far the ripple pushes, as a share of the picture's width. 0 is still.
uniform float wave_strength : hint_range(0.0, 0.2) = 0.0;

// How many crests fit down the picture. More crests read as finer water.
uniform float wave_length : hint_range(0.5, 32.0) = 6.0;

// How fast the crests travel. 0 freezes the ripple where it stands.
uniform float wave_speed : hint_range(0.0, 20.0) = 4.0;

void fragment() {
	// The crest runs down the picture and pushes across it, which is what a flag or a heat haze
	// does. TIME is the engine's own clock, so two nodes wearing this stay in step.
	float push = sin(UV.y * wave_length * 6.28318 + TIME * wave_speed) * wave_strength;
	vec2 rippled = vec2(UV.x + push, UV.y);
	// Outside the picture there is nothing to sample, so a push that would read past the edge
	// reads the edge instead of wrapping a stripe of the far side back in.
	COLOR = texture(TEXTURE, clamp(rippled, vec2(0.0), vec2(1.0)));
}
