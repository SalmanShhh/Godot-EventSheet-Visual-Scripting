# Godot EventSheets - the Doctor's Migration section.
#
# One question: which rows in this project hold a verb the installed vocabulary no longer has. Such a
# row is not broken - its template and its reading were both written onto it when it was applied, so
# it compiles to the same line and says the same sentence it always did - but it can no longer be
# edited, re-picked or explained, and that is worth knowing before somebody meets it under a deadline.
#
# IT IS THE ONLY PLACE THE WORDS APPEAR, alongside the selected row's help strip. The sheet itself
# stays quiet: an affected row wears the quiet amber state and nothing else - no block, no icon, no
# inline sentence. Same finding, three roofs, one wording.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a studio's own vocabulary lands in this same section
# rather than inventing a second report. Registering from the Doctor's own run is what makes it show
# up in all four runners (the panel, the headless CLI, CI and the MCP server).
#
# THE CORPUS IS EVERY `.tres` SHEET AND A SAMPLE OF THE `.gd` ONES, and the asymmetry is the point.
# A `.tres` sheet STORES its rows, so a verb it names can outlive the vocabulary that had it - that
# is the whole state this section is about, and every one of them is read. A `.gd` sheet derives its
# rows from the file every time it is opened, and a line whose verb is gone has no lift entry left to
# match, so it degrades to honest code and there is nothing here to find; the only way one of them
# reports is a vocabulary that disagrees with itself (a lift entry kept after its verb was dropped),
# which is a pack-authoring mistake worth sampling for and not worth reading a thousand files for.
# The sample is capped, sorted, and says out loud that it is a sample.
#
# Sheets are opened in memory and dropped. Nothing is written, nothing is cached, and a project whose
# vocabulary is all present reports one summary line and no findings.
@tool
class_name EventSheetMigrationDoctor
extends RefCounted

## The id the section is registered under, and the id its one finding is filed as. Frozen alongside
## the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "migration"
const CHECK_VERB_GONE := EventSheetMigrationFindings.KIND_VERB_GONE

## How many `.gd` scripts one audit samples, on top of every `.tres` sheet. A ceiling, not a target -
## the header says why a `.gd` sheet is a sample and a `.tres` one is not.
const SCRIPTS_SAMPLED: int = 24


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetMigrationDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://. `sheet_paths` is the project's `.tres` sheets, which is exactly the half of the
## corpus that has to be read whole; the `.gd` half is sampled beside it.
static func check(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(corpus(sheet_paths, EventSheets.project_scripts())))


## What one audit reads: every stored sheet, then the first few scripts in path order. Sorted and
## de-duplicated so two machines read the same files in the same order and print the same report.
static func corpus(sheet_paths: PackedStringArray, scripts: PackedStringArray) -> PackedStringArray:
	var stored: PackedStringArray = sheet_paths.duplicate()
	stored.sort()
	var sampled: PackedStringArray = scripts.duplicate()
	sampled.sort()
	var read: PackedStringArray = PackedStringArray()
	for path: String in stored:
		if not read.has(path):
			read.append(path)
	for path: String in sampled:
		if read.size() >= stored.size() + SCRIPTS_SAMPLED:
			break
		if not read.has(path):
			read.append(path)
	return read


## The whole section as findings, the summary first: how many sheets were read and how many of them
## hold a verb that is gone. Pure over a list of paths, so a test can hand it a corpus of two.
##
## The vocabulary is resolved ONCE for the whole run and handed to every sheet: reflecting the
## installed packs per sheet would be the same answer computed a hundred times.
static func report(paths: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if paths.is_empty():
		return findings
	var known: Callable = EventSheetMigrationFindings.catalog_resolver()
	var importer := GDScriptImporter.new()
	var measured: int = 0
	var affected: int = 0
	# The summary points at the sheet with the MOST gone verbs, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there. Nothing wrong
	# points at nothing: a line that opens a file for no reason is a line that wastes a click.
	var worst_path: String = ""
	var worst_count: int = 0
	for path: String in paths:
		var sheet: EventSheetResource = _opened(importer, path)
		if sheet == null:
			continue
		measured += 1
		var mine: Array[Dictionary] = EventSheetMigrationFindings.findings(sheet, path, known)
		if not mine.is_empty():
			affected += 1
		if mine.size() > worst_count:
			worst_count = mine.size()
			worst_path = path
		findings.append_array(script_findings(path, mine))
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		"Migration: %d sheet(s) read, and %d of them hold a verb the installed vocabulary no longer has." % [
			measured, affected], ""))
	return findings


## One path as a sheet, whichever of the two formats it is: a `.tres` is loaded as the resource it
## already is, and anything else is opened through the importer the way the editor opens it.
static func _opened(importer: GDScriptImporter, path: String) -> EventSheetResource:
	if path.get_extension().to_lower() == "tres":
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	return importer.import_external(path)


## What one opened sheet contributes to the section. Pure over the findings a sheet earned, so the
## wording is pinned without going through the importer.
static func script_findings(script_path: String, mine: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for finding: Dictionary in mine:
		findings.append(_finding("warning", CHECK_VERB_GONE, script_path,
			str(finding.get("message", "")), str(finding.get("subject", ""))))
	return findings


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}
