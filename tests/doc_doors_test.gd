# EventSheets - every row is a door, both ways.
#
# A reference entry answers at three depths (what the verb is, the written section that teaches it,
# what the dialog says about its fields) and it answers BACK: where the reader's own project already
# uses it. What this file pins:
#
#   - the ranking that chooses a teaching section, including the two ways it must refuse: evidence
#     too weak to act on, and an empty result list;
#   - the section line a reader is shown before following the link, so the landing is never a
#     surprise;
#   - the template matching the project-wide walk recognises a use by - its literal runs, in order,
#     and the templates that are all placeholder and therefore evidence of nothing;
#   - the walk itself, over a fixture sheet and fixture sources, pinned as values: which sheets, how
#     many uses each, and the order they come back in (which must not depend on the order the
#     caller happened to hand them over in);
#   - the sentences the entry prints, all four of them, including the one that says the project has
#     never used this verb;
#   - that the reading order puts the three depths together at the top of the page.
#
# Needs an editor (not reachable here): that F1 over a real row opens the panel, that "Learn more"
# in the Parameters dialog navigates, and that clicking a project row opens the file and lands on
# the line. Those ride public seams that are pinned by name here instead.
@tool
class_name DocDoorsTest
extends RefCounted

const PROVIDER := "Core"
const ACE_ID := "TestVerb"
const PANEL_PATH := "res://addons/eventsheet/editor/docs/doc_panel.gd"
const DIALOG_PATH := "res://addons/eventsheet/editor/ace_params_dialog.gd"
const API_PATH := "res://addons/eventsheet/api/eventsheets.gd"
const SEARCH_PATH := "res://addons/eventsheet/editor/docs/doc_search.gd"
const DOCK_PATH := "res://addons/eventsheet/editor/event_sheet_dock.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_teaching_section() and all_passed
	all_passed = _test_template_matching() and all_passed
	all_passed = _test_project_walk() and all_passed
	all_passed = _test_sentences() and all_passed
	all_passed = _test_reading_order() and all_passed
	all_passed = _test_seams() and all_passed
	return all_passed


## WHICH SECTION TEACHES A VERB. A heading beats a whole page at the same strength, because a
## heading is the paragraph that teaches it and a page title is a place to start scrolling. And
## evidence weaker than a body hit is refused outright: a subsequence match on a title matches
## almost every page for almost every query, so acting on one would be a confident wrong answer.
static func _test_teaching_section() -> bool:
	var results: Array[Dictionary] = [
		{"doc_id": "guide:GUIDE-A", "page_id": "GUIDE-A", "title": "Guide A", "heading": "",
			"anchor": "", "score": EventSheetDocSearch.SCORE_HEADING_PREFIX},
		{"doc_id": "guide:GUIDE-B", "page_id": "GUIDE-B", "title": "Guide B", "heading": "Waiting",
			"anchor": "waiting", "score": EventSheetDocSearch.SCORE_HEADING_PREFIX},
	]
	var best: Dictionary = EventSheetDocTeaches.best_section(results)
	var all_passed: bool = _check("a heading wins over a whole page at the same strength",
		str(best.get("anchor", "")), "waiting")
	all_passed = _check("and the landing carries the page it is on",
		str(best.get("doc_id", "")), "guide:GUIDE-B") and all_passed
	all_passed = _check("a stronger page still wins over a weaker heading",
		str(EventSheetDocTeaches.best_section([
			{"doc_id": "guide:GUIDE-B", "title": "Guide B", "heading": "Waiting", "anchor": "waiting",
				"score": EventSheetDocSearch.SCORE_BODY},
			{"doc_id": "guide:GUIDE-A", "title": "Guide A", "heading": "", "anchor": "",
				"score": EventSheetDocSearch.SCORE_TITLE_PREFIX},
		] as Array[Dictionary]).get("doc_id", "")), "guide:GUIDE-A") and all_passed
	all_passed = _check("scattered letters in a title are not evidence a section teaches anything",
		EventSheetDocTeaches.best_section([
			{"doc_id": "guide:GUIDE-C", "title": "Guide C", "heading": "", "anchor": "",
				"score": EventSheetDocSearch.SCORE_TITLE_SUBSEQUENCE},
		] as Array[Dictionary]), {}) and all_passed
	all_passed = _check("nothing found is nothing offered",
		EventSheetDocTeaches.best_section([] as Array[Dictionary]), {}) and all_passed

	# What the reader is shown BEFORE they follow it - the page, and the heading inside it.
	all_passed = _check("the line names the page and the heading",
		EventSheetDocTeaches.section_line(best), "Guide B  ·  Waiting") and all_passed
	all_passed = _check("a page-level landing names only the page",
		EventSheetDocTeaches.section_line({"title": "Guide A", "heading": ""}), "Guide A") and all_passed
	all_passed = _check("no section, no line", EventSheetDocTeaches.section_line({}), "") and all_passed
	return all_passed


## WHAT A USE LOOKS LIKE IN A FILE NOBODY HAS OPENED. `.gd` is the default sheet format, so a
## project-wide count that only walked the sheets there is a model of would answer "twice" for a
## project that uses the verb thirty times.
static func _test_template_matching() -> bool:
	var segments: PackedStringArray = EventSheetDocProjectUsage.template_segments(
		"{target.}add_to_group({group}, true)")
	var all_passed: bool = _check("the literal runs of a template, in order",
		", ".join(segments), "add_to_group(, , true)")
	all_passed = _check("punctuation too short to be evidence is not a run",
		", ".join(EventSheetDocProjectUsage.template_segments("{a} = {b}")), "") and all_passed
	all_passed = _check("a template that is all placeholder recognises nothing",
		", ".join(EventSheetDocProjectUsage.template_segments("{value}")), "") and all_passed

	all_passed = _check("a line carrying every run in order is a use",
		EventSheetDocProjectUsage.line_matches("\tself.add_to_group(\"enemies\", true)", segments),
		true) and all_passed
	all_passed = _check("a line missing one of them is not",
		EventSheetDocProjectUsage.line_matches("\tadd_to_group(\"enemies\")", segments), false) and all_passed
	all_passed = _check("and neither is one that carries them back to front",
		EventSheetDocProjectUsage.line_matches("\ttrue, add_to_group(", segments), false) and all_passed
	all_passed = _check("nothing to recognise recognises nothing",
		EventSheetDocProjectUsage.line_matches("add_to_group(x, true)", PackedStringArray()),
		false) and all_passed
	return all_passed


## THE WALK, over a sheet there is a model of and two files there are not. Pinned as values, and
## pinned in ORDER: the list is sorted by path, so two opens of the same entry list the same rows.
static func _test_project_walk() -> bool:
	var segments: PackedStringArray = EventSheetDocProjectUsage.template_segments("{target.}queue_free()")
	var sheets: Dictionary = {"res://b_sheet.tres": _sheet_using(2)}
	var sources: Dictionary = {
		"res://z_last.gd": "func _ready() -> void:\n\tqueue_free()\n",
		"res://a_first.gd": "extends Node\n\n\nfunc _ready() -> void:\n\tget_parent().queue_free()\n",
		"res://c_none.gd": "extends Node\n",
	}
	var found: Array[Dictionary] = EventSheetDocProjectUsage.uses(PROVIDER, ACE_ID, segments, sheets, sources)
	var all_passed: bool = _check("only the files that use it are listed",
		", ".join(_paths(found)), "res://a_first.gd, res://b_sheet.tres, res://z_last.gd")
	all_passed = _check("a modelled sheet is counted by its rows",
		int((found[1] as Dictionary).get("count", 0)), 2) and all_passed
	all_passed = _check("an unopened script is counted by its lines",
		int((found[0] as Dictionary).get("count", 0)), 1) and all_passed
	all_passed = _check("and the line is the one the reader will land on",
		int(((found[0] as Dictionary).get("rows", [])[0] as Dictionary).get("line", 0)), 5) and all_passed
	all_passed = _check("the totals are the sum, over the sheets that had any",
		str(EventSheetDocProjectUsage.totals(found)), str({"total": 4, "sheets": 3})) and all_passed

	# A file that is ALSO an open tab is walked once, as the model - the live version of a sheet is
	# the one being edited, and counting it twice would report uses nobody wrote.
	var doubled: Array[Dictionary] = EventSheetDocProjectUsage.uses(PROVIDER, ACE_ID, segments,
		{"res://a_first.gd": _sheet_using(1)}, sources)
	all_passed = _check("a file that is open is counted once, from the model",
		int((doubled[0] as Dictionary).get("count", 0)), 1) and all_passed

	# The list the entry DRAWS is trimmed; the count it prints is not, so a trimmed list never
	# becomes a smaller number.
	var many: Array[Dictionary] = []
	for index: int in range(EventSheetDocProjectUsage.MAX_SHEETS + 3):
		many.append({"sheet": "res://sheet_%d.gd" % index, "count": 9, "rows": _rows(9)})
	var shown: Array[Dictionary] = EventSheetDocProjectUsage.trimmed(many)
	all_passed = _check("the drawn list stops at the sheet cap",
		shown.size(), EventSheetDocProjectUsage.MAX_SHEETS) and all_passed
	all_passed = _check("and at the row cap inside one sheet",
		(shown[0].get("rows", []) as Array).size(), EventSheetDocProjectUsage.MAX_ROWS_PER_SHEET) and all_passed
	all_passed = _check("trimming never changes a count",
		int(EventSheetDocProjectUsage.totals(shown).get("total", 0)),
		EventSheetDocProjectUsage.MAX_SHEETS * 9) and all_passed
	all_passed = _check("a row is labelled by its file and its line",
		EventSheetDocProjectUsage.row_label("res://levels/one.gd", 42), "one.gd:42") and all_passed
	all_passed = _check("a row with no line is labelled by its file alone",
		EventSheetDocProjectUsage.row_label("res://levels/one.gd", 0), "one.gd") and all_passed
	return all_passed


## THE FOUR SENTENCES, including the one that matters most: a verb the project has never used says
## so plainly. The absence is the answer, not a failure to report.
static func _test_sentences() -> bool:
	var all_passed: bool = _check("never used says so",
		EventSheetDocProjectUsage.sentence(0, 0), "Not used anywhere in this project yet.")
	all_passed = _check("one use reads as one",
		EventSheetDocProjectUsage.sentence(1, 1), "Used once in your project - open it.") and all_passed
	all_passed = _check("several in one sheet name the count",
		EventSheetDocProjectUsage.sentence(4, 1), "Used 4 times in your project - open one.") and all_passed
	all_passed = _check("across several sheets names both",
		EventSheetDocProjectUsage.sentence(12, 3),
		"Used 12 times across 3 sheets in your project - open one.") and all_passed
	return all_passed


## THE THREE DEPTHS SIT TOGETHER. A reader who has to scroll between the entry, the section that
## teaches it and the dialog's own words is reading three pages again.
static func _test_reading_order() -> bool:
	var blocks: Array[Dictionary] = [
		{"kind": "project_usage"}, {"kind": "strip"}, {"kind": "title"}, {"kind": "teaches"},
		{"kind": "prose"}, {"kind": "usage"},
	]
	var plan: String = ", ".join(EventSheetDocPanel.section_plan(blocks))
	return _check("the entry, the section that teaches it and the dialog's words read as one answer",
		plan, "title, description, teaches, strip, usage, project_usage")


## THE SEAMS the editor halves ride, pinned by name because they cannot be exercised headlessly. A
## renamed seam is a door that silently stops opening.
static func _test_seams() -> bool:
	var panel: String = _read(PANEL_PATH)
	var all_passed: bool = _check("the panel asks a host to open a project row",
		panel.contains("signal project_row_requested(sheet_path: String, line: int)"), true)
	all_passed = _check("and to open a page at one heading",
		panel.contains("signal doc_requested_at(doc_id: String, anchor: String)"), true) and all_passed
	all_passed = _check("the Parameters dialog offers the way into the guide",
		_read(DIALOG_PATH).contains("_help_strip.offer_learn_more("), true) and all_passed
	var api: String = _read(API_PATH)
	all_passed = _check("the project-wide join is public",
		api.contains("static func project_uses_of(definition: ACEDefinition)"), true) and all_passed
	all_passed = _check("and so is the landing it offers",
		api.contains("static func reveal_project_row(sheet_path: String, line: int)"), true) and all_passed
	# One cross-sheet landing in the editor, not two: the Manual asks the find bar's own door.
	all_passed = _check("the landing is the find results bar's own",
		api.contains("_dock._find_results.jump_to_line("), true) and all_passed

	# THE SAME DOOR from the other two surfaces. A search result and the picker's info affordance
	# resolve to the SAME id a row's F1 does, which is what makes the stacked answer one page rather
	# than three surfaces that each explain a verb their own way.
	all_passed = _check("a search result for a verb names its entry",
		_read(SEARCH_PATH).contains("\"doc_id\": EventSheetDocExplain.doc_id_for_definition(definition)"),
		true) and all_passed
	all_passed = _check("the picker's info affordance opens the same entry",
		_read(DOCK_PATH).contains("open_documentation(EventSheetDocExplain.doc_id_for_definition(definition))"),
		true) and all_passed
	return all_passed


## A sheet with `count` action rows that all name the same verb.
static func _sheet_using(count: int) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	for index: int in range(count):
		var row: EventRow = EventRow.new()
		var action: ACEAction = ACEAction.new()
		action.provider_id = PROVIDER
		action.ace_id = ACE_ID
		row.actions.append(action)
		sheet.events.append(row)
	return sheet


static func _rows(count: int) -> Array:
	var rows: Array = []
	for index: int in range(count):
		rows.append({"line": index + 1, "preview": ""})
	return rows


static func _paths(found: Array[Dictionary]) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for entry: Dictionary in found:
		paths.append(str(entry.get("sheet", "")))
	return paths


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_doors_test: %s" % label)
		return true
	print("[FAIL] doc_doors_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
