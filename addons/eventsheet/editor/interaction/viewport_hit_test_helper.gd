@tool
class_name ViewportHitTestHelper
extends RefCounted

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
    for span_index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null or not span.rect.has_point(position):
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
    if divider_x > 0.0:
        result["lane"] = "action" if position.x >= divider_x else "condition"
    var gutter_rect: Rect2 = layout.get("gutter_rect", Rect2())
    if gutter_rect.size != Vector2.ZERO and gutter_rect.has_point(position):
        result["gutter"] = true
    return result
