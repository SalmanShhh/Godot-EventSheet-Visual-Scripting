// Page curl - the picture peels off the screen like a page being turned.
//
// One of Scene Flow's transition shaders, driven by the one `progress` dial: 0 is the game showing,
// 1 is the game hidden.
//
// THIS ONE READS THE SCREEN BACK, because the curling page is the picture itself folded over: it
// costs one screen read per pixel it covers while it runs. It is an approximation rather than a
// simulated sheet of paper - the page folds flat about the moving edge and darkens as it turns away,
// which is what reads as a curl at the speed a transition runs.
shader_type canvas_item;

// Whatever has already been drawn this frame - the game the page is made of.
uniform sampler2D screen : hint_screen_texture, filter_linear;

// How covered the screen is. 0 is the game, 1 is nothing but what is behind the page.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// What is behind the page once it has peeled away.
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// How wide the curling strip is, in screen fractions, and how dark the underside of the page goes.
uniform float curl_width : hint_range(0.02, 0.6) = 0.18;
uniform float shading : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	float walk = clamp(progress, 0.0, 1.0);
	// The peel starts off the left edge and finishes off the right one, so the whole screen is behind
	// the page by the time progress lands.
	float edge = walk * (1.0 + curl_width);
	float along = UV.x;
	// How far behind the leading edge this pixel is: 0 at the edge itself, 1 once the page has fully
	// turned over it.
	float behind = clamp((edge - along) / max(curl_width, 0.001), 0.0, 1.0);
	// The page folded back on itself: the picture mirrored about the moving edge.
	vec2 folded = clamp(vec2(edge + (edge - along), SCREEN_UV.y), vec2(0.0), vec2(1.0));
	vec3 page = texture(screen, folded).rgb * (1.0 - behind * shading);
	vec3 shown = mix(page, cover_color.rgb, smoothstep(0.75, 1.0, behind));
	COLOR = vec4(shown, smoothstep(along - 0.002, along + 0.002, edge));
}
