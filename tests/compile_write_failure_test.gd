# EventSheets - the compiler says why it could not write a script. "Failed to open output path" named
# a path and no cause; the usual causes are a read-only file or a cloud-sync lock, and the write is
# atomic, so the reader is told nothing was overwritten.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "compile_write_failure_test"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var path: String = "user://no_such_folder_for_compile_write/out.gd"
	var result: Dictionary = EventSheetCompiler.compile(sheet, path)
	var errors: Array = result.get("errors", [])
	var text: String = str(errors[0]) if not errors.is_empty() else ""
	return SUPPORT.pins(P, [
		["the compile does not succeed", bool(result.get("success", true)), false],
		["the error names the file", text.contains(path), true],
		["the error says what usually causes it", text.contains("read-only"), true],
		["the error says nothing was overwritten", text.contains("Nothing was overwritten"), true],
		["the error says what to do", text.contains("then save again"), true],
		["the old wording is gone", text.contains("Failed to open"), false],
	])
