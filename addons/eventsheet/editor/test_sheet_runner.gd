# Godot EventSheets - the Test sheet runner (finding tests, running one, and wording the report).
#
# Every part of running a Test sheet that is not "how did you ask for it": discovery, running a
# single compiled test inside a SceneTree, the totals, and the exact text of the report. The
# headless command (tools/run_test_sheets.gd) and the editor's Tools > Run Tests… panel are both
# thin shells over this file, so a run from the terminal and a run from the editor produce the same
# words in the same order.
#
# HOW A TEST IS FOUND: a Test sheet compiles to plain GDScript carrying the marker comment
# `## @ace_test_sheet` on a line of its own, so discovery is a text scan - no registry to keep in
# sync, no project setting, and a file copied into another project stays a test.
#
# HOW A TEST IS RUN: the script is instantiated as a Node and added to the tree (so its generated
# _ready runs and the On Test Start event connects), then `test_started` is emitted with the file's
# name. The test's rows record their claims onto the node's own metadata, and when it finishes - or
# falls quiet, or runs out of time - the report is read back off the node.
#
# WHY THE VERDICT IS STATED EXPLICITLY: a runner that crashes must not look like a run with no
# failures. Every report ends in "All tests passed." or "Some tests failed.", and a test that
# recorded nothing at all counts as a FAILURE, never as a clean run.
#
# Loaded by path (it carries no class_name on purpose): the headless command runs outside the editor
# where the plugin's class cache may not be built, and the menu keeps the editor's boot path free of
# anything it does not need until you ask for it.
@tool
extends RefCounted

## The header marker the compiler emits for a Test sheet.
const MARKER := "## @ace_test_sheet"
## Metadata keys the Testing vocabulary records under (kept in step with testing_aces.gd).
const REPORT_META := "__ef_test_report"
const FINISHED_META := "__ef_test_finished"
## How many rows are suspended on a deadline right now (Expect Signal / Watch For Signal raise it
## for the length of their wait). A waiting test records nothing, so without this the quiet break
## below would cut a test off mid-await and report the claims that never ran as a clean pass.
const PENDING_META := "__ef_test_pending"
## Seconds a single test may take before the runner stops waiting on it.
const DEFAULT_TIMEOUT := 5.0
## Frames a test may go without recording anything before it counts as finished. A test whose rows
## all run in one frame would otherwise sit out its whole timeout for nothing.
const QUIET_FRAMES := 30
## Folders never scanned: the plugin's own sources and Godot's import cache.
const SKIPPED_DIRS: Array[String] = ["res://addons", "res://.godot"]


## Runs every test found under `root_path` and returns the results array report_lines() words.
## Both shells call this; it is a coroutine, so `await` it.
static func run_all(tree: SceneTree, root_path: String = "res://", timeout: float = DEFAULT_TIMEOUT) -> Array:
	var results: Array = []
	for path: String in discover(root_path):
		results.append(await run_script(tree, path, timeout))
	return results


## Runs one compiled test script inside `tree` and returns {test, path, entries}. Every failure
## mode - a script that will not load, one that is not a Node, one that says nothing - comes back as
## a recorded FAILURE rather than an absence, so no run can go green by staying silent.
static func run_script(tree: SceneTree, path: String, timeout: float = DEFAULT_TIMEOUT) -> Dictionary:
	var test_name: String = path.get_file().get_basename()
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		return _lone_failure(test_name, path, "the script failed to load - see the parse error above")
	var instance: Variant = script.new()
	var node: Node = instance as Node
	if node == null:
		if instance is Object and not (instance is RefCounted):
			(instance as Object).free()
		return _lone_failure(test_name, path, "a test sheet has to be a Node script - this one is not")
	node.name = test_name
	tree.root.add_child(node)
	await tree.process_frame
	if node.has_signal("test_started"):
		node.emit_signal("test_started", test_name)
	else:
		node.set_meta(REPORT_META, (node.get_meta(REPORT_META, []) as Array)
			+ [[test_name, false, "no test_started signal - re-save this sheet as a Test sheet"]])
	var deadline: int = Time.get_ticks_msec() + int(maxf(timeout, 0.0) * 1000.0)
	var quiet: int = 0
	var seen: int = (node.get_meta(REPORT_META, []) as Array).size()
	while not bool(node.get_meta(FINISHED_META, false)) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		var now_seen: int = (node.get_meta(REPORT_META, []) as Array).size()
		if now_seen != seen:
			seen = now_seen
			quiet = 0
		else:
			quiet += 1
		if seen > 0 and quiet >= QUIET_FRAMES and int(node.get_meta(PENDING_META, 0)) <= 0:
			break
	var entries: Array = (node.get_meta(REPORT_META, []) as Array).duplicate(true)
	node.queue_free()
	await tree.process_frame
	return {"test": test_name, "path": path, "entries": entries}


static func _lone_failure(test_name: String, path: String, reason: String) -> Dictionary:
	return {"test": test_name, "path": path, "entries": [[test_name, false, reason]]}


## Every compiled test script under `root_path`, sorted, found by the header marker. Deliberately a
## text scan: the marker is part of the emitted file, so this works on a folder of scripts with no
## project registry, no import step and no editor running.
static func discover(root_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_scan_dir(root_path if root_path.ends_with("/") else root_path + "/", found)
	found.sort()
	return found


## `dir_path` always ends in "/" here - "res://" is a whole path, not a path plus a separator, so
## trimming the trailing slash off the root turns it into the unopenable "res:/".
static func _scan_dir(dir_path: String, found: PackedStringArray) -> void:
	for skipped: String in SKIPPED_DIRS:
		if dir_path == skipped + "/":
			return
	for file_name: String in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".gd"):
			continue
		var file_path: String = dir_path + file_name
		if has_marker(FileAccess.get_file_as_string(file_path)):
			found.append(file_path)
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		if sub_dir.begins_with("."):
			continue
		_scan_dir(dir_path + sub_dir + "/", found)


## True when the source carries the marker as a DECLARATION - a line of its own. Matching the bare
## text anywhere would claim every file that merely mentions it, this runner and its own test first
## of all, and each of those would then be "run" and fail for not being a test.
static func has_marker(source: String) -> bool:
	for line: String in source.split("\n"):
		if line.strip_edges() == MARKER:
			return true
	return false


## Pass/fail totals over every result. A test that recorded NOTHING counts as one failure: silence
## is the one outcome a test suite may never read as success.
static func summarize(results: Array) -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	for result: Dictionary in results:
		var entries: Array = result.get("entries", []) as Array
		if entries.is_empty():
			failed += 1
			continue
		for entry: Variant in entries:
			if entry is Array and (entry as Array).size() >= 2 and bool((entry as Array)[1]):
				passed += 1
			else:
				failed += 1
	return {"passed": passed, "failed": failed}


## The whole report: one heading per test, one line per claim, the totals, and the verdict line.
## Returned as lines (never printed here) so the editor panel and a CI log show the same text.
static func report_lines(results: Array) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for result: Dictionary in results:
		var entries: Array = result.get("entries", []) as Array
		var test_name: String = str(result.get("test", "test"))
		var counts: Dictionary = summarize([result])
		lines.append("[test] %s: %d passed, %d failed" % [test_name, int(counts["passed"]), int(counts["failed"])])
		if entries.is_empty():
			lines.append("  " + silent_claim(test_name))
			continue
		for entry: Variant in entries:
			lines.append("  " + claim_line(entry))
	lines.append(totals_line(results))
	lines.append(verdict_line(results))
	return lines


## One recorded claim as a readable line: "PASS gravity pulls down" / "FAIL death fires - why".
static func claim_line(entry: Variant) -> String:
	var parts: Array = (entry as Array) if entry is Array else []
	var claim_name: String = str(parts[0]) if parts.size() > 0 else "(unnamed)"
	var passed: bool = bool(parts[1]) if parts.size() > 1 else false
	var message: String = str(parts[2]) if parts.size() > 2 else ""
	var line: String = ("PASS " if passed else "FAIL ") + claim_name
	if not passed and not message.strip_edges().is_empty():
		line += " - " + message
	return line


## What a test that recorded nothing reads as. Worded once here so the panel and the log agree.
static func silent_claim(test_name: String) -> String:
	return "FAIL %s - no claims were recorded; this test asserted nothing" % test_name


static func totals_line(results: Array) -> String:
	var totals: Dictionary = summarize(results)
	return "%d passed, %d failed" % [int(totals["passed"]), int(totals["failed"])]


## The literal verdict the repo's own suite prints, so one habit reads both runs. A run with NO
## results is a failure too: a project whose tests all stopped being found would otherwise print the
## same green line, and pass the same gate, as a project whose tests all passed.
static func verdict_line(results: Array) -> String:
	if results.is_empty():
		return "Some tests failed."
	return "All tests passed." if int(summarize(results)["failed"]) == 0 else "Some tests failed."


## The claim rows a table shows for one result: [name, PASS/FAIL, message]. The panel's content, kept
## here beside the wording it mirrors so the window and the log can never drift apart.
static func claim_rows(result: Dictionary) -> Array:
	var rows: Array = []
	var entries: Array = result.get("entries", []) as Array
	if entries.is_empty():
		rows.append([str(result.get("test", "test")), "FAIL", "no claims were recorded; this test asserted nothing"])
		return rows
	for entry: Variant in entries:
		var parts: Array = (entry as Array) if entry is Array else []
		var claim_name: String = str(parts[0]) if parts.size() > 0 else "(unnamed)"
		var passed: bool = bool(parts[1]) if parts.size() > 1 else false
		var message: String = str(parts[2]) if parts.size() > 2 else ""
		rows.append([claim_name, "PASS" if passed else "FAIL", "" if passed else message])
	return rows
