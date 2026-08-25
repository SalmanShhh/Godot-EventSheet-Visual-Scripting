@tool
class_name EventSheetViewportGuideLines
extends RefCounted

# The tree connector from an event to its sub-events.
#
# Indent alone loses the depth on a long handler: seven rows in, "which parent is this under"
# stops being answerable by eye. An event sheet draws a connector, so this draws one - a continuous
# vertical trunk per nesting level, plus a short elbow into the row it belongs to.
#
# Strictly draw-only. It reserves no width, shifts no metric and is never measured: the trunks
# sit in the indent gutter the layout already leaves empty, so turning the connector on or off
# cannot move a single glyph. Row density (View > Compact Rows) only tunes the elbow's reach,
# never the trunk positions, because those must line up with the indent the layout applied.


## Trunk x for one nesting level, in the same indent gutter the row layout leaves empty. Kept
## as one function so the trunk can never drift off the indent step the layout applied.
static func trunk_x(row_rect: Rect2, level: int) -> float:
	return row_rect.position.x + float(EventSheetPalette.GUTTER_WIDTH) + float(level * EventSheetPalette.INDENT_WIDTH) + 2.0


## How far the elbow reaches toward the row it points at. Density trades whitespace for rows on
## screen, so a compact sheet gets a shorter stub - the connector stays legible without eating
## the tighter row.
static func elbow_reach() -> float:
	return float(EventSheetPalette.INDENT_WIDTH) * 0.55 * EventSheetPalette.row_density()


## Draws the connector for one row. `depth` is the row's indent: 0 draws nothing (a top-level
## event has no parent to connect to), and each level above that gets a trunk. The trunk spans
## the FULL row height with no inset, so consecutive sub-events read as one continuous line
## instead of a dotted column of dashes.
static func draw_guides(control: Control, row_rect: Rect2, depth: int, guide_color: Color) -> void:
	if control == null or depth < 1:
		return
	var line_width: float = EventSheetPalette.scaled_f(1.0)
	for level: int in range(depth):
		var x: float = trunk_x(row_rect, level)
		control.draw_line(
			Vector2(x, row_rect.position.y),
			Vector2(x, row_rect.end.y),
			guide_color,
			line_width,
			true
		)
	# The elbow: the innermost trunk turns toward the row it parents, so the eye lands on the
	# row rather than on a bare vertical line running past it.
	var elbow_x: float = trunk_x(row_rect, depth - 1)
	var elbow_y: float = row_rect.position.y + row_rect.size.y * 0.5
	control.draw_line(
		Vector2(elbow_x, elbow_y),
		Vector2(elbow_x + elbow_reach(), elbow_y),
		guide_color,
		line_width,
		true
	)
