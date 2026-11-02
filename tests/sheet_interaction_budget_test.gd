# What a pointer on the sheet is allowed to cost. Moving over rows, dragging across them and folding one
# used to relay out every visible row, repaint every visible row, or rebuild the whole sheet. Each of those
# has a pin of what it may touch (no wall clock involved, so it cannot flap) and, where a wall clock means
# something headless, a budget of three times the median measured on a quiet machine, on the 700-row pack.
# A headless run cannot draw: the frame times themselves are measured in the real editor.
@tool
class_name SheetInteractionBudgetTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "sheet_interaction_budget_test"
const SHEET := "res://eventsheet_addons/juice/juice_behavior.gd"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const STEPS := 40

## One fold clicked and clicked back, by reflow. A whole rebuild of this sheet is seconds.
const FOLD_PAIR_BUDGET_MS: float = 130.0
## One pointer crossing between two events under a look that shows add lines on hover.
const HOVER_CROSS_BUDGET_MS: float = 2.5
## Laying out the rows on screen again after the drop target moved one row.
const DRAG_MOVE_BUDGET_MS: float = 3.0
## One fold clicked and clicked back on a sheet of eleven hundred rows (a hundred groups of ten notes), by
## reflow. Measuring every row again used to make a fold ten times this.
const LARGE_FOLD_PAIR_BUDGET_MS: float = 120.0
## Putting the rows of the 900-row pack back after an event was moved, as an authored sheet (every row's
## words built up front). Before the sentence scanners answered by string search it took a little under
## four seconds on a loaded machine; the bound sits under that and over what it takes now.
const REBUILD_AFTER_MOVE_BUDGET_MS: float = 3000.0
## Asking every row on screen (forty of them) whether its paint changed, the part of a frame that runs
## on every hover and every slide.
const FRAME_CHECK_BUDGET_MS: float = 3.5


static func run() -> bool:
	if not FileAccess.file_exists(SHEET):
		return true
	var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(SHEET), true, SHEET)
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1900.0, 1100.0)
	view.set_sheet(sheet)
	var ok: bool = _drag_touches_only_the_target(view)
	ok = _frame_check_cost(view) and ok
	ok = _fold_cost(view) and ok
	ok = _rebuild_after_move_cost(view, sheet) and ok
	view.free()
	ok = _hover_cross_cost(sheet) and ok
	ok = _large_fold_cost() and ok
	return ok


## An event moved up the sheet and the rows put back: the step a drop ends in.
static func _rebuild_after_move_cost(view: EventSheetViewport, sheet: EventSheetResource) -> bool:
	var first: int = -1
	var second: int = -1
	for index: int in range(sheet.events.size()):
		if sheet.events[index] is EventRow:
			if first < 0:
				first = index
			elif second < 0:
				second = index
	if second < 0:
		return SUPPORT.check(NAME, "the sheet has two events to move between", false, true)
	var moved: Resource = sheet.events[second]
	sheet.events.remove_at(second)
	sheet.events.insert(first, moved)
	var started: int = Time.get_ticks_usec()
	view.set_sheet(sheet)
	var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	sheet.events.remove_at(first)
	sheet.events.insert(second, moved)
	view.set_sheet(sheet)
	print("%s: the rows after an event was moved take %.0f ms" % [NAME, ms])
	return SUPPORT.check(NAME, "the rebuild after a move is inside its budget", ms < REBUILD_AFTER_MOVE_BUDGET_MS, true)


## A fold on a sheet with a thousand rows: every row but the one that changed keeps its measurement.
static func _large_fold_cost() -> bool:
	var sheet := EventSheetResource.new()
	for group_index: int in range(100):
		var group := EventGroup.new()
		group.group_name = "Group %d" % group_index
		for note_index: int in range(10):
			var note := CommentRow.new()
			note.text = "note %d.%d" % [group_index, note_index]
			group.events.append(note)
		sheet.events.append(group)
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	view.settle_all_row_heights()
	var builds: int = view.row_builds()
	var started: int = Time.get_ticks_usec()
	view._folding.toggle_row_fold(0)
	view._folding.toggle_row_fold(0)
	var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var rows: int = view.get_total_row_count()
	var builds_after: int = view.row_builds()
	view.free()
	print("%s: a fold and back on %d rows takes %.1f ms" % [NAME, rows, ms])
	return SUPPORT.pins(NAME, [
		["the large sheet has its rows", rows > 1000, true],
		["a fold on a large sheet builds no rows", builds_after, builds],
		["a fold and back on a large sheet is inside its budget", ms < LARGE_FOLD_PAIR_BUDGET_MS, true],
	])


static func _events(view: EventSheetViewport) -> Array[int]:
	var events: Array[int] = []
	for index: int in range(view.get_total_row_count()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_type == EventRowData.RowType.EVENT:
			events.append(index)
	return events


static func _lay_out(view: EventSheetViewport, first: int, last: int) -> void:
	var width: float = view._get_logical_canvas_width()
	var font: Font = view._get_font()
	var font_size: int = view._get_font_size()
	for index: int in range(first, mini(last, view.get_total_row_count() - 1) + 1):
		view._layout_builder.get_or_build_row_layout(index, width, font, font_size)


## Each step of a drag moves the target one row. Only that row is laid out again, whatever else is on screen.
static func _drag_touches_only_the_target(view: EventSheetViewport) -> bool:
	_lay_out(view, 0, 60)
	view._drag_row_index = 0
	var before: int = view._layout_cache.size()
	var started: int = Time.get_ticks_usec()
	for step: int in range(STEPS):
		view._drag_target_index = 5 + step
		view._drag_target_mode = "before"
		_lay_out(view, 0, 60)
	var each_ms: float = float(Time.get_ticks_usec() - started) / 1000.0 / float(STEPS)
	var grown: int = view._layout_cache.size() - before
	view._drag_row_index = -1
	view._drag_target_index = -1
	view._drag_target_mode = ""
	print("%s: a drag move relays out %d rows (%.2f ms)" % [NAME, grown / STEPS, each_ms])
	return SUPPORT.pins(NAME, [
		["a target that moves one row lays out one row per move", grown <= STEPS, true],
		["a drag move is inside its budget", each_ms < DRAG_MOVE_BUDGET_MS, true],
	])


static func _frame_check_cost(view: EventSheetViewport) -> bool:
	var width: float = view._get_logical_canvas_width()
	var font: Font = view._get_font()
	var font_size: int = view._get_font_size()
	_lay_out(view, 0, 40)
	var started: int = Time.get_ticks_usec()
	for step: int in range(STEPS):
		var frame: int = view._frame_paint_signature(1.0, font, font_size)
		for index: int in range(0, 40):
			var layout: Dictionary = view._layout_builder.get_or_build_row_layout(index, width, font, font_size)
			EventSheetRetainedPaintItem.paint_signature(view._row_at(index), layout, frame)
	var each_ms: float = float(Time.get_ticks_usec() - started) / 1000.0 / float(STEPS)
	print("%s: asking 40 rows whether their paint changed takes %.2f ms" % [NAME, each_ms])
	return SUPPORT.check(NAME, "the per-frame paint check is inside its budget", each_ms < FRAME_CHECK_BUDGET_MS, true)


static func _fold_cost(view: EventSheetViewport) -> bool:
	var target: String = ""
	for index: int in range(view.get_total_row_count()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and not row_data.children.is_empty() and view._row_builder.can_redress_fold(row_data):
			target = row_data.row_uid
			break
	if target.is_empty():
		return SUPPORT.check(NAME, "the sheet has a row to fold", false, true)
	var builds: int = view.row_builds()
	var started: int = Time.get_ticks_usec()
	view._folding.toggle_row_fold_by_uid(target)
	view._folding.toggle_row_fold_by_uid(target)
	var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	print("%s: fold and unfold by reflow takes %.1f ms" % [NAME, ms])
	return SUPPORT.pins(NAME, [
		["a fold builds no rows", view.row_builds(), builds],
		["a fold and back is inside its budget", ms < FOLD_PAIR_BUDGET_MS, true],
	])


static func _hover_cross_cost(sheet: EventSheetResource) -> bool:
	sheet.editor_style = (load(NATIVE_THEME) as EventSheetEditorStyle).duplicate(true)
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1900.0, 1100.0)
	view.set_sheet(sheet)
	var events: Array[int] = _events(view)
	if events.size() < STEPS + 2:
		view.free()
		return SUPPORT.check(NAME, "the sheet has events to cross", false, true)
	view.settle_all_row_heights()
	var started: int = Time.get_ticks_usec()
	for step: int in range(STEPS):
		view._set_hover_state(events[step], 0)
	var each_ms: float = float(Time.get_ticks_usec() - started) / 1000.0 / float(STEPS)
	print("%s: a pointer crossing between events takes %.2f ms" % [NAME, each_ms])
	view.free()
	return SUPPORT.check(NAME, "a hover crossing is inside its budget", each_ms < HOVER_CROSS_BUDGET_MS, true)
