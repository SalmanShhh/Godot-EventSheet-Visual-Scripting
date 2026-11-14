# EventSheets - the Class window reads the sheet's code without writing it. Typing a new `extends` makes
# the window compile the open sheet to find the members the new base would lose; that compile must
# produce text and touch no file, because the rows in memory may hold edits the user has not saved
# and may not want to keep.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const WINDOW_PATH := "res://addons/eventsheet/editor/dock/class_window.gd"
const FILE_PATH := "user://class_window_no_write_probe.gd"
const SOURCE := "extends Node2D\n\nvar speed: int = 3\n"


static func run() -> bool:
	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(FILE_PATH)
	if sheet == null:
		return SUPPORT.check("class_window_no_write_test", "the probe file opens as a sheet", false, true)
	# An unsaved edit: it exists only in memory.
	(sheet.events[1] as LocalVariable).default_value = 99
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = "extends Control\nvar _current_sheet = null\n"
	stub_script.reload()
	var stub: Control = Control.new()
	stub.set_script(stub_script)
	stub.set("_current_sheet", sheet)
	var window: RefCounted = load(WINDOW_PATH).new()
	window.init(stub, null)
	var used: String = window._used_text()
	var on_disk: String = FileAccess.get_file_as_string(FILE_PATH)
	stub.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_PATH))
	var ok: bool = run_parse_error_marks()
	return SUPPORT.pins("class_window_no_write_test", [
		["the window reads the unsaved edit", used.contains("= 99"), true],
		["the file on disk is exactly what it was", on_disk, SOURCE],
	]) and ok


## Opening a file with an engine parse error marks the row it sits on, and it asks the compiler for the
## source map to do so. That is a question about the sheet, so it must leave the file alone, whatever
## the rows in memory hold at that moment.
static func run_parse_error_marks() -> bool:
	var path: String = "user://parse_error_marks_probe.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(path)
	if sheet == null:
		return SUPPORT.check("class_window_no_write_test", "the parse error probe opens as a sheet", false, true)
	(sheet.events[1] as LocalVariable).default_value = 99
	EventSheetParseErrors.store_on_sheet(sheet, [{"line": 3, "message": "probe"}])
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = "extends Control\nvar _viewport = null\n"
	stub_script.reload()
	var stub: Control = Control.new()
	stub.set_script(stub_script)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	stub.set("_viewport", viewport)
	var io: EventSheetSheetIO = EventSheetSheetIO.new()
	io._dock = stub
	io._flag_parse_error_rows(sheet, path)
	var on_disk: String = FileAccess.get_file_as_string(path)
	viewport.free()
	stub.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return SUPPORT.check("class_window_no_write_test", "marking parse errors leaves the file as it was", on_disk, SOURCE)
