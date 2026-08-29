# EventForge - the documentation chores, and the three doors that call them.
#
# The point of the chores module is that there is ONE of it: a dialog, a command line and a CI job
# all run the same code and get the same report. So this pins the chores themselves - what they
# answer, what they write, and above all what they REFUSE to do - rather than any one door.
#
# THE REFUSALS ARE THE INTERESTING TESTS. A drafted description stays a draft. A save refreshes a
# page that already exists and creates nothing. A chore that has nothing to do says so instead of
# writing an empty file. Automation that quietly did more than it said is the failure this whole
# surface is built to avoid, and these are the assertions that would catch it.
@tool
class_name DocChoresTest
extends RefCounted

const WORK_ROOT := "user://eventsheet_test_chores"


static func run() -> bool:
	# The chores write into the project's own docs folder. Pointed at the user directory for the
	# duration, and put back afterwards, so a suite run leaves nothing in anybody's checkout - and so
	# a serial CI run does not hand the next test a setting this one changed.
	var previous_docs_dir: Variant = ProjectSettings.get_setting(
		EventSheetDocLibrary.USER_DOCS_SETTING, EventSheetDocLibrary.USER_DOCS_DEFAULT)
	ProjectSettings.set_setting(EventSheetDocLibrary.USER_DOCS_SETTING, WORK_ROOT)
	var all_passed: bool = true
	all_passed = _test_the_chore_list() and all_passed
	all_passed = _test_unknown_chore() and all_passed
	all_passed = _test_report_is_one_text() and all_passed
	all_passed = _test_drafts_stay_drafts() and all_passed
	all_passed = _test_one_page_per_sheet() and all_passed
	all_passed = _test_save_refreshes_only_what_exists() and all_passed
	all_passed = _test_search_refreshes_one_page() and all_passed
	all_passed = _test_remembered_boxes() and all_passed
	all_passed = _test_the_ci_file() and all_passed
	all_passed = _test_the_bulk_reduction_agrees() and all_passed
	_clear("%s/manual" % WORK_ROOT)
	_clear(WORK_ROOT)
	ProjectSettings.set_setting(EventSheetDocLibrary.USER_DOCS_SETTING, previous_docs_dir)
	EventSheetDocLibrary.reload()
	return all_passed


static func _test_the_chore_list() -> bool:
	var ids: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetDocChores.chores():
		ids.append(str(entry.get("id", "")))
	var passed: bool = _check("every chore is in the run order, in that order",
		", ".join(ids), ", ".join(EventSheetDocChores.CHORE_ORDER))
	var undescribed: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetDocChores.chores():
		if str(entry.get("label", "")).is_empty() or str(entry.get("note", "")).is_empty():
			undescribed.append(str(entry.get("id", "")))
	passed = _check("and says both what it is and what it costs a person by hand",
		", ".join(undescribed), "") and passed
	return passed


static func _test_unknown_chore() -> bool:
	var report: Dictionary = EventSheetDocChores.run_one("polish-the-brass")
	var passed: bool = _check("an id nobody minted is refused rather than guessed at",
		bool(report.get("ok", true)), false)
	passed = _check("and says so in the same shape as every other chore",
		(report.get("lines", PackedStringArray()) as PackedStringArray).size(), 1) and passed
	return passed


## The report is one text whichever door asked for it, and the chore's own name heads its lines.
static func _test_report_is_one_text() -> bool:
	var report: Dictionary = {"lines": PackedStringArray(["Check coverage and drift:", "  nothing"])}
	return _check("the report is its lines, in order",
		EventSheetDocChores.report_text(report), "Check coverage and drift:\n  nothing")


## Drafting writes drafts, says they are drafts, and applies nothing.
static func _test_drafts_stay_drafts() -> bool:
	var sheet: EventSheetResource = _sheet_with_an_undescribed_function()
	var text: String = EventSheetDocChores.drafts_markdown({"res://player.tres": sheet})
	var passed: bool = _check("the undescribed function is drafted",
		text.contains("heal"), true)
	passed = _check("the file says out loud that nothing was applied",
		text.contains("Nothing here has been applied to a sheet."), true) and passed
	passed = _check("and the sheet itself is untouched",
		EventSheetDescriptions.for_function(sheet.functions[0] as EventFunction).is_empty(),
		true) and passed
	var described: EventSheetResource = _sheet_with_an_undescribed_function()
	(described.functions[0] as EventFunction).description = "Puts hit points back."
	passed = _check("a sheet with nothing missing produces no file at all",
		EventSheetDocChores.drafts_markdown({"res://player.tres": described}), "") and passed
	return passed


## ONE PAGE PER SHEET, and the emphasis is on ONE. A sheet at the project root is filed under its
## own name; a sheet in a folder carries a tail derived from that folder, because the file NAME is
## not a name - res://player/main.gd and res://enemy/main.gd are two sheets, and filing both under
## "main" had one silently overwrite the other on disk, in the search index and in the exported site.
## The tail is derived rather than the folder spelled out, so a published page id does not carry the
## shape of somebody's project.
static func _test_one_page_per_sheet() -> bool:
	var directory: String = EventSheetDocChores.manual_dir()
	var passed: bool = _check("a sheet at the project root is filed under its own name",
		EventSheetDocChores.manual_page_path("res://player.tres"), "%s/player.md" % directory)
	var one: String = EventSheetDocChores.manual_page_path("res://player/main.gd")
	var two: String = EventSheetDocChores.manual_page_path("res://enemy/main.gd")
	passed = _check("two sheets with one file name in two folders own two pages",
		one == two, false) and passed
	passed = _check("and both pages are still recognisably that sheet",
		one.get_file().begins_with("main-") and two.get_file().begins_with("main-"), true) and passed
	passed = _check("the same sheet asks for the same page every time",
		EventSheetDocChores.manual_page_path("res://player/main.gd"), one) and passed
	passed = _check("and the page id says nothing about the folder it came from",
		one.contains("player") or two.contains("enemy"), false) and passed
	passed = _check("the exporter derives the same stem the chore writes to",
		"%s/%s.md" % [directory, EventSheetProjectManual.page_stem("res://player/main.gd")],
		one) and passed
	passed = _check("a path with no file name owns no page",
		EventSheetDocChores.manual_page_path("res://"), "") and passed
	return passed


## THE SMALLEST AUTOMATION. Saving refreshes the page this sheet already has, and never creates one:
## a project that did not ask for a manual does not acquire one because somebody pressed Ctrl+S.
static func _test_save_refreshes_only_what_exists() -> bool:
	var sheet: EventSheetResource = _sheet_with_an_undescribed_function()
	var path: String = EventSheetDocChores.manual_page_path("res://player.tres")
	_delete(path)
	var passed: bool = _check("with no page on disk, a save writes nothing",
		EventSheetDocChores.refresh_after_save("res://player.tres", sheet), false)
	passed = _check("and creates no page either",
		FileAccess.file_exists(path), false) and passed
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_write(path, "# Stale\n")
	passed = _check("with one on disk, a save rewrites it",
		EventSheetDocChores.refresh_after_save("res://player.tres", sheet), true) and passed
	passed = _check("with the page the sheet writes about itself",
		_read(path), EventSheetProjectManual.page_for(sheet)) and passed
	passed = _check("and a second save of an unchanged sheet rewrites nothing",
		EventSheetDocChores.refresh_after_save("res://player.tres", sheet), false) and passed
	_delete(path)
	return passed


## The search entry for one page is rebuilt in place, and the rest of the index does not move.
##
## EVERY SIZE HERE IS READ BACK THROUGH index(), never from the refresh call's own answer, and that
## is the point rather than a convenience: the index rebuilds itself whenever the number of pages it
## was built for stops matching the number the library offers, so a refresh that left those two
## counts disagreeing would be discarded by the very next read while still reporting success.
static func _test_search_refreshes_one_page() -> bool:
	# BOTH CACHES ARE DROPPED FIRST, and that is what makes this deterministic rather than a test
	# whose answer depends on which of its neighbours ran. The two counts can only differ when the
	# library offers an id whose file cannot be read, and a discovery cache holding a page that has
	# since been deleted is exactly how one appears - an earlier test in this same process writes
	# and removes one. Re-scanning leaves every offered page readable, which is the state where
	# recording the wrong count is visible on the very next read.
	EventSheetDocLibrary.reload()
	EventSheetDocSearch.reload()
	var before: int = EventSheetDocSearch.index().size()
	var id: String = "Project/fixture-page"
	var passed: bool = _check("a page the index has never seen joins it",
		EventSheetDocSearch.refresh_page(id, "Fixture", "# Fixture\n\n## Swinging\n\nRope.\n"), true)
	passed = _check("as one entry", EventSheetDocSearch.index().size(), before + 1) and passed
	passed = _check("and it is still there on the read after that",
		EventSheetDocSearch.index().size(), before + 1) and passed
	passed = _check("refreshing it again does not add a second",
		EventSheetDocSearch.refresh_page(id, "Fixture", "# Fixture\n\nRope and hooks.\n"),
		true) and passed
	passed = _check("and the entry carries the NEW words",
		_words_of(id).contains(" hooks "), true) and passed
	passed = _check("an empty id refreshes nothing",
		EventSheetDocSearch.refresh_page("", "x", "y"), false) and passed
	# CI runs the suite serially in one process: an index this test grew must not be the next test's
	# corpus.
	EventSheetDocSearch.reload()
	return passed


static func _words_of(id: String) -> String:
	for entry: Dictionary in EventSheetDocSearch.index():
		if str(entry.get("id", "")) == id:
			return str(entry.get("words", ""))
	return ""


static func _test_remembered_boxes() -> bool:
	var config: ConfigFile = ConfigFile.new()
	var passed: bool = _check("a project that has never been asked runs the two that only describe",
		", ".join(EventSheetDocsHousekeepingDialog.ticked_in(config)), "manual, check")
	config.set_value(EventSheetDocsHousekeepingDialog.SETTINGS_SECTION, "manual", false)
	config.set_value(EventSheetDocsHousekeepingDialog.SETTINGS_SECTION, "site", true)
	passed = _check("and afterwards runs what it was told to, in run order",
		", ".join(EventSheetDocsHousekeepingDialog.ticked_in(config)), "check, site") and passed
	return passed


## The CI file is pinned to this project's engine, says it is the reader's, and runs the two
## commands a person would run.
static func _test_the_ci_file() -> bool:
	var passed: bool = _check("a release version reads as the releases page spells it",
		EventSheetDocsCiWorkflow.version_tag({"major": 4, "minor": 7, "patch": 0,
			"status": "stable"}), "4.7-stable")
	passed = _check("and a patch release keeps its patch",
		EventSheetDocsCiWorkflow.version_tag({"major": 4, "minor": 7, "patch": 2,
			"status": "stable"}), "4.7.2-stable") and passed
	var text: String = EventSheetDocsCiWorkflow.workflow_text("4.7-stable")
	passed = _check("the engine is pinned in the file where it can be edited",
		text.contains("Godot_v4.7-stable_linux.x86_64.zip"), true) and passed
	passed = _check("it runs the check", text.contains("cli.gd -- docs-check"), true) and passed
	passed = _check("and the export", text.contains("cli.gd -- docs-export"), true) and passed
	passed = _check("the site leaves as an artifact rather than being published anywhere",
		text.contains("upload-artifact"), true) and passed
	passed = _check("and the file says it belongs to the reader",
		text.contains("This file is yours."), true) and passed
	return passed


## The bulk reduction and the per-name one are the same reduction. They have to be: one decides
## whether the changelog mentions a verb and the other spells the verb.
static func _test_the_bulk_reduction_agrees() -> bool:
	var packs: PackedStringArray = PackedStringArray(["Quest"])
	var derived: PackedStringArray = PackedStringArray(["advance_objective", "retract_line"])
	var ledger: String = "## [0.9.0]\n- Quest: Advance Objective now counts.\n"
	return _check("a verb the ledger names in its own words is not reported as unwritten",
		", ".join(EventSheetDocCoverage.unwritten_verbs(ledger, packs, derived)), "retract_line")


# ── Fixtures ──────────────────────────────────────────────────────────────────────────────────


static func _sheet_with_an_undescribed_function() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	# A draft is composed from what the rows DO, so a function with no rows has nothing to draft -
	# which is itself the right answer, and would make this fixture pass for the wrong reason.
	var row: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.params = {"message": "\"healed\""}
	row.actions.append(action)
	heal.events.append(row)
	sheet.functions.append(heal)
	return sheet


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


static func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _clear(root: String) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	var files: PackedStringArray = DirAccess.get_files_at(root)
	files.sort()
	for file_name: String in files:
		DirAccess.remove_absolute("%s/%s" % [root, file_name])
	DirAccess.remove_absolute(root)


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	print("[FAIL] %s: expected %s, got %s" % [label, expected, got])
	return false
