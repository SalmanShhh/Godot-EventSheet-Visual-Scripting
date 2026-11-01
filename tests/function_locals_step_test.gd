@tool
extends RefCounted
# Godot EventSheets - the locals of a function body stand on the level of the events round them
#
# In the Editor Native look a function body whose first statement hoists a ternary used to draw an
# "Always" head row that said nothing, with the branches, the locals declared after them and the run
# of actions below one level deeper than the events round it. The head is gone now, so each row of
# the body stands on the level of its siblings. The pins hold:
#   1. the level of every row of such a body (branches, locals, the run after them, what follows);
#   2. a head that DOES say something (a condition, an action before the branch) is kept, and its
#      branches stay one level under it;
#   3. Classic Sheet reads the body as it always did - the look decides, not the shape;
#   4. it is a drawing order and nothing else - the file saves back byte for byte.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "function_locals_step_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const SOURCE := """extends Node


func shorten(value: float) -> String:
	var sign_text: String = "-" if value < 0.0 else ""
	var magnitude: float = absf(value)
	var exponent: int = int(magnitude)
	magnitude += 1.0
	if exponent < 3:
		return sign_text
	var tier: int = exponent / 3
	tier += 1
	return str(tier)
"""
const GUARDED := """extends Node


func shorten(value: float) -> String:
	if value > 1.0:
		var sign_text: String = "-" if value < 0.0 else ""
		return sign_text
	return ""
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_levels() and ok
	ok = _test_round_trip() and ok
	return ok


static func _view_of(source: String, theme_path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	sheet.read_only = false
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	return view


## One word per flat row: `local:<level>` for a declaration, `event:<level>` for an event.
static func _shape(view: EventSheetViewport) -> PackedStringArray:
	var shape := PackedStringArray()
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null:
			continue
		if row_data.event_local:
			shape.append("local:%d" % row_data.indent)
		elif row_data.row_type == EventRowData.RowType.EVENT:
			shape.append("event:%d" % row_data.indent)
	return shape


static func _test_levels() -> bool:
	var native_view: EventSheetViewport = _view_of(SOURCE, NATIVE_THEME)
	var native_shape: PackedStringArray = _shape(native_view)
	native_view.free()
	var classic_view: EventSheetViewport = _view_of(SOURCE, CLASSIC_THEME)
	var classic_shape: PackedStringArray = _shape(classic_view)
	classic_view.free()
	var guarded_view: EventSheetViewport = _view_of(GUARDED, NATIVE_THEME)
	var guarded_shape: PackedStringArray = _shape(guarded_view)
	guarded_view.free()
	return SUPPORT.pins(TEST_NAME, [
		["Editor Native: no head row, and the branches, locals and runs all stand on the body's level",
			native_shape, PackedStringArray([
				"event:0", "event:1", "event:1", "local:1", "local:1", "event:1", "event:1", "local:1", "event:1"])],
		["Classic Sheet reads this body as it always did (the look decides, not the shape)",
			classic_shape, PackedStringArray([
				"event:0", "event:1", "event:1", "event:1", "local:1", "local:1", "event:1", "event:1", "local:2"])],
		["a head with a condition of its own is kept, and its branches stay under it",
			guarded_shape, PackedStringArray(["event:0", "event:1", "event:2", "event:2", "event:2", "event:1"])],
	])


static func _test_round_trip() -> bool:
	var again: String = SUPPORT.reemit(SOURCE, "user://function_locals_step_probe.gd")
	var guarded_again: String = SUPPORT.reemit(GUARDED, "user://function_locals_step_guarded_probe.gd")
	var ok: bool = SUPPORT.check(TEST_NAME, "the file saves back byte for byte", again, SOURCE)
	return SUPPORT.check(TEST_NAME, "so does the guarded one", guarded_again, GUARDED) and ok
