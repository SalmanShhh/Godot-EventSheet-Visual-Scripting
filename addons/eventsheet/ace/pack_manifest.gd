# Godot EventSheets - WHAT THIS PACK LOOKED LIKE WHEN IT ARRIVED.
#
# A pack is COPIED into the project on purpose: once it is in eventsheet_addons/ it is the project's
# own code, to be read, edited and shipped like anything else. That is the good half. The other half
# is that a year later nobody can tell which of its files they changed and which they never touched -
# and an update that cannot tell either is an update that either overwrites somebody's work or
# refuses to move at all.
#
# So an attach WRITES DOWN what it brought: one manifest per pack, holding the content hash of every
# file it landed. No mtimes (a checkout, a copy or a sync moves those without touching a byte), no
# guessing, no comparing against a copy of the pack held somewhere else. A file whose hash still
# matches what arrived is untouched; a file whose hash differs is yours. That is the entire question,
# and it is answered from the bytes on disk.
#
# A LINE-ENDING DIFFERENCE IS A DIFFERENCE. A file saved back out with CRLF where LF arrived is not
# byte-identical, so it classifies as YOURS - because the honest answer to "did this file change?"
# is the one the bytes give, and a hash that quietly normalized whitespace would be a hash that
# quietly loses a real edit some day. The row says so in its own words ("only the line endings
# differ") so the reader can take the new version in one click and not wonder what they did.
#
# A PACK WITH NO MANIFEST IS NOT A PACK WITH NO CHANGES. The packs that ship inside the plugin were
# never attached, and a folder somebody assembled by hand never was either. Those classify as
# UNRECORDED - every file treated as yours, nothing assumed - rather than pretending a missing
# record means an untouched file.
#
# THIS IS NOT THE CATALOG. `EventSheetPackCatalog` derives a pack's name, pitch, shelf and version
# from the pack's own file precisely so there is no metadata to keep in step, and that stays true.
# What is written here is the one fact that CANNOT be derived from the files as they stand now:
# what they were when they landed.
#
# NOTHING HERE WRITES A .gd. The manifest is its own small file beside the pack's code, and no
# opened sheet, no save and no compile ever consults it.
@tool
class_name EventSheetPackManifest
extends RefCounted

const PACKS_ROOT: String = "res://eventsheet_addons"

## The record's file name inside the pack folder.
const MANIFEST_FILE: String = "pack_manifest.json"

## Bumped only if the record's shape changes. A manifest from a shape this build cannot read is
## treated as no manifest at all, which is the safe direction: everything reads as yours.
const FORMAT_VERSION: int = 1

## The three answers `classify()` gives one file.
const STATE_UNTOUCHED: String = "untouched"
const STATE_YOURS: String = "yours"
const STATE_UNRECORDED: String = "unrecorded"

## The note beside a file that differs only in how its lines end.
const NOTE_LINE_ENDINGS: String = "only the line endings differ"
## The note beside a file the record does not mention at all.
const NOTE_NOT_RECORDED: String = "not in what arrived"
## The note beside a file the record mentions and the folder no longer has.
const NOTE_MISSING: String = "recorded at attach, gone from the folder"

## Files the record deliberately never holds. `.import` is written by the engine for its own use on
## first import and carries a per-project uid, so recording it would mark every pack in every
## project as edited on the day it was opened.
const IGNORED_EXTENSIONS: PackedStringArray = ["import"]


# ── Hashing ───────────────────────────────────────────────────────────────────────────────────


## The content hash of some bytes, as lowercase hex. ONE definition, used for both the file on disk
## and the file inside an incoming archive, so the two can never be hashed by different rules.
static func hash_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


## The content hash of a file on disk. "" when there is no such file.
static func hash_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return hash_bytes(FileAccess.get_file_as_bytes(path))


## The same bytes with every line ending reduced to a newline - the ONLY normalization anything here
## does, and it is used to EXPLAIN a difference, never to hide one.
static func line_ending_neutral_hash(bytes: PackedByteArray) -> String:
	var text: String = bytes.get_string_from_utf8()
	if text.is_empty() and not bytes.is_empty():
		# Not text at all (an icon, a font). There is nothing to neutralize, so answer the bytes.
		return hash_bytes(bytes)
	return hash_bytes(text.replace("\r\n", "\n").replace("\r", "\n").to_utf8_buffer())


# ── The folder ────────────────────────────────────────────────────────────────────────────────


static func folder_for(pack_dir: String) -> String:
	return PACKS_ROOT.path_join(pack_dir)


static func manifest_path(pack_folder: String) -> String:
	return pack_folder.path_join(MANIFEST_FILE)


## Every file a pack folder holds, as paths relative to the folder, sorted, walked depth first. The
## manifest itself and the ignored extensions are left out, so stamping a folder twice records the
## same set both times.
static func files_of(pack_folder: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_walk(pack_folder, "", found)
	found.sort()
	return found


static func _walk(root: String, prefix: String, into: PackedStringArray) -> void:
	var here: String = root if prefix.is_empty() else root.path_join(prefix)
	for file_name: String in DirAccess.get_files_at(here):
		if prefix.is_empty() and file_name == MANIFEST_FILE:
			continue
		if IGNORED_EXTENSIONS.has(file_name.get_extension()):
			continue
		into.append(file_name if prefix.is_empty() else prefix.path_join(file_name))
	var directories: PackedStringArray = DirAccess.get_directories_at(here)
	directories.sort()
	for directory: String in directories:
		if directory.begins_with("."):
			continue
		_walk(root, directory if prefix.is_empty() else prefix.path_join(directory), into)


# ── Writing the record ────────────────────────────────────────────────────────────────────────


## Stamps a pack folder: hashes every file it now holds and writes the record beside them. This is
## what an attach calls, once, after the last byte has landed. Returns the record it wrote, or {}
## when the folder holds nothing.
##
## `version` is the pack's own declared version at the moment it arrived, kept so a later update can
## say what it is updating FROM even after the file that declared it has been edited.
static func stamp(pack_folder: String, version: String = "") -> Dictionary:
	var files: PackedStringArray = files_of(pack_folder)
	if files.is_empty():
		return {}
	var hashes: Dictionary = {}
	var neutral: Dictionary = {}
	for relative: String in files:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(pack_folder.path_join(relative))
		hashes[relative] = hash_bytes(bytes)
		# The line-ending-neutral hash is kept ONLY for a file that actually holds a carriage return,
		# so the common case costs nothing. Without it stored, a file re-saved with the other
		# platform's line endings is still correctly YOURS - it just cannot be told apart from a real
		# edit, and the reader loses a sentence they would have found useful.
		var neutral_hash: String = line_ending_neutral_hash(bytes)
		if neutral_hash != hashes[relative]:
			neutral[relative] = neutral_hash
	var record: Dictionary = {
		"format": FORMAT_VERSION,
		"pack": pack_folder.get_file(),
		"version": version,
		"files": hashes,
		"line_endings": neutral,
	}
	var file: FileAccess = FileAccess.open(manifest_path(pack_folder), FileAccess.WRITE)
	if file == null:
		return {}
	# Sorted keys and a tab indent: the record is a file in somebody's repository, so it has to read
	# as a diff a human can follow and land identically on two machines.
	file.store_string(JSON.stringify(record, "\t", true) + "\n")
	file.close()
	return record


## The record a pack folder carries, or {} when it has none or the one it has is unreadable. An
## unreadable record is an ABSENT record on purpose: guessing at half a shape is how an update
## overwrites something.
static func read(pack_folder: String) -> Dictionary:
	var path: String = manifest_path(pack_folder)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var record: Dictionary = parsed
	if int(record.get("format", 0)) != FORMAT_VERSION:
		return {}
	if not (record.get("files", null) is Dictionary):
		return {}
	return record


static func has_record(pack_folder: String) -> bool:
	return not read(pack_folder).is_empty()


# ── The question ──────────────────────────────────────────────────────────────────────────────


## Every file in the folder, and every file the record mentions, as
## {"path", "state", "note"} - sorted by path, one row each, nothing merged away.
##
## A folder with no record answers UNRECORDED for every row rather than UNTOUCHED, because "we do
## not know" and "you did not change it" are different answers and only one of them is true.
static func classify(pack_folder: String) -> Array[Dictionary]:
	var record: Dictionary = read(pack_folder)
	var recorded: Dictionary = record.get("files", {}) if not record.is_empty() else {}
	var paths: Dictionary = {}
	for relative: String in files_of(pack_folder):
		paths[relative] = true
	for relative: Variant in recorded.keys():
		paths[str(relative)] = true
	var sorted: PackedStringArray = PackedStringArray()
	for relative: Variant in paths.keys():
		sorted.append(str(relative))
	sorted.sort()
	var rows: Array[Dictionary] = []
	for relative: String in sorted:
		rows.append(classify_one(pack_folder, relative, record))
	return rows


## One file's answer, given the pack's record ({} for a pack that has none). Split out so the update
## plan can ask about a single path without walking a folder, and so a test can pin each answer.
static func classify_one(pack_folder: String, relative: String, record: Dictionary) -> Dictionary:
	var path: String = pack_folder.path_join(relative)
	if record.is_empty():
		return {"path": relative, "state": STATE_UNRECORDED, "note": ""}
	var recorded: Dictionary = record.get("files", {})
	if not recorded.has(relative):
		return {"path": relative, "state": STATE_YOURS, "note": NOTE_NOT_RECORDED}
	if not FileAccess.file_exists(path):
		return {"path": relative, "state": STATE_YOURS, "note": NOTE_MISSING}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var attached_hash: String = str(recorded[relative])
	if hash_bytes(bytes) == attached_hash:
		return {"path": relative, "state": STATE_UNTOUCHED, "note": ""}
	# It differs. The one thing worth naming is the difference that is not an edit anybody made on
	# purpose: a whole file re-saved with the other platform's line endings. It is still YOURS - the
	# bytes decide - but the reader deserves to know that is all it is.
	var note: String = ""
	if line_ending_neutral_hash(bytes) == neutral_of_record(record, relative, attached_hash):
		note = NOTE_LINE_ENDINGS
	return {"path": relative, "state": STATE_YOURS, "note": note}


## The line-ending-neutral hash the record holds for one file. Stamping keeps one only where the
## arriving file actually held a carriage return; for everything else the raw hash IS the neutral
## one, which is exactly what a file that arrived with plain newlines should be compared against.
static func neutral_of_record(record: Dictionary, relative: String, attached_hash: String) -> String:
	var stored: Dictionary = record.get("line_endings", {})
	return str(stored[relative]) if stored.has(relative) else attached_hash


## The rows of one state, in order. The dialog draws three lists off this rather than filtering in
## three places and drifting.
static func rows_in_state(rows: Array[Dictionary], state: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in rows:
		if str(row.get("state", "")) == state:
			out.append(row)
	return out
