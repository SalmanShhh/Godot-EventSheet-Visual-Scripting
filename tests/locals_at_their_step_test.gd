@tool
extends RefCounted
# Godot EventSheets - a local variable stands at the step where the code declares it
#
# In the Editor Native look an event is one panel and a `var` line is one tight row at the step of
# the code that declares it: before the event whose actions carry its value, at that event's own
# level, never hoisted to the top of the whole body and never a row inside the event. The pins hold:
#   1. the order of the flat rows - each local between the events it sits between, on the level of
#      the events round it;
#   2. the look is the only thing that decides it: Classic Sheet keeps every local under its event;
#   3. it is a drawing order and nothing else - the file opens and saves back byte for byte.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "locals_at_their_step_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const SOURCE := """extends Node


func calc(value: float) -> String:
	if value == 0:
		return "0"
	var sign_text := ""
	if value < 0:
		sign_text = "-"
	var magnitude: float = absf(value)
	var exponent: int = int(magnitude)
	if exponent < 3:
		return sign_text
	var tier: int = exponent / 3
	tier += 1
	return str(tier)
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_order() and ok
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


## One word per flat row: `local:<indent>` for a declaration, `event:<indent>` for an event.
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


static func _test_order() -> bool:
	var native_view: EventSheetViewport = _view_of(NATIVE_THEME)
	var native_shape: PackedStringArray = _shape(native_view)
	native_view.free()
	var classic_view: EventSheetViewport = _view_of(CLASSIC_THEME)
	var classic_shape: PackedStringArray = _shape(classic_view)
	classic_view.free()
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Editor Native: each local stands between the events it sits between, on their level",
			native_shape, PackedStringArray(["event:0", "event:1", "event:1", "event:1", "local:1", "local:1",
				"event:1", "event:1", "local:1", "event:1"])],
		["Classic Sheet keeps every local inside the event that carries it, a level deeper",
			classic_shape, PackedStringArray(["event:0", "event:1", "event:1", "event:1", "event:1", "local:2",
				"local:2", "event:1", "event:1", "local:2"])],
		["the declarations come in the order the code writes them",
			_declared_names(SOURCE), PackedStringArray(["sign_text", "magnitude", "exponent", "tier"])],
	])
	return ok


static func _declared_names(source: String) -> PackedStringArray:
	var names := PackedStringArray()
	for line: String in source.split("
"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("var "):
			names.append(trimmed.substr(4).split(":")[0].split(" ")[0])
	return names


static func _test_round_trip() -> bool:
	var again: String = SUPPORT.reemit(SOURCE, "user://locals_at_their_step_probe.gd")
	return SUPPORT.check(TEST_NAME, "the file saves back byte for byte", again, SOURCE)
