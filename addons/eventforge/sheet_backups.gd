# Godot EventSheets - save-time backup ring for sheets
#
# Every save of an existing sheet (.tres, .res, or a GDScript-backed .gd) first copies the
# file's pre-save bytes into a per-sheet ring under user://eventsheet_backups/ (outside the project: no git noise,
# no export pollution). The ring keeps the newest N (eventsheets/editor/backup_count,
# default 10; 0 disables) so a bad save, a wrong-sheet overwrite or an editor crash
# never costs more than one save's worth of work - git-grade safety for the
# non-programmer half of the audience who won't have git discipline yet.
#
# Restore goes through the dock (Tools → Sheet Backups…): a backup loads INTO the
# editor as an unsaved change - the user reviews and saves to keep it, so a restore
# never silently rewrites a file (and the pre-restore state is itself backed up by
# the save that follows).
@tool
class_name EventSheetBackups
extends RefCounted

const BACKUPS_ROOT := "user://eventsheet_backups"


static func backup_count() -> int:
	return int(ProjectSettings.get_setting("eventsheets/editor/backup_count", 10))


## One folder per sheet path, flattened so res:// and user:// sheets can't collide.
static func backup_dir_for(sheet_path: String) -> String:
	var sanitized: String = sheet_path.replace("://", "_").replace("/", "_").replace(":", "_")
	return "%s/%s" % [BACKUPS_ROOT, sanitized]


## All backups of a sheet, newest first. Filenames are zero-padded sequence numbers
## ("0002.player.tres") so lexicographic order IS age order - timestamps would collide
## on same-second saves.
static func list_backups(sheet_path: String) -> PackedStringArray:
	var dir_path: String = backup_dir_for(sheet_path)
	var backups: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return backups
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and (entry.ends_with(".tres") or entry.ends_with(".res") or entry.ends_with(".gd")):
			backups.append("%s/%s" % [dir_path, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	backups.sort()
	backups.reverse()
	return backups


## Copies the sheet file's CURRENT bytes into the ring and prunes past backup_count.
## Returns the backup path, or "" when disabled or there's nothing to back up yet.
static func backup_sheet(sheet_path: String) -> String:
	var keep: int = backup_count()
	if keep <= 0 or not FileAccess.file_exists(sheet_path):
		return ""
	var dir_path: String = backup_dir_for(sheet_path)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var existing: PackedStringArray = list_backups(sheet_path)
	var current_bytes: PackedByteArray = FileAccess.get_file_as_bytes(sheet_path)
	var next_index: int = 1
	if not existing.is_empty():
		# Identical to the newest backup: nothing new to protect - don't churn the ring
		# (GDScript-backed sheets back up on EVERY save now, most of which are no-ops).
		if FileAccess.get_file_as_bytes(existing[0]) == current_bytes:
			return existing[0]
		next_index = int(existing[0].get_file().get_slice(".", 0)) + 1
	var backup_path: String = "%s/%04d.%s" % [dir_path, next_index, sheet_path.get_file()]
	var out: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(current_bytes)
	out.close()
	var all_backups: PackedStringArray = list_backups(sheet_path)
	for index in range(keep, all_backups.size()):
		DirAccess.remove_absolute(all_backups[index])
	return backup_path
