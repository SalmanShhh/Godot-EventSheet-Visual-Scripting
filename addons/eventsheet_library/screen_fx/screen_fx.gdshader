// Screen FX - the four full-screen effects, on one rectangle that samples what has already been
// drawn.
//
// A full-screen effect in Godot is a CanvasLayer holding a ColorRect whose shader reads
// `hint_screen_texture`: the rectangle covers the viewport, the shader is handed the frame so far,
// and whatever it writes is what the player sees. All four effects live in one shader on one
// rectangle so the screen is read once per frame rather than once per effect.
//
// Every dial rests at a value that draws the screen back unchanged, so a rectangle nobody has asked
// for anything costs one full-screen copy - which is why the pack hides the rectangle whenever every
// effect is idle, and costs nothing at all at rest.
shader_type canvas_item;

// Whatever has already been drawn this frame - the whole screen, sampled back.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

// How far the blur reaches, in mip levels of the screen. 0 is sharp.
uniform float blur : hint_range(0.0, 6.0) = 0.0;

// The colour the screen fades towards, and how far it has faded. 0 shows the game.
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;

// The shockwave ring: where it started (in screen coordinates, 0 to 1), how far it has travelled,
// and how hard it pushes. A strength of 0 is no ring.
uniform vec2 shock_center = vec2(0.5, 0.5);
uniform float shock_radius : hint_range(0.0, 2.0) = 0.0;
uniform float shock_strength : hint_range(0.0, 1.0) = 0.0;

// How far the red and blue channels are pulled apart, for the moment a hit lands. 0 is aligned.
uniform float chromatic : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 looked_up = SCREEN_UV;
	// The ring: pixels within a band of the travelling radius are pushed outwards from the centre,
	// hardest at the band's middle. Outside the band nothing moves, so the cost of a ring nobody
	// fired is one comparison.
	if (shock_strength > 0.0) {
		vec2 from_centre = SCREEN_UV - shock_center;
		float distance_out = length(from_centre);
		float band = 1.0 - smoothstep(0.0, 0.1, abs(distance_out - shock_radius));
		looked_up += normalize(from_centre + vec2(0.0001)) * band * shock_strength * 0.05;
	}
	// The channels are pulled apart along the line from the centre, which is what a lens does.
	vec3 seen;
	if (chromatic > 0.0) {
		vec2 apart = (looked_up - vec2(0.5)) * chromatic * 0.02;
		seen = vec3(
			textureLod(screen, looked_up + apart, blur).r,
			textureLod(screen, looked_up, blur).g,
			textureLod(screen, looked_up - apart, blur).b);
	} else {
		seen = textureLod(screen, looked_up, blur).rgb;
	}
	COLOR = vec4(mix(seen, fade_color.rgb, clamp(fade_amount, 0.0, 1.0) * fade_color.a), 1.0);
}
