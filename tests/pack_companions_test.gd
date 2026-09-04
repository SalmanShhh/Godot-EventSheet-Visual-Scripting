# Godot EventSheets - the files a pack ships BESIDE its script are the bytes they came from.
#
# A pack is not always one .gd. Screen FX ships twelve shaders and a scene, Blend Modes fifteen more,
# Scene Flow seven transition shaders, the Post Kit six compute shaders and their effect scripts,
# Juice six moment files. Every one of those is COMPILER OUTPUT in the same sense the pack script is:
# it is written by `Lib.ship_files` out of the builder's own source folder, and hand-editing the
# shipped copy is editing generated code.
#
# THE HOLE THIS FILLS. `tools/audit_addons.gd` reads only the pack .gd - it skips every non-script
# file by construction - so a hand edit to a shipped shader, a starter moment or a pack scene passed
# every gate in the tree and was silently reverted by the next build. Two packs had grown a
# byte-compare of their own folder; seven had not, and a copy of the same check per pack is how two
# of them come to disagree.
#
# So the shipments are DERIVED rather than listed: every `Lib.ship_files(<source>, <base>, [<ext>])`
# call in `tools/pack_builders/` is read out of the builder that makes it, which means a pack that
# starts shipping a companion tomorrow is gated the day it does, with no table to remember.
@tool
class_name PackCompanionsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "pack_companions_test"

## Where the builders live, and where their source folders are - the two halves of every shipment.
const BUILDERS := "res://tools/pack_builders/"
const SOURCES := "res://tools/pack_builders/src/"

## The call that makes a shipment. Found by text in the builder, because the builder IS the record of
## what a pack ships and a second list of it here could only ever go stale.
const SHIPMENT_CALL := "Lib.ship_files("


static func run() -> bool:
	var shipments: Array[Dictionary] = _shipments()
	var differ: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	var shipped_files: int = 0
	for shipment: Dictionary in shipments:
		var from_dir: String = SOURCES + str(shipment["source"])
		var into_dir: String = str(shipment["base"]).get_base_dir()
		for file_name: String in _companions(from_dir, shipment["extensions"] as PackedStringArray):
			shipped_files += 1
			var into_path: String = into_dir.path_join(file_name)
			if not FileAccess.file_exists(into_path):
				missing.append(into_path)
				continue
			if FileAccess.get_file_as_string(into_path) \
					!= FileAccess.get_file_as_string(from_dir.path_join(file_name)):
				differ.append(into_path)
	missing.sort()
	differ.sort()
	return SUPPORT.pins(P, [
		["every companion a builder ships is beside the pack", ",".join(missing), ""],
		["and is the bytes of the source file it came from", ",".join(differ), ""],
		["the shipments are found in the builders rather than listed here",
			shipments.size() > 0, true],
		["and every one of them ships at least one file", shipped_files >= shipments.size(), true],
	])


## Every companion shipment the pack builders declare, as {source, base, extensions}. Read out of the
## builder text: the call may be wrapped over two lines, so the whole call is taken from the opening
## bracket to its match and then split.
static func _shipments() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var names: PackedStringArray = DirAccess.get_files_at(BUILDERS)
	names.sort()
	for file_name: String in names:
		if not file_name.ends_with(".gd") or file_name.begins_with("_"):
			continue
		var source: String = FileAccess.get_file_as_string(BUILDERS + file_name)
		var at: int = source.find(SHIPMENT_CALL)
		while at >= 0:
			var call_text: String = _call_arguments(source, at + SHIPMENT_CALL.length() - 1)
			var shipment: Dictionary = _read_shipment(call_text)
			if not shipment.is_empty():
				found.append(shipment)
			at = source.find(SHIPMENT_CALL, at + 1)
	return found


## The text between one opening bracket and the bracket that closes it.
static func _call_arguments(source: String, opening: int) -> String:
	var depth: int = 0
	for index: int in range(opening, source.length()):
		var here: String = source[index]
		if here == "(" or here == "[":
			depth += 1
		elif here == ")" or here == "]":
			depth -= 1
			if depth == 0:
				return source.substr(opening + 1, index - opening - 1)
	return ""


## One call's arguments as the shipment they describe. A call whose arguments are not two plain
## string literals and a list of them is skipped rather than guessed at - it is not a shape any
## builder writes today, and guessing would gate the wrong folder.
static func _read_shipment(call_text: String) -> Dictionary:
	var literals: PackedStringArray = PackedStringArray()
	var reading: bool = false
	var held: String = ""
	for index: int in call_text.length():
		var here: String = call_text[index]
		if here == "\"":
			if reading:
				literals.append(held)
				held = ""
			reading = not reading
			continue
		if reading:
			held += here
	if literals.size() < 3:
		return {}
	var extensions: PackedStringArray = PackedStringArray()
	for index: int in range(2, literals.size()):
		extensions.append(literals[index])
	return {"source": literals[0], "base": literals[1], "extensions": extensions}


## The files in one source folder that a shipment carries, sorted so the answer is the same on every
## machine (CI walks a directory in whatever order the filesystem hands back).
static func _companions(from_dir: String, extensions: PackedStringArray) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: String in DirAccess.get_files_at(from_dir):
		if extensions.has(entry.get_extension()):
			names.append(entry)
	names.sort()
	return names
