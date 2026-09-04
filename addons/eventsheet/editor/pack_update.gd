# Godot EventSheets - A PACK UPDATE IS A PROPOSAL.
#
# Taking a pack's new version is not an install. The pack was COPIED into the project on purpose, so
# by the time an update arrives some of those files are the project's own - edited, extended, or left
# exactly as they landed - and only the project can say which. This file works out the proposal; the
# dialog shows it; nothing here writes a byte until somebody presses the button.
#
# THE TRI-LIST, BEFORE A BYTE MOVES.
#   UNTOUCHED - the file still hashes to what arrived, so the new version's answer is taken for it.
#               LISTED, never silent: "we replaced eleven files you never opened" is something the
#               reader gets to read before it happens, not after.
#   YOURS     - the file differs from what arrived. One choice per file: keep mine, take new, or see
#               the diff. The default is KEEP MINE, because an update that quietly overwrote
#               somebody's work would only have to be wrong once.
#   VOCABULARY- what the new version retires and adds, derived by DIFFING THE TWO VERSIONS' REGISTRY
#               DUMPS rather than by reading a release note. A retired verb still compiles exactly as
#               before - retiring means a forwarding address, never a deleted template - so the row
#               that mentions it opens the migrate dry run rather than demanding anything.
#
# THE OLD VERSION GOES TO THE BACKUP RING FIRST. Every file this is about to overwrite or remove is
# copied into the same per-file ring a sheet save uses, before the first write, and the line the
# dialog prints afterwards says how many went and where they are.
#
# AND THE RING HAS A DOOR. The editor's own Restore menu restores the SHEET IN FRONT OF YOU, which a
# pack's guide, icon or translation table never is; those used to be recovered by copying a file out
# of a folder by hand. `restorable()` lists what the ring holds for one pack and `restore()` puts one
# entry back as an UNDOABLE FILE WRITE with a receipt - the bytes that were there are what Ctrl+Z
# writes, so a restore is as reversible as any other edit. Nothing here ever writes to the ring: it
# is read, listed and copied out of, and only a save or an update ever adds to it. A door that
# pruned the ring while restoring from it would be a door that eats the thing it is for.
#
# NOTHING IS DERIVED FROM A DATE. What arrived is known because the attach hashed it into the pack's
# own manifest; a file's mtime, a version string and a folder's age are all things a checkout can
# move without a byte changing, and none of them is consulted here.
@tool
class_name EventSheetPackUpdate
extends RefCounted

## What may be decided about one file.
const CHOICE_TAKE_NEW: String = "take_new"
const CHOICE_KEEP_MINE: String = "keep_mine"

## What the new version does to one file, independent of who decides it.
const CHANGE_SAME: String = "same"
const CHANGE_REPLACED: String = "replaced"
const CHANGE_ADDED: String = "added"
const CHANGE_REMOVED: String = "removed"

## Where an incoming pack script is written so its vocabulary can be reflected. `user://`, because
## reading a version's verbs must not put a single byte of it under res:// before it is taken.
##
## A FOLDER rather than a fixed file name, because the copy has to keep the pack script's OWN name:
## a pack that declares no `class_name` takes its provider id from its file name, so reflecting the
## incoming version under a holding name of our own would give every one of its verbs a
## different key - and the diff would then report the whole vocabulary as retired and re-added.
const REFLECT_DIR: String = "user://eventsheet_pack_update_reflect"


# ── What is being offered ─────────────────────────────────────────────────────────────────────


## The files an incoming pack archive holds for one pack, as {relative path: bytes}. Entries are
## taken from under the pack's own folder when the archive is rooted at eventsheet_addons/, and
## from the archive root when it is rooted at the pack itself - both are shapes people really send.
## An entry that would write outside the pack folder is refused by returning {} for the whole
## archive: half an update is worse than none.
static func read_zip(zip_path: String, pack_dir: String) -> Dictionary:
	var reader: ZIPReader = ZIPReader.new()
	if not FileAccess.file_exists(zip_path) or reader.open(zip_path) != OK:
		return {}
	var entries: PackedStringArray = reader.get_files()
	var prefixes: PackedStringArray = PackedStringArray(["%s/" % pack_dir, "eventsheet_addons/%s/" % pack_dir])
	var incoming: Dictionary = {}
	for entry: String in entries:
		if entry.ends_with("/"):
			continue
		if not EventSheetAddonManagerDialog.is_safe_entry(entry):
			reader.close()
			return {}
		var relative: String = entry
		for prefix: String in prefixes:
			if entry.begins_with(prefix):
				relative = entry.substr(prefix.length())
				break
		if relative == entry and entry.contains("/"):
			# An archive rooted at some other folder entirely. Its own top folder is taken as the
			# pack, which is what an author who zipped their working directory produced.
			relative = entry.substr(entry.find("/") + 1)
		if relative.is_empty() or relative == EventSheetPackManifest.MANIFEST_FILE:
			# The record is written by THIS project's attach, never taken from the sender.
			continue
		if EventSheetPackManifest.IGNORED_EXTENSIONS.has(relative.get_extension()):
			continue
		incoming[relative] = reader.read_file(entry)
	reader.close()
	return incoming


## The whole proposal: {"untouched": rows, "yours": rows, "unrecorded": bool, "pack": dir}, each row
## {"path", "state", "change", "note"} and each list sorted by path.
##
## A pack with no attach record answers UNRECORDED and puts EVERY file under "yours" - "we do not
## know what you changed" is a different sentence from "you changed nothing", and only one of them
## is true.
static func plan(pack_folder: String, incoming: Dictionary) -> Dictionary:
	var record: Dictionary = EventSheetPackManifest.read(pack_folder)
	var paths: Dictionary = {}
	for relative: String in EventSheetPackManifest.files_of(pack_folder):
		paths[relative] = true
	for relative: Variant in incoming.keys():
		paths[str(relative)] = true
	var sorted: PackedStringArray = PackedStringArray()
	for relative: Variant in paths.keys():
		sorted.append(str(relative))
	sorted.sort()
	var untouched: Array[Dictionary] = []
	var yours: Array[Dictionary] = []
	for relative: String in sorted:
		var row: Dictionary = _row_for(pack_folder, relative, incoming, record)
		if str(row["state"]) == EventSheetPackManifest.STATE_UNTOUCHED:
			untouched.append(row)
		else:
			yours.append(row)
	return {
		"pack": pack_folder.get_file(),
		"unrecorded": record.is_empty(),
		"untouched": untouched,
		"yours": yours,
	}


## One file's row: what the project did to it, and what the new version does with it.
static func _row_for(pack_folder: String, relative: String, incoming: Dictionary,
		record: Dictionary) -> Dictionary:
	var installed_path: String = pack_folder.path_join(relative)
	var here: bool = FileAccess.file_exists(installed_path)
	var arriving: bool = incoming.has(relative)
	var change: String = CHANGE_SAME
	if here and not arriving:
		change = CHANGE_REMOVED
	elif arriving and not here:
		change = CHANGE_ADDED
	elif here and arriving:
		var installed_hash: String = EventSheetPackManifest.hash_file(installed_path)
		var incoming_hash: String = EventSheetPackManifest.hash_bytes(incoming[relative])
		change = CHANGE_SAME if installed_hash == incoming_hash else CHANGE_REPLACED
	var row: Dictionary = EventSheetPackManifest.classify_one(pack_folder, relative, record)
	# A file the new version BRINGS was never here to be touched, so it is not a question: it lands.
	if change == CHANGE_ADDED:
		row["state"] = EventSheetPackManifest.STATE_UNTOUCHED
		row["note"] = ""
	elif str(row["state"]) == EventSheetPackManifest.STATE_UNRECORDED:
		# Nothing is known about this file, so it is treated as the reader's until they say otherwise.
		row["state"] = EventSheetPackManifest.STATE_YOURS
	row["change"] = change
	return row


## What one row does unless the reader says otherwise: the new version's answer for a file nobody
## touched, and the reader's own file for everything else.
static func default_choice(row: Dictionary) -> String:
	return CHOICE_TAKE_NEW if str(row.get("state", "")) == EventSheetPackManifest.STATE_UNTOUCHED \
		else CHOICE_KEEP_MINE


# ── What the vocabulary does ──────────────────────────────────────────────────────────────────


## The registry diff between the installed version of a pack and the incoming one, as
## `EventForgeRegistryDump.diff()` returns it. The dialog's vocabulary section is THIS - never prose
## the sender wrote about their own release, and never a second reflection of its own.
##
## The incoming script is written to `user://` and reflected there. Reflecting a pack means
## instantiating it, which is what the registry already does for every pack the project has
## installed; doing it under `user://` keeps the version being ASKED ABOUT out of res:// until it is
## taken, and the file is removed again either way.
static func vocabulary(pack_folder: String, incoming: Dictionary) -> Dictionary:
	return _reflected(pack_folder, incoming).get("diff", {
		"retired": [], "added": [], "changed": [], "readable": false})


## The vocabulary a project would have IF this update were taken: the incoming version's verbs laid
## over the installed catalogue. It is what the dry run has to answer against - the dialog's own
## button promises "every row that would be rewritten", and answering that against the packs the
## project has TODAY shows what the update's forwarding addresses would do only by accident, which
## for an update that adds one is never.
##
## {} when the incoming archive holds no script for this pack, which is the same answer `vocabulary`
## gives that case.
static func vocabulary_after(pack_folder: String, incoming: Dictionary) -> Dictionary:
	var incoming_entries: Dictionary = _reflected(pack_folder, incoming).get("entries", {})
	if incoming_entries.is_empty():
		return {}
	var merged: Dictionary = EventForgeSuccessors.catalog().duplicate()
	for key: Variant in incoming_entries.keys():
		merged[str(key)] = incoming_entries[key]
	return merged


## The one reflection both answers above come out of: {"diff", "entries"}, `entries` being the
## incoming version's own catalogue. Reflected ONCE, because reflecting a pack means writing it out
## and instantiating it, and doing that twice for two questions about one archive is the same answer
## computed twice.
static func _reflected(pack_folder: String, incoming: Dictionary) -> Dictionary:
	var installed_script: String = EventSheetPackCatalog.main_script_for(
		pack_folder.get_file(), pack_folder.get_base_dir())
	var unreadable: Dictionary = {"diff": {"retired": [], "added": [], "changed": [],
		"readable": false}, "entries": {}}
	if installed_script.is_empty():
		return unreadable
	var relative: String = installed_script.trim_prefix("%s/" % pack_folder)
	if not incoming.has(relative):
		return unreadable
	DirAccess.make_dir_recursive_absolute(REFLECT_DIR)
	var reflect_path: String = REFLECT_DIR.path_join(installed_script.get_file())
	var file: FileAccess = FileAccess.open(reflect_path, FileAccess.WRITE)
	if file == null:
		return unreadable
	file.store_buffer(incoming[relative])
	file.close()
	var before: String = EventForgeRegistryDump.for_script(installed_script)
	var entries: Dictionary = EventForgeRegistryDump.entries_of_script(reflect_path)
	var after: String = EventForgeRegistryDump.text(entries)
	DirAccess.remove_absolute(reflect_path)
	DirAccess.remove_absolute(REFLECT_DIR)
	return {"diff": EventForgeRegistryDump.diff(before, after), "entries": entries}


# ── Taking it ─────────────────────────────────────────────────────────────────────────────────


## Writes the update. Every file about to be overwritten or removed goes into the backup ring FIRST,
## so the previous version is one restore away before the first new byte lands. Returns
## {"written", "removed", "kept", "backed_up"} - counts, so a caller can say what happened.
##
## `choices` maps a row's path to CHOICE_*; a path it does not name takes `default_choice`.
##
## `version` is what the record should say this folder now holds. Left empty it is READ BACK OFF THE
## FOLDER once the writing is done, which is the only reading that can be right: the field exists so
## a later update can say what it is updating FROM, and stamping it blank made the second update of
## any pack blind. The attach path passes the version it read out of the archive; an update has no
## such reading of its own until the files are on disk, so it takes it from there.
static func apply(pack_folder: String, incoming: Dictionary, update_plan: Dictionary,
		choices: Dictionary, version: String = "") -> Dictionary:
	var rows: Array[Dictionary] = []
	rows.append_array(update_plan.get("untouched", []) as Array)
	rows.append_array(update_plan.get("yours", []) as Array)
	var written: int = 0
	var removed: int = 0
	var kept: int = 0
	var backed_up: int = 0
	for row: Dictionary in rows:
		var relative: String = str(row.get("path", ""))
		var change: String = str(row.get("change", CHANGE_SAME))
		var choice: String = str(choices.get(relative, default_choice(row)))
		if change == CHANGE_SAME or choice == CHOICE_KEEP_MINE:
			kept += 1 if change != CHANGE_SAME else 0
			continue
		var target: String = pack_folder.path_join(relative)
		if FileAccess.file_exists(target) and not EventSheetBackups.backup_sheet(target).is_empty():
			backed_up += 1
		if change == CHANGE_REMOVED:
			DirAccess.remove_absolute(target)
			removed += 1
			continue
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			continue
		file.store_buffer(incoming[relative])
		file.close()
		written += 1
	# The record is re-stamped over the folder as it now stands, so the NEXT update asks its question
	# against what this one actually left behind - kept files and taken files alike, and the version
	# the folder now declares rather than a blank.
	EventSheetPackManifest.stamp(pack_folder, version if not version.is_empty() \
		else installed_version(pack_folder))
	return {"written": written, "removed": removed, "kept": kept, "backed_up": backed_up}


## What version the pack in this folder says it is, read off the folder itself. "" when it does not
## say, which is a fine thing for a pack not to say and a bad thing to invent.
static func installed_version(pack_folder: String) -> String:
	return EventSheetPackCatalog.version_of(EventSheetPackCatalog.main_script_for(
		pack_folder.get_file(), pack_folder.get_base_dir())).strip_edges()


## Where the previous bytes of everything this update overwrote or removed are, in words a reader can
## act on. The ring is per-file and it is the same one a sheet save uses, so a pack file that was
## taken over is one restore away in the same place every other backup in this project lives.
static func backup_note(done: Dictionary) -> String:
	var rung: int = int(done.get("backed_up", 0))
	if rung <= 0:
		return ""
	return EventSheetL10n.translate(" The previous bytes of those %d file(s) are in the backup ring, under %s - Restore… on this pack's row lists them.") % [
		rung, EventSheetBackups.BACKUPS_ROOT]


# ── The way back ───────────────────────────────────────────────────────────────────────


## Every previous version of this pack's files the backup ring is holding, newest first within each
## file and files in path order, as {"path", "target", "backup", "when", "bytes", "gone"}:
##   `path`   the file's place inside the pack, which is how a reader knows what they are looking at;
##   `target` where it would be written back;
##   `backup` the ring entry itself;
##   `when`   when that entry was written, as a sortable UTC string;
##   `bytes`  how big it is;
##   `gone`   true when the pack no longer has that file at all - an update that REMOVED one still
##            backed it up first, and that is exactly the case somebody comes here for.
##
## THE CANDIDATES ARE NAMED, AND THE ONE THAT CANNOT BE IS PROVED. The pack itself says which files
## it has - the folder as it stands now, plus every file the attach record wrote down - and each of
## those is asked for its own ring.
##
## That leaves the row somebody actually comes here for: a file an UPDATE REMOVED. It backed the file
## up first and then re-stamped the record over the folder it left, so neither source mentions it any
## more and only the ring remembers it existed. A ring folder is the file's whole path with its
## separators replaced by underscores, which is many-to-one - `a_b/c.md` and `a/b/c.md` spell it the
## same way - so reading one backwards is guessing, and guessing a path this would then WRITE to is
## the one thing a door like this must never do. So the reconstruction is only taken when it cannot
## be wrong: a ring entry is named `<sequence>.<the file's own name>`, and when that name is the
## whole of what follows the pack's own prefix, the file sat at the top of the pack folder and there
## is nothing left to guess. A removed file deeper in the folder is not offered, rather than offered
## at a path invented for it.
static func restorable(pack_folder: String) -> Array[Dictionary]:
	var candidates: PackedStringArray = EventSheetPackManifest.files_of(pack_folder)
	var recorded: Variant = EventSheetPackManifest.read(pack_folder).get("files", {})
	if recorded is Dictionary:
		for relative: Variant in (recorded as Dictionary).keys():
			if not candidates.has(str(relative)):
				candidates.append(str(relative))
	for orphan: String in _ring_only_files(pack_folder):
		if not candidates.has(orphan):
			candidates.append(orphan)
	candidates.sort()
	var listed: Array[Dictionary] = []
	for relative: String in candidates:
		var target: String = pack_folder.path_join(relative)
		for backup: String in EventSheetBackups.list_backups(target):
			listed.append({
				"path": relative,
				"target": target,
				"backup": backup,
				"when": Time.get_datetime_string_from_unix_time(
					FileAccess.get_modified_time(backup), true),
				"bytes": FileAccess.get_file_as_bytes(backup).size(),
				"gone": not FileAccess.file_exists(target),
			})
	return listed


## The top-level files of this pack the ring is holding and the pack itself no longer mentions - the
## ones an update removed. Read out of the ring's own folder names, and only where the name says the
## whole answer: the ring entry inside carries the file's own name, and a folder whose name is the
## pack's prefix plus exactly that name can only have come from a file at the top of the pack folder.
## Anything else is left alone rather than reconstructed.
static func _ring_only_files(pack_folder: String) -> PackedStringArray:
	var prefix: String = "%s_" % EventSheetBackups.backup_dir_for(pack_folder).get_file()
	var found: PackedStringArray = PackedStringArray()
	# THE RING ROOT IS NOT THERE UNTIL SOMETHING FILLS IT, and a project that has never taken an
	# update is the ordinary state of a fresh one. `DirAccess.get_directories_at` answers a missing
	# folder with an empty list AND an engine error in the Output panel, so pressing Restore… on such
	# a project got the manager's polite "holding nothing" sentence with a red line underneath it.
	if not DirAccess.dir_exists_absolute(EventSheetBackups.BACKUPS_ROOT):
		return found
	for ring_name: String in DirAccess.get_directories_at(EventSheetBackups.BACKUPS_ROOT):
		if not ring_name.begins_with(prefix):
			continue
		var suffix: String = ring_name.substr(prefix.length())
		if suffix.is_empty() or suffix.contains("/"):
			continue
		for entry: String in DirAccess.get_files_at(
				EventSheetBackups.BACKUPS_ROOT.path_join(ring_name)):
			# `<four digits>.<the file's own name>` - the ring's own spelling, and the only part of a
			# folder name that is not a lossy encoding of a path.
			if entry.length() > 5 and entry.substr(5) == suffix and not found.has(suffix):
				found.append(suffix)
	found.sort()
	return found


## One listed entry as the line the window shows. Pure over the entry, so the suite reads exactly
## what a reader reads without opening a window - and so the TIME in it is the ring's own fact rather
## than the moment the list was drawn.
static func restore_line(entry: Dictionary) -> String:
	var line: String = "%s - %s, %d byte(s)" % [str(entry.get("path", "")),
		str(entry.get("when", "")), int(entry.get("bytes", 0))]
	if bool(entry.get("gone", false)):
		return "%s (%s)" % [line, EventSheetL10n.translate("this file is not in the pack any more")]
	return line


## Puts one ring entry's bytes back on the file they came from, as ONE undoable edit: the way back
## writes the bytes that are there NOW, or removes the file again when there was none, so Ctrl+Z
## leaves the folder exactly as this found it.
##
## Returns the receipt - {"restored", "path", "backup", "bytes", "was_missing"} - so the caller says
## what happened rather than reporting that a button was pressed. `restored` is false and nothing is
## written when the ring entry has gone (a later save pruned it while the window was open).
##
## `undo` is the editor's undo manager, asked for here when the editor is running and handed in by
## the suite. Without one the write still happens - a project with no editor open is not a project
## where a restore should refuse - and there is simply nothing to take it back.
static func restore(entry: Dictionary, undo: Object = null) -> Dictionary:
	var backup: String = str(entry.get("backup", ""))
	var target: String = str(entry.get("target", ""))
	var receipt: Dictionary = {"restored": false, "path": str(entry.get("path", "")),
		"backup": backup, "bytes": 0, "was_missing": false}
	if backup.is_empty() or target.is_empty() or not FileAccess.file_exists(backup):
		return receipt
	var restoring: PackedByteArray = FileAccess.get_file_as_bytes(backup)
	var was_missing: bool = not FileAccess.file_exists(target)
	var previous: PackedByteArray = PackedByteArray()
	if not was_missing:
		previous = FileAccess.get_file_as_bytes(target)
	receipt["restored"] = true
	receipt["bytes"] = restoring.size()
	receipt["was_missing"] = was_missing
	var manager: Object = undo
	if manager == null and Engine.is_editor_hint():
		manager = EditorInterface.get_editor_undo_redo()
	if manager == null:
		write_bytes(target, restoring)
		return receipt
	# The two halves are named METHODS on this script rather than lambdas, because an undo manager
	# stores an object and a method name and calls it back later - a closure would be a reference the
	# history cannot hold.
	var here: Script = _own_script()
	manager.call("create_action",
		EventSheetL10n.translate("Restore %s from the backup ring") % str(entry.get("path", "")))
	manager.call("add_do_method", here, "write_bytes", target, restoring)
	if was_missing:
		manager.call("add_undo_method", here, "remove_written", target)
	else:
		manager.call("add_undo_method", here, "write_bytes", target, previous)
	manager.call("commit_action")
	return receipt


## This file as the object an undo manager calls a static method back on.
static func _own_script() -> Script:
	return load("res://addons/eventsheet/editor/pack_update.gd") as Script


## The write a restore is made of, named so an undo manager can call it by name in both directions.
## It writes exactly the bytes it was handed and touches nothing else - no ring entry, no record, no
## rescan.
static func write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()


## The other half of that pair: the way back from restoring a file the pack no longer had.
static func remove_written(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## The sentence a restore leaves behind. Pure over the receipt, so the suite pins the words.
static func restore_text(receipt: Dictionary) -> String:
	if not bool(receipt.get("restored", false)):
		return EventSheetL10n.translate("That backup is not there any more - the ring keeps a fixed number of them, and a save since this list was drawn has pushed it out.")
	if bool(receipt.get("was_missing", false)):
		return EventSheetL10n.translate("%s is back in the pack, %d byte(s), from the backup ring. It was not in the folder at all until now. Ctrl+Z removes it again, and the ring is untouched.") % [
			str(receipt.get("path", "")), int(receipt.get("bytes", 0))]
	return EventSheetL10n.translate("%s was put back from the backup ring, %d byte(s). Ctrl+Z writes the bytes that were there before, and the ring is untouched.") % [
		str(receipt.get("path", "")), int(receipt.get("bytes", 0))]


# ── The words ─────────────────────────────────────────────────────────────────────────────────


## One row as the dialog and the suite both read it: the path, what happens to it, and any note.
static func row_text(row: Dictionary) -> String:
	var note: String = str(row.get("note", "")).strip_edges()
	var line: String = "%s - %s" % [str(row.get("path", "")), change_text(str(row.get("change", "")))]
	return line if note.is_empty() else "%s (%s)" % [line, note]


static func change_text(change: String) -> String:
	match change:
		CHANGE_ADDED:
			return EventSheetL10n.translate("new in this version")
		CHANGE_REMOVED:
			return EventSheetL10n.translate("dropped by this version")
		CHANGE_REPLACED:
			return EventSheetL10n.translate("this version rewrites it")
		_:
			return EventSheetL10n.translate("identical in both")


## The line above the three lists. It says the shape of the decision, not a verdict.
static func summary_text(update_plan: Dictionary) -> String:
	var untouched: int = (update_plan.get("untouched", []) as Array).size()
	var yours: int = (update_plan.get("yours", []) as Array).size()
	if bool(update_plan.get("unrecorded", false)):
		return EventSheetL10n.translate("This pack carries no record of what arrived, so all %d file(s) are listed as yours and nothing is taken unless you say so.") % yours
	if yours == 0:
		return EventSheetL10n.translate("%d file(s) are exactly as they arrived and take the new version. You changed none of them.") % untouched
	return EventSheetL10n.translate("%d file(s) are exactly as they arrived and take the new version. %d you changed, each with its own answer below.") % [
		untouched, yours]


## The vocabulary section, line by line, as the dialog draws it. A retired verb says where it went,
## because "retired" here never means gone: the old spelling keeps its id, its template and its
## place in the picker, and a sheet written on it compiles to the same line it always did.
static func vocabulary_lines(vocabulary_diff: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in (vocabulary_diff.get("retired", []) as Array):
		var key: String = str(entry.get("key", ""))
		if bool(entry.get("gone", false)):
			lines.append(EventSheetL10n.translate("%s is not published by the new version - rows using it keep working from the file you have.") % key)
			continue
		lines.append(EventSheetL10n.translate("%s now points at %s - old rows still compile the same; the dry run shows what would change.") % [
			key, str(entry.get("successor", ""))])
	for key: String in PackedStringArray(vocabulary_diff.get("added", PackedStringArray())):
		lines.append(EventSheetL10n.translate("%s is new in this version.") % key)
	return lines
