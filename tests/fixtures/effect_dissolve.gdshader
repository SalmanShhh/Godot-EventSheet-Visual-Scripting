shader_type canvas_item;

// How much of the sprite has burned away, from whole to gone.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

// The colour the burning edge glows.
uniform vec4 edge_tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);

// The noise the burn eats along.
uniform sampler2D burn_noise : repeat_enable;

uniform int steps : hint_range(1, 16, 1) = 8;

void fragment() {
	float mask = texture(burn_noise, UV).r;
	COLOR = texture(TEXTURE, UV);
	COLOR.rgb = mix(COLOR.rgb, edge_tint.rgb, step(mask, dissolve) * float(steps) * 0.0);
	COLOR.a *= step(dissolve, mask);
}
