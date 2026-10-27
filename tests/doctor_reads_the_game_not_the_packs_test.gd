# Godot EventSheets - the Doctor measures the reader's game, never the packs installed beside it.
#
# Walked in a user's project with the behaviour packs copied in: the packs are a hundred and forty
# folders of scripts, the game is ten. Six sections still took their corpus straight from the
# project's script list, so in that project the Doctor's Interop table measured pack scripts, its
# reading ledger sampled nothing but packs ("Read the first 12 script(s) of 189"), Performance told
# the reader to rewrite a pack's distance check, Migration counted the packs' sheets, and the
# Effects and Feedbacks summaries double-clicked into a pack. None of it was the reader's to act on.
#
# This repository holds the packs at the same path a user's project does, so asking each section's
# own door here is asking the same question that project asked.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "doctor_reads_the_game_not_the_packs_test"
const PACK_SCRIPT := "res://eventsheet_addons/move_to/move_to_behavior.gd"


static func run() -> bool:
	var ok: bool = SUPPORT.check(TEST_NAME, "a corpus keeps the reader's files, in their order, and drops the shipped ones",
		Array(EventSheetDoctorSection.own_paths(PackedStringArray([
			"res://player.gd", PACK_SCRIPT, "res://addons/eventsheet/plugin.gd", "res://hud.gd"]))),
		["res://player.gd", "res://hud.gd"])
	EventSheetProjectDoctor.clear_project_scripts()
	ok = SUPPORT.check(TEST_NAME, "the project list this repository answers still holds the pack script",
		EventSheetProjectDoctor._project_scripts().has(PACK_SCRIPT), true) and ok
	ok = SUPPORT.check(TEST_NAME, "Performance sweeps no pack for scripts that work every frame",
		_shipped(Array(EventSheetPerformanceDoctor.sweep().get("busy", PackedStringArray()))), []) and ok
	ok = SUPPORT.check(TEST_NAME, "Feedbacks reads no pack's Feedback Player as the game's",
		_shipped(Array(EventSheetFeedbackDoctor.scripts_naming_a_player())), []) and ok
	# The corpus each summary counts is the reader's scripts: Interop leaves out the ones marked to
	# stay code, the ledger and Migration count them all.
	var own: PackedStringArray = EventSheetDoctorSection.own_paths(EventSheetProjectDoctor._project_scripts())
	var unmarked: int = 0
	for path: String in own:
		if not EventSheetInteropDoctor.stays_code(path):
			unmarked += 1
	var counted: Array = []
	var expected: Array = []
	for section: Array in [
			["Interop", EventSheetInteropDoctor, "Interop: (\\d+) script", unmarked],
			["the reading ledger", EventSheetReadingDoctor, "Read the first \\d+ script\\(s\\) of (\\d+)", own.size()],
			["Effects", EventSheetEffectsDoctor, "", 0],
			["Migration", EventSheetMigrationDoctor, "is a sample: \\d+ of (\\d+) script", own.size()]]:
		var findings: Array[Dictionary] = []
		(section[1] as Object).call("check", PackedStringArray(), findings)
		var named: Array = []
		var total: int = -1
		var pattern: RegEx = RegEx.create_from_string(str(section[2])) if not str(section[2]).is_empty() else null
		for finding: Dictionary in findings:
			named.append(str(finding.get("path", "")))
			var found: RegExMatch = pattern.search(str(finding.get("message", ""))) if pattern != null else null
			if found != null:
				total = int(found.get_string(1))
		ok = SUPPORT.check(TEST_NAME, "%s names no pack file in any finding" % str(section[0]), _shipped(named), []) and ok
		if pattern != null:
			counted.append([str(section[0]), total])
			expected.append([str(section[0]), int(section[3])])
	ok = SUPPORT.check(TEST_NAME, "and each summary counts the reader's scripts, not the packs'", counted, expected) and ok
	EventSheetProjectDoctor.clear_project_scripts()
	return ok


## The paths of a list that the plugin ships, in their order.
static func _shipped(paths: Array) -> Array:
	return paths.filter(func(path: Variant) -> bool:
		return str(path).begins_with("res://eventsheet_addons/") or str(path).begins_with("res://addons/"))
