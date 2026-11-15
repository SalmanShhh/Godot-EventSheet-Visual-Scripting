# Godot EventSheets - the words of the "changed outside the editor" question, and what taking the file
# on disk does for a sheet saved as a resource (.tres). The question was only ever asked for script
# sheets, so a .tres changed by a merge or another tool, with the tab open and unsaved, was written
# over by the next Save. Loaded by path from the external watcher, which keeps the dialog itself.
@tool
extends RefCounted

## Where the unsaved version is written, as a resource, before it joins the backup ring.
const UNSAVED_COPY := "user://eventsheet_unsaved_before_reload.tres"


## The unsaved version of `sheet` into the file's backup ring, so taking the file on disk loses
## nothing for good. Returns the backup's path, "" when it could not be kept.
static func keep_unsaved(sheet: EventSheetResource, path: String) -> String:
	var kept: String = ""
	if ResourceSaver.save(sheet, UNSAVED_COPY) == OK:
		kept = EventSheetBackups.backup_bytes(path, FileAccess.get_file_as_bytes(UNSAVED_COPY))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(UNSAVED_COPY))
	return kept


## Reads the file again into the active tab: a fresh copy, not the cached one, put where the old sheet
## was so the undo history and the viewport start from what is on disk.
static func reload(dock: Control, path: String) -> void:
	var fresh: EventSheetResource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	if fresh == null:
		dock._set_status(EventSheetL10n.translate("%s could not be read as a sheet, so the version here was kept.") % path.get_file(), true)
		return
	fresh.take_over_path(path)
	var index: int = dock._active_tab_index
	dock._open_tabs[index] = {"sheet": fresh, "path": path, "dirty": false}
	dock._activate_tab(index)
	dock._external_mtime = FileAccess.get_modified_time(path)


## What the reload question says, and which answer is the safe one. With unsaved edits here, keeping
## them is the blue answer and the file on disk is the risky one; on a clean tab a reload loses
## nothing, so Reload is the blue answer and nothing is painted as dangerous. The list above the
## answers says, before anyone chooses, whether this tab has edits to lose and when the file changed
## (`changed_at` is its modification time, 0 when unknown).
static func reload_prompt(file_name: String, dirty: bool, changed_at: int = 0) -> Dictionary:
	var at: String = "" if changed_at <= 0 else Time.get_time_string_from_unix_time(
		changed_at + int(Time.get_time_zone_from_system().get("bias", 0)) * 60).left(5)
	var ask: Dictionary = {
		"list": [[EventSheetL10n.translate("This tab - unsaved edits") if dirty
				else EventSheetL10n.translate("This tab - nothing unsaved"), EventSheetL10n.translate("yours")],
			[EventSheetL10n.translate("On disk - changed at %s") % at if not at.is_empty()
				else EventSheetL10n.translate("On disk - changed"), EventSheetL10n.translate("the file")]],
		"title": EventSheetL10n.translate("%s changed outside the editor") % file_name,
		"say": EventSheetL10n.translate("The file on disk changed, and nothing here is unsaved. Show the new version?"),
		"note": EventSheetL10n.translate("Reloading reads its events again; there is nothing for Ctrl+Z to take back."),
		"glyph": "!",
		"main": EventSheetL10n.translate("Reload"),
		"cancel": EventSheetL10n.translate("Keep this version"),
	}
	if dirty:
		ask.merge({
			"say": EventSheetL10n.translate("The file on disk changed while you were editing it here. Which version do you want?"),
			"note": EventSheetL10n.translate("Using the file on disk keeps your unsaved edits as a backup in Sheet Backups first; Ctrl+Z cannot bring them back."),
			"main": EventSheetL10n.translate("Keep mine"),
			"cancel": "",
			"danger": EventSheetL10n.translate("Use the file on disk"),
		}, true)
	return ask
