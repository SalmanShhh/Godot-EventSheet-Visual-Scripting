// Blend Modes - mask.
//
// A second picture decides where this one is allowed to be. The mask's ALPHA is what is read, so
// any sprite, any drawn shape, any texture with a transparent part works as one - a torn edge, a
// spotlight, a hole punched through a wall, a wipe that moves.
//
// This one does NOT read the screen: it only decides how much of the item's own pixel survives, so
// it costs one extra texture read per pixel and nothing else. It composes with an item's ordinary
// blend mode the way any material does, because the mask replaces the material rather than joining
// it - Unmask puts back whatever was worn before.
//
// `strength` walks between the item as it was (0) and the mask fully applied (1).
shader_type canvas_item;
render_mode unshaded;

// The shape that decides. Its alpha is what is read; its colour is ignored.
uniform sampler2D mask : filter_linear;

// Which of the five ways the two shapes meet. The numbers are the order the pack's own mode words
// are in, and the pack is the only thing that writes this.
//   0 inside   keep the item only where the mask is solid
//   1 outside  keep the item only where the mask is clear
//   2 atop     the mask's shape, painted with the item
//   3 behind   the item, with the mask filling in everywhere the item is not
//   4 xor      keep whichever of the two is alone, and drop where they meet
uniform int mask_mode : hint_range(0, 4) = 0;

// How far the mask goes: 0 leaves the item whole, 1 is the whole mask.
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 paint = texture(TEXTURE, UV) * COLOR;
	float shape = texture(mask, UV).a;
	float kept = paint.a;
	if (mask_mode == 0) {
		kept = paint.a * shape;
	} else if (mask_mode == 1) {
		kept = paint.a * (1.0 - shape);
	} else if (mask_mode == 2) {
		kept = shape;
	} else if (mask_mode == 3) {
		kept = paint.a + shape * (1.0 - paint.a);
	} else {
		kept = paint.a * (1.0 - shape) + shape * (1.0 - paint.a);
	}
	COLOR = vec4(paint.rgb, mix(paint.a, kept, clamp(strength, 0.0, 1.0)));
}
