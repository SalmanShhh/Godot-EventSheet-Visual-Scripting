# Godot EventSheets - a row built lazily is drawn at the height its words need, not at the guess.
#
# Rows past the first screenful get their words when they come into view, and until then their height
# is a guess from the line count, which knows nothing of a cell that wraps or of the add lines a
# resting or inert row hides. Drawn into the guess, a wrapped cell spilled into the row below (a
# real editor at 760 px showed it on the fps controller pack: "capture_mouse_on_re" cut off, a long
# action clipped mid-sentence). Measured headless on the same pack at a 640 px canvas: 65 of the 74
# lazy event rows had a guessed height that was not their built one.
#
# Pinned:
#   * the guess really is wrong for rows of this pack (so the rest is not vacuous);
#   * the rows a draw is about to paint are measured again with their words, and the rows below move
#     by exactly what they gained, so no row overlaps the next;
#   * every change of the tops moves the layout's generation, so the margin brackets held for a draw
#     are worked out again (a hover that re-measured a row under an add-lines-on-hover look moved the
#     tops without it, and the brackets went on being drawn at the old ones);
#   * once the idle walk has built every row's words, the patterns the sheet claims are the ones a
#     full build claims, and every row's height is its built one;
#   * the hover's other-uses highlight, the spoken name of a row and Copy as text's lookup read built
#     words without building the whole sheet.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "lazy_row_heights_test"
const SAMPLE_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
const CANVAS: Vector2 = Vector2(520.0, 700.0)


static func run() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SAMPLE_PACK, false)
	if sheet == null:
		return SUPPORT.check(P, "the sample pack imports", false, true)
	EventSheetACELifter.attempt_lift(sheet, FileAccess.get_file_as_string(SAMPLE_PACK))
	var viewport: EventSheetViewport = _view(sheet)
	var rows: int = viewport.get_total_row_count()

	# 1. The guess is wrong somewhere below the first screenful.
	var guessed_wrong: int = 0
	var lazy_rows: Array[int] = []
	for index: int in range(rows):
		var row: EventRowData = viewport._row_at(index)
		if row == null or row.row_type != EventRowData.RowType.EVENT or not row.spans.is_empty():
			continue
		lazy_rows.append(index)
	var probe: EventSheetViewport = _view(sheet)
	for index: int in lazy_rows:
		var row: EventRowData = probe._row_at(index)
		var guessed: float = probe._row_metrics_helper.row_height(index)
		probe._row_builder._ensure_event_spans(row)
		if not is_equal_approx(guessed, probe._row_metrics_helper._resolve_row_height(row)):
			guessed_wrong += 1
	probe.free()
	passed = SUPPORT.check(P, "some lazy rows' guessed height is not their built one (%d of %d)" % [guessed_wrong, lazy_rows.size()],
		guessed_wrong > 0, true) and passed

	# 2. A window far down the sheet, settled the way a draw settles it.
	var from: int = lazy_rows[lazy_rows.size() / 2] if not lazy_rows.is_empty() else 0
	var to: int = mini(from + 30, rows - 1)
	var generation: int = viewport._row_metrics_helper.generation()
	viewport._settle_rows_in_view(Vector2i(from, to))
	var wrong: PackedStringArray = PackedStringArray()
	for index: int in range(from, to + 1):
		var row: EventRowData = viewport._row_at(index)
		if row == null or row.row_type != EventRowData.RowType.EVENT:
			continue
		var reserved: float = viewport._row_metrics_helper.row_height(index)
		var needed: float = viewport._row_metrics_helper._resolve_row_height(row)
		if not is_equal_approx(reserved, needed):
			wrong.append("row %d reserved %.0f needs %.0f" % [index, reserved, needed])
	passed = SUPPORT.check(P, "every row a draw paints is as tall as its words need %s" % str(wrong.slice(0, 3)), wrong.size(), 0) and passed
	passed = SUPPORT.check(P, "no row overlaps the one below it", _overlaps(viewport, 0, rows - 1), PackedStringArray()) and passed
	passed = SUPPORT.check(P, "and the layout's generation moved, so held bracket strokes are worked out again",
		viewport._row_metrics_helper.generation() > generation, true) and passed
	var held: Array = viewport.group_bracket_strokes(CANVAS.x)
	passed = SUPPORT.check(P, "the brackets drawn after it are the brackets of the new tops",
		str(held) == str(viewport._compute_group_bracket_strokes(CANVAS.x)), true) and passed

	# 3. A hover re-measure that moves the tops moves the generation too.
	var hover_row: int = to
	var metrics: Array = viewport._row_metrics_helper._row_metrics
	(metrics[hover_row] as Dictionary)["open"] = not bool((metrics[hover_row] as Dictionary).get("open", false))
	(metrics[hover_row] as Dictionary)["height"] = 1.0
	generation = viewport._row_metrics_helper.generation()
	var moved: bool = viewport._row_metrics_helper.remeasure_open_rows()
	passed = SUPPORT.check(P, "a hover re-measure that moves the tops moves the generation",
		[moved, viewport._row_metrics_helper.generation() > generation], [true, true]) and passed

	# 4. The lookups that read only some rows build only those.
	viewport.set_sheet(sheet)
	var far: int = _last_lazy_event(viewport)
	if far >= 0:
		var far_row: EventRowData = viewport._row_at(far)
		var found: Dictionary = viewport.rows_for_resources([far_row.source_resource])
		passed = SUPPORT.check(P, "finding the rows of a selection builds no words of the rest of the sheet",
			_built_events(viewport) < _event_count(viewport), true) and passed
		passed = SUPPORT.check(P, "and finds the row", (found.get("rows", []) as Array).has(far_row), true) and passed
	var parent: int = _lazy_event_with_lazy_child(viewport)
	if parent >= 0:
		var spoken: String = viewport.accessible_name_for_row(parent)
		var parent_row: EventRowData = viewport._row_at(parent)
		var child_built: bool = true
		for child: EventRowData in parent_row.children:
			if child.row_type == EventRowData.RowType.EVENT and child.spans.is_empty() and child.source_resource is EventRow:
				child_built = false
		passed = SUPPORT.check(P, "a row's spoken name is read with the words of the events under it",
			[spoken.is_empty(), child_built], [false, true]) and passed

	# 5. The idle walk: every row's words, the whole sheet's patterns, every row at its built height.
	viewport.set_sheet(sheet)
	EventSheetViewportReadingRows.ensure_claims(sheet)
	var lazy_patterns: int = EventSheetPatternFacts.claims(sheet).size()
	var filler: RefCounted = viewport._word_filler
	passed = SUPPORT.check(P, "a fresh build leaves rows for the idle walk", filler.is_done(), false) and passed
	var guard: int = 0
	while not filler.is_done() and guard < 10000:
		filler.pump(2000)
		guard += 1
	passed = SUPPORT.check(P, "the idle walk finishes", filler.is_done(), true) and passed
	var walked_built: int = _built_events(viewport)
	viewport.get_row_tree()
	passed = SUPPORT.check(P, "and leaves nothing for a full build to add (%d of %d events have words to build)" % [walked_built, _event_count(viewport)],
		walked_built, _built_events(viewport)) and passed
	var walked_patterns: int = EventSheetPatternFacts.claims(sheet).size()
	var full: EventSheetViewport = _view(sheet)
	full.get_row_tree()
	passed = SUPPORT.check(P, "the patterns claimed after the walk are a full build's (%d before it)" % lazy_patterns,
		walked_patterns, EventSheetPatternFacts.claims(sheet).size()) and passed
	full.free()
	viewport.set_sheet(sheet)
	while not filler.is_done():
		filler.pump(2000)
	var off: int = 0
	for index: int in range(viewport.get_total_row_count()):
		var row: EventRowData = viewport._row_at(index)
		if row != null and row.row_type == EventRowData.RowType.EVENT \
				and not is_equal_approx(viewport._row_metrics_helper.row_height(index), viewport._row_metrics_helper._resolve_row_height(row)):
			off += 1
	passed = SUPPORT.check(P, "after the walk every row is at its built height", off, 0) and passed
	passed = SUPPORT.check(P, "and no row overlaps the next", _overlaps(viewport, 0, viewport.get_total_row_count() - 1), PackedStringArray()) and passed
	viewport.free()
	return passed


static func _view(sheet: EventSheetResource) -> EventSheetViewport:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_preset(Control.PRESET_TOP_LEFT)
	viewport.size = CANVAS
	viewport.set_sheet(sheet)
	return viewport


static func _overlaps(viewport: EventSheetViewport, from: int, to: int) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for index: int in range(from, to):
		var bottom: float = viewport._row_metrics_helper.row_top(index) + viewport._row_metrics_helper.row_height(index)
		if viewport._row_metrics_helper.row_top(index + 1) < bottom - 0.01:
			found.append("row %d ends at %.0f, row %d starts at %.0f" % [index, bottom, index + 1, viewport._row_metrics_helper.row_top(index + 1)])
	return found.slice(0, 3)


static func _last_lazy_event(viewport: EventSheetViewport) -> int:
	for index: int in range(viewport.get_total_row_count() - 1, -1, -1):
		var row: EventRowData = viewport._row_at(index)
		if row != null and row.row_type == EventRowData.RowType.EVENT and row.spans.is_empty() and row.source_resource is EventRow:
			return index
	return -1


static func _lazy_event_with_lazy_child(viewport: EventSheetViewport) -> int:
	for index: int in range(viewport.get_total_row_count() - 1, -1, -1):
		var row: EventRowData = viewport._row_at(index)
		if row == null or row.row_type != EventRowData.RowType.EVENT or not row.spans.is_empty():
			continue
		for child: EventRowData in row.children:
			if child.row_type == EventRowData.RowType.EVENT and child.spans.is_empty() and child.source_resource is EventRow:
				return index
	return -1


static func _event_count(viewport: EventSheetViewport) -> int:
	var count: int = 0
	for row: EventRowData in _all_rows(viewport):
		if row.row_type == EventRowData.RowType.EVENT and (row.source_resource is EventRow or row.reading_resource is EventRow):
			count += 1
	return count


static func _built_events(viewport: EventSheetViewport) -> int:
	var count: int = 0
	for row: EventRowData in _all_rows(viewport):
		if row.row_type == EventRowData.RowType.EVENT and (row.source_resource is EventRow or row.reading_resource is EventRow) \
				and not row.spans.is_empty():
			count += 1
	return count


static func _all_rows(viewport: EventSheetViewport) -> Array[EventRowData]:
	var out: Array[EventRowData] = []
	for root: EventRowData in viewport._root_rows:
		_walk(root, out)
	return out


static func _walk(row: EventRowData, out: Array[EventRowData]) -> void:
	out.append(row)
	for child: EventRowData in row.children:
		_walk(child, out)
