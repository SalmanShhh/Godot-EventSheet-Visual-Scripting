# Godot EventSheets - the Doctor's Multiplayer section.
#
# After slotting the plugin into a project that already networks, the first question is
# "what did it understand?". This is the answer: every script in the project that touches the
# network, how much of what it says about the network read as rows, the lines it could only show as
# code, and the four mistakes this doctor knows.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that adds its own networking - a lobby service, a
# relay - adds its scripts to this same section rather than inventing a second report. Registering
# from the Doctor's own run is what makes it show up in all four runners (the panel, the headless
# CLI, CI and the MCP server) without the plugin having to be loaded first.
#
# NOTHING is written and nothing is stored: a script is opened as a sheet in memory, measured, and
# dropped. A project with no networking in it costs one substring test per script and reports
# nothing at all.
@tool
class_name EventSheetMultiplayerDoctor
extends RefCounted

## The id the section is registered under, and the ids each kind of finding is filed as. Frozen
## alongside the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "multiplayer"
const CHECK_READING := "multiplayer-reading"
const CHECK_MESSAGE := "multiplayer-message"
const CHECK_HOST_ONLY := "multiplayer-host-only"
const CHECK_AUTHORITY := "multiplayer-authority"
const CHECK_SENDER := "multiplayer-sender"

## Which check id each of the four findings reports as. One table, so the note on the row and the
## line in the report are the same finding under two roofs.
const CHECK_FOR_KIND: Dictionary = {
	EventSheetMultiplayerFindings.KIND_NOT_A_MESSAGE: CHECK_MESSAGE,
	EventSheetMultiplayerFindings.KIND_HOST_ONLY: CHECK_HOST_ONLY,
	EventSheetMultiplayerFindings.KIND_EVERYONE_MOVES: CHECK_AUTHORITY,
	EventSheetMultiplayerFindings.KIND_TRUSTS_SENDER: CHECK_SENDER
}


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetMultiplayerDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(networked_scripts()))


## Every script in the project that says something about the network, in path order. Excludes the
## plugin's own code, like every other Doctor corpus.
##
## A line-by-line sweep with the IMPORTER's own question before the expensive part: importing every
## script in a project to find out it says nothing about the network is a cost every single-player
## project would pay for nothing, and asking a second question about what counts as networking
## would let the corpus and the coverage number disagree.
static func networked_scripts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for script_path: String in EventSheets.project_scripts():
		for line: String in EventSheetProjectDoctor.source_of(script_path).split("\n"):
			if EventForgeMultiplayerLift.is_networking_line(line):
				found.append(script_path)
				break
	return found


## The whole section as findings, the summary first: how many scripts touch the network and how
## much of what they say about it reads as rows, then the scripts with lines the sheet can only
## show as code, then the four. Pure over a list of paths, so a test can hand it a corpus of two.
static func report(scripts: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if scripts.is_empty():
		return findings
	var importer := GDScriptImporter.new()
	var read: int = 0
	var total: int = 0
	var unread_scripts: int = 0
	var measured: int = 0
	# The summary points at the script that read WORST, because that is the one worth opening -
	# double-clicking the line in the panel is what takes the reader there.
	var worst_path: String = scripts[0]
	var worst_percent: int = 101
	for script_path: String in scripts:
		var sheet: EventSheetResource = importer.import_external(script_path)
		if sheet == null:
			continue
		measured += 1
		var coverage: Dictionary = EventSheetReadingCoverage.networking(sheet)
		read += int(coverage.get("read", 0))
		total += int(coverage.get("total", 0))
		if int(coverage.get("percent", 100)) < worst_percent:
			worst_percent = int(coverage.get("percent", 100))
			worst_path = script_path
		if not unread_lines(sheet).is_empty():
			unread_scripts += 1
		findings.append_array(script_findings(script_path, sheet))
	findings.insert(0, _finding("info", CHECK_ID, worst_path,
		"Multiplayer: %d script(s) touch the network, and %d%% of what they say about it reads as rows (%d of %d line(s)). %d have lines the sheet can only show as code." % [
			measured, _percent(read, total), read, total, unread_scripts], ""))
	return findings


## What one opened script contributes to the section: the line saying how much of its networking
## The sheet could only show as code (when there is any), then the findings about it. Pure over a
## sheet, so the wording is pinned without going through the importer.
static func script_findings(script_path: String, sheet: EventSheetResource) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var unread: PackedStringArray = unread_lines(sheet)
	if not unread.is_empty():
		findings.append(_finding("info", CHECK_READING, script_path,
			"%s reads %d%% of its networking as rows - %d line(s) stay code. First: %s" % [
				script_path.get_file(),
				int(EventSheetReadingCoverage.networking(sheet).get("percent", 0)),
				unread.size(), unread[0]],
			unread[0]))
	for finding: Dictionary in EventSheetMultiplayerFindings.findings(sheet):
		findings.append(_finding("warning",
			str(CHECK_FOR_KIND.get(str(finding.get("kind", "")), CHECK_ID)),
			script_path, "%s %s" % [script_path.get_file(), str(finding.get("message", ""))],
			str(finding.get("subject", ""))))
	return findings


## The networking lines an opened script still shows as code - the list the Adopt offer is made
## over, in file order.
static func unread_lines(sheet: EventSheetResource) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for block: RawCodeRow in EventSheetReadingCoverage.script_blocks(sheet):
		for line: String in block.code.split("\n"):
			if EventForgeMultiplayerLift.is_networking_line(line):
				lines.append(line.strip_edges())
	return lines


## The share that read, floored, and 100 for a corpus with nothing in it - the same rule the
## coverage census follows, so the section's number and a head's number can never disagree.
static func _percent(read: int, total: int) -> int:
	return 100 if total <= 0 else int(floor(100.0 * float(read) / float(total)))


static func _finding(severity: String, check_id: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject
	}
