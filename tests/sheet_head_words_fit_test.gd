# Godot EventSheets - the words on the sheet's head bar never run over its counts.
#
# The head bar reads left to right: the name, what kind of script it is, then the notes and buttons the
# file earns, with the counts at the right edge. When the bar is too narrow for all of it, the words that
# come last give way - they are left out - before the counts lose any of their room. A word is either given
# room to read or not drawn at all; it is never squeezed into a sliver that draws over its neighbour.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "sheet_head_words_fit_test"
const PATH := "res://addons/eventforge/importer/variable_parser.gd"


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(PATH), true, PATH)
	sheet.external_source_path = PATH
	sheet.read_only = true
	for width: float in [1200.0, 900.0, 700.0, 600.0]:
		var view := EventSheetViewport.new()
		view.set_ace_registry(EventSheetACERegistry.new())
		view.size = Vector2(width, 900.0)
		view.set_sheet(sheet)
		view._layout_builder.get_or_build_row_layout(0, view.get_canvas_logical_width(), view._get_font(), view._get_font_size())
		var head: EventRowData = view._row_at(0)
		var counts_left: float = 1.0e9
		var drawn: Array[Rect2] = []
		var unmarked: int = 0
		for span: EventSheetSemanticSpan in head.spans:
			if span.rect.size.x <= 0.0:
				# A word left out says so, so the renderer does not draw it at the corner of the row.
				if not (span.metadata is Dictionary and bool((span.metadata as Dictionary).get("no_room", false))):
					unmarked += 1
				continue
			if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("align_right", false)):
				counts_left = minf(counts_left, span.rect.position.x)
			else:
				drawn.append(span.rect)
		var overlapping: int = 0
		var slivers: int = 0
		for rect: Rect2 in drawn:
			if rect.end.x > counts_left:
				overlapping += 1
			if rect.size.x < 10.0:
				slivers += 1
		ok = SUPPORT.check(P, "at %d px no word runs over the counts" % int(width), overlapping, 0) and ok
		ok = SUPPORT.check(P, "at %d px no word is a sliver" % int(width), slivers, 0) and ok
		ok = SUPPORT.check(P, "at %d px every word left out is marked as left out" % int(width), unmarked, 0) and ok
		ok = SUPPORT.check(P, "at %d px the counts are still there" % int(width), counts_left < 1.0e9, true) and ok
		view.free()
	return ok
