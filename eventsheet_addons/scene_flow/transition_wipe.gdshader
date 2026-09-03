// Wipe - the cover sweeps in following a picture you chose.
//
// One of Scene Flow's transition shaders, driven by the one `progress` dial: 0 is the game showing,
// 1 is the game hidden.
//
// THE PICTURE IS THE SHAPE OF THE WIPE. Any greyscale image will do: the dark parts of it are
// covered first and the light parts last, so a left-to-right ramp is a bar wipe, a radial ramp is a
// clock, a splash of noise is a dissolve, and a hand-painted shape is whatever you painted. With no
// image at all it falls back to a plain left-to-right sweep, so the row works before you have drawn
// anything.
shader_type canvas_item;

// How covered the screen is. 0 is the game, 1 is nothing but the cover colour.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// What the screen is covered with.
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// The greyscale picture the sweep follows, and whether one was given at all (Scene Flow sets this
// when the row names an image, so the fallback sweep is not a texture nobody supplied).
uniform sampler2D wipe_image : hint_default_white, filter_linear;
uniform float use_image : hint_range(0.0, 1.0) = 0.0;

// How soft the moving edge is, as a fraction of the picture's own range.
uniform float softness : hint_range(0.0, 0.5) = 0.08;

void fragment() {
	float painted = dot(texture(wipe_image, UV).rgb, vec3(0.3333, 0.3333, 0.3333));
	float order = mix(UV.x, painted, clamp(use_image, 0.0, 1.0));
	// The edge is walked a little past 1 so the last pixel is covered exactly when progress lands.
	float covered = smoothstep(order, order + softness, clamp(progress, 0.0, 1.0) * (1.0 + softness));
	COLOR = vec4(cover_color.rgb, cover_color.a * covered);
}
