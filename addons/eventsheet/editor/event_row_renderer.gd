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
# Object icon drawn before the object label in ACE cells (C3 grammar). The advance must
# stay in sync with _measure_span_width in the viewport or hit-testing drifts.
const OBJECT_ICON_SIZE := 14.0
const OBJECT_ICON_ADVANCE := 18.0
const BADGE_FONT_SIZE_DELTA := 1
const BADGE_MIN_HORIZONTAL_PADDING := 1.0
const SELECTION_OUTLINE_LIGHTEN := 0.28
const SELECTION_OUTLINE_ALPHA := 0.92
const HOVER_OUTLINE_LIGHTEN := 0.35
const HOVER_OUTLINE_ALPHA := 0.84
const CHIP_HOVER_ACCENT_BLEND := 0.22
const CHIP_HOVER_MIN_ALPHA := 0.42
const CHIP_HOVER_BORDER_BLEND := 0.55
const CHIP_HOVER_BORDER_ALPHA := 0.96
const CHIP_SELECT_ACCENT_BLEND := 0.22
const CHIP_SELECT_ALPHA_MULTI := 0.62
const CHIP_SELECT_ALPHA_SINGLE := 0.55
const CHIP_SELECT_BORDER_LIGHTEN := 0.32
const CHIP_SELECT_BORDER_ALPHA := 0.98
const CHIP_SELECT_INDICATOR_OFFSET := 2.0
const CHIP_SELECT_INDICATOR_WIDTH := 3.0
const CHIP_SELECT_INDICATOR_MARGIN := 4.0
const CHIP_SELECT_INDICATOR_MIN_HEIGHT := 2.0
const SPAN_SELECT_OUTLINE_LIGHTEN := 0.3
const SPAN_SELECT_OUTLINE_ALPHA := 0.95
const SPAN_HOVER_OUTLINE_LIGHTEN := 0.28
const SPAN_HOVER_OUTLINE_ALPHA := 0.82

## C3-style insert marker: arrowheads at both ends of a thin drop line so the insert point
## reads instantly (mirrors Construct 3's tree-insert-mark).
func _draw_insert_marker_arrows(control: Control, line_rect: Rect2, color: Color) -> void:
    var mid_y: float = line_rect.get_center().y
    var arrow: float = 5.0
    control.draw_colored_polygon(PackedVector2Array([
        Vector2(line_rect.position.x, mid_y - arrow),
        Vector2(line_rect.position.x + arrow, mid_y),
        Vector2(line_rect.position.x, mid_y + arrow)
    ]), color)
    control.draw_colored_polygon(PackedVector2Array([
        Vector2(line_rect.end.x, mid_y - arrow),
        Vector2(line_rect.end.x - arrow, mid_y),
        Vector2(line_rect.end.x, mid_y + arrow)
    ]), color)

## Draws ACE text with its parameter values highlighted (C3-style): plain segments use the
## base colour, value segments (numbers / quoted strings / booleans, precomputed at span
## build) use the value colour. Segments advance by measured logical width and stop at the
## clip width.
func _draw_text_with_values(
    control: Control,
    baseline: Vector2,
    text: String,
    value_ranges: Array,
    max_width: float,
    font: Font,
    font_size: int,
    base_color: Color,
    value_color: Color = COLOR_VALUE
) -> void:
    var cursor: int = 0
    var x: float = baseline.x
    var limit: float = baseline.x + max_width
    for range_entry in value_ranges:
        if not (range_entry is Array) or (range_entry as Array).size() < 2:
            continue
        var start: int = int(range_entry[0])
        var length: int = int(range_entry[1])
        if start < cursor or start >= text.length():
            continue
        var plain: String = text.substr(cursor, start - cursor)
        if not plain.is_empty() and x < limit:
            _draw_text(control, Vector2(x, baseline.y), plain, limit - x, font, font_size, base_color)
            x += font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
        var value_text: String = text.substr(start, length)
        if not value_text.is_empty() and x < limit:
            _draw_text(control, Vector2(x, baseline.y), value_text, limit - x, font, font_size, value_color)
            x += font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
        cursor = start + length
        if x >= limit:
            return
    var tail: String = text.substr(cursor)
    if not tail.is_empty() and x < limit:
        _draw_text(control, Vector2(x, baseline.y), tail, limit - x, font, font_size, base_color)

## Draws text crisply under the viewport's zoom: the canvas transform scales geometry, but
## glyphs scaled that way blur (zoom in) or alias (zoom out). This rasterizes the text at its
## final physical pixel size in identity space instead, then restores the zoom transform.
func _draw_text(
    control: Control,
    baseline: Vector2,
    text: String,
    max_width: float,
    font: Font,
    font_size: int,
    color: Color
) -> void:
    var zoom: float = control.get_zoom_factor() if control.has_method("get_zoom_factor") else 1.0
    if is_equal_approx(zoom, 1.0):
        control.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)
        return
    var physical_size: int = maxi(int(round(font_size * zoom)), 6)
    # Small slack so hinting differences at the rounded physical size don't clip the last glyph.
    var physical_width: float = max_width * zoom + 4.0 if max_width > 0.0 else max_width
    control.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    control.draw_string(font, baseline * zoom, text, HORIZONTAL_ALIGNMENT_LEFT, physical_width, physical_size, color)
    control.draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))

func draw_row(control: Control, layout: Dictionary, row_data: EventRowData, font: Font, font_size: int, editor_style: EventSheetEditorStyle = null) -> void:
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
    var total_selected_spans: int = int(layout.get("total_selected_spans", 0))
    var line_number: int = int(layout.get("line_number", 0))
    var breakpoint_enabled: bool = bool(layout.get("breakpoint_enabled", false))
    var disabled: bool = bool(layout.get("disabled", false))
    var has_span_selection: bool = not selected_span_indices.is_empty()
    var event_style: EventSheetEventStyle = (
        editor_style.get_event_style()
        if editor_style != null
        else null
    )
    var selection_fill: Color = (
        event_style.selection_fill_color
        if event_style != null
        else EventSheetPalette.COLOR_SELECTION
    )
    var hover_fill: Color = (
        event_style.hover_fill_color
        if event_style != null
        else EventSheetPalette.COLOR_HOVER
    )

    _draw_gutter(control, gutter_rect, line_number, breakpoint_enabled, row_data.bookmark_enabled, font, font_size)
    if row_data.row_type == EventRowData.RowType.GROUP:
        _draw_group_row_chrome(control, row_rect, fold_rect, alternating, event_style)
    elif row_data.row_type == EventRowData.RowType.COMMENT and event_style != null:
        # Per-comment colors (C3 parity): the row's custom tint wins over the theme token.
        var comment_bg: Color = row_data.custom_color if row_data.custom_color.a > 0.01 else event_style.comment_row_background_color
        control.draw_rect(row_rect, comment_bg, true)
    elif row_data.row_type == EventRowData.RowType.EVENT and event_style != null:
        control.draw_rect(
            row_rect,
            event_style.row_background_alt_color if alternating else event_style.row_background_color,
            true
        )
    else:
        control.draw_rect(row_rect, BG_1 if alternating else BG_0, true)
    if condition_lane_rect.size != Vector2.ZERO:
        control.draw_rect(
            condition_lane_rect,
            event_style.condition_lane_color if event_style != null else EventSheetPalette.COLOR_LANE_CONDITIONS,
            true
        )
    if action_lane_rect.size != Vector2.ZERO:
        control.draw_rect(
            action_lane_rect,
            event_style.action_lane_color if event_style != null else EventSheetPalette.COLOR_LANE_ACTIONS,
            true
        )
    if lane_divider_rect.size != Vector2.ZERO:
        control.draw_rect(
            lane_divider_rect,
            event_style.lane_divider_color if event_style != null else EventSheetPalette.COLOR_LANE_DIVIDER,
            true
        )
    if row_data.row_type == EventRowData.RowType.EVENT and event_style != null:
        var block_border: Color = event_style.row_border_color
        control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, row_rect.size.x, 1.0), block_border, true)
        control.draw_rect(Rect2(row_rect.position.x, row_rect.end.y - 1.0, row_rect.size.x, 1.0), block_border, true)
    _draw_indent_guides(control, row_rect, row_data.indent)
    if row_data.selected and not has_span_selection:
        control.draw_rect(row_rect, selection_fill, true)
        if row_data.row_type != EventRowData.RowType.EVENT:
            _draw_row_outline(control, row_rect, selection_fill, SELECTION_OUTLINE_LIGHTEN, SELECTION_OUTLINE_ALPHA)
    # Hover feedback: individual conditions/actions highlight per-cell (drawn in _draw_spans).
    # Whole-row hover is only for single-cell rows (group/comment/variable); on a multi-cell
    # event it lights up the entire block and reads as "selected", which is confusing.
    if row_data.hovered and row_data.row_type != EventRowData.RowType.EVENT:
        control.draw_rect(row_rect, hover_fill, true)
        _draw_row_outline(control, row_rect, hover_fill, HOVER_OUTLINE_LIGHTEN, HOVER_OUTLINE_ALPHA)
    _draw_fold_arrow(control, fold_rect, row_data.folded, not row_data.children.is_empty())
    _draw_icon(control, icon_rect, row_data)
    _draw_spans(control, row_data, font, font_size, editing_span_index, editing_buffer, editing_caret, selected_span_indices, hovered_span_index, total_selected_spans, event_style, selection_fill, hover_fill)
    if drag_rect.size != Vector2.ZERO:
        control.draw_rect(drag_rect, EventSheetPalette.COLOR_DRAG_LINE, true)
        if drag_rect.size.y <= 4.0:
            _draw_insert_marker_arrows(control, drag_rect, EventSheetPalette.COLOR_DRAG_LINE)
    if ace_drag_rect.size != Vector2.ZERO:
        var ace_drag_color: Color = EventSheetPalette.COLOR_BREAKPOINT if ace_drag_error else EventSheetPalette.COLOR_DRAG_LINE
        control.draw_rect(ace_drag_rect, ace_drag_color, ace_drag_rect.size.y <= 4.0, 2.0)
        if ace_drag_rect.size.y <= 4.0:
            _draw_insert_marker_arrows(control, ace_drag_rect, ace_drag_color)
    if drag_feedback_rect.size != Vector2.ZERO and not drag_feedback_text.is_empty():
        _draw_drag_feedback(control, drag_feedback_rect, drag_feedback_text, font, font_size, drag_feedback_error)
    if disabled:
        control.draw_rect(row_rect, EventSheetPalette.COLOR_DISABLED, true)
    if not debug_text.is_empty():
        _draw_debug_overlay(control, row_rect, font, font_size, debug_text)

func _draw_gutter(control: Control, gutter_rect: Rect2, line_number: int, breakpoint_enabled: bool, bookmark_enabled: bool, font: Font, font_size: int) -> void:
    if gutter_rect.size == Vector2.ZERO:
        return
    control.draw_rect(gutter_rect, EventSheetPalette.COLOR_GUTTER_BG, true)
    control.draw_rect(Rect2(gutter_rect.end.x - 1.0, gutter_rect.position.y, 1.0, gutter_rect.size.y), EventSheetPalette.COLOR_GUTTER_RAIL, true)
    if line_number > 0:
        var text: String = str(line_number)
        var baseline_y: float = gutter_rect.position.y + (gutter_rect.size.y * ROW_VERTICAL_CENTER_RATIO) + ((font_size - 1) * FONT_BASELINE_OFFSET_RATIO)
        _draw_text(control, Vector2(gutter_rect.position.x + 4.0, baseline_y), text, gutter_rect.size.x - 8.0, font, font_size - 1, EventSheetPalette.COLOR_GUTTER_TEXT)
    if breakpoint_enabled:
        var center: Vector2 = Vector2(gutter_rect.position.x + 7.0, gutter_rect.get_center().y)
        control.draw_circle(center, 3.5, EventSheetPalette.COLOR_BREAKPOINT)
    if bookmark_enabled:
        # Bookmark flag: a small right-pointing pennant at the gutter's right edge.
        var flag_x: float = gutter_rect.end.x - 10.0
        var flag_y: float = gutter_rect.get_center().y
        control.draw_colored_polygon(PackedVector2Array([
            Vector2(flag_x, flag_y - 4.0),
            Vector2(flag_x + 7.0, flag_y),
            Vector2(flag_x, flag_y + 4.0)
        ]), EventSheetPalette.COLOR_BOOKMARK)

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

func _draw_row_outline(control: Control, row_rect: Rect2, base_color: Color, lighten: float, alpha: float) -> void:
    var outline: Color = base_color.lightened(lighten)
    outline.a = alpha
    control.draw_rect(row_rect.grow(-0.5), outline, false, 1.0)

func _draw_group_row_chrome(control: Control, row_rect: Rect2, fold_rect: Rect2, alternating: bool, event_style: EventSheetEventStyle = null) -> void:
    var bg: Color = EventSheetPalette.COLOR_GROUP_BG_ALT if alternating else EventSheetPalette.COLOR_GROUP_BG
    if event_style != null:
        bg = event_style.group_background_alt_color if alternating else event_style.group_background_color
    var accent: Color = event_style.group_accent_color if event_style != null else EventSheetPalette.COLOR_GROUP_ACCENT
    var fold_bg: Color = event_style.group_fold_background_color if event_style != null else EventSheetPalette.COLOR_GROUP_FOLD_BG
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

func _draw_spans(
    control: Control,
    row_data: EventRowData,
    font: Font,
    font_size: int,
    editing_span_index: int,
    editing_buffer: String,
    editing_caret: int,
    selected_span_indices: Array,
    hovered_span_index: int,
    total_selected_spans: int,
    event_style: EventSheetEventStyle = null,
    selection_fill: Color = EventSheetPalette.COLOR_SELECTION,
    hover_fill: Color = EventSheetPalette.COLOR_HOVER
) -> void:
    for span_index: int in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null:
            continue
        var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
        if bool(metadata.get("chip", false)):
            _draw_chip_span(control, span, metadata)
        if selected_span_indices.has(span_index):
            if bool(metadata.get("chip", false)):
                _draw_chip_selected_span(control, span, metadata, selection_fill, total_selected_spans > 1)
            else:
                var selected_bg: Color = selection_fill
                selected_bg.a = 0.72
                control.draw_rect(span.rect.grow(2.0), selected_bg, true)
                var selected_outline: Color = selection_fill.lightened(SPAN_SELECT_OUTLINE_LIGHTEN)
                selected_outline.a = SPAN_SELECT_OUTLINE_ALPHA
                control.draw_rect(span.rect.grow(2.0), selected_outline, false, 1.0)
        elif span_index == hovered_span_index:
            if bool(metadata.get("chip", false)):
                _draw_cell_hover(control, span.rect, event_style.cell_hover_color if event_style != null else Color(1.0, 1.0, 1.0, 0.14))
            else:
                var hover_bg: Color = hover_fill
                hover_bg.a = 0.46
                control.draw_rect(span.rect.grow(1.0), hover_bg, true)
                var hover_outline: Color = hover_fill.lightened(SPAN_HOVER_OUTLINE_LIGHTEN)
                hover_outline.a = SPAN_HOVER_OUTLINE_ALPHA
                control.draw_rect(span.rect.grow(1.0), hover_outline, false, 1.5)
        if bool(metadata.get("badge", false)):
            _draw_badge_span(control, span, font, font_size, metadata)
            continue
        var color: Color = metadata.get("text_color", _get_span_color(span.type, event_style))
        var ace_enabled: bool = bool(metadata.get("ace_enabled", true))
        if not ace_enabled:
            color = color.lerp(TEXT_MUTED, 0.6)
        if row_data.row_type == EventRowData.RowType.GROUP and bool(metadata.get("group_title", false)):
            color = event_style.group_title_color if event_style != null else EventSheetPalette.COLOR_GROUP_TITLE
        var draw_text: String = editing_buffer if span_index == editing_span_index else span.text
        var draw_font_size: int = EventSheetPalette.resolve_font_size(
            font_size,
            int(metadata.get("font_size_delta", 0))
        )
        if row_data.row_type == EventRowData.RowType.GROUP and bool(metadata.get("group_title", false)):
            draw_font_size = EventSheetPalette.resolve_font_size(draw_font_size, 0, 1)
        var baseline_y: float = span.rect.position.y + (span.rect.size.y * ROW_VERTICAL_CENTER_RATIO) + (draw_font_size * FONT_BASELINE_OFFSET_RATIO)
        var text_padding: float = float(metadata.get("padding_x", 0.0)) if bool(metadata.get("chip", false)) else 0.0
        var text_x: float = span.rect.position.x + text_padding
        var right_padding: float = text_padding if bool(metadata.get("chip", false)) else 2.0
        var text_width: float = max(span.rect.size.x - (text_x - span.rect.position.x) - right_padding, 1.0)
        # Construct 3-style object icon + label drawn before the ACE text
        # (e.g. "[icon] System  Is on floor").
        var object_icon: Variant = metadata.get("object_icon")
        if object_icon is Texture2D:
            var icon_y: float = span.rect.position.y + (span.rect.size.y - OBJECT_ICON_SIZE) * 0.5
            control.draw_texture_rect(object_icon as Texture2D, Rect2(text_x, icon_y, OBJECT_ICON_SIZE, OBJECT_ICON_SIZE), false)
            text_x += OBJECT_ICON_ADVANCE
            text_width = max(span.rect.size.x - (text_x - span.rect.position.x) - right_padding, 1.0)
        var object_label: String = str(metadata.get("object_label", ""))
        if not object_label.is_empty():
            var object_color: Color = event_style.object_label_color if event_style != null else COLOR_OBJECT
            _draw_text(control, Vector2(text_x, baseline_y), object_label, text_width, font, draw_font_size, object_color)
            var label_advance: float = font.get_string_size(object_label + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
            text_x += label_advance
            text_width = max(span.rect.size.x - (text_x - span.rect.position.x) - right_padding, 1.0)
        var value_ranges: Array = metadata.get("value_ranges", []) if span_index != editing_span_index else []
        if value_ranges.is_empty():
            _draw_text(control, Vector2(text_x, baseline_y), draw_text, text_width, font, draw_font_size, color)
        else:
            var value_color: Color = event_style.value_highlight_color if event_style != null else COLOR_VALUE
            _draw_text_with_values(control, Vector2(text_x, baseline_y), draw_text, value_ranges, text_width, font, draw_font_size, color, value_color)
        # Color params get a small swatch right after the text (C3-style color preview).
        var swatch: Variant = metadata.get("swatch_color")
        if swatch is Color:
            var swatch_advance: float = minf(font.get_string_size(draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x, text_width)
            var swatch_size: float = maxf(draw_font_size * 0.7, 8.0)
            var swatch_rect: Rect2 = Rect2(text_x + swatch_advance + 6.0, span.rect.position.y + (span.rect.size.y - swatch_size) * 0.5, swatch_size, swatch_size)
            control.draw_rect(swatch_rect, swatch as Color, true)
            control.draw_rect(swatch_rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.0)
        # Strike through the text when the ACE is disabled OR its whole row (event/group/
        # comment) is disabled, so "commented out" reads clearly like in code.
        if not ace_enabled or (row_data != null and row_data.disabled):
            var strike_y: float = span.rect.get_center().y
            control.draw_line(
                Vector2(span.rect.position.x, strike_y),
                Vector2(span.rect.end.x, strike_y),
                color,
                1.0,
                true
            )
        if span_index == editing_span_index:
            var prefix: String = draw_text.substr(0, clamp(editing_caret, 0, draw_text.length()))
            var prefix_width: float = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
            var caret_x: float = min(text_x + prefix_width + 1.0, span.rect.end.x - right_padding)
            control.draw_line(
                Vector2(caret_x, span.rect.position.y + 5.0),
                Vector2(caret_x, span.rect.end.y - 5.0),
                TEXT_PRIMARY,
                1.0,
                true
            )

func _draw_chip_span(control: Control, span: SemanticSpan, metadata: Dictionary) -> void:
    # Flat C3/GDevelop-style cell: a subtle rectangular fill, no border or rounded corners.
    var bg: Color = metadata.get("chip_bg", Color(1.0, 1.0, 1.0, 0.035))
    control.draw_rect(span.rect, bg, true)

## Flat, clearly-visible hover for a single condition/action cell: a neutral light tint over
## just that cell (distinct from the accent-coloured selection), so it reads as "this cell".
func _draw_cell_hover(control: Control, rect: Rect2, tint: Color) -> void:
    control.draw_rect(rect, tint, true)

func _draw_chip_selected_span(
    control: Control,
    span: SemanticSpan,
    metadata: Dictionary,
    selection_fill: Color,
    multi_select: bool
) -> void:
    # Flat selected cell: a stronger accent-tinted fill plus a left accent bar (C3 cue).
    var accent: Color = metadata.get("text_color", TEXT_PRIMARY)
    var fill: Color = Color(accent.r, accent.g, accent.b, 0.16 if multi_select else 0.22)
    control.draw_rect(span.rect, fill, true)
    control.draw_rect(Rect2(span.rect.position.x, span.rect.position.y, 2.0, span.rect.size.y), accent, true)

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
    _draw_text(
        control,
        Vector2(rect.position.x + 8.0, baseline_y),
        text,
        rect.size.x - 16.0,
        font,
        max(font_size - 1, 10),
        Color(1.0, 1.0, 1.0, 0.96)
    )
func _draw_badge_span(control: Control, span: SemanticSpan, font: Font, font_size: int, metadata: Dictionary) -> void:
    var badge_rect: Rect2 = span.rect
    var badge_bg: Color = metadata.get("badge_bg", EventSheetPalette.COLOR_LANE_DIVIDER)
    var badge_fg: Color = metadata.get("badge_fg", TEXT_PRIMARY)
    var badge_style: String = str(metadata.get("badge_style", ""))
    var badge_font_size: int = EventSheetPalette.resolve_font_size(
        font_size,
        int(metadata.get("font_size_delta", 0)),
        -BADGE_FONT_SIZE_DELTA
    )
    if badge_style in ["trigger", "negated"]:
        var radius: float = min(badge_rect.size.x, badge_rect.size.y) * 0.45
        control.draw_circle(badge_rect.get_center(), radius, badge_bg)
    else:
        var style: StyleBoxFlat = StyleBoxFlat.new()
        style.bg_color = badge_bg
        style.set_corner_radius_all(int(metadata.get("corner_radius", 4)))
        style.set_content_margin_all(0)
        control.draw_style_box(style, badge_rect)
    var text: String = span.text
    var text_size: Vector2 = font.get_string_size(
        text,
        HORIZONTAL_ALIGNMENT_LEFT,
        -1.0,
        badge_font_size
    )
    var text_baseline_x: float = badge_rect.position.x + max((badge_rect.size.x - text_size.x) * 0.5, BADGE_MIN_HORIZONTAL_PADDING)
    var effective_text_height: float = max(font.get_height(badge_font_size), text_size.y)
    var baseline_y: float = badge_rect.position.y + ((badge_rect.size.y - effective_text_height) * 0.5) + font.get_ascent(badge_font_size)
    _draw_text(
        control,
        Vector2(text_baseline_x, baseline_y),
        text,
        -1.0,
        font,
        badge_font_size,
        badge_fg
    )

func _draw_debug_overlay(control: Control, row_rect: Rect2, font: Font, font_size: int, debug_text: String) -> void:
    var badge_width: float = font.get_string_size(debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size - 1).x + 10.0
    var badge_rect := Rect2(row_rect.end.x - badge_width - 8.0, row_rect.position.y + 5.0, badge_width, row_rect.size.y - 10.0)
    control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 4.0, row_rect.size.y), EventSheetPalette.COLOR_DEBUG, true)
    control.draw_rect(badge_rect, EventSheetPalette.COLOR_DEBUG, true)
    var baseline_y: float = badge_rect.position.y + (badge_rect.size.y * ROW_VERTICAL_CENTER_RATIO) + ((font_size - 1) * FONT_BASELINE_OFFSET_RATIO)
    _draw_text(control, Vector2(badge_rect.position.x + 5.0, baseline_y), debug_text, -1.0, font, font_size - 1, EventSheetPalette.COLOR_DEBUG_TEXT)

func _get_span_color(span_type: int, event_style: EventSheetEventStyle = null) -> Color:
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
            return event_style.comment_text_color if event_style != null else EventSheetPalette.COLOR_COMMENT
        _:
            return TEXT_PRIMARY
