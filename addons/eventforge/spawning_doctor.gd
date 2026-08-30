# Godot EventSheets - the Doctor's Spawning section.
#
# Four checks, and every one of them describes a crash or a hang that the editor is perfectly happy
# with: a node parented while the physics server is flushing, a reference to something that may
# already be freed, a scene whose sheet spawns that same scene on creation, and a wait booked against
# a node an earlier row in the same event removed.
#
# All four are about the ROWS, so they are read out of the project's scripts - opened as sheets in
# memory, measured, and dropped. What each of them MEANS lives in EventSheetSpawnFindings, which is
# also what the canvas hangs under the row, so a reader meets the same sentence wherever they meet
# the problem.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that ships spawning of its own adds its scripts to
# this same section rather than inventing a second report. Registering from the Doctor's own run is
# what makes it show up in all four runners (the panel, the headless CLI, CI and the MCP server)
# without the plugin having to be loaded first.
#
# NOTHING is written and nothing is stored. A project that never spawns pays one substring test per
# script and reports nothing at all.
@tool
class_name EventSheetSpawningDoctor
extends RefCounted

## The id the section is registered under, and the id each finding is filed as. Frozen alongside the
## wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "spawning"
const CHECK_PHYSICS := "spawning-added-during-physics"
const CHECK_MAYBE_FREED := "spawning-maybe-freed"
const CHECK_SELF_SPAWN := "spawning-spawns-itself"
const CHECK_STILL_BOOKED := "spawning-freed-still-booked"

## Which check id each finding reports as. One table, so the note on the row and the line in the
## report are the same finding under two roofs.
const CHECK_FOR_KIND: Dictionary = {
	EventSheetSpawnFindings.KIND_ADDED_DURING_PHYSICS: CHECK_PHYSICS,
	EventSheetSpawnFindings.KIND_MAYBE_FREED: CHECK_MAYBE_FREED,
	EventSheetSpawnFindings.KIND_SPAWNS_ITSELF: CHECK_SELF_SPAWN,
	EventSheetSpawnFindings.KIND_FREED_STILL_BOOKED: CHECK_STILL_BOOKED,
}

## The plugin's own folder, left out of the corpus for the reason every other Doctor corpus leaves it
## out: it is shipped code the project author did not write and cannot usefully edit.
const PLUGIN_DIRECTORY := "res://addons/"

## The cheap first questions asked of a script's TEXT, one per rule. Reading the rows of a script
## means opening it as a sheet, which is the most expensive thing this section can do, so a script is
## only opened when its own text says it could earn one of the four findings.
##
## AND THE QUESTION IS ASKED PER FUNCTION, not per file. "Says add_child somewhere and says
## _physics_process somewhere" describes half the scripts in a game and none of them any better than
## the others; what the rule is about is a parenting INSIDE that callback, so that is what the
## pre-read looks for - the two words in one function body. It is the same move the Multiplayer
## section makes by asking the importer's own question of each line before opening anything, and it
## is the difference between a corpus of seventy-seven and a corpus of five.
##
## Over-admitting here is safe and under-admitting is not: this only decides what gets OPENED, and
## the rules themselves decide what is reported. So every test below is looser than its rule.
const PARENTING_WORD := "add_child("
const FREEING_WORD := "queue_free"
const MEMBER_FREEING_WORD := ".queue_free"
const MAKING_WORD := ".instantiate()"
const PHYSICS_WORDS: PackedStringArray = ["_physics_process", "_body_entered", "_body_exited",
	"_area_entered", "_area_exited"]
const BOOKING_WORDS: PackedStringArray = ["create_timer(", "create_tween("]
const CREATED_WORD := "_ready"

## What a function body begins with at the top level of a file. The pre-read splits on it and parses
## nothing: a body is the lines from one of these to the next.
const FUNCTION_LEAD := "func "

## And the ceiling that stands behind the pre-read: a COUNT, and nothing else. With the per-function
## pre-read in front of it, it is not reached in this repository - it is the floor under a project
## shaped in a way nobody here has seen, so an audit cannot be made unbounded by somebody else's code.
## A run that does reach it still counts every candidate in its summary, so a capped run reads as a
## partial one rather than as a clean one.
##
## NO WALL CLOCK. A ceiling measured in milliseconds makes the report depend on how fast the machine
## reading it is: the same project, audited on a laptop and on a build server, would file different
## findings, and a report that changes without the project changing is not a report anybody can act
## on. The count bounds the same thing the clock was there to bound - how many scripts get opened -
## and it is the same on every machine. The candidates are ranked strongest-evidence-first, so the
## scripts a cut loses are the weakest ones rather than an arbitrary tail.
##
## AND THE NUMBER IS WHAT THE CLOCK WAS BUYING, not a wish. Opening a script as a sheet costs about a
## second, and this repository's own strongest candidates - which include the plugin's tools and tests
## rather than a game's scripts - cost 2.3, 0.6, 0.3 and 0.3 seconds. Three and a bit seconds was what
## the old three-second budget actually allowed here, so four is that same audit written down instead
## of raced for. Raising it is a conversation about the whole audit's budget, which is nearly spent.
##
## Only this project-wide sweep is capped. The notes on a sheet's own rows are derived from that one
## sheet whenever the canvas rebuilds, so the sheet in front of a reader is never one the ceiling cut
## off.
const MEASURED_LIMIT: int = 4


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetSpawningDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(EventSheets.project_scripts()))


## The whole section as findings, the summary first: how many scripts spawn and how many of them have
## something wrong, then the findings themselves. Pure over its corpus, so a test can hand it a list
## of scripts and read the same report the panel shows.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var spawning: int = 0
	var troubled: int = 0
	var measured: int = 0
	# The summary points at the FIRST script with something wrong, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = ""
	var ordered: PackedStringArray = ranked(scripts)
	spawning = ordered.size()
	for script_path: String in ordered:
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
	if spawning <= 0:
		return findings
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		EventSheetL10n.translate("Spawning: %d script(s) that add or destroy nodes, %d read, %d with something that will go wrong at run time.") % [
			spawning, measured, troubled], ""))
	return findings


## What one script contributes. The script is opened as a sheet in memory, measured and dropped -
## nothing is written, and the scene it is attached to is asked for by the same index the head's
## bands read, because the self-spawning rule needs to know which scene this script runs in.
static func sheet_findings(script_path: String) -> Array[Dictionary]:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	if sheet == null:
		return []
	var scenes: PackedStringArray = EventSheetSceneReplication.scenes_using(script_path)
	var scene_path: String = scenes[0] if scenes.size() > 0 else ""
	return _filed(script_path, EventSheetSpawnFindings.findings(sheet, scene_path))


## The scripts of a corpus that could earn a finding, STRONGEST EVIDENCE FIRST and then by path. The
## order is what makes the ceilings above safe to have: a run that stops early stops on the weakest
## candidates rather than on an arbitrary tail, so the sections a reader most needs are the ones that
## survive a big project. Deterministic in both keys, so two audits of an unchanged project read the
## same.
static func ranked(scripts: PackedStringArray) -> PackedStringArray:
	var scored: Array[Dictionary] = []
	for script_path: String in scripts:
		if script_path.begins_with(PLUGIN_DIRECTORY):
			continue
		var weight: int = evidence(FileAccess.get_file_as_string(script_path))
		if weight > 0:
			scored.append({"path": script_path, "weight": weight})
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["weight"]) == int(right["weight"]):
			return str(left["path"]) < str(right["path"])
		return int(left["weight"]) > int(right["weight"]))
	var ordered: PackedStringArray = PackedStringArray()
	for entry: Dictionary in scored:
		ordered.append(str(entry["path"]))
	return ordered


## How much a script's own text says it could earn - a weight per rule whose shape it holds inside
## ONE function body, and 0 for a script that holds none. The three that need a callback weigh more
## than the last, which is the one a declaration is only half of, so a run that ever does reach a
## ceiling loses the weakest evidence rather than an arbitrary tail.
static func evidence(source: String) -> int:
	var weight: int = 0
	for body: String in function_bodies(source):
		if body.contains(PARENTING_WORD) and _says_any(body, PHYSICS_WORDS):
			weight += 2
		if body.contains(FREEING_WORD) and _says_any(body, BOOKING_WORDS):
			weight += 2
		if body.contains(MAKING_WORD) and body.contains(CREATED_WORD):
			weight += 2
	# The maybe-freed rule is the one that SPANS functions - a node stored in one and read in another
	# - so it is asked of the whole file. What narrows it is the declaration: only a member the file
	# types as a node can be the reference that goes stale, and only a free reached through a name can
	# be about a reference somebody stored.
	if source.contains(MEMBER_FREEING_WORD) and declares_a_node(source):
		weight += 1
	return weight


## The function bodies of a file, each one its own head plus the lines under it, in file order. No
## parsing: a body runs from one top-level `func ` to the next, which is all a pre-read needs.
static func function_bodies(source: String) -> PackedStringArray:
	var bodies: PackedStringArray = PackedStringArray()
	var current: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if line.begins_with(FUNCTION_LEAD) or line.begins_with("static " + FUNCTION_LEAD):
			if not current.is_empty():
				bodies.append("\n".join(current))
			current = PackedStringArray()
		current.append(line)
	if not current.is_empty():
		bodies.append("\n".join(current))
	return bodies


## True when a file declares a member typed as a node - the only kind of stored value the maybe-freed
## rule can be about. Asked with ClassDB, which is the same question the removal guard asks of a
## sheet's variables, so the pre-read and the rule agree about what a node is.
static func declares_a_node(source: String) -> bool:
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if not text.begins_with("var ") and not text.begins_with("@onready var ") \
				and not text.begins_with("@export var "):
			continue
		var colon: int = text.find(":")
		if colon < 0:
			continue
		var declared: String = text.substr(colon + 1).strip_edges()
		for stop: String in [" ", "=", ",", ")"]:
			var cut: int = declared.find(stop)
			if cut > 0:
				declared = declared.substr(0, cut)
		if declared.is_empty() or not ClassDB.class_exists(declared):
			continue
		if declared == "Object" or ClassDB.is_parent_class(declared, "Node"):
			return true
	return false


## True when a script's own text says it could earn one of the four findings. Pure over the text, so
## the pre-read is pinned without opening anything.
static func might_earn_a_finding(script_path: String) -> bool:
	return says_enough(FileAccess.get_file_as_string(script_path))


## The same question, asked of the text itself: does anything in it weigh at all.
static func says_enough(source: String) -> bool:
	return evidence(source) > 0


static func _says_any(source: String, words: PackedStringArray) -> bool:
	for word: String in words:
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
