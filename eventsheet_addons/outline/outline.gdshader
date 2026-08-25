// Outline - draws a border around whatever the sprite's own alpha says its shape is.
//
// The border is drawn INSIDE the sprite's rectangle, because a canvas_item shader may only colour
// pixels the node already covers. A sprite whose art touches the edge of its image therefore has no
// room for an outline: give the image a few transparent pixels of margin, or turn on the texture's
// region with padding, and the outline appears.
//
// The pack copies this file into your project on attach, so it is yours to edit.
shader_type canvas_item;

// The colour drawn around the sprite.
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// How thick the border is, in pixels of the sprite's own image. 0 is no outline at all.
uniform float outline_width : hint_range(0.0, 16.0) = 0.0;

void fragment() {
	vec4 drawn = texture(TEXTURE, UV);
	vec2 step_size = TEXTURE_PIXEL_SIZE * outline_width;
	// Eight neighbours: four sides and four corners. The corners are what stop a diagonal edge from
	// coming out as a staircase of gaps.
	float around = 0.0;
	around = max(around, texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV + vec2(-step_size.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV + vec2(0.0, step_size.y)).a);
	around = max(around, texture(TEXTURE, UV + vec2(0.0, -step_size.y)).a);
	around = max(around, texture(TEXTURE, UV + step_size * 0.7071).a);
	around = max(around, texture(TEXTURE, UV - step_size * 0.7071).a);
	around = max(around, texture(TEXTURE, UV + vec2(step_size.x, -step_size.y) * 0.7071).a);
	around = max(around, texture(TEXTURE, UV + vec2(-step_size.x, step_size.y) * 0.7071).a);
	// Where the sprite is solid it is drawn as it is; where it is clear but something solid is
	// within reach, the outline colour is drawn instead.
	float border = clamp(around - drawn.a, 0.0, 1.0) * step(0.001, outline_width) * outline_color.a;
	COLOR.rgb = mix(drawn.rgb, outline_color.rgb, border);
	COLOR.a = max(drawn.a, border);
}
