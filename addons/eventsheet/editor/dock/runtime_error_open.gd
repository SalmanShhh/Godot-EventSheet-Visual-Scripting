# Godot EventSheets - the door from a run-time error to a sheet that is not open. The error names a
# script and a line; the row it came from can only be found in a sheet that is open in a tab, and an
# error from any other script got its sentence and no address. When the script is a project script,
# the strip's button says "Open the sheet", opens it, and then finds the row as it would have if the
# tab had been there. Loaded by path from the dock, only when an error arrives.
@tool
extends RefCounted

## Folders of this plugin's own scripts: an error there is not about a sheet of the reader's.
const OWN_FOLDERS: PackedStringArray = ["res://addons/eventforge/", "res://addons/eventsheet/"]


## The script to open for an error that no open tab wrote, "" when there is none to offer. `tabs` is
## the dock's list of open tabs.
static func sheet_to_open(script_path: String, tabs: Array) -> String:
	var path: String = script_path.strip_edges()
	if EventSheetRuntimeErrorLocator.tab_for(tabs, path) >= 0 or path.get_extension() != "gd" or not path.begins_with("res://") or not FileAccess.file_exists(path):
		return ""
	for folder: String in OWN_FOLDERS:
		if path.begins_with(folder):
			return ""
	return path


## What the strip's button says: the row to jump to, or the sheet to open first.
static func jump_label(report: Dictionary) -> String:
	if not str(report.get("open_path", "")).is_empty():
		return EventSheetL10n.translate("Open the sheet")
	return EventSheetL10n.translate("Jump to event")


## Opens the script as a sheet and finds the row of the failing line, writing both into `report` so
## the ordinary jump carries on from there.
static func open_sheet_of(dock: Control, report: Dictionary) -> void:
	var path: String = str(report.get("open_path", ""))
	dock._navigate.open_or_focus(path)
	var located: Dictionary = dock._locate_runtime_error_row(path, int(report.get("line", 0)))
	report["row_resource"] = located.get("resource")
	report["tab_index"] = int(located.get("tab_index", -1))
	report["candidates"] = located.get("candidates", [])
	report["open_path"] = ""
