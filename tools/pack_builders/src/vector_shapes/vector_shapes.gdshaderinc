// Vector Shapes - the whole drawing, once.
//
// Every shape node in this pack draws ONE quad wearing this code: the fragment works out how far
// the pixel is from the shape's outline (a signed distance), and turns that distance into coverage.
// That is why a ring is round at any zoom and a hairline is one crisp pixel at any zoom: nothing is
// baked into a texture, and nothing is tessellated on the CPU.
//
// It lives in an INCLUDE, and the five `.gdshader` files beside it are four lines each. A blend
// mode is a `render_mode` in Godot, which is decided when the shader is compiled and cannot be a
// uniform, so "the same drawing, blended differently" has to be one file per blend. Sharing the body
// through an include is the only way to have five blends and one copy of the drawing.
//
// The 3D twins read THIS FILE TOO. `vector_shapes_3d.gdshaderinc` defines VECTOR_SHAPES_SPATIAL and
// includes it, so a spatial shape gets the same distance fields, the same dashes and the same
// colour modes, and the canvas fragment at the bottom is left out for the spatial one it declares
// instead. That is the whole reason the drawing is a function rather than a fragment body: two
// shader types cannot share a fragment, but they can share everything the fragment does.
//
// PRECISION: every distance here is in local pixels around a shape whose own numbers a designer
// typed, so the arithmetic stays in the hundreds. Nothing accumulates over frames and nothing is
// divided by a value that approaches zero (every divisor is guarded), which is what keeps this
// mediump-safe on the phones and browsers that only offer mediump.

// The most points a Polygon or Polyline carries. A uniform array is a fixed size, and 32 is what a
// hand-drawn outline actually uses; a longer outline is Godot's own Polygon2D's job and the guide
// says so.
const int MAX_POINTS = 32;

// Which shape this quad is drawing. One shader with a branch, rather than one shader per shape,
// because the branch is uniform (every pixel of a draw takes the same arm, so no lane diverges) and
// because a phone or a browser pays for shader COMPILES far more than for a branch: seven variants
// would be seven compiles and seven pipeline states on a device that stalls on both.
uniform int shape_kind = 0;              // 0 line, 1 disc, 2 rect, 3 polygon, 4 polyline, 5 triangle, 6 regular polygon
uniform vec2 quad_origin = vec2(0.0);    // the quad's top-left corner, in the node's own coordinates
uniform vec2 quad_size = vec2(1.0);      // the quad's size, so UV maps back to those coordinates

uniform float thickness_px = 2.0;        // the stroke's width, already converted to pixels
uniform float aa_width = 1.0;            // how wide the fade at an edge is, in pixels
uniform bool filled = false;             // a closed shape draws its inside as well as its outline
uniform int caps = 2;                    // 0 none (butt), 1 square, 2 round

uniform vec4 colour_a : source_color = vec4(1.0);
uniform vec4 colour_b : source_color = vec4(1.0);
uniform vec4 colour_c : source_color = vec4(1.0);
uniform vec4 colour_d : source_color = vec4(1.0);
uniform int colour_mode = 0;             // 0 single, 1 two, 2 radial, 3 angular, 4 gradient, 5 per corner
uniform sampler2D gradient_texture : source_color, hint_default_white, filter_linear;

uniform bool border_on = false;
uniform vec4 border_colour : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float border_px = 2.0;

uniform bool dashed = false;
uniform int dash_snap = 1;               // 0 off, 1 tiling, 2 end to end
uniform int dash_style = 0;              // 0 plain, 1 angled, 2 rounded
uniform float dash_length_px = 12.0;     // one dash, in pixels (the count mode sends the span instead)
uniform float dash_gap_px = 6.0;         // the gap after it, in pixels
uniform int dash_count = 0;              // when above zero, this many dashes per span instead of a length
uniform float dash_gap_share = 0.5;      // in count mode, how much of one period is gap
uniform float dash_offset = 0.0;         // whole numbers tile, so scrolling never jumps

uniform vec2 point_a = vec2(0.0);        // line: its two ends
uniform vec2 point_b = vec2(64.0, 0.0);
uniform float radius = 32.0;             // disc: outer radius
uniform float inner_radius = 0.0;        // above zero makes it a ring
uniform float angle_from = 0.0;          // disc: the sweep, in radians, measured from +X
uniform float angle_to = 6.2831853;
uniform vec2 box_half = vec2(32.0);      // rect: half its size
uniform vec4 corner_radius = vec4(0.0);  // rect: top-left, top-right, bottom-right, bottom-left
uniform vec2 points[MAX_POINTS];         // polygon / polyline / triangle / regular polygon
uniform int point_count = 0;
uniform bool path_closed = true;


// One segment, as a distance and as a place along it. Returns the perpendicular distance to the
// segment's centre line in `.x`, how far along the segment the pixel is in `.y`, and the segment's
// own length in `.z` - the three numbers every stroke, cap and dash below is made of.
vec3 segment_reading(vec2 p, vec2 a, vec2 b) {
	vec2 ba = b - a;
	float len = max(length(ba), 0.0001);
	vec2 dir = ba / len;
	vec2 pa = p - a;
	float along = dot(pa, dir);
	float perp = dot(pa, vec2(-dir.y, dir.x));
	return vec3(perp, along, len);
}


// The stroke's distance for one segment, with its end caps: negative inside the stroke.
float stroke_distance(vec3 reading, float half_thickness, int cap_mode, bool cap_start, bool cap_end) {
	float perp = abs(reading.x);
	float along = reading.y;
	float len = reading.z;
	// How far past each end this pixel lies. These are NOT clamped to zero: a segment whose
	// overshoot cannot go positive never ends, and a shape drawn from lines that never end has a
	// stroke running off it in both directions - which is a hexagon with two rules through it.
	float over_start = -along;
	float over_end = along - len;
	// Which ends are CUT: only an end the path really has, and only when its cap is not round. An
	// end that meets the next segment is left to the round term below, which is the join that
	// leaves no notch on the outside of a corner.
	bool cut_start = cap_start && cap_mode != 2;
	bool cut_end = cap_end && cap_mode != 2;
	float reach = cap_mode == 1 ? half_thickness : 0.0;   // square reaches half a thickness past the end
	float cut_edge = max(cut_start ? over_start - reach : -1e20, cut_end ? over_end - reach : -1e20);
	float soft = max(cut_start ? -1e20 : over_start, cut_end ? -1e20 : over_end);
	// The honest Euclidean distance to the segment, which is a round cap at a path end and a round
	// hand-over at a join; a cut end contributes its straight edge through `cut_edge` instead.
	float rounded = length(vec2(max(soft, 0.0), perp)) - half_thickness;
	return max(max(perp - half_thickness, cut_edge), rounded);
}


// A dash pattern along one span, as coverage. `along` is the distance travelled, `span` the length
// the pattern must fit, `perp` the signed distance across the stroke.
float dash_coverage(float along, float span, float perp, float half_thickness, float aa) {
	float dash_len = max(dash_length_px, 0.01);
	float gap_len = max(dash_gap_px, 0.0);
	if (dash_count > 0) {
		float period_count = max(span, 0.01) / float(dash_count);
		gap_len = period_count * clamp(dash_gap_share, 0.0, 0.95);
		dash_len = max(period_count - gap_len, 0.01);
	}
	float period = dash_len + gap_len;
	float duty = dash_len / period;
	if (dash_snap != 0) {
		// Tiling and end-to-end both make the period divide the span exactly, so the pattern never
		// ends on a half dash. End-to-end additionally centres a dash on each end of the span,
		// which is what puts a dash on every corner of a rect and every vertex of a polygon.
		float wanted = max(1.0, floor(max(span, 0.01) / period + 0.5));
		period = max(span, 0.01) / wanted;
	}
	float phase = along / period + dash_offset;
	if (dash_snap == 2) {
		phase -= duty * 0.5;
	}
	float local_x = (fract(phase) - duty * 0.5) * period;   // 0 at the middle of a dash
	float half_dash = duty * period * 0.5;
	float y = abs(perp);
	float mask;
	if (dash_style == 2) {
		// Rounded: the dash is a capsule, so its ends are half discs like a round cap.
		float flat_span = max(half_dash - half_thickness, 0.0);
		mask = length(vec2(max(abs(local_x) - flat_span, 0.0), y)) - half_thickness;
	} else if (dash_style == 1) {
		// Angled: the cut leans over by the stroke's own width, so the dash is a parallelogram.
		mask = max(abs(local_x + perp * 0.5) - half_dash, y - half_thickness);
	} else {
		mask = max(abs(local_x) - half_dash, y - half_thickness);
	}
	return 1.0 - smoothstep(-aa, aa, mask);
}


// The colour at this pixel, before the dash and the outline decide how much of it lands.
// `t` is the shape's own 0-to-1 reading (along a line, out from a centre, round a sweep) and `uv`
// the quad's, which is what a per-corner fill needs.
vec4 shape_colour(float t, vec2 uv) {
	if (colour_mode == 1) {
		return mix(colour_a, colour_b, clamp(t, 0.0, 1.0));
	}
	if (colour_mode == 2 || colour_mode == 3) {
		return mix(colour_a, colour_b, clamp(t, 0.0, 1.0));
	}
	if (colour_mode == 4) {
		return texture(gradient_texture, vec2(clamp(t, 0.0, 1.0), 0.5));
	}
	if (colour_mode == 5) {
		vec4 top = mix(colour_a, colour_b, uv.x);
		vec4 bottom = mix(colour_d, colour_c, uv.x);
		return mix(top, bottom, uv.y);
	}
	return colour_a;
}


// The rounded rectangle's distance, and the corner radius that applies in this quadrant.
float rounded_box_distance(vec2 p, vec2 half_size, vec4 radii) {
	float r = p.x > 0.0 ? (p.y < 0.0 ? radii.y : radii.z) : (p.y < 0.0 ? radii.x : radii.w);
	r = min(r, min(half_size.x, half_size.y));
	vec2 q = abs(p) - half_size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}


// THE WHOLE DRAWING, AS ONE FUNCTION, so that both shader families read the same bytes for it: the
// canvas one below and the spatial one in the include beside this file. A dash tuned on a 2D line
// and the same dash on its 3D twin cannot drift, because there is one copy of the arithmetic.
//
//   p                where this pixel is, in the shape's own coordinates
//   uv               the quad's own 0-to-1 reading, which a per-corner fill needs
//   half_thickness   half the stroke's width, in those same coordinates
//   half_border      half the border's width, in those same coordinates
//   aa               how wide the fade at an edge is, in those same coordinates
//
// The two callers differ only in what they hand over: a canvas shape works in pixels, and a spatial
// one works in the node's own units and converts a screen-unit stroke through the camera first.
vec4 vector_shape_at(vec2 p, vec2 uv, float half_thickness, float half_border, float aa) {
	float outline = 1e20;    // distance to the outline: negative inside a filled shape
	float stroke = 1e20;     // distance to the stroke drawn on that outline
	float along = 0.0;       // how far along the outline this pixel is
	float span = 1.0;        // the length the dash pattern fits into
	float perp = 0.0;        // across the stroke, for the dash's own shape
	float t = 0.0;           // the shape's 0-to-1 reading, for the colour modes

	if (shape_kind == 1) {
		// Disc: one radius, one inner radius and two angles are a disc, a ring, a pie and an arc.
		float r = max(radius, 0.01);
		float dist = length(p);
		float sweep = max(angle_to - angle_from, 0.0001);
		float ang = atan(p.y, p.x);
		float rel = mod(ang - angle_from, 6.2831853);
		bool in_sweep = rel <= sweep || sweep >= 6.2831853;
		float mid = (r + inner_radius) * 0.5;
		outline = inner_radius > 0.0 ? max(dist - r, inner_radius - dist) : dist - r;
		stroke = inner_radius > 0.0 ? abs(dist - mid) - (r - inner_radius) * 0.5 : abs(dist - r) - half_thickness;
		if (!in_sweep) {
			outline = 1e20;
			stroke = 1e20;
		}
		perp = dist - (inner_radius > 0.0 ? mid : r);
		span = min(sweep, 6.2831853) * r;
		along = rel * r;
		t = colour_mode == 3 ? rel / sweep : clamp((dist - inner_radius) / max(r - inner_radius, 0.01), 0.0, 1.0);
	} else if (shape_kind == 2) {
		// Rect: analytic, so a corner radius is exact rather than a fan of points. Its dashes walk
		// the straight perimeter, which is why a corner radius softens where a corner dash sits.
		outline = rounded_box_distance(p, box_half, corner_radius);
		stroke = abs(outline) - half_thickness;
		perp = outline;
		vec2 h = max(box_half, vec2(0.01));
		span = 2.0 * (h.x + h.y);
		// Which side the pixel belongs to, walking clockwise from the top-left corner.
		vec2 q = p / h;
		bool horizontal = abs(q.y) >= abs(q.x);
		if (horizontal) {
			along = q.y < 0.0 ? (p.x + h.x) : (2.0 * h.x + 2.0 * h.y + (h.x - p.x));
		} else {
			along = q.x > 0.0 ? (2.0 * h.x + (p.y + h.y)) : (4.0 * h.x + 2.0 * h.y + (h.y - p.y));
		}
		if (dash_snap == 2) {
			// End to end snaps each SIDE on its own, so every corner carries a dash.
			span = horizontal ? 2.0 * h.x : 2.0 * h.y;
			along = horizontal ? (p.x + h.x) : (p.y + h.y);
		}
		t = colour_mode == 2 ? clamp(length(p / max(h, vec2(0.01))), 0.0, 1.0) : uv.x;
	} else {
		// Everything made of segments: the line (two points), the polyline, and the closed
		// polygon, triangle and regular polygon, whose points the node works out on the CPU.
		vec2 a0 = point_a;
		vec2 b0 = point_b;
		int count = shape_kind == 0 ? 2 : point_count;
		bool closed = shape_kind == 0 ? false : (shape_kind == 4 ? path_closed : true);
		float best = 1e20;
		float total = 0.0;
		float winding = 1.0;
		int last = count - 1;
		for (int i = 0; i < MAX_POINTS; i++) {
			if (i >= count) {
				break;
			}
			bool is_last = i == last;
			if (is_last && !closed) {
				break;
			}
			vec2 a = shape_kind == 0 ? (i == 0 ? a0 : b0) : points[i];
			vec2 b = shape_kind == 0 ? b0 : (is_last ? points[0] : points[i + 1]);
			vec3 reading = segment_reading(p, a, b);
			// A CLOSED outline has no ends at all: its last segment joins back to the first point,
			// so neither side of any segment wears a cap. An open path caps its first segment's
			// start and its final segment's end, and the loop breaks before the wrap-around one.
			bool cap_start = !closed && i == 0;
			bool cap_end = !closed && i == last - 1;
			float d = stroke_distance(reading, half_thickness, shape_kind == 0 ? caps : (closed ? 0 : caps), cap_start, cap_end);
			if (d < best) {
				best = d;
				perp = reading.x;
				along = dash_snap == 2 ? clamp(reading.y, 0.0, reading.z) : total + clamp(reading.y, 0.0, reading.z);
				span = dash_snap == 2 ? reading.z : 0.0;
			}
			total += reading.z;
			// The crossing test that says whether a closed outline holds this pixel.
			bool cond_a = a.y > p.y;
			bool cond_b = b.y > p.y;
			if (cond_a != cond_b) {
				float x_at = a.x + (p.y - a.y) / (b.y - a.y + 0.00001) * (b.x - a.x);
				if (p.x < x_at) {
					winding = -winding;
				}
			}
			if (shape_kind == 0) {
				break;
			}
		}
		stroke = best;
		if (dash_snap != 2) {
			span = max(total, 0.01);
		}
		outline = closed ? (winding < 0.0 ? -abs(best + half_thickness) : abs(best + half_thickness)) : 1e20;
		t = clamp(along / max(span, 0.01), 0.0, 1.0);
		if (colour_mode == 2) {
			t = clamp(length(p) / max(max(quad_size.x, quad_size.y) * 0.5, 0.01), 0.0, 1.0);
		} else if (colour_mode == 3) {
			t = clamp((atan(p.y, p.x) + 3.1415927) / 6.2831853, 0.0, 1.0);
		}
	}

	// Coverage. A filled shape is its inside, with the border laid over the edge of it; an unfilled
	// one is its stroke alone. The dash pattern cuts whichever of the two is a line around an edge,
	// which is why a filled rect's dashes are its border's and a line's dashes are its own.
	vec4 body = shape_colour(t, uv);
	vec4 result = vec4(body.rgb, 0.0);
	if (filled) {
		float fill_alpha = 1.0 - smoothstep(-aa, aa, outline);
		result = vec4(body.rgb, body.a * fill_alpha);
		if (border_on) {
			float edge_alpha = 1.0 - smoothstep(-aa, aa, abs(outline) - half_border);
			if (dashed) {
				edge_alpha = min(edge_alpha, dash_coverage(along, span, perp, half_border, aa));
			}
			result = mix(result, vec4(border_colour.rgb, border_colour.a), edge_alpha);
		}
	} else {
		float stroke_alpha = 1.0 - smoothstep(-aa, aa, stroke);
		if (dashed) {
			stroke_alpha = min(stroke_alpha, dash_coverage(along, span, perp, half_thickness, aa));
		}
		result = vec4(body.rgb, body.a * stroke_alpha);
	}
	return result;
}


// The canvas half: one quad in the node's own pixels. It is skipped when a spatial shader includes
// this file, which declares a fragment of its own - a shader has one, whichever type it is - and
// skipped again for the INSTANCED half beside it, whose fragment reads a shape's numbers off the
// instance rather than out of these uniforms so a hundred of them are one draw call.
#ifndef VECTOR_SHAPES_SPATIAL
#ifndef VECTOR_SHAPES_BATCH
void fragment() {
	vec4 drawn = vector_shape_at(quad_origin + UV * quad_size, UV, max(thickness_px, 0.01) * 0.5,
		max(border_px, 0.01) * 0.5, max(aa_width, 0.0001));
	COLOR = vec4(drawn.rgb, drawn.a * COLOR.a);
}
#endif
#endif
