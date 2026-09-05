# Godot EventSheets - the Doctor's Feedbacks section.
#
# One check, about the one thing a row on a Feedback Player can silently get wrong: it names a card
# by a LABEL, and a card that has been renamed leaves the row compiling, running, and doing nothing.
# The editor can see that before the game runs, because the scene the sheet's script sits on carries
# the player's list in its own saved bytes.
#
# What the finding MEANS lives in EventSheetFeedbackFindings, which is also what the canvas puts
# into the quiet amber state and what the row's help strip says - so a reader meets the same sentence
# wherever they meet the problem.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that ships feedback of its own lands in this same
# section rather than inventing a second report. Registering from the Doctor's own run is what makes
# it show up in all four runners (the panel, the headless CLI, CI and the MCP server) without the
# plugin having to be loaded first.
#
# THE CORPUS IS NARROW ON PURPOSE. A script is only opened when its own text says it addresses a
# Feedback Player at all, so a project with no feedback in it pays one substring test per script and
# reports nothing.
#
# NOTHING is written and nothing is stored: a script is opened as a sheet in memory, measured, and
# dropped.
@tool
class_name EventSheetFeedbackDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id its one finding is filed as. Frozen alongside
## the wording: the tests and the inbox address a finding by its check id.
const CHECK_ID := "feedbacks"
const CHECK_UNKNOWN_LABEL := EventSheetFeedbackFindings.KIND_UNKNOWN_LABEL

## What a script has to say before it is worth opening. The pack's calls all go through one node
## name, so a file that never writes it can never earn the finding.
const PLAYER_WORD := "$FeedbackPlayer"


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetFeedbackDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(scripts_naming_a_player()))


## Every script in the project that addresses a Feedback Player, in path order. Excludes the
## plugin's own code, like every other Doctor corpus.
static func scripts_naming_a_player() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for script_path: String in EventSheets.project_scripts():
		if EventSheetProjectDoctor.source_of(script_path).contains(PLAYER_WORD):
			found.append(script_path)
	return found


## The whole section as findings, the summary first: how many sheets play a beat through a player,
## and how many labels among them name a card no player in the scene has. Pure over a list of paths,
## so a test can hand it a corpus of one.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if scripts.is_empty():
		return findings
	var measured: int = 0
	var unknown: int = 0
	# The summary points at the sheet with the MOST unknown labels, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = scripts[0]
	var worst_count: int = -1
	for script_path: String in scripts:
		var sheet: EventSheetResource = EventSheetProjectDoctor.sheet_of(script_path)
		if sheet == null:
			continue
		measured += 1
		var mine: Array[Dictionary] = EventSheetFeedbackFindings.findings(sheet, script_path)
		unknown += mine.size()
		if mine.size() > worst_count:
			worst_count = mine.size()
			worst_path = script_path
		findings.append_array(script_findings(script_path, mine))
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		"Feedbacks: %d sheet(s) play a beat through a Feedback Player, and %d row(s) name a feedback no player in their scene has." % [
			measured, unknown], ""))
	return findings


## What one opened sheet contributes to the section. Pure over the findings it earned, so the
## wording is pinned without going through the importer.
static func script_findings(script_path: String, mine: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for finding: Dictionary in mine:
		findings.append(_finding("warning", CHECK_UNKNOWN_LABEL, script_path,
			str(finding.get("message", "")), str(finding.get("subject", ""))))
	return findings
