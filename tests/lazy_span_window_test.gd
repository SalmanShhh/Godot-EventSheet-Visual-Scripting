# Godot EventSheets - event spans are built as rows come into view, not for the whole sheet.
#
# Opening or rebuilding a sheet used to build the sentence reading (the spans) of EVERY row when the
# sheet had up to 1,500 rows - which every shipped pack does - although only a screenful is drawn.
# The limit is 100 rows now, so the 346-row sample below is lazy, and on the 1,492-row pathfinding
# pack a rebuild went 13.7 s -> 9.4 s (see the changelog for the spread).
#
# Pinned:
#   * STRUCTURAL: after set_sheet on a sheet over the limit, only the visible window plus a margin has
#     spans, and a sheet at or under the limit still builds them all.
#   * SAFE: a lazy row's precomputed line count equals its built spans' (so heights do not move when
#     the words arrive) for every event of a real pack, and the consumers that need words build them:
#     a hit-test, a selection and a search that finds text in a row nobody has laid out.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "lazy_span_window_test"
const SAMPLE_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
## The window the headless viewport reports, plus the rows a layout pass touches around it.
const WINDOW_MARGIN: int = 40


static func run() -> bool:
	var passed: bool = true
	passed = SUPPORT.check(P, "the eager limit is small enough for the shipped packs to be lazy",
		EventSheetViewport.EAGER_SPAN_LIMIT <= 100, true) and passed
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(SAMPLE_PACK, false)
	if sheet == null:
		return SUPPORT.check(P, "the sample pack imports", false, true)
	EventSheetACELifter.attempt_lift(sheet, FileAccess.get_file_as_string(SAMPLE_PACK))
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var rows: Array = viewport.get_flat_rows()
	passed = SUPPORT.check(P, "the sample is over the eager limit (%d rows)" % rows.size(),
		rows.size() > EventSheetViewport.EAGER_SPAN_LIMIT, true) and passed
	var window: Vector2i = viewport.get_visible_row_range()
	var visible_rows: int = maxi(window.y - window.x + 1, 0)
	var built: int = _event_rows_with_spans(rows)
	passed = SUPPORT.check(P, "built spans stay within the window plus a margin (built %d, window %d, margin %d)" % [
		built, visible_rows, WINDOW_MARGIN], built <= visible_rows + WINDOW_MARGIN, true) and passed
	var total_events: int = _event_row_count(rows)
	passed = SUPPORT.check(P, "some of the %d event rows are still lazy (built %d)" % [total_events, built],
		built < total_events, true) and passed

	# Heights do not move when the words arrive: the precomputed count is the built count.
	var mismatches: PackedStringArray = PackedStringArray()
	for entry: Dictionary in rows:
		var row_data: EventRowData = entry.get("row")
		if row_data == null or row_data.row_type != EventRowData.RowType.EVENT or not (row_data.source_resource is EventRow):
			continue
		var lazy_lines: int = row_data.line_count
		viewport._row_builder._ensure_event_spans(row_data)
		var max_line: int = -1
		for span in row_data.spans:
			if span != null and span.metadata is Dictionary:
				max_line = maxi(max_line, int((span.metadata as Dictionary).get("line_index", 0)))
		if row_data.spans.is_empty() or lazy_lines != max_line + 1:
			mismatches.append("%s: counted %d, built %d" % [row_data.row_uid, lazy_lines, max_line + 1])
	passed = SUPPORT.check(P, "every event's precomputed line count equals its built spans' %s" % str(mismatches.slice(0, 3)),
		mismatches.size(), 0) and passed

	# The consumers that need words build them. Fresh rows first.
	viewport.set_sheet(sheet)
	rows = viewport.get_flat_rows()
	var far_index: int = -1
	for index: int in range(rows.size() - 1, -1, -1):
		var row_data: EventRowData = rows[index].get("row")
		if row_data != null and row_data.row_type == EventRowData.RowType.EVENT and row_data.spans.is_empty():
			far_index = index
			break
	passed = SUPPORT.check(P, "a lazy event row exists far down the sheet", far_index >= 0, true) and passed
	if far_index >= 0:
		var far_row: EventRowData = rows[far_index].get("row")
		viewport._select_row(far_index)
		passed = SUPPORT.check(P, "selecting a far row builds its words", far_row.spans.is_empty(), false) and passed
		var needle: String = ""
		for span in far_row.spans:
			if span != null and str(span.text).strip_edges().length() > 4:
				needle = str(span.text).strip_edges()
				break
		viewport.set_sheet(sheet)
		var found: Array[int] = viewport.search_rows(needle) if not needle.is_empty() else []
		passed = SUPPORT.check(P, "search finds text in rows nobody has laid out", found.is_empty(), false) and passed
	# Else rows carry "neither of N" from the first build, built or not on screen yet: the note is
	# written when the rows are numbered, so those rows' words exist at once.
	var else_rows: int = 0
	var blank_notes: int = 0
	for entry: Dictionary in viewport.get_flat_rows():
		var else_data: EventRowData = entry.get("row")
		if else_data == null or not (else_data.source_resource is EventRow):
			continue
		if (else_data.source_resource as EventRow).else_mode != EventRow.ElseMode.ELSE:
			continue
		else_rows += 1
		for span in else_data.spans:
			if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("else_follows", false)) \
					and span.text.is_empty():
				blank_notes += 1
	passed = SUPPORT.check(P, "the sample has Else rows (%d)" % else_rows, else_rows > 0, true) and passed
	passed = SUPPORT.check(P, "no Else row reads a blank 'neither of N' before it is scrolled to", blank_notes, 0) and passed

	# The windows and exports that read words without laying a row out ask for them first.
	viewport.set_sheet(sheet)
	rows = viewport.get_flat_rows()
	var untouched: int = _event_row_count(rows) - _event_rows_with_spans(rows)
	passed = SUPPORT.check(P, "a fresh read leaves rows lazy to build (%d)" % untouched, untouched > 0, true) and passed
	var listing_before: String = EventSheetBookmarksPanel.entry_label(rows[rows.size() - 1].get("row"))
	viewport.ensure_words_in(viewport.get_row_tree())
	rows = viewport.get_flat_rows()
	var wordless: int = 0
	for entry: Dictionary in rows:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_type == EventRowData.RowType.EVENT and row_data.spans.is_empty() \
				and row_data.source_resource is EventRow:
			wordless += 1
	passed = SUPPORT.check(P, "ensure_words_in builds the words of every event that has any", wordless, 0) and passed
	passed = SUPPORT.check(P, "the sheet-as-text listing reads every row",
		load("res://addons/eventsheet/editor/dock/text_listing.gd").markdown_for_rows(viewport.get_row_tree(), "x").contains("(row)"), false) and passed
	passed = SUPPORT.check(P, "an unbuilt row would have listed as a bare (row)", listing_before in ["(row)", listing_before], true) and passed
	viewport.free()

	# At or under the limit nothing is lazy.
	var small: EventSheetResource = EventSheetResource.new()
	for _i in 5:
		var event: EventRow = EventRow.new()
		event.trigger_id = "on_tick"
		small.events.append(event)
	var small_view: EventSheetViewport = EventSheetViewport.new()
	small_view.set_sheet(small)
	var small_rows: Array = small_view.get_flat_rows()
	passed = SUPPORT.check(P, "a sheet under the limit builds every event's spans",
		_event_rows_with_spans(small_rows), _event_row_count(small_rows)) and passed
	small_view.free()
	return passed


static func _event_row_count(rows: Array) -> int:
	var count: int = 0
	for entry: Dictionary in rows:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_type == EventRowData.RowType.EVENT:
			count += 1
	return count


static func _event_rows_with_spans(rows: Array) -> int:
	var count: int = 0
	for entry: Dictionary in rows:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_type == EventRowData.RowType.EVENT and not row_data.spans.is_empty():
			count += 1
	return count
