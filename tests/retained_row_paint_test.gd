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
	# A state row asks the running game at draw time: its token's seconds change with no rebuild.
	var state_span: EventSheetSemanticSpan = EventSheetSemanticSpan.new()
	state_span.metadata = {"state_name": "CHASE"}
	row_data.spans = [state_span]
	EventSheetStateWatch.clear()
	var resting: int = EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)
	EventSheetStateWatch.note_frame({"state": "CHASE", "state_seconds": 1.0})
	var live_one: int = EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)
	EventSheetStateWatch.note_frame({"state": "CHASE", "state_seconds": 2.5})
	var live_two: int = EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)
	EventSheetStateWatch.note_frame({"state": "PATROL", "state_seconds": 2.5})
	var left_it: int = EventSheetRetainedPaintItem.paint_signature(row_data, layout, 7)
	EventSheetStateWatch.clear()
	rows.append(["a state coming live moves the signature", live_one != resting, true])
	rows.append(["its seconds move the signature", live_two != live_one, true])
	rows.append(["the game leaving that state moves it too", left_it != live_two, true])
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

	# One frame with many rows on it (zoomed far out on a long sheet) must not leave as many nodes behind.
	var total_rows: int = view.get_total_row_count()
	place.call(0, total_rows - 1)
	place.call(0, 2)
	rows.append(["a frame with every row on it leaves a bounded pool", view.retained_paint_stats()["pooled"] <= EventSheetViewport.RETAINED_POOL_SPARE, true])
	var alive: int = 0
	for child: Node in view.get_children():
		if child is EventSheetRetainedPaintItem and not child.is_queued_for_deletion():
			alive += 1
	rows.append(["and the rest of the items are gone", alive <= 3 + EventSheetViewport.RETAINED_POOL_SPARE, true])

	# Zooming out while scrolled deep leaves the scroll offset past the end of the canvas for one frame:
	# that frame is not a reason to draw (and make an item for) every row of the sheet.
	var host: ScrollContainer = ScrollContainer.new()
	host.size = Vector2(1200.0, 300.0)
	host.add_child(view)
	var deep: Vector2i = view.visible_rows_at(view._row_metrics_helper.row_top(total_rows - 1) + 90000.0, 300.0)
	rows.append(["a scroll offset past the end asks for the last row, not all of them", deep, Vector2i(total_rows - 1, total_rows - 1)])
	host.remove_child(view)
	host.free()

	# The frame-wide part. The canvas grows and shrinks as an event opens its add lines, and only its width
	# reaches a row's paint; a colour changed in place on the look (the Inspector edits a sheet's own one)
	# must reach every row although the look is the same object.
	view.apply_editor_style(EventSheetEditorThemeDeriver.promoted_default_style())
	var framed: int = view._frame_paint_signature(1.0, font, font_size)
	var was_size: Vector2 = view.size
	view.size = was_size + Vector2(0.0, 500.0)
	rows.append(["a taller canvas leaves the frame signature alone", view._frame_paint_signature(1.0, font, font_size), framed])
	view.size = was_size + Vector2(200.0, 0.0)
	rows.append(["a wider canvas moves it", view._frame_paint_signature(1.0, font, font_size) != framed, true])
	view.size = was_size
	var event_style: EventSheetEventStyle = view._get_event_style()
	var kept_colour: Color = event_style.row_background_color
	event_style.row_background_color = Color(0.5, 0.1, 0.1)
	rows.append(["a colour changed in place on the look moves it", view._frame_paint_signature(1.0, font, font_size) != framed, true])
	event_style.row_background_color = kept_colour
	rows.append(["and putting it back settles it", view._frame_paint_signature(1.0, font, font_size), framed])

	# A row a drag in hand changes stays on its own item (the row below slides over it, not under it), is
	# recorded every frame, and draws its own offset; left alone again it records once more and stands still.
	view._row_items_placed.clear()
	var moving_index: int = 1
	var moving_row: EventRowData = view._row_at(moving_index)
	var moving_layout: Dictionary = view._layout_builder.get_or_build_row_layout(moving_index, width, font, font_size)
	view._place_row_item(moving_index, moving_layout, moving_row, font, font_size, 1.0, 40.0, frame[0], true)
	var motion_one: Dictionary = view.retained_paint_stats()
	view._place_row_item(moving_index, moving_layout, moving_row, font, font_size, 1.0, 40.0, frame[0], true)
	var motion_two: Dictionary = view.retained_paint_stats()
	var moving_item: EventSheetRetainedPaintItem = view._row_items[moving_index]
	rows.append(["a row in motion is recorded every frame", int(motion_two["requests"]) - int(motion_one["requests"]), 1])
	rows.append(["and draws its own offset, so its item does not move", moving_item.position, Vector2.ZERO])
	rows.append(["it remembers which row it draws", moving_item.row_index, moving_index])
	view._place_row_item(moving_index, moving_layout, moving_row, font, font_size, 1.0, 40.0, frame[0], false)
	var settled: Dictionary = view.retained_paint_stats()
	rows.append(["leaving the motion path records it once more", int(settled["requests"]) - int(motion_two["requests"]), 1])
	rows.append(["and it is placed at the offset like any other row", moving_item.position, Vector2(0.0, 40.0)])
	view._place_row_item(moving_index, moving_layout, moving_row, font, font_size, 1.0, 40.0, frame[0], false)
	rows.append(["after that the same paint moved asks for nothing", int(view.retained_paint_stats()["requests"]) - int(settled["requests"]), 0])
	view.free()
	return SUPPORT.pins(TEST_NAME, rows)
