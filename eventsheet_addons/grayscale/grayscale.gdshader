// Grayscale - drains the colour out of a sprite, part of the way or all of it.
//
// The grey is the eye's own weighting of red, green and blue rather than a plain average, because
// an average turns a saturated red and a saturated blue into the same middle grey and the picture
// goes flat.
//
// The pack copies this file into your project on attach, so it is yours to edit.
shader_type canvas_item;

// How much colour has been drained. 0 is the sprite untouched, 1 is fully grey.
uniform float grayscale : hint_range(0.0, 1.0) = 0.0;

// What the grey is tinted with once the colour is gone. White leaves it plain grey; a cold blue
// reads as frozen, a brown as a sepia photograph.
uniform vec4 gray_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 drawn = texture(TEXTURE, UV);
	float grey = dot(drawn.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR.rgb = mix(drawn.rgb, vec3(grey) * gray_tint.rgb, clamp(grayscale, 0.0, 1.0));
	COLOR.a = drawn.a;
}
