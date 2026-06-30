@tool
class_name ViewportRowMetrics
extends RefCounted
# The ROW-METRICS layer: per-row vertical layout (top/height) for the event sheet's virtualized
# viewport. Extracted from event_sheet_viewport.gd to keep that file maintainable. This subsystem
# owns the metrics array and the width it was last computed at; it reads the row model
# (_flat_rows / _root_rows), the zoom, fonts, the event style, and the logical canvas width through
# a back-reference to the viewport. Row layout must stay byte-identical to the pre-extraction code,
# so the bodies below were moved VERBATIM — only member access was rewritten to go through
# `_viewport.` (the metric arithmetic itself is unchanged).
#
# Two methods are STATIC + pure (wrapped_line_count, _row_index_at_y) so they remain unit-testable
# without a live viewport. The viewport keeps thin delegates + static forwarders so existing
# internal callers and tests (which call e.g. EventSheetViewport.wrapped_line_count(...) by class
# name, or viewport._get_row_top(i)) are unchanged.

var _viewport: Control = null

## Owns the per-row layout (top/height in logical px). Rebuilt whenever the row model or the
## canvas width changes.
var _row_metrics: Array[Dictionary] = []
## Logical canvas width the row metrics were last computed at. Comment rows wrap to this
## width, so when it changes on resize the metrics must be rebuilt (heights change).
var _metrics_canvas_width: float = -1.0

func init(viewport: Control) -> void:
    _viewport = viewport

func rebuild() -> void:
    _metrics_canvas_width = _viewport._get_logical_canvas_width()
    _row_metrics.clear()
    var top: float = 0.0
    var previous_indent: int = -1
    for index in range(_viewport._flat_rows.size()):
        var row_data: EventRowData = _viewport._row_at(index)
        # Separate sibling/parent-level event blocks with a small gap, but keep a parent and
        # its sub-events (a deeper indent) tight together so the nesting reads clearly.
        if (
            index > 0
            and row_data != null
            and row_data.indent <= previous_indent
            and (row_data.row_type == EventRowData.RowType.EVENT or row_data.row_type == EventRowData.RowType.GROUP)
        ):
            top += _viewport.EVENT_BLOCK_GAP
        var height: float = _resolve_row_height(row_data)
        _row_metrics.append({"top": top, "height": height})
        top += height
        if row_data != null:
            previous_indent = row_data.indent

func _resolve_row_height(row_data: EventRowData) -> float:
    if row_data == null:
        return float(_viewport.ROW_HEIGHT)
    if row_data.row_type == EventRowData.RowType.COMMENT:
        # Comments wrap to the row width; the row is as tall as the wrapped text needs.
        return _measure_comment_height(row_data)
    if row_data.row_type != EventRowData.RowType.EVENT:
        # Multi-line non-event rows (GDScript blocks) expand by their precomputed line count.
        if row_data.line_count > 1:
            return float(row_data.line_count) * _viewport._get_event_line_height(_viewport._get_font_size())
        return float(_viewport.ROW_HEIGHT)
    var line_height: float = _viewport._get_event_line_height(_viewport._get_font_size())
    # When spans are still lazy (not yet built), use the precomputed line count so
    # metrics never trigger span building. Once built, the spans are authoritative.
    if row_data.spans.is_empty():
        return float(maxi(row_data.line_count, 1)) * line_height
    var max_line_index: int = 0
    for span in row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        max_line_index = maxi(max_line_index, int(metadata.get("line_index", 0)))
    return float((max_line_index + 1) * line_height)

## Total height of a comment row once each of its logical lines is wrapped to the row width.
## Mirrors the per-span wrapping done in the layout pass, so the reserved height always
## matches what is actually drawn (otherwise wrapped text would overlap the next row).
func _measure_comment_height(row_data: EventRowData) -> float:
    var line_height: float = _viewport._get_event_line_height(_viewport._get_font_size())
    if row_data.spans.is_empty():
        return float(maxi(row_data.line_count, 1)) * line_height
    var wrap_width: float = _comment_wrap_width(row_data.indent, _viewport._get_logical_canvas_width())
    var font: Font = _viewport._get_font()
    var font_size: int = _viewport._get_font_size()
    var total_lines: int = 0
    for span in row_data.spans:
        total_lines += _comment_span_line_count(span, wrap_width, font, font_size)
    return float(maxi(total_lines, 1)) * line_height

## Where comment text begins on the row (logical/unzoomed px). Kept in sync with the comment
## branch of the layout pass so wrapping width, hit-testing, and drawing all agree.
func _comment_text_origin_x(indent: int) -> float:
    var origin_x: float = (
        EventSheetPalette.ROW_HORIZONTAL_PADDING
        + EventSheetPalette.GUTTER_WIDTH
        + float(indent * _viewport.INDENT_WIDTH)
        + 18.0
    )
    var badge_column: float = max(float(_viewport._get_event_style().condition_badge_column_width), 0.0)
    if badge_column > 0.0:
        origin_x += badge_column + EventSheetPalette.SPAN_GAP
    return origin_x

## The pixel width comment text wraps inside: from the comment text origin to the row's right
## padding (the same right limit the layout clamps spans to). Floored at MIN_COMMENT_WRAP_WIDTH.
func _comment_wrap_width(indent: int, width: float) -> float:
    var right_limit: float = width - EventSheetPalette.ROW_HORIZONTAL_PADDING
    return max(right_limit - _comment_text_origin_x(indent) - 2.0, _viewport.MIN_COMMENT_WRAP_WIDTH)

## How many visual lines one comment span occupies after wrapping. BBCode-styled lines are
## drawn as a single styled run (segment wrapping is not supported), so they stay one line.
func _comment_span_line_count(span: SemanticSpan, wrap_width: float, font: Font, font_size: int) -> int:
    if span == null:
        return 1
    var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
    if not (metadata.get("bbcode_segments", []) as Array).is_empty():
        return 1
    return wrapped_line_count(span.text, wrap_width, font, font_size)

## Word-wrapped visual line count for `text` inside `wrap_width` (logical px). Uses the same
## TextServer word/grapheme breaking the renderer draws with, so measurement and drawing stay
## in lock-step. Pure + static so it is unit-testable without a live viewport. >= 1 always.
static func wrapped_line_count(text: String, wrap_width: float, font: Font, font_size: int) -> int:
    if font == null or text.strip_edges().is_empty() or wrap_width <= 1.0:
        return 1
    var single_line: float = font.get_height(font_size)
    if single_line <= 0.0:
        return 1
    var wrapped_height: float = font.get_multiline_string_size(
        text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, font_size, -1,
        TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND
    ).y
    return maxi(1, int(round(wrapped_height / single_line)))

func row_top(index: int) -> float:
    if index < 0 or index >= _row_metrics.size():
        return float(index * _viewport.ROW_HEIGHT)
    return float(_row_metrics[index].get("top", float(index * _viewport.ROW_HEIGHT)))

func row_height(index: int) -> float:
    if index < 0 or index >= _row_metrics.size():
        return float(_viewport.ROW_HEIGHT)
    return float(_row_metrics[index].get("height", _viewport.ROW_HEIGHT))

func row_index_at_y(y: float) -> int:
    return _row_index_at_y(_row_metrics, y)

## Resolves a vertical position to a row index. A click in the small inter-block GAP before a row
## (dead space not covered by any row band, EVENT_BLOCK_GAP) resolves to the PRECEDING event, so
## clicking just outside / below an event block still selects it instead of clearing the selection
## — the dead zone that let Delete fall through to the editor's scene tree. Static + pure = testable.
static func _row_index_at_y(metrics: Array, y: float) -> int:
    if metrics.is_empty() or y < 0.0:
        return -1
    for index in range(metrics.size()):
        var top: float = float(metrics[index].get("top", 0.0))
        var height: float = float(metrics[index].get("height", EventSheetPalette.ROW_HEIGHT))
        if y < top:
            return index - 1
        if y < top + height:
            return index
    return -1

## Total height of all rows (top + height of the last metric), or 0 when there are no rows.
## Absorbs the inline `_row_metrics[last]` read `_update_canvas_min_size` used to do.
func total_height() -> float:
    if _row_metrics.is_empty():
        return 0.0
    var last_metric: Dictionary = _row_metrics[_row_metrics.size() - 1]
    return float(last_metric.get("top", 0.0)) + float(last_metric.get("height", _viewport.ROW_HEIGHT))

func is_empty() -> bool:
    return _row_metrics.is_empty()

## The logical canvas width the metrics were last rebuilt at (the resize guard compares against this).
func metrics_width() -> float:
    return _metrics_canvas_width
