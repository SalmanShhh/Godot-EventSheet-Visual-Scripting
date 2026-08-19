@tool
class_name EventSheetToolFiles
extends RefCounted

# W9 / W10 / W11. The three kinds of file a project's TOOLING is written in, read as the sheets they
# already are: a test, a command-line tool, and a behavior pack's recipe.
#
# Every one of them is a whole-FILE shape rather than a statement: a `quit(1)` means "finish with
# code 1" only in a file the engine runs as its whole main loop, and `passed = _check(...) and
# passed` means "check this" only in a file whose entry point is `static func run() -> bool`. So the
# file is classified once, the answer travels as ordinary sentence context, and every reading below
# refuses to fire without it. A game script that happens to call `quit()` is untouched.
#
# Everything here is DISPLAY ONLY and every function is static and pure: no reading decides what is
# emitted, the rows' resources are never touched, and a test pins a sentence by value with no
# viewport at all. The byte round-trip cannot move because nothing here writes anything.

## The three file kinds, which are also the pattern ids claimed for them. Frozen once shipped.
const KIND_TEST_SHEET := "test_sheet"
const KIND_COMMAND_TOOL := "command_tool"
const KIND_PACK_RECIPE := "pack_recipe"

## The objects these readings file their sentences under. "Test" and "Command tool" are the two new
## ones; a folder and a file are the words the storage readings already use.
const OBJECT_TEST := "Test"
const OBJECT_COMMAND_TOOL := "Command tool"
const OBJECT_FOLDER := "Folder"
const OBJECT_FILE := "File"

## The entry point each kind is recognised by, and the harness helper a test carries.
const TEST_ENTRY := "static func run() -> bool:"
const TEST_ENTRY_NAME := "run"
const COMMAND_ENTRY_NAME := "_init"
const RECIPE_ENTRY := "static func build() -> bool:"
const RECIPE_ENTRY_NAME := "build"
const CHECK_HELPER := "_check"

## The folder a test sheet lives under, and the folder a pack recipe lives under. Both are the plain
## project conventions rather than anything this plugin invented, which is why a game project's own
## `tests/` folder reads exactly like this repo's.
const TESTS_FOLDER := "tests"
const RECIPES_FOLDER := "pack_builders"

## The sheet-level properties a pack recipe states about the behavior it builds. These are HEAD facts
## on the Include bar rather than rows: they are what the pack IS, not something it does. Keyed by the
## property the recipe writes, valued by the word the bar says it with.
const RECIPE_HEAD_PROPERTIES: Dictionary = {
	"host_class": "host",
	"custom_class_name": "class",
	"addon_category": "category",
	"class_description": "about",
	"addon_tags": "tags",
	"behavior_mode": "behavior",
}

## The head facts a recipe states but does NOT wear as a chip: what it IS (a behavior), what it says
## about itself in prose, and the tags it files itself under. All three belong on the bar's dropdown
## rather than in a line a reader scans left to right.
const HEAD_CHIP_SKIPPED: PackedStringArray = ["behavior", "about", "tags"]

## How a command tool asks for the words typed after `--` on the command line.
const ARGUMENTS_CALL := "OS.get_cmdline_user_args()"

## Reading a file whole, and reading it past the cache. Both are single calls a tool writes constantly
## and neither had a reading before.
const FILE_TEXT_CALL := "FileAccess.get_file_as_string("
const RESOURCE_LOAD_CALL := "ResourceLoader.load("
const CACHE_IGNORE := "CACHE_MODE_IGNORE"

## Making a folder, and writing a file in one line. The two-line `open` + `store_string` spelling keeps
## the File readings it already had - two statements are two rows, which is the sheet's own rule.
const MAKE_DIR_CALL := "DirAccess.make_dir_recursive_absolute("
const WRITE_TEXT_HEAD := "FileAccess.open("

## How a pack recipe opens the string list its whole behavior is written in, and how it closes it.
const JOINED_BODY_HEAD := "\"\\n\".join(PackedStringArray(["
const JOINED_BODY_TAIL := "]))"


## Everything the grammar needs to know about the FILE, as ordinary sentence context. {} for a file
## that is none of the three kinds, which is every game script - so the readings below cost a lookup
## and nothing else.
##
##   tool_file_kind      "test_sheet" | "command_tool" | "pack_recipe"
##   test_accumulators   the names a test folds its verdict through ("passed", "all_passed", ...)
##   test_checks         [{label, actual, expected}] in file order
##   test_fixture        the res:// path this test opens as its fixture, "" when it has none
##   command_walk_locals {local name: true} for a local filled by a folder walk's get_next()
static func facts(lines: PackedStringArray, script_path: String = "") -> Dictionary:
	var kind: String = kind_of(lines, script_path)
	if kind.is_empty():
		return {}
	var extras: Dictionary = {"tool_file_kind": kind}
	match kind:
		KIND_TEST_SHEET:
			extras["test_accumulators"] = accumulator_names(lines)
			extras["test_checks"] = checks(lines)
			extras["test_fixture"] = fixture_path(lines)
		KIND_COMMAND_TOOL:
			extras["command_walk_locals"] = folder_walk_locals(lines)
		KIND_PACK_RECIPE:
			extras.merge(recipe_facts(lines), true)
	return extras


## The lines a tooling file's facts are read from. An OPENED file is read off disk rather than out of
## the sheet: the importer lifts `extends SceneTree`, `static func run() -> bool` and the `@export`
## settings out of the raw rows and into structure, so the sheet's own code rows no longer hold the
## very lines that say what kind of file this is. The file on disk always does.
static func lines_of_sheet(sheet: EventSheetResource) -> PackedStringArray:
	if sheet == null:
		return PackedStringArray()
	var path: String = sheet.external_source_path
	if not path.strip_edges().is_empty() and FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path).split("
")
	return EventSheetViewportReadingRows.ordered_code_lines(sheet)


## Which of the three shapes this file is, or "" for anything else. A recipe is checked first: it is a
## file full of `static func build()` that a command tool would never be mistaken for, but it does
## live under tools/ beside them.
static func kind_of(lines: PackedStringArray, script_path: String = "") -> String:
	if is_pack_recipe(lines, script_path):
		return KIND_PACK_RECIPE
	if is_command_tool(lines):
		return KIND_COMMAND_TOOL
	if is_test_sheet(lines, script_path):
		return KIND_TEST_SHEET
	return ""


## A test sheet: a `.gd` under a `tests/` folder whose entry point is `static func run() -> bool`.
## Both halves are required. The folder alone would claim a fixture, and the signature alone would
## claim any helper that happens to answer yes or no.
static func is_test_sheet(lines: PackedStringArray, script_path: String) -> bool:
	if not _in_folder(script_path, TESTS_FOLDER):
		return false
	for line: String in lines:
		if line.strip_edges() == TEST_ENTRY:
			return true
	return false


## A command tool: a script the engine runs as its whole main loop, which is what `extends SceneTree`
## (or the bare `MainLoop` it derives from) plus an `_init` means. No path test - a command tool is a
## command tool wherever it is saved.
static func is_command_tool(lines: PackedStringArray) -> bool:
	var main_loop: bool = false
	var has_init: bool = false
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if line == "extends SceneTree" or line == "extends MainLoop":
			main_loop = true
		elif line.begins_with("func %s(" % COMMAND_ENTRY_NAME):
			has_init = true
	return main_loop and has_init


## A pack recipe: a `static func build()` under a `pack_builders` folder that fills an
## EventSheetResource and saves it as a pack. All three are required - the folder says what the file
## is for, the entry point says it is a recipe, and `save_pack` says it actually builds one.
static func is_pack_recipe(lines: PackedStringArray, script_path: String) -> bool:
	if not _in_folder(script_path, RECIPES_FOLDER):
		return false
	var has_build: bool = false
	var saves: bool = false
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if line == RECIPE_ENTRY:
			has_build = true
		elif line.contains("save_pack("):
			saves = true
	return has_build and saves


## True when `script_path` has `folder` as one of its path components. A file called `tests.gd` is not
## in a tests folder, and a path this editor never saw ("") is in no folder at all.
static func _in_folder(script_path: String, folder: String) -> bool:
	if script_path.strip_edges().is_empty():
		return false
	return script_path.get_base_dir().split("/").has(folder)


# ── W9. Test sheets ───────────────────────────────────────────────────────────────────────────────


## The names a test folds its verdict through: every local declared `true` and later written as
## `<name> = ... and <name>`. Derived rather than hard-coded, because half the suite calls it `passed`
## and half calls it `all_passed`, and a project's own tests will call it something else again.
static func accumulator_names(lines: PackedStringArray) -> PackedStringArray:
	var declared: Dictionary = {}
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		var name: String = _declared_true_name(line)
		if not name.is_empty():
			declared[name] = true
	var names: PackedStringArray = PackedStringArray()
	for name: String in declared.keys():
		names.append(name)
	names.sort()
	return names


## The local a line declares as `true`, or "" when the line declares nothing of the kind. Both the
## inferred and the annotated spellings count.
static func _declared_true_name(line: String) -> String:
	if not line.begins_with("var "):
		return ""
	var body: String = line.substr(4).strip_edges()
	for opener: String in [" := true", ": bool = true"]:
		var at: int = body.find(opener)
		if at > 0 and body.substr(at + opener.length()).strip_edges().is_empty():
			return body.substr(0, at).strip_edges()
	return ""


## Every check this file makes, in file order, as {label, actual, expected}. The one idiom the whole
## suite is written in, and the one a reader has to be able to see: a row per claim, with the two
## values it compares.
static func checks(lines: PackedStringArray) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var accumulators: PackedStringArray = accumulator_names(lines)
	var pending: String = ""
	for raw_line: String in lines:
		pending = (pending + "\n" + raw_line) if not pending.is_empty() else raw_line
		if not _parentheses_balanced(pending):
			continue
		var parsed: Dictionary = check_call(pending, accumulators)
		pending = ""
		if not parsed.is_empty():
			found.append(parsed)
	return found


## One `passed = _check(label, actual, expected) and passed` line, split into the three things it
## says. {} for anything else - including a `passed = _other_test() and passed`, which is a call and
## reads as one.
static func check_call(code: String, accumulators: PackedStringArray) -> Dictionary:
	var text: String = _join_lines(code)
	var assign_at: int = EventSheetSentence.top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	var accumulator: String = text.substr(0, assign_at).strip_edges()
	if not accumulators.has(accumulator):
		return {}
	var right: String = text.substr(assign_at + 3).strip_edges()
	var tail: String = " and %s" % accumulator
	if not right.ends_with(tail):
		return {}
	var call: String = right.substr(0, right.length() - tail.length()).strip_edges()
	if not call.begins_with("%s(" % CHECK_HELPER) or not call.ends_with(")"):
		return {}
	var inside: String = call.substr(CHECK_HELPER.length() + 1, call.length() - CHECK_HELPER.length() - 2)
	var arguments: PackedStringArray = EventSheetSentence.split_top_level(inside, ",")
	if arguments.size() != 3:
		return {}
	return {
		"accumulator": accumulator,
		"label": arguments[0].strip_edges(),
		"actual": arguments[1].strip_edges(),
		"expected": arguments[2].strip_edges(),
	}


## The fixture a test opens: the first `res://` path it names that is not the test's own file. A test
## with no fixture returns "" and the bar simply says nothing extra.
static func fixture_path(lines: PackedStringArray) -> String:
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if line.begins_with("#"):
			continue
		var at: int = line.find("\"res://")
		if at < 0:
			continue
		var rest: String = line.substr(at + 1)
		var close_at: int = rest.find("\"")
		if close_at <= 0:
			continue
		var path: String = rest.substr(0, close_at)
		if path.get_extension() in ["gd", "tres", "tscn", "json", "csv", "txt"]:
			return path
	return ""


## The Check row: `Test ▸ Check "the label": actual = expected`. {} unless the file is a test sheet,
## so the same line in a game script keeps reading as the assignment it is.
static func check_statement(code: String, context: Dictionary) -> Dictionary:
	if str(context.get("tool_file_kind", "")) != KIND_TEST_SHEET:
		return {}
	var accumulators: PackedStringArray = context.get("test_accumulators", PackedStringArray())
	var parsed: Dictionary = check_call(code, accumulators)
	if parsed.is_empty():
		return {}
	var reading: Dictionary = EventSheetSentence.sentence_of(OBJECT_TEST, "Check {label}: {actual} = {expected}", {
		"label": [str(parsed["label"]), "value"],
		"actual": [EventSheetSentence.expression_text(str(parsed["actual"]), context), "name"],
		"expected": [EventSheetSentence.expression_text(str(parsed["expected"]), context), "value"],
	})
	# The label travels with the reading so the row can be coloured by the last run's verdict without
	# parsing the line a second time. Display only, like everything else here.
	reading["check_label"] = bare_label(str(parsed["label"]))
	return reading


## A check's label with its quotes taken off - the form a `[PASS] …: <label>` line prints it in.
static func bare_label(label: String) -> String:
	var text: String = label.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text


## The head facts an opened tooling file states on its Include bar, in bar order. Each is one chip.
## Static and value-driven so a test pins the exact words with no viewport at all.
static func head_chips(kind: String, check_count: int, head: Dictionary = {}) -> PackedStringArray:
	var chips: PackedStringArray = PackedStringArray()
	match kind:
		KIND_TEST_SHEET:
			chips.append(EventSheetSentence.translate("test sheet"))
			chips.append("%d %s" % [check_count,
				EventSheetSentence.translate("check") if check_count == 1 else EventSheetSentence.translate("checks")])
		KIND_COMMAND_TOOL:
			chips.append(EventSheetSentence.translate("command tool"))
			chips.append(EventSheetSentence.translate("runs headless"))
		KIND_PACK_RECIPE:
			chips.append(EventSheetSentence.translate("pack recipe"))
			for word: String in head.keys():
				if word in HEAD_CHIP_SKIPPED:
					continue
				chips.append("%s %s" % [EventSheetSentence.translate(word), str(head[word])])
	return chips


# ── W10. Command tools ────────────────────────────────────────────────────────────────────────────


## The locals a folder walk fills: `var entry: String = dir.get_next()`. The `while not entry.is_empty()`
## a line below is the loop's real header, and it can only be read as "for each file in folder" once
## this line has said what `entry` holds.
static func folder_walk_locals(lines: PackedStringArray) -> Dictionary:
	var locals: Dictionary = {}
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if not line.contains(".get_next()"):
			continue
		var assign_at: int = EventSheetSentence.top_level_index(line, " = ")
		if assign_at <= 0:
			continue
		var target: String = line.substr(0, assign_at).strip_edges()
		if target.begins_with("var "):
			target = target.substr(4).strip_edges()
		var colon_at: int = target.find(":")
		if colon_at > 0:
			target = target.substr(0, colon_at).strip_edges()
		if not target.is_empty():
			locals[target] = true
	return locals


## The statements only a command tool writes: finishing with an exit code, making a folder, and
## writing a file in one line. {} for every other file, which is what keeps `quit()` in a game script
## reading as "Quit game".
static func command_statement(code: String, context: Dictionary) -> Dictionary:
	if str(context.get("tool_file_kind", "")) != KIND_COMMAND_TOOL:
		return {}
	var text: String = _join_lines(code).strip_edges()
	if text == "quit()":
		return EventSheetSentence.sentence_of(OBJECT_COMMAND_TOOL, "Finish", {})
	if text.begins_with("quit(") and text.ends_with(")"):
		var code_text: String = text.substr(5, text.length() - 6).strip_edges()
		if code_text.is_empty():
			return EventSheetSentence.sentence_of(OBJECT_COMMAND_TOOL, "Finish", {})
		return EventSheetSentence.sentence_of(OBJECT_COMMAND_TOOL, "Finish with code {code}", {
			"code": [EventSheetSentence.expression_text(code_text, context), "value"]
		})
	if text.begins_with(MAKE_DIR_CALL) and text.ends_with(")"):
		var folder: String = text.substr(MAKE_DIR_CALL.length(), text.length() - MAKE_DIR_CALL.length() - 1)
		return EventSheetSentence.sentence_of(OBJECT_FOLDER, "Create {path}", {
			"path": [EventSheetSentence.expression_text(folder.strip_edges(), context), "value"]
		})
	var written: Dictionary = _write_text_statement(text, context)
	if not written.is_empty():
		return written
	return {}


## `FileAccess.open(p, FileAccess.WRITE).store_string(text)` - opening and writing in one line, which
## is one step and reads as one row. The two-statement spelling keeps the two rows it already had.
static func _write_text_statement(text: String, context: Dictionary) -> Dictionary:
	if not text.begins_with(WRITE_TEXT_HEAD) or not text.contains(").store_string("):
		return {}
	var split_at: int = text.find(").store_string(")
	var opened: String = text.substr(WRITE_TEXT_HEAD.length(), split_at - WRITE_TEXT_HEAD.length())
	var arguments: PackedStringArray = EventSheetSentence.split_top_level(opened, ",")
	if arguments.size() != 2 or not arguments[1].contains("WRITE"):
		return {}
	return EventSheetSentence.sentence_of(OBJECT_FILE, "Write text to {path}", {
		"path": [EventSheetSentence.expression_text(arguments[0].strip_edges(), context), "value"]
	})


## A folder walk's loop header: `while not entry.is_empty()`, where `entry` is a local this file fills
## from `get_next()`. Reads as the one thing the four lines together mean.
static func command_condition(expression: String, context: Dictionary) -> Dictionary:
	if str(context.get("tool_file_kind", "")) != KIND_COMMAND_TOOL:
		return {}
	var text: String = expression.strip_edges()
	if not text.begins_with("not ") or not text.ends_with(".is_empty()"):
		return {}
	var name: String = text.substr(4, text.length() - 4 - 11).strip_edges()
	var walk_locals: Dictionary = context.get("command_walk_locals", {})
	if not walk_locals.has(name):
		return {}
	return EventSheetSentence.sentence_of(OBJECT_COMMAND_TOOL, "For each file in folder", {})


## The values only a command tool reads: the words after `--` on the command line, a resource loaded
## past the cache, and a file read whole. "" when the text is none of them, and the caller keeps
## whatever it already had.
static func command_expression(text: String, context: Dictionary) -> String:
	if str(context.get("tool_file_kind", "")) != KIND_COMMAND_TOOL:
		return ""
	var value: String = text.strip_edges()
	if value == ARGUMENTS_CALL:
		return "%s.%s" % [EventSheetSentence.translate(OBJECT_COMMAND_TOOL), EventSheetSentence.translate("Arguments")]
	if value.begins_with(FILE_TEXT_CALL) and value.ends_with(")"):
		return EventSheetSentence.translate("the file's text")
	if value.begins_with(RESOURCE_LOAD_CALL) and value.ends_with(")") and value.contains(CACHE_IGNORE):
		var inside: String = value.substr(RESOURCE_LOAD_CALL.length(), value.length() - RESOURCE_LOAD_CALL.length() - 1)
		var arguments: PackedStringArray = EventSheetSentence.split_top_level(inside, ",")
		if arguments.is_empty():
			return ""
		return EventSheetSentence.translate("load {path} ignoring the cache").format({
			"path": EventSheetSentence.expression_text(arguments[0].strip_edges(), context)
		})
	return ""


# ── W11. Pack recipes ─────────────────────────────────────────────────────────────────────────────


## What a recipe says about the behavior it builds, and the GDScript it builds it out of:
##
##   recipe_head   {"host": "Node2D", "class": "PinBehavior", ...} in RECIPE_HEAD_PROPERTIES order
##   recipe_pack   the folder the pack is saved as ("pin")
##   recipe_code   the joined string-list body, as the lines of the .gd it becomes
static func recipe_facts(lines: PackedStringArray) -> Dictionary:
	return {
		"recipe_head": recipe_head(lines),
		"recipe_pack": recipe_pack_id(lines),
		"recipe_code": recipe_code_lines(lines),
	}


## The head facts, in the order the bar says them. A property the recipe never writes is simply
## absent - the bar states what the recipe states and never guesses a default.
static func recipe_head(lines: PackedStringArray) -> Dictionary:
	var stated: Dictionary = {}
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		for property: String in RECIPE_HEAD_PROPERTIES.keys():
			var head: String = "sheet.%s = " % property
			if not line.begins_with(head):
				continue
			var value: String = line.substr(head.length()).strip_edges()
			stated[str(RECIPE_HEAD_PROPERTIES[property])] = _plain_value(value)
	var ordered: Dictionary = {}
	for property: String in RECIPE_HEAD_PROPERTIES.keys():
		var word: String = str(RECIPE_HEAD_PROPERTIES[property])
		if stated.has(word):
			ordered[word] = stated[word]
	return ordered


## Where a recipe saves its pack: the base path `save_pack` is given, without the `.gd` the pack is
## emitted as ("res://eventsheet_addons/pin/pin_behavior").
static func recipe_pack_id(lines: PackedStringArray) -> String:
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		var at: int = line.find("save_pack(")
		if at < 0:
			continue
		var inside: String = line.substr(at + 10)
		if inside.ends_with(")"):
			inside = inside.substr(0, inside.length() - 1)
		var arguments: PackedStringArray = EventSheetSentence.split_top_level(inside, ",")
		if arguments.size() >= 2:
			return _plain_value(arguments[1].strip_edges())
	return ""


## The GDScript a recipe joins out of a string list, as the lines of the file it will become. This is
## the whole behavior - the `@export` settings and the annotated verbs - which a reader cannot see at
## all while it is a folded string literal. Escapes are undone exactly as `"\n".join` would leave
## them, so what comes back out is what the built pack has in it.
static func recipe_code_lines(lines: PackedStringArray) -> PackedStringArray:
	var body: PackedStringArray = PackedStringArray()
	var inside: bool = false
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if not inside:
			if line.contains(JOINED_BODY_HEAD):
				inside = true
			continue
		if line.begins_with(JOINED_BODY_TAIL):
			inside = false
			continue
		var entry: String = line
		if entry.ends_with(","):
			entry = entry.substr(0, entry.length() - 1)
		entry = entry.strip_edges()
		if not entry.begins_with("\"") or not entry.ends_with("\""):
			continue
		body.append(_unescape(entry.substr(1, entry.length() - 2)))
	return body


## A GDScript string literal as the plain text it holds; anything that is not a literal comes back
## unchanged, so a recipe that computes a value shows the expression it wrote.
static func _plain_value(text: String) -> String:
	var value: String = text.strip_edges()
	if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
		return _unescape(value.substr(1, value.length() - 2))
	return value


## The escapes a joined string list is written with, undone. Backslash last would eat the others'
## backslashes, so it is handled in the one pass rather than by three replaces.
static func _unescape(text: String) -> String:
	var out: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\\" and index + 1 < text.length():
			var next: String = text[index + 1]
			match next:
				"n":
					out += "\n"
				"t":
					out += "\t"
				"\"":
					out += "\""
				"\\":
					out += "\\"
				_:
					out += character + next
			index += 2
			continue
		out += character
		index += 1
	return out


# ── Shared ────────────────────────────────────────────────────────────────────────────────────────


## A statement spread over several physical lines, as the one statement it is.
static func _join_lines(code: String) -> String:
	var joined: String = ""
	for line: String in code.split("\n"):
		joined = line.strip_edges() if joined.is_empty() else "%s %s" % [joined, line.strip_edges()]
	return joined.strip_edges()


## True when every bracket a run of lines opened has been closed - which is how a wrapped call is
## told from a finished one without parsing GDScript.
static func _parentheses_balanced(text: String) -> bool:
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if in_string:
			if character == "\\":
				index += 2
				continue
			if character == quote:
				in_string = false
		elif character == "\"" or character == "'":
			in_string = true
			quote = character
		elif character == "(" or character == "[":
			depth += 1
		elif character == ")" or character == "]":
			depth -= 1
		index += 1
	return depth <= 0
