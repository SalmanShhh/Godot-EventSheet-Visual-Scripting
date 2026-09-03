#[compute]
#version 450

// The push constant every Post Kit effect shares: the frame size, the strength after the
// accessibility dials, the aspect ratio, the colour the effect works in, and two sets of dials
// whose meaning is the effect's own. One header, so no effect has to think about alignment.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict image2D frame;

layout(set = 0, binding = 1) uniform sampler2D mask;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float strength;
	float aspect;
	vec4 colour;
	vec4 dials;
	vec4 more;
} params;

// Draws the edge of the mask over the frame. The mask holds the chosen things whole, whatever is
// standing in front of them, so an edge found in it is drawn through walls by construction.
//
// dials.x is the outline width in pixels, dials.y is how much of the mask is filled in: 0 leaves an
// outline, 1 leaves a solid silhouette.
void main() {
	ivec2 at = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (at.x >= size.x || at.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(at) + 0.5) / params.raster_size;
	vec2 reach = max(params.dials.x, 1.0) / params.raster_size;
	float here = texture(mask, uv).a;
	// Eight taps around the pixel: a pixel that is empty while one of its neighbours is not is a
	// pixel just outside the silhouette, which is where an outline belongs.
	float around = 0.0;
	around = max(around, texture(mask, uv + vec2(reach.x, 0.0)).a);
	around = max(around, texture(mask, uv - vec2(reach.x, 0.0)).a);
	around = max(around, texture(mask, uv + vec2(0.0, reach.y)).a);
	around = max(around, texture(mask, uv - vec2(0.0, reach.y)).a);
	around = max(around, texture(mask, uv + reach).a);
	around = max(around, texture(mask, uv - reach).a);
	around = max(around, texture(mask, uv + vec2(reach.x, -reach.y)).a);
	around = max(around, texture(mask, uv + vec2(-reach.x, reach.y)).a);
	float edge = clamp(around - here, 0.0, 1.0);
	float ink = clamp(max(edge, here * params.dials.y), 0.0, 1.0) * params.strength;
	if (ink <= 0.0) {
		return;
	}
	vec4 pixel = imageLoad(frame, at);
	pixel.rgb = mix(pixel.rgb, params.colour.rgb, ink);
	imageStore(frame, at, pixel);
}
