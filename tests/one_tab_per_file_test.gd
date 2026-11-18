# Godot EventSheets - asking for a file that is already open brings its tab forward.
#
# Two tabs of one file are two copies of it to edit, and saving one writes over the other's work. Every door
# that means "open this sheet" - the Open dialog, the Start page's recent sheets, the Project Doctor's findings,
# a runtime error's Open the sheet, the Include manager - goes through the one that re-focuses the tab.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "one_tab_per_file_test"
const SCRIPT_PATH := "res://demo/showcase/input_rebind/input_rebind.gd"


static func run() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.open_or_focus_sheet(SCRIPT_PATH)
	var one: int = dock._open_tabs.size()
	dock.reopen_sheet_path(SCRIPT_PATH)
	ok = SUPPORT.check(P, "reopening a sheet that is open keeps one tab of it", dock._open_tabs.size(), one) and ok
	load("res://addons/eventsheet/editor/dock/runtime_error_open.gd").open_sheet_of(dock, {"open_path": SCRIPT_PATH, "line": 1})
	ok = SUPPORT.check(P, "a runtime error's Open the sheet keeps one tab of it", dock._open_tabs.size(), one) and ok
	var forward: int = dock._active_tab_index
	dock.open_or_focus_sheet(SCRIPT_PATH)
	ok = SUPPORT.check(P, "and the tab of the file is the one in front", dock._active_tab_index, forward) and ok
	dock.free()
	return ok
