// Vector Shapes, drawn MANY AT ONCE - the half the drawing rows use.
//
// A shape NODE is one quad carrying its own numbers in uniforms, which is right for a shape you
// placed and tuned. A shape drawn from a ROW is one of a hundred in a frame, all wearing the same
// draw style, so its numbers ride the INSTANCE instead: one MultiMesh per shape kind per frame, and
// one draw call for every arc in that frame however many there are.
//
// THE STYLE IS THE UNIFORM HALF, and it is the same set of uniforms the include below declares -
// the stroke's width, its caps, its colours, its dash pattern. So a dash tuned on a placed shape and
// a dash drawn from a row are one copy of the arithmetic rather than two that drift apart.
//
// WHAT RIDES THE INSTANCE. Godot gives a 2D instance a transform, a colour and one vec4 of custom
// data, which is exactly enough for the shapes here: the transform says where the shape is and
// which way it faces, the colour is the row's own tint, and the four custom numbers are its
// geometry (a radius and two angles for an arc, two half sides and a corner for a rect, a cell for
// a grid).
//
// THE QUAD IS SIZED BY THE SHAPE, so a small cross does not pay for a big arc's pixels: the mesh is
// a unit quad from -1 to 1 and the instance transform scales it by the shape's own reach. That
// reach is worked out from the same four numbers on both sides of the wire - `batch_extent` here
// and `_batch_extent` in the canvas runtime - and the two MUST agree, or a shape is clipped by the
// quad it is drawn on.
//
// PRECISION: every distance is in pixels around numbers a designer typed, nothing accumulates over
// frames, and every divisor is guarded - the same mediump-safe arithmetic as the shared body.
shader_type canvas_item;
render_mode blend_mix;

// The shared body leaves ITS canvas fragment out when this is defined, because this file declares
// one of its own that reads the instance rather than the shape uniforms. Everything else in there -
// the dash pattern, the colour modes, the rounded box, the segment stroke - is what this half came
// for.
#define VECTOR_SHAPES_BATCH
#include "vector_shapes.gdshaderinc"

// Which shape this MultiMesh is drawing. One batch is one kind, so this is a uniform and not
// instance data: every pixel of the whole draw takes the same arm of the branch below.
uniform int batch_kind = 0;  // 0 arc, 1 pie, 2 rounded rect, 3 regular polygon, 4 grid, 5 cross, 6 arrow

// The instance's own four numbers, carried from the vertex stage because INSTANCE_CUSTOM is only
// readable there. Flat: it is one value for the whole quad, never interpolated across it.
varying flat vec4 shape_numbers;


// How far this shape reaches from its own centre, in pixels. THE CANVAS RUNTIME COMPUTES THE SAME
// NUMBER to scale the instance, so the quad is exactly big enough for what is drawn on it.
float batch_extent(vec4 s) {
	float margin = max(thickness_px, 0.01) * 0.5 + max(aa_width, 0.0) + 2.0;
	if (batch_kind == 2 || batch_kind == 4) {
		return max(abs(s.x), abs(s.y)) + margin;
	}
	if (batch_kind == 6) {
		return max(abs(s.x), abs(s.z)) + margin;
	}
	return abs(s.x) + margin;
}


void vertex() {
	shape_numbers = INSTANCE_CUSTOM;
}


void fragment() {
	vec4 s = shape_numbers;
	vec2 p = (UV * 2.0 - 1.0) * batch_extent(s);
	float half_thickness = max(thickness_px, 0.01) * 0.5;
	float aa = max(aa_width, 0.0001);

	float outline = 1e20;   // negative inside a filled shape
	float stroke = 1e20;    // distance to the stroke drawn on its outline
	float along = 0.0;      // how far along that outline this pixel is
	float span = 1.0;       // the length a dash pattern is fitted into
	float perp = 0.0;       // across the stroke, for the dash's own shape
	float t = 0.0;          // the shape's 0-to-1 reading, for the colour modes
	bool fill_it = filled;
	bool can_dash = false;

	if (batch_kind == 0 || batch_kind == 1) {
		// Arc and pie: one radius, one inner radius and two angles, exactly as a placed Disc.
		float r = max(s.x, 0.01);
		float inner = clamp(s.y, 0.0, r);
		float sweep = max(s.w - s.z, 0.0001);
		float dist = length(p);
		float rel = mod(atan(p.y, p.x) - s.z, 6.2831853);
		bool in_sweep = rel <= sweep || sweep >= 6.2831853;
		float mid = (r + inner) * 0.5;
		outline = inner > 0.0 ? max(dist - r, inner - dist) : dist - r;
		stroke = inner > 0.0 ? abs(dist - mid) - (r - inner) * 0.5 : abs(dist - r) - half_thickness;
		if (!in_sweep) {
			outline = 1e20;
			stroke = 1e20;
		}
		perp = dist - (inner > 0.0 ? mid : r);
		span = min(sweep, 6.2831853) * r;
		along = rel * r;
		t = colour_mode == 3 ? rel / sweep : clamp((dist - inner) / max(r - inner, 0.01), 0.0, 1.0);
		fill_it = batch_kind == 1;
		can_dash = batch_kind == 0;
	} else if (batch_kind == 2) {
		// Rounded rect: analytic, so the corner radius is exact rather than a fan of points.
		vec2 half_size = max(abs(s.xy), vec2(0.01));
		outline = rounded_box_distance(p, half_size, vec4(max(s.z, 0.0)));
		stroke = abs(outline) - half_thickness;
		perp = outline;
		span = 2.0 * (half_size.x + half_size.y);
		vec2 q = p / half_size;
		bool horizontal = abs(q.y) >= abs(q.x);
		if (horizontal) {
			along = q.y < 0.0 ? (p.x + half_size.x) : (2.0 * half_size.x + 2.0 * half_size.y + (half_size.x - p.x));
		} else {
			along = q.x > 0.0 ? (2.0 * half_size.x + (p.y + half_size.y)) : (4.0 * half_size.x + 2.0 * half_size.y + (half_size.y - p.y));
		}
		if (dash_snap == 2) {
			// End to end snaps each SIDE on its own, so every corner carries a dash.
			span = horizontal ? 2.0 * half_size.x : 2.0 * half_size.y;
			along = horizontal ? (p.x + half_size.x) : (p.y + half_size.y);
		}
		t = colour_mode == 2 ? clamp(length(q), 0.0, 1.0) : UV.x;
		can_dash = true;
	} else if (batch_kind == 3) {
		// Regular polygon: the distance to the side plane of whichever sector the pixel is in.
		float r = max(s.x, 0.01);
		float sides = max(s.y, 3.0);
		float sector = 6.2831853 / sides;
		float apothem = r * cos(sector * 0.5);
		float ang = atan(p.y, p.x) - s.z;
		float rel = mod(ang, sector);
		outline = cos(rel - sector * 0.5) * length(p) - apothem;
		stroke = abs(outline) - half_thickness;
		perp = outline;
		span = sides * 2.0 * r * sin(sector * 0.5);
		float turn = mod(ang, 6.2831853) / 6.2831853;
		along = turn * span;
		if (dash_snap == 2) {
			span = span / sides;
			along = mod(ang, sector) / sector * span;
		}
		t = colour_mode == 3 ? turn : clamp(length(p) / r, 0.0, 1.0);
		can_dash = true;
	} else if (batch_kind == 4) {
		// Grid: the nearest ruling in each direction, clipped to the box it fills.
		vec2 half_size = max(abs(s.xy), vec2(0.01));
		float cell = max(s.z, 1.0);
		vec2 nearest = abs(mod(p + vec2(cell * 0.5), vec2(cell)) - vec2(cell * 0.5));
		float rulings = min(nearest.x, nearest.y) - half_thickness;
		stroke = max(rulings, rounded_box_distance(p, half_size, vec4(0.0)));
		t = UV.x;
	} else if (batch_kind == 5) {
		// Cross: two strokes through the centre, wearing the style's own caps.
		float arm = max(s.x, 0.01);
		float across = stroke_distance(segment_reading(p, vec2(-arm, 0.0), vec2(arm, 0.0)), half_thickness, caps, true, true);
		float down = stroke_distance(segment_reading(p, vec2(0.0, -arm), vec2(0.0, arm)), half_thickness, caps, true, true);
		stroke = min(across, down);
		t = UV.x;
	} else {
		// Arrow: a shaft along +X with an open head at its tip, so the head is the stroke's own
		// width rather than a filled triangle nobody can thin.
		float half_length = max(s.x, 0.01);
		float head = clamp(s.y, 0.0, half_length * 2.0);
		float half_head = max(s.z, 0.01) * 0.5;
		vec2 tip = vec2(half_length, 0.0);
		vec2 base = vec2(half_length - head, 0.0);
		float shaft = stroke_distance(segment_reading(p, vec2(-half_length, 0.0), tip), half_thickness, caps, true, true);
		float upper = stroke_distance(segment_reading(p, base + vec2(0.0, -half_head), tip), half_thickness, caps, true, true);
		float lower = stroke_distance(segment_reading(p, base + vec2(0.0, half_head), tip), half_thickness, caps, true, true);
		stroke = min(shaft, min(upper, lower));
		t = clamp((p.x + half_length) / max(half_length * 2.0, 0.01), 0.0, 1.0);
	}

	// The row's own colour rides the instance and lands here in COLOR; the style's colour modes
	// blend on top of it, which is why a plain row is its colour and a gradient style is a ramp.
	vec4 body = shape_colour(t, UV) * COLOR;
	float coverage;
	if (fill_it) {
		coverage = 1.0 - smoothstep(-aa, aa, outline);
	} else {
		coverage = 1.0 - smoothstep(-aa, aa, stroke);
		if (dashed && can_dash) {
			coverage = min(coverage, dash_coverage(along, span, perp, half_thickness, aa));
		}
	}
	COLOR = vec4(body.rgb, body.a * coverage);
}
