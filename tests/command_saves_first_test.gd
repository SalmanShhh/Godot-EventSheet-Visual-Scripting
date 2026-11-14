# EventSheets - a command that needs the sheet's script on disk saves the sheet the way Save does.
# Run now and Reload compile the open sheet to its script. With edits not yet saved they used to write
# the script directly: no backup of the version before, and the tab still marked unsaved afterwards.
# They now go through the same save as the Save button, so the version before is kept in the backup
# ring and the tab is clean.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PATH: String = "user://command_saves_first_probe.gd"
const SOURCE: String = "extends Node\n\n\nfunc _run() -> void:\n\tpass\n"


static func run() -> bool:
	var ok: bool = true
	for command: String in ["run_now", "reload"]:
		ok = _command_saves_first(command) and ok
	return ok


static func _command_saves_first(command: String) -> bool:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock._load_sheet_from_path(PATH)
	dock._preview_glue._on_preview_edit_requested()
	dock._perform_undoable_sheet_edit("Add a note", func() -> bool:
		var comment: CommentRow = CommentRow.new()
		comment.text = "unsaved note"
		dock._current_sheet.events.append(comment)
		return true)
	dock._mark_dirty("Add a note")
	var was_dirty: bool = dock._dirty
	dock._editor_tool_bar.call(command)
	var backups: PackedStringArray = EventSheetBackups.list_backups(PATH)
	var newest_backup: String = FileAccess.get_file_as_string(backups[0]) if not backups.is_empty() else "<no backup>"
	var results: Array = [
		["the edit was unsaved before the command", was_dirty, true],
		["the tab is clean after it", dock._dirty, false],
		["the script holds the edit", FileAccess.get_file_as_string(PATH).contains("unsaved note"), true],
		["the version before is in the backup ring", newest_backup, SOURCE],
	]
	dock.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var labelled: Array = []
	for row: Array in results:
		labelled.append(["%s: %s" % [command, row[0]], row[1], row[2]])
	return SUPPORT.pins("command_saves_first_test", labelled)
