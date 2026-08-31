# Godot EventSheets - the Doctor's Tool edits section.
#
# A tool that edits the scene somebody has open owes them their Ctrl+Z. This section is where that
# is said: every tool sheet in the project that changes the open scene outside the editor's undo
# history, and the undoable row that makes the same change as a step the editor can take back.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that ships editor tooling of its own lands in this
# same section rather than inventing a second report. Registering from the Doctor's own run is what
# makes it show up in all four runners (the panel, the headless CLI, CI and the MCP server) without
# the plugin having to be loaded first.
#
# THE CORPUS IS NARROW ON PURPOSE, and the narrowing is the difference between a section worth
# reading and a wall of noise. A @tool script on an ordinary node sets its own properties constantly
# and is right to: it is not editing anybody's scene, and there is no history for it to be missing
# from. So a file is only opened at all when it is a @tool script that ALSO reaches for the scene the
# editor has open - the edited scene root, or the editor's selection - which is the same question the
# rule asks of the rows afterwards, asked once over the raw text first so the ordinary tool script
# costs two substring tests and no import.
#
# NOTHING is written and nothing is stored: a script is opened as a sheet in memory, measured, and
# dropped. A project with no editor tools in it reports nothing at all.
@tool
class_name EventSheetToolEditsDoctor
extends RefCounted

## The id the section is registered under, and the id its one finding is filed as. Frozen alongside
## the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "tool-edits"
const CHECK_NOT_UNDOABLE := EventSheetUndoableFindings.KIND_NOT_UNDOABLE


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetToolEditsDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(scene_editing_tools()))


## Every script in the project that is a tool AND works on the scene the editor has open, in path
## order. Excludes the plugin's own code, like every other Doctor corpus.
##
## A raw-text sweep before the expensive part, for the reason the header gives: importing every
## @tool script in a project to find out that it only ever sets its own properties is a cost a
## project full of ordinary tool scripts would pay for nothing.
static func scene_editing_tools() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for script_path: String in EventSheets.project_scripts():
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if source.contains("@tool") and EventForgeUndoableEdits.touches_open_scene(source):
			found.append(script_path)
	return found


## The whole section as findings, the summary first: how many tools edit the open scene and how many
## of them do it in a way the editor can take back. Pure over a list of paths, so a test can hand it
## a corpus of two.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if scripts.is_empty():
		return findings
	var importer := GDScriptImporter.new()
	var measured: int = 0
	var undoable_tools: int = 0
	# The summary points at the tool with the MOST edits the editor cannot take back, because that is
	# the one worth opening - double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = scripts[0]
	var worst_count: int = -1
	for script_path: String in scripts:
		var sheet: EventSheetResource = importer.import_external(script_path)
		if sheet == null:
			continue
		measured += 1
		var mine: Array[Dictionary] = EventSheetUndoableFindings.findings(sheet, script_path)
		if mine.is_empty():
			undoable_tools += 1
		if mine.size() > worst_count:
			worst_count = mine.size()
			worst_path = script_path
		findings.append_array(script_findings(script_path, mine))
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		"Tool edits: %d tool sheet(s) change the scene the editor has open, and %d of them do it as steps the editor can take back." % [
			measured, undoable_tools], ""))
	return findings


## What one opened tool contributes to the section. Pure over the findings a sheet earned, so the
## wording is pinned without going through the importer.
static func script_findings(script_path: String, mine: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for finding: Dictionary in mine:
		findings.append(_finding("warning", CHECK_NOT_UNDOABLE, script_path,
			str(finding.get("message", "")), str(finding.get("subject", ""))))
	return findings


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}
