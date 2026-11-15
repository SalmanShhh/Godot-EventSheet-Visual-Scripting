@tool
extends RefCounted
# "Use in event sheets", the FileSystem right-click on a script of yours: the whole flow behind the one
# entry. A script that is not in use yet is told to every sheet at once and the status line says how many
# rows it added; a script that already gives sheets rows opens its window instead.
#
# Loaded by path by the plugin when the entry is clicked, so nothing here is compiled at editor boot and
# the context-menu file that calls it never names the public API or the reader. No class_name.

const EVENTSHEETS_API_PATH := "res://addons/eventsheet/api/eventsheets.gd"
const SCANNER_PATH := "res://addons/eventsheet/ace/project_scanner.gd"
const PROVIDER_PREVIEW_PATH := "res://addons/eventsheet/ace/provider_preview.gd"


## Runs the entry for `path` against the open workspace `dock`. Returns the sentence it said.
static func use(path: String, dock: Control) -> String:
	if load(SCANNER_PATH).script_is_in_use(path):
		if dock != null:
			dock._providers_glue.on_manage_ace_providers_requested(path)
		return ""
	var added: bool = load(EVENTSHEETS_API_PATH).use_script_in_sheets(path)
	var message: String = rows_added_text(path) if added else EventSheetL10n.translate("%s could not be used in event sheets.") % path.get_file()
	if dock != null:
		dock._set_status(message, not added)
	return message


## "<file>: N rows added" - what the click did, counted from the same scan the window draws from.
static func rows_added_text(path: String) -> String:
	var count: int = 0
	for entry: Variant in load(PROVIDER_PREVIEW_PATH).scan(path).get("entries", []):
		if not bool((entry as Dictionary).get("left_out", false)):
			count += 1
	if count == 0:
		return EventSheetL10n.translate("%s: no rows added. Give the script a class_name, so its functions have a name to be called by.") % path.get_file()
	return EventSheetL10n.translate("%s: %d rows added") % [path.get_file(), count]
