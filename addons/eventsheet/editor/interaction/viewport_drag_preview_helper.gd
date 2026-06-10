@tool
class_name ViewportDragPreviewHelper
extends RefCounted

static func build_ace_drag_preview_rect(
    row_data: EventRowData,
    lane: String,
    ace_index: int,
    insert_mode: String,
    condition_lane_rect: Rect2,
    action_lane_rect: Rect2,
    line_height: float,
    action_padding: float,
    condition_padding: float,
    find_ace_span_index: Callable,
    get_lane_ace_span_indices: Callable,
    get_span_gap: Callable
) -> Rect2:
    var lane_rect: Rect2 = action_lane_rect if lane == "action" else condition_lane_rect
    if lane_rect.size == Vector2.ZERO:
        return Rect2()
    var preview_height: float = max(min(line_height - 8.0, lane_rect.size.y - 8.0), 10.0)
    var preview_y: float = lane_rect.position.y + 4.0
    var ace_span_kind: String = "action" if lane == "action" else "condition"
    var ace_span_indices: Array[int] = get_lane_ace_span_indices.call(row_data, ace_span_kind)
    if ace_index >= 0:
        var target_span_index: int = int(find_ace_span_index.call(row_data, ace_span_kind, ace_index))
        if target_span_index >= 0 and target_span_index < row_data.spans.size():
            var target_span: SemanticSpan = row_data.spans[target_span_index]
            var preview_x: float = (
                target_span.rect.end.x + (float(get_span_gap.call(target_span)) * 0.5)
                if insert_mode == "after"
                else target_span.rect.position.x - (float(get_span_gap.call(target_span)) * 0.5)
            )
            preview_x = clampf(preview_x, lane_rect.position.x + 4.0, lane_rect.end.x - 4.0)
            preview_y = target_span.rect.position.y + 2.0
            preview_height = max(target_span.rect.size.y - 4.0, 10.0)
            return Rect2(preview_x - 1.5, preview_y, 3.0, preview_height)
    if not ace_span_indices.is_empty():
        var edge_span: SemanticSpan = row_data.spans[ace_span_indices[ace_span_indices.size() - 1]]
        var edge_preview_x: float = clampf(
            edge_span.rect.end.x + (float(get_span_gap.call(edge_span)) * 0.5),
            lane_rect.position.x + 4.0,
            lane_rect.end.x - 4.0
        )
        return Rect2(
            edge_preview_x - 1.5,
            edge_span.rect.position.y + 2.0,
            3.0,
            max(edge_span.rect.size.y - 4.0, 10.0)
        )
    if lane == "condition":
        var trigger_span_index: int = int(find_ace_span_index.call(row_data, "trigger", 0))
        if trigger_span_index >= 0 and trigger_span_index < row_data.spans.size():
            var trigger_span: SemanticSpan = row_data.spans[trigger_span_index]
            var trigger_preview_x: float = clampf(
                trigger_span.rect.end.x + (float(get_span_gap.call(trigger_span)) * 0.5),
                lane_rect.position.x + 4.0,
                lane_rect.end.x - 4.0
            )
            return Rect2(
                trigger_preview_x - 1.5,
                trigger_span.rect.position.y + 2.0,
                3.0,
                max(trigger_span.rect.size.y - 4.0, 10.0)
            )
    var empty_preview_x: float = (
        lane_rect.end.x - action_padding if lane == "action" else lane_rect.position.x + condition_padding
    )
    empty_preview_x = clampf(empty_preview_x, lane_rect.position.x + 4.0, lane_rect.end.x - 4.0)
    return Rect2(empty_preview_x - 1.5, preview_y, 3.0, preview_height)
