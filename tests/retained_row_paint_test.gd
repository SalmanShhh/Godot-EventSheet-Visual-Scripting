# Every hover, keystroke and selection used to repaint every visible row. Each visible row now lives
# on a retained canvas item that is recorded again only when its paint signature changes. The pixels
# themselves are proven in the real editor (screenshots at rest, hover, selection, drag, both
# looks); this pins the decisions that make that safe:
#   1. The signature moves with everything a row's paint reads that can change without a rebuild:
#      the row's plain fields, the live state the layout refreshes on read (hover, selection, the
#      edit in progress), and the frame-wide values. It does not move when nothing did.
#   2. An item is recorded again only for a changed signature, row or layout identity.
#   3. A frame that changed one row asks for exactly one record; the same frame again asks for none.
#   4. Rows that leave the screen give their items back for reuse, and a reused item is never taken
#      for the row it last showed.
#   5. The items sit in row order after rows enter and leave.
@tool
class_name RetainedRowPaintTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "retained_row_paint_test"
const SHEET := "res://demo/showcase/boomer_level/boomer_level.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_signature() and ok
	ok = _test_needs_record() and ok
	ok = _test_placement() and ok
	return ok


static func _row() -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	row_data.row_type = EventRowData.RowType.EVENT
	return row_data


static func _test_signature() -> bool:
	var row_data: EventRowData = _row()
	var layout: Dictionary = {"hovered_span_index": -1, "selected_span_indices": []}
	var base: int = EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)
	var rows: Array = [["the same inputs give the same signature", EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7), base]]
	var changes: Array = []
	row_data.hovered = true
	changes.append(["a hovered row", EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)])
	row_data.hovered = false
	row_data.selected = true
	changes.append(["a selected row", EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)])
	row_data.selected = false
	row_data.folded = true
	changes.append(["a folded row", EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)])
	row_data.folded = false
	row_data.firing_intensity = 0.4
	changes.append(["a firing row", EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)])
	row_data.firing_intensity = 0.0
	row_data.event_number = 12
	changes.append(["a renumbered row", EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)])
	row_data.event_number = 0
	changes.append(["another frame signature (zoom, look, size)", EventSheetRetainedPaintItem.paint_signature(row_data, layout, 8)])
	for key: String in ["hovered_span_index", "editing_span_index", "editing_buffer", "editing_caret", "editing_select_anchor", "editing_note", "total_selected_spans"]:
		var live: Dictionary = layout.duplicate()
		live[key] = "x" if key in ["editing_buffer", "editing_note"] else 3
		changes.append(["the layout's " + key, EventSheetRetainedPaintItem.paint_signature(row_data, live, 7)])
	var selected_cells: Dictionary = layout.duplicate()
	selected_cells["selected_span_indices"] = [1]
	changes.append(["the selected cells", EventSheetRetainedPaintItem.paint_signature(row_data, selected_cells, 7)])
	var matches: Dictionary = layout.duplicate()
	matches["match_span_indices"] = PackedInt32Array([2])
	changes.append(["the lit uses of a hovered variable", EventSheetRetainedPaintItem.paint_signature(row_data, matches, 7)])
	for change: Array in changes:
		rows.append(["%s moves the signature" % change[0], int(change[1]) != base, true])
	return SUPPORT.pins(TEST_NAME, rows)


static func _test_needs_record() -> bool:
	var item: EventSheetRetainedPaintItem = EventSheetRetainedPaintItem.new()
	var row_data: EventRowData = _row()
	var layout: Dictionary = {"a": 1}
	var rows: Array = [["a fresh item needs a record", item.needs_record(layout, row_data, 5), true]]
	item.record(layout, row_data, 5)
	rows.append(["the same row, layout and signature need none", item.needs_record(layout, row_data, 5), false])
	rows.append(["a new signature needs one", item.needs_record(layout, row_data, 6), true])
	rows.append(["a rebuilt layout (another dictionary) needs one", item.needs_record({"a": 1}, row_data, 5), true])
	rows.append(["another row needs one", item.needs_record(layout, _row(), 5), true])
	item.forget()
	rows.append(["a forgotten item is never taken for the row it showed", item.needs_record(layout, row_data, 5), true])
	rows.append(["a forgotten item is hidden", item.visible, false])
	item.free()
	return SUPPORT.pins(TEST_NAME, rows)


static func _test_placement() -> bool:
	if not FileAccess.file_exists(SHEET):
		return true
	var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(SHEET), true, SHEET)
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	var font: Font = view._get_font()
	var font_size: int = view._get_font_size()
	var width: float = view._get_logical_canvas_width()
	var frame: Array[int] = [99]

	var place := func(first: int, last: int) -> void:
		view._row_items_placed.clear()
		for index: int in range(first, last + 1):
			var row_data: EventRowData = view._row_at(index)
			var layout: Dictionary = view._layout_builder.get_or_build_row_layout(index, width, font, font_size)
			view._place_row_item(index, layout, row_data, font, font_size, 1.0, 0.0, frame[0])
		view._release_unplaced_row_items()

	place.call(0, 5)
	var first_pass: Dictionary = view.retained_paint_stats()
	place.call(0, 5)
	var second_pass: Dictionary = view.retained_paint_stats()
	view._row_at(2).hovered = true
	place.call(0, 5)
	var hovered_pass: Dictionary = view.retained_paint_stats()
	frame[0] = 100
	place.call(0, 5)
	var framed_pass: Dictionary = view.retained_paint_stats()

	var rows: Array = [
		["six rows, six items", first_pass["placed"], 6],
		["each new item is recorded once", first_pass["requests"], 6],
		["the same frame again records nothing", int(second_pass["requests"]) - int(first_pass["requests"]), 0],
		["one hovered row records exactly one item", int(hovered_pass["requests"]) - int(second_pass["requests"]), 1],
		["another frame signature (zoom, look) records them all", int(framed_pass["requests"]) - int(hovered_pass["requests"]), 6],
	]

	# Rows scroll away: their items are pooled, and rows scrolling in take them back, recorded afresh.
	place.call(3, 8)
	var scrolled: Dictionary = view.retained_paint_stats()
	rows.append(["scrolled by three rows still six items", scrolled["placed"], 6])
	rows.append(["only the three rows that came in were recorded", int(scrolled["requests"]) - int(framed_pass["requests"]), 3])
	# Row order in the tree follows row index however items were recycled.
	var order: Array = []
	for index: int in range(3, 9):
		order.append((view._row_items[index] as Node).get_index())
	var sorted_order: Array = order.duplicate()
	sorted_order.sort()
	rows.append(["items stand in row order after rows came and went", order, sorted_order])
	place.call(0, 2)
	rows.append(["rows far away left only their own items", view.retained_paint_stats()["placed"], 3])
	rows.append(["the others are pooled for reuse", view.retained_paint_stats()["pooled"] >= 3, true])
	view.free()
	return SUPPORT.pins(TEST_NAME, rows)
