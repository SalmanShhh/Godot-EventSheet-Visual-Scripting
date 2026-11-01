@tool
extends RefCounted
# Godot EventSheets - a branch of a pair is an event of its own in the margin
#
# In the Editor Native look an `a if c else b` that a statement hoists reads as two rows, and each
# row is an event with its own number: the events after a pair move down by the branches before it.
# A function body that opens with such a statement carries no head row of its own - the head would
# say only its placeholder - so the branches and the locals after them stand on the level of the
# events round them. The pins hold:
#   1. the numbers down the margin, branches and the run after one included;
#   2. a fold never renumbers anything (the walk reads folded rows too);
#   3. Classic Sheet keeps one number per event;
#   4. it is a reading and nothing else - the file saves back byte for byte.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "branch_numbering_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const SOURCE := """extends Node


func calc(value: float) -> String:
	if not is_finite(value):
		return "Infinity" if value > 0.0 else "-Infinity"
	if value == 0.0:
		return "0"
	var sign_text: String = "-" if value < 0.0 else ""
	var magnitude: float = absf(value)
	var exponent: int = int(magnitude)
	if exponent < 3:
		return sign_text
	return str(exponent)
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_numbers() and ok
	ok = _test_fold() and ok
	ok = _test_translation() and ok
	ok = _test_round_trip() and ok
	return ok


static func _view_of(theme_path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	sheet.read_only = false
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	return view


## One word per flat row: `<kind>:<indent>:<number>` where kind is `event` or `local`, and the number
## is the margin's (the event's own, or `b` and the number a branch wears; `-` for none).
static func _shape(view: EventSheetViewport) -> PackedStringArray:
	var shape := PackedStringArray()
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null:
			continue
		var margin: String = "-"
		if row_data.event_number > 0:
			margin = str(row_data.event_number)
		elif row_data.branch_number > 0:
			margin = "b%d" % row_data.branch_number
		if row_data.event_local:
			shape.append("local:%d" % row_data.indent)
		elif row_data.row_type == EventRowData.RowType.EVENT:
			shape.append("event:%d:%s" % [row_data.indent, margin])
	return shape


static func _test_numbers() -> bool:
	var native_view: EventSheetViewport = _view_of(NATIVE_THEME)
	var native_shape: PackedStringArray = _shape(native_view)
	native_view.free()
	var classic_view: EventSheetViewport = _view_of(CLASSIC_THEME)
	var classic_shape: PackedStringArray = _shape(classic_view)
	classic_view.free()
	return SUPPORT.pins(TEST_NAME, [
		["Editor Native: the pair's two branches take 3 and 4, the events after move down, the placeholder head is gone",
			native_shape, PackedStringArray([
				"event:0:1", "event:1:2", "event:2:b3", "event:2:b4", "event:1:5",
				"local:1", "event:1:6", "event:1:b7", "local:1", "local:1", "event:1:b8", "event:1:9", "event:1:10"])],
		["Classic Sheet keeps one number per event and no branch number",
			classic_shape, PackedStringArray([
				"event:0:1", "event:1:2", "event:2:-", "event:2:-", "event:1:3",
				"event:1:4", "event:2:-", "event:2:-", "event:2:-", "local:2", "local:2", "local:2", "event:1:5", "event:1:6"])],
	])


static func _test_fold() -> bool:
	var folded_view: EventSheetViewport = _view_of(NATIVE_THEME)
	var head: EventRowData = null
	for root_row: EventRowData in folded_view._root_rows:
		for body_row: EventRowData in root_row.children:
			if head == null and body_row.row_type == EventRowData.RowType.EVENT and not body_row.children.is_empty():
				head = body_row
	var folded_shape: PackedStringArray = PackedStringArray()
	if head != null:
		folded_view.toggle_row_fold_by_uid(head.row_uid)
		folded_shape = _shape(folded_view)
	folded_view.free()
	var kept: PackedStringArray = PackedStringArray()
	for word: String in folded_shape:
		if word.ends_with(":5") or word.ends_with(":6") or word.ends_with(":9") or word.ends_with(":10"):
			kept.append(word)
	return SUPPORT.pins(TEST_NAME, [
		["folding the guard hides its branches and renumbers nothing after it",
			kept, PackedStringArray(["event:1:5", "event:1:6", "event:1:9", "event:1:10"])],
	])


static func _test_round_trip() -> bool:
	var again: String = SUPPORT.reemit(SOURCE, "user://branch_numbering_probe.gd")
	return SUPPORT.check(TEST_NAME, "the file saves back byte for byte", again, SOURCE)


static func _test_translation() -> bool:
	var view: EventSheetViewport = _view_of(NATIVE_THEME)
	var classic: EventSheetViewport = _view_of(CLASSIC_THEME)
	var pins: Array = [
		["the sheet's third event wears 5 in the margin once the pair's two branches are before it",
			view.display_event_number(3), 5],
		["margin 5 is the sheet's third event", view.model_event_number(5), 3],
		["margin 3 is a branch, which no event of the sheet answers to", view.model_event_number(3), 0],
		["an event before the pair keeps its number", view.display_event_number(2), 2],
		["Classic Sheet never renumbers", classic.display_event_number(3), 3],
		["Classic Sheet's margin number is the sheet's", classic.model_event_number(3), 3],
		["the margin counts four more places than the sheet has events: two branches, the Else after the 6, the run after it",
			view.branch_growth(), 4],
		["Classic Sheet counts none", classic.branch_growth(), 0],
	]
	view.free()
	classic.free()
	return SUPPORT.pins(TEST_NAME, pins)
