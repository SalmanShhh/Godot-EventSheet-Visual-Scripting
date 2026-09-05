# Godot EventSheets - the Doctor's Renames section.
#
# One question: which rows of this project point at a name that went out of its own file while this
# session was watching. Such a row is not corrupt - it says what it always said and compiles to the
# line it always compiled to - but the thing it points at has moved, and the row was not told.
#
# IT IS ONE OF THE TWO PLACES THE WORDS APPEAR, the other being the selected row's help strip. The
# sheet itself stays quiet: an affected row wears the quiet amber state and nothing else. Same
# finding, two roofs, one wording.
#
# IT ANSWERS ONLY FOR SAVES IT WATCHED, and says so rather than pretending otherwise. The evidence
# for a rename is one file's identity moving once with a name going out of it, which is a thing you
# have to have been present for. A headless run - the CLI, CI - has watched nothing, so this section
# reports its summary line and no findings, which is the honest answer and not a gap. Inside a
# running editor, where the sheets have been open while somebody renamed things, it is the inbox for
# exactly the rows that broke.
#
# NOTHING APPLIES FROM HERE. A finding's door opens the sheet's own receipt, which owns the undo
# step. A report that rewrote files from a list nobody was looking at would be the fatal version of
# this feature.
#
# THE CORPUS IS THE SHEETS THIS SESSION WATCHED A SAVE OF, and it is derived rather than handed over.
# A registered check receives `sheet_paths`, which lists only the project's `.tres` sheets while `.gd`
# is the default sheet format - so a section built on it alone reads nothing in a normal project and
# reports "0 sheet(s) read" forever while looking like it works. The Migration section beside it
# widens with `EventSheets.project_scripts()`; this one does not need to, because the rule above
# means a file whose save was never watched cannot earn a finding whatever is in it. So the corpus is
# the `.tres` sheets plus exactly the files the witness has a save for, which is the smallest corpus
# that can answer the question and the only one that answers it at all.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses, so it lands in all
# four runners (the panel, the headless CLI, CI and the MCP server).
@tool
class_name EventSheetRenameDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the ids its findings are filed as. Frozen alongside
## the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "renames"
const CHECK_CALL_GONE := EventSheetRenameFindings.KIND_CALL_GONE
const CHECK_NODE_GONE := EventSheetRenameFindings.KIND_NODE_GONE


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetRenameDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://. The Doctor's `sheet_paths` is the project's `.tres` sheets alone, so the `.gd`
## sheets - which is nearly all of them - are added from the witness, which is where the only files
## that can answer this question are named.
static func check(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(corpus(sheet_paths, EventSheetRenameEvidence.watched_paths())))


## What one run reads: the stored sheets it was handed, plus every file this session watched a save
## of. Sorted and de-duplicated, so two machines read the same files in the same order.
##
## `watched` is passed in rather than fetched, so a test hands in a corpus of its own and the words
## below are pinned without a session behind them.
static func corpus(sheet_paths: PackedStringArray, watched: PackedStringArray) -> PackedStringArray:
	var read: PackedStringArray = PackedStringArray()
	for listed: PackedStringArray in [sheet_paths, watched]:
		for path: String in listed:
			# A scene is watched for its node names and is not a sheet; it is read THROUGH the script
			# that runs it, which is in this list on its own.
			if not read.has(path) and path.get_extension().to_lower() != "tscn":
				read.append(path)
	read.sort()
	return read


## The whole section as findings, the summary first. Pure over a list of paths, so a test can hand it
## a corpus of two. Paths are sorted here rather than trusted from the caller, so two machines read
## the same files in the same order and print the same report.
static func report(paths: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var read: PackedStringArray = paths.duplicate()
	read.sort()
	var measured: int = 0
	var affected: int = 0
	for path: String in read:
		var sheet: EventSheetResource = _opened(path)
		if sheet == null:
			continue
		measured += 1
		var mine: Array[Dictionary] = EventSheetRenameFindings.findings(sheet, path,
			EventSheetRenameEvidence.witness_for(path, _scene_of(path)))
		if not mine.is_empty():
			affected += 1
		findings.append_array(sheet_findings(path, mine))
	findings.insert(0, _finding("info", CHECK_ID, "",
		"Renames: %d sheet(s) read, and %d of them hold a row pointing at a name that went out of its file." % [
			measured, affected], ""))
	return findings


## What one opened sheet contributes to the section. Pure over the findings a sheet earned, so the
## wording is pinned without going through the importer.
static func sheet_findings(path: String, mine: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for finding: Dictionary in mine:
		findings.append(_finding("warning", str(finding.get("kind", CHECK_ID)), path,
			str(finding.get("message", "")), str(finding.get("subject", ""))))
	return findings


## The first scene that runs this script, in path order, or "" - the file whose node names the node
## half of the rule is about. First rather than all of them: a script on two scenes has two answers
## to "which node is this", and a section that guessed between them would be guessing.
static func _scene_of(script_path: String) -> String:
	var scenes: PackedStringArray = EventSheetSceneConnections.scenes_using_script(script_path)
	return scenes[0] if scenes.size() > 0 else ""


## One path as a sheet, whichever of the two formats it is: a `.tres` is loaded as the resource it
## already is, and anything else is opened through the importer the way the editor opens it.
static func _opened(path: String) -> EventSheetResource:
	if path.get_extension().to_lower() == "tres":
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	return EventSheetProjectDoctor.sheet_of(path)
