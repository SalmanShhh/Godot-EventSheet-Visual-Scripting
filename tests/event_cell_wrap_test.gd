# Condition/action cells WRAP instead of clipping (the Construct rule): when a cell's text is
# wider than its lane, the row grows by whole visual lines and the renderer wraps the text.
# One shared walk (ViewportRowMetrics.event_line_extents) feeds BOTH the height metrics and the
# layout pass, so the reserved height and the drawn rects can never disagree. Pins:
#   1. A long condition in a wide lane stays one visual line; in a narrow lane it wraps (>1),
#      and the row total covers the taller lane.
#   2. The action lane wraps independently of the condition lane.
#   3. A styled (bbcode-segment) cell never wraps - segment wrapping is unsupported by design.
#   4. The layout pass stamps comment_wrap metadata on the wrapped span and grows its rect to
#      the visual-line count, with span tops following the cumulative lane tops.
@tool
class_name EventCellWrapTest
extends RefCounted


const LONG_TEXT: String = "only once ever ( \"first_flight_hint_shown_to_the_player\" ) across every run of the game"


static func run() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	var font: Font = ThemeDB.fallback_font
	var font_size: int = viewport._get_font_size()
	var metrics: ViewportRowMetrics = viewport._row_metrics_helper

	# A hand-built EVENT row: one long condition cell, one long action cell.
	var row_data: EventRowData = EventRowData.new()
	row_data.row_type = EventRowData.RowType.EVENT
	var cond_span: SemanticSpan = SemanticSpan.new()
	cond_span.text = LONG_TEXT
	cond_span.metadata = {"kind": "condition", "line_index": 0, "chip": true}
	var act_span: SemanticSpan = SemanticSpan.new()
	act_span.text = "Set the long_named_score_variable to long_named_score_variable + 100 points"
	act_span.metadata = {"kind": "action", "lane": "action", "line_index": 0, "chip": true}
	row_data.spans = [cond_span, act_span]

	# 1. Wide lane: everything fits on one visual line. Narrow lane: both lanes wrap.
	var wide: Dictionary = metrics.event_line_extents(row_data, 2200.0, font, font_size)
	ok = _check("wide canvas stays one visual line", int(wide.get("total", 0)), 1) and ok
	var narrow: Dictionary = metrics.event_line_extents(row_data, 520.0, font, font_size)
	var narrow_cond_lines: int = int((narrow.get("cond_count", {}) as Dictionary).get(0, 1))
	var narrow_act_lines: int = int((narrow.get("act_count", {}) as Dictionary).get(0, 1))
	ok = _check("narrow condition lane wraps", narrow_cond_lines > 1, true) and ok
	ok = _check("narrow action lane wraps", narrow_act_lines > 1, true) and ok
	ok = _check("row total covers the taller lane", int(narrow.get("total", 0)), maxi(narrow_cond_lines, narrow_act_lines)) and ok

	# 2. Lanes wrap independently: a short action next to a long condition stays one line.
	act_span.text = "Destroy"
	var lopsided: Dictionary = metrics.event_line_extents(row_data, 520.0, font, font_size)
	ok = _check("short action stays one line beside a wrapped condition", int((lopsided.get("act_count", {}) as Dictionary).get(0, 1)), 1) and ok
	ok = _check("lopsided total is the condition lane's", int(lopsided.get("total", 0)), int((lopsided.get("cond_count", {}) as Dictionary).get(0, 1))) and ok

	# 3. A styled cell (bbcode segments) wraps too, counted by the shared greedy break points.
	cond_span.metadata["bbcode_segments"] = [{"text": LONG_TEXT}]
	var styled: Dictionary = metrics.event_line_extents(row_data, 520.0, font, font_size)
	ok = _check("styled segments wrap too", int((styled.get("cond_count", {}) as Dictionary).get(0, 1)) > 1, true) and ok
	cond_span.metadata.erase("bbcode_segments")

	# 3b. The greedy break points themselves: one line when wide; when narrow, offsets are
	# strictly increasing and slicing at them reassembles the original text losslessly.
	ok = _check("break points: wide text is one line", ViewportRowMetrics.wrap_break_points(LONG_TEXT, 10000.0, font, font_size).size(), 1) and ok
	var breaks: PackedInt32Array = ViewportRowMetrics.wrap_break_points(LONG_TEXT, 150.0, font, font_size)
	ok = _check("break points: narrow text splits", breaks.size() > 1, true) and ok
	var monotonic: bool = true
	var rejoined: String = ""
	for break_index in range(breaks.size()):
		var slice_end: int = breaks[break_index + 1] if break_index + 1 < breaks.size() else LONG_TEXT.length()
		if slice_end <= breaks[break_index]:
			monotonic = false
		rejoined += LONG_TEXT.substr(breaks[break_index], slice_end - breaks[break_index])
	ok = _check("break points: strictly increasing", monotonic, true) and ok
	ok = _check("break points: slices reassemble the text", rejoined, LONG_TEXT) and ok
	ok = _check("break points: a giant word hard-splits instead of overflowing", ViewportRowMetrics.wrap_break_points("abcdefghijklmnopqrstuvwxyz_abcdefghijklmnopqrstuvwxyz", 60.0, font, font_size).size() > 1, true) and ok

	# 4. The layout pass agrees with the metrics: the wrapped span carries comment_wrap and a
	# rect spanning its visual lines. Feed the row through the REAL flat-row path at a narrow
	# size so layout and metrics see the same width.
	act_span.text = "Set the long_named_score_variable to long_named_score_variable + 100 points"
	viewport.size = Vector2(520.0, 400.0)
	viewport._flat_rows = [{"row": row_data}]
	viewport._rebuild_row_metrics()
	var line_height: float = viewport._get_event_line_height(font_size)
	var layout_width: float = viewport._get_logical_canvas_width()
	var expected: Dictionary = metrics.event_line_extents(row_data, layout_width, font, font_size)
	var expected_lines: int = int((expected.get("cond_count", {}) as Dictionary).get(0, 1))
	ok = _check("layout-width extents wrap too", expected_lines > 1, true) and ok
	ok = _check("row height reserves every visual line", viewport._get_row_height(0) >= float(int(expected.get("total", 1))) * line_height - 0.01, true) and ok
	viewport._layout_builder.get_or_build_row_layout(0, layout_width, font, font_size)
	ok = _check("layout stamps the wrap flag", bool((cond_span.metadata as Dictionary).get("comment_wrap", false)), true) and ok
	ok = _check("the condition rect spans its visual lines", int(roundf((cond_span.rect.size.y + 1.0) / line_height)), expected_lines) and ok

	# 5. A styled action cell gets segment_wrap_breaks stamped (not comment_wrap), and the
	# stamped break count matches the visual-line count the height reserved.
	act_span.metadata["bbcode_segments"] = [{"text": act_span.text, "bold": true}]
	viewport._layout_cache.clear()
	viewport._rebuild_row_metrics()
	viewport._layout_builder.get_or_build_row_layout(0, layout_width, font, font_size)
	var styled_extents: Dictionary = metrics.event_line_extents(row_data, layout_width, font, font_size)
	var styled_act_lines: int = int((styled_extents.get("act_count", {}) as Dictionary).get(0, 1))
	ok = _check("styled action wraps at layout width", styled_act_lines > 1, true) and ok
	var stamped: PackedInt32Array = (act_span.metadata as Dictionary).get("segment_wrap_breaks", PackedInt32Array())
	ok = _check("layout stamps segment break points", stamped.size(), styled_act_lines) and ok
	ok = _check("a styled cell never carries the plain wrap flag", bool((act_span.metadata as Dictionary).get("comment_wrap", false)), false) and ok

	viewport.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_cell_wrap_test: %s" % label)
		return true
	print("[FAIL] event_cell_wrap_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
