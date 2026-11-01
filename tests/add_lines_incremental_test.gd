# A look that shows an event's add lines only while the event is hovered or selected grows one event
# and shrinks another each time the pointer crosses between them. That used to re-measure by walking
# every row and then throw away EVERY cached layout, so each hover relaid out the whole screen. The
# change is now incremental: only the rows the change moved lose their layout, and the walk stops where
# the gains and losses cancel out. Pins:
#   1. After any sequence of hovers and selections the incremental metrics (every row's top and
#      height) equal a fresh measure of the same state.
#   2. Moving the pointer between two neighbouring events leaves the layouts of the rows beyond them
#      cached.
#   3. The hover flag lives on exactly one row after a run of moves.
#   4. A change of height renews the metrics generation, so what remembers row positions (the
#      brackets) asks again.
@tool
class_name AddLinesIncrementalTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "add_lines_incremental_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const SHEET := "res://demo/showcase/boomer_level/boomer_level.gd"


static func run() -> bool:
	if not FileAccess.file_exists(SHEET):
		return true
	var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(SHEET), true, SHEET)
	sheet.read_only = false
	sheet.editor_style = (load(NATIVE_THEME) as EventSheetEditorStyle).duplicate(true)
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	var rows: Array = []
	rows.append(["the look shows add lines on hover", view._get_event_style().add_lines_on_hover, true])
	var events: Array[int] = []
	for index: int in range(view.get_total_row_count()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_type == EventRowData.RowType.EVENT:
			events.append(index)
	rows.append(["the sheet has events to hover", events.size() >= 4, true])
	if events.size() < 4:
		view.free()
		return SUPPORT.pins(TEST_NAME, rows)

	var width: float = view._get_logical_canvas_width()
	var font: Font = view._get_font()
	var font_size: int = view._get_font_size()
	var generation_before: int = view._row_metrics_helper.generation()

	# A walk of hovers (down, jumping, back up) and a selection, each checked against a fresh measure.
	var path: Array[int] = [events[0], events[1], events[2], events[1], events[events.size() - 1], events[0], events[3], -1, events[2]]
	var mismatches: Array[String] = []
	for step: int in range(path.size()):
		view._set_hover_state(path[step], 0 if path[step] >= 0 else -1)
		if step == 4:
			view._select_row(events[2])
		var incremental: Array = _metrics_of(view)
		view._row_metrics_helper.rebuild()
		var fresh: Array = _metrics_of(view)
		if incremental != fresh:
			mismatches.append("step %d (row %d)" % [step, path[step]])
	rows.append(["incremental metrics equal a fresh measure at every step", mismatches, []])
	rows.append(["a change of height renewed the metrics generation", view._row_metrics_helper.generation() > generation_before, true])

	var hovered: int = 0
	for index: int in range(view.get_total_row_count()):
		if view._row_at(index).hovered:
			hovered += 1
	rows.append(["exactly one row carries the hover flag", hovered, 1])

	# Layout reuse, over every pair of events the pointer could cross between: lay out every row, move
	# the pointer, and see which layouts survive. Correctness: a row whose place or height changed lost
	# its layout. Efficiency: for some pair the gains and losses cancel and most layouts survive.
	var stale_layouts: Array[String] = []
	var best_survivors: int = 0
	var total: int = view.get_total_row_count()
	for pair: int in range(events.size() - 1):
		view._set_hover_state(events[pair], 0)
		for index: int in range(total):
			view._layout_builder.get_or_build_row_layout(index, width, font, font_size)[PROBE] = true
		var before: Array = _metrics_of(view)
		view._set_hover_state(events[pair + 1], 0)
		var after: Array = _metrics_of(view)
		var survivors: int = 0
		for index: int in range(total):
			var layout: Dictionary = view._layout_builder.get_or_build_row_layout(index, width, font, font_size)
			if layout.has(PROBE):
				survivors += 1
				if before[index] != after[index]:
					stale_layouts.append("pair %d row %d" % [pair, index])
		best_survivors = maxi(best_survivors, survivors)
	rows.append(["no row that moved or changed height kept its old layout", stale_layouts, []])
	rows.append(["for some pair of neighbouring events most layouts survive", best_survivors >= total - 6, true])
	view.free()
	return SUPPORT.pins(TEST_NAME, rows)


const PROBE: String = "probe_marker"


static func _metrics_of(view: EventSheetViewport) -> Array:
	var metrics: Array = []
	for index: int in range(view.get_total_row_count()):
		metrics.append([snappedf(view._row_metrics_helper.row_top(index), 0.001), snappedf(view._row_metrics_helper.row_height(index), 0.001)])
	return metrics
