# Godot EventSheets - the sheet health card (V20).
#
# Pins VALUES: the exact lines the card draws and which panel each one belongs to, the Doctor counts
# for ONE sheet out of a project-wide report, how a set of Test Sheets reads when one of them failed
# and when none has been run, and the hover the Open Sheets panel shows where a sheet is picked.
@tool
class_name SheetHealthCardTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_card_for_a_sheet() and all_passed
	all_passed = _test_card_lines() and all_passed
	all_passed = _test_doctor_counts() and all_passed
	all_passed = _test_test_results() and all_passed
	all_passed = _test_open_sheets_hover() and all_passed
	return all_passed


static func _fixture_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVariable"
	action.params = {"variable": "score", "value": "10"}
	event.actions.append(action)
	sheet.events.append(event)
	return sheet


static func _test_card_for_a_sheet() -> bool:
	var card: Dictionary = EventSheetHealthCard.card_for(_fixture_sheet(), "res://game/player.gd", [])
	var passed: bool = _check("the card is titled with the file it is about",
		str(card.get("title", "")), "player.gd")
	# A sheet with no script blocks left reads entirely as events - the same measure the Include
	# bar's own chip prints.
	passed = _check("a fully lifted sheet reads as events", int(card.get("percent", 0)), 100) and passed
	passed = _check("a clean sheet has nothing for the Doctor", int(card.get("errors", -1)), 0) and passed
	passed = _check("and nothing unused", int(card.get("unused", -1)), 0) and passed
	return passed


static func _test_card_lines() -> bool:
	var card: Dictionary = {
		"title": "player.gd", "percent": 100, "patterns": 4, "adoptable": 2,
		"errors": 0, "notes": 2, "tests": 3, "test_result": "green", "unused": 1,
	}
	var lines: Array = EventSheetHealthCard.card_lines(card)
	var passed: bool = _check("the reading line says how much reads as events, and its patterns",
		str((lines[0] as Dictionary).get("text", "")), "reads as events 100% · 4 patterns · 2 adoptable")
	passed = _check("clicking it opens the panel that measured it",
		str((lines[0] as Dictionary).get("panel", "")), "coverage") and passed
	passed = _check("the Doctor line counts both kinds",
		str((lines[1] as Dictionary).get("text", "")), "Doctor 0 errors · 2 notes") and passed
	passed = _check("the tests line says how many and how they went",
		str((lines[2] as Dictionary).get("text", "")), "tests: 3 Test Sheets, last run green") and passed
	passed = _check("the unused line counts what nothing uses",
		str((lines[3] as Dictionary).get("text", "")), "unused: 1 thing") and passed
	# A sheet with none of any of it says so plainly rather than showing zeroes.
	var bare: Array = EventSheetHealthCard.card_lines({
		"percent": 82, "patterns": 0, "adoptable": 0, "errors": 1, "notes": 0,
		"tests": 0, "test_result": "", "unused": 0,
	})
	passed = _check("no patterns, no patterns clause",
		str((bare[0] as Dictionary).get("text", "")), "reads as events 82%") and passed
	passed = _check("no tests says so", str((bare[2] as Dictionary).get("text", "")), "tests: none yet") and passed
	passed = _check("nothing unused says so", str((bare[3] as Dictionary).get("text", "")), "unused: nothing") and passed
	return passed


static func _test_doctor_counts() -> bool:
	var findings: Array = [
		{"severity": "error", "path": "res://game/player.gd", "message": "one"},
		{"severity": "warning", "path": "res://game/player.gd", "message": "two"},
		{"severity": "info", "path": "res://game/player.gd", "message": "three"},
		{"severity": "error", "path": "res://game/enemy.gd", "message": "not this sheet's"},
	]
	var counts: Dictionary = EventSheetHealthCard.doctor_counts(findings, "res://game/player.gd")
	var passed: bool = _check("only this sheet's errors count", int(counts.get("errors", -1)), 1)
	passed = _check("warnings and infos are both notes", int(counts.get("notes", -1)), 2) and passed
	return passed


static func _test_test_results() -> bool:
	EventSheetHealthCard.record_test_result("res://tests/a_test.gd", 0)
	EventSheetHealthCard.record_test_result("res://tests/b_test.gd", 0)
	var passed: bool = _check("a run with nothing failing is green",
		EventSheetHealthCard.last_test_result("res://tests/a_test.gd"), "green")
	passed = _check("two green tests read green together",
		EventSheetHealthCard.combined_test_result(
			PackedStringArray(["res://tests/a_test.gd", "res://tests/b_test.gd"])), "green") and passed
	EventSheetHealthCard.record_test_result("res://tests/b_test.gd", 2)
	passed = _check("one failure makes the whole set read failed",
		EventSheetHealthCard.combined_test_result(
			PackedStringArray(["res://tests/a_test.gd", "res://tests/b_test.gd"])), "red") and passed
	passed = _check("a test nobody has run says nothing either way",
		EventSheetHealthCard.combined_test_result(PackedStringArray(["res://tests/never.gd"])), "") and passed
	return passed


## The hover where a sheet is PICKED: where it is stored, how much of it reads as events, and the
## workspace it belongs to.
static func _test_open_sheets_hover() -> bool:
	var passed: bool = _check("an unsaved sheet says so",
		EventSheetOpenSheetsDock.hover_text({"path": ""}), "(unsaved sheet)")
	passed = _check("a saved one leads with its file",
		EventSheetOpenSheetsDock.hover_text({"path": "res://game/player.gd", "health": "reads as events"}),
		"res://game/player.gd\nreads as events") and passed
	passed = _check("and names its workspace when it has one",
		EventSheetOpenSheetsDock.hover_text({"path": "res://game/player.gd", "health": "reads as events",
			"group": "Level 1"}),
		"res://game/player.gd\nreads as events\nLevel 1") and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_health_card_test: %s" % label)
		return true
	print("[FAIL] sheet_health_card_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
