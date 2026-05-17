@tool
class_name EventRowRenderer
extends RefCounted

const ROW_HEIGHT := EventSheetPalette.ROW_HEIGHT
const INDENT_WIDTH := EventSheetPalette.INDENT_WIDTH
const FONT_SIZE := EventSheetPalette.FONT_SIZE
const BG_0 = EventSheetPalette.BG_0
const BG_1 = EventSheetPalette.BG_1
const TEXT_PRIMARY = EventSheetPalette.TEXT_PRIMARY
const TEXT_SECONDARY = EventSheetPalette.TEXT_SECONDARY
const TEXT_MUTED = EventSheetPalette.TEXT_MUTED
const COLOR_OBJECT = EventSheetPalette.COLOR_OBJECT
const COLOR_ACTION = EventSheetPalette.COLOR_ACTION
const COLOR_TRIGGER = EventSheetPalette.COLOR_TRIGGER
const COLOR_VALUE = EventSheetPalette.COLOR_VALUE

func draw_row(control: Control, layout: Dictionary, row_data: EventRowData, font: Font, font_size: int) -> void:
    var row_rect: Rect2 = layout.get("row_rect", Rect2())
    var fold_rect: Rect2 = layout.get("fold_rect", Rect2())
    var icon_rect: Rect2 = layout.get("icon_rect", Rect2())
    var drag_rect: Rect2 = layout.get("drag_rect", Rect2())
    var alternating: bool = bool(layout.get("alternating", false))
    var debug_text: String = str(layout.get("debug_text", ""))
    var editing_span_index: int = int(layout.get("editing_span_index", -1))
    var editing_buffer: String = str(layout.get("editing_buffer", ""))
    var editing_caret: int = int(layout.get("editing_caret", -1))

    control.draw_rect(row_rect, BG_1 if alternating else BG_0, true)
    _draw_indent_guides(control, row_rect, row_data.indent)
    if row_data.selected:
        control.draw_rect(row_rect, EventSheetPalette.COLOR_SELECTION, true)
    if row_data.hovered:
        control.draw_rect(row_rect, EventSheetPalette.COLOR_HOVER, true)
    _draw_fold_arrow(control, fold_rect, row_data.folded, not row_data.children.is_empty())
    _draw_icon(control, icon_rect, row_data)
    _draw_spans(control, row_data, font, font_size, editing_span_index, editing_buffer, editing_caret)
    if drag_rect.size != Vector2.ZERO:
        control.draw_rect(drag_rect, EventSheetPalette.COLOR_DRAG_LINE, true)
    if not debug_text.is_empty():
        _draw_debug_overlay(control, row_rect, font, font_size, debug_text)

func _draw_indent_guides(control: Control, row_rect: Rect2, depth: int) -> void:
    for level: int in range(depth):
        var guide_x: float = row_rect.position.x + EventSheetPalette.GUTTER_WIDTH + float(level * INDENT_WIDTH) + 2.0
        control.draw_line(
            Vector2(guide_x, row_rect.position.y + 4.0),
            Vector2(guide_x, row_rect.end.y - 4.0),
            EventSheetPalette.COLOR_GUIDE,
            1.0,
            true
        )

func _draw_fold_arrow(control: Control, fold_rect: Rect2, folded: bool, visible: bool) -> void:
    if not visible or fold_rect.size == Vector2.ZERO:
        return
    var center: Vector2 = fold_rect.get_center()
    var color: Color = TEXT_MUTED
    if folded:
        control.draw_polyline(
            PackedVector2Array([
                Vector2(center.x - 3.0, center.y - 4.0),
                Vector2(center.x + 2.0, center.y),
                Vector2(center.x - 3.0, center.y + 4.0)
            ]),
            color,
            1.5,
            true
        )
    else:
        control.draw_polyline(
            PackedVector2Array([
                Vector2(center.x - 4.0, center.y - 2.0),
                Vector2(center.x, center.y + 3.0),
                Vector2(center.x + 4.0, center.y - 2.0)
            ]),
            color,
            1.5,
            true
        )

func _draw_icon(control: Control, icon_rect: Rect2, row_data: EventRowData) -> void:
    if icon_rect.size == Vector2.ZERO:
        return
    var color: Color = COLOR_OBJECT
    match row_data.row_type:
        EventRowData.RowType.GROUP:
            color = COLOR_TRIGGER
        EventRowData.RowType.COMMENT:
            color = EventSheetPalette.COLOR_COMMENT
        EventRowData.RowType.SECTION:
            color = TEXT_MUTED
    control.draw_rect(icon_rect, color, true)

func _draw_spans(control: Control, row_data: EventRowData, font: Font, font_size: int, editing_span_index: int, editing_buffer: String, editing_caret: int) -> void:
    for span_index: int in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null:
            continue
        var color: Color = _get_span_color(span.type)
        var draw_text: String = editing_buffer if span_index == editing_span_index else span.text
        var baseline_y: float = span.rect.position.y + (span.rect.size.y * 0.5) + (font_size * 0.35)
        control.draw_string(font, Vector2(span.rect.position.x, baseline_y), draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
        if span_index == editing_span_index:
            var prefix: String = draw_text.substr(0, clamp(editing_caret, 0, draw_text.length()))
            var prefix_width: float = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
            var caret_x: float = span.rect.position.x + prefix_width + 1.0
            control.draw_line(
                Vector2(caret_x, span.rect.position.y + 5.0),
                Vector2(caret_x, span.rect.end.y - 5.0),
                TEXT_PRIMARY,
                1.0,
                true
            )

func _draw_debug_overlay(control: Control, row_rect: Rect2, font: Font, font_size: int, debug_text: String) -> void:
    var badge_width: float = font.get_string_size(debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size - 1).x + 10.0
    var badge_rect := Rect2(row_rect.end.x - badge_width - 8.0, row_rect.position.y + 5.0, badge_width, row_rect.size.y - 10.0)
    control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 4.0, row_rect.size.y), EventSheetPalette.COLOR_DEBUG, true)
    control.draw_rect(badge_rect, EventSheetPalette.COLOR_DEBUG, true)
    var baseline_y: float = badge_rect.position.y + (badge_rect.size.y * 0.5) + ((font_size - 1) * 0.35)
    control.draw_string(font, Vector2(badge_rect.position.x + 5.0, baseline_y), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size - 1, EventSheetPalette.COLOR_DEBUG_TEXT)

func _get_span_color(span_type: int) -> Color:
    match span_type:
        SemanticSpan.SpanType.OBJECT:
            return COLOR_OBJECT
        SemanticSpan.SpanType.CONDITION:
            return TEXT_PRIMARY
        SemanticSpan.SpanType.ACTION:
            return COLOR_ACTION
        SemanticSpan.SpanType.VALUE:
            return COLOR_VALUE
        SemanticSpan.SpanType.OPERATOR:
            return TEXT_SECONDARY
        SemanticSpan.SpanType.KEYWORD:
            return TEXT_MUTED
        SemanticSpan.SpanType.EXPRESSION:
            return TEXT_PRIMARY
        SemanticSpan.SpanType.COMMENT:
            return EventSheetPalette.COLOR_COMMENT
        _:
            return TEXT_PRIMARY
