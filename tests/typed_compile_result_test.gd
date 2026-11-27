# Godot EventSheets - the compile answered as a typed object, beside the Dictionary the API always gave.
#
# `EventSheets.compile_result()` and `echo_result()` carry the same facts as `compile()` and `echo()`, as
# variables a script editor completes. The Dictionary calls are not touched; this pins that the two
# agree, that a failure keeps its sentence, and that a Dictionary missing keys reads as empty values.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "typed_compile_result_test"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheets.new_sheet({"base_class": "Node"})
	var as_dictionary: Dictionary = EventSheets.echo(sheet)
	var typed: EventSheetCompileResult = EventSheets.echo_result(sheet)
	var broken: EventSheetCompileResult = EventSheets.echo_result(null)
	var from_nothing: EventSheetCompileResult = EventSheetCompileResult.from_dictionary({})
	var rows: Array = [
		["echo_result says what echo says: success", typed.success, bool(as_dictionary["success"])],
		["echo_result says what echo says: the code", typed.output, str(as_dictionary["output"])],
		["the code is not empty", typed.output.is_empty(), false],
		["a clean compile has no errors", typed.errors.size(), 0],
		["warnings are the same sentences", typed.warnings, PackedStringArray(as_dictionary["warnings"])],
		["a sheet that is not there is a failure", broken.success, false],
		["and it says so in a sentence", broken.errors.size(), 1],
		["a Dictionary with nothing in it is a failed compile with no code", [from_nothing.success, from_nothing.output, from_nothing.refused_path], [false, "", ""]],
		["compile_result with no file writes nothing and still answers", EventSheets.compile_result(sheet).output, typed.output],
	]
	return SUPPORT.pins(TEST_NAME, rows)
