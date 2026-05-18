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
const ROW_VERTICAL_CENTER_RATIO := 0.5
const FONT_BASELINE_OFFSET_RATIO := 0.35
const BADGE_FONT_SIZE_DELTA := 1

var _ui_config: EventSheetUIConfig = null

func set_ui_config(config: EventSheetUIConfig) -> void:
    _ui_config = config

func draw_row(control: Control, layout: Dictionary, row_data: EventRowData, font: Font, font_size: int) -> void:
    var row_rect: Rect2 = layout.get("row_rect", Rect2())
    var gutter_rect: Rect2 = layout.get("gutter_rect", Rect2())
    var fold_rect: Rect2 = layout.get("fold_rect", Rect2())
    var icon_rect: Rect2 = layout.get("icon_rect", Rect2())
    var drag_rect: Rect2 = layout.get("drag_rect", Rect2())
    var ace_drag_rect: Rect2 = layout.get("ace_drag_rect", Rect2())
    var ace_drag_error: bool = bool(layout.get("ace_drag_error", false))
    var drag_feedback_rect: Rect2 = layout.get("drag_feedback_rect", Rect2())
    var drag_feedback_text: String = str(layout.get("drag_feedback_text", ""))
    var drag_feedback_error: bool = bool(layout.get("drag_feedback_error", false))
    var condition_lane_rect: Rect2 = layout.get("condition_lane_rect", Rect2())
    var action_lane_rect: Rect2 = layout.get("action_lane_rect", Rect2())
    var lane_divider_rect: Rect2 = layout.get("lane_divider_rect", Rect2())
    var alternating: bool = bool(layout.get("alternating", false))
    var debug_text: String = str(layout.get("debug_text", ""))
    var editing_span_index: int = int(layout.get("editing_span_index", -1))
    var editing_buffer: String = str(layout.get("editing_buffer", ""))
    var editing_caret: int = int(layout.get("editing_caret", -1))
    var selected_span_indices: Array = layout.get("selected_span_indices", [])
    var hovered_span_index: int = int(layout.get("hovered_span_index", -1))
    var line_number: int = int(layout.get("line_number", 0))
    var breakpoint_enabled: bool = bool(layout.get("breakpoint_enabled", false))
    var disabled: bool = bool(layout.get("disabled", false))
    var has_span_selection: bool = not selected_span_indices.is_empty()

    var selection_color: Color = _ui_config.selection_color if _ui_config != null else EventSheetPalette.COLOR_SELECTION
    var hover_color: Color = _ui_config.hover_color if _ui_config != null else EventSheetPalette.COLOR_HOVER
    var lane_conditions_color: Color = _ui_config.lane_conditions_color if _ui_config != null else EventSheetPalette.COLOR_LANE_CONDITIONS
    var lane_actions_color: Color = _ui_config.lane_actions_color if _ui_config != null else EventSheetPalette.COLOR_LANE_ACTIONS
    var lane_divider_color: Color = _ui_config.lane_divider_color if _ui_config != null else EventSheetPalette.COLOR_LANE_DIVIDER
    var row_bg_color: Color = _ui_config.row_bg_color if _ui_config != null else BG_0
    var row_bg_alt_color: Color = _ui_config.row_bg_alt_color if _ui_config != null else BG_1

    _draw_gutter(control, gutter_rect, line_number, breakpoint_enabled, font, font_size)
    if row_data.row_type == EventRowData.RowType.GROUP:
        _draw_group_row_chrome(control, row_rect, fold_rect, alternating)
    else:
        control.draw_rect(row_rect, row_bg_alt_color if alternating else row_bg_color, true)
    if condition_lane_rect.size != Vector2.ZERO:
        control.draw_rect(condition_lane_rect, lane_conditions_color, true)
    if action_lane_rect.size != Vector2.ZERO:
        control.draw_rect(action_lane_rect, lane_actions_color, true)
    if lane_divider_rect.size != Vector2.ZERO:
        control.draw_rect(lane_divider_rect, lane_divider_color, true)
    _draw_indent_guides(control, row_rect, row_data.indent)
    if row_data.selected and not has_span_selection:
        control.draw_rect(row_rect, selection_color, true)
    if row_data.hovered:
        control.draw_rect(row_rect, hover_color, true)
    _draw_fold_arrow(control, fold_rect, row_data.folded, not row_data.children.is_empty())
    _draw_icon(control, icon_rect, row_data)
    _draw_spans(control, row_data, font, font_size, editing_span_index, editing_buffer, editing_caret, selected_span_indices, hovered_span_index)
    if drag_rect.size != Vector2.ZERO:
        control.draw_rect(drag_rect, EventSheetPalette.COLOR_DRAG_LINE, true)
    if ace_drag_rect.size != Vector2.ZERO:
        control.draw_rect(
            ace_drag_rect,
            EventSheetPalette.COLOR_BREAKPOINT if ace_drag_error else EventSheetPalette.COLOR_DRAG_LINE,
            ace_drag_rect.size.y <= 4.0,
            2.0
        )
    if drag_feedback_rect.size != Vector2.ZERO and not drag_feedback_text.is_empty():
        _draw_drag_feedback(control, drag_feedback_rect, drag_feedback_text, font, font_size, drag_feedback_error)
    if disabled:
        control.draw_rect(row_rect, EventSheetPalette.COLOR_DISABLED, true)
    if not debug_text.is_empty():
        _draw_debug_overlay(control, row_rect, font, font_size, debug_text)

func _draw_gutter(control: Control, gutter_rect: Rect2, line_number: int, breakpoint_enabled: bool, font: Font, font_size: int) -> void:
    if gutter_rect.size == Vector2.ZERO:
        return
    control.draw_rect(gutter_rect, EventSheetPalette.COLOR_GUTTER_BG, true)
    control.draw_rect(Rect2(gutter_rect.end.x - 1.0, gutter_rect.position.y, 1.0, gutter_rect.size.y), EventSheetPalette.COLOR_GUTTER_RAIL, true)
    if line_number > 0:
        var text: String = str(line_number)
        var baseline_y: float = gutter_rect.position.y + (gutter_rect.size.y * ROW_VERTICAL_CENTER_RATIO) + ((font_size - 1) * FONT_BASELINE_OFFSET_RATIO)
        control.draw_string(font, Vector2(gutter_rect.position.x + 4.0, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, gutter_rect.size.x - 8.0, font_size - 1, EventSheetPalette.COLOR_GUTTER_TEXT)
    if breakpoint_enabled:
        var center: Vector2 = Vector2(gutter_rect.position.x + 7.0, gutter_rect.get_center().y)
        control.draw_circle(center, 3.5, EventSheetPalette.COLOR_BREAKPOINT)

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

func _draw_group_row_chrome(control: Control, row_rect: Rect2, fold_rect: Rect2, alternating: bool) -> void:
    var bg: Color = (
        (_ui_config.group_bg_alt_color if _ui_config != null else EventSheetPalette.COLOR_GROUP_BG_ALT)
        if alternating
        else (_ui_config.group_bg_color if _ui_config != null else EventSheetPalette.COLOR_GROUP_BG)
    )
    var accent: Color = _ui_config.group_accent_color if _ui_config != null else EventSheetPalette.COLOR_GROUP_ACCENT
    var fold_bg: Color = _ui_config.group_fold_bg_color if _ui_config != null else EventSheetPalette.COLOR_GROUP_FOLD_BG
    control.draw_rect(row_rect, bg, true)
    control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 3.0, row_rect.size.y), accent, true)
    control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, row_rect.size.x, 1.0), accent.darkened(0.28), true)
    control.draw_rect(Rect2(row_rect.position.x, row_rect.end.y - 1.0, row_rect.size.x, 1.0), accent.darkened(0.38), true)
    if fold_rect.size != Vector2.ZERO:
        control.draw_rect(fold_rect.grow(1.0), fold_bg, true)

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

func _draw_spans(control: Control, row_data: EventRowData, font: Font, font_size: int, editing_span_index: int, editing_buffer: String, editing_caret: int, selected_span_indices: Array, hovered_span_index: int) -> void:
    var selection_color: Color = _ui_config.selection_color if _ui_config != null else EventSheetPalette.COLOR_SELECTION
    var hover_color: Color = _ui_config.hover_color if _ui_config != null else EventSheetPalette.COLOR_HOVER
    var group_title_color: Color = _ui_config.group_title_color if _ui_config != null else EventSheetPalette.COLOR_GROUP_TITLE
    for span_index: int in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null:
            continue
        var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
        if bool(metadata.get("chip", false)):
            _draw_chip_span(control, span, metadata)
        if selected_span_indices.has(span_index):
            var selected_bg: Color = selection_color
            selected_bg.a = 0.72
            control.draw_rect(span.rect.grow(2.0), selected_bg, true)
        elif span_index == hovered_span_index:
            var hover_bg: Color = hover_color
            hover_bg.a = 0.6
            control.draw_rect(span.rect.grow(1.0), hover_bg, true)
        if bool(metadata.get("badge", false)):
            _draw_badge_span(control, span, font, font_size, metadata)
            continue
        var color: Color = _get_span_color(span.type)
        if row_data.row_type == EventRowData.RowType.GROUP and bool(metadata.get("group_title", false)):
            color = group_title_color
        var draw_text: String = editing_buffer if span_index == editing_span_index else span.text
        var draw_font_size: int = font_size + 1 if row_data.row_type == EventRowData.RowType.GROUP and bool(metadata.get("group_title", false)) else font_size
        var baseline_y: float = span.rect.position.y + (span.rect.size.y * ROW_VERTICAL_CENTER_RATIO) + (draw_font_size * FONT_BASELINE_OFFSET_RATIO)
        var text_x: float = span.rect.position.x + (8.0 if bool(metadata.get("chip", false)) else 0.0)
        var right_padding: float = 8.0 if bool(metadata.get("chip", false)) else 2.0
        var text_width: float = max(span.rect.size.x - (text_x - span.rect.position.x) - right_padding, 1.0)
        control.draw_string(font, Vector2(text_x, baseline_y), draw_text, HORIZONTAL_ALIGNMENT_LEFT, text_width, draw_font_size, color)
        if span_index == editing_span_index:
            var prefix: String = draw_text.substr(0, clamp(editing_caret, 0, draw_text.length()))
            var prefix_width: float = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
            var caret_x: float = min(text_x + prefix_width + 1.0, span.rect.end.x - right_padding)
            control.draw_line(
                Vector2(caret_x, span.rect.position.y + 5.0),
                Vector2(caret_x, span.rect.end.y - 5.0),
                TEXT_PRIMARY,
                1.0,
                true
            )

func _draw_chip_span(control: Control, span: SemanticSpan, metadata: Dictionary) -> void:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    var colors: Dictionary = _resolve_chip_colors(metadata)
    style.bg_color = colors.get("bg", Color(1.0, 1.0, 1.0, 0.05))
    style.border_color = colors.get("border", Color(1.0, 1.0, 1.0, 0.14))
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.set_content_margin_all(0)
    control.draw_style_box(style, span.rect)

func _draw_drag_feedback(
    control: Control,
    rect: Rect2,
    text: String,
    font: Font,
    font_size: int,
    is_error: bool
) -> void:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = (
        Color(0.45, 0.14, 0.17, 0.96)
        if is_error
        else Color(0.17, 0.21, 0.28, 0.96)
    )
    style.border_color = (
        EventSheetPalette.COLOR_BREAKPOINT
        if is_error
        else EventSheetPalette.COLOR_DRAG_LINE
    )
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    style.set_content_margin_all(0)
    control.draw_style_box(style, rect)
    var baseline_y: float = rect.position.y + (rect.size.y * ROW_VERTICAL_CENTER_RATIO) + ((font_size - 2) * FONT_BASELINE_OFFSET_RATIO)
    control.draw_string(
        font,
        Vector2(rect.position.x + 8.0, baseline_y),
        text,
        HORIZONTAL_ALIGNMENT_LEFT,
        rect.size.x - 16.0,
        max(font_size - 1, 10),
        Color(1.0, 1.0, 1.0, 0.96)
    )
func _draw_badge_span(control: Control, span: SemanticSpan, font: Font, font_size: int, metadata: Dictionary) -> void:
    var badge_rect: Rect2 = span.rect
    var badge_colors: Dictionary = _resolve_badge_colors(metadata)
    var badge_bg: Color = badge_colors.get("bg", EventSheetPalette.COLOR_LANE_DIVIDER)
    var badge_fg: Color = badge_colors.get("fg", TEXT_PRIMARY)
    var badge_style: String = str(metadata.get("badge_style", ""))
    if badge_style in ["trigger", "negated"]:
        var radius: float = min(badge_rect.size.x, badge_rect.size.y) * 0.45
        control.draw_circle(badge_rect.get_center(), radius, badge_bg)
    else:
        var style: StyleBoxFlat = StyleBoxFlat.new()
        style.bg_color = badge_bg
        style.set_corner_radius_all(4)
        style.set_content_margin_all(0)
        control.draw_style_box(style, badge_rect)
    var text: String = span.text
    var text_size: Vector2 = font.get_string_size(
        text,
        HORIZONTAL_ALIGNMENT_LEFT,
        -1.0,
        font_size - BADGE_FONT_SIZE_DELTA
    )
    var text_x: float = badge_rect.position.x + max((badge_rect.size.x - text_size.x) * 0.5, 3.0)
    var baseline_y: float = badge_rect.position.y + (badge_rect.size.y * ROW_VERTICAL_CENTER_RATIO) + ((font_size - BADGE_FONT_SIZE_DELTA) * FONT_BASELINE_OFFSET_RATIO)
    control.draw_string(
        font,
        Vector2(text_x, baseline_y),
        text,
        HORIZONTAL_ALIGNMENT_LEFT,
        -1.0,
        font_size - BADGE_FONT_SIZE_DELTA,
        badge_fg
    )

func _draw_debug_overlay(control: Control, row_rect: Rect2, font: Font, font_size: int, debug_text: String) -> void:
    var badge_width: float = font.get_string_size(debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size - 1).x + 10.0
    var badge_rect := Rect2(row_rect.end.x - badge_width - 8.0, row_rect.position.y + 5.0, badge_width, row_rect.size.y - 10.0)
    control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 4.0, row_rect.size.y), EventSheetPalette.COLOR_DEBUG, true)
    control.draw_rect(badge_rect, EventSheetPalette.COLOR_DEBUG, true)
    var baseline_y: float = badge_rect.position.y + (badge_rect.size.y * ROW_VERTICAL_CENTER_RATIO) + ((font_size - 1) * FONT_BASELINE_OFFSET_RATIO)
    control.draw_string(font, Vector2(badge_rect.position.x + 5.0, baseline_y), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size - 1, EventSheetPalette.COLOR_DEBUG_TEXT)

func _get_span_color(span_type: int) -> Color:
    match span_type:
        SemanticSpan.SpanType.OBJECT:
            return _ui_config.object_text_color if _ui_config != null else COLOR_OBJECT
        SemanticSpan.SpanType.CONDITION:
            return _ui_config.condition_text_color if _ui_config != null else TEXT_PRIMARY
        SemanticSpan.SpanType.ACTION:
            return _ui_config.action_text_color if _ui_config != null else COLOR_ACTION
        SemanticSpan.SpanType.VALUE:
            return _ui_config.value_text_color if _ui_config != null else COLOR_VALUE
        SemanticSpan.SpanType.OPERATOR:
            return _ui_config.text_secondary_color if _ui_config != null else TEXT_SECONDARY
        SemanticSpan.SpanType.KEYWORD:
            return _ui_config.text_muted_color if _ui_config != null else TEXT_MUTED
        SemanticSpan.SpanType.EXPRESSION:
            return _ui_config.text_primary_color if _ui_config != null else TEXT_PRIMARY
        SemanticSpan.SpanType.COMMENT:
            return _ui_config.comment_text_color if _ui_config != null else EventSheetPalette.COLOR_COMMENT
        _:
            return _ui_config.text_primary_color if _ui_config != null else TEXT_PRIMARY

func _resolve_chip_colors(metadata: Dictionary) -> Dictionary:
    if _ui_config == null:
        return {
            "bg": metadata.get("chip_bg", Color(1.0, 1.0, 1.0, 0.05)),
            "border": metadata.get("chip_border", Color(1.0, 1.0, 1.0, 0.14))
        }
    var kind: String = str(metadata.get("kind", ""))
    var lane: String = str(metadata.get("lane", ""))
    if kind == "variable":
        return {
            "bg": _ui_config.variable_chip_bg_color,
            "border": _ui_config.variable_chip_border_color
        }
    if lane == "action":
        return {
            "bg": _ui_config.action_chip_bg_color,
            "border": _ui_config.action_chip_border_color
        }
    if lane == "condition":
        return {
            "bg": _ui_config.condition_chip_bg_color,
            "border": _ui_config.condition_chip_border_color
        }
    if bool(metadata.get("group_title", false)):
        return {
            "bg": _ui_config.group_bg_alt_color if bool(metadata.get("chip_alt", false)) else _ui_config.group_bg_color,
            "border": _ui_config.group_accent_color
        }
    return {
        "bg": _ui_config.comment_chip_bg_color,
        "border": _ui_config.comment_chip_border_color
    }

func _resolve_badge_colors(metadata: Dictionary) -> Dictionary:
    if _ui_config == null:
        return {
            "bg": metadata.get("badge_bg", EventSheetPalette.COLOR_LANE_DIVIDER),
            "fg": metadata.get("badge_fg", TEXT_PRIMARY)
        }
    var style: String = str(metadata.get("badge_style", ""))
    match style:
        "group":
            return {"bg": _ui_config.group_badge_bg_color, "fg": _ui_config.group_badge_fg_color}
        "const":
            return {"bg": _ui_config.const_badge_bg_color, "fg": _ui_config.const_badge_fg_color}
        "trigger":
            return {"bg": _ui_config.trigger_badge_bg_color, "fg": _ui_config.trigger_badge_fg_color}
        "or":
            return {"bg": _ui_config.or_badge_bg_color, "fg": _ui_config.or_badge_fg_color}
        "negated":
            return {"bg": _ui_config.negated_badge_bg_color, "fg": _ui_config.negated_badge_fg_color}
        _:
            return {
                "bg": metadata.get("badge_bg", EventSheetPalette.COLOR_LANE_DIVIDER),
                "fg": metadata.get("badge_fg", _ui_config.text_primary_color)
            }
