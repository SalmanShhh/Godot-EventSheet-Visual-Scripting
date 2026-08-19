@tool
class_name EventSheetHealthCard
extends RefCounted
# THE SHEET HEALTH CARD (V20) - how one sheet is doing, at a glance, where the sheet is picked.
#
#   player.gd                                                   health
#   reads as events 100% · 4 patterns · 2 adoptable
#   Doctor 0 errors · 2 notes
#   tests: 3 Test Sheets, last run green
#   unused: 1 variable
#
# Coverage, patterns, the Doctor, the tests and the tidiness sweep each already have their own
# place; the card is one glance across all five, and every line CLICKS THROUGH to the panel that
# owns it, so it stays a summary rather than becoming a sixth place where things live.
#
# Nothing here measures anything twice: the percentage is the reading-coverage measure the Include
# bar's chip prints, the patterns are the pattern registry's own summary, the Doctor lines are the
# Doctor's findings filtered to this sheet, and the tidiness lines are the Loose Ends walk. A card
# that disagreed with the panel it links to would be worse than no card.
#
# Pure and static over a loaded sheet, so the whole card is testable without a dock.

const META_SECTION := "eventsheets"
const META_KEY := "test_results"

## Headless twin of the editor metadata store, so the last-run memory is testable without an editor.
static var _memory: Dictionary = {}


## The whole card for one sheet: `{"title", "percent", "patterns", "adoptable", "errors", "notes",
## "tests", "test_result", "unused"}`. `doctor_findings` is whatever the Doctor last said (the
## caller passes it in rather than making the card run a project-wide sweep on a hover).
static func card_for(sheet: EventSheetResource, sheet_path: String,
		doctor_findings: Array = []) -> Dictionary:
	var coverage: Dictionary = EventSheetReadingCoverage.measure(sheet)
	# The pattern registry is per-rebuild, so a sheet that was merely loaded has claimed nothing
	# yet: state its patterns here the same way a rebuild does, and read the summary off that.
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_patterns(sheet)
	var patterns: Dictionary = EventSheetPatternFacts.summary(sheet)
	var doctor: Dictionary = doctor_counts(doctor_findings, sheet_path)
	var tests: PackedStringArray = test_sheets_for(sheet, sheet_path)
	return {
		"title": sheet_path.get_file() if not sheet_path.is_empty() else "This sheet",
		"percent": int(coverage.get("percent", 100)),
		"patterns": int(patterns.get("patterns", 0)),
		"adoptable": int(patterns.get("adoptable", 0)),
		"errors": int(doctor.get("errors", 0)),
		"notes": int(doctor.get("notes", 0)),
		"tests": tests.size(),
		"test_result": combined_test_result(tests),
		"unused": unused_count(sheet),
	}


## The card as the lines it draws, each naming the panel that owns it so a click can go there:
## `[{"text": String, "panel": String}]`. The panels are "coverage", "patterns", "doctor", "tests"
## and "loose_ends".
static func card_lines(card: Dictionary) -> Array:
	var reading: String = EventSheetL10n.translate("reads as events %d%%") % int(card.get("percent", 100))
	var patterns: int = int(card.get("patterns", 0))
	if patterns > 0:
		reading += " · %s · %s" % [
			EventSheetL10n.translate("%d patterns") % patterns,
			EventSheetL10n.translate("%d adoptable") % int(card.get("adoptable", 0)),
		]
	var doctor: String = "%s · %s" % [
		EventSheetL10n.translate("Doctor %d errors") % int(card.get("errors", 0)),
		EventSheetL10n.translate("%d notes") % int(card.get("notes", 0)),
	]
	var tests: int = int(card.get("tests", 0))
	var tests_line: String = EventSheetL10n.translate("tests: none yet")
	if tests > 0:
		tests_line = "%s, %s" % [
			EventSheetL10n.translate("tests: %d Test Sheets") % tests,
			_result_words(str(card.get("test_result", ""))),
		]
	var unused: int = int(card.get("unused", 0))
	var unused_line: String = EventSheetL10n.translate("unused: nothing")
	if unused == 1:
		unused_line = EventSheetL10n.translate("unused: 1 thing")
	elif unused > 1:
		unused_line = EventSheetL10n.translate("unused: %d things") % unused
	return [
		{"text": reading, "panel": "coverage"},
		{"text": doctor, "panel": "doctor"},
		{"text": tests_line, "panel": "tests"},
		{"text": unused_line, "panel": "loose_ends"},
	]


static func _result_words(result: String) -> String:
	match result:
		"green":
			return EventSheetL10n.translate("last run green")
		"red":
			return EventSheetL10n.translate("last run failed")
	return EventSheetL10n.translate("never run")


## How many errors and how many notes the Doctor has about ONE sheet. Warnings count as notes: a
## card has two numbers, and the panel behind it has the full severities.
static func doctor_counts(findings: Array, sheet_path: String) -> Dictionary:
	var errors: int = 0
	var notes: int = 0
	for entry: Variant in findings:
		var finding: Dictionary = entry
		if not sheet_path.is_empty() and str(finding.get("path", "")) != sheet_path:
			continue
		if str(finding.get("severity", "")) == "error":
			errors += 1
		else:
			notes += 1
	return {"errors": errors, "notes": notes}


## The Test Sheets that test THIS sheet: the ones whose source names it, by path or by the class it
## declares. Nothing links a test to a sheet in the file format, so being named is the link - which
## is also the link a reader would look for.
static func test_sheets_for(sheet: EventSheetResource, sheet_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var runner: GDScript = load("res://addons/eventsheet/editor/test_sheet_runner.gd")
	if runner == null:
		return found
	var declared: String = ""
	if sheet != null:
		declared = str(sheet.get("custom_class_name")).strip_edges()
	var file_name: String = sheet_path.get_file()
	for test_path: String in runner.call("discover", "res://"):
		if test_path == sheet_path:
			continue
		var source: String = FileAccess.get_file_as_string(test_path)
		if source.is_empty():
			continue
		if (not file_name.is_empty() and source.contains(file_name)) \
				or (not declared.is_empty() and source.contains(declared)):
			found.append(test_path)
	return found


## What the tidiness sweep counts as unused about this sheet: the functions nothing calls, plus the
## rows left disabled and the events with nothing in them. The Loose Ends panel is where they are
## listed one by one; this is only how many.
static func unused_count(sheet: EventSheetResource) -> int:
	var counted: int = 0
	for entry: Variant in EventSheetLooseEndsPanel.loose_ends(sheet):
		var kind: String = str((entry as Dictionary).get("kind", ""))
		if kind == "orphan_verb" or kind == "unfinished" or kind == "disabled":
			counted += 1
	return counted


# ── the last run ──────────────────────────────────────────────────────────────────────────────


## Remembers how one sheet's tests last went: "green" when nothing failed, "red" when something
## did. Called by the test window after a run, so the card can say it without running anything.
static func record_test_result(sheet_path: String, failed: int) -> void:
	if sheet_path.strip_edges().is_empty():
		return
	var stored: Dictionary = _all_results()
	stored[sheet_path] = "red" if failed > 0 else "green"
	_memory = stored.duplicate(true)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata(META_SECTION, META_KEY, stored)


## How a set of Test Sheets last went, together: red the moment any one of them failed, green when
## every one that ran passed, and "" while none of them has been run here.
static func combined_test_result(tests: PackedStringArray) -> String:
	var verdict: String = ""
	for test_path: String in tests:
		var one: String = last_test_result(test_path)
		if one == "red":
			return "red"
		if one == "green":
			verdict = "green"
	return verdict


## "green", "red", or "" when this sheet's tests have never been run here.
static func last_test_result(sheet_path: String) -> String:
	return str(_all_results().get(sheet_path, ""))


static func _all_results() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var stored: Variant = EditorInterface.get_editor_settings().get_project_metadata(META_SECTION, META_KEY, {})
		if stored is Dictionary:
			return (stored as Dictionary).duplicate(true)
	return _memory.duplicate(true)
