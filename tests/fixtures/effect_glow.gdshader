shader_type canvas_item;

// How brightly the aura burns around the sprite.
uniform float glow : hint_range(0.0, 4.0) = 1.0;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.rgb *= glow;
}
