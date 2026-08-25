# Godot EventSheets - what a red run means, worked out before anybody reads it.
#
# A failing suite used to hand you three things and no help: a verdict line, however many `[FAIL]`
# lines are buried in eight shard logs, and the knowledge that a crashed test prints none of them at
# all. Everything after that was manual - find the log, find the assertion, guess which of the
# afternoon's edits could have caused it, remember the incantation that runs one test alone.
#
# This does that part. It reads the logs the runner already writes and prints, per failing test:
# the assertion that failed with its expected and its got, the files you changed that map to that
# test (the same mapping tools/pick_tests.gd uses, asked backwards), and the exact line to paste to
# run that one test again.
#
# And it reads the CRASH TRAIL. tests/run_tests.gd writes a start line before each test and a finish
# line after it, so a test that took the process down leaves a start with no finish. That test is
# named here, which is the one thing a log of a crashed run cannot tell you.
#
# USAGE (the binary is Godot 4.7; keep the path out of anything committed):
#   "$GODOT" --headless --path . --script tools/test_report.gd
# The parallel launcher runs it for you whenever a run is not green.
@tool
extends SceneTree

## Where the launcher keeps each process's output, and what one is called.
const LOG_DIR: String = "res://.godot/test_logs/"

## Where tests/run_tests.gd leaves its crash trail, one file per process.
const PROGRESS_DIR: String = "res://.godot/test_progress/"

## The shape of a failing assertion. Every test in this suite prints `[FAIL] <test>: <what>`, some
## of them through a nested reporter that indents the line first - which is why the anchor is the
## bracket rather than the start of the line.
const FAIL_PATTERN: String = "^\\s*\\[FAIL\\]\\s*(?<test>[A-Za-z0-9_]+)?:?\\s*(?<detail>.*)$"

## How many failing assertions to print per test. A test that fails forty times has one cause, and
## printing forty of them buries the report it is meant to be.
const MAX_DETAIL_LINES: int = 4

## How many blamed files to name. A whole-tree gate (the style sweep, the personal-path sweep) maps
## to every file of its kind, and a list of four hundred is not a lead.
const MAX_BLAMED_FILES: int = 8


func _init() -> void:
	var crashed: PackedStringArray = crashed_tests()
	var failures: Dictionary = failing_tests()
	print("")
	print("── the report ──────────────────────────────────────────────────────────────────")
	if crashed.is_empty() and failures.is_empty():
		print("Nothing failed and nothing crashed. (If the verdict was still red, the cause is")
		print("outside the tests - a shard that never started, or a log that was not written.)")
		quit(0)
		return
	var changed: PackedStringArray = _changed_files()
	for test_name: String in crashed:
		print("")
		print("CRASHED: %s" % test_name)
		print("  It started and never finished, so it printed no [FAIL] line and every test after")
		print("  it in that process never ran. Look for a hard error rather than an assertion.")
		_print_blame(test_name, changed)
		_print_rerun(test_name)
	for test_name: String in failures.keys():
		print("")
		print("FAILED: %s" % test_name)
		for detail: String in (failures[test_name] as PackedStringArray):
			print("  %s" % detail)
		_print_blame(test_name, changed)
		_print_rerun(test_name)
	print("")
	quit(0)


## Every test that started and never finished, across every process's trail. Empty on a clean run,
## and empty as well when the trail was never written (an older runner, or a run that died before
## its first test).
static func crashed_tests() -> PackedStringArray:
	var crashed: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(PROGRESS_DIR)
	if dir == null:
		return crashed
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".log"):
			continue
		var unfinished: String = unfinished_in(FileAccess.get_file_as_string(PROGRESS_DIR + file_name))
		if not unfinished.is_empty():
			crashed.append(unfinished)
	return crashed


## The test one trail started and never finished, or "". Pure, so the rule is testable: the trail is
## strictly alternating, so the answer is simply "the last line is a start".
static func unfinished_in(trail: String) -> String:
	var last_started: String = ""
	for line: String in trail.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("START "):
			last_started = text.trim_prefix("START ").trim_suffix(".gd")
		elif text.begins_with("DONE "):
			last_started = ""
	return last_started


## {test name: the failing assertions it printed}, read out of every log the launcher wrote.
static func failing_tests() -> Dictionary:
	var failures: Dictionary = {}
	var dir: DirAccess = DirAccess.open(LOG_DIR)
	if dir == null:
		return failures
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if not file_name.ends_with(".txt"):
			continue
		_collect_failures(FileAccess.get_file_as_string(LOG_DIR + file_name), failures)
	return failures


## The failing assertions in one log, added to `failures` under the test that printed each. A line
## whose test name cannot be read is filed under "(unnamed)" rather than dropped - an assertion
## nobody can attribute is still an assertion that failed.
static func _collect_failures(log_text: String, failures: Dictionary) -> void:
	var pattern: RegEx = RegEx.create_from_string(FAIL_PATTERN)
	if pattern == null:
		return
	for line: String in log_text.split("\n"):
		var found: RegExMatch = pattern.search(line)
		if found == null:
			continue
		var test_name: String = found.get_string("test")
		if test_name.is_empty():
			test_name = "(unnamed)"
		var detail: String = found.get_string("detail").strip_edges()
		var existing: PackedStringArray = failures.get(test_name, PackedStringArray())
		if existing.size() < MAX_DETAIL_LINES and not detail.is_empty():
			existing.append(detail)
		failures[test_name] = existing


## The changed files that map to this test, as tools/pick_tests.gd maps them - asked backwards. This
## is the "what did I touch that could have done this" step, and it is the one that takes longest by
## hand on a suite this size.
func _print_blame(test_name: String, changed: PackedStringArray) -> void:
	var blamed: PackedStringArray = _blamed_files(test_name, changed)
	if blamed.is_empty():
		print("  Nothing you changed maps to this test, so look at a shared gate or at the tree.")
		return
	print("  Changed files that map to it:")
	for index: int in mini(blamed.size(), MAX_BLAMED_FILES):
		print("    %s" % blamed[index])
	if blamed.size() > MAX_BLAMED_FILES:
		print("    ... and %d more (a whole-tree gate maps to every file of its kind)"
			% (blamed.size() - MAX_BLAMED_FILES))


## The line that runs this test and nothing else.
func _print_rerun(test_name: String) -> void:
	print("  Run it alone:")
	print("    $env:EVENTFORGE_TEST_ONLY = \"%s\"; & $env:GODOT --headless --path . --script tests/run_tests.gd; Remove-Item Env:\\EVENTFORGE_TEST_ONLY"
		% test_name)


func _changed_files() -> PackedStringArray:
	var picker: GDScript = load("res://tools/pick_tests.gd")
	return picker.call("changed_files") if picker != null else PackedStringArray()


func _blamed_files(test_name: String, changed: PackedStringArray) -> PackedStringArray:
	var picker: GDScript = load("res://tools/pick_tests.gd")
	if picker == null:
		return PackedStringArray()
	return picker.call("blamed_files", test_name, changed)
