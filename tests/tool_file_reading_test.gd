# Godot EventSheets - W9 / W10 / W11. The three files a project's TOOLING is written in, read as the
# sheets they already are: a test, a command-line tool, and a behavior pack's recipe.
#
# Two things are pinned here and both are VALUES. The first is the exact sentence each shape reads as
# - `Test ▸ Check "…": … = …`, `Command tool ▸ Finish with code 1`, `Folder ▸ Create …` - because a
# reading is a promise about words. The second is that the file did not move: every reading is
# display-only, so opening one of these files and saving it untouched has to reproduce it byte for
# byte, and the recipe is the one that proves it hardest (it is full of escaped quotes and joined
# string lists, the exact things a lift would corrupt).
#
# The fixtures are this repo's OWN files wherever possible - a real test, a real command tool, a real
# pack recipe - because the claim W9 makes is about 612 real tests rather than about a made-up one.
# A synthetic pair under user:// stands in for a game project's own tests folder, which is the other
# half of the same claim.
@tool
class_name ToolFileReadingTest
extends RefCounted

const REAL_TEST := "res://tests/object_facts_test.gd"
const REAL_COMMAND_TOOL := "res://tools/audit_addons.gd"
const REAL_RECIPE := "res://tools/pack_builders/pin.gd"

## A game project's own test, in its own tests folder - the same shape, none of this repo's names.
const GAME_TEST_PATH := "user://tests/score_rules_test.gd"
const GAME_TEST_SOURCE := """@tool
class_name ScoreRulesTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _check("a coin is worth ten", ScoreRules.value_of("coin"), 10) and passed
	passed = _check("an unknown pickup is worth nothing",
			ScoreRules.value_of("rock"), 0) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] score rules: %s" % label)
		return true
	print("[FAIL] score rules: %s" % label)
	return false
"""

## A command tool with every shape W10 names, in one file.
const GAME_TOOL_PATH := "user://bake_atlas.gd"
const GAME_TOOL_SOURCE := """@tool
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	var path: String = args[0]
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.make_dir_recursive_absolute("res://baked")
	FileAccess.open("res://baked/out.txt", FileAccess.WRITE).store_string(str(resource))
	var folder: DirAccess = DirAccess.open("res://baked")
	folder.list_dir_begin()
	var entry: String = folder.get_next()
	while not entry.is_empty():
		entry = folder.get_next()
	quit()
"""


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_kinds() and all_passed
	all_passed = _test_check_rows() and all_passed
	all_passed = _test_command_rows() and all_passed
	all_passed = _test_recipe_facts() and all_passed
	all_passed = _test_bar_buttons() and all_passed
	all_passed = _test_run_verdicts() and all_passed
	all_passed = _test_head_chips() and all_passed
	all_passed = _test_opened_files() and all_passed
	all_passed = _test_round_trip() and all_passed
	return all_passed


## Which file is which, and - just as important - which is neither. A game script that calls `quit()`
## or writes `passed = ...` must stay exactly as it reads today.
static func _test_kinds() -> bool:
	var passed: bool = true
	passed = _check("a repo test is a test sheet",
		EventSheetToolFiles.kind_of(_lines_of(REAL_TEST), REAL_TEST), "test_sheet") and passed
	passed = _check("a game project's own test is a test sheet too",
		EventSheetToolFiles.kind_of(GAME_TEST_SOURCE.split("\n"), GAME_TEST_PATH), "test_sheet") and passed
	passed = _check("an audit script is a command tool",
		EventSheetToolFiles.kind_of(_lines_of(REAL_COMMAND_TOOL), REAL_COMMAND_TOOL), "command_tool") and passed
	passed = _check("a pack builder is a pack recipe",
		EventSheetToolFiles.kind_of(_lines_of(REAL_RECIPE), REAL_RECIPE), "pack_recipe") and passed
	passed = _check("the same test source outside a tests folder is not a test sheet",
		EventSheetToolFiles.kind_of(GAME_TEST_SOURCE.split("\n"), "res://game/score_rules.gd"), "") and passed
	passed = _check("a plain game script is none of them",
		EventSheetToolFiles.kind_of(PackedStringArray([
			"extends Node", "func _ready() -> void:", "\tget_tree().quit()"
		]), "res://game/player.gd"), "") and passed
	return passed


## The suite's one idiom, as the row it reads as. The template is the whole promise: an object called
## Test, the word Check, the label in quotes, and the two values it compares either side of an `=`.
static func _test_check_rows() -> bool:
	var passed: bool = true
	var context: Dictionary = EventSheetToolFiles.facts(GAME_TEST_SOURCE.split("\n"), GAME_TEST_PATH)
	passed = _check("the accumulator is derived from the file, not assumed",
		", ".join(context.get("test_accumulators", PackedStringArray())), "passed") and passed
	var checks: Array = context.get("test_checks", [])
	passed = _check("both checks are found, wrapped lines and all", checks.size(), 2) and passed
	passed = _check("a one-line check reads as a Check row",
		_sentence_of("\tpassed = _check(\"a coin is worth ten\", ScoreRules.value_of(\"coin\"), 10) and passed", context),
		"Test ▸ Check \"a coin is worth ten\": ScoreRules.value_of(\"coin\") = 10") and passed
	passed = _check("a check wrapped over two lines reads as ONE Check row",
		_sentence_of("\tpassed = _check(\"an unknown pickup is worth nothing\",\n\t\t\tScoreRules.value_of(\"rock\"), 0) and passed", context),
		"Test ▸ Check \"an unknown pickup is worth nothing\": ScoreRules.value_of(\"rock\") = 0") and passed
	passed = _check("the label travels with the reading so a run can colour the row",
		str(EventSheetToolFiles.check_statement(
			"\tpassed = _check(\"a coin is worth ten\", 1, 1) and passed", context).get("check_label", "")),
		"a coin is worth ten") and passed
	# The same line in a file that is NOT a test sheet keeps whatever it read as before.
	passed = _check("a check-shaped line in a game script is not a Check row",
		EventSheetToolFiles.check_statement(
			"\tpassed = _check(\"x\", 1, 1) and passed", {}).is_empty(), true) and passed
	return passed


## The steps only a command tool takes, and the three values only it reads.
static func _test_command_rows() -> bool:
	var passed: bool = true
	var context: Dictionary = EventSheetToolFiles.facts(GAME_TOOL_SOURCE.split("\n"), GAME_TOOL_PATH)
	passed = _check("an exit code is a finish, and it says which",
		_sentence_of("\tquit(1)", context), "Command tool ▸ Finish with code 1") and passed
	passed = _check("a bare quit is just a finish",
		_sentence_of("\tquit()", context), "Command tool ▸ Finish") and passed
	passed = _check("making a folder is the Folder object's own step",
		_sentence_of("\tDirAccess.make_dir_recursive_absolute(\"res://baked\")", context),
		"Folder ▸ Create \"res://baked\"") and passed
	passed = _check("opening and writing in one line is one File row",
		_sentence_of("\tFileAccess.open(\"res://baked/out.txt\", FileAccess.WRITE).store_string(text)", context),
		"File ▸ Write text to \"res://baked/out.txt\"") and passed
	passed = _check("the command line's words are the tool's own expression",
		EventSheetSentence.expression_text("OS.get_cmdline_user_args()", context),
		"Command tool.Arguments") and passed
	passed = _check("a load past the cache says so",
		EventSheetSentence.expression_text("ResourceLoader.load(path, \"\", ResourceLoader.CACHE_MODE_IGNORE)", context),
		"load path ignoring the cache") and passed
	passed = _check("a file read whole is the file's text",
		EventSheetSentence.expression_text("FileAccess.get_file_as_string(path)", context),
		"the file's text") and passed
	passed = _check("the folder walk's local is found from the line that fills it",
		", ".join(PackedStringArray((context.get("command_walk_locals", {}) as Dictionary).keys())),
		"entry") and passed
	passed = _check("the walk's loop header reads as what the four lines mean together",
		_condition_of("not entry.is_empty()", context), "Command tool ▸ For each file in folder") and passed
	passed = _check("the same loop over a local nothing filled is left alone",
		EventSheetToolFiles.command_condition("not name.is_empty()", context).is_empty(), true) and passed
	passed = _check("quit() in a game script still quits the game",
		_sentence_of("\tquit()", {}), "") and passed
	return passed


## What a recipe STATES about the pack it builds (head facts, not rows), and the GDScript hidden
## inside its joined string list - escaped quotes, tabs and annotations included.
static func _test_recipe_facts() -> bool:
	var passed: bool = true
	var lines: PackedStringArray = _lines_of(REAL_RECIPE)
	var head: Dictionary = EventSheetToolFiles.recipe_head(lines)
	passed = _check("the recipe's host is a head fact", str(head.get("host", "")), "Node2D") and passed
	passed = _check("so is the class it ships as", str(head.get("class", "")), "PinBehavior") and passed
	passed = _check("so is its category", str(head.get("category", "")), "Pin") and passed
	passed = _check("the pack it builds is named by save_pack",
		EventSheetToolFiles.recipe_pack_id(lines), "res://eventsheet_addons/pin/pin_behavior") and passed
	var code: PackedStringArray = EventSheetToolFiles.recipe_code_lines(lines)
	passed = _check("the string list opens as the GDScript it becomes",
		code[0] if not code.is_empty() else "", "# --- Designer knobs (tune in the Inspector) ---") and passed
	passed = _check("an escaped quote comes back out as a quote",
		"\n".join(code).contains("## @ace_name(\"Is Pinned\")"), true) and passed
	passed = _check("a tab escape comes back out as a tab",
		"\n".join(code).contains("\n\treturn pin_enabled and is_instance_valid(anchor)"), true) and passed
	passed = _check("an @export line is in there to read as a setting row",
		"\n".join(code).contains("@export var pin_enabled: bool = true"), true) and passed
	return passed


## The exact words each bar says. A button whose text a test does not pin is a button that can drift.
static func _test_bar_buttons() -> bool:
	var passed: bool = true
	EventSheetEditorToolBar.clear_output()
	passed = _check("a test sheet's bar is one Run button",
		_button_words(REAL_TEST), "Run ▸") and passed
	passed = _check("a command tool runs with arguments and shows what it printed",
		_button_words(REAL_COMMAND_TOOL), "Run with arguments… ▸ | Output ▾ no output yet") and passed
	passed = _check("a pack recipe builds its pack and opens the built one",
		_button_words(REAL_RECIPE), "Build pack ▸ | Open built pack ▸") and passed
	passed = _check("the built pack a recipe would open is the one it names",
		EventSheetEditorToolBar.built_pack_path(_open(REAL_RECIPE)),
		"res://eventsheet_addons/pin/pin_behavior.gd") and passed
	passed = _check("a plain game script gets no bar at all",
		EventSheetEditorToolBar.buttons_for(_open("res://tests/fixtures/object_facts_player.gd")).size(), 0) and passed
	return passed


## Running one test headless, and what its output says about each row. The run itself is not spawned
## here (a test that spawns a second editor is a test that takes a minute); what IS pinned is the two
## halves that decide what a reader sees - the runner script the run is made through, and the reading
## of the [PASS] / [FAIL] lines it prints back.
static func _test_run_verdicts() -> bool:
	var passed: bool = true
	passed = _check("the one-off runner loads the test and finishes with its verdict",
		EventSheetEditorToolBar.single_test_runner_source("res://tests/score_rules_test.gd"),
		"\n".join(PackedStringArray([
			"@tool",
			"extends SceneTree",
			"",
			"",
			"func _init() -> void:",
			"\tvar script: Script = load(\"res://tests/score_rules_test.gd\")",
			"\tvar passed: bool = bool(script.call(\"run\")) if script != null else false",
			"\tquit(0 if passed else 1)",
			""
		]))) and passed
	var labels: PackedStringArray = PackedStringArray(["a coin is worth ten", "an unknown pickup is worth nothing"])
	var verdicts: Dictionary = EventSheetEditorToolBar.parse_check_verdicts("\n".join(PackedStringArray([
		"[PASS] score rules: a coin is worth ten",
		"[FAIL] score rules: an unknown pickup is worth nothing",
		"some other line nobody cares about",
	])), labels)
	passed = _check("a passing check is read as passing", bool(verdicts.get("a coin is worth ten", false)), true) and passed
	passed = _check("a failing check is read as failing",
		bool(verdicts.get("an unknown pickup is worth nothing", true)), false) and passed
	EventSheetEditorToolBar.clear_checks()
	passed = _check("a check nothing has run says nothing",
		EventSheetEditorToolBar.check_verdict("res://tests/x.gd", "a coin is worth ten") == null, true) and passed
	EventSheetEditorToolBar.record_checks("res://tests/x.gd", verdicts)
	passed = _check("a recorded run answers for its own test",
		bool(EventSheetEditorToolBar.check_verdict("res://tests/x.gd", "a coin is worth ten")), true) and passed
	EventSheetEditorToolBar.clear_checks()
	return passed


## The head chips each kind states, in bar order.
static func _test_head_chips() -> bool:
	var passed: bool = true
	passed = _check("a test sheet says what it is and how many checks it makes",
		" · ".join(EventSheetToolFiles.head_chips("test_sheet", 5)), "test sheet · 5 checks") and passed
	passed = _check("one check is not pluralised",
		" · ".join(EventSheetToolFiles.head_chips("test_sheet", 1)), "test sheet · 1 check") and passed
	passed = _check("a command tool says it runs headless",
		" · ".join(EventSheetToolFiles.head_chips("command_tool", 0)), "command tool · runs headless") and passed
	passed = _check("a recipe states the pack it builds, and states it once",
		" · ".join(EventSheetToolFiles.head_chips("pack_recipe", 0,
			EventSheetToolFiles.recipe_head(_lines_of(REAL_RECIPE)))),
		"pack recipe · host Node2D · class PinBehavior · category Pin") and passed
	return passed


## The rows a real opened file actually draws - the half a static reading cannot prove on its own.
static func _test_opened_files() -> bool:
	var passed: bool = true
	_write(GAME_TEST_PATH, GAME_TEST_SOURCE)
	var readings: PackedStringArray = _open_and_read(GAME_TEST_PATH)
	passed = _check("the test's entry point reads under Test, not under Functions",
		_has(readings, "Test ▸ On run"), true) and passed
	passed = _check("a Check row is drawn for the coin claim",
		_has(readings, "Test ▸ Check \"a coin is worth ten\": ScoreRules.value_of(\"coin\") = 10"), true) and passed
	passed = _check("the head says it is a test sheet",
		_has(readings, "test sheet"), true) and passed
	passed = _check("the head counts the checks", _has(readings, "2 checks"), true) and passed
	_write(GAME_TOOL_PATH, GAME_TOOL_SOURCE)
	var tool_readings: PackedStringArray = _open_and_read(GAME_TOOL_PATH)
	passed = _check("a command tool's _init reads as the run it is",
		_has(tool_readings, "Command tool ▸ On run"), true) and passed
	passed = _check("the head says it runs headless",
		_has(tool_readings, "runs headless"), true) and passed
	return passed


## The standing contract, on the three hardest files in the repo: a reading may not move a byte. The
## recipe is the one that matters most - it is a file of escaped quotes and joined string lists.
static func _test_round_trip() -> bool:
	var passed: bool = true
	for path: String in [REAL_TEST, REAL_COMMAND_TOOL, REAL_RECIPE, GAME_TEST_PATH, GAME_TOOL_PATH]:
		passed = _round_trips(path) and passed
	return passed


static func _round_trips(path: String) -> bool:
	var source: String = FileAccess.get_file_as_string(path)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var output: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
	return _check("%s saves every byte back" % path.get_file(), output, source)


# ── Helpers ───────────────────────────────────────────────────────────────────────────────────────


static func _lines_of(path: String) -> PackedStringArray:
	return FileAccess.get_file_as_string(path).split("\n")


static func _open(path: String) -> EventSheetResource:
	return GDScriptImporter.new().import_external(path)


## One statement as "object ▸ sentence", the way a row draws it.
static func _sentence_of(code: String, context: Dictionary) -> String:
	return _say(EventSheetSentence.statement(code, context))


## One condition as "object ▸ sentence".
static func _condition_of(code: String, context: Dictionary) -> String:
	return _say(EventSheetSentence.condition(code, context))


static func _say(reading: Dictionary) -> String:
	if reading.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in (reading.get("segments", []) as Array):
		parts.append(str((entry as Dictionary).get("text", "")))
	var object_label: String = str(reading.get("object", ""))
	var sentence: String = "".join(parts).strip_edges()
	return "%s ▸ %s" % [object_label, sentence] if not object_label.is_empty() else sentence


## The bar's buttons as one line, the way a reader reads them left to right.
static func _button_words(path: String) -> String:
	var words: PackedStringArray = PackedStringArray()
	for button: Dictionary in EventSheetEditorToolBar.buttons_for(_open(path), path):
		words.append(str(button["text"]))
	return " | ".join(words)


## Every row's reading in an opened file, as "object ▸ sentence" plus the bare span texts, so a head
## chip and a row sentence are both findable.
static func _open_and_read(path: String) -> PackedStringArray:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var view := EventSheetViewport.new()
	# Reading mode is where a verb reads as the trigger it is (`Test ▸ On run`) rather than as its
	# Define row - the same mode the whole reading campaign is about.
	view.reading_mode = true
	view.set_sheet(sheet)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(view._root_rows, view):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	view.free()
	return readings


static func _walk(rows: Array, view: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		view._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, view))
	return found


static func _has(readings: PackedStringArray, wanted: String) -> bool:
	for reading: String in readings:
		if reading == wanted:
			return true
	return false


static func _write(path: String, source: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(source)
		file.close()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tool files: %s" % label)
		return true
	print("[FAIL] tool files: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
