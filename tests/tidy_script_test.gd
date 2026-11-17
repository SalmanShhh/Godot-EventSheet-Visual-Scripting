# Godot EventSheets - "Tidy this script" moves a file's older spellings to today's, on purpose only.
#
# An untouched open and save never changes a file. Tidy is the one door that does: it turns on, per row, the
# newer spelling the row already has as a choice (a float literal in a guard, a member's repeated icon and
# category lines) and moves the file's annotation words to one-hash comments above the description. Every line
# it would change is listed BEFORE anything changes, the result opens and saves back byte for byte and parses,
# a second Tidy finds nothing, and in the dock it lands as one undo step through the ordinary save.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "tidy_script_test"
const TIDY := preload("res://addons/eventsheet/editor/dock/tidy_script.gd")

const OLD_FORM := "extends Node\n\nvar __every_tick: float = 0.0\n\nfunc _process(delta: float) -> void:\n\t__every_tick += delta\n\tif __every_tick >= maxf(2.0, 0.001):\n\t\t__every_tick = fmod(__every_tick, maxf(2.0, 0.001))\n\t\tprint(\"tick\")\n"
const TIDIED := "extends Node\n\nvar __every_tick: float = 0.0\n\nfunc _process(delta: float) -> void:\n\t__every_tick += delta\n\tif __every_tick >= 2.0:\n\t\t__every_tick = fmod(__every_tick, maxf(2.0, 0.001))\n\t\tprint(\"tick\")\n"

const TWO_HASH := "## A tiny provider of greetings.\n## @ace_version(1.0.0)\n@tool\nclass_name TidyProbeAddon\nextends RefCounted\n\n## @ace_action\n## @ace_name(\"Say Hello\")\n## @ace_category(\"Greeting\")\n## @ace_description(\"Prints a hello.\")\nfunc say_hello(who: String) -> void:\n\tprint(who)\n\n\n## Says goodbye to someone.\n## @ace_action\n## @ace_name(\"Say Goodbye\")\n## @ace_category(\"Greeting\")\nfunc say_goodbye(who: String) -> void:\n\tprint(\"bye \", who)\n"
const ONE_HASH := "# @ace_version(1.0.0)\n## A tiny provider of greetings.\n@tool\nclass_name TidyProbeAddon\nextends RefCounted\n\n# @ace_action\n# @ace_name(\"Say Hello\")\n# @ace_category(\"Greeting\")\n# @ace_description(\"Prints a hello.\")\nfunc say_hello(who: String) -> void:\n\tprint(who)\n\n\n# @ace_action\n# @ace_name(\"Say Goodbye\")\n# @ace_category(\"Greeting\")\n## Says goodbye to someone.\nfunc say_goodbye(who: String) -> void:\n\tprint(\"bye \", who)\n"

const LEAN_SOURCE := "## Greets people.\n## @ace_category(\"Greeting\")\n## @ace_version(1.0.0)\n@tool\nclass_name TidyLeanAddon\nextends RefCounted\n\n## @ace_action\n## @ace_name(\"Say Hello\")\n## @ace_category(\"Greeting\")\nfunc say_hello(who: String) -> void:\n\tprint(who)\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_fold(ok)
	ok = _test_the_annotation_move(ok)
	ok = _test_a_repeated_category_line_is_left_out(ok)
	ok = _test_planning_changes_nothing(ok)
	ok = _test_apply_lands_what_was_planned(ok)
	ok = _test_a_result_that_does_not_read_back_is_left_out_and_counted(ok)
	ok = _test_nothing_to_tidy(ok)
	ok = _test_one_hash_files_and_untouched_saves_do_not_move(ok)
	ok = _test_the_lines_that_differ(ok)
	return ok


static func _reopened(text: String, path: String) -> EventSheetResource:
	var sheet: EventSheetResource = SUPPORT.reopen(text, true, path)
	sheet.external_source_path = path
	return sheet


static func _lines(made: Dictionary) -> Array:
	return Array(TIDY.preview_lines(made))


static func _test_the_fold(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("tidy_fold.gd")
	var sheet: EventSheetResource = _reopened(OLD_FORM, path)
	var made: Dictionary = TIDY.plan(sheet)
	ok = SUPPORT.check(P, "the plan lists the one guard it changes, before and after",
		_lines(made), ["if __every_tick >= maxf(2.0, 0.001): => if __every_tick >= 2.0:"]) and ok
	ok = SUPPORT.check(P, "the plan carries the whole text it would write", str(made["after"]), TIDIED) and ok
	ok = SUPPORT.check(P, "nothing was left out", int(made["left"]), 0) and ok
	ok = SUPPORT.check(P, "the file's own spelling does not move when it has none to move", str(made["spelling"]), "") and ok
	ok = SUPPORT.check(P, "Tidy turns one row", int(TIDY.apply(sheet, made)), 1) and ok
	var tidied: String = SUPPORT.compile_output(sheet, path)
	ok = SUPPORT.check(P, "the tidied file", tidied, TIDIED) and ok
	ok = SUPPORT.check(P, "the tidied file opens and saves back byte for byte", SUPPORT.reemit(tidied, path) == tidied, true) and ok
	ok = SUPPORT.check(P, "a second Tidy has nothing to do",
		(TIDY.plan(_reopened(tidied, path))["changes"] as Array).size(), 0) and ok
	ok = SUPPORT.check(P, "and neither has the sheet that was just tidied",
		(TIDY.plan(sheet)["changes"] as Array).size(), 0) and ok
	# A guard around a name is never offered: the fold is for plain numbers.
	var named: String = OLD_FORM.replace("maxf(2.0, 0.001)", "maxf(wave_gap, 0.001)").replace("var __every_tick", "var wave_gap: float = 2.0\nvar __every_tick")
	ok = SUPPORT.check(P, "a guard around a name is not offered",
		(TIDY.plan(_reopened(named, path))["changes"] as Array).size(), 0) and ok
	return ok


static func _test_the_annotation_move(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("tidy_words.gd")
	var sheet: EventSheetResource = _reopened(TWO_HASH, path)
	ok = SUPPORT.check(P, "the file starts as a two-hash file", sheet.annotation_spelling, "##") and ok
	var made: Dictionary = TIDY.plan(sheet)
	ok = SUPPORT.check(P, "every annotation line is listed as it is and as it will be", _lines(made), [
		"## @ace_version(1.0.0) => # @ace_version(1.0.0)",
		"## @ace_action => # @ace_action",
		"## @ace_name(\"Say Hello\") => # @ace_name(\"Say Hello\")",
		"## @ace_category(\"Greeting\") => # @ace_category(\"Greeting\")",
		"## @ace_description(\"Prints a hello.\") => # @ace_description(\"Prints a hello.\")",
		"## @ace_action => # @ace_action",
		"## @ace_name(\"Say Goodbye\") => # @ace_name(\"Say Goodbye\")",
		"## @ace_category(\"Greeting\") => # @ace_category(\"Greeting\")",
	]) and ok
	ok = SUPPORT.check(P, "the words sit above the description, which stays next to what it describes", str(made["after"]), ONE_HASH) and ok
	ok = SUPPORT.check(P, "the move is the file's spelling", str(made["spelling"]), "#") and ok
	TIDY.apply(sheet, made)
	ok = SUPPORT.check(P, "the sheet writes the planned text after it", SUPPORT.compile_output(sheet, path), ONE_HASH) and ok
	ok = SUPPORT.check(P, "the moved file opens and saves back byte for byte", SUPPORT.reemit(ONE_HASH, path) == ONE_HASH, true) and ok
	var reopened: EventSheetResource = _reopened(ONE_HASH, path)
	ok = SUPPORT.check(P, "and reopens as the same two function rows", reopened.functions.size(), 2) and ok
	ok = SUPPORT.check(P, "keeping the one-hash spelling", reopened.annotation_spelling, "#") and ok
	ok = SUPPORT.check(P, "a second Tidy has nothing to do", (TIDY.plan(reopened)["changes"] as Array).size(), 0) and ok
	var probe: GDScript = GDScript.new()
	probe.source_code = RegEx.create_from_string("(?m)^class_name\\s.*$").sub(ONE_HASH, "", true)
	ok = SUPPORT.check(P, "the moved file parses", probe.reload(true), OK) and ok
	return ok


static func _test_a_repeated_category_line_is_left_out(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("tidy_lean.gd")
	var made: Dictionary = TIDY.plan(_reopened(LEAN_SOURCE, path))
	var lines: Array = _lines(made)
	ok = SUPPORT.check(P, "a member's category line that repeats the class's own is listed as removed",
		lines.has("## @ace_category(\"Greeting\") => (line removed)"), true) and ok
	ok = SUPPORT.check(P, "and the member keeps its own name and action words",
		str(made["after"]).contains("# @ace_action\n# @ace_name(\"Say Hello\")\nfunc say_hello"), true) and ok
	ok = SUPPORT.check(P, "one row's choice and the file's spelling were turned", (made["turned"] as Array).size(), 1) and ok
	ok = SUPPORT.check(P, "the shorter file opens and saves back byte for byte", SUPPORT.reemit(str(made["after"]), path) == str(made["after"]), true) and ok
	return ok


static func _test_planning_changes_nothing(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("tidy_plan_only.gd")
	var sheet: EventSheetResource = _reopened(TWO_HASH, path)
	var before: String = SUPPORT.compile_output(sheet, path)
	TIDY.plan(sheet)
	ok = SUPPORT.check(P, "planning writes the same text afterwards", SUPPORT.compile_output(sheet, path), before) and ok
	ok = SUPPORT.check(P, "and leaves the file's spelling alone", sheet.annotation_spelling, "##") and ok
	ok = SUPPORT.check(P, "and its words where they were", sheet.annotation_words_first, false) and ok
	var old_form: EventSheetResource = _reopened(OLD_FORM, path)
	TIDY.plan(old_form)
	ok = SUPPORT.check(P, "and the rows' choices where they were", SUPPORT.compile_output(old_form, path), OLD_FORM) and ok
	return ok


static func _test_apply_lands_what_was_planned(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("tidy_apply.gd")
	var sheet: EventSheetResource = _reopened(OLD_FORM, path)
	var made: Dictionary = TIDY.plan(sheet)
	# The sheet moves under the plan: the guard's number is edited by hand.
	var edited: String = OLD_FORM.replace("maxf(2.0, 0.001)", "maxf(3.0, 0.001)")
	var moved: EventSheetResource = _reopened(edited, path)
	ok = SUPPORT.check(P, "a plan made on another sheet's text is not applied", int(TIDY.apply(moved, made)), 0) and ok
	ok = SUPPORT.check(P, "and the sheet it was handed is exactly as it was", SUPPORT.compile_output(moved, path), edited) and ok
	ok = SUPPORT.check(P, "an empty plan applies nothing", int(TIDY.apply(sheet, {"changes": []})), 0) and ok
	return ok


static func _test_a_result_that_does_not_read_back_is_left_out_and_counted(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("tidy_left.gd")
	var refuse_all: Callable = func(_text: String) -> bool: return false
	var made: Dictionary = TIDY.plan(_reopened(TWO_HASH, path), refuse_all)
	ok = SUPPORT.check(P, "a move that cannot be read back changes nothing", (made["changes"] as Array).size(), 0) and ok
	ok = SUPPORT.check(P, "and says how many lines it left as they are", int(made["left"]), 8) and ok
	ok = SUPPORT.check(P, "the text it would write is the text it was given", str(made["after"]), TWO_HASH) and ok
	# One of two results is refused: the guard is kept when only the words fail.
	var mixed_source: String = "## @ace_version(1.0.0)
" + OLD_FORM
	var refuse_words: Callable = func(text: String) -> bool: return not text.begins_with("# @ace_version")
	var mixed: Dictionary = TIDY.plan(_reopened(mixed_source, path), refuse_words)
	ok = SUPPORT.check(P, "when the words cannot move a plain guard still can", _lines(mixed),
		["if __every_tick >= maxf(2.0, 0.001): => if __every_tick >= 2.0:"]) and ok
	ok = SUPPORT.check(P, "and the one line that was left is counted", int(mixed["left"]), 1) and ok
	ok = SUPPORT.check(P, "the words stay where they were", str(mixed["spelling"]), "") and ok
	return ok


static func _test_nothing_to_tidy(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("tidy_none.gd")
	var made: Dictionary = TIDY.plan(_reopened(TIDIED, path))
	ok = SUPPORT.check(P, "a script written in today's spelling has nothing to tidy", (made["changes"] as Array).size(), 0) and ok
	ok = SUPPORT.check(P, "and says it is sure", bool(made["unsure"]), false) and ok
	ok = SUPPORT.check(P, "no plan for no sheet", (TIDY.plan(null)["changes"] as Array).size(), 0) and ok
	return ok


static func _test_one_hash_files_and_untouched_saves_do_not_move(ok: bool) -> bool:
	var path: String = SUPPORT.own_path("tidy_stays.gd")
	for source: String in [TWO_HASH, ONE_HASH, OLD_FORM, LEAN_SOURCE]:
		ok = SUPPORT.check(P, "an untouched open and save writes the file's own bytes (%d chars)" % source.length(),
			SUPPORT.reemit(source, path), source) and ok
	ok = SUPPORT.check(P, "a one-hash file has no spelling to move",
		(TIDY.plan(_reopened(ONE_HASH, path))["changes"] as Array).size(), 0) and ok
	return ok


static func _test_the_lines_that_differ(ok: bool) -> bool:
	var changes: Array = TIDY.changed_lines("a\nb\nc\nd\n", "a\nB\nc\nd\ne\n")
	ok = SUPPORT.check(P, "a changed line and an added line", changes.map(func(entry: Dictionary) -> String:
		return "%d:%s=>%s" % [entry["line"], entry["before"], entry["after"]]), ["2:b=>B", "5:=>e"]) and ok
	changes = TIDY.changed_lines("x\ny\nz", "x\nz")
	ok = SUPPORT.check(P, "a removed line", changes.map(func(entry: Dictionary) -> String:
		return "%d:%s=>%s" % [entry["line"], entry["before"], entry["after"]]), ["2:y=>"]) and ok
	ok = SUPPORT.check(P, "the same text has no differing line", TIDY.changed_lines("same\ntext", "same\ntext").size(), 0) and ok
	# A change far from another stays two entries, in file order.
	var long_before: PackedStringArray = PackedStringArray()
	var long_after: PackedStringArray = PackedStringArray()
	for index: int in range(400):
		long_before.append("line %d" % index)
		long_after.append("line %d" % index)
	long_after[10] = "changed 10"
	long_after[390] = "changed 390"
	ok = SUPPORT.check(P, "two far-apart changes in a long file", TIDY.changed_lines("\n".join(long_before), "\n".join(long_after)).map(
		func(entry: Dictionary) -> String: return "%d:%s" % [entry["line"], entry["after"]]), ["11:changed 10", "391:changed 390"]) and ok
	return ok

