# EventForge - Three input shapes that Godot files as ordinary handlers read as the words
# the sheet already has for them: the cursor arriving at an object and leaving it are the Mouse's
# `Cursor is over <object>` with the edge said quietly, input landing on a clickable body is
# `On <object> clicked`, and the joypad connection signal is the Gamepad's
# `On gamepad connected / disconnected` with the device and connected chips beside it.
#
# The file is untouched by all three: each one still recompiles byte-identically.
@tool
class_name InputObjectReadingTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MOUSE_ENTERED := "extends Area2D\n\n\nfunc _ready() -> void:\n\tmouse_entered.connect(_on_mouse_entered)\n\n\nfunc _on_mouse_entered() -> void:\n\thighlight()\n"
const MOUSE_EXITED := "extends Area2D\n\n\nfunc _ready() -> void:\n\tmouse_exited.connect(_on_mouse_exited)\n\n\nfunc _on_mouse_exited() -> void:\n\thighlight()\n"
const JOY_CONNECTION := "extends Node\n\n\nfunc _ready() -> void:\n\tInput.joy_connection_changed.connect(_on_pad)\n\n\nfunc _on_pad(device: int, connected: bool) -> void:\n\trefresh()\n"
const INPUT_EVENT := "extends Area2D\n\n\nfunc _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:\n\tif event is InputEventMouseButton and event.pressed:\n\t\tselect()\n"
const INPUT_EVENT_LOOSE := "extends Area2D\n\n\nfunc _input_event(vp, event, shape):\n\tif event is InputEventMouseButton and event.pressed:\n\t\tselect()\n"


static func run() -> bool:
	var ok: bool = true
	ok = _check("the cursor arriving reads as the Mouse's own words",
		_condition_lane(MOUSE_ENTERED), "Mouse | Cursor is over Area2D (enters)") and ok
	ok = _check("the cursor leaving is the same sentence, other edge",
		_condition_lane(MOUSE_EXITED), "Mouse | Cursor is over Area2D (leaves)") and ok
	ok = _check("the joypad connection signal reads on the Gamepad",
		_condition_lane(JOY_CONNECTION),
		"Gamepad | On gamepad connected / disconnected device connected") and ok
	ok = _check("input landing on a clickable body reads as a click on it",
		_condition_lane(INPUT_EVENT), "Mouse | On Area2D clicked") and ok
	ok = _check("the untyped spelling of that handler reads the same",
		_condition_lane(INPUT_EVENT_LOOSE), "Mouse | On Area2D clicked") and ok
	# The contract: none of the five moved a byte of the file they were read off.
	for entry: Array in [
		["the cursor handler", MOUSE_ENTERED], ["the cursor-leaving handler", MOUSE_EXITED],
		["the joypad connect line", JOY_CONNECTION], ["the clickable body", INPUT_EVENT],
		["the untyped clickable body", INPUT_EVENT_LOOSE]
	]:
		ok = _check("%s round-trips byte-identically" % str(entry[0]),
			_roundtrip(str(entry[1])), str(entry[1])) and ok
	return ok


## The condition lane of the sheet's first trigger row, as `<object> | <words>` - object first,
## because half of what each of these readings says is WHOSE news it is.
static func _condition_lane(source: String) -> String:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var object_label: String = ""
	var words: PackedStringArray = PackedStringArray()
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null:
			continue
		for span: SemanticSpan in row.spans:
			if not (span.metadata is Dictionary):
				continue
			var metadata: Dictionary = span.metadata as Dictionary
			if str(metadata.get("lane", "")) != "condition":
				continue
			if not str(metadata.get("kind", "")) in ["trigger", "trigger_payload"]:
				continue
			if object_label.is_empty():
				object_label = str(metadata.get("object_label", ""))
			words.append(str(span.text))
		if not words.is_empty():
			break
	dock.free()
	if words.is_empty():
		return "<none>"
	return "%s | %s" % [object_label, " ".join(words)]


## What the sheet writes back out for a file it just read.
static func _roundtrip(source: String) -> String:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	sheet.external_source_path = "user://eventforge_input_object_reading.gd"
	return str(SheetCompiler.compile(sheet, "user://eventforge_input_object_reading.gd").get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("input_object_reading_test", label, actual, expected)
