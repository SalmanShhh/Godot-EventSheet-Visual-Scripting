# Godot EventSheets - wrapped text takes its full height, the head bar's counts stay whole, and an Else
# is followed by an ordinary gap.
#
# Three faults in what a narrow sheet draws. A wrapped line of a note was counted by dividing the wrapped
# block's pixel height by the font's nominal line height, which undercounts when the shaped lines are
# shorter than that, so the row reserved a line too few and the last word landed on the next line's text.
# The head bar's counts were laid out to the canvas (never narrower than 640 px) instead of the width the
# reader can see, so a narrow dock cut a count in the middle of a word. And the Else chip reserved a floor
# of padding its look does not draw, which showed as a wide gap before the line's note.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "wrapped_text_spacing_test"
const PATH := "res://addons/eventforge/importer/variable_parser.gd"
const SENTENCE := "the quick brown fox jumps over the lazy dog and keeps running far away"


static func run() -> bool:
	var ok: bool = true
	ok = _line_starts() and ok
	ok = _note_rows() and ok
	ok = _head_counts() and ok
	ok = _else_chip() and ok
	return ok


## The ONE wrapping a plain cell or note is counted and drawn with.
static func _line_starts() -> bool:
	var ok: bool = true
	var font: Font = ThemeDB.fallback_font
	var size: int = 12
	var full: float = font.get_string_size(SENTENCE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	ok = SUPPORT.check(P, "text that fits starts one line", EventSheetViewportRowMetrics.wrap_line_starts(SENTENCE, full + 1.0, font, size), PackedInt32Array([0])) and ok
	var width: float = full * 0.4
	var starts: PackedInt32Array = EventSheetViewportRowMetrics.wrap_line_starts(SENTENCE, width, font, size)
	ok = SUPPORT.check(P, "text wider than its room wraps", starts.size() > 1, true) and ok
	ok = SUPPORT.check(P, "the first line starts at the first character", starts[0], 0) and ok
	ok = SUPPORT.check(P, "the count is the number of lines", EventSheetViewportRowMetrics.wrapped_line_count(SENTENCE, width, font, size), starts.size()) and ok
	var rebuilt: String = ""
	var widest: float = 0.0
	for line: int in range(starts.size()):
		var to: int = starts[line + 1] if line + 1 < starts.size() else SENTENCE.length()
		var piece: String = SENTENCE.substr(starts[line], to - starts[line])
		rebuilt += piece
		widest = maxf(widest, font.get_string_size(piece.strip_edges(false, true), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x)
	ok = SUPPORT.check(P, "the lines together are the text", rebuilt, SENTENCE) and ok
	ok = SUPPORT.check(P, "no line is wider than the room", widest <= width + 0.5, true) and ok
	ok = SUPPORT.check(P, "a line never starts inside a word", _starts_on_words(SENTENCE, starts), true) and ok
	return ok


static func _starts_on_words(text: String, starts: PackedInt32Array) -> bool:
	for index: int in range(1, starts.size()):
		if text[starts[index] - 1] != " ":
			return false
	return true


## A wrapped note's lines stack at a full line each and never run into the line below.
static func _note_rows() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(PATH), true, PATH)
	sheet.external_source_path = PATH
	sheet.read_only = true
	for width: float in [1000.0, 800.0, 640.0]:
		var view := EventSheetViewport.new()
		view.set_ace_registry(EventSheetACERegistry.new())
		view.size = Vector2(width, 900.0)
		view.set_sheet(sheet)
		var font: Font = view._get_font()
		var font_size: int = view._get_font_size()
		var line_height: float = view._get_event_line_height(font_size)
		view._row_metrics_helper.rebuild()
		var checked: int = 0
		var overlapping: int = 0
		var short_of_lines: int = 0
		var stacked_wrong: int = 0
		for index: int in range(view.get_flat_rows().size()):
			var row_data: EventRowData = view._row_at(index)
			if row_data == null or row_data.row_type != EventRowData.RowType.COMMENT:
				continue
			view.get_row_layout_for_test(index)
			var previous_bottom: float = -1.0e9
			var last_bottom: float = 0.0
			for span: EventSheetSemanticSpan in row_data.spans:
				if not EventSheetViewportLayoutBuilder._is_comment_text_span(span) or span.rect.size.x <= 0.0:
					continue
				checked += 1
				var reserved: int = int(round((span.rect.size.y + 6.0) / line_height))
				var drawn: int = EventSheetViewportRowMetrics.wrapped_line_count(span.text, span.rect.size.x - 2.0, font, font_size)
				if drawn > reserved:
					short_of_lines += 1
				if span.rect.position.y < previous_bottom - 0.5:
					overlapping += 1
				previous_bottom = span.rect.end.y
				last_bottom = maxf(last_bottom, span.rect.end.y)
			if last_bottom > view._row_metrics_helper.row_top(index) + view._row_metrics_helper.row_height(index):
				stacked_wrong += 1
		ok = SUPPORT.check(P, "at %d px the notes were looked at" % int(width), checked > 3, true) and ok
		ok = SUPPORT.check(P, "at %d px every note line has a line of room for each line it wraps to" % int(width), short_of_lines, 0) and ok
		ok = SUPPORT.check(P, "at %d px no note line starts inside the one above" % int(width), overlapping, 0) and ok
		ok = SUPPORT.check(P, "at %d px a note's lines end inside its row" % int(width), stacked_wrong, 0) and ok
		view.free()
	return ok


## The head bar's counts are laid out to the width the reader can see, and are whole or left out.
static func _head_counts() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(PATH), true, PATH)
	sheet.external_source_path = PATH
	sheet.read_only = true
	for width: float in [600.0, 520.0, 420.0, 300.0]:
		# The viewport sits in the scrolling window the dock gives it: the window is the dock's width while the
		# canvas inside it is never narrower than its floor.
		var scroll := ScrollContainer.new()
		scroll.size = Vector2(width, 900.0)
		var view := EventSheetViewport.new()
		view.set_ace_registry(EventSheetACERegistry.new())
		scroll.add_child(view)
		view.set_sheet(sheet)
		view._layout_builder.get_or_build_row_layout(0, view.get_canvas_logical_width(), view._get_font(), view._get_font_size())
		var head: EventRowData = view._row_at(0)
		var visible: float = view.get_visible_content_width()
		var cut: int = 0
		var unmarked: int = 0
		var counted: int = 0
		for span: EventSheetSemanticSpan in head.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if not bool(metadata.get("align_right", false)):
				continue
			if span.rect.size.x <= 0.0:
				if not bool(metadata.get("no_room", false)):
					unmarked += 1
				continue
			counted += 1
			if span.rect.end.x > visible:
				cut += 1
		ok = SUPPORT.check(P, "at %d px the rows are laid out to the visible width, down to the layout floor" % int(width), [view.get_canvas_logical_width() >= EventSheetViewport.LAYOUT_WIDTH_FLOOR and view.get_canvas_logical_width() <= maxf(width, EventSheetViewport.LAYOUT_WIDTH_FLOOR) + 0.5, visible], [true, width]) and ok
		ok = SUPPORT.check(P, "at %d px no count reaches past the visible edge" % int(width), cut, 0) and ok
		ok = SUPPORT.check(P, "at %d px a count that is not drawn says so" % int(width), unmarked, 0) and ok
		if width >= 520.0:
			ok = SUPPORT.check(P, "at %d px the counts still fit and are drawn" % int(width), counted > 0, true) and ok
		scroll.free()
	return ok


## The Else word is measured with the padding its look states and no floor beyond it.
static func _else_chip() -> bool:
	var ok: bool = true
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	var font: Font = view._get_font()
	var font_size: int = view._get_font_size()
	var word_width: float = font.get_string_size("Else", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var else_span: EventSheetSemanticSpan = EventSheetSemanticSpan.new()
	else_span.text = "Else"
	else_span.metadata = {"kind": "else_keyword", "chip": true, "padding_x": 0.0}
	ok = SUPPORT.check(P, "an Else chip with no padding of its look has no blank beside its word", view._row_builder._measure_span_width(else_span, "Else", font, font_size), word_width) and ok
	else_span.metadata = {"kind": "else_keyword", "chip": true, "padding_x": 8.0}
	ok = SUPPORT.check(P, "an Else chip keeps the padding its look states", view._row_builder._measure_span_width(else_span, "Else", font, font_size), word_width + 16.0) and ok
	var other: EventSheetSemanticSpan = EventSheetSemanticSpan.new()
	other.text = "Else"
	other.metadata = {"kind": "condition", "chip": true, "padding_x": 0.0}
	ok = SUPPORT.check(P, "any other chip keeps its floor", view._row_builder._measure_span_width(other, "Else", font, font_size), word_width + view.CHIP_EXTRA_WIDTH) and ok
	view.free()
	return ok
