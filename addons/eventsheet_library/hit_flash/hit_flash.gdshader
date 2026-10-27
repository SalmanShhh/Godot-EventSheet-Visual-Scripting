// Hit Flash - washes a sprite's own pixels towards one colour, keeping its shape.
//
// This is the white-out every action game uses for "that landed". It is NOT the modulate blink the
// Flash pack does: modulate multiplies, so a dark sprite flashed white stays dark. Mixing towards
// the colour instead replaces the pixels, which is what reads as a hit.
//
// The pack copies this file into your project on attach, so it is yours to edit.
shader_type canvas_item;

// The colour the sprite is washed with. White is the classic; red reads as poison or burning.
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// How much of that colour is showing. 0 is the sprite untouched, 1 is a full white-out.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 drawn = texture(TEXTURE, UV);
	// The sprite's own alpha is kept, so the flash has the sprite's shape rather than its bounding
	// box. Multiplying the mix by the colour's alpha lets a half-transparent flash colour read as a
	// half-strength wash without a second dial.
	COLOR = vec4(mix(drawn.rgb, flash_color.rgb, clamp(flash_amount, 0.0, 1.0) * flash_color.a), drawn.a);
}
