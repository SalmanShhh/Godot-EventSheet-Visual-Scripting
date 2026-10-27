// Vector Shapes in 3D - the spatial half of ONE drawing.
//
// The include line below is the whole point of this file: it names the SAME FILE the five canvas
// shaders name, so the distance fields, the dashes, the caps and the colour modes have exactly one
// copy in the pack and the two halves cannot drift. A spatial shader cannot share a `fragment()`
// with a canvas one, so the shared file keeps the drawing in a function and leaves its own fragment
// out when VECTOR_SHAPES_SPATIAL is defined. It is named by its INSTALLED path rather than as a
// neighbour, because this half is authored in a source folder of its own and shipped beside the 2D
// half - one path that reads the same from both places.
//
// WHAT THIS HALF ADDS. Three things a shape needs in 3D and does not need in 2D:
//
//   billboard   the quad turns to face the camera, in the VERTEX stage - four vertices of work per
//               shape per frame, not a redraw and not a CPU pass over anything
//   ribbon      a Line 3D is a strip built between two points in space rather than a rectangle on a
//               plane, so a rope between a hand and a grapple point is a real line in the world
//   screen      a stroke measured in PIXELS rather than in metres, read from how much of the shape
//               one pixel covers where it lands, so a range ring is the same weight near and far
//
// PRECISION. Everything below is in the node's own units around numbers a designer typed, and the
// one division that could bite (units per pixel) is guarded on both sides, which is what keeps this
// mediump-safe on the phones and browsers that only offer mediump.
//
// THE RENDERER. Nothing here is Forward+ only: an unshaded spatial shader with these five blends
// runs on Mobile and on Compatibility as well, which is the same promise the canvas half makes.

#define VECTOR_SHAPES_SPATIAL
#include "res://eventsheet_addons/vector_shapes/vector_shapes.gdshaderinc"

// Whether the shape turns to face the camera. A uniform rather than a `render_mode` because it is a
// field a designer flips, and because the billboard is done here rather than by a material flag -
// which is what lets the ribbon face the camera along its own axis instead of spinning about it.
uniform bool billboard = false;

// Whether this is a strip between two points (a Line 3D) rather than a shape on a plane.
uniform bool ribbon = false;
uniform vec3 ribbon_a = vec3(0.0);
uniform vec3 ribbon_b = vec3(1.0, 0.0, 0.0);

// Whether the stroke's width is read as pixels on the screen rather than as the node's own units.
uniform bool screen_thickness = false;

// The shape's own coordinates at this fragment. The two stages divide the work the way the engine
// makes them: the VERTEX stage places the quad, and the FRAGMENT stage is where the camera can be
// read at all - the projection and the viewport built-ins are only filled in there, which is why a
// screen-unit stroke is measured per pixel and the quad that has to hold it is padded by the shape's
// own size rather than by a width nobody knows yet.
varying vec2 shape_point;


// How far past its own box the quad has to reach. In the node's own units that is exactly half a
// stroke; in screen units the stroke is as wide as the camera says it is, so the quad reaches half
// its own size instead - which runs out only once the whole shape is a few pixels across, and a
// shape that small is its stroke anyway.
float quad_reach(float extent) {
	if (screen_thickness) {
		return max(extent * 0.5, 0.02);
	}
	return max(max(thickness_px, border_px), 0.0) * 0.5 + max(aa_width, 0.0) * 0.01 + 0.02;
}


void vertex() {
	float model_scale = length(MODEL_MATRIX[0].xyz);
	if (ribbon) {
		// A strip between two points, widened across the direction the viewer reads it from: the
		// node's own +Z when it is flat, and the camera when it is a billboard. Both are the same
		// four vertices, which is why a rope costs no more than a rectangle.
		vec3 middle = mix(ribbon_a, ribbon_b, 0.5);
		vec3 towards = ribbon_b - ribbon_a;
		float span = max(length(towards), 0.0001);
		vec3 direction = towards / span;
		vec3 facing = vec3(0.0, 0.0, 1.0);
		if (billboard) {
			facing = normalize((inverse(MODEL_MATRIX) * INV_VIEW_MATRIX[3]).xyz - middle);
		}
		vec3 across = cross(direction, facing);
		float across_length = length(across);
		across = across_length < 0.0001 ? vec3(0.0, 1.0, 0.0) : across / across_length;
		// The strip runs past each end so a round cap has somewhere to be drawn.
		float reach = quad_reach(span);
		float along = UV.x * (span + 2.0 * reach) - reach;
		float sideways = (UV.y - 0.5) * 2.0 * reach;
		VERTEX = ribbon_a + direction * along + across * sideways;
		shape_point = vec2(along, sideways);
	} else {
		if (billboard) {
			// The engine's own billboard, kept here rather than as a material flag so that the
			// node's scale survives it: the rotation becomes the camera's and the scale is put back.
			MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
			MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
				vec4(model_scale, 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		}
		vec2 centre = quad_origin + quad_size * 0.5;
		// The quad GROWS here rather than on the CPU, because a screen-unit stroke is only as wide
		// as the camera says it is - a node that padded its own quad would clip its own outline the
		// moment the camera backed away.
		float pad = quad_reach(max(quad_size.x, quad_size.y));
		vec2 grown = quad_size * 0.5 + vec2(pad);
		// UV runs down the quad and the node's own Y runs up it, which is the one place the two
		// halves of this pack differ: a 3D shape's coordinates are Y-up, like everything else in 3D.
		shape_point = centre + vec2(UV.x - 0.5, 0.5 - UV.y) * grown * 2.0;
		VERTEX = vec3(shape_point, 0.0);
	}
}


void fragment() {
	// HOW BIG A PIXEL IS, HERE, in the shape's own units. It is read from the screen-space
	// derivatives of the shape's own coordinates rather than worked out from the camera: that is
	// exact for a shape seen at an angle, for an orthographic camera and for any scale on the node,
	// and it needs no built-in the stage might not carry. It is what the fade at an edge is one
	// pixel wide in, and what turns a stroke typed in PIXELS into a length in the world.
	vec2 along_x = dFdx(shape_point);
	vec2 along_y = dFdy(shape_point);
	float units_per_pixel = max(sqrt(abs(along_x.x * along_y.y - along_x.y * along_y.x)), 0.000001);
	float scale = screen_thickness ? units_per_pixel : 1.0;
	vec4 drawn = vector_shape_at(shape_point, UV,
		max(thickness_px, 0.0001) * 0.5 * scale,
		max(border_px, 0.0001) * 0.5 * scale,
		max(aa_width, 0.0001) * units_per_pixel);
	ALBEDO = drawn.rgb;
	ALPHA = drawn.a;
}
