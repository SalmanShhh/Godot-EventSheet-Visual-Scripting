# Godot EventSheets - the beats every Doctor section shares.
#
# A section of the Doctor is a file of its own, and four of the things each one does were not just
# the same idea in every file but the same TEXT in every file:
#
#   THE FINDING SHAPE   the five-key dictionary the panel, the triage inbox, the quick-fix chips and
#                     the headless CLI all read by name. It is FROZEN: those four readers address
#                     these keys by their spelling, and a sixth key would be invisible to all four.
#   THE FILING WALK   a family's own findings turned into that shape, under the check id its kind
#                     maps to, worded with the file a reader should open in front.
#   THE PRE-READ    the substring test that decides what gets OPENED at all, always looser than the
#                     rules it guards - opening is the expensive half, reporting is the careful one.
#   THE ORDERING    the deterministic sort a section with a reading ceiling needs, so that stopping
#                     early stops on the least interesting file rather than an arbitrary one.
#
# They live here now, and a section reaches them by EXTENDING this class rather than by naming it.
# GDScript inherits static functions, so `_finding(...)` inside a section is this file's `_finding`
# and the call reads exactly as it did when every section carried its own copy of the body.
#
# NOTHING HERE KNOWS ABOUT ANY SECTION, and that is deliberate twice over. A static function cannot
# see the constants of the class that inherited it, so the two per-section facts the filing walk
# needs - the map from a family's kind to a check id, and the id an unmapped kind falls back to -
# are passed in. And a base that reached back into the Doctor to read a source or list the scripts
# would put a cycle between the two files for no gain: those are the section's own business, and
# every one of them already asks the Doctor directly.
@tool
class_name EventSheetDoctorSection
extends RefCounted

## Where this plugin's own code lives. Every section that walks the project's scripts leaves it out:
## the editor is not the reader's game, and a note about it is not theirs to act on.
const PLUGIN_DIRECTORY := "res://addons/"

## Where the behaviour packs live. The shipped ones are rebuilt from the plugin's pack builders, so in
## a game that installed them they are the plugin's code as much as `addons/` is: a finding about a
## pack's script was the first thing a new project's Doctor said, and nothing the reader could fix.
## The SAME folder holds the reader's own work, though - New behaviour, New global and Export Pack
## each write a folder here - so the folder alone does not say whose a file is.
const PACK_DIRECTORY := "res://eventsheet_addons/"

## The pack folders the plugin ships, as the pack builders publish them. Written by
## `tools/measure_packs.gd -- --write` and gated against the builders, because a user's project has
## the plugin's `addons/` but not its builders.
const SHIPPED_PACKS := preload("res://addons/eventforge/shipped_pack_folders.gd")


## True for a file the plugin ships - its own code, a shipped pack or one of the runtime scripts at
## the packs' root - which no section reports on. A file in any other folder under the packs' root
## is a behaviour, global or pack the reader made, and is reported on like the rest of their game.
static func _is_shipped(path: String) -> bool:
	if path.begins_with(PLUGIN_DIRECTORY):
		return true
	if not path.begins_with(PACK_DIRECTORY):
		return false
	var rest: String = path.trim_prefix(PACK_DIRECTORY)
	var slash: int = rest.find("/")
	# Nothing the editor makes lands at the root: every maker writes a folder of its own.
	return slash < 0 or SHIPPED_PACKS.FOLDERS.has(rest.substr(0, slash))


## The paths of a corpus the reader wrote, in their order: everything `_is_shipped` names is left
## out. A section whose corpus is the project's scripts asks this at its door, so a game that
## installed the packs is measured, sampled and summarised on its own files - in such a game the
## packs outnumber the reader's scripts many times over, and a sample read in path order was
## otherwise nothing but packs.
static func own_paths(paths: PackedStringArray) -> PackedStringArray:
	var own: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if not _is_shipped(path):
			own.append(path)
	return own


## One finding, in the shape every runner reads. `severity` is "error", "warning" or "info";
## `check_id` is what the panel groups by and what a quick-fix chip is addressed to; `path` is the
## file double-clicking the line opens; `message` is the words; and `subject` is the one name or
## line the finding is about, which is what the sheet's amber row state and the fix doors match on.
static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}


## A family's findings as the Doctor files them: each keeps its own severity and wording, filed
## under the check id its kind maps to and worded with the file in front, so a reader scanning the
## panel sees which file each line is about without opening anything. `check_for_kind` is the
## section's own kind-to-check map; `fallback_check_id` is where a kind nobody mapped is filed.
static func _filed(path: String, found: Array[Dictionary], check_for_kind: Dictionary,
		fallback_check_id: String) -> Array[Dictionary]:
	var filed: Array[Dictionary] = []
	for finding: Dictionary in found:
		filed.append(_finding(str(finding.get("severity", "warning")),
			str(check_for_kind.get(str(finding.get("kind", "")), fallback_check_id)), path,
			"%s %s" % [path.get_file(), str(finding.get("message", ""))],
			str(finding.get("subject", ""))))
	return filed


## True when a text says any one of these words. The pre-read, and deliberately looser than the
## rules behind it: it only decides what is worth importing, and the rules decide what is worth
## reporting.
static func _says_any(source: String, words: PackedStringArray) -> bool:
	for word: String in words:
		if source.contains(word):
			return true
	return false


## Scored paths in one deterministic order: by the named integer key, then by path, so two audits of
## an unchanged project read the same. `ascending` false puts the strongest evidence first, which is
## what a section with a reading ceiling wants - a run that stops early then loses the weakest
## candidates rather than an arbitrary tail.
static func _ordered_paths(scored: Array[Dictionary], key: String,
		ascending: bool) -> PackedStringArray:
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left[key]) == int(right[key]):
			return str(left["path"]) < str(right["path"])
		return int(left[key]) < int(right[key]) if ascending else int(left[key]) > int(right[key]))
	var ordered: PackedStringArray = PackedStringArray()
	for entry: Dictionary in scored:
		ordered.append(str(entry["path"]))
	return ordered
