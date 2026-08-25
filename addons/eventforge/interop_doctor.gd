# Godot EventSheets - the Doctor's Interop section: adopt at your own pace, and keep what stays code.
#
# Slotting this plugin into a project that already has code raises exactly one question, and it is
# not "how do I convert everything": it is "what did it understand, and where should I start?". This
# is the answer. Every script the project owns, how much of it reads as rows, what a rename would
# need to know about it, and which shipped behaviour could take a hand-written pattern over.
#
# THE SCORE GATES NOTHING. A project at 12% works exactly as well as one at 90%; the number exists so
# a team can SEE the seam move at their own speed, not so anybody chases it. Nothing here writes, and
# nothing here changes what a script does - a file is opened in memory, measured, and dropped.
#
# AND ITS OPPOSITE. A script marked to stay code is never measured, never counted against the score
# and never offered anything. The mark is one comment line, so it survives without the plugin
# installed and reads as what it is to the next person who opens the file in any editor. The physics
# wizard's 800-line solver deserves peace.
#
# WHY IT MEASURES A FEW RATHER THAN ALL. Opening a script as a sheet runs the whole lift, which is
# seconds on a big file. A report that took a minute would be a report nobody ran, so it measures the
# smallest candidates first, within a wall-clock budget, and SAYS how many of how many it read. The
# smallest are also the best next candidates - a small input or UI script is the one that reads 100%.
@tool
class_name EventSheetInteropDoctor
extends RefCounted

## The id the section is registered under, and the ids each kind of line is filed as. Frozen
## alongside the wording: the tests and any quick-fix chip address a finding by its check id.
const CHECK_ID := "interop"
const CHECK_SCRIPT := "interop-script"
const CHECK_ADOPT := "interop-adopt"
const CHECK_STAYS_CODE := "interop-stays-code"

## The mark that keeps a script out of all of this: one comment line, on a line of its own, anywhere
## in the file. A comment because it has to survive the plugin being uninstalled - the file goes on
## saying what its owner decided, and Godot goes on running it byte-identically either way.
const STAYS_CODE_MARK := "# eventsheets: stays code"

## How many scripts one report opens, and how long it may spend doing it. Both are ceilings, not
## targets: the report says what it measured, so a project of two thousand scripts gets a useful
## page in a second rather than a complete one in a minute.
const MEASURED_LIMIT: int = 8
const MEASURE_BUDGET_MSEC: int = 1200


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetInteropDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(EventSheets.project_scripts()))


## Whether this file carries the mark that keeps it code. Read off the file, so it is the same answer
## whether the plugin is asking, a reader is looking, or a diff is being reviewed.
static func stays_code(script_path: String) -> bool:
	if script_path.strip_edges().is_empty():
		return false
	return _marked_in(FileAccess.get_file_as_string(script_path))


## The same question asked of text already in hand, which is how the report asks it: it reads every
## script of the project once and needs the mark and the size out of that one read.
static func _marked_in(text: String) -> bool:
	if not text.contains(STAYS_CODE_MARK):
		return false
	for line: String in text.split("\n"):
		if line.strip_edges() == STAYS_CODE_MARK:
			return true
	return false


## One script's adoption facts: {"path", "reads_as", "lifted", "verbatim", "callers", "adoptable"}.
## `lifted` counts the functions that opened as functions and `verbatim` the ones still sitting as
## code; `callers` is how many other scripts call something this one declares, which is what a rename
## of it would have to check. Pure over a path, so the wording is pinned without a Doctor run.
static func adoption(script_path: String) -> Dictionary:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	if sheet == null:
		return {}
	var coverage: Dictionary = EventSheetReadingCoverage.measure(sheet)
	var verbatim: int = 0
	for row: Variant in sheet.events:
		if row is RawCodeRow and ((row as RawCodeRow).code.begins_with("func ") \
				or (row as RawCodeRow).code.begins_with("static func ")):
			verbatim += 1
	return {
		"path": script_path,
		"reads_as": int(coverage.get("percent", 0)),
		"lifted": sheet.functions.size(),
		"verbatim": verbatim,
		"callers": _caller_count(sheet, script_path),
		"adoptable": _adoptable_names(sheet),
	}


## The whole section as findings: what installing changed (nothing), the score, the best next
## candidates, the Adopt offers in one place, and the scripts their owners marked to stay code.
## Pure over a list of paths, so a test can hand it a corpus of two.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if scripts.is_empty():
		return findings
	# ONE read per script answers both questions - is it marked, and how big is it - because this runs
	# over every script the project owns and reading each of them twice is the whole cost of the
	# section. The lifts below are bounded; this walk is not, so it has to be the cheap half.
	var kept_as_code: PackedStringArray = PackedStringArray()
	var sized: Array[Dictionary] = []
	for script_path: String in scripts:
		var text: String = FileAccess.get_file_as_string(script_path)
		if _marked_in(text):
			kept_as_code.append(script_path)
			continue
		sized.append({"path": script_path, "size": text.length()})
	var measured: Array[Dictionary] = _measure(_smallest_first(sized))
	var candidates: PackedStringArray = PackedStringArray()
	for entry: Dictionary in sized:
		candidates.append(str(entry["path"]))
	findings.append(_finding("info", CHECK_ID, measured[0].get("path", "") if not measured.is_empty() else "",
		EventSheetL10n.translate("Interop: %d script(s) of this project, %d measured, and %d%% of what they hold reads as rows. Installing the plugin changed nothing - a script is code until you open it as a sheet. The score gates nothing; it is there to watch the seam move.") % [
			candidates.size(), measured.size(), _average_reads_as(measured)], ""))
	for entry: Dictionary in measured:
		findings.append(_finding("info", CHECK_SCRIPT, str(entry["path"]), _script_line(entry), ""))
		var adoptable: PackedStringArray = entry["adoptable"]
		if not adoptable.is_empty():
			findings.append(_finding("info", CHECK_ADOPT, str(entry["path"]),
				EventSheetL10n.translate("%s could hand %s to a shipped behaviour - open it and the row says what would change before anything does.") % [
					str(entry["path"]).get_file(), ", ".join(adoptable)], ""))
	for script_path: String in kept_as_code:
		findings.append(_finding("info", CHECK_STAYS_CODE, script_path,
			EventSheetL10n.translate("%s is marked to stay code: never offered anything, never counted, opened read-only.") % script_path.get_file(), ""))
	return findings


## One measured script in a sentence: the share that reads as rows, what that is made of, and what a
## rename of it would have to check.
static func _script_line(entry: Dictionary) -> String:
	var line: String = EventSheetL10n.translate("%s reads as rows: %d%% - %d function(s) opened, %d still code.") % [
		str(entry["path"]).get_file(), int(entry["reads_as"]), int(entry["lifted"]), int(entry["verbatim"])]
	var callers: int = int(entry["callers"])
	if callers > 0:
		line += " " + EventSheetL10n.translate("%d other script(s) call something it declares.") % callers
	return line


## The candidates, smallest file first - which is both the cheapest to measure and, as it happens,
## the best place to start: a small input or UI script is the one that reads 100%.
static func _smallest_first(sized: Array[Dictionary]) -> PackedStringArray:
	sized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["size"]) == int(right["size"]):
			return str(left["path"]) < str(right["path"])
		return int(left["size"]) < int(right["size"]))
	var ordered: PackedStringArray = PackedStringArray()
	for entry: Dictionary in sized:
		ordered.append(str(entry["path"]))
	return ordered


## Opens as many as the ceilings allow, then sorts what it read best-candidate-first: the script that
## already reads as rows is the one to open next, and among equals the smaller.
static func _measure(ordered: PackedStringArray) -> Array[Dictionary]:
	var measured: Array[Dictionary] = []
	var deadline: int = Time.get_ticks_msec() + MEASURE_BUDGET_MSEC
	for script_path: String in ordered:
		if measured.size() >= MEASURED_LIMIT or Time.get_ticks_msec() > deadline:
			break
		var entry: Dictionary = adoption(script_path)
		if not entry.is_empty():
			measured.append(entry)
	measured.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["reads_as"]) == int(right["reads_as"]):
			return str(left["path"]) < str(right["path"])
		return int(left["reads_as"]) > int(right["reads_as"]))
	return measured


## The share that reads as rows across what was measured, floored - and 100 for nothing measured,
## the same rule every other coverage number here follows.
static func _average_reads_as(measured: Array[Dictionary]) -> int:
	if measured.is_empty():
		return 100
	var total: int = 0
	for entry: Dictionary in measured:
		total += int(entry["reads_as"])
	return int(floor(float(total) / float(measured.size())))


## How many OTHER scripts call something this one declares - the number a rename of it would have to
## check, off the one project index. 0 while that index is still counting, which is the honest answer
## to a question nobody has finished asking - and it is asked rather than waited for on purpose: the
## whole audit has a budget, and a health check is not worth a second of somebody's time on its own.
static func _caller_count(sheet: EventSheetResource, script_path: String) -> int:
	if not EventSheetProjectShareIndex.request():
		return 0
	var callers: Dictionary = {}
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction):
			continue
		for caller: String in EventSheetProjectShareIndex.callers_of(
				(entry as EventFunction).function_name, script_path):
			callers[caller] = true
	return callers.size()


## The shipped behaviours this script's own patterns could be handed to, named once each. Read off
## the claim registry every other Adopt offer reads, so the report can only ever list offers a reader
## will actually find on a row.
static func _adoptable_names(sheet: EventSheetResource) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	EventSheetViewportReadingRows.ensure_claims(sheet)
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var adoptable: String = EventSheetPatternVocabulary.adoptable_for(claim as Dictionary)
		if adoptable.is_empty():
			continue
		var label: String = EventSheetPatternVocabulary.pack_label(adoptable)
		if not label.is_empty() and not names.has(label):
			names.append(label)
	return names


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}
