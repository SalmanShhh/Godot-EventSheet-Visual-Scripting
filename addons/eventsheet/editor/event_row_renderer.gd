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
# K4. The "or" divider between two OR'd conditions: the rule sits this far above the line it divides
# from the one before (the same 3px pad the layout gives a line's spans, so the rule lands in the
# middle of the gap), inset from the lane's edges, with this much air between the word and its rule.
const OR_DIVIDER_GAP := 3.0
const OR_DIVIDER_INSET := 4.0
const OR_DIVIDER_WORD_GAP := 6.0
# Object icon drawn before the object label in ACE cells (event-sheet grammar). Event-sheet
# framing: the icon sits centred on a subtle rounded plate (the "{my}" icon chip), so icons
# read as a tidy column instead of loose glyphs. The advance must stay in sync with
# _measure_span_width in the viewport or hit-testing drifts.
const OBJECT_ICON_SIZE := 14.0
const OBJECT_ICON_PLATE_SIZE := 18.0
const OBJECT_ICON_ADVANCE := 23.0
const OBJECT_ICON_PLATE_FILL := Color(1.0, 1.0, 1.0, 0.05)
const OBJECT_ICON_PLATE_BORDER := Color(1.0, 1.0, 1.0, 0.13)
# A colour value's live swatch, drawn just past its span's text. The gap and the box are constants
# here, and the width the span must RESERVE for them is derived from the same two numbers, so a
# swatch can sit on any span in a row without painting over whatever follows it.
const SWATCH_GAP := 6.0
const SWATCH_MIN_BOX := 8.0
const SWATCH_FONT_RATIO := 0.7
# The rule down the left edge of a variable row, in logical pixels.
const VARIABLE_ROW_RULE_WIDTH := 2.0
## How much of the variable rule's colour a block-closing hairline keeps - a whisper of the same
## lilac, so the break reads without competing with the rows it separates.
const BLOCK_HAIRLINE_ALPHA := 0.45

# R1 - how a region fence paints in its own colour: the faintest wash behind the opening head, a
# firm rule at the left edge of both fences, and the dash rhythm the badge and the body rule share.
# Alphas, not colours: the hue is always the region's own, so no theme token is involved.
const REGION_ROW_WASH_ALPHA := 0.06
const REGION_RULE_ALPHA := 0.75
const REGION_DASH_LENGTH := 3.0

# One shared plate StyleBox (this draws once per icon per frame on a virtualized canvas -
# never allocate it inside the draw loop).
static var _icon_plate_style: StyleBoxFlat = null

# Stamped by the viewport ONCE per _draw frame (it is constant across the frame): the
# per-row alternative - a dynamic control.get() in the draw loop - is exactly the lookup
# the rule above forbids.
var show_event_numbers: bool = true
## Stamped the same way: the Event Trace hit-count lens (View > Row Hit Counts, ships OFF).
## While false NOTHING below is drawn and the gutter paints exactly as it always has.
var show_hit_counts: bool = false

# ── The hit-count chip (LEFT MARGIN ONLY - never a cell, never program text) ──
# Height/inset of the small count chip that stacks under the event number in the 20px gutter.
const HIT_CHIP_HEIGHT := 11.0
const HIT_CHIP_INSET := 1.5
# The count chip's tones. Blue is the resting readout; warm marks the run's busiest rows; the
# muted pair plus a dim left rail marks a row that has not fired once since Run.
const HIT_CHIP_FILL := Color(0.31, 0.56, 0.87, 0.15)
const HIT_CHIP_BORDER := Color(0.31, 0.56, 0.87, 0.30)
const HIT_CHIP_TEXT := Color("#7fb0e8")
const HIT_CHIP_HOT_FILL := Color(0.93, 0.58, 0.26, 0.20)
const HIT_CHIP_HOT_BORDER := Color(0.93, 0.58, 0.26, 0.38)
const HIT_CHIP_HOT_TEXT := Color("#f0b174")
const HIT_CHIP_COLD_FILL := Color(1.0, 1.0, 1.0, 0.04)
const HIT_CHIP_COLD_BORDER := Color(1.0, 1.0, 1.0, 0.09)
const HIT_CHIP_COLD_TEXT := Color("#6f7580")
const HIT_CHIP_COLD_RAIL := Color(1.0, 1.0, 1.0, 0.13)

## The reading tokens a style-less draw falls back to (a headless measure, a preview with no style).
## Built once and kept, because draw_row runs per row per frame and a fresh Resource each time would
## allocate through the whole sheet.
static var _fallback_reading: EventSheetReadingStyle = null


static func _fallback_reading_style() -> EventSheetReadingStyle:
	if _fallback_reading == null:
		_fallback_reading = EventSheetReadingStyle.new()
	return _fallback_reading


## The same idea for the row shell tokens, so a style-less draw never has to spell a colour out.
static var _fallback_event: EventSheetEventStyle = null


static func _fallback_event_style() -> EventSheetEventStyle:
	if _fallback_event == null:
		_fallback_event = EventSheetEventStyle.new()
	return _fallback_event


## The fixed object-name column width for a span's lane (0 = flow, the classic behavior).
## One resolver shared by the draw, the width measure, and the text-origin hit-test so the
## three can never disagree about where display text starts.
## `text` shortened with a trailing ellipsis until it fits `max_width`. Godot's draw_string takes a
## width but CLIPS at it - a name in a user-draggable column would be sliced through a glyph, which is
## eliding avoids. Returns the text untouched when it already fits (the common case),
## so the measuring loop only ever runs on a name that is actually too long for its column.
static func _elide(text: String, max_width: float, font: Font, font_size: int) -> String:
	if max_width <= 0.0 or font == null:
		return text
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
		return text
	var trimmed: String = text
	while trimmed.length() > 1:
		trimmed = trimmed.substr(0, trimmed.length() - 1)
		if font.get_string_size(trimmed + "…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= max_width:
			return trimmed + "…"
	return "…"


## The hairline that marks an object column's right edge inside a cell - the event-sheet permanent
## sub-lane split. It sits ON the boundary the resize grab tests against, so what you see is exactly
## what you can drag. Skipped for a cell too short to show it.
##
## It deliberately does NOT reuse lane_divider_color: that token is a dark grey-blue tuned to separate
## the lanes over the SHEET BACKGROUND, and measured against a filled condition cell it lands within
## about six values of the fill - drawn there it is invisible. The column's own label colour, faint,
## reads on both the blue condition fill and the green action fill and still follows the theme.
static func _draw_object_column_separator(control: CanvasItem, span: SemanticSpan, boundary_x: float, event_style: EventSheetEventStyle) -> void:
	if event_style == null or span == null or span.rect.size.y <= 4.0:
		return
	var separator: Color = event_style.object_label_color
	control.draw_rect(
		Rect2(boundary_x - 3.0, span.rect.position.y + 1.0, 1.0, span.rect.size.y - 2.0),
		Color(separator.r, separator.g, separator.b, 0.30),
		true
	)


## The object column actually in force for a lane. THE one resolver - draw, measure, hit-test and the
## drag boundary all come through here, so they can never disagree about where the column ends.
##
## `lane_width` bounds it. A column is a themed/dragged number in logical pixels with no idea how much
## lane it is being asked to occupy: the shipped 130px default against the 160px minimum conditions
## lane pushed the display text 48px PAST the lane divider on a narrow sheet (measured at a 420px
## canvas), so the text vanished on any docked panel or split view. The column may now take at most
## 45% of its lane, leaving the majority for the text it is supposed to be labelling. Pass 0 (the
## default) only where the lane is genuinely unknown - the bound is then skipped, as before.
static func object_column_width_for(event_style: EventSheetEventStyle, lane: String, lane_width: float = 0.0) -> float:
	if event_style == null:
		return 0.0
	var column: float = 0.0
	match lane:
		"condition":
			column = float(event_style.condition_object_column_width)
		"action":
			column = float(event_style.action_object_column_width)
	if column <= 0.0:
		return 0.0  # flow mode: text follows each label
	return minf(column, lane_width * 0.45) if lane_width > 0.0 else column


## The side of the colour box drawn for a span carrying `swatch_color`, at the size that span's
## text draws at - so the swatch grows with the row and with the editor's scale.
static func swatch_box_for(draw_font_size: int) -> float:
	return maxf(float(draw_font_size) * SWATCH_FONT_RATIO, SWATCH_MIN_BOX)


## What a span carrying `swatch_color` must add to its measured text width: the gap before the box
## plus the box itself. The measurement side calls this so the reserve and the drawing can never
## disagree, which is what lets a swatch ride ANY span (a value, a muted hex note, a parameter)
## instead of only the last one in the row.
static func swatch_advance_for(draw_font_size: int) -> float:
	return SWATCH_GAP + swatch_box_for(draw_font_size)


static func _object_icon_plate_style() -> StyleBoxFlat:
	if _icon_plate_style == null:
		_icon_plate_style = StyleBoxFlat.new()
		_icon_plate_style.bg_color = OBJECT_ICON_PLATE_FILL
		_icon_plate_style.border_color = OBJECT_ICON_PLATE_BORDER
		_icon_plate_style.set_border_width_all(1)
		_icon_plate_style.set_corner_radius_all(3)
	return _icon_plate_style
const BADGE_FONT_SIZE_DELTA := 1
const BADGE_MIN_HORIZONTAL_PADDING := 1.0
const SELECTION_OUTLINE_LIGHTEN := 0.28
const SELECTION_OUTLINE_ALPHA := 0.92
const SPAN_SELECT_OUTLINE_LIGHTEN := 0.3
const SPAN_SELECT_OUTLINE_ALPHA := 0.95
const SPAN_HOVER_OUTLINE_LIGHTEN := 0.28
const SPAN_HOVER_OUTLINE_ALPHA := 0.82


## Event-sheet-style insert marker: arrowheads at both ends of a thin drop line so the insert point
## reads instantly (mirrors the tree-insert-mark).
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


## Draws ACE text with its parameter values highlighted (event-sheet-style): plain segments use the
## base colour, value segments (numbers / quoted strings / booleans, precomputed at span
## build) use the value colour. Segments advance by measured logical width and stop at the
## clip width.
## Bold overlay for the substituted parameter runs: each [start, length] re-draws its text
## 0.7px right of the base pass (the BBCode cells' bold trick - layout metrics untouched).
## A run is split at value-range boundaries so every piece re-draws in the colour the base
## pass gave it: tinted values stay tinted, plain expressions stay the base colour.
func _draw_param_emphasis(
	control: Control,
	baseline: Vector2,
	text: String,
	param_ranges: Array,
	value_ranges: Array,
	max_width: float,
	font: Font,
	font_size: int,
	base_color: Color,
	value_color: Color,
	string_color: Color,
	bool_color: Color
) -> void:
	var limit: float = baseline.x + max_width
	for entry: Variant in param_ranges:
		if not (entry is Array) or (entry as Array).size() < 2:
			continue
		var start: int = int((entry as Array)[0])
		var length: int = int((entry as Array)[1])
		if start < 0 or length <= 0 or start >= text.length():
			continue
		length = mini(length, text.length() - start)
		var cursor: int = start
		var end: int = start + length
		while cursor < end:
			var run_end: int = end
			var run_color: Color = base_color
			for value_range: Variant in value_ranges:
				if not (value_range is Array) or (value_range as Array).size() < 2:
					continue
				var value_start: int = int((value_range as Array)[0])
				var value_end: int = value_start + int((value_range as Array)[1])
				if cursor >= value_start and cursor < value_end:
					run_end = mini(end, value_end)
					var kind: String = str((value_range as Array)[2]) if (value_range as Array).size() >= 3 else ""
					if kind == "string":
						run_color = string_color
					elif kind == "bool":
						run_color = bool_color
					else:
						run_color = value_color
					break
				elif value_start > cursor:
					run_end = mini(run_end, value_start)
			var run_text: String = text.substr(cursor, run_end - cursor)
			var x: float = baseline.x + font.get_string_size(text.substr(0, cursor), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			if x < limit and not run_text.is_empty():
				_draw_text(control, Vector2(x + 0.7, baseline.y), run_text, limit - x, font, font_size, run_color)
			cursor = maxi(run_end, cursor + 1)


func _draw_text_with_values(
	control: Control,
	baseline: Vector2,
	text: String,
	value_ranges: Array,
	max_width: float,
	font: Font,
	font_size: int,
	base_color: Color,
	value_color: Color = COLOR_VALUE,
	string_color: Color = COLOR_VALUE,
	bool_color: Color = COLOR_VALUE
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
		# Typed value tint: the trailing kind picks the hue; numbers keep value_color.
		var value_col: Color = value_color
		if (range_entry as Array).size() >= 3:
			match str(range_entry[2]):
				"string":
					value_col = string_color
				"bool":
					value_col = bool_color
		var value_text: String = text.substr(start, length)
		if not value_text.is_empty() and x < limit:
			_draw_text(control, Vector2(x, baseline.y), value_text, limit - x, font, font_size, value_col)
			x += font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		cursor = start + length
		if x >= limit:
			return
	var tail: String = text.substr(cursor)
	if not tail.is_empty() and x < limit:
		_draw_text(control, Vector2(x, baseline.y), tail, limit - x, font, font_size, base_color)


# ── The collapsed row's one-line summary ──────────────────────────────────────────────────────
# A sheet is browsed by collapsing, so a collapsed block that shows nothing about what it holds
# has hidden the very thing you collapsed it to find. Each collapsed row therefore trails a
# muted phrase naming its first rows. It is DRAW-ONLY: it reserves no width, is never measured
# and is never hit-tested, so it cannot move a single glyph of the row it follows.

## The gap between the row's own text and its summary, and the margin kept clear at the right
## edge. 1x-authored metrics - scaled for the running editor like all other chrome.
const SUMMARY_GAP := 10.0
const SUMMARY_RIGHT_INSET := 8.0
const SUMMARY_ALPHA := 0.75


func _draw_collapsed_summary(control: Control, row_rect: Rect2, row_data: EventRowData, font: Font, font_size: int) -> void:
	if not row_data.folded or row_data.children.is_empty() or font == null:
		return
	if not control.has_method("collapsed_row_summary"):
		return
	var summary: String = str(control.collapsed_row_summary(row_data))
	if summary.is_empty() or row_data.spans.is_empty():
		return
	# The summary follows the row's FIRST line: a header that stacks (a verb row with input
	# chips) keeps its summary beside the line that names it, not floating past the last one.
	# The line is found by the spans' own line_index, not by matching their y: a BADGE is inset
	# vertically inside its column, so a row that LEADS with one (a trigger, a function's
	# `ƒ Functions ▸ On <name>`) matched nothing but the badge and drew the summary straight over
	# the object name that followed it.
	var first_line_top: float = row_data.spans[0].rect.position.y
	var first_line_height: float = row_data.spans[0].rect.size.y
	var text_end: float = row_data.spans[0].rect.end.x
	for span: SemanticSpan in row_data.spans:
		if span == null:
			continue
		var line_index: int = int((span.metadata as Dictionary).get("line_index", 0)) if span.metadata is Dictionary else 0
		if line_index != 0:
			continue
		first_line_top = minf(first_line_top, span.rect.position.y)
		first_line_height = maxf(first_line_height, span.rect.size.y)
		text_end = maxf(text_end, span.rect.end.x)
	var start_x: float = text_end + EventSheetPalette.scaled_f(SUMMARY_GAP)
	var max_width: float = row_rect.end.x - EventSheetPalette.scaled_f(SUMMARY_RIGHT_INSET) - start_x
	if max_width <= EventSheetPalette.scaled_f(SUMMARY_GAP):
		return
	var baseline := Vector2(
		start_x,
		first_line_top + (first_line_height * ROW_VERTICAL_CENTER_RATIO) + (font_size * FONT_BASELINE_OFFSET_RATIO)
	)
	_draw_text(
		control,
		baseline,
		_elide(summary, max_width, font, font_size),
		max_width,
		font,
		font_size,
		Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, SUMMARY_ALPHA)
	)


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

## Word-wrapped multi-line text (comments). `baseline` is the baseline of the FIRST line;
## subsequent lines flow downward at the font's line height. The wrap width / break flags
## match the viewport's wrapped_line_count(), so what is drawn fills exactly the height the
## row reserved. Zoom is handled like _draw_text: at zoom != 1 we paint at the physical size
## (scaling width too) so wrap points stay identical and glyphs stay crisp.
const COMMENT_BREAK_FLAGS := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND


func _draw_multiline_text(
	control: Control,
	baseline: Vector2,
	text: String,
	max_width: float,
	font: Font,
	font_size: int,
	color: Color
) -> void:
	if text.is_empty():
		return
	var zoom: float = control.get_zoom_factor() if control.has_method("get_zoom_factor") else 1.0
	# The same word-first break rule the height metrics measured with, so a cell never paints a
	# mid-word split its reserved height did not account for (and never splits "Ready" in two).
	var flags: int = ViewportRowMetrics.break_flags_for(text, max_width, font, font_size)
	if is_equal_approx(zoom, 1.0):
		control.draw_multiline_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, -1, color, flags)
		return
	var physical_size: int = maxi(int(round(font_size * zoom)), 6)
	var physical_width: float = max_width * zoom if max_width > 0.0 else max_width
	control.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	control.draw_multiline_string(font, baseline * zoom, text, HORIZONTAL_ALIGNMENT_LEFT, physical_width, physical_size, -1, color, flags)
	control.draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))


func draw_row(control: Control, layout: Dictionary, row_data: EventRowData, font: Font, font_size: int, editor_style: EventSheetEditorStyle = null) -> void:
	var row_rect: Rect2 = layout.get("row_rect", Rect2())
	var gutter_rect: Rect2 = layout.get("gutter_rect", Rect2())
	var fold_rect: Rect2 = layout.get("fold_rect", Rect2())
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
	var editing_select_anchor: int = int(layout.get("editing_select_anchor", -1))
	var selected_span_indices: Array = layout.get("selected_span_indices", [])
	var hovered_span_index: int = int(layout.get("hovered_span_index", -1))
	# R41 - the other uses of the hovered variable, in ITS scope, lit up alongside the one under the
	# cursor. The set arrives per row, because the uses are spread across rows.
	var match_span_indices: Array = Array(layout.get("match_span_indices", PackedInt32Array()))
	var total_selected_spans: int = int(layout.get("total_selected_spans", 0))
	var line_number: int = int(layout.get("line_number", 0))
	# Read LIVE off row_data (like bookmark_enabled below) - the layout dict is cached, so a
	# breakpoint toggled after the cache was built kept drawing its stale state until an
	# unrelated relayout happened to rebuild it.
	var breakpoint_enabled: bool = row_data.breakpoint_enabled
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
	# The marks that say what a row IS - the guides, the stripes, the drag bubble, the swatch
	# outline, the disabled scrim. Resolved once per row and handed down, the same way the event
	# style is, so no painter below has to know where a theme lives.
	var reading_style: EventSheetReadingStyle = (
		editor_style.get_reading_style()
		if editor_style != null
		else _fallback_reading_style()
	)

	# ── Gutter paint policy (structural, not paint-order): EVENT rows (and synthetic
	# sub-rows) OWN a visible gutter cell, so their fills use row_fill_rect, which starts
	# PAST the gutter - no later fill can cover the number, ever. GROUP/COMMENT/SECTION
	# rows are full-bleed bars: they draw over the gutter for the seamless event-sheet look,
	# their x=0 accent stripes visible (they show no number, so nothing is lost).
	# Event-number mode (default on, the event-sheet margin): event rows show their STABLE
	# sheet-order number INSTEAD of the flat row index - never both, or the two digit
	# strings smear whenever a comment/group/variable row makes them diverge. Off
	# restores the flat index on every row (visible where fills don't cover the gutter).
	var is_event_row: bool = row_data.row_type == EventRowData.RowType.EVENT
	var row_fill_rect: Rect2 = Rect2(gutter_rect.end.x, row_rect.position.y, maxf(row_rect.size.x - gutter_rect.size.x, 0.0), row_rect.size.y) if is_event_row else row_rect
	var gutter_number: int = int(layout.get("event_number", 0)) if show_event_numbers else line_number
	# The hit-count lens: resolved ONCE per row here, so _draw_gutter stays a painter. Empty
	# string = draw the gutter exactly as before (lens off, no traced run, or not an event row).
	var hit_uid: String = hit_chip_uid(show_hit_counts, is_event_row, str(layout.get("event_uid", "")))
	_draw_gutter(control, gutter_rect, gutter_number, breakpoint_enabled, row_data.bookmark_enabled, font, font_size, event_style, hit_uid, reading_style)
	if row_data.row_type == EventRowData.RowType.GROUP:
		var group_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
		if row_data.source_resource is EventGroup:
			group_tint = (row_data.source_resource as EventGroup).custom_color
		elif row_data.custom_color.a > 0.01:
			# A `#region` bar is a group bar without an EventGroup behind it (the file stores two
			# fence lines), so its accent arrives on the row itself.
			group_tint = row_data.custom_color
		_draw_group_row_chrome(control, row_rect, fold_rect, alternating, event_style, group_tint)
	elif row_data.row_type == EventRowData.RowType.REGION:
		# R1 - a region is a FOLD MARK, not a chapter bar: the faintest wash of its own colour and a
		# solid 2px rule on the head, and nothing but that rule on the closing tick, so the fences
		# read as the two lines of the file they are.
		_draw_region_row_chrome(control, row_rect, row_data.custom_color,
			EventSheetRegionFacts.is_closing_fence(row_data.source_resource), event_style)
	elif row_data.row_type == EventRowData.RowType.COMMENT and event_style != null:
		# Per-comment colors (event-sheet parity): the row's custom tint wins over the theme token.
		var comment_bg: Color = row_data.custom_color if row_data.custom_color.a > 0.01 else event_style.comment_row_background_color
		control.draw_rect(row_rect, comment_bg, true)
	elif is_event_row and event_style != null:
		control.draw_rect(
			row_fill_rect,
			event_style.row_background_alt_color if alternating else event_style.row_background_color,
			true
		)
	else:
		var section_bg: Color = BG_1 if alternating else BG_0
		# A row may carry a faint role tint (a published-verb Define row washed by its ACE kind): blend it
		# over the base so the block reads as its kind - an event block - then a left accent
		# bar in the same hue drives the cue home. custom_color.a == 0 rows are untouched.
		if row_data.custom_color.a > 0.01:
			section_bg = section_bg.lerp(Color(row_data.custom_color.r, row_data.custom_color.g, row_data.custom_color.b, section_bg.a), row_data.custom_color.a)
		control.draw_rect(row_rect, section_bg, true)
		if row_data.custom_color.a > 0.01:
			control.draw_rect(Rect2(row_rect.position, Vector2(3.0, row_rect.size.y)), Color(row_data.custom_color.r, row_data.custom_color.g, row_data.custom_color.b, 0.9), true)
	if row_data.variable_row:
		_draw_variable_row_wash(control, row_rect, reading_style)
	if row_data.rule_below:
		# V2 - the hairline that closes a block (the globals this sheet only uses, above the ones it
		# declares). Drawn in the variable rule's own colour, quietly, so no theme has to dress a
		# second token for a line one pixel tall.
		var hairline: Color = reading_style.variable_row_rule_color
		control.draw_rect(
			Rect2(Vector2(row_rect.position.x, row_rect.end.y - 1.0), Vector2(row_rect.size.x, 1.0)),
			Color(hairline.r, hairline.g, hairline.b, hairline.a * BLOCK_HAIRLINE_ALPHA),
			true
		)
	if not is_event_row and (breakpoint_enabled or row_data.bookmark_enabled):
		# The full-bleed bar just covered the gutter - re-stamp only the MARKERS so a
		# bookmarked comment / breakpointed group keeps its pennant and dot visible.
		_draw_gutter_markers(control, gutter_rect, breakpoint_enabled, row_data.bookmark_enabled, reading_style)
	# The event block's silhouette: the LEFT edge (condition lane) carries the full corner
	# radius - the bottom-left always rounds - and the RIGHT edge (action lane) half of it,
	# so blocks read as opening toward their actions. Radius 0 = the classic square look.
	var block_radius: int = event_style.event_corner_radius if event_style != null else 8
	var block_radius_right: int = int(round(block_radius * 0.5))
	if condition_lane_rect.size != Vector2.ZERO:
		var lane_color: Color = event_style.condition_lane_color if event_style != null else EventSheetPalette.COLOR_LANE_CONDITIONS
		_draw_rounded_rect(control, condition_lane_rect, lane_color, block_radius, 0, block_radius, 0)
	if action_lane_rect.size != Vector2.ZERO:
		var action_color: Color = event_style.action_lane_color if event_style != null else EventSheetPalette.COLOR_LANE_ACTIONS
		_draw_rounded_rect(control, action_lane_rect, action_color, 0, block_radius_right, 0, block_radius_right)
	if lane_divider_rect.size != Vector2.ZERO:
		control.draw_rect(
			lane_divider_rect,
			event_style.lane_divider_color if event_style != null else EventSheetPalette.COLOR_LANE_DIVIDER,
			true
		)
	if row_data.row_type == EventRowData.RowType.EVENT and event_style != null:
		# Border lines inset past the rounded corners so they never cut across the curve -
		# measured from the INSET fill (the block starts after the gutter cell), so the
		# hairlines never overhang into the gutter the fill deliberately avoids.
		var block_border: Color = event_style.row_border_color
		var border_left: float = row_fill_rect.position.x + float(block_radius)
		var border_width: float = maxf(row_fill_rect.size.x - float(block_radius + block_radius_right), 0.0)
		control.draw_rect(Rect2(border_left, row_fill_rect.position.y, border_width, 1.0), block_border, true)
		control.draw_rect(Rect2(border_left, row_fill_rect.end.y - 1.0, border_width, 1.0), block_border, true)
	_draw_indent_guides(control, row_rect, row_data.indent, reading_style.indent_guide_color)
	# M15 - the tree connector from a parent event down to this sub-event, on top of the indent
	# stops above. Draw-only: it reserves no width and is never measured, so it cannot move a
	# glyph; the guide geometry itself lives in its own helper.
	EventSheetViewportGuideLines.draw_guides(control, row_rect, row_data.indent, reading_style.tree_guide_color)
	if row_data.language_block:
		# A LANGUAGE block (a data-class holder, a methods-class, a host binding, a lifted switch case...)
		# reads as an event row but is not a regular ACE event: a quiet indigo left stripe + faint wash mark
		# the whole block without dimming it. Error / firing stripes below draw over it, so they still win.
		var language_accent: Color = (
			event_style.language_block_accent_color
			if event_style != null
			else EventSheetPalette.COLOR_LANGUAGE_BLOCK
		)
		control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 3.0, row_rect.size.y), Color(language_accent.r, language_accent.g, language_accent.b, 0.75), true)
		control.draw_rect(row_fill_rect, Color(language_accent.r, language_accent.g, language_accent.b, 0.05), true)
	if is_event_row and row_data.custom_color.a > 0.01:
		# A published verb's Define row is washed by its ACE KIND: a left accent bar plus a faint tint over
		# the whole block. Drawn AFTER the lane fills (the same place the language-block cue draws) so the
		# kind reads across both lanes instead of hiding under them. Error / firing stripes draw after this,
		# so they still win. Regular event rows carry no custom_color and are untouched.
		# The wash STRENGTH is the alpha the builder already baked in from the theme's
		# verb_row_tint_strength - read it back rather than keeping a second literal here that could
		# drift out of step with the one the caption band is derived from.
		var role_accent: Color = row_data.custom_color
		control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 3.0, row_rect.size.y), Color(role_accent.r, role_accent.g, role_accent.b, 0.9), true)
		control.draw_rect(row_fill_rect, role_accent, true)
	if not row_data.error_message.is_empty():
		# Error → row deep-link: a red left stripe + faint wash flag the offending row (the
		# message shows in the row tooltip). A fixed error red - not yet a theme token.
		var error_stripe: Color = reading_style.error_stripe_color
		control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 3.0, row_rect.size.y), error_stripe, true)
		control.draw_rect(row_fill_rect, Color(error_stripe.r, error_stripe.g, error_stripe.b, 0.08), true)
	if row_data.firing or row_data.firing_intensity > 0.0:
		# Live event trace: a cyan left stripe + faint wash on events firing right now (debug
		# run), PULSING - the intensity decays after each fire so a one-shot reads as a fading
		# flash while a sustained fire holds full glow (a bare firing flag paints at full).
		var pulse: float = maxf(row_data.firing_intensity, 1.0 if row_data.firing and row_data.firing_intensity <= 0.0 else 0.0)
		var firing_stripe: Color = reading_style.firing_stripe_color
		control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 3.0, row_rect.size.y), Color(firing_stripe.r, firing_stripe.g, firing_stripe.b, pulse), true)
		control.draw_rect(row_fill_rect, Color(firing_stripe.r, firing_stripe.g, firing_stripe.b, 0.10 * pulse), true)
	if row_data.selected and not has_span_selection:
		# Slightly tempered for single-cell rows (comments especially) - selection
		# stays unmistakable via the outline, without the full-strength flood fill.
		var row_selection: Color = selection_fill
		if row_data.row_type != EventRowData.RowType.EVENT:
			row_selection.a *= 0.75
		control.draw_rect(row_fill_rect, row_selection, true)
		if row_data.row_type != EventRowData.RowType.EVENT:
			_draw_row_outline(control, row_rect, selection_fill, SELECTION_OUTLINE_LIGHTEN, SELECTION_OUTLINE_ALPHA)
	# Hover feedback: individual conditions/actions highlight per-cell (drawn in _draw_spans).
	# Whole-row hover is only for single-cell rows (group/comment/variable); on a multi-cell
	# event it lights up the entire block and reads as "selected", which is confusing.
	if row_data.hovered and row_data.row_type != EventRowData.RowType.EVENT:
		# Softened (user call: full-strength fill + outline on comment rows strained
		# the eyes): a faint tint, no outline - selection keeps the strong look.
		var soft_hover: Color = hover_fill
		soft_hover.a *= 0.4
		control.draw_rect(row_rect, soft_hover, true)
	_draw_fold_arrow(control, fold_rect, row_data.folded, not row_data.children.is_empty())
	_draw_spans(control, row_data, font, font_size, editing_span_index, editing_buffer, editing_caret, editing_select_anchor, selected_span_indices, hovered_span_index, total_selected_spans, event_style, selection_fill, hover_fill, match_span_indices, reading_style)
	# V8 - what the open inline editor has to say before it is committed ("renames 6 uses in 2
	# sheets · Enter to apply · Esc"). Drawn AFTER the spans and measured from the field's own rect,
	# so it claims no layout: an editor's note is a hint, not a cell.
	_draw_editing_note(control, row_data, editing_span_index, str(layout.get("editing_note", "")),
		font, font_size, reading_style)
	# K4 - drawn OVER the condition cells: the rule lands in the gap between two condition lines,
	# and a cell's own plate is painted after the row's background, so a divider under it would be
	# covered by the very cells it separates.
	_draw_or_dividers(control, row_data, condition_lane_rect, font, font_size, reading_style)
	_draw_collapsed_summary(control, row_rect, row_data, font, font_size)
	if drag_rect.size != Vector2.ZERO:
		if bool(layout.get("drag_rect_outline", false)):
			# Group-fold drop: outline the whole target row (a filled row-sized rect would bury the
			# text) with a soft tint, so the gesture reads "fold INTO this", not "insert here".
			var group_fill: Color = reading_style.drag_line_color
			group_fill.a *= 0.2
			control.draw_rect(drag_rect, group_fill, true)
			control.draw_rect(drag_rect, reading_style.drag_line_color, false, 2.0)
		else:
			control.draw_rect(drag_rect, reading_style.drag_line_color, true)
			if drag_rect.size.y <= 4.0:
				_draw_insert_marker_arrows(control, drag_rect, reading_style.drag_line_color)
	if ace_drag_rect.size != Vector2.ZERO:
		var ace_drag_color: Color = reading_style.drag_refusal_color if ace_drag_error else reading_style.drag_line_color
		control.draw_rect(ace_drag_rect, ace_drag_color, ace_drag_rect.size.y <= 4.0, 2.0)
		if ace_drag_rect.size.y <= 4.0:
			_draw_insert_marker_arrows(control, ace_drag_rect, ace_drag_color)
	if drag_feedback_rect.size != Vector2.ZERO and not drag_feedback_text.is_empty():
		_draw_drag_feedback(control, drag_feedback_rect, drag_feedback_text, font, font_size, drag_feedback_error, reading_style)
	if disabled:
		control.draw_rect(row_rect, reading_style.disabled_row_color, true)
	if not debug_text.is_empty():
		_draw_debug_overlay(control, row_rect, font, font_size, debug_text)


## K4. Where an "or" divider sits on a row: the y of the rule, and the x range it may use. Measured
## from the TOP of the first span on the line being divided, so the rule lands in the gap between two
## conditions instead of on either of them. {} when that line has no condition span on this row (a
## sliced row, a fold) - nothing is ever ruled across an empty lane. Static and pure: the geometry is
## a fact about the laid-out row, so a test pins the same numbers the draw uses.
static func or_divider_geometry(row_data: EventRowData, line_index: int, lane_rect: Rect2) -> Dictionary:
	if row_data == null or lane_rect.size.x <= 0.0:
		return {}
	var top: float = -1.0
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata
		if str(metadata.get("lane", "")) != "condition":
			continue
		if int(metadata.get("line_index", -1)) != line_index:
			continue
		if top < 0.0 or span.rect.position.y < top:
			top = span.rect.position.y
	if top < 0.0:
		return {}
	return {
		"y": top - OR_DIVIDER_GAP,
		"from_x": lane_rect.position.x + OR_DIVIDER_INSET,
		"to_x": lane_rect.position.x + lane_rect.size.x - OR_DIVIDER_INSET
	}


## K4. The word "or" and a hairline, drawn between each pair of OR'd conditions. It replaces the badge
## the second condition used to wear: a badge says something about the row it is on, and "or" is
## about the pair. The theme's OR pair dresses it, so a preset that restyled the badge restyles this
## without knowing it changed.
func _draw_or_dividers(control: Control, row_data: EventRowData, lane_rect: Rect2, font: Font,
		font_size: int, reading_style: EventSheetReadingStyle = null) -> void:
	if row_data == null or row_data.or_condition_lines.is_empty() or font == null:
		return
	var reading: EventSheetReadingStyle = reading_style if reading_style != null else _fallback_reading_style()
	var word: String = EventSheetL10n.translate("or")
	var draw_size: int = maxi(font_size - 2, 8)
	var word_width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_size).x
	var ink: Color = reading.or_badge_foreground_color
	# The rule is the OR pair mixed: its own plate colour carries the theme's intent, and enough of
	# the word's ink to stay a visible hairline on a preset that made the plate nearly the row.
	var rule: Color = reading.or_badge_background_color.lerp(ink, 0.55)
	rule.a = maxf(rule.a, 0.5)
	for line_index: int in row_data.or_condition_lines:
		var geometry: Dictionary = or_divider_geometry(row_data, line_index, lane_rect)
		if geometry.is_empty():
			continue
		var y: float = float(geometry["y"])
		var from_x: float = float(geometry["from_x"])
		var to_x: float = float(geometry["to_x"])
		var baseline: float = y + (font.get_ascent(draw_size) - font.get_descent(draw_size)) * 0.5
		control.draw_string(font, Vector2(from_x, baseline), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_size, ink)
		var rule_start: float = from_x + word_width + OR_DIVIDER_WORD_GAP
		if rule_start < to_x:
			control.draw_line(Vector2(rule_start, y), Vector2(to_x, y), rule, 1.0)


func _draw_gutter(control: Control, gutter_rect: Rect2, line_number: int, breakpoint_enabled: bool, bookmark_enabled: bool, font: Font, font_size: int, event_style: EventSheetEventStyle = null, hit_uid: String = "", reading_style: EventSheetReadingStyle = null) -> void:
	if gutter_rect.size == Vector2.ZERO:
		return
	var reading: EventSheetReadingStyle = reading_style if reading_style != null else _fallback_reading_style()
	var gutter_bg: Color = event_style.gutter_background_color if event_style != null else EventSheetPalette.COLOR_GUTTER_BG
	var gutter_text: Color = event_style.gutter_text_color if event_style != null else EventSheetPalette.COLOR_GUTTER_TEXT
	control.draw_rect(gutter_rect, gutter_bg, true)
	control.draw_rect(Rect2(gutter_rect.end.x - 1.0, gutter_rect.position.y, 1.0, gutter_rect.size.y), reading.event_number_rail_color, true)
	# The count chip stacks UNDER the number rather than beside it: this gutter is 20px wide, and a
	# margin that grows when a debugger lens is switched on would reflow the whole sheet - the one
	# thing the lens must never do. Only a run that has actually streamed draws anything.
	var stacked: bool = not hit_uid.is_empty() and EventSheetTraceHitCounts.has_run()
	if line_number > 0:
		var text: String = str(line_number)
		var center_ratio: float = ROW_VERTICAL_CENTER_RATIO if not stacked else 0.0
		var baseline_y: float = gutter_rect.position.y + (gutter_rect.size.y * center_ratio) + ((font_size - 1) * FONT_BASELINE_OFFSET_RATIO)
		if stacked:
			baseline_y = gutter_rect.get_center().y - 1.0
		_draw_text(control, Vector2(gutter_rect.position.x + 4.0, baseline_y), text, gutter_rect.size.x - 8.0, font, font_size - 1, gutter_text)
	if stacked:
		_draw_hit_count_chip(control, gutter_rect, hit_uid, font, font_size)
	_draw_gutter_markers(control, gutter_rect, breakpoint_enabled, bookmark_enabled, reading)


## THE gate: which row gets a hit-count chip, and therefore whether ANY of this feature is
## painted. Returns the uid to report on, or "" for "draw the gutter exactly as it always was".
## Static and total, so "with the lens off nothing is emitted" is provable by the suite instead
## of by staring at two screenshots.
static func hit_chip_uid(lens_on: bool, is_event_row: bool, event_uid: String) -> String:
	if not lens_on or not is_event_row or event_uid.is_empty():
		return ""
	# No traced run means no counts. An unknown count is never drawn as a zero.
	return event_uid if EventSheetTraceHitCounts.has_run() else ""


## The chip's text for a uid: "x3" while the exact number fits, "1k"/"14k" once it does not.
## The x reads as a multiplier at a glance and is dropped where the width is needed for digits.
static func hit_chip_text(event_uid: String) -> String:
	var count: int = EventSheetTraceHitCounts.count_for(event_uid)
	var compact: String = EventSheetTraceHitCounts.chip_text(count)
	return ("x" + compact) if count < 1000 else compact


## The Event Trace's tally for one row, as a chip in the bottom half of the gutter cell: a muted
## count, warm when the row is among the run's busiest, and a dim left rail plus x0 when the row
## has not fired once since Run. The exact number is one hover away (the gutter tooltip) - at this
## width the chip is a glance, not a readout.
func _draw_hit_count_chip(control: Control, gutter_rect: Rect2, hit_uid: String, font: Font, font_size: int) -> void:
	var count: int = EventSheetTraceHitCounts.count_for(hit_uid)
	var fill: Color = HIT_CHIP_FILL
	var border: Color = HIT_CHIP_BORDER
	var text_color: Color = HIT_CHIP_TEXT
	if count == 0:
		fill = HIT_CHIP_COLD_FILL
		border = HIT_CHIP_COLD_BORDER
		text_color = HIT_CHIP_COLD_TEXT
		# The never-fired rail: a dim bar down the margin, so a cold row is findable by scrolling
		# past it rather than by reading every chip.
		control.draw_rect(Rect2(gutter_rect.position.x, gutter_rect.position.y + 1.0, 2.0, gutter_rect.size.y - 2.0), HIT_CHIP_COLD_RAIL, true)
	elif EventSheetTraceHitCounts.is_hot(hit_uid):
		fill = HIT_CHIP_HOT_FILL
		border = HIT_CHIP_HOT_BORDER
		text_color = HIT_CHIP_HOT_TEXT
	var chip_rect := Rect2(
		gutter_rect.position.x + HIT_CHIP_INSET,
		gutter_rect.get_center().y + 1.0,
		maxf(gutter_rect.size.x - HIT_CHIP_INSET * 2.0 - 1.0, 4.0),
		HIT_CHIP_HEIGHT
	)
	_draw_rounded_rect(control, chip_rect, fill, 2, 2, 2, 2)
	control.draw_rect(chip_rect.grow(-0.5), border, false, 1.0)
	var chip_font_size: int = maxi(font_size - 4, 7)
	var chip_text: String = hit_chip_text(hit_uid)
	var text_width: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, chip_font_size).x if font != null else 0.0
	var text_x: float = chip_rect.position.x + maxf((chip_rect.size.x - text_width) * 0.5, 0.5)
	# No width limit: draw_string CLIPS at the width it is given, measured from the draw position,
	# so passing the chip's own width would slice the last glyph off a CENTRED string.
	_draw_text(control, Vector2(text_x, chip_rect.position.y + HIT_CHIP_HEIGHT - 2.5), chip_text, -1.0, font, chip_font_size, text_color)


## The breakpoint dot + bookmark pennant, separated so full-bleed rows (group/comment/
## section - whose bars cover the whole gutter) can re-stamp JUST the markers on top:
## a bookmarked comment or a breakpointed group must still show its indicator.
func _draw_gutter_markers(control: Control, gutter_rect: Rect2, breakpoint_enabled: bool, bookmark_enabled: bool, reading_style: EventSheetReadingStyle = null) -> void:
	var reading: EventSheetReadingStyle = reading_style if reading_style != null else _fallback_reading_style()
	if breakpoint_enabled:
		var center: Vector2 = Vector2(gutter_rect.position.x + 7.0, gutter_rect.get_center().y)
		control.draw_circle(center, 3.5, reading.breakpoint_color)
	if bookmark_enabled:
		# Bookmark flag: a small right-pointing pennant at the gutter's right edge.
		var flag_x: float = gutter_rect.end.x - 10.0
		var flag_y: float = gutter_rect.get_center().y
		control.draw_colored_polygon(PackedVector2Array([
			Vector2(flag_x, flag_y - 4.0),
			Vector2(flag_x + 7.0, flag_y),
			Vector2(flag_x, flag_y + 4.0)
		]), reading.bookmark_color)


func _draw_indent_guides(control: Control, row_rect: Rect2, depth: int, guide_color: Color = EventSheetPalette.COLOR_GUIDE) -> void:
	for level: int in range(depth):
		var guide_x: float = row_rect.position.x + EventSheetPalette.GUTTER_WIDTH + float(level * INDENT_WIDTH) + 2.0
		control.draw_line(
			Vector2(guide_x, row_rect.position.y + 4.0),
			Vector2(guide_x, row_rect.end.y - 4.0),
			guide_color,
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


func _draw_group_row_chrome(control: Control, row_rect: Rect2, fold_rect: Rect2, alternating: bool, event_style: EventSheetEventStyle = null, group_tint: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var bg: Color = EventSheetPalette.COLOR_GROUP_BG_ALT if alternating else EventSheetPalette.COLOR_GROUP_BG
	if event_style != null:
		bg = event_style.group_background_alt_color if alternating else event_style.group_background_color
	var accent: Color = event_style.group_accent_color if event_style != null else EventSheetPalette.COLOR_GROUP_ACCENT
	# Per-group color tag wins over the theme (event-sheet parity, mirrors per-comment colors).
	if group_tint.a > 0.0:
		accent = group_tint
		bg = bg.lerp(Color(group_tint.r, group_tint.g, group_tint.b, bg.a), 0.22)
	var fold_bg: Color = event_style.group_fold_background_color if event_style != null else EventSheetPalette.COLOR_GROUP_FOLD_BG
	# Group corner rounding is a theme token (0 = the classic square bar). When rounded, the full-width
	# top/bottom accent hairlines inset by the radius so they don't overhang the rounded corners.
	var group_radius: int = event_style.group_corner_radius if event_style != null else 0
	_draw_rounded_rect(control, row_rect, bg, group_radius, group_radius, group_radius, group_radius)
	control.draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 3.0, row_rect.size.y), accent, true)
	control.draw_rect(Rect2(row_rect.position.x + group_radius, row_rect.position.y, row_rect.size.x - 2.0 * group_radius, 1.0), accent.darkened(0.28), true)
	control.draw_rect(Rect2(row_rect.position.x + group_radius, row_rect.end.y - 1.0, row_rect.size.x - 2.0 * group_radius, 1.0), accent.darkened(0.38), true)
	if fold_rect.size != Vector2.ZERO:
		control.draw_rect(fold_rect.grow(1.0), fold_bg, true)


## R1 - a region fence's chrome. The opener wears the faintest wash of the region's own colour and
## a solid rule at its left edge; the closing tick wears the rule alone, over nothing, so it reads
## as the end of the dashed rule running down the body rather than as another row.
func _draw_region_row_chrome(control: Control, row_rect: Rect2, accent: Color, closing: bool,
		event_style: EventSheetEventStyle = null) -> void:
	var ink: Color = accent
	if ink.a <= 0.01:
		ink = event_style.behavior_accent_color if event_style != null else EventSheetPalette.COLOR_GROUP_ACCENT
	if not closing:
		control.draw_rect(row_rect, Color(ink.r, ink.g, ink.b, REGION_ROW_WASH_ALPHA), true)
	control.draw_rect(
		Rect2(row_rect.position.x, row_rect.position.y, EventSheetGroupFacts.BRACKET_WIDTH, row_rect.size.y),
		Color(ink.r, ink.g, ink.b, REGION_RULE_ALPHA),
		true
	)


## A dashed box around one badge, drawn as four dashed strokes. Godot's own dashed-line primitive
## does the spacing, so the dashes here and the dashed rule down a region's body are the same mark.
func _draw_dashed_outline(control: Control, rect: Rect2, ink: Color) -> void:
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	for index: int in range(corners.size()):
		control.draw_dashed_line(
			corners[index], corners[(index + 1) % corners.size()], ink, 1.0, REGION_DASH_LENGTH
		)


func _draw_spans(
	control: Control,
	row_data: EventRowData,
	font: Font,
	font_size: int,
	editing_span_index: int,
	editing_buffer: String,
	editing_caret: int,
	editing_select_anchor: int,
	selected_span_indices: Array,
	hovered_span_index: int,
	total_selected_spans: int,
	event_style: EventSheetEventStyle = null,
	selection_fill: Color = EventSheetPalette.COLOR_SELECTION,
	hover_fill: Color = EventSheetPalette.COLOR_HOVER,
	match_span_indices: Array = [],
	reading_style: EventSheetReadingStyle = null
) -> void:
	var reading: EventSheetReadingStyle = reading_style if reading_style != null else _fallback_reading_style()
	# Multi-line blocks (in-flow GDScript, action-lane comments) paint as ONE merged
	# cell: union rects per block, background/hover/selection drawn once. The per-line
	# spans remain the layout + hit-test truth - the merge is purely visual (user
	# call: a 3-line GDScript action is one resized cell, not three stacked cells).
	var groups: Dictionary = resolve_block_groups(row_data.spans)
	var block_unions: Dictionary = groups["unions"]
	var block_heads: Dictionary = groups["heads"]
	# Selection/background for a block draws once at the union, regardless of WHICH
	# member line is the selected/hovered one (a single click selects only the clicked
	# line's span, often not the head - guarding on the head dropped the highlight).
	var drawn_block_selection: Dictionary = {}
	# Declutter: the "+ Add action" / "+ Add condition" affordances are hidden at rest and revealed
	# when the row is hovered or selected, so a populated sheet reads calmly instead of repeating
	# add links under every event. Events that have NO actions (or no real conditions - the Every
	# Tick placeholder doesn't count) keep theirs visible so newcomers can still discover them.
	# The spans stay in the layout model regardless (hit-testing + tests rely on them).
	var row_has_action: bool = false
	var row_has_condition: bool = false
	for probe_span: SemanticSpan in row_data.spans:
		if probe_span == null or not (probe_span.metadata is Dictionary):
			continue
		var probe_meta: Dictionary = probe_span.metadata as Dictionary
		var probe_kind: String = str(probe_meta.get("kind", ""))
		if probe_kind == "action":
			row_has_action = true
		elif probe_kind == "trigger" or (probe_kind == "condition" and not bool(probe_meta.get("placeholder", false))):
			# A trigger occupies the lane too: an "On Ready -> act" row is complete, so its add
			# link can wait for hover like any populated lane.
			row_has_condition = true
	var reveal_add_action: bool = row_data.hovered or row_data.selected or not row_has_action
	var reveal_add_condition: bool = row_data.hovered or row_data.selected or not row_has_condition
	for span_index: int in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[span_index]
		if span == null:
			continue
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		var span_kind: String = str(metadata.get("kind", ""))
		if span_kind == "add_action" and not reveal_add_action:
			continue
		if span_kind == "add_condition" and not reveal_add_condition:
			continue
		# The add affordances get button chrome (a faint pill) instead of the generic span hover
		# box, so they read as clickable buttons rather than stray muted text.
		var is_add_affordance: bool = span_kind == "add_action" or span_kind == "add_condition" or span_kind == "add_event"
		var in_block: bool = block_heads.has(span_index)
		var is_block_head: bool = in_block and int(block_heads[span_index]) == span_index
		if bool(metadata.get("chip", false)):
			if in_block:
				if is_block_head:
					_draw_block_cell(control, block_unions[span_index], metadata)
			elif bool(metadata.get("code_cell", false)):
				_draw_block_cell(control, span.rect, metadata)
			else:
				_draw_chip_span(control, span, metadata, event_style.cell_corner_radius if event_style != null else 4)
		if selected_span_indices.has(span_index):
			if bool(metadata.get("chip", false)):
				var head_for_block: int = int(block_heads.get(span_index, -1))
				if not in_block:
					_draw_chip_selected_span(control, span, metadata, selection_fill, total_selected_spans > 1)
				elif not drawn_block_selection.has(head_for_block):
					# One draw per block - alpha would otherwise stack when several
					# members are selected (rubber-band).
					drawn_block_selection[head_for_block] = true
					var selected_rect_span: SemanticSpan = SemanticSpan.new()
					selected_rect_span.rect = block_unions[span_index]
					_draw_chip_selected_span(control, selected_rect_span, metadata, selection_fill, total_selected_spans > 1)
			else:
				var selected_bg: Color = selection_fill
				selected_bg.a = 0.72
				control.draw_rect(span.rect.grow(2.0), selected_bg, true)
				var selected_outline: Color = selection_fill.lightened(SPAN_SELECT_OUTLINE_LIGHTEN)
				selected_outline.a = SPAN_SELECT_OUTLINE_ALPHA
				control.draw_rect(span.rect.grow(2.0), selected_outline, false, 1.0)
		elif match_span_indices.has(span_index) and span_index != hovered_span_index and not is_add_affordance:
			# R41 - a use of the hovered variable somewhere else in its scope: a tint far softer than
			# the cursor's own hover, so the eye finds every one of them without the sheet lighting up.
			var match_rect: Rect2 = block_unions[span_index] if in_block else span.rect
			var match_fill: Color = hover_fill
			match_fill.a = reading.name_highlight_strength
			control.draw_rect(match_rect.grow(1.0), match_fill, true)
			var match_edge: Color = hover_fill.lightened(SPAN_HOVER_OUTLINE_LIGHTEN)
			match_edge.a = 0.65
			control.draw_rect(match_rect.grow(1.0), match_edge, false, 1.0)
		elif span_index == hovered_span_index and not is_add_affordance:
			if bool(metadata.get("chip", false)):
				var hover_rect: Rect2 = block_unions[span_index] if in_block else span.rect
				_draw_cell_hover(control, hover_rect, event_style.cell_hover_color if event_style != null else _fallback_event_style().cell_hover_color)
			else:
				# Softened span hover (user call: highlighting strained the eyes).
				var hover_bg: Color = hover_fill
				hover_bg.a = 0.28
				control.draw_rect(span.rect.grow(1.0), hover_bg, true)
				var hover_outline: Color = hover_fill.lightened(SPAN_HOVER_OUTLINE_LIGHTEN)
				hover_outline.a = 0.55
				control.draw_rect(span.rect.grow(1.0), hover_outline, false, 1.0)
		if bool(metadata.get("badge", false)):
			_draw_badge_span(control, span, font, font_size, metadata)
			continue
		var color: Color = metadata.get("text_color", _get_span_color(span.type, event_style))
		# V12 - the type word is the guide rail on a variable's value: while the field is being typed
		# into, a literal the declared type cannot hold turns amber with the reason on the row, never
		# a modal. The value is still whatever the file says until Enter.
		if span_index == editing_span_index and metadata.has("variable_type_name") \
				and not EventSheetVariableSentence.value_fits(str(metadata["variable_type_name"]), editing_buffer):
			color = reading.lift_note_badge_foreground_color
		var ace_enabled: bool = bool(metadata.get("ace_enabled", true))
		if not ace_enabled:
			color = color.lerp(TEXT_MUTED, 0.6)
		if is_add_affordance:
			_draw_add_affordance_pill(control, span.rect, color, span_index == hovered_span_index)
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
		# Event-sheet-style object icon + label drawn before the ACE text
		# (e.g. "[icon] System  Is on floor").
		var object_icon: Variant = metadata.get("object_icon")
		if object_icon is Texture2D:
			# Event-sheet icon chip: a subtle rounded plate behind the icon so every row's icon
			# reads as one tidy framed column (the "{my}" look).
			var plate_y: float = span.rect.position.y + (span.rect.size.y - OBJECT_ICON_PLATE_SIZE) * 0.5
			var plate_rect := Rect2(text_x, plate_y, OBJECT_ICON_PLATE_SIZE, OBJECT_ICON_PLATE_SIZE)
			control.draw_style_box(_object_icon_plate_style(), plate_rect)
			var icon_inset: float = (OBJECT_ICON_PLATE_SIZE - OBJECT_ICON_SIZE) * 0.5
			control.draw_texture_rect(object_icon as Texture2D, Rect2(text_x + icon_inset, plate_y + icon_inset, OBJECT_ICON_SIZE, OBJECT_ICON_SIZE), false)
			text_x += OBJECT_ICON_ADVANCE
			text_width = max(span.rect.size.x - (text_x - span.rect.position.x) - right_padding, 1.0)
		var object_label: String = str(metadata.get("object_label", ""))
		if not object_label.is_empty():
			var object_color: Color = event_style.object_label_color if event_style != null else COLOR_OBJECT
			# "System" is the catch-all object for engine/Core ACEs, so it repeats on nearly
			# every row. Keep it (the object is always shown) but dim it so the eye reads the
			# actual condition/action, not a column of identical "System" labels.
			if object_label == "System":
				object_color.a *= 0.5
			# Event-sheet sub-lane: a fixed object column aligns every row's display text at the
			# same edge (label clipped to the column); width 0 keeps the classic flow where
			# text follows each label.
			# The lane width comes back through the control (the same way zoom does above): _draw_spans
			# does not receive the lane rects, and the column MUST be bounded by the same number the
			# measure / hit-test twins use or draw and hit-test drift apart.
			var drawn_lane: String = str(metadata.get("lane", ""))
			var lane_bound: float = control.lane_width_for(drawn_lane) if control.has_method("lane_width_for") else 0.0
			var object_column_width: float = object_column_width_for(event_style, drawn_lane, lane_bound)
			# Sub-lane alignment: the layout stamps the per-span column width whose boundary
			# lands on the lane's SHARED separator x (a badge shifts a cell's start; the fixed
			# style width would drift its separator off the lines below). Prefer it when set.
			var aligned_column: Variant = metadata.get("object_column_px")
			if object_column_width > 0.0 and aligned_column is float and is_equal_approx(float(metadata.get("object_column_base", -1.0)), object_column_width):
				object_column_width = aligned_column
			if object_column_width > 0.0:
				# A name too long for the column ELIDES ("CharacterBody2D" -> "CharacterBo…") rather than
				# being sliced mid-glyph: draw_string's width argument clips, it does not ellipsize, and a
				# column the user can drag narrow needs to degrade legibly at any width.
				var label_limit: float = min(object_column_width - 6.0, text_width)
				_draw_text(control, Vector2(text_x, baseline_y), _elide(object_label, label_limit, font, draw_font_size), label_limit, font, draw_font_size, object_color)
				# W14 - the variable's OWN name, muted, after the class the object column now says.
				# The class is what the object is; the name is which one, and a reader who goes looking
				# for it in the code needs both. Drawn INSIDE the column and only when the column has
				# room left, so every row's text still starts on the same edge.
				var column_note: String = str(metadata.get("object_note", ""))
				if not column_note.is_empty():
					var used: float = font.get_string_size(object_label + " ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
					var note_room: float = label_limit - used
					if note_room > 12.0:
						var column_note_color: Color = object_color
						column_note_color.a *= 0.55
						_draw_text(control, Vector2(text_x + used, baseline_y),
							_elide(column_note, note_room, font, draw_font_size), note_room, font,
							draw_font_size, column_note_color)
				text_x += object_column_width
			else:
				_draw_text(control, Vector2(text_x, baseline_y), object_label, text_width, font, draw_font_size, object_color)
				text_x += font.get_string_size(object_label + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
				# W14 - the variable's OWN name, muted, beside the class the object column now says.
				# The class is what the object is; the name is which one, and a reader who goes
				# looking for it in the code needs both. Flow mode only: in column mode the column is
				# the class's, and a second word in it would push every row's text out of alignment.
				var object_note: String = str(metadata.get("object_note", ""))
				if not object_note.is_empty():
					var note_color: Color = object_color
					note_color.a *= 0.55
					_draw_text(control, Vector2(text_x, baseline_y), object_note, text_width, font, draw_font_size, note_color)
					text_x += font.get_string_size(object_note + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
			# The object column's RESTING separator - a hairline on the same boundary the resize grab
			# uses. An event sheet shows this split permanently, so the object column reads as a real column
			# rather than as text that happens to start further along; without it the boundary was
			# invisible until the cursor crossed it and the resize cursor appeared.
			# ONLY in column mode: in flow mode there is no column, so a line after each label would
			# just be a ragged staircase marking a boundary that does not exist.
			if object_column_width > 0.0:
				_draw_object_column_separator(control, span, text_x, event_style)
			# N10 - the drawn bounds of the object column, so ONE click on the name can open the
			# object popup. The label is not a span of its own (it is drawn inside the leading edge
			# of the condition/action cell), so the same trick the colour swatch uses applies: the
			# renderer, which is the only thing that knows where the text actually landed, stamps
			# its rect and the input layer hit-tests against it.
			span.metadata["object_label_rect"] = Rect2(
				span.rect.position.x, span.rect.position.y,
				text_x - span.rect.position.x, span.rect.size.y)
			text_width = max(span.rect.size.x - (text_x - span.rect.position.x) - right_padding, 1.0)
		var value_ranges: Array = metadata.get("value_ranges", []) if span_index != editing_span_index else []
		var param_ranges: Array = metadata.get("param_ranges", []) if span_index != editing_span_index else []
		var bbcode_segments: Array = metadata.get("bbcode_segments", []) if span_index != editing_span_index else []
		# V13 - the code echo rests at a fraction of its colour so the sentence leads, and comes up
		# to full the moment the pointer is on the row it belongs to.
		if row_data.hovered and bool(metadata.get("code_echo", false)) and not bbcode_segments.is_empty():
			bbcode_segments = opaque_segments(bbcode_segments)
		if not bbcode_segments.is_empty():
			# BBCode-lite cells: sequential styled segments (bold = double-draw). A segment the
			# author left colour-less still shows the typed value TINTS - its text is split at
			# the value-range boundaries (offsets into the stripped text) and each piece draws
			# in its range's hue, so `[b]{amount}[/b]` reads bold AND number-green.
			# When the layout stamped segment_wrap_breaks (the cell is taller than one line),
			# the segment run is sliced at those exact offsets and drawn as stacked visual
			# lines - the event-sheet rule: the cell grows, styled text never clips.
			var bbcode_value_color: Color = event_style.value_highlight_color if event_style != null else COLOR_VALUE
			var seg_breaks: PackedInt32Array = metadata.get("segment_wrap_breaks", PackedInt32Array()) if span_index != editing_span_index else PackedInt32Array()
			if seg_breaks.is_empty():
				seg_breaks = PackedInt32Array([0])
			var total_length: int = 0
			for length_segment: Dictionary in bbcode_segments:
				total_length += str(length_segment.get("text", "")).length()
			var seg_line_h: float = float(metadata.get("comment_line_height", draw_font_size + 6))
			var first_baseline_y: float = baseline_y
			if seg_breaks.size() > 1:
				# Multi-line: start from a first-line baseline (baseline_y centers on the whole
				# multi-line rect), same recompute the wrapped-comment path does.
				first_baseline_y = span.rect.position.y + (seg_line_h * ROW_VERTICAL_CENTER_RATIO) + (draw_font_size * FONT_BASELINE_OFFSET_RATIO)
			for break_index in range(seg_breaks.size()):
				var seg_line_start: int = seg_breaks[break_index]
				var seg_line_end: int = seg_breaks[break_index + 1] if break_index + 1 < seg_breaks.size() else total_length
				var line_baseline_y: float = first_baseline_y + float(break_index) * seg_line_h
				var segment_x: float = text_x
				var segment_offset: int = 0
				for segment: Dictionary in bbcode_segments:
					var full_segment_text: String = str(segment.get("text", ""))
					var segment_start: int = segment_offset
					segment_offset += full_segment_text.length()
					if full_segment_text.is_empty() or segment_offset <= seg_line_start or segment_start >= seg_line_end:
						continue
					var piece_from: int = maxi(segment_start, seg_line_start)
					var piece_offset_shift: int = piece_from
					var segment_text: String = full_segment_text.substr(piece_from - segment_start, mini(segment_offset, seg_line_end) - piece_from)
					if segment_text.is_empty():
						continue
					var has_author_color: bool = segment.get("color") is Color
					var segment_color: Color = segment.get("color") if has_author_color else color
					if bool(segment.get("italic", false)):
						segment_color = Color(segment_color, segment_color.a * 0.85)
					var remaining: float = text_width - (segment_x - text_x)
					if remaining <= 1.0:
						break
					if has_author_color or value_ranges.is_empty():
						_draw_text(control, Vector2(segment_x, line_baseline_y), segment_text, remaining, font, draw_font_size, segment_color)
						if bool(segment.get("bold", false)):
							_draw_text(control, Vector2(segment_x + 0.7, line_baseline_y), segment_text, remaining, font, draw_font_size, segment_color)
					else:
						var shifted_ranges: Array = []
						for value_range: Variant in value_ranges:
							if value_range is Array and (value_range as Array).size() >= 2:
								var local_start: int = int((value_range as Array)[0]) - piece_offset_shift
								if local_start + int((value_range as Array)[1]) > 0 and local_start < segment_text.length():
									var kept: Array = [maxi(local_start, 0),
										mini(local_start + int((value_range as Array)[1]), segment_text.length()) - maxi(local_start, 0)]
									if (value_range as Array).size() >= 3:
										kept.append((value_range as Array)[2])
									shifted_ranges.append(kept)
						_draw_text_with_values(control, Vector2(segment_x, line_baseline_y), segment_text, shifted_ranges,
							remaining, font, draw_font_size, segment_color, bbcode_value_color,
							reading.string_value_color, reading.boolean_value_color)
						if bool(segment.get("bold", false)):
							_draw_text_with_values(control, Vector2(segment_x + 0.7, line_baseline_y), segment_text, shifted_ranges,
								remaining, font, draw_font_size, segment_color, bbcode_value_color,
								reading.string_value_color, reading.boolean_value_color)
					segment_x += font.get_string_size(segment_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
		elif bool(metadata.get("comment_wrap", false)) and span_index != editing_span_index:
			# Wrapped comment: draw from the top of the (multi-line-tall) cell so the whole
			# note reads vertically. baseline_y centers on the WHOLE rect, so recompute a
			# first-line baseline using the single-line height the layout reserved.
			var comment_line_h: float = float(metadata.get("comment_line_height", draw_font_size + 6))
			var comment_baseline_y: float = span.rect.position.y + (comment_line_h * ROW_VERTICAL_CENTER_RATIO) + (draw_font_size * FONT_BASELINE_OFFSET_RATIO)
			_draw_multiline_text(control, Vector2(text_x, comment_baseline_y), draw_text, text_width, font, draw_font_size, color)
		elif value_ranges.is_empty():
			_draw_text(control, Vector2(text_x, baseline_y), draw_text, text_width, font, draw_font_size, color)
		else:
			var value_color: Color = event_style.value_highlight_color if event_style != null else COLOR_VALUE
			_draw_text_with_values(control, Vector2(text_x, baseline_y), draw_text, value_ranges, text_width, font, draw_font_size, color, value_color, reading.string_value_color, reading.boolean_value_color)
		# The event-sheet parameter emphasis: every substituted parameter value re-draws 0.7px over -
		# the same double-draw bold the BBCode cells use - in whatever colour that run already
		# has, so the typed value tints never wash out.
		if not param_ranges.is_empty() and bbcode_segments.is_empty() and not bool(metadata.get("comment_wrap", false)):
			var emphasis_value_color: Color = event_style.value_highlight_color if event_style != null else COLOR_VALUE
			_draw_param_emphasis(control, Vector2(text_x, baseline_y), draw_text, param_ranges, value_ranges,
				text_width, font, draw_font_size, color, emphasis_value_color,
				reading.string_value_color, reading.boolean_value_color)
		# Color params get a small swatch right after the text (event-sheet-style color preview).
		var swatch: Variant = metadata.get("swatch_color")
		if swatch is Color:
			var swatch_advance: float = minf(font.get_string_size(draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x, text_width)
			var swatch_size: float = swatch_box_for(draw_font_size)
			var swatch_rect: Rect2 = Rect2(text_x + swatch_advance + SWATCH_GAP, span.rect.position.y + (span.rect.size.y - swatch_size) * 0.5, swatch_size, swatch_size)
			control.draw_rect(swatch_rect, swatch as Color, true)
			control.draw_rect(swatch_rect, reading.color_swatch_border_color, false, 1.0)
			# Record where the swatch landed so a click can hit-test it and open the inline colour picker
			# (no dialog) - the viewport reads span.metadata["swatch_rect"] in _handle_mouse_button.
			span.metadata["swatch_rect"] = swatch_rect
		# Compression cue: an ACE that compiles to MORE than one line is doing abstraction
		# work - a quiet "→N" after the text makes that legible, so plain 1:1 rows read as
		# Extract-to-Function candidates and compressing rows read as earned leverage.
		var compiled_lines: int = int(metadata.get("compiled_lines", 0))
		if compiled_lines > 1 and span_index != editing_span_index:
			var cue_x: float = text_x + minf(font.get_string_size(draw_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x, text_width) + 8.0
			if swatch is Color:
				cue_x += swatch_box_for(draw_font_size) + 8.0
			var cue_font_size: int = maxi(draw_font_size - 2, 8)
			var cue_color: Color = Color(TEXT_MUTED, TEXT_MUTED.a * 0.85)
			_draw_text(control, Vector2(cue_x, baseline_y), "→%d" % compiled_lines, 64.0, font, cue_font_size, cue_color)
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
			# Inline text selection: a translucent band over anchor..caret (drawn over the
			# text, low alpha = the classic highlight look).
			if editing_select_anchor >= 0 and editing_select_anchor != editing_caret:
				var select_from: int = clamp(mini(editing_select_anchor, editing_caret), 0, draw_text.length())
				var select_to: int = clamp(maxi(editing_select_anchor, editing_caret), 0, draw_text.length())
				var select_x: float = text_x + font.get_string_size(draw_text.substr(0, select_from), HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
				var select_w: float = font.get_string_size(draw_text.substr(select_from, select_to - select_from), HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
				select_w = minf(select_w, maxf(span.rect.end.x - right_padding - select_x, 0.0))
				if select_w > 0.0:
					control.draw_rect(Rect2(select_x, span.rect.position.y + 3.0, select_w, span.rect.size.y - 6.0), reading.text_selection_color, true)
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


## V8. The muted line beside an open inline editor, starting one gap past the field it belongs to
## and clipped to the row. Nothing at all when no field is open or the field has nothing to say -
## which is every edit but a rename.
func _draw_editing_note(control: Control, row_data: EventRowData, editing_span_index: int,
		note: String, font: Font, font_size: int, reading: EventSheetReadingStyle) -> void:
	if note.strip_edges().is_empty() or editing_span_index < 0 or editing_span_index >= row_data.spans.size():
		return
	var field: SemanticSpan = row_data.spans[editing_span_index]
	if field == null or field.rect.size.x <= 0.0:
		return
	var note_size: int = EventSheetPalette.resolve_font_size(font_size, -1)
	var note_x: float = field.rect.end.x + EventSheetPalette.scaled_f(10.0)
	var available: float = control.size.x - EventSheetPalette.ROW_HORIZONTAL_PADDING - note_x
	if available <= 0.0:
		return
	control.draw_string(font, Vector2(note_x, field.rect.position.y + field.rect.size.y * ROW_VERTICAL_CENTER_RATIO
		+ float(note_size) * FONT_BASELINE_OFFSET_RATIO), note,
		HORIZONTAL_ALIGNMENT_LEFT, available, note_size, reading.muted_text_color)


## Rounded-rect fills share cached StyleBoxFlats (bounded: a handful of colors x radii),
## so per-frame drawing allocates nothing. Radius 0 on every corner falls back to the
## plain rect fill.
static var _rounded_box_cache: Dictionary = {}


func _draw_rounded_rect(control: Control, rect: Rect2, color: Color, top_left: int, top_right: int, bottom_left: int, bottom_right: int) -> void:
	if top_left == 0 and top_right == 0 and bottom_left == 0 and bottom_right == 0:
		control.draw_rect(rect, color, true)
		return
	var key: String = "%d:%d:%d:%d:%s" % [top_left, top_right, bottom_left, bottom_right, color.to_html()]
	var box: StyleBoxFlat = _rounded_box_cache.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = color
		box.corner_radius_top_left = top_left
		box.corner_radius_top_right = top_right
		box.corner_radius_bottom_left = bottom_left
		box.corner_radius_bottom_right = bottom_right
		_rounded_box_cache[key] = box
	box.draw(control.get_canvas_item(), rect)


func _draw_chip_span(control: Control, span: SemanticSpan, metadata: Dictionary, cell_radius: int = 4) -> void:
	# Flat event-sheet/GDevelop-style cell with softly rounded corners (the radius is the
	# theme's cell_corner_radius token; 0 = the classic square cell).
	var bg: Color = metadata.get("chip_bg", _fallback_reading_style().default_chip_plate_color)
	_draw_rounded_rect(control, span.rect, bg, cell_radius, cell_radius, cell_radius, cell_radius)


## Button chrome behind the "+ Add event/condition/action" affordances: a faint rounded pill with
## an outline, brightening on hover - so the add gestures read as clickable buttons instead of
## stray muted text (newcomers don't click things that look like notes). Alpha is fixed here; the
## accent's own alpha is ignored (the affordance text is deliberately faded to 55%).
static func _draw_add_affordance_pill(control: Control, rect: Rect2, accent: Color, hovered: bool) -> void:
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.set_corner_radius_all(8)
	pill.set_border_width_all(1)
	pill.bg_color = Color(accent.r, accent.g, accent.b, 0.16 if hovered else 0.06)
	pill.border_color = Color(accent.r, accent.g, accent.b, 0.55 if hovered else 0.28)
	control.draw_style_box(pill, rect.grow_individual(7.0, 1.0, 7.0, 1.0))

# Calm, theme-neutral GDScript-cell tint: a very faint desaturated wash + a muted left stripe, so a
# code cell reads as "this is code" without the saturated blue that fought the editor theme.
const CODE_CELL_BG := Color(0.62, 0.64, 0.68, 0.05)
const CODE_CELL_STRIPE := Color(0.56, 0.58, 0.63, 0.38)


## Groups consecutive multi-line block spans (block_lines>1, starting at block_line 0)
## into one visual cell. Returns {"unions": {span_index: Rect2}, "heads":
## {span_index: head_index}} covering every member of every block - so background,
## hover and selection can draw once at the union no matter which member line the
## user clicked (the per-line spans stay the hit-test truth).
static func resolve_block_groups(spans: Array) -> Dictionary:
	var unions: Dictionary = {}
	var heads: Dictionary = {}
	var scan_index: int = 0
	while scan_index < spans.size():
		var head_span: SemanticSpan = spans[scan_index]
		var head_meta: Dictionary = head_span.metadata if head_span != null and head_span.metadata is Dictionary else {}
		var block_total: int = int(head_meta.get("block_lines", 0))
		if block_total > 1 and int(head_meta.get("block_line", -1)) == 0:
			var last_member: int = mini(scan_index + block_total, spans.size()) - 1
			var union_rect: Rect2 = head_span.rect
			for member: int in range(scan_index + 1, last_member + 1):
				if spans[member] != null:
					union_rect = union_rect.merge(spans[member].rect)
			for member: int in range(scan_index, last_member + 1):
				unions[member] = union_rect
				heads[member] = scan_index
			scan_index = last_member + 1
			continue
		scan_index += 1
	return {"unions": unions, "heads": heads}


## One merged cell for a multi-line block. In-flow GDScript additionally gets a code
## stripe + cool tint, so "this cell is code" reads at a glance (user call: it must be
## visually obvious when an action is just GDScript).
func _draw_block_cell(control: Control, rect: Rect2, metadata: Dictionary) -> void:
	if bool(metadata.get("code_cell", false)):
		control.draw_rect(rect, CODE_CELL_BG, true)
		control.draw_rect(Rect2(rect.position.x, rect.position.y, 2.0, rect.size.y), CODE_CELL_STRIPE, true)
		return
	var bg: Color = metadata.get("chip_bg", _fallback_reading_style().default_chip_plate_color)
	control.draw_rect(rect, bg, true)


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
	# Flat selected cell: a stronger accent-tinted fill plus a left accent bar (event-sheet cue).
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
	is_error: bool,
	reading_style: EventSheetReadingStyle = null
) -> void:
	var reading: EventSheetReadingStyle = reading_style if reading_style != null else _fallback_reading_style()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = (
		reading.drag_bubble_refused_background_color
		if is_error
		else reading.drag_bubble_background_color
	)
	style.border_color = (
		reading.drag_refusal_color
		if is_error
		else reading.drag_line_color
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
		reading.drag_bubble_text_color
	)


## The same styled segments at full opacity - what a resting code echo looks like once the pointer
## reaches its row. Static and pure, so the hover state is testable without a canvas.
static func opaque_segments(segments: Array) -> Array:
	var lit: Array = []
	for entry: Variant in segments:
		var segment: Dictionary = (entry as Dictionary).duplicate()
		if segment.get("color") is Color:
			var tone: Color = segment["color"]
			segment["color"] = Color(tone.r, tone.g, tone.b, 1.0)
		lit.append(segment)
	return lit


## The flat lilac wash + 2px left rule every variable row wears. Flat is the shipped look: the wash
## draws as one rectangle unless the theme states a different right-edge colour, and only then does
## it become a two-triangle fade across the row.
func _draw_variable_row_wash(control: Control, row_rect: Rect2, reading: EventSheetReadingStyle) -> void:
	var wash: Color = reading.variable_row_wash_color
	var wash_end: Color = reading.variable_row_wash_end_color
	if wash_end == wash:
		control.draw_rect(row_rect, wash, true)
	else:
		control.draw_polygon(
			PackedVector2Array([
				row_rect.position,
				Vector2(row_rect.end.x, row_rect.position.y),
				row_rect.end,
				Vector2(row_rect.position.x, row_rect.end.y),
			]),
			PackedColorArray([wash, wash_end, wash_end, wash])
		)
	control.draw_rect(
		Rect2(row_rect.position, Vector2(VARIABLE_ROW_RULE_WIDTH, row_rect.size.y)),
		reading.variable_row_rule_color,
		true
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
	if badge_style == "glyph":
		# A MARK, not a chip: the small cue that says ONE fact about the row (this variable is
		# editable in the Inspector). No plate and no word - the hover carries the sentence. Falls
		# through to the plain text draw below if the mark has no art.
		var mark_side: float = min(badge_rect.size.x, badge_rect.size.y) * 0.95
		# A row may hand the slot a real texture instead (a group head's folder, which is the
		# editor's own Folder icon): drawn untinted, the way the icon was designed.
		var supplied_mark: Variant = metadata.get("badge_icon")
		if supplied_mark is Texture2D:
			control.draw_texture_rect(
				supplied_mark as Texture2D,
				Rect2(badge_rect.get_center() - Vector2(mark_side, mark_side) * 0.5, Vector2(mark_side, mark_side)),
				false
			)
			return
		var mark: Texture2D = _badge_icon(span.text, int(round(mark_side)))
		if mark != null:
			control.draw_texture_rect(
				mark,
				Rect2(badge_rect.get_center() - Vector2(mark_side, mark_side) * 0.5, Vector2(mark_side, mark_side)),
				false,
				badge_fg
			)
			return
	elif badge_style == "outline":
		# The kind cue a variable row leads with: an outlined box around one glyph, so the badge
		# column reads as a column without the weight of a filled chip on every declaration. A
		# region's `#` asks for the same box DASHED - the script editor's fold mark, and the same
		# stroke its body wears - so the two cues read as one idea.
		if bool(metadata.get("badge_dashed", false)):
			_draw_dashed_outline(control, badge_rect, badge_fg)
		else:
			var outline := StyleBoxFlat.new()
			outline.bg_color = Color(badge_bg.r, badge_bg.g, badge_bg.b, badge_bg.a * 0.35)
			outline.border_color = badge_fg
			outline.set_border_width_all(1)
			outline.set_corner_radius_all(int(metadata.get("corner_radius", 4)))
			outline.set_content_margin_all(0)
			control.draw_style_box(outline, badge_rect)
	elif badge_style in ["trigger", "negated"]:
		var radius: float = min(badge_rect.size.x, badge_rect.size.y) * 0.45
		control.draw_circle(badge_rect.get_center(), radius, badge_bg, true, -1.0, true)
		# Badge marks are SVG art rasterized at the EXACT pixel size this badge draws at (cached
		# per size), so every zoom and HiDPI scale gets a designed, pixel-crisp icon - no texture
		# files, no import-time resolution to outgrow. The primitive draws below remain as the
		# fallback if the rasterizer ever refuses a string.
		if badge_style == "trigger":
			var icon_side: float = radius * 1.9
			# A row can supply a real texture for the badge slot (the Class setup strip passes
			# the editor's own icon for the base class); the SVG marks below are the default.
			var supplied_icon: Variant = metadata.get("badge_icon")
			if supplied_icon is Texture2D:
				var supplied_rect := Rect2(badge_rect.get_center() - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
				control.draw_texture_rect(supplied_icon, supplied_rect, false)
				return
			var icon: Texture2D = _badge_icon(span.text, int(round(icon_side)))
			if icon != null:
				var icon_rect := Rect2(badge_rect.get_center() - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
				control.draw_texture_rect(icon, icon_rect, false, badge_fg)
				return
			if _draw_tempo_glyph(control, badge_rect.get_center(), radius, span.text, badge_fg):
				return
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


## The badge marks as SVG, keyed by the glyph char the tempo classifier picked (⟳ every tick,
## ▶ once, ⌨ input, ➜ signal, ◆ state). White art on a 24-unit canvas; the draw call tints it
## with the badge's foreground color, so one SVG serves every theme.
const BADGE_MARK_SVGS: Dictionary = {
	"⟳": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M18.9 12a6.9 6.9 0 1 1-2.02-4.88\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.7\" stroke-linecap=\"round\"/><path d=\"M17.8 2.6 L18.6 8.6 L12.6 7.8 Z\" fill=\"#fff\"/></svg>",
	"▶": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M8.2 5.2 L19 12 L8.2 18.8 Z\" fill=\"#fff\"/></svg>",
	"➜": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M4 12h10.4\" stroke=\"#fff\" stroke-width=\"2.8\" stroke-linecap=\"round\"/><path d=\"M12.6 6.4 L20.2 12 L12.6 17.6 Z\" fill=\"#fff\"/></svg>",
	"⌨": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><rect x=\"4\" y=\"7\" width=\"16\" height=\"10\" rx=\"2.6\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.2\"/><circle cx=\"12\" cy=\"12\" r=\"1.7\" fill=\"#fff\"/></svg>",
	"◆": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M12 4.2 L19.8 12 L12 19.8 L4.2 12 Z\" fill=\"#fff\"/></svg>",
	"ƒ": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M15.8 4.4c-2.1-.3-3.5.7-3.9 2.9l-.5 2.7H8.6v2.2h2.4l-1.1 6c-.2 1.2-.8 1.6-2.1 1.4v2c2.6.4 4.2-.7 4.6-3.2l1.1-6.2h2.9V10h-2.5l.4-2.3c.2-1 .7-1.3 1.9-1.1z\" fill=\"#fff\"/></svg>",
	"≡": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M5 7.5h14M5 12h14M5 16.5h10\" stroke=\"#fff\" stroke-width=\"2.4\" stroke-linecap=\"round\"/></svg>",
	"▣": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><rect x=\"4.5\" y=\"4.5\" width=\"15\" height=\"15\" rx=\"3\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.2\"/><rect x=\"9.4\" y=\"9.4\" width=\"5.2\" height=\"5.2\" rx=\"1\" fill=\"#fff\"/></svg>",
	# The sliders mark: a variable a designer can edit in the Inspector wears this instead of a word.
	"⚙": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M3.6 8.4h16.8M3.6 15.6h16.8\" stroke=\"#fff\" stroke-width=\"2.1\" stroke-linecap=\"round\"/><circle cx=\"8.8\" cy=\"8.4\" r=\"2.9\" fill=\"#fff\"/><circle cx=\"15.6\" cy=\"15.6\" r=\"2.9\" fill=\"#fff\"/></svg>",
	# The switch a head band wears for a line that is either written or not (`@tool`): a track with
	# its knob at the right when the line is there, at the left and hollow when it is not.
	"◍": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><rect x=\"2.4\" y=\"7.2\" width=\"19.2\" height=\"9.6\" rx=\"4.8\" fill=\"#fff\"/><circle cx=\"16.8\" cy=\"12\" r=\"3.1\" fill=\"#000\" fill-opacity=\"0.55\"/></svg>",
	"◌": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><rect x=\"3.5\" y=\"8.3\" width=\"17\" height=\"7.4\" rx=\"3.7\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2\"/><circle cx=\"7.9\" cy=\"12\" r=\"2.4\" fill=\"#fff\"/></svg>",
	# G2 - the ring a group head wears BEFORE its switch: this switch can be thrown while the game
	# runs, by Set group active. A plain ring, so it qualifies the switch instead of competing with it.
	"◎": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"7.6\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2\"/><circle cx=\"12\" cy=\"12\" r=\"2.6\" fill=\"#fff\"/></svg>",
	# G1 - the folder a group head leads with when the editor's own Folder texture is unavailable
	# (headless, or object icons turned off): a tab and a body, the file-manager idiom.
	"▤": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M3.2 6.6a1.6 1.6 0 0 1 1.6-1.6h4.1l1.9 2.2h7.4a1.6 1.6 0 0 1 1.6 1.6v9.2a1.6 1.6 0 0 1-1.6 1.6H4.8a1.6 1.6 0 0 1-1.6-1.6z\" fill=\"#fff\"/></svg>",
}

## SVG textures rasterized per (glyph, pixel size) - a handful of tiny images per session.
static var _badge_icon_cache: Dictionary = {}


## The badge mark for `glyph` rasterized at exactly `side_px`, or null when the glyph has no SVG
## (or the rasterizer refuses it - the caller falls back to the primitive draws).
static func _badge_icon(glyph: String, side_px: int) -> Texture2D:
	if side_px < 2 or not BADGE_MARK_SVGS.has(glyph):
		return null
	var cache_key: String = "%s|%d" % [glyph, side_px]
	if _badge_icon_cache.has(cache_key):
		return _badge_icon_cache[cache_key]
	var image: Image = Image.new()
	if image.load_svg_from_string(str(BADGE_MARK_SVGS[glyph]), float(side_px) / 24.0) != OK:
		_badge_icon_cache[cache_key] = null
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_badge_icon_cache[cache_key] = texture
	return texture


## Vector art for the tempo badge glyphs, keyed by the glyph char the tempo classifier picked
## (⟳ every tick, ▶ once, ⌨ input, ➜ signal). Antialiased primitives scaled to the badge
## radius, so every size and font renders the same crisp mark. Returns false for unknown
## glyphs - the caller then draws the text as before.
func _draw_tempo_glyph(control: Control, center: Vector2, radius: float, glyph: String, color: Color) -> bool:
	match glyph:
		"⟳":
			# Refresh loop: a 300-degree arc with a tangential arrowhead closing the circle.
			var arc_radius: float = radius * 0.58
			var line_width: float = maxf(radius * 0.22, 1.2)
			var start_angle: float = -PI * 0.30
			var end_angle: float = start_angle + PI * 1.66
			control.draw_arc(center, arc_radius, start_angle, end_angle, 20, color, line_width, true)
			var tip_angle: float = end_angle
			var tip_base: Vector2 = center + Vector2(cos(tip_angle), sin(tip_angle)) * arc_radius
			var tangent: Vector2 = Vector2(-sin(tip_angle), cos(tip_angle))
			var outward: Vector2 = Vector2(cos(tip_angle), sin(tip_angle))
			var head_length: float = radius * 0.52
			var head_width: float = radius * 0.34
			control.draw_colored_polygon(PackedVector2Array([
				tip_base + tangent * head_length,
				tip_base + outward * head_width,
				tip_base - outward * head_width,
			]), color)
			return true
		"▶":
			# Play triangle, optically centred (nudged right so the mass sits in the middle).
			var half_height: float = radius * 0.52
			var left_x: float = center.x - radius * 0.34
			control.draw_colored_polygon(PackedVector2Array([
				Vector2(left_x, center.y - half_height),
				Vector2(center.x + radius * 0.56, center.y),
				Vector2(left_x, center.y + half_height),
			]), color)
			return true
		"➜":
			# Straight arrow: shaft + head, the "a signal fired" mark.
			var shaft_left: Vector2 = center + Vector2(-radius * 0.52, 0.0)
			var head_base_x: float = center.x + radius * 0.10
			var line_width: float = maxf(radius * 0.24, 1.2)
			control.draw_line(shaft_left, Vector2(head_base_x + 1.0, center.y), color, line_width, true)
			control.draw_colored_polygon(PackedVector2Array([
				Vector2(center.x + radius * 0.62, center.y),
				Vector2(head_base_x, center.y - radius * 0.38),
				Vector2(head_base_x, center.y + radius * 0.38),
			]), color)
			return true
		"⌨":
			# Input key: a rounded keycap outline with a centred dot.
			var cap_width: float = radius * 1.15
			var cap_height: float = radius * 0.92
			var cap_rect := Rect2(center.x - cap_width * 0.5, center.y - cap_height * 0.5, cap_width, cap_height)
			control.draw_rect(cap_rect, color, false, maxf(radius * 0.18, 1.0), true)
			control.draw_circle(center, radius * 0.14, color)
			return true
		"◆":
			# State diamond: a rotated square, the "you are in this state" mark.
			var reach: float = radius * 0.62
			control.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -reach),
				center + Vector2(reach, 0.0),
				center + Vector2(0.0, reach),
				center + Vector2(-reach, 0.0),
			]), color)
			return true
	return false


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
