# Godot EventSheets - a row's lines each hold something, and a sentence is never cut or broken.
#
# Three leftovers of how an opened script's rows were laid out in a narrow dock:
#   - a row reserved a blank line under a wrapped condition, only because an action stood on the second
#     logical line of the other lane (an empty band the height of a chip line, with nothing in it);
#   - a match arm's captured name stood beside its sentence even when that sentence had to wrap to leave
#     the name room, so it landed in the middle ("event [other]" and "is text" on the next line);
#   - a function's head ("On function _append_condition_entry") was cut at the cell's edge with no
#     ellipsis and no wrap, while the row had room to grow downward.
# Each is measured on the layout a real viewport makes at several dock widths.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NARROW := preload("res://tests/narrow_row_cells_test.gd")
const P := "row_lines_hold_something_test"


static func run() -> bool:
	var ok: bool = true
	for width: float in [640.0, 700.0, 800.0, 900.0, 996.0, 1100.0]:
		ok = _no_empty_band(width) and ok
		ok = _binding_after_the_whole_sentence(width) and ok
	for width: float in [480.0, 560.0, 640.0, 700.0, 800.0, 996.0]:
		ok = _function_head_is_whole(width) and ok
	return ok


## The lowest edge of any cell the row draws, the row's bottom, and one line's height.
static func _lowest_cell_gap(view: EventSheetViewport, index: int, row_data: EventRowData) -> float:
	var lowest: float = -INF
	for span: EventSheetSemanticSpan in row_data.spans:
		if span.rect.size.x > 0.0 and span.rect.size.y > 0.0:
			lowest = maxf(lowest, span.rect.end.y)
	var bottom: float = view._row_metrics_helper.row_top(index) + view._row_metrics_helper.row_height(index)
	return bottom - lowest


static func _no_empty_band(width: float) -> bool:
	var made: Array = NARROW._laid_out(NARROW.UNDO_STEP, width)
	var view: EventSheetViewport = made[1]
	var line_height: float = view._get_event_line_height(view._get_font_size())
	var arms: int = 0
	var empty: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		var is_arm: bool = false
		for span: EventSheetSemanticSpan in row_data.spans:
			if span.text.begins_with("mode ="):
				is_arm = true
		if not is_arm:
			continue
		arms += 1
		# Under the lowest cell there may be the row's own padding, never a whole line.
		if _lowest_cell_gap(view, index, row_data) > line_height * 0.75:
			empty += 1
	var ok: bool = SUPPORT.check(P, "at %d px both arms of the undo funnel were laid out" % int(width), arms, 2)
	ok = SUPPORT.check(P, "at %d px no row reserves a line that holds nothing" % int(width), empty, 0) and ok
	made[0].free()
	return ok


static func _binding_after_the_whole_sentence(width: float) -> bool:
	var made: Array = NARROW._laid_out(NARROW.PATTERNS, width)
	var view: EventSheetViewport = made[1]
	var line_height: float = view._get_event_line_height(view._get_font_size())
	var bindings: int = 0
	var inside: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		for chip: EventSheetSemanticSpan in row_data.spans:
			var chip_metadata: Dictionary = chip.metadata as Dictionary
			if str(chip_metadata.get("kind", "")) != "match_binding" or chip.rect.size.x <= 0.0:
				continue
			bindings += 1
			for cell: EventSheetSemanticSpan in row_data.spans:
				var cell_metadata: Dictionary = cell.metadata as Dictionary
				if str(cell_metadata.get("kind", "")) != "match_pattern" or int(cell_metadata.get("line_index", 0)) != int(chip_metadata.get("line_index", 0)):
					continue
				# A sentence of several lines has the name after it, never on a line the sentence is still using.
				if cell.rect.size.y > line_height * 1.5 and chip.rect.position.y < cell.rect.end.y - 1.0:
					inside += 1
	var ok: bool = SUPPORT.check(P, "at %d px the match arms' names were laid out" % int(width), bindings > 1, true)
	ok = SUPPORT.check(P, "at %d px no captured name stands inside a sentence that wraps" % int(width), inside, 0) and ok
	made[0].free()
	return ok


static func _function_head_is_whole(width: float) -> bool:
	var made: Array = NARROW._laid_out(NARROW.UNDO_STEP, width)
	var view: EventSheetViewport = made[1]
	var font: Font = view._get_font()
	var font_size: int = view._get_font_size()
	var line_height: float = view._get_event_line_height(font_size)
	var heads: int = 0
	var cut: int = 0
	var tall_but_whole: int = 0
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
			continue
		for span: EventSheetSemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata as Dictionary
			if str(metadata.get("kind", "")) != "define_function" or not span.text.begins_with("On function") or span.rect.size.x <= 0.0:
				continue
			heads += 1
			var room: float = view._row_metrics_helper._fill_text_wrap_width(metadata, span.rect.size.x, font, font_size,
				float(metadata.get("object_column_px", -1.0)))
			var drawn_whole: bool = font.get_string_size(span.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= room + 0.5
			if not drawn_whole and not bool(metadata.get("comment_wrap", false)):
				cut += 1
			# A head that fits keeps its one line.
			if drawn_whole and span.rect.size.y > line_height * 1.5:
				tall_but_whole += 1
	var ok: bool = SUPPORT.check(P, "at %d px the function heads were laid out" % int(width), heads, 4)
	ok = SUPPORT.check(P, "at %d px no function head is cut at the cell's edge" % int(width), cut, 0) and ok
	ok = SUPPORT.check(P, "at %d px a head that fits stays one line" % int(width), tall_but_whole, 0) and ok
	made[0].free()
	return ok
