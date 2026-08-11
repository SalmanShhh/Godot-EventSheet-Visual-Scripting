@tool
class_name ViewportRowMetrics
extends RefCounted
# The ROW-METRICS layer: per-row vertical layout (top/height) for the event sheet's virtualized
# viewport. Extracted from event_sheet_viewport.gd to keep that file maintainable. This subsystem
# owns the metrics array and the width it was last computed at; it reads the row model
# (_flat_rows / _root_rows), the zoom, fonts, the event style, and the logical canvas width through
# a back-reference to the viewport. Row layout must stay byte-identical to the pre-extraction code,
# so the bodies below were moved VERBATIM - only member access was rewritten to go through
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
	var previous_attached: bool = false
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._row_at(index)
		# Separate sibling/parent-level event blocks with a small gap, but keep a parent and
		# its sub-events (a deeper indent) tight together so the nesting reads clearly.
		# A row flagged attached_below OWNS the row beneath it (a published verb's description caption
		# and its verb row), so the gap opens ABOVE the caption and is suppressed between the two.
		if (
			index > 0
			and row_data != null
			and row_data.indent <= previous_indent
			and not previous_attached
			and (
				row_data.row_type == EventRowData.RowType.EVENT
				or row_data.row_type == EventRowData.RowType.GROUP
				or row_data.attached_below
			)
		):
			top += _viewport.EVENT_BLOCK_GAP * EventSheetPalette.row_density()
		var height: float = _resolve_row_height(row_data)
		_row_metrics.append({"top": top, "height": height})
		top += height
		if row_data != null:
			previous_indent = row_data.indent
			previous_attached = row_data.attached_below
		else:
			previous_attached = false


func _resolve_row_height(row_data: EventRowData) -> float:
	# Header-like rows reserve height_scale times their natural height (state headers, the
	# Class setup bar, Host binding - the C3 Includes-bar presence); layout re-centers content.
	return _resolve_row_height_natural(row_data) * clampf(row_data.height_scale if row_data != null else 1.0, 1.0, 3.0)


func _resolve_row_height_natural(row_data: EventRowData) -> float:
	if row_data == null:
		return float(_viewport.ROW_HEIGHT)
	if row_data.row_type == EventRowData.RowType.COMMENT:
		# Comments wrap to the row width; the row is as tall as the wrapped text needs.
		return _measure_comment_height(row_data)
	if row_data.row_type == EventRowData.RowType.GROUP:
		# Group headers are the sheet's chapter bars: a themable height, double an event row by
		# default, never below the base row height (a squashed bar would clip its title).
		var event_style: EventSheetEventStyle = _viewport._get_event_style()
		var group_height: int = event_style.group_row_height if event_style != null else EventSheetPalette.GROUP_ROW_HEIGHT
		# A group with a DESCRIPTION is a two-line header (the builder sets line_count = 2), so it must
		# also clear the font's own two lines. The themed 56 is under 2 x the line height even at the
		# default font, and badly under it once the editor font grows - so the description was drawn
		# into the row below and painted over, the same bleed single-line rows had on a Retina Mac.
		var text_height: float = float(maxi(row_data.line_count, 1)) \
			* _viewport._get_event_line_height(_viewport._get_font_size())
		return max(max(float(group_height), text_height), float(_viewport.ROW_HEIGHT))
	if row_data.row_type != EventRowData.RowType.EVENT:
		# Multi-line non-event rows (GDScript blocks) expand by their precomputed line count.
		if row_data.line_count > 1:
			return float(row_data.line_count) * _viewport._get_event_line_height(_viewport._get_font_size())
		# A SINGLE-line non-event row (a variable, a signal, a section) must still reserve the FONT's
		# line height, floored by the base row height - not the bare constant. The layout gives these
		# rows a font-derived rect (viewport_layout_builder line_height - 6.0), so reserving a fixed 28
		# under-measures them the moment the editor font grows past ~17px, which is what a Retina Mac at
		# 200% editor scale does: every such row bled ~10px into the row below and the neighbouring
		# opaque band painted over it. At the default font this is still exactly 28, so 100%-scale
		# editors are unchanged.
		return maxf(float(_viewport.ROW_HEIGHT), _viewport._get_event_line_height(_viewport._get_font_size()))
	var line_height: float = _viewport._get_event_line_height(_viewport._get_font_size())
	# When spans are still lazy (not yet built), use the precomputed line count so
	# metrics never trigger span building. Once built, the spans are authoritative.
	if row_data.spans.is_empty():
		return float(maxi(row_data.line_count, 1)) * line_height
	# Wrapped cells grow the row: the shared extents walk (also used by the layout pass)
	# counts each lane's visual lines, and the row covers the taller lane.
	var extents: Dictionary = event_line_extents(row_data, _viewport._get_logical_canvas_width(), _viewport._get_font(), _viewport._get_font_size())
	return float(maxi(int(extents.get("total", 1)), 1)) * line_height


## Per-lane visual-line layout for an EVENT row once cell text WRAPS to its lane - the
## Construct rule: the cell grows taller, the text never clips. Returns, per logical line,
## the visual line each lane's cells start at (cond_top / act_top), how many visual lines each
## fill cell needs (cond_count / act_count), and the row's visual-line total. ONE function
## shared by the height metrics and the layout pass, so the reserved height and the drawn
## positions can never disagree (the comment path mirrors by hand; events share instead).
## Plain cells wrap on TextServer word breaks; styled (bbcode-segment) cells wrap on the
## shared greedy break points (wrap_break_points), which the layout stamps for the renderer.
func event_line_extents(row_data: EventRowData, width: float, font: Font, font_size: int) -> Dictionary:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var x: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + EventSheetPalette.GUTTER_WIDTH + float(row_data.indent * _viewport.INDENT_WIDTH) + 18.0
	var lane_divider_x: float = _viewport.get_lane_divider_x(width)
	var condition_lane_rect := Rect2(x, 0.0, maxf(lane_divider_x - x, 1.0), 1.0)
	var action_lane_rect := Rect2(lane_divider_x + float(event_style.lane_divider_width), 0.0, maxf(width - lane_divider_x - float(event_style.lane_divider_width), 1.0), 1.0)
	var condition_x: float = _viewport._get_condition_track_start(row_data, x, condition_lane_rect)
	var badge_column: float = maxf(float(event_style.condition_badge_column_width), 0.0)
	var badge_gap: float = EventSheetPalette.SPAN_GAP if badge_column > 0.0 else 0.0
	var condition_text_start_x: float = condition_x + badge_column + badge_gap
	var max_condition_right: float = lane_divider_x - float(event_style.condition_lane_padding)
	var action_x: float = lane_divider_x + float(event_style.lane_divider_width) + float(event_style.action_lane_padding)
	var reservations: Dictionary = _viewport._build_action_line_reservations(row_data, action_lane_rect, font, font_size)
	var cond_badge_x: Dictionary = {}
	var cond_text_x: Dictionary = {}
	var act_x: Dictionary = {}
	var cond_count: Dictionary = {}
	var act_count: Dictionary = {}
	var max_line: int = 0
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		var line: int = int(metadata.get("line_index", 0))
		max_line = maxi(max_line, line)
		var lane: String = _viewport._resolve_span_lane(span)
		var measured: float = _viewport._measure_span_width(span, span.text, font, font_size)
		if lane == "action":
			if bool(metadata.get("align_right", false)):
				continue
			var start_x: float = float(act_x.get(line, action_x))
			if str(metadata.get("kind", "")) == "action" and not bool(metadata.get("natural_width", false)):
				var reserved: float = float(reservations.get(line, action_lane_rect.end.x - float(event_style.action_lane_padding)))
				var available: float = maxf(reserved - maxf(_viewport._get_span_gap(span), EventSheetPalette.SPAN_GAP) - start_x, 1.0)
				act_count[line] = maxi(int(act_count.get(line, 1)), _fill_cell_line_count(span, metadata, available + 2.0, font, font_size, object_column_override(metadata, action_x, start_x)))
				act_x[line] = start_x + available + 2.0 + _viewport._get_span_gap(span)
			else:
				act_x[line] = start_x + measured + 2.0 + _viewport._get_span_gap(span)
		else:
			if bool(metadata.get("badge", false)):
				var natural_badge: bool = bool(metadata.get("badge_natural_width", false))
				var badge_width: float = measured if natural_badge or badge_column <= 0.0 else badge_column
				var badge_start: float = float(cond_badge_x.get(line, condition_x))
				cond_badge_x[line] = badge_start + maxf(minf(badge_width, max_condition_right - badge_start), _viewport.MIN_SPAN_WIDTH) + 2.0 + _viewport._get_span_gap(span)
			else:
				var text_start: float = float(cond_text_x.get(line, float(cond_badge_x.get(line, condition_text_start_x))))
				if str(metadata.get("kind", "")) in ["condition", "trigger"]:
					var available_c: float = maxf(max_condition_right - text_start, _viewport.MIN_SPAN_WIDTH)
					cond_count[line] = maxi(int(cond_count.get(line, 1)), _fill_cell_line_count(span, metadata, available_c + 2.0, font, font_size, object_column_override(metadata, condition_text_start_x, text_start)))
					cond_text_x[line] = text_start + available_c + 2.0 + _viewport._get_span_gap(span)
				else:
					var chip_width: float = maxf(minf(measured, max_condition_right - text_start), _viewport.MIN_SPAN_WIDTH)
					cond_text_x[line] = text_start + chip_width + 2.0 + _viewport._get_span_gap(span)
	var cond_top: Dictionary = {}
	var act_top: Dictionary = {}
	var cond_cursor: int = 0
	var act_cursor: int = 0
	for line_cursor: int in range(max_line + 1):
		cond_top[line_cursor] = cond_cursor
		act_top[line_cursor] = act_cursor
		cond_cursor += maxi(int(cond_count.get(line_cursor, 1)), 1)
		act_cursor += maxi(int(act_count.get(line_cursor, 1)), 1)
	return {"cond_top": cond_top, "act_top": act_top, "cond_count": cond_count, "act_count": act_count, "total": maxi(maxi(cond_cursor, act_cursor), 1)}


## Visual lines one condition/action FILL cell needs at its cell rect width. Plain text wraps
## on TextServer breaks (wrapped_line_count); styled cells wrap on the shared greedy break
## points, so this count always equals the number of lines the renderer will actually draw.
func _fill_cell_line_count(span: SemanticSpan, metadata: Dictionary, cell_rect_width: float, font: Font, font_size: int, column_override: float = -1.0) -> int:
	var wrap_width: float = _fill_text_wrap_width(metadata, cell_rect_width, font, font_size, column_override)
	if (metadata.get("bbcode_segments", []) as Array).is_empty():
		return wrapped_line_count(span.text, wrap_width, font, font_size)
	return wrap_break_points(span.text, wrap_width, font, font_size).size()


## The width the renderer actually wraps a fill cell's TEXT inside: the cell rect minus the
## chip padding and the leading object icon/label column the renderer advances past before
## drawing text. Must mirror the renderer's text_x/right_padding math or the counted lines
## and the drawn lines drift apart. `column_override` is the per-span aligned column width
## (see object_column_override); -1.0 falls back to the style's base column.
func _fill_text_wrap_width(metadata: Dictionary, cell_rect_width: float, font: Font, font_size: int, column_override: float = -1.0) -> float:
	var is_chip: bool = bool(metadata.get("chip", false))
	var pad: float = float(metadata.get("padding_x", 0.0)) if is_chip else 0.0
	var trail: float = pad if is_chip else 2.0
	var lead: float = pad
	if metadata.get("object_icon") is Texture2D:
		lead += EventRowRenderer.OBJECT_ICON_ADVANCE
	var object_label: String = str(metadata.get("object_label", ""))
	if not object_label.is_empty():
		var lane: String = str(metadata.get("lane", ""))
		var column: float = EventRowRenderer.object_column_width_for(_viewport._get_event_style(), lane, _viewport.lane_width_for(lane))
		if column_override >= 0.0:
			lead += column_override
		elif column > 0.0:
			lead += column
		else:
			var draw_font_size: int = EventSheetPalette.resolve_font_size(font_size, int(metadata.get("font_size_delta", 0)))
			lead += font.get_string_size(object_label + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
	return maxf(cell_rect_width - lead - trail, 1.0)


## The C3 sub-lane rule: within a lane, every cell's object-column SEPARATOR sits at the same
## absolute x, regardless of where that cell starts (a badge on the trigger line shifts its
## cell right; without this, its separator drifted a few px from the lines below - the
## "awkward and misaligned" middle). The shared boundary always reserves the object ICON slot
## (icon + label are ONE column, like Construct), so an icon-bearing cell keeps its full
## label room and an iconless one simply gets a slightly wider label area at the same edge.
## Returns the column width THIS span must use so its boundary lands there, or -1.0 when the
## span has no label or the lane is in flow mode. Floored at 24px so a cell starting
## unusually far right never collapses its label to nothing.
func object_column_override(metadata: Dictionary, lane_origin_x: float, span_x: float) -> float:
	if str(metadata.get("object_label", "")).is_empty():
		return -1.0
	var lane: String = str(metadata.get("lane", ""))
	var column: float = EventRowRenderer.object_column_width_for(_viewport._get_event_style(), lane, _viewport.lane_width_for(lane))
	if column <= 0.0:
		return -1.0
	var lead: float = float(metadata.get("padding_x", 0.0)) if bool(metadata.get("chip", false)) else 0.0
	if metadata.get("object_icon") is Texture2D:
		lead += EventRowRenderer.OBJECT_ICON_ADVANCE
	return maxf(lane_origin_x + EventRowRenderer.OBJECT_ICON_ADVANCE + column - (span_x + lead), 24.0)


## Greedy word-wrap break points for STYLED (bbcode-segment) cells: character offsets where
## each visual line starts (first is always 0). The renderer slices the segment run at these
## exact offsets, so the counted lines and the drawn lines are the same by construction. A
## single word wider than the line hard-breaks mid-word rather than overflowing.
static func wrap_break_points(text: String, wrap_width: float, font: Font, font_size: int) -> PackedInt32Array:
	var starts := PackedInt32Array([0])
	if font == null or wrap_width <= 1.0 or text.strip_edges().is_empty():
		return starts
	var line_start: int = 0
	var last_break: int = -1
	var cursor: int = 0
	while cursor < text.length():
		var piece: String = text.substr(line_start, cursor - line_start + 1)
		if font.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > wrap_width and cursor > line_start:
			line_start = last_break if last_break > line_start else cursor
			starts.append(line_start)
			cursor = line_start
			last_break = -1
			continue
		if text[cursor] == " ":
			last_break = cursor + 1
		cursor += 1
	return starts


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
	# Construct-style banner: comment text starts at the row's left edge (no badge-column indent),
	# kept in sync with the comment branch of the layout pass (which now adds no indent either).
	return (
		EventSheetPalette.ROW_HORIZONTAL_PADDING
		+ EventSheetPalette.GUTTER_WIDTH
		+ float(indent * _viewport.INDENT_WIDTH)
		+ 18.0
	)


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
## - the dead zone that let Delete fall through to the editor's scene tree. Static + pure = testable.
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
