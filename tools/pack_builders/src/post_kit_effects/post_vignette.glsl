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

// Shades the frame towards a colour as it nears the corners. dials.x is where the shading starts,
// measured out from the middle, so a large value leaves a wide clear middle.
void main() {
	ivec2 at = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (at.x >= size.x || at.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(at) + 0.5) / params.raster_size;
	vec2 centred = (uv - 0.5) * vec2(params.aspect, 1.0);
	float reach = length(centred) * 1.4142;
	float shade = smoothstep(params.dials.x, 1.0, reach) * params.strength;
	vec4 pixel = imageLoad(frame, at);
	pixel.rgb = mix(pixel.rgb, params.colour.rgb, shade);
	imageStore(frame, at, pixel);
}
