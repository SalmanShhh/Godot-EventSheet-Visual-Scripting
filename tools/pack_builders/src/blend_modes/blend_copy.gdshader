// Blend Modes - copy.
//
// No blending at all: the item's own colour, put down over what is under it, ignoring it
// entirely. It is here so a look can be turned off without taking the material away, and so
// strength fades from a blend to a plain draw.
//
// THE COST, said once: the item reads back what has already been drawn under it
// (`hint_screen_texture`), blends its own pixel into that, and draws the answer. That is one
// screen read for every pixel the item covers, every frame it is visible - and the read itself
// costs more than that sentence suggests. Godot serves `hint_screen_texture` out of a BackBufferCopy
// of the WHOLE viewport, taken per blending item, so ten blended sprites are ten full-screen copies
// however small each sprite is. That is a look for the few things that want it rather than for
// every sprite in the scene. It also means the item has to be drawn AFTER whatever it is blending
// with: later in the tree, or on a higher z index.
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
	vec3 blended = paint.rgb;
	COLOR = vec4(mix(under, blended, clamp(strength, 0.0, 1.0)), paint.a);
}
