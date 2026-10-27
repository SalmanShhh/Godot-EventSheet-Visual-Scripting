#[compute]
#version 450

// The push constant every Post Kit effect shares: the frame size, the strength after the
// accessibility dials, the aspect ratio, the colour the effect works in, and two sets of dials
// whose meaning is the effect's own. One header, so no effect has to think about alignment.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict image2D frame;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float strength;
	float aspect;
	vec4 colour;
	vec4 dials;
	vec4 more;
} params;

// Multiplies the frame by one colour and by dials.x, the light left over. Multiplying keeps the
// shading where it was, which is what separates a tint from a wash of paint.
void main() {
	ivec2 at = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (at.x >= size.x || at.y >= size.y) {
		return;
	}
	vec4 pixel = imageLoad(frame, at);
	vec3 tinted = pixel.rgb * params.colour.rgb * max(params.dials.x, 0.0);
	pixel.rgb = mix(pixel.rgb, tinted, params.strength);
	imageStore(frame, at, pixel);
}
