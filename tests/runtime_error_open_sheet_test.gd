# EventSheets - a run-time error from a script that is not open in a tab offers to open it. The error
# named a file and a line; only an open sheet could say which row wrote that line, so an error from any
# other script got its sentence and no address. The strip's button now says "Open the sheet", opens the
# script and then finds the row.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "runtime_error_open_sheet_test"
const SCRIPT_PATH := "res://tests/fixtures/runtime_error_open_probe.gd"
const SOURCE := "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"one\")\n\tprint(\"two\")\n"


static func run() -> bool:
	var file: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	if file == null:
		return SUPPORT.check(P, "the probe script can be written", false, true)
	file.store_string(SOURCE)
	file.close()
	EventSheetRuntimeErrorLocator.clear()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var tabs_before: int = dock._open_tabs.size()
	var report: Dictionary = dock.report_runtime_error("Invalid call. Nonexistent function 'two' in base 'Node'.", SCRIPT_PATH, 6)
	var rows: Array = [
		["no tab wrote that script, so the sheet is offered", str(report.get("open_path", "")), SCRIPT_PATH],
		["the button says so", dock._runtime_error_jump_button.text, "Open the sheet"],
		["and is live", dock._runtime_error_jump_button.disabled, false],
	]
	dock._jump_to_runtime_error_row()
	rows.append_array([
		["the script is now open in a tab of its own", dock._open_tabs.size(), tabs_before + 1],
		["and that tab is the one on screen", dock._current_sheet.external_source_path, SCRIPT_PATH],
		["the row is found", dock._runtime_error_report.get("row_resource") != null, true],
		["the offer is spent", str(dock._runtime_error_report.get("open_path", "")), ""],
	])
	# This plugin's own scripts and files that do not exist are never offered.
	rows.append_array([
		["nothing is offered for a file that is not there",
			load("res://addons/eventsheet/editor/dock/runtime_error_open.gd").sheet_to_open("res://tests/fixtures/nothing_here.gd", []), ""],
		["nor for this plugin's own scripts",
			load("res://addons/eventsheet/editor/dock/runtime_error_open.gd").sheet_to_open("res://addons/eventsheet/editor/dock/sheet_io.gd", []), ""],
		["nor when a tab already has it",
			load("res://addons/eventsheet/editor/dock/runtime_error_open.gd").sheet_to_open(SCRIPT_PATH, dock._open_tabs), ""],
	])
	dock.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRIPT_PATH))
	EventSheetRuntimeErrorLocator.clear()
	return SUPPORT.pins(P, rows)
