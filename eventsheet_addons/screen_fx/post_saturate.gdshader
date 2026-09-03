// Saturate - the colours get stronger, without anything else about the picture changing.
//
// One of the post stack's own effects: the stack gives every entry its own full-screen rectangle
// wearing one of these files, and turns `strength` from the rows. At 0 the screen arrives back
// exactly as it was drawn, which is the value an entry rests at.
//
// It reads the screen back, so it costs one screen read per pixel of the viewport while it is on.
shader_type canvas_item;

// Whatever has already been drawn this frame, including every post effect under this one.
uniform sampler2D screen : hint_screen_texture, filter_linear;

// How far towards the boosted colours. 0 is the screen unchanged.
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// What full strength means: 1 is no change at all, 2 is twice as colourful. Left as a dial because
// "more colour" is a matter of taste and of what the game already looks like.
uniform float saturation : hint_range(1.0, 3.0) = 1.8;

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	// The grey a person would see this colour as, by the weights the eye actually uses - so pushing
	// away from it brightens the colour rather than the picture.
	float grey = dot(seen, vec3(0.2126, 0.7152, 0.0722));
	vec3 boosted = mix(vec3(grey), seen, saturation);
	COLOR = vec4(clamp(mix(seen, boosted, clamp(strength, 0.0, 1.0)), vec3(0.0), vec3(1.0)), 1.0);
}
