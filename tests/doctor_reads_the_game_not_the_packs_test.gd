# Godot EventSheets - the Doctor measures the reader's game, never the packs installed beside it.
#
# Walked in a user's project with the behaviour packs copied in: the packs are a hundred and forty
# folders of scripts, the game is ten. Six sections still took their corpus straight from the
# project's script list, so in that project the Doctor's Interop table measured pack scripts, its
# reading ledger sampled nothing but packs ("Read the first 12 script(s) of 189"), Performance told
# the reader to rewrite a pack's distance check, Migration counted the packs' sheets, and the
# Effects and Feedbacks summaries double-clicked into a pack, and in the editor the Docs section
# listed stale names in the shipped pack guides. None of it was the reader's to act on.
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
	# The Docs section read the shipped guides wherever it ran, so a stock install opened the Doctor on
	# a page of stale names in the plugin's own pack guides. Outside the plugin's project they are left
	# out; this repository keeps no guide of its own, so what is left is nothing.
	var every_guide: PackedStringArray = EventSheetDocsDoctor.guide_pages()
	ok = SUPPORT.check(TEST_NAME, "the plugin's own project still audits its shipped guides",
		every_guide.has("Addons/Advanced-Random"), true) and ok
	ok = SUPPORT.check(TEST_NAME, "a game the plugin was installed into audits none of them",
		Array(EventSheetDocsDoctor.guide_pages(false)), []) and ok
	EventSheetProjectDoctor.clear_project_scripts()
	ok = _the_readers_own_folder_under_the_packs_is_theirs() and ok
	return ok


## New behaviour, New global and Export Pack all write a folder under eventsheet_addons/, beside the
## packs - so the folder alone cannot say whose a file is. A user's own global there was skipped by
## Interop, the reading ledger, Performance and Migration, and its guide by Docs. The project's script
## list and the guides are handed in through the walks' own caches, so nothing is written to disk.
const USER_GLOBAL := "res://eventsheet_addons/game_state/game_state.gd"
const USER_GUIDE := "res://eventsheet_addons/game_state/guide.md"


static func _the_readers_own_folder_under_the_packs_is_theirs() -> bool:
	var ok: bool = SUPPORT.check(TEST_NAME, "a folder the reader made under the packs is theirs, a shipped pack and a root runtime script are not",
		Array(EventSheetDoctorSection.own_paths(PackedStringArray([
			USER_GLOBAL, PACK_SCRIPT, "res://eventsheet_addons/free_spot.gd", "res://player.gd"]))),
		[USER_GLOBAL, "res://player.gd"])
	EventSheetProjectDoctor.clear_project_scripts()
	EventSheetProjectDoctor._project_scripts_cache = PackedStringArray([PACK_SCRIPT, USER_GLOBAL])
	EventSheetProjectDoctor._project_scripts_walked = true
	EventSheetProjectDoctor._source_cache[USER_GLOBAL] = "extends Node\n\n\nfunc _process(_delta: float) -> void:\n\tfor enemy: Node in get_tree().get_nodes_in_group(\"enemies\"):\n\t\tenemy.set_process(false)\n"
	EventSheetProjectDoctor._source_cache[PACK_SCRIPT] = FileAccess.get_file_as_string(PACK_SCRIPT)
	EventSheetProjectDoctor._sheet_cache[USER_GLOBAL] = GDScriptImporter.new().import_external_source(
		str(EventSheetProjectDoctor._source_cache[USER_GLOBAL]), true, USER_GLOBAL)
	ok = SUPPORT.check(TEST_NAME, "Performance sweeps the reader's own global",
		Array(EventSheetPerformanceDoctor.sweep().get("busy", PackedStringArray())), [USER_GLOBAL]) and ok
	# Interop and Migration say how many scripts they read; the ledger says nothing at all over an
	# empty corpus, so its having a page is the count.
	var counted: Array = []
	for section: Array in [
			["Interop", EventSheetInteropDoctor, "Interop: (\\d+) script"],
			["the reading ledger", EventSheetReadingDoctor, ""],
			["Migration", EventSheetMigrationDoctor, "Migration: (\\d+) sheet\\(s\\) read"]]:
		var findings: Array[Dictionary] = []
		(section[1] as Object).call("check", PackedStringArray(), findings)
		var total: int = -1 if not str(section[2]).is_empty() else mini(findings.size(), 1)
		if not str(section[2]).is_empty():
			var pattern: RegEx = RegEx.create_from_string(str(section[2]))
			for finding: Dictionary in findings:
				var found: RegExMatch = pattern.search(str(finding.get("message", "")))
				if found != null:
					total = int(found.get_string(1))
		counted.append([str(section[0]), total])
	ok = SUPPORT.check(TEST_NAME, "Interop, the ledger and Migration each read the reader's own global",
		counted, [["Interop", 1], ["the reading ledger", 1], ["Migration", 1]]) and ok
	EventSheetProjectDoctor.clear_project_scripts()
	# The guide the reader's own pack keeps beside itself is theirs to fix, in any project.
	var kept_external: Dictionary = EventSheetDocLibrary._external
	var kept_loaded: bool = EventSheetDocLibrary._external_loaded
	EventSheetDocLibrary._external = {
		"Packs/game_state": {"path": USER_GUIDE, "title": "Game State"},
		"Packs/move_to": {"path": "res://eventsheet_addons/move_to/guide.md", "title": "Move To"},
	}
	EventSheetDocLibrary._external_loaded = true
	ok = SUPPORT.check(TEST_NAME, "a game the plugin was installed into still audits the guide of its own pack",
		Array(EventSheetDocsDoctor.guide_pages(false)), ["Packs/game_state"]) and ok
	EventSheetDocLibrary._external = kept_external
	EventSheetDocLibrary._external_loaded = kept_loaded
	return ok


## The paths of a list that the plugin ships, in their order.
static func _shipped(paths: Array) -> Array:
	return paths.filter(func(path: Variant) -> bool:
		return str(path).begins_with("res://eventsheet_addons/") or str(path).begins_with("res://addons/"))
