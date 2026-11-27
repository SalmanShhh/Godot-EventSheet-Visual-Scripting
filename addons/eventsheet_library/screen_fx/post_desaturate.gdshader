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

// A circle for the grey to spread through, for the Grayscale rows. `reach` is its radius in screen
// pixels around `centre` (0 to 1 across and down); below 0 there is no circle and the whole screen drains,
// which is what every row that does not set it has always had.
uniform vec2 centre = vec2(0.5, 0.5);
uniform float reach = -1.0;
// How soft the circle's edge is, 0 sharp to 1 fading across the whole radius.
uniform float softness : hint_range(0.0, 1.0) = 0.2;
// On: colour inside the circle and grey outside it.
uniform bool colour_inside = false;

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	// The grey a person would see this colour as, by the weights the eye actually uses.
	float grey = dot(seen, vec3(0.2126, 0.7152, 0.0722));
	vec3 drained = vec3(grey) * drain_towards.rgb;
	float share = 1.0;
	if (reach >= 0.0) {
		float away = length((SCREEN_UV - centre) / SCREEN_PIXEL_SIZE);
		float edge = max(reach, 0.0001);
		float soft = max(clamp(softness, 0.0, 1.0) * edge, 0.5);
		share = 1.0 - smoothstep(edge - soft, edge, away);
		if (colour_inside) {
			share = 1.0 - share;
		}
	}
	COLOR = vec4(mix(seen, drained, clamp(strength, 0.0, 1.0) * share), 1.0);
}
