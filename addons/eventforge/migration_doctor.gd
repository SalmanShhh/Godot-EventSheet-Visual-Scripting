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
# The sample is capped, sorted, and SAYS OUT LOUD IN ITS OWN SUMMARY LINE that it is one, with the
# two numbers - a section whose only sentence read "812 sheet(s) read" over a corpus of two dozen is
# how a branch gate passes green over files it never opened.
#
# THE WHOLE `.gd` HALF CAN BE ASKED FOR, and it is opt-in rather than the default because reading a
# thousand scripts means LIFTING a thousand scripts, which is minutes rather than seconds. Every
# reader of this section carries the flag through to the corpus - `EventSheets.migration_report(true)`
# is the public door - and the summary line then says which of the two ran, in both directions: a
# sampled run names both numbers, and a whole read says it was whole. A mode that could only be told
# apart by counting the findings would be a mode nobody could trust the verdict of.
#
# Sheets are opened in memory and dropped. Nothing is written, nothing is cached, and a project whose
# vocabulary is all present reports one summary line and no findings.
@tool
class_name EventSheetMigrationDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id its one finding is filed as. Frozen alongside
## the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "migration"
const CHECK_VERB_GONE := EventSheetMigrationFindings.KIND_VERB_GONE
## The per-sheet line: one file, how many of its rows migrate cleanly and how many ask you. Its own
## id because it is the line the "Apply per sheet" chip hangs off, and a chip on the section's
## summary would offer to migrate a file the summary does not name.
const CHECK_SHEET := "migration-sheet"

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
	# ONE walk for both halves of the section. Opening a sheet is the expensive part of this audit -
	# a `.gd` one is lifted from its text every time - so the words and the per-sheet counts are
	# taken from the same open rather than from two walks of the same corpus.
	var scripts: PackedStringArray = EventSheets.project_scripts()
	var audited: Dictionary = _audit(corpus(sheet_paths, scripts), {},
		sample_note(sheet_paths, scripts))
	var said: Array[Dictionary] = []
	said.assign(audited.get("findings", []))
	var counted: Array[Dictionary] = []
	counted.assign(audited.get("rows", []))
	findings.append_array(said)
	findings.append_array(sheet_lines(counted))


## The project's own corpus, listed the way the audit lists it - what the public report reads when
## nobody hands it a list of its own.
static func project_corpus(read_every_script: bool = false) -> PackedStringArray:
	return corpus(
		EventSheetTemplates.non_template_sheets(EventSheetProjectFind.list_project_sheets()),
		EventSheets.project_scripts(), read_every_script)


## THE PUBLIC REPORT'S ROWS, and the shape is frozen the way an `ace_id` is - see
## `EventSheets.migration_report()`, which is the seam this is served through.
##
## One entry per row of the project that migration has something to say about:
##   {sheet, row, from_id, to_id, before, after, asks}
## `sheet` is the file, `row` its 1-based place among that sheet's verb-carrying rows in reading
## order, `from_id`/`to_id` are "<provider>::<ace_id>" spellings (`to_id` empty when the vocabulary
## has no newer one), `before`/`after` are the lines the row writes now and would write, and `asks`
## is true when a person has to decide. `after` is non-empty exactly when `asks` is false: a row
## nothing can rewrite has no line to show for a rewrite that will not happen.
##
## Sorted by file and then by row, so two machines print the same report. No timestamps, no machine
## paths, nothing remembered between runs.
## `vocabulary` is the corpus to answer against, so a test can hand in a catalogue of its own and the
## editor and the audit can share one reflection of the installed packs.
static func rows(paths: PackedStringArray, vocabulary: Dictionary = {}) -> Array[Dictionary]:
	var listed: Array[Dictionary] = []
	listed.assign(_audit(paths, vocabulary, "").get("rows", []))
	return listed


## One line per sheet the report names: how many of its rows migrate cleanly and how many ask you.
## Filed as findings so they land in the same triage inbox as everything else, and so double-clicking
## one opens the sheet it is about - which is the whole point of a per-sheet line.
##
## NOTHING APPLIES FROM HERE. The chip on one of these lines opens the sheet's own migrate dialog,
## which shows the receipt and owns the undo step. A report that rewrote files from a list nobody was
## looking at would be the fatal version of this feature.
static func sheet_lines(report_rows: Array[Dictionary]) -> Array[Dictionary]:
	var clean: Dictionary = {}
	var asks: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for row: Dictionary in report_rows:
		var path: String = str(row.get("sheet", ""))
		if not order.has(path):
			order.append(path)
			clean[path] = 0
			asks[path] = 0
		if bool(row.get("asks", true)):
			asks[path] = int(asks[path]) + 1
		else:
			clean[path] = int(clean[path]) + 1
	order.sort()
	var lines: Array[Dictionary] = []
	for path: String in order:
		lines.append(_finding("info", CHECK_SHEET, path,
			"%s - %d row(s) migrate cleanly, %d ask you." % [path.get_file(), int(clean[path]),
				int(asks[path])], path))
	return lines


## What the summary line says about its own corpus when that corpus is a SAMPLE: how many of the
## project's scripts were read and how many there are. "" when every one of them was, so an ordinary
## small project's line stays the plain sentence it always was.
##
## It is a sentence rather than a number in a dictionary because the only reader who needs it is the
## person reading the section, and the one thing that must never happen is their reading a count of
## sheets that is not the count of sheets that were opened.
static func sample_note(sheet_paths: PackedStringArray, scripts: PackedStringArray,
		read_every_script: bool = false) -> String:
	var read: PackedStringArray = corpus(sheet_paths, scripts, read_every_script)
	var sampled: int = 0
	for path: String in scripts:
		if read.has(path):
			sampled += 1
	# A WHOLE READ NAMES ITSELF EVEN THOUGH IT HAS NOTHING TO CONFESS. The two modes read different
	# corpora and print the same shape of verdict, so a reader who asked for the whole thing and got
	# the sample by accident - a flag dropped on the way through a build script - would have no way
	# to tell from the line in front of them.
	if read_every_script:
		return " The .gd half was read whole: %d script(s)." % scripts.size()
	if sampled >= scripts.size():
		return ""
	return " The .gd half is a sample: %d of %d script(s) were read." % [sampled, scripts.size()]


## What one audit reads: every stored sheet, then the first few scripts in path order - or every one
## of them when the whole `.gd` half was asked for. Sorted and de-duplicated so two machines read the
## same files in the same order and print the same report, in either mode.
static func corpus(sheet_paths: PackedStringArray, scripts: PackedStringArray,
		read_every_script: bool = false) -> PackedStringArray:
	var stored: PackedStringArray = sheet_paths.duplicate()
	stored.sort()
	var sampled: PackedStringArray = scripts.duplicate()
	sampled.sort()
	var read: PackedStringArray = PackedStringArray()
	for path: String in stored:
		if not read.has(path):
			read.append(path)
	for path: String in sampled:
		if not read_every_script and read.size() >= stored.size() + SCRIPTS_SAMPLED:
			break
		if not read.has(path):
			read.append(path)
	return read


## The whole section as findings, the summary first: how many sheets were read and how many of them
## hold a verb that is gone. Pure over a list of paths, so a test can hand it a corpus of two.
##
## The vocabulary is resolved ONCE for the whole run and handed to every sheet: reflecting the
## installed packs per sheet would be the same answer computed a hundred times.
##
## `vocabulary` is the corpus to answer against, so a test or a staged fixture can hand in one of its
## own; the audit itself passes nothing and gets the shipped catalogue.
static func report(paths: PackedStringArray, vocabulary: Dictionary = {},
		note: String = "") -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	findings.assign(_audit(paths, vocabulary, note).get("findings", []))
	return findings


## The one walk both halves of the section come out of: {"findings": [...], "rows": [...]}.
##
## Each path is opened exactly ONCE, because opening is what this audit costs - a `.gd` sheet is
## lifted from its text every time it is read - and asking the same corpus two questions is not a
## reason to read it twice. The vocabulary is reflected once too and handed to every sheet.
##
## Paths are sorted here rather than trusted from the caller, so two machines read the same files in
## the same order and print the same report whatever order they were handed in.
static func _audit(paths: PackedStringArray, vocabulary: Dictionary,
		note: String = "") -> Dictionary:
	var findings: Array[Dictionary] = []
	var listed: Array[Dictionary] = []
	if paths.is_empty():
		return {"findings": findings, "rows": listed}
	var catalog: Dictionary = vocabulary if not vocabulary.is_empty() else EventForgeSuccessors.catalog()
	var known: Callable = EventSheetMigrationFindings.resolver_over(catalog)
	var importer := GDScriptImporter.new()
	var read: PackedStringArray = paths.duplicate()
	read.sort()
	var measured: int = 0
	var affected: int = 0
	# The summary points at the sheet with the MOST gone verbs, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there. Nothing wrong
	# points at nothing: a line that opens a file for no reason is a line that wastes a click.
	var worst_path: String = ""
	var worst_count: int = 0
	for path: String in read:
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
		for entry: Dictionary in EventSheetMigrationPlan.plan(sheet, catalog):
			listed.append({
				"sheet": path,
				"row": int(entry.get("ordinal", 0)),
				"from_id": str(entry.get("from", "")),
				"to_id": str(entry.get("to", "")),
				"before": str(entry.get("before", "")),
				"after": str(entry.get("after", "")),
				"asks": bool(entry.get("asks", true)),
			})
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		"Migration: %d sheet(s) read, and %d of them hold a verb the installed vocabulary no longer has.%s" % [
			measured, affected, note], ""))
	return {"findings": findings, "rows": listed}


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
