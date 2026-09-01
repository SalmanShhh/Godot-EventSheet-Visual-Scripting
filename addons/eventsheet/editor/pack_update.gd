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
# copied into the same per-file ring a sheet save uses, before the first write. An update is then as
# reversible as any other edit: the previous bytes are one restore away.
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
	var installed_script: String = EventSheetPackCatalog.main_script_for(
		pack_folder.get_file(), pack_folder.get_base_dir())
	if installed_script.is_empty():
		return {"retired": [], "added": [], "changed": [], "readable": false}
	var relative: String = installed_script.trim_prefix("%s/" % pack_folder)
	if not incoming.has(relative):
		return {"retired": [], "added": [], "changed": [], "readable": false}
	DirAccess.make_dir_recursive_absolute(REFLECT_DIR)
	var reflect_path: String = REFLECT_DIR.path_join(installed_script.get_file())
	var file: FileAccess = FileAccess.open(reflect_path, FileAccess.WRITE)
	if file == null:
		return {"retired": [], "added": [], "changed": [], "readable": false}
	file.store_buffer(incoming[relative])
	file.close()
	var before: String = EventForgeRegistryDump.for_script(installed_script)
	var after: String = EventForgeRegistryDump.for_script(reflect_path)
	DirAccess.remove_absolute(reflect_path)
	DirAccess.remove_absolute(REFLECT_DIR)
	return EventForgeRegistryDump.diff(before, after)


# ── Taking it ─────────────────────────────────────────────────────────────────────────────────


## Writes the update. Every file about to be overwritten or removed goes into the backup ring FIRST,
## so the previous version is one restore away before the first new byte lands. Returns
## {"written", "removed", "kept", "backed_up"} - counts, so a caller can say what happened.
##
## `choices` maps a row's path to CHOICE_*; a path it does not name takes `default_choice`.
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
	# against what this one actually left behind - kept files and taken files alike.
	EventSheetPackManifest.stamp(pack_folder, version)
	return {"written": written, "removed": removed, "kept": kept, "backed_up": backed_up}


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
