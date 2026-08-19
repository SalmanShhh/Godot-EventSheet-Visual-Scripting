@tool
class_name ViewportHitTestHelper
extends RefCounted


## The rectangle a chip can be HIT in, which is never smaller than a target has to be even when
## the chip drawn inside it is. A one-glyph chip is eight pixels wide on screen; a reader who
## cannot place a pointer to the pixel still has to be able to press it. The drawing is untouched -
## only the catchment grows, and it grows around the chip's own centre so nothing shifts.
static func hit_rect(rect: Rect2) -> Rect2:
	var width: float = maxf(rect.size.x, EventSheetAccessibility.MIN_CHIP_HIT_WIDTH)
	var height: float = maxf(rect.size.y, EventSheetAccessibility.MIN_CHIP_HIT_HEIGHT)
	return Rect2(rect.position - Vector2(width - rect.size.x, height - rect.size.y) * 0.5,
		Vector2(width, height))


static func hit_test_row(
	position: Vector2,
	row_index: int,
	layout: Dictionary,
	row_data: EventRowData,
	resolve_span_lane: Callable,
	find_condition_span_index: Callable
) -> Dictionary:
	if row_data == null:
		return {}
	var result := {"row_index": row_index, "span_index": -1, "fold": false}
	var fold_rect: Rect2 = layout.get("fold_rect", Rect2())
	if fold_rect.size != Vector2.ZERO and fold_rect.has_point(position):
		result["fold"] = true
		return result
	# Two passes, and the order matters: every chip is offered its OWN rectangle first, so a
	# neighbour's enlarged catchment can never steal a press that landed squarely on a chip. Only
	# once nothing was hit exactly does the second pass let a chip smaller than a target reach out
	# into the dead space beside it.
	for generous: bool in [false, true]:
		for span_index in range(row_data.spans.size()):
			var span: SemanticSpan = row_data.spans[span_index]
			if span == null:
				continue
			var catchment: Rect2 = hit_rect(span.rect) if generous else span.rect
			if not catchment.has_point(position):
				continue
			if span.hoverable:
				result["span_index"] = span_index
				result["lane"] = str(resolve_span_lane.call(span))
				result["span_metadata"] = span.metadata if span.metadata is Dictionary else {}
				return result
			if span.metadata is Dictionary and (span.metadata as Dictionary).has("condition_index"):
				var condition_span_index: int = int(
					find_condition_span_index.call(
						row_data,
						int((span.metadata as Dictionary).get("condition_index", -1))
					)
				)
				if condition_span_index >= 0:
					var condition_span: SemanticSpan = row_data.spans[condition_span_index]
					result["span_index"] = condition_span_index
					result["lane"] = str(resolve_span_lane.call(condition_span))
					result["span_metadata"] = (
						condition_span.metadata
						if condition_span.metadata is Dictionary
						else {}
					)
					return result
	var divider_x: float = float(layout.get("lane_divider_x", -1.0))
	var lane_content_left: float = float(layout.get("gutter_rect", Rect2()).end.x)
	if divider_x > 0.0:
		result["lane"] = "action" if position.x >= divider_x else "condition"
		# Full-line fallback: a click on a condition/action line, to the right of the text or in
		# the small gaps between cells, still selects that ACE - but only inside a lane. Clicking
		# the gutter / indent margin (left of the lanes) falls through to whole-event selection.
		if position.x >= lane_content_left:
			var wanted_lane: String = str(result.get("lane", "condition"))
			for line_span_index in range(row_data.spans.size()):
				var line_span: SemanticSpan = row_data.spans[line_span_index]
				if line_span == null or not line_span.hoverable:
					continue
				var line_meta: Dictionary = line_span.metadata if line_span.metadata is Dictionary else {}
				if str(line_meta.get("kind", "")) not in ["condition", "trigger", "action"]:
					continue
				if str(resolve_span_lane.call(line_span)) != wanted_lane:
					continue
				if position.y >= line_span.rect.position.y - 4.0 and position.y <= line_span.rect.end.y + 4.0:
					result["span_index"] = line_span_index
					result["span_metadata"] = line_meta
					return result
	var gutter_rect: Rect2 = layout.get("gutter_rect", Rect2())
	if gutter_rect.size != Vector2.ZERO and gutter_rect.has_point(position):
		result["gutter"] = true
	return result
