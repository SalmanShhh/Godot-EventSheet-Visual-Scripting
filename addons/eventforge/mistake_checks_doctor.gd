# Godot EventSheets - the Doctor's Mistake checks section.
#
# Nine mistakes a sheet makes that Godot only reports when the game runs: a node of the wrong type, a
# literal res:// path nobody has, a group nothing is in, a $Path the scene lacks, a signal emitted or
# handled with the wrong number of values, a While nothing inside can end, a local that hides a sheet
# variable or a parameter, and a division by a literal zero. The tenth listed on the same board, a
# control the Input Map lacks, is already the Doctor's "unknown-input-action" finding, so it is not
# said twice here - the row that names it wears the amber state on the canvas and offers the same doors.
#
# All of them are about ROWS, so they are read out of the project's scripts - opened as sheets in
# memory, measured and dropped. What each of them MEANS lives in EventSheetMistakeFindings, which is
# also what puts the row into the amber or red state on the canvas and what the help strip says, so a
# reader meets the same sentence wherever they meet the problem.
#
# THE PRE-READ. Opening a script as a sheet is the most expensive thing this section can do, so a
# script is only opened when its own text says it could earn a finding, and the strongest evidence is
# read first. A run that stops at the ceiling loses the weakest candidates, never an arbitrary tail;
# the sheet a reader has OPEN is never one the ceiling cuts off, because the canvas derives its own
# findings from that one sheet.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so it shows up in all four runners (the panel, the headless
# CLI, CI and the MCP server). NOTHING is written and nothing is stored.
@tool
class_name EventSheetMistakeChecksDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id its summary line is filed as.
const CHECK_ID := "mistakes"

## Which check id each finding is filed under. One table, so the row on the canvas and the line in
## the report are the same finding under two roofs.
const CHECK_FOR_KIND: Dictionary = {
	EventSheetMistakeFindings.KIND_WRONG_NODE_TYPE: "wrong-node-type",
	EventSheetMistakeFindings.KIND_MISSING_PATH: "path-not-in-project",
	EventSheetMistakeFindings.KIND_EMPTY_GROUP: "group-nothing-is-in",
	EventSheetMistakeFindings.KIND_MISSING_NODE: "node-path-not-in-scene",
	EventSheetMistakeFindings.KIND_EMIT_COUNT: "signal-emit-value-count",
	EventSheetMistakeFindings.KIND_HANDLER_COUNT: "signal-handler-value-count",
	EventSheetMistakeFindings.KIND_ENDLESS_WHILE: "while-never-ends",
	EventSheetMistakeFindings.KIND_LOCAL_HIDES_VARIABLE: "local-hides-variable",
	EventSheetMistakeFindings.KIND_LOCAL_HIDES_PARAMETER: "local-hides-parameter",
	EventSheetMistakeFindings.KIND_DIVIDE_BY_ZERO: "divide-by-literal-zero",
	EventSheetMistakeFindings.KIND_WRONG_KIND: "value-of-the-wrong-kind",
	EventSheetMistakeFindings.KIND_CONTROL_IN_CONTAINER: "control-inside-a-container",
	EventSheetMistakeFindings.KIND_TWEEN_ON_BODY: "tween-fights-physics-body",
	EventSheetMistakeFindings.KIND_BEHAVIOUR_ON_BODY: "behaviour-fights-physics-body",
	EventSheetListFindings.KIND_UNORDERED_NODE_LIST: "node-list-never-read-by-order",
	EventSheetListFindings.KIND_NEVER_CLEANED: "node-list-never-cleaned",
	EventSheetPickScope.FINDING_KIND: "no-pick-here",
	EventSheetListFindings.KIND_OTHER_OBJECTS_LIST: "reaches-into-another-objects-list",
}

## The missing-control finding is the Doctor's own already (per script, with Add and Pick doors).
const SAID_ELSEWHERE: PackedStringArray = [EventSheetMistakeFindings.KIND_MISSING_ACTION]

## The words a script has to say before it is worth opening, one per rule. Looser than the rules.
const SCENE_WORDS: PackedStringArray = ["$", "%", "get_node("]
const SIGNAL_WORDS: PackedStringArray = [".emit(", "emit_signal(", ".connect("]
const GROUP_WORDS: PackedStringArray = ["_group("]
## The classic mistakes: a Tween, or a write to a position, which a Container or the physics engine may undo.
const CLASSIC_WORDS: PackedStringArray = ["tween_property(", "host.position", "host.global_position", "host.scale", "position =", "position +=", "position.x", "position.y"]

## A ceiling on how many scripts one run opens: a COUNT, never a clock, so the same project reads the
## same on every machine. Candidates are ranked strongest evidence first.
const MEASURED_LIMIT: int = 12

static var _division_regex: RegEx = null
static var _declaration_regex: RegEx = null


## Registers the section, replacing any previous registration.
static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(EventSheetMistakeChecksDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	# The groups of the whole project are listed once and held; built here a few files at a time, so the first
	# sheet judged below does not walk the project in a frame of its own.
	await EventSheetMistakeFindings.project_groups_in_turns()
	# The sheets the report is about to open are opened here, one turn each, so the editor draws between
	# them; the report then finds each one already held for the audit.
	var scripts: PackedStringArray = EventSheetProjectDoctor._project_scripts()
	# Ranked once, in turns, and the ranking handed on: it reads every script of the project.
	var ordered: PackedStringArray = await ranked_in_turns(scripts)
	await EventSheetProjectDoctor.prepare_sheets(ordered.slice(0, MEASURED_LIMIT))
	findings.append_array(await report_in_turns(scripts, ordered))


## The whole section as findings, the summary first (only when something was found: a project with
## nothing to say gets no line). Pure over its corpus, so a test can hand it a list of scripts.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var troubled: int = 0
	var measured: int = 0
	var worst_path: String = ""
	var candidates: PackedStringArray = ranked(scripts)
	for script_path: String in candidates:
		if measured >= MEASURED_LIMIT:
			break
		measured += 1
		var found: Array[Dictionary] = sheet_findings(script_path)
		if found.is_empty():
			continue
		if troubled == 0:
			worst_path = script_path
		troubled += 1
		findings.append_array(found)
	return _with_summary(findings, worst_path, measured, troubled)


## The summary line in front of what was found, only when something was found.
static func _with_summary(findings: Array[Dictionary], worst_path: String, measured: int, troubled: int) -> Array[Dictionary]:
	if findings.is_empty():
		return findings
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		EventSheetL10n.translate("Mistake checks: scripts read: %d; scripts with a line that cannot run or does not do what it says: %d.") % [
			measured, troubled], ""))
	return findings


## `report`, a sheet at a time with a frame between: the same answer, so the editor draws while a project's sheets
## are read and their margin numbers are built (each of those is a whole canvas).
static func report_in_turns(scripts: PackedStringArray, ranked_paths: Variant = null) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var troubled: int = 0
	var measured: int = 0
	var worst_path: String = ""
	var ordered: PackedStringArray = ranked_paths as PackedStringArray if ranked_paths != null else ranked(scripts)
	for script_path: String in ordered:
		if measured >= MEASURED_LIMIT:
			break
		measured += 1
		await EventSheetProjectDoctor.breathe()
		var sheet: EventSheetResource = EventSheetProjectDoctor.sheet_of(script_path)
		if sheet == null:
			continue
		var mine: Array[Dictionary] = await EventSheetMistakeFindings.findings_in_turns(sheet, script_path, EventSheetProjectDoctor.breathe)
		# The margin numbers build a whole canvas, so they are a turn of their own - and only for a sheet
		# with a finding that names an event.
		var named: bool = names_an_event(mine)
		if named:
			await EventSheetProjectDoctor.breathe()
		var found: Array[Dictionary] = script_findings(script_path, mine, EventSheetProjectDoctor.margin_numbers_of(sheet) if named else {})
		if found.is_empty():
			continue
		if troubled == 0:
			worst_path = script_path
		troubled += 1
		findings.append_array(found)
	return _with_summary(findings, worst_path, measured, troubled)


## What one script contributes: its findings, each filed under its own check id with the sheet's
## margin number for the row (so the report says "event 4" the way the margin does).
static func sheet_findings(script_path: String) -> Array[Dictionary]:
	var sheet: EventSheetResource = EventSheetProjectDoctor.sheet_of(script_path)
	if sheet == null:
		return []
	var mine: Array[Dictionary] = EventSheetMistakeFindings.findings(sheet, script_path)
	# The margin is numbered only for a script with a finding that names an event: it builds a whole canvas.
	return script_findings(script_path, mine, EventSheetProjectDoctor.margin_numbers_of(sheet) if names_an_event(mine) else {})


## Whether any of a script's findings is filed with the margin number of an event, which is the only
## thing the number is for. A finding said elsewhere is dropped, and one about the file as a whole
## carries no event.
static func names_an_event(mine: Array[Dictionary]) -> bool:
	for finding: Dictionary in mine:
		if not SAID_ELSEWHERE.has(str(finding.get("kind", ""))) and finding.get("event") is Object:
			return true
	return false


## Pure over the findings it earned, so the wording is pinned without going through the importer.
static func script_findings(script_path: String, mine: Array[Dictionary], numbers: Dictionary = {}) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for finding: Dictionary in mine:
		if SAID_ELSEWHERE.has(str(finding.get("kind", ""))):
			continue
		var filed: Dictionary = _finding(str(finding.get("severity", "warning")),
			str(CHECK_FOR_KIND.get(str(finding.get("kind", "")), CHECK_ID)), script_path,
			"%s %s" % [script_path.get_file(), str(finding.get("message", ""))], str(finding.get("subject", "")))
		var event_row: Object = finding.get("event") as Object
		if event_row != null:
			filed["event"] = int(numbers.get(event_row.get_instance_id(), 0))
		filed["kind"] = str(finding.get("kind", ""))
		filed["to"] = str(finding.get("to", ""))
		filed["lane"] = str(finding.get("lane", ""))
		filed["index"] = int(finding.get("index", -1))
		filed["doors"] = doors_of(finding)
		findings.append(filed)
	return findings


## A row finding's doors as the Doctor's chips read them: [{id, label}], in the strip's order.
static func doors_of(finding: Dictionary) -> Array:
	var doors: Array = []
	for keys: Array in [["fix", "fix_label"], ["second_fix", "second_fix_label"], ["third_fix", "third_fix_label"]]:
		if not str(finding.get(keys[0], "")).is_empty():
			doors.append({"id": str(finding[keys[0]]), "label": str(finding.get(keys[1], ""))})
	return doors


## The scripts of a corpus that could earn a finding, strongest evidence first and then by path.
static func ranked(scripts: PackedStringArray) -> PackedStringArray:
	var scored: Array[Dictionary] = []
	for script_path: String in scripts:
		if _is_shipped(script_path):
			continue
		var weight: int = evidence(EventSheetProjectDoctor.source_of(script_path), script_path)
		if weight > 0:
			scored.append({"path": script_path, "weight": weight})
	return _ordered_paths(scored, "weight", false)


## `ranked`, a few scripts at a time with a frame between turns: the same list, for a project of thousands of scripts.
## What a script's text says is judged on a worker thread; the one rule that asks which scene holds the script is asked
## here on the main thread, of the scripts whose text mentions a node, a turn each.
static func ranked_in_turns(scripts: PackedStringArray) -> PackedStringArray:
	var judged: Array = await EventSheetProjectDoctor.in_batches(scripts, func(batch: PackedStringArray) -> Array:
		var out: Array = []
		for script_path: String in batch:
			if _is_shipped(script_path):
				continue
			var source: String = EventSheetProjectDoctor.source_of(script_path)
			out.append([script_path, evidence_of_text(source), _says_any(source, SCENE_WORDS)])
		return out)
	var scored: Array[Dictionary] = []
	for entry: Variant in judged:
		var row: Array = entry
		var weight: int = int(row[1])
		if bool(row[2]):
			await EventSheetProjectDoctor.breathe()
			var script_path: String = str(row[0])
			if script_path.is_empty() or not EventSheetSceneReplication.scenes_using(script_path).is_empty():
				weight += 1
		if weight > 0:
			scored.append({"path": str(row[0]), "weight": weight})
	return _ordered_paths(scored, "weight", false)


## How much a script's own text says it could earn: one point per rule whose shape it holds. 0 for a
## script that holds none. A script on a scene earns the node rules; a script with the same name
## declared at both levels earns the shadow rule.
static func evidence(source: String, script_path: String = "") -> int:
	var weight: int = evidence_of_text(source)
	if _says_any(source, SCENE_WORDS) and (script_path.is_empty()
			or not EventSheetSceneReplication.scenes_using(script_path).is_empty()):
		weight += 1
	return weight


## `evidence` without the rule that asks which scene holds the script: what the text alone says, touching nothing but the
## text, so it can be asked on a worker thread.
static func evidence_of_text(source: String) -> int:
	var weight: int = 0
	if _says_any(source, SIGNAL_WORDS):
		weight += 1
	if source.contains("\twhile ") or source.contains("\nwhile "):
		weight += 1
	if _division_pattern().search(source) != null:
		weight += 1
	if source.contains("\"res://"):
		weight += 1
	if _says_any(source, CLASSIC_WORDS):
		weight += 1
	if _says_any(source, GROUP_WORDS):
		weight += 1
	if _hides_a_name(source):
		weight += 1
	# A typed variable is what a wrong kind of value is judged against: the weakest evidence, since most scripts have one.
	if source.contains("\nvar ") and source.contains(": "):
		weight += 1
	return weight


static func _division_pattern() -> RegEx:
	if _division_regex == null:
		_division_regex = RegEx.create_from_string("[A-Za-z0-9_)\\]]\\s*[/%]=?\\s*0(?:\\.0*)?(?![\\w.])")
	return _division_regex


## True when a name is declared at the top level of a file and again, indented, in a function.
static func _hides_a_name(source: String) -> bool:
	if _declaration_regex == null:
		_declaration_regex = RegEx.create_from_string("(?m)^(?<indent>[ \\t]*)(?:@\\w+(?:\\([^)]*\\))?\\s+)*var\\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)")
	var top: Dictionary = {}
	var inner: Dictionary = {}
	for hit: RegExMatch in _declaration_regex.search_all(source):
		if hit.get_string("indent").is_empty():
			top[hit.get_string("name")] = true
		else:
			inner[hit.get_string("name")] = true
	for name_text: Variant in inner.keys():
		if top.has(name_text):
			return true
	return false
