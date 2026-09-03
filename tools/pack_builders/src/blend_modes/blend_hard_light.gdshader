// Blend Modes - hard light.
//
// Overlay the other way round: the ITEM decides which half of the curve each pixel takes. A
// harsher, more contrasty stamp than overlay.
//
// THE COST, said once: the item reads back what has already been drawn under it
// (`hint_screen_texture`), blends its own pixel into that, and draws the answer. That is one
// screen read for every pixel the item covers, every frame it is visible - a look for the few
// things that want it rather than for every sprite in the scene. It also means the item has to
// be drawn AFTER whatever it is blending with: later in the tree, or on a higher z index.
//
// `strength` walks between what was already on the screen (0) and the whole mode (1), so the
// same shader fades a look in without a second one.
shader_type canvas_item;
// Unshaded: the pixels under this item have already been lit, so lighting them again through
// the item would light them twice.
render_mode unshaded;

// Whatever has already been drawn this frame, sampled back.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

// How far the blend goes: 0 leaves the screen as it was, 1 is the whole mode.
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 paint = texture(TEXTURE, UV) * COLOR;
	vec3 under = textureLod(screen, SCREEN_UV, 0.0).rgb;
	vec3 blended = mix(
		2.0 * under * paint.rgb,
		1.0 - 2.0 * (1.0 - under) * (1.0 - paint.rgb),
		step(0.5, paint.rgb));
	COLOR = vec4(mix(under, blended, clamp(strength, 0.0, 1.0)), paint.a);
}
