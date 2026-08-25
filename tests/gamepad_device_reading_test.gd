# EventForge - A gamepad branch that names a DEVICE reads as one row in the Gamepad object's own
# words: `if event is InputEventJoypadButton and event.pressed and event.device == 0 and
# event.button_index == JOY_BUTTON_A:` is `On gamepad 0 button A pressed`, not four condition cells.
# The device index IS the gamepad number, exactly as the Gamepad object counts them from 0. A keyboard
# has no number in the sheet, so `event.device == 1` on a Keyboard branch stays the comparison it is.
@tool
class_name GamepadDeviceReadingTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _check("a gamepad branch that names a device reads as one row",
		_condition_lane("extends Node\n\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif event is InputEventJoypadButton and event.pressed and event.device == 0 and event.button_index == JOY_BUTTON_A:\n\t\tjump()\n"),
		"On gamepad 0 button A pressed") and ok
	ok = _check("a gamepad branch with no device keeps the plain button words",
		_condition_lane("extends Node\n\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:\n\t\tjump()\n"),
		"On button A pressed") and ok
	# A keyboard has no gamepad number, so the device test is NOT absorbed: the row keeps the key
	# words and the comparison reads on its own beside them.
	ok = _check("a keyboard branch keeps its own words",
		_condition_lane("extends Node\n\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif event is InputEventKey and event.pressed and event.device == 1 and event.keycode == KEY_SPACE:\n\t\tjump()\n"),
		"On Space pressed") and ok
	return ok


## The text of the first condition-lane span on the sheet's first input event row.
static func _condition_lane(source: String) -> String:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var found: String = "<none>"
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null:
			continue
		for span: SemanticSpan in row.spans:
			if not (span.metadata is Dictionary):
				continue
			if str((span.metadata as Dictionary).get("lane")) != "condition":
				continue
			if str(span.text).begins_with("On "):
				found = str(span.text)
				break
		if found != "<none>":
			break
	dock.free()
	return found


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] gamepad_device_reading_test: %s" % label)
		return true
	print("[FAIL] gamepad_device_reading_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
