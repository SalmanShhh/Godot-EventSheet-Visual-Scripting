// Blend Modes - hue.
//
// Takes only the HUE from the item and leaves the brightness and the strength of the colour
// underneath alone - recolour a sprite without touching its shading.
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

// The four colour modes take a whole colour apart rather than working channel by channel, so they
// share these four helpers - the same brightness/saturation arithmetic every compositing tool uses.
float lum_of(vec3 colour) {
	return dot(colour, vec3(0.3, 0.59, 0.11));
}

vec3 clip_colour(vec3 colour) {
	float lum = lum_of(colour);
	float low = min(colour.r, min(colour.g, colour.b));
	float high = max(colour.r, max(colour.g, colour.b));
	if (low < 0.0) {
		colour = lum + (colour - lum) * lum / max(lum - low, 0.0001);
	}
	if (high > 1.0) {
		colour = lum + (colour - lum) * (1.0 - lum) / max(high - lum, 0.0001);
	}
	return colour;
}

vec3 with_lum(vec3 colour, float lum) {
	return clip_colour(colour + (lum - lum_of(colour)));
}

float sat_of(vec3 colour) {
	return max(colour.r, max(colour.g, colour.b)) - min(colour.r, min(colour.g, colour.b));
}

vec3 with_sat(vec3 colour, float sat) {
	float low = min(colour.r, min(colour.g, colour.b));
	float high = max(colour.r, max(colour.g, colour.b));
	if (high <= low) {
		return vec3(0.0);
	}
	return (colour - low) * sat / (high - low);
}

void fragment() {
	vec4 paint = texture(TEXTURE, UV) * COLOR;
	vec3 under = textureLod(screen, SCREEN_UV, 0.0).rgb;
	vec3 blended = with_lum(with_sat(paint.rgb, sat_of(under)), lum_of(under));
	COLOR = vec4(mix(under, blended, clamp(strength, 0.0, 1.0)), paint.a);
}
