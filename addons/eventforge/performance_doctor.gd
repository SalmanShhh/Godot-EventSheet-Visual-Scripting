# Godot EventSheets - the Doctor's Performance section, and the one troubleshooting question that
# rides the same sweep.
#
# The six classic ways a frame gets spent, found across the whole project rather than one sheet at a
# time - and each of them with the fix that is one click away in the editor. Plus one question that
# is not about speed at all: does anything in this game hear about its own errors? It is asked here
# because the answer is in the same text this section is already reading, and reading the corpus a
# second time to ask it would be a second full pass over every script in the project.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that adds its own per-frame vocabulary reports
# into this same section rather than inventing a second one.
#
# THE COST OF ASKING is the design constraint here. Opening every script in a project as a sheet to
# find out that most of them do nothing every frame is a bill every project would pay for nothing,
# so a script is only opened when its TEXT says both halves of the question: something happens every
# frame, and one of the six shapes appears somewhere in it. A project with no per-frame work costs
# one read per script and reports nothing at all.
@tool
class_name EventSheetPerformanceDoctor
extends RefCounted

## The id the section is registered under, and the id each kind of finding is filed as. Frozen
## alongside the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "performance"
const CHECK_LOOKUP := "performance-lookup"
const CHECK_SCAN := "performance-scan"
const CHECK_DISTANCE := "performance-distance"
const CHECK_LOOP := "performance-loop"
const CHECK_CHURN := "performance-churn"
const CHECK_TEXT := "performance-text"

## Which check id each finding reports as. One table, so the note on the row and the line in the
## report are the same finding under two roofs.
const CHECK_FOR_KIND: Dictionary = {
	EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP: CHECK_LOOKUP,
	EventSheetPerformanceFindings.KIND_FULL_SCAN: CHECK_SCAN,
	EventSheetPerformanceFindings.KIND_DISTANCE_ROOT: CHECK_DISTANCE,
	EventSheetPerformanceFindings.KIND_HEAVY_LOOP: CHECK_LOOP,
	EventSheetPerformanceFindings.KIND_SPAWN_CHURN: CHECK_CHURN,
	EventSheetPerformanceFindings.KIND_SAME_TEXT: CHECK_TEXT,
}

## The first half of the question, in the text of the file: does anything here happen every frame?
const PER_FRAME_LINES: PackedStringArray = ["func _process(", "func _physics_process("]

## And the second half: does any of the six shapes appear at all? A file with a per-frame function
## and none of these is never opened.
const SHAPES: PackedStringArray = [
	"get_node(", "get_nodes_in_group(", "get_children()", "distance_to(", "instantiate()", ".text = ",
]


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetPerformanceDoctor, "check"))


## The check id for the one question that is not about speed, and the project setting that answers
## it forever. A game that ignores its own errors on purpose says so once and is never asked again.
const CHECK_NO_REPORT := "no-error-report"
const SUGGEST_SETTING := "eventsheets/doctor/suggest_error_report"


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var swept: Dictionary = sweep()
	findings.append_array(report(PackedStringArray(swept.get("busy", PackedStringArray()))))
	if not bool(swept.get("handles_trouble", true)) and _still_asking():
		findings.append(_finding("info", CHECK_NO_REPORT, "",
			"Nothing in this game hears about its own errors. Add an On Something Went Wrong event to the Game sheet and a build can save the report, show the player something, or skip the broken thing and keep playing - the editor's error strip only helps while you are the one running it.", ""))


## ONE read per script, answering both questions this section asks of the corpus: which scripts are
## worth opening, and whether any of them already hears about trouble.
static func sweep() -> Dictionary:
	var busy: PackedStringArray = PackedStringArray()
	var handles_trouble: bool = false
	for script_path: String in EventSheets.project_scripts():
		var text: String = EventSheetProjectDoctor.source_of(script_path)
		if text.contains(SheetCompiler.TROUBLE_SIGNAL):
			handles_trouble = true
		if _mentions(text, PER_FRAME_LINES) and _mentions(text, SHAPES):
			busy.append(script_path)
	return {"busy": busy, "handles_trouble": handles_trouble}


## Every script in the project worth opening: one that does something every frame AND spells one of
## the six shapes somewhere.
static func busy_scripts() -> PackedStringArray:
	return PackedStringArray(sweep().get("busy", PackedStringArray()))


## Whether the project still wants to be asked about this. Absent means yes, which is what makes it
## a suggestion a new project sees exactly once.
static func _still_asking() -> bool:
	return bool(ProjectSettings.get_setting(SUGGEST_SETTING, true))


static func _mentions(text: String, needles: PackedStringArray) -> bool:
	for needle: String in needles:
		if text.contains(needle):
			return true
	return false


## How many busy scripts this section opens, and how long it is allowed to spend doing it. Opening a
## script as a sheet is the expensive half of every reading the Doctor does, and this section is one
## of several sharing one audit - so it takes a CEILING and says how many of how many it read, the
## same bargain the adoption table strikes. Smallest first, because that reads the most for the
## budget.
##
## Measured over this repository (1,131 scripts, 71 of them doing work every frame): the text sweep
## costs 534 ms and reading six of them another 1.5 s. The whole audit is a shared budget, so this
## section is deliberately one of its smaller lines.
const MEASURED_LIMIT: int = 6
const MEASURE_BUDGET_MSEC: int = 1500


## The whole section as findings, the summary first. Pure over a list of paths, so a test can hand
## it a corpus of two.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if scripts.is_empty():
		return findings
	var importer := GDScriptImporter.new()
	var measured: int = 0
	var safe_fixes: int = 0
	# The summary points at the script with the MOST findings, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = scripts[0]
	var worst_count: int = -1
	var deadline: int = Time.get_ticks_msec() + MEASURE_BUDGET_MSEC
	for script_path: String in _smallest_first(scripts):
		if measured >= MEASURED_LIMIT or Time.get_ticks_msec() > deadline:
			break
		var sheet: EventSheetResource = importer.import_external(script_path)
		if sheet == null:
			continue
		measured += 1
		var mine: Array[Dictionary] = EventSheetPerformanceFindings.findings(sheet)
		if mine.size() > worst_count:
			worst_count = mine.size()
			worst_path = script_path
		safe_fixes += EventSheetPerformanceFindings.safe(mine).size()
		findings.append_array(script_findings(script_path, mine))
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		"Performance: %d of %d script(s) that work every frame were read, and %d of them earn a finding. %d of those fixes are safe to apply together." % [
			measured, scripts.size(), _scripts_with_findings(findings), safe_fixes], ""))
	return findings


## The corpus in the order that reads the most of it for the budget: smallest file first, ties by
## path so two runs on the same project read the same scripts.
static func _smallest_first(scripts: PackedStringArray) -> PackedStringArray:
	var sized: Array[Dictionary] = []
	for script_path: String in scripts:
		sized.append({"path": script_path, "size": _size_of(script_path)})
	sized.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["size"]) == int(right["size"]):
			return str(left["path"]) < str(right["path"])
		return int(left["size"]) < int(right["size"]))
	var ordered: PackedStringArray = PackedStringArray()
	for entry: Dictionary in sized:
		ordered.append(str(entry["path"]))
	return ordered


static func _size_of(script_path: String) -> int:
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	return 0 if file == null else int(file.get_length())


## What one opened script contributes: one line per finding, named by its file so the report reads
## as a project's report rather than as a sheet's.
static func script_findings(script_path: String, mine: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for finding: Dictionary in mine:
		findings.append(_finding("info",
			str(CHECK_FOR_KIND.get(str(finding.get("kind", "")), CHECK_ID)),
			script_path, "%s %s" % [script_path.get_file(), str(finding.get("message", ""))],
			str(finding.get("subject", ""))))
	return findings


## How many distinct scripts the findings so far are about - the number the summary quotes.
static func _scripts_with_findings(findings: Array[Dictionary]) -> int:
	var paths: Dictionary = {}
	for finding: Dictionary in findings:
		paths[str(finding.get("path", ""))] = true
	return paths.size()


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}
