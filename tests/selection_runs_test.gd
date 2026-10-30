@tool
extends RefCounted
# Godot EventSheets - a selection is drawn as RUNS
#
# Selected rows that touch are one selection mark: one frame round the run and one fill across it,
# never a frame per row. An event takes every selected row under it into its run (its local lines,
# its sub-events), so selecting a parent draws ONE frame from its top to its last child's bottom;
# a second event at the same depth starts a second frame; neighbouring variable lines share a frame
# and a gap splits them; a cell picked on its own keeps its own outline and is in no run at all.
# Pinned as values:
#   1. ViewportSelectionHelper.selection_runs over plain rows, case by case;
#   2. on the real BoomerLevel showcase: event 5 selected (its subtree with it) is one framed run,
#      its rect is the rows' own band, and every row of it is stamped to take the run's fill;
#   3. four neighbouring variables are one frame; taking the second out splits them, and the line
#      left alone above the gap is in no run (it draws its own outline).

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "selection_runs_test"
const SHOWCASE := "res://demo/showcase/boomer_level/boomer_level.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_runs() and ok
	ok = _test_branch_on_showcase() and ok
	return ok


static func _test_runs() -> bool:
	var event_row: int = EventRowData.RowType.EVENT
	var line_row: int = EventRowData.RowType.SECTION
	var branch: Array = _rows([[event_row, 0, true], [line_row, 1, true], [event_row, 1, true],
		[event_row, 2, true], [event_row, 1, true], [event_row, 0, false]])
	var siblings: Array = _rows([[event_row, 0, true], [event_row, 0, true]])
	var variables: Array = _rows([[line_row, 0, true], [line_row, 0, true], [line_row, 0, false],
		[line_row, 0, true]])
	var lines_then_event: Array = _rows([[line_row, 0, true], [event_row, 0, true]])
	var pair: Array = _rows([[event_row, 0, true], [event_row, 0, true], [event_row, 0, true]])
	return SUPPORT.pins(TEST_NAME, [
		["a parent and its subtree are ONE run, local lines included", _runs(branch), [[0, 4, true, 5]]],
		["two events side by side are two runs", _runs(siblings), [[0, 0, true, 1], [1, 1, true, 1]]],
		["neighbouring variable lines are one run, a gap splits them", _runs(variables),
			[[0, 1, false, 2], [3, 3, false, 1]]],
		["an event after a run of lines starts its own", _runs(lines_then_event),
			[[0, 0, false, 1], [1, 1, true, 1]]],
		["the rows of one statement count as one statement", _runs(pair, [0, 0, 2]),
			[[0, 1, true, 1], [2, 2, true, 1]]],
		# With the parent's cell the selection, nothing holds the branch together: its rows run on
		# their own terms - the line alone, then each event with what lies under it.
		["a statement whose cell is the selection is in no run", _runs(branch, [], [0]),
			[[1, 1, false, 1], [2, 3, true, 2], [4, 4, true, 1]]],
	])


static func _test_branch_on_showcase() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SHOWCASE)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	var five: int = _row_of_event(viewport, 5)
	var eight: int = _row_of_event(viewport, 8)
	var nine: int = _row_of_event(viewport, 9)
	viewport._select_row(five)
	var frames: Array = viewport.selection_run_frames()
	var band_top: float = viewport._row_metrics_helper.row_top(five)
	var band_bottom: float = viewport._row_metrics_helper.row_top(nine - 1) + viewport._row_metrics_helper.row_height(nine - 1)
	viewport._stamp_selection_runs(Vector2i(0, viewport._flat_rows.size() - 1))
	var stamped: Array = []
	for index: int in range(five, nine):
		stamped.append(viewport._row_at(index).in_selection_run)
	var all_true: Array = []
	all_true.resize(nine - five)
	all_true.fill(true)
	var first_frame: Dictionary = frames[0] if frames.size() == 1 else {}
	var rect: Rect2 = first_frame.get("rect", Rect2())
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["event 5 is followed by its subtree down to event 8", [five >= 0, eight > five, nine > eight], [true, true, true]],
		["selecting event 5 draws ONE frame", frames.size(), 1],
		["the frame runs from event 5 to the last row before event 9",
			[int(first_frame.get("first", -1)), int(first_frame.get("last", -1))], [five, nine - 1]],
		["the frame's rect is the rows' own band", [rect.position.y, rect.end.y], [band_top, band_bottom]],
		["every row of the branch takes the run's one fill", stamped, all_true],
	])
	# Variables: four neighbours, then the second taken out.
	var first_variable: int = _variable_row(viewport, "secrets_total")
	var fourth_variable: int = _variable_row(viewport, "level_seconds")
	viewport._select_row(first_variable)
	viewport._select_range(fourth_variable)
	var four: Array = viewport.selection_run_frames()
	viewport._select_from_click(_variable_row(viewport, "kills"), -1, true)
	var split: Array = viewport.selection_run_frames()
	viewport._stamp_selection_runs(Vector2i(0, viewport._flat_rows.size() - 1))
	var alone: EventRowData = viewport._row_at(first_variable)
	ok = SUPPORT.pins(TEST_NAME, [
		["four neighbouring variables are one frame", _spans(four), [[first_variable, fourth_variable]]],
		["taking the second out leaves one frame below the gap", _spans(split),
			[[_variable_row(viewport, "enemies_total"), fourth_variable]]],
		["the line alone above the gap is selected and in no run", [alone.selected, alone.in_selection_run], [true, false]],
	]) and ok
	viewport.free()
	return ok


## Plain rows from [row_type, indent, selected] triples.
static func _rows(specs: Array) -> Array:
	var rows: Array = []
	for spec: Variant in specs:
		var row: EventRowData = EventRowData.new()
		row.row_type = int(spec[0])
		row.indent = int(spec[1])
		row.selected = bool(spec[2])
		rows.append(row)
	return rows


## The runs as [first, last, has_event, statements]. `leads` gives each row's statement lead (its
## own index when missing); `cells` lists the rows whose cell is the selection.
static func _runs(rows: Array, leads: Array = [], cells: Array = []) -> Array:
	var out: Array = []
	var runs: Array = ViewportSelectionHelper.selection_runs(0, rows.size() - 1,
		func(index: int) -> EventRowData: return rows[index] as EventRowData,
		func(index: int) -> int: return int(leads[index]) if index < leads.size() else index,
		func(index: int) -> bool: return cells.has(index))
	for run: Variant in runs:
		var entry: Dictionary = run as Dictionary
		out.append([int(entry["first"]), int(entry["last"]), bool(entry["has_event"]), int(entry["statements"])])
	return out


static func _spans(frames: Array) -> Array:
	var out: Array = []
	for frame: Variant in frames:
		out.append([int((frame as Dictionary)["first"]), int((frame as Dictionary)["last"])])
	return out


static func _row_of_event(viewport: EventSheetViewport, number: int) -> int:
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row != null and row.event_number == number and row.source_resource is EventRow:
			return index
	return -1


static func _variable_row(viewport: EventSheetViewport, variable_name: String) -> int:
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row == null or not row.variable_row:
			continue
		viewport._row_builder._ensure_event_spans(row)
		for span: SemanticSpan in row.spans:
			if span != null and span.text == variable_name:
				return index
	return -1
