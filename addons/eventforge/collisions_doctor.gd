# Godot EventSheets - the Doctor's Collisions section.
#
# Four checks, and every one of them describes a trigger that is correct and never fires. The sheet
# says "On body entered"; the `.tscn` says which layer the node sits on, which layers it watches,
# whether its monitoring switch is on, and whether it has a shape at all. Nothing in the editor puts
# those two halves in front of the same reader, so this section does - and it is the only place the
# WORDS appear, because the sheet itself stays quiet under the standing rule: an affected row wears
# the amber state and nothing else.
#
# What each finding MEANS lives in EventSheetCollisionFindings, which is also what the canvas reads
# for that amber state and what the selected row's help strip says - so a reader meets the same
# sentence wherever they meet the problem.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that ships collision verbs of its own lands in this
# same section rather than inventing a second report. Registering from the Doctor's own run is what
# makes it show up in all four runners (the panel, the headless CLI, CI and the MCP server) without
# the plugin having to be loaded first.
#
# NOTHING is written and nothing is stored. A project whose scripts never wait on a touch pays one
# substring test per script and reports nothing at all.
@tool
class_name EventSheetCollisionsDoctor
extends RefCounted

## The id the section is registered under, and the id each finding is filed as. Frozen alongside the
## wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "collisions"
const CHECK_CANNOT_SEE := "collisions-nothing-can-reach"
const CHECK_MONITORING := "collisions-monitoring-off"
const CHECK_NO_SHAPE := "collisions-no-shape"
const CHECK_ONE_WAY := "collisions-one-way-facing"

## Which check id each finding reports as. One table, so the amber row, the help strip and the line
## in the report are the same finding under three roofs.
const CHECK_FOR_KIND: Dictionary = {
	EventSheetCollisionFindings.KIND_CANNOT_SEE: CHECK_CANNOT_SEE,
	EventSheetCollisionFindings.KIND_MONITORING_OFF: CHECK_MONITORING,
	EventSheetCollisionFindings.KIND_NO_SHAPE: CHECK_NO_SHAPE,
	EventSheetCollisionFindings.KIND_ONE_WAY_FACING: CHECK_ONE_WAY,
}

## The plugin's own folder, left out of the corpus for the reason every other Doctor corpus leaves it
## out: it is shipped code the project author did not write and cannot usefully edit.
const PLUGIN_DIRECTORY := "res://addons/"

## The words a script's own TEXT has to say before it is opened. Reading the rows of a script means
## opening it as a sheet, which is the most expensive thing this section can do - so a script that
## never asks about a touch is never opened. The first four are the signal names themselves, which is
## what a hand-written `connect` and a lifted trigger row both carry.
##
## And the landing question beside them, because the one-way rule is asked of a sheet that expects
## something to LAND rather than of one waiting on a signal - a moving platform is written as a
## physics loop and connects nothing at all. Left out, that rule's finding was filed against a sheet
## nothing ever opened, which is a finding nobody can read.
const TOUCH_WORDS: PackedStringArray = [
	"body_entered", "body_exited", "area_entered", "area_exited", "is_on_floor",
]

## And the ceiling behind the pre-read: a COUNT, and nothing else. No wall clock - a budget measured
## in milliseconds makes the report depend on how fast the machine reading it is, and the same
## project audited on a laptop and on a build server would file different findings. The candidates
## are sorted, so a run that does reach the ceiling loses a stable tail rather than an arbitrary one,
## and the summary counts every candidate so a capped run reads as a partial one.
const MEASURED_LIMIT: int = 6


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetCollisionsDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(EventSheets.project_scripts()))


## The whole section as findings, the summary first: how many scripts wait on a touch, how many were
## read, and how many of them have something that cannot fire. Pure over its two corpora, so a test
## can hand it a list of scripts and the scenes to measure them against and read the same report the
## panel shows. `scenes` empty means the project's own, which is what every runner passes.
static func report(scripts: PackedStringArray,
		scenes: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var waiting: int = 0
	var troubled: int = 0
	var measured: int = 0
	var worst_path: String = ""
	var ordered: PackedStringArray = ranked(scripts)
	waiting = ordered.size()
	for script_path: String in ordered:
		if measured >= MEASURED_LIMIT:
			break
		measured += 1
		var found: Array[Dictionary] = sheet_findings(script_path, scenes)
		if found.is_empty():
			continue
		if troubled == 0:
			worst_path = script_path
		troubled += 1
		findings.append_array(found)
	if waiting <= 0:
		return findings
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		EventSheetL10n.translate("Collisions: %d script(s) waiting on a touch, %d read, %d whose trigger cannot fire as the scene stands.") % [
			waiting, measured, troubled], ""))
	return findings


## What one script contributes. The script is opened as a sheet in memory, measured and dropped -
## nothing is written, and the scene it is attached to is asked for by the same reader the head's
## bands use, because every rule here needs the node's own numbers.
static func sheet_findings(script_path: String,
		scenes: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	if sheet == null:
		return []
	return _filed(script_path, EventSheetCollisionFindings.findings(sheet, script_path, scenes))


## The scripts worth reading, sorted. The plugin's own are left out, and so is every script that
## never waits on a touch at all.
##
## AND EVERY SCRIPT THAT SITS ON NOTHING THAT COLLIDES. Every rule here is about a node's own layer,
## mask, switch or shape, so a script no single scene runs on a collision object cannot earn one of
## them however many touch signals its text mentions - and a candidate that cannot earn a finding is
## a candidate the ceiling below should never spend itself on. The question is a lookup in the scene
## index the head's bands already read, not a scan, and over this repository it is the difference
## between twenty-five candidates and the handful that could really be wrong.
static func ranked(scripts: PackedStringArray) -> PackedStringArray:
	var ordered: PackedStringArray = PackedStringArray()
	for script_path: String in scripts:
		if script_path.begins_with(PLUGIN_DIRECTORY):
			continue
		if not says_enough(EventSheetProjectDoctor.source_of(script_path)):
			continue
		if EventSheetSceneCollisionFacts.for_script(script_path).is_empty():
			continue
		ordered.append(script_path)
	ordered.sort()
	return ordered


## Does this text wait on a touch at all. Deliberately looser than the rules: it only decides what
## gets OPENED, and the rules decide what is reported.
static func says_enough(source: String) -> bool:
	for word: String in TOUCH_WORDS:
		if source.contains(word):
			return true
	return false


## A family's findings as the Doctor files them: its own severity and wording, under the check id its
## kind maps to, pointing at the file a reader should open.
static func _filed(path: String, found: Array[Dictionary]) -> Array[Dictionary]:
	var filed: Array[Dictionary] = []
	for finding: Dictionary in found:
		filed.append(_finding(str(finding.get("severity", "warning")),
			str(CHECK_FOR_KIND.get(str(finding.get("kind", "")), CHECK_ID)), path,
			"%s %s" % [path.get_file(), str(finding.get("message", ""))],
			str(finding.get("subject", ""))))
	return filed


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}
