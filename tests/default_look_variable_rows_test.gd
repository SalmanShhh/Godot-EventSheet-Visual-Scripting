# EventForge - the look a new sheet gets (the one derived from the editor's own colours) lists a
# variable the way the Inspector lists a property: type, name as written, value, note and icon tiles,
# without the compiler's own bookkeeping variables - on a dark editor and a light one.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var dark: EventSheetEventStyle = EventSheetEditorThemeDeriver.derive(Color(0.21, 0.24, 0.29), Color(0.44, 0.73, 0.98)).get_event_style()
	var light: EventSheetEventStyle = EventSheetEditorThemeDeriver.derive(Color(0.9, 0.9, 0.9), Color(0.2, 0.45, 0.8)).get_event_style()
	return SUPPORT.pins("default_look_variable_rows_test", [
		["a dark editor's default look reads variables Inspector-style",
			[dark.inspector_variable_rows, dark.hide_compiler_variables], [true, true]],
		["and so does a light editor's",
			[light.inspector_variable_rows, light.hide_compiler_variables], [true, true]],
	])
