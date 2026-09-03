// Vignette - the corners of the screen go dark, so the middle is where the eye goes.
//
// One of the post stack's own effects: the stack gives every entry its own full-screen rectangle
// wearing one of these files, and turns `strength` from the rows. At 0 the screen arrives back
// exactly as it was drawn, which is the value an entry rests at.
//
// It reads the screen back, so it costs one screen read per pixel of the viewport while it is on.
shader_type canvas_item;

// Whatever has already been drawn this frame, including every post effect under this one.
uniform sampler2D screen : hint_screen_texture, filter_linear;

// How dark the corners go. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// The colour the corners fall towards, and how gradually the darkening comes on. A low softness is
// a hard oval; a high one is a slow fall from the middle.
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float softness : hint_range(0.05, 1.5) = 0.7;

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	// Distance from the middle, with the corners at roughly 1, so the fall does not depend on how
	// wide the window is.
	float out_from_middle = length(SCREEN_UV - vec2(0.5)) * 1.4142;
	float shade = smoothstep(1.0 - softness, 1.0, out_from_middle) * strength;
	COLOR = vec4(mix(seen, vignette_color.rgb, shade * vignette_color.a), 1.0);
}
