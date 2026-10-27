// Desaturate - the colour drains out of the picture towards grey.
//
// One of the post stack's own effects: the stack gives every entry its own full-screen rectangle
// wearing one of these files, and turns `strength` from the rows. At 0 the screen arrives back
// exactly as it was drawn, which is the value an entry rests at; at 1 it is the same picture with no
// colour left in it at all.
//
// It reads the screen back, so it costs one screen read per pixel of the viewport while it is on.
shader_type canvas_item;

// Whatever has already been drawn this frame, including every post effect under this one.
uniform sampler2D screen : hint_screen_texture, filter_linear;

// How much colour is gone. 0 is the screen unchanged, 1 is grey.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// What is left of the picture as the colour goes: a tint the grey is pushed towards, so a danger
// moment can drain towards cold blue rather than towards flat grey.
uniform vec4 drain_towards : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	// The grey a person would see this colour as, by the weights the eye actually uses.
	float grey = dot(seen, vec3(0.2126, 0.7152, 0.0722));
	vec3 drained = vec3(grey) * drain_towards.rgb;
	COLOR = vec4(mix(seen, drained, clamp(strength, 0.0, 1.0)), 1.0);
}
