# Godot EventSheets - what a restore from Sheet Backups keeps of the sheet it replaces
#
# Restoring a backup copies it over the open sheet, which also clears the undo history: whatever was
# unsaved in the tab is gone for good unless it is put somewhere first. This puts it in the sheet's own
# backup ring, in the form the ring holds for that file (script text for a script, the resource for a
# resource sheet), so the next Restore lists it. Loaded by path from the dock.
@tool
extends RefCounted


## Keeps the open sheet's current, unsaved state in its backup ring. Returns the backup's path, or ""
## when nothing could be kept (backups switched off, or the file has no name yet).
static func keep_unsaved_state(sheet: EventSheetResource, path: String) -> String:
	if sheet == null or path.is_empty():
		return ""
	if path.get_extension().to_lower() == "gd":
		var text: String = str(EventSheetCompiler.echo(sheet).get("output", ""))
		return "" if text.is_empty() else EventSheetBackups.backup_bytes(path, text.to_utf8_buffer())
	return load("res://addons/eventsheet/editor/dock/reload_from_disk.gd").keep_unsaved(sheet, path)
