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

// Every pixel takes the colour of the top-left pixel of its block. dials.x is the block size at full
// strength; strength walks it back down to one pixel, so the effect fades in.
//
// The frame is read and written in place, which is safe here for one reason: the pixel a block reads
// from is the block'"'"'s own corner, and that corner reads and writes itself. Whatever order the
// invocations run in, the value they find there is the same one.
void main() {
	ivec2 at = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (at.x >= size.x || at.y >= size.y) {
		return;
	}
	int block = max(int(round(mix(1.0, max(params.dials.x, 1.0), params.strength))), 1);
	ivec2 corner = (at / block) * block;
	imageStore(frame, at, imageLoad(frame, corner));
}
