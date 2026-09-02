# The controls vocabulary reads BACK out of ordinary hand-written Godot.
#
# Every template in the controls module is the exact bytes a hand-written script writes for the same
# idea, which is the whole reason an opened file reads as those rows: the importer's reverse index is
# built from those very strings. This test proves both halves of that claim for each shape - the line
# becomes a ROW (not a grey code wall), and the file still re-emits byte for byte.
#
# A shape that could not reproduce its source would fail the byte gate rather than corrupt the file,
# so the round-trip check is the one that must never be dropped.
@tool
class_name ControlsLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## The hand-written lines this vocabulary claims, one per idea. Each is placed inside a lifecycle
## body and must come back as a row.
const LIFTED_ACTIONS: Array[String] = [
	"Input.action_press(\"jump\")",
	"Input.action_release(\"jump\")",
	"Input.parse_input_event(event)",
	"get_viewport().set_input_as_handled()",
	"Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)",
	"Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)",
	"Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)",
	"Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)",
	"Input.warp_mouse(Vector2(100, 100))",
	"InputMap.action_erase_events(\"jump\")",
	"InputMap.action_add_event(\"jump\", event)",
	"InputMap.load_from_project_settings()",
	"InputMap.action_set_deadzone(\"steer\", 0.2)",
	"Input.start_joy_vibration(0, 0.3, 0.8, 0.2)",
]

## The hand-written conditions this vocabulary claims. Each is the whole `if` of a lifecycle body.
const LIFTED_CONDITIONS: Array[String] = [
	"event is InputEventScreenDrag",
	"event is InputEventMagnifyGesture",
	"event is InputEventPanGesture",
	"event is InputEventMouseButton and event.double_click",
	"event is InputEventKey and event.is_echo()",
	"event is InputEventJoypadButton and event.pressed and event.device == 0 and event.button_index == JOY_BUTTON_A",
	"Input.is_action_pressed(\"jump\", true)",
	"InputMap.has_action(\"dash\")",
	"not Input.get_connected_joypads().is_empty()",
	"Input.get_accelerometer().x > 5",
]


static func run() -> bool:
	var passed: bool = true
	for line: String in LIFTED_ACTIONS:
		var source: String = _action_source(line)
		passed = _check("action lifts to a row: %s" % line, _structured(source), true) and passed
		passed = _check("action round-trips byte-identically: %s" % line,
			_recompile(source), source) and passed
	for expression: String in LIFTED_CONDITIONS:
		var source: String = _condition_source(expression)
		passed = _check("condition lifts to a row: %s" % expression, _structured(source), true) and passed
		passed = _check("condition round-trips byte-identically: %s" % expression,
			_recompile(source), source) and passed
	passed = _check_sensor_locals() and passed
	return passed


## `var a = Input.get_accelerometer()` is a Local variable row, not a code cell, and the value
## it is set to reads in the Touch object's words.
static func _check_sensor_locals() -> bool:
	var source: String = "extends Node\n\n\nfunc _process(delta: float) -> void:\n\tvar a = Input.get_accelerometer()\n\tvar g = Input.get_gravity()\n"
	var passed: bool = _check("a sensor local lifts to a row", _structured(source), true)
	passed = _check("a sensor local round-trips byte-identically", _recompile(source), source) and passed
	passed = _check("the value it is set to reads in the Touch object's words",
		EventSheetSentence.expression_text("Input.get_accelerometer()"), "acceleration") and passed
	return passed


static func _action_source(line: String) -> String:
	return "extends Node\n\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\t%s\n" % line


static func _condition_source(expression: String) -> String:
	return "extends Node\n\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif %s:\n\t\tfired = true\n" % expression


## True when the body became rows rather than a verbatim `func …` wall.
static func _structured(source: String) -> bool:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var has_structure: bool = false
	if not imported.functions.is_empty():
		has_structure = true
	for row: Variant in imported.events:
		if row is EventRow:
			has_structure = true
		if row is RawCodeRow and (row as RawCodeRow).code.begins_with("func "):
			return false
	return has_structure


static func _recompile(source: String) -> String:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	imported.external_source_path = "user://controls_lift_rt.gd"
	return str(SheetCompiler.compile(imported, "user://controls_lift_rt.gd").get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("controls_lift_test", label, actual, expected)
