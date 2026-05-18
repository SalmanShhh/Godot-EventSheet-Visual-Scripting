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
    var preview_thickness: float = 3.0
    var preview_margin: float = 4.0
    var preview_x: float = lane_rect.position.x + preview_margin
    var preview_width: float = max(lane_rect.size.x - preview_margin * 2.0, 8.0)
    var ace_span_kind: String = "action" if lane == "action" else "condition"
    var ace_span_indices: Array[int] = get_lane_ace_span_indices.call(row_data, ace_span_kind)
    var preview_y: float = lane_rect.position.y + (line_height * 0.5)
    if ace_index >= 0:
        var target_span_index: int = int(find_ace_span_index.call(row_data, ace_span_kind, ace_index))
        if target_span_index >= 0 and target_span_index < row_data.spans.size():
            var target_span: SemanticSpan = row_data.spans[target_span_index]
            preview_y = (
                target_span.rect.end.y - (preview_thickness * 0.5)
                if insert_mode == "after"
                else target_span.rect.position.y - (preview_thickness * 0.5)
            )
            preview_y = clampf(preview_y, lane_rect.position.y + 2.0, lane_rect.end.y - preview_thickness - 2.0)
            return Rect2(preview_x, preview_y, preview_width, preview_thickness)
    if not ace_span_indices.is_empty():
        var edge_span: SemanticSpan = row_data.spans[ace_span_indices[ace_span_indices.size() - 1]]
        preview_y = clampf(
            edge_span.rect.end.y - (preview_thickness * 0.5),
            lane_rect.position.y + 2.0,
            lane_rect.end.y - preview_thickness - 2.0
        )
        return Rect2(preview_x, preview_y, preview_width, preview_thickness)
    if lane == "condition":
        var trigger_span_index: int = int(find_ace_span_index.call(row_data, "trigger", 0))
        if trigger_span_index >= 0 and trigger_span_index < row_data.spans.size():
            var trigger_span: SemanticSpan = row_data.spans[trigger_span_index]
            preview_y = clampf(
                trigger_span.rect.end.y - (preview_thickness * 0.5),
                lane_rect.position.y + 2.0,
                lane_rect.end.y - preview_thickness - 2.0
            )
            return Rect2(preview_x, preview_y, preview_width, preview_thickness)
    var empty_preview_x: float = (
        lane_rect.position.x + max(action_padding, preview_margin)
        if lane == "action"
        else lane_rect.position.x + max(condition_padding, preview_margin)
    )
    preview_x = clampf(empty_preview_x, lane_rect.position.x + preview_margin, lane_rect.end.x - preview_margin - preview_width)
    preview_y = clampf(preview_y, lane_rect.position.y + 2.0, lane_rect.end.y - preview_thickness - 2.0)
    return Rect2(preview_x, preview_y, preview_width, preview_thickness)
