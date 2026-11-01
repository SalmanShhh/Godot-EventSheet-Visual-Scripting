@tool
extends RefCounted
# Godot EventSheets - the gap an event is carried into opens at the level of the blocks it lands among
#
# While an event is carried the place it lands is a dashed gap the rows slide apart round. In the
# Editor Native look blocks nest by lines, so a gap at a level begins where the blocks of that level
# do, and a drop over a branch of a pair (which has no place between its rows) opens its gap after
# the event the pair belongs to, at that event's level, below everything it draws. The pins hold:
#   1. the left edge of a row gap, level by level, in both looks;
#   2. the gap a carried event opens over a branch of a pair.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "drag_gap_level_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const PAIR_SOURCE := """extends Node

var value: int = 0
var x: int = 0
var y: int = 0
var z: int = 0


func _process(_delta: float) -> void:
	if value > 3:
		x = 1 if value > 5 else 2
		y = 3
	if value > 7:
		z = 1
	if value > 9:
		z = 2
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_gap_edges() and ok
	ok = _test_pair_gap() and ok
	return ok


static func _view_of(theme_path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = SUPPORT.reopen(PAIR_SOURCE)
	sheet.read_only = false
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	return view


static func _test_gap_edges() -> bool:
	var native_view: EventSheetViewport = _view_of(NATIVE_THEME)
	var classic_view: EventSheetViewport = _view_of(CLASSIC_THEME)
	var step: float = float(classic_view.indent_width())
	var native_edges: Array = []
	var classic_edges: Array = []
	for level: int in range(4):
		native_edges.append(native_view._drag_motion._row_gap_left(level))
		classic_edges.append(classic_view._drag_motion._row_gap_left(level))
	native_view.free()
	classic_view.free()
	return SUPPORT.pins(TEST_NAME, [
		["Editor Native: a row gap opens at the left edge of the blocks of its level",
			native_edges, [52.0, 70.0, 88.0, 106.0]],
		["Classic Sheet keeps the gutter plus a step per level",
			classic_edges, [20.0, 20.0 + step, 20.0 + 2.0 * step, 20.0 + 3.0 * step]],
	])


## An event carried over a branch of a pair is dropped AFTER the event the pair belongs to: the gap
## opens at that event's level and below everything it draws, not between the rows of the pair.
static func _test_pair_gap() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	EventSheetAccessibility.set_reduced_motion(true)
	var branch: int = -1
	for index: int in range(view.get_flat_rows().size()):
		var candidate: EventRowData = view._row_at(index)
		if candidate != null and not candidate.ternary_anchor_uid.is_empty():
			branch = index
			break
	var last: int = view.statement_last_index(branch)
	var lead: int = view.statement_lead_index(branch)
	var next_event: int = last + 1
	var carried: int = view.get_flat_rows().size() - 1
	var result: Array = []
	if branch >= 0 and carried > next_event:
		view._drag_row_index = carried
		view._drag_row_indices = [carried] as Array[int]
		var carried_top: float = view._row_metrics_helper.row_top(carried)
		view._drag_motion.press(Vector2(10.0, carried_top + 4.0))
		view._drag_motion.lift_rows([carried], Vector2(10.0, carried_top + 6.0))
		var target: Dictionary = view.normalize_row_drop_target(branch, "after")
		view._drag_target_index = int(target["index"])
		view._drag_target_mode = str(target["mode"])
		view.place_drag_gap({"row_index": branch})
		OS.delay_msec(260)
		view._drag_motion.advance()
		var gaps: Array = view._drag_motion.gap_rects()
		if not gaps.is_empty():
			var gap: Rect2 = (gaps[0] as Dictionary)["rect"]
			result = [gap.position.x, gap.position.y == view._row_metrics_helper.row_top(next_event)]
		view._drag_motion.finish()
	var lead_indent: int = view._row_at(lead).indent if lead >= 0 else -1
	view.free()
	EventSheetAccessibility.set_reduced_motion(false)
	return SUPPORT.pins(TEST_NAME, [
		["the pair's own event stands at the top level", lead_indent, 0],
		["a drop over a branch opens its gap at that event's level and at the top of the next event",
			result, [52.0, true]],
	])
