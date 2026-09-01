# Godot EventSheets - THE STANDING CONTRACTS, ASKED FROM A COMMAND LINE.
#
# `tools/verify_sheets.gd` is the gate a team puts in front of a branch: four checks, each one
# sentence of the contract spelled out, answered read-only with an exit code and a file:line per
# failure. This is what it promises.
#
#   1. THE TREE ANSWERS NOTHING. The showcases are compiler output, which makes them the honest
#      corpus for a gate about compiler output: every one of them parses, and every one comes back
#      byte for byte. A green run is proved against real files rather than against fixtures.
#   2. EACH CHECK GOES RED ON ITS OWN FILE, and says which line. Four bad files, four different
#      sentences, and the sentence names the place in the editor that shows the same thing.
#   3. THE MOST SPECIFIC READING WINS. A file whose `_ready` declares one local twice is exactly a
#      file Godot refuses to parse - so it is reported as the doubled local, which has a fix, and
#      not as a parse error, which does not.
#   4. IT READS AND NEVER WRITES. Every fixture below is compared byte for byte with itself after
#      the run that complained about it.
#
# The fixtures live in `user://` so nothing under res:// is touched, and the one real corpus is read
# without being written.
@tool
class_name VerifyCommandTest
extends RefCounted

## The pack that was here once. Invented on purpose: a verb the installed vocabulary does not have
## is the one state nothing can carry a forwarding address for, which is what makes its row ask.
const OLD_PROVIDER := "VerifyProbe"

## The bad files, one per check. `user://` so a test never writes inside res://.
const BROKEN_PATH := "user://eventforge_verify_broken.gd"
const MARKED_PATH := "user://eventforge_verify_marked.gd"
const ENDINGS_PATH := "user://eventforge_verify_endings.gd"
const DOUBLED_PATH := "user://eventforge_verify_doubled.gd"
const ASKING_PATH := "user://eventforge_verify_asking.tres"
const CLEAN_PATH := "user://eventforge_verify_clean.gd"

## The token the doubled fixture declares twice, fixed rather than drawn so the sentence below is a
## value and not a shape.
const DOUBLED_TOKEN := "__peer_a3f81c02"

## A showcase that is generated from a sheet and committed, named so the green run below is proved
## to have actually read something rather than to have read an empty list.
const REAL_FILE := "res://demo/showcase/path_chase/path_chase.gd"


static func run() -> bool:
	var ok: bool = _test_the_tree_answers_nothing()
	ok = _test_a_file_the_engine_refuses() and ok
	ok = _test_a_file_still_holding_markers() and ok
	ok = _test_a_file_that_would_not_come_back() and ok
	ok = _test_which_line_would_come_back_different() and ok
	ok = _test_two_rows_that_mint_the_same_local() and ok
	ok = _test_a_row_waiting_on_a_human() and ok
	ok = _test_what_one_run_reads() and ok
	ok = _test_the_lines_it_prints() and ok
	return ok


# ── 1. the tree answers nothing ───────────────────────────────────────────────────


## The green run, over files nobody wrote for this test. The showcases are regenerated from their
## sheets by the example builder, so they are the same thing a user's project holds: emitted
## GDScript that has to parse and has to come back byte for byte.
##
## The count is not pinned - it is a live tree and it grows - but the corpus is proved non-empty by
## naming one file in it, because a gate that read nothing would pass this test in silence.
static func _test_the_tree_answers_nothing() -> bool:
	var showcases: PackedStringArray = PackedStringArray()
	for path: String in EventSheets.project_scripts():
		if path.begins_with("res://demo/"):
			showcases.append(path)
	var read: PackedStringArray = EventSheetVerify.corpus(showcases)
	var ok: bool = _check("the showcases are a corpus, and this file is in it",
		read.has(REAL_FILE), true)
	var result: Dictionary = EventSheetVerify.run(showcases)
	ok = _check("every committed showcase parses and comes back byte for byte",
		_lines(result), PackedStringArray()) and ok
	ok = _check("and the verdict counts what it read",
		EventSheetVerify.verdict(result),
		"verify: %d file(s) read, nothing to answer." % read.size()) and ok
	return ok


# ── 2. a file the engine refuses ──────────────────────────────────────────────────


## The parse check, and its wording is deliberately about the file rather than about the syntax: the
## engine already printed the line and the reason, and repeating them from a second parser of our own
## is how a gate comes to disagree with the thing that actually refuses to run the game.
static func _test_a_file_the_engine_refuses() -> bool:
	_write(BROKEN_PATH, "extends Node\n\n\nfunc _ready() -> void:\n\t1 +\n")
	var found: Array[Dictionary] = EventSheetVerify.file_failures(BROKEN_PATH)
	var ok: bool = _check("one failure, and it is the parse", _checks(found),
		PackedStringArray([EventSheetVerify.CHECK_PARSES]))
	if ok:
		ok = _check("it says what a file that does not parse is", found[0], {
			"check": "parses", "path": BROKEN_PATH, "line": 0,
			"message": "This file is not valid GDScript. A sheet is its .gd, so this is not a sheet to fix later - it is a file nothing loads.",
			"where": "The engine printed its own Parse Error line above, naming the line; Godot's script editor names the same one.",
		}) and ok
	ok = _writes_nothing(BROKEN_PATH) and ok
	DirAccess.remove_absolute(BROKEN_PATH)
	return ok


# ── 3. a file still holding markers ───────────────────────────────────────────────


## The same check, met by the state that has its own words. A file with markers in it is not GDScript
## either, but "merge markers on lines 5, 7 and 9" is something a person can finish and "this is not
## valid GDScript" is not - and the sentence is the editor's own, off the same guard that opens such
## a file read-only.
static func _test_a_file_still_holding_markers() -> bool:
	_write(MARKED_PATH, "extends Node\n\n\nfunc _ready() -> void:\n<<<<<<< HEAD\n\tspeed = 200\n=======\n\tspeed = 320\n>>>>>>> feature/jump\n")
	var found: Array[Dictionary] = EventSheetVerify.file_failures(MARKED_PATH)
	var ok: bool = _check("one failure, filed as the parse it is", _checks(found),
		PackedStringArray([EventSheetVerify.CHECK_PARSES]))
	if ok:
		ok = _check("it names the first marker line and all of them", found[0], {
			"check": "parses", "path": MARKED_PATH, "line": 5,
			"message": "Merge markers on lines 5, 7 and 9. This is not GDScript, so nothing can read it: not the game, not the editor, not this gate.",
			"where": "EventSheets opens a file in this state read-only, with a banner at the head naming those lines and Show the conflicts beside it.",
		}) and ok
	ok = _writes_nothing(MARKED_PATH) and ok
	DirAccess.remove_absolute(MARKED_PATH)
	return ok


# ── 4. a file that would not come back ────────────────────────────────────────────


## The round-trip check, met by the difference nobody can see: a file that does not end with a
## newline. Saving it from the editor adds one, which is a byte, which is the whole law - and it is
## worth having a gate say so, because a diff tool draws that as a changed line and a person reading
## the two files side by side sees nothing at all.
static func _test_a_file_that_would_not_come_back() -> bool:
	var body: String = "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"hello\")"
	_write(CLEAN_PATH, body + "\n")
	var ok: bool = _check("the same file with its final newline has nothing to answer",
		EventSheetVerify.file_failures(CLEAN_PATH), [])
	_write(ENDINGS_PATH, body)
	var found: Array[Dictionary] = EventSheetVerify.file_failures(ENDINGS_PATH)
	ok = _check("one failure, and it is the round trip", _checks(found),
		PackedStringArray([EventSheetVerify.CHECK_ROUND_TRIP])) and ok
	if not found.is_empty():
		ok = _check("it names the last line and says what the difference is", found[0], {
			"check": "round-trip", "path": ENDINGS_PATH, "line": 5,
			"message": "Opening this file as a sheet and saving it untouched would not reproduce it. The two agree line for line, so what differs is the newline at the end of the file: a file saved from the editor ends with one.",
			"where": "Open the file as a sheet: a line the importer cannot read back stays a verbatim Script block, and this is the first one that would come back changed.",
		}) and ok
	ok = _writes_nothing(ENDINGS_PATH) and ok
	DirAccess.remove_absolute(ENDINGS_PATH)
	DirAccess.remove_absolute(CLEAN_PATH)
	return ok


## The four shapes a difference can have: a line that changed, a line that would be dropped, lines
## that would be added, and a line that differs where nobody can see it. This is the whole of what a
## reader is told about a file that will not come back, so it is pinned as values.
static func _test_which_line_would_come_back_different() -> bool:
	var ok: bool = _check("a changed line quotes both sides",
		EventSheetVerify.first_difference("a\nb\nc\n", "a\nB\nc\n"),
		{"line": 2, "message": "Line 2 would come back as \"B\" instead of \"b\""})
	ok = _check("a dropped line says which one",
		EventSheetVerify.first_difference("a\nb\nc\n", "a\nb\n"),
		{"line": 3, "message": "Line 3 would be dropped: \"c\""}) and ok
	ok = _check("added lines say how many and where they start",
		EventSheetVerify.first_difference("a\n", "a\nb\nc\n"),
		{"line": 2, "message": "2 line(s) would be added, the first of them \"b\""}) and ok
	ok = _check("a difference nobody can see is named rather than quoted twice",
		EventSheetVerify.first_difference("a\nb  \n", "a\nb\n"),
		{"line": 2, "message": "Line 2 differs only in its trailing whitespace: \"b\""}) and ok
	ok = _check("and a line longer than the report is cut, not wrapped",
		EventSheetVerify.first_difference("x".repeat(80) + "\n", "y\n"),
		{"line": 1, "message": "Line 1 would come back as \"y\" instead of \"%s…\"" % "x".repeat(72)}) and ok
	return ok


# ── 5. two rows that mint the same local ──────────────────────────────────────────


## The doubled local, AND the ordering that makes it useful. This file does not parse - that is what
## Godot does with one name declared twice in one scope - so a gate that asked the engine first would
## report a parse error, which nobody can act on, instead of the sentence that names the token and
## the chip that re-mints it.
static func _test_two_rows_that_mint_the_same_local() -> bool:
	_write(DOUBLED_PATH, "extends Node\n\n\nfunc _ready() -> void:\n\tvar %s := 1\n\tprint(%s)\n\tvar %s := 2\n" % [
		DOUBLED_TOKEN, DOUBLED_TOKEN, DOUBLED_TOKEN])
	var found: Array[Dictionary] = EventSheetVerify.file_failures(DOUBLED_PATH)
	var ok: bool = _check("the doubled local is the failure, not the parse error it causes",
		_checks(found), PackedStringArray([EventSheetVerify.CHECK_DUPLICATE_TOKEN]))
	if ok:
		ok = _check("it points at the second declaration, which is the row a merge brought in",
			found[0], {
				"check": "duplicate-local-token", "path": DOUBLED_PATH, "line": 7,
				"message": "Two rows both declare %s in _ready (lines 5, 7). Godot refuses a file that declares one name twice, so this will not run - it is two branches that minted the same token and a merge that brought both in. Re-mint one of them and both rows go on working." % DOUBLED_TOKEN,
				"where": "Project Doctor lists this line with one chip on it, Re-mint one of them, and the re-mint is an ordinary undoable sheet edit.",
			}) and ok
	ok = _writes_nothing(DOUBLED_PATH) and ok
	DirAccess.remove_absolute(DOUBLED_PATH)
	return ok


# ── 6. a row waiting on a human ───────────────────────────────────────────────────


## The fourth check, and the distinction it rests on: a row that migrates cleanly is work one click
## can do and a branch may land with it, while a row that ASKS has moved a decision onto whoever
## opens the file next. Only the second is a failure.
##
## The fixture's verb is not installed anywhere, which is exactly the state that asks: the forwarding
## address would have been carried by the entry that is missing.
static func _test_a_row_waiting_on_a_human() -> bool:
	ResourceSaver.save(_sheet(), ASKING_PATH)
	var result: Dictionary = EventSheetVerify.run(PackedStringArray([ASKING_PATH]))
	var found: Array[Dictionary] = []
	found.assign(result.get("failures", []))
	var ok: bool = _check("the stored sheet is read, and one row asks", _checks(found),
		PackedStringArray([EventSheetVerify.CHECK_MIGRATION_ASKS]))
	if ok:
		ok = _check("it counts to the row the way the sheet does, and quotes what it writes",
			found[0], {
				"check": "migration-asks", "path": ASKING_PATH, "line": 0,
				"message": "Event 1 writes \"polish($Lamp)\" on a verb the installed vocabulary has moved on from, and the rewrite is one nothing can make for you.",
				"where": "Open the sheet and press Migrate… on the head band's counting line: this row is one of the ones it leaves alone, with the reason beside it.",
			}) and ok
	ok = _check("a stored sheet is not asked whether it is GDScript",
		EventSheetVerify.file_failures(ASKING_PATH), []) and ok
	ok = _check("and a row that asks is the only migration failure - a clean rewrite is not one",
		EventSheetVerify.migration_failures([
			{"sheet": "res://player.gd", "row": 3, "from_id": "Old::A", "to_id": "Core::B",
				"before": "a()", "after": "b()", "asks": false},
		]), []) and ok
	DirAccess.remove_absolute(ASKING_PATH)
	return ok


# ── 7. what one run reads ─────────────────────────────────────────────────────────


## The corpus, which is the whole of what "git decides when it runs" means: hand it the staged files
## and it reads those. Sorted so two machines print the same report, de-duplicated because git can
## list a path twice, and forgiving of a path that is not there because a staged deletion is one.
static func _test_what_one_run_reads() -> bool:
	_write(CLEAN_PATH, "extends Node\n")
	ResourceSaver.save(_sheet(), ASKING_PATH)
	var listed: PackedStringArray = EventSheetVerify.corpus(PackedStringArray([
		ASKING_PATH, CLEAN_PATH, CLEAN_PATH, "user://eventforge_verify_gone.gd",
		"res://project.godot", EventSheetVerify.TEMPLATE_DIR + "Node/eventforge_provider.gd",
	]))
	var ok: bool = _check("sorted, de-duplicated, and only the two kinds of file it has a question about",
		listed, PackedStringArray([ASKING_PATH, CLEAN_PATH]))
	ok = _check("a folder of deliberately broken fixtures is named rather than argued with",
		EventSheetVerify.corpus(PackedStringArray([ASKING_PATH, CLEAN_PATH]),
			PackedStringArray(["user://eventforge_verify_c"])),
		PackedStringArray([ASKING_PATH])) and ok
	# The hook hands over what git printed, which is relative to the repository root and means
	# nothing to the engine. Both spellings are the same file, and so are both spellings of a skip.
	ok = _check("a path the way git prints it is the path the engine reads",
		[EventSheetVerify.in_project("demo/showcase/path_chase/path_chase.gd"),
			EventSheetVerify.in_project("./demo/showcase/path_chase/path_chase.gd"),
			EventSheetVerify.in_project(REAL_FILE), EventSheetVerify.in_project(ASKING_PATH)],
		[REAL_FILE, REAL_FILE, REAL_FILE, ASKING_PATH]) and ok
	ok = _check("and a skip written the same way skips the same folder",
		EventSheetVerify.corpus(PackedStringArray(["demo/showcase/path_chase/path_chase.gd"]),
			PackedStringArray(["demo/showcase/"])), PackedStringArray()) and ok
	DirAccess.remove_absolute(CLEAN_PATH)
	DirAccess.remove_absolute(ASKING_PATH)
	return ok


# ── 8. the lines it prints ────────────────────────────────────────────────────────


## What a terminal, a hook and a CI annotation actually show. The file and line lead in the shape
## every compiler prints them in, so an editor that turns such a line into a link does.
static func _test_the_lines_it_prints() -> bool:
	var ok: bool = _check("a failure with a line reads as file:line", EventSheetVerify.failure_line({
		"check": "round-trip", "path": "res://player.gd", "line": 41, "message": "Would not come back.",
		"where": "Open it as a sheet.",
	}), "res://player.gd:41 [round-trip] Would not come back. Open it as a sheet.")
	ok = _check("and one about the whole file leaves the line off", EventSheetVerify.failure_line({
		"check": "parses", "path": "res://player.gd", "line": 0, "message": "Not GDScript.",
		"where": "Godot names the line.",
	}), "res://player.gd [parses] Not GDScript. Godot names the line.") and ok
	ok = _check("a green run says what it read, so nobody wonders whether it ran",
		EventSheetVerify.verdict({"files": 42, "failures": []}),
		"verify: 42 file(s) read, nothing to answer.") and ok
	ok = _check("and a red one counts both", EventSheetVerify.verdict(
		{"files": 42, "failures": [{}, {}]}), "verify: 42 file(s) read, 2 failure(s).") and ok
	return ok


# ── the fixtures ──────────────────────────────────────────────────────────────────


## A one-event sheet whose single action names a verb nothing installs, with the template and the
## reading baked onto it exactly as the dock bakes them at apply time - which is why the row goes on
## compiling to the line it always did while having nowhere to be sent.
static func _sheet() -> EventSheetResource:
	var action: ACEAction = ACEAction.new()
	action.provider_id = OLD_PROVIDER
	action.ace_id = "PolishTheLamp"
	action.codegen_template = "polish($Lamp)"
	action.display_text = "Polish the lamp"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(action)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "VerifyCommandFixture"
	sheet.host_class = "Node"
	sheet.events.append(event)
	return sheet


static func _write(path: String, source: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(source)
		file.close()


## The read-only promise, asked of one fixture: the bytes it had before the gate complained about it
## are the bytes it has after.
static func _writes_nothing(path: String) -> bool:
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	EventSheetVerify.file_failures(path)
	return _check("and the file it complained about is byte for byte what it was",
		FileAccess.get_file_as_bytes(path), before)


## The check ids of a list of failures, which is what most assertions here are about: which check
## spoke, and only that one.
static func _checks(failures: Array[Dictionary]) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for failure: Dictionary in failures:
		said.append(str(failure.get("check", "")))
	return said


## The printed lines of a whole run, so a red green-run test says WHICH file broke rather than that
## a list was not empty.
static func _lines(result: Dictionary) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for failure: Dictionary in (result.get("failures", []) as Array):
		said.append(EventSheetVerify.failure_line(failure))
	return said


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if got == expected:
		print("[PASS] verify_command_test: %s" % label)
		return true
	print("[FAIL] verify_command_test: %s (expected %s, got %s)" % [label, expected, got])
	return false
