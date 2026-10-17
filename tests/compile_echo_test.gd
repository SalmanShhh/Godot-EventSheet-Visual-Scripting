@tool
extends RefCounted
# Godot EventSheets - reading what a sheet compiles to writes nothing. compile() with no path saves to
# the sheet's own file, so the windows that only show or check the code (the Manual's uses of a verb,
# Find References' line numbers, the Properties window, Loose Ends, Insert new object's preview) saved
# the open sheet's unsaved edits into its .gd, and a sheet with no file dropped a stray generated
# script declaring its class_name into the project. They ask echo() now.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "compile_echo_test"
const SOURCE := "user://eventforge_compile_echo_probe.gd"
const TRES := "user://eventforge_compile_echo_probe.tres"
const GENERATED := "user://eventforge_compile_echo_probe_generated.gd"


static func run() -> bool:
	var on_disk: String = "extends Node\n\n\nfunc _ready() -> void:\n\tpass\n"
	var file: FileAccess = FileAccess.open(SOURCE, FileAccess.WRITE)
	file.store_string(on_disk)
	file.close()
	# A script-backed sheet with an edit the reader has not saved.
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(on_disk)
	sheet.external_source_path = SOURCE
	var unsaved: RawCodeRow = RawCodeRow.new()
	unsaved.code = "var not_saved_yet: int = 0"
	sheet.events.append(unsaved)
	var echoed: Dictionary = SheetCompiler.echo(sheet)
	# A sheet kept as a resource, whose compile writes a generated script beside it.
	var kept: EventSheetResource = EventSheetResource.new()
	kept.take_over_path(TRES)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GENERATED))
	var kept_echo: Dictionary = SheetCompiler.echo(kept)
	var rows: Array = [
		["the echo holds the unsaved edit", str(echoed.get("output", "")).contains("not_saved_yet"), true],
		["and it compiled", bool(echoed.get("success", false)), true],
		["the sheet's own file is untouched", FileAccess.get_file_as_string(SOURCE), on_disk],
		["a resource sheet's echo compiles", bool(kept_echo.get("success", false)), true],
		["and leaves no generated script beside it", FileAccess.file_exists(GENERATED), false],
	]
	# compile() still writes, as Save needs it to.
	SheetCompiler.compile(sheet)
	rows.append(["compile() still saves to the sheet's file", FileAccess.get_file_as_string(SOURCE).contains("not_saved_yet"), true])
	for path: String in [SOURCE, GENERATED]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return SUPPORT.pins(NAME, rows)
