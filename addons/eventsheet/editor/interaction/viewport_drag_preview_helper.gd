@tool
class_name ViewportDragPreviewHelper
extends RefCounted

const PLACEHOLDER_FALLBACK_WIDTH_RATIO := 0.34

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

static func build_ace_drag_visuals(
    row_data: EventRowData,
    lane: String,
    ace_index: int,
    insert_mode: String,
    condition_lane_rect: Rect2,
    action_lane_rect: Rect2,
    row_rect: Rect2,
    line_height: float,
    action_padding: float,
    condition_padding: float,
    find_ace_span_index: Callable,
    get_lane_ace_span_indices: Callable,
    get_span_gap: Callable
) -> Dictionary:
    var insertion_rect: Rect2 = build_ace_drag_preview_rect(
        row_data,
        lane,
        ace_index,
        insert_mode,
        condition_lane_rect,
        action_lane_rect,
        line_height,
        action_padding,
        condition_padding,
        find_ace_span_index,
        get_lane_ace_span_indices,
        get_span_gap
    )
    var lane_rect: Rect2 = action_lane_rect if lane == "action" else condition_lane_rect
    var placeholder_rect: Rect2 = Rect2()
    if lane_rect.size != Vector2.ZERO:
        var ace_span_kind: String = "action" if lane == "action" else "condition"
        var target_span: SemanticSpan = null
        if ace_index >= 0:
            var target_span_index: int = int(find_ace_span_index.call(row_data, ace_span_kind, ace_index))
            if target_span_index >= 0 and target_span_index < row_data.spans.size():
                target_span = row_data.spans[target_span_index]
        var target_span_width: float = lane_rect.size.x * PLACEHOLDER_FALLBACK_WIDTH_RATIO
        if target_span != null:
            target_span_width = target_span.rect.size.x
        var placeholder_height: float = max(min(line_height - 8.0, lane_rect.size.y - 8.0), 10.0)
        var placeholder_width: float = clampf(
            target_span_width,
            72.0,
            max(lane_rect.size.x - 10.0, 72.0)
        )
        var placeholder_center_x: float = (
            insertion_rect.position.x + (insertion_rect.size.x * 0.5)
            if insertion_rect.size != Vector2.ZERO
            else lane_rect.position.x + (lane_rect.size.x * 0.5)
        )
        var placeholder_x: float = clampf(
            placeholder_center_x - (placeholder_width * 0.5),
            lane_rect.position.x + 4.0,
            lane_rect.end.x - placeholder_width - 4.0
        )
        var target_span_y: float = insertion_rect.position.y
        if target_span != null:
            target_span_y = target_span.rect.position.y + 2.0
        var placeholder_y: float = target_span_y
        placeholder_y = clampf(
            placeholder_y,
            lane_rect.position.y + 2.0,
            lane_rect.end.y - placeholder_height - 2.0
        )
        placeholder_rect = Rect2(placeholder_x, placeholder_y, placeholder_width, placeholder_height)
    return {
        "insertion_rect": insertion_rect,
        "placeholder_rect": placeholder_rect,
        "target_block_rect": row_rect.grow(-2.0) if row_rect.size != Vector2.ZERO else Rect2()
    }
