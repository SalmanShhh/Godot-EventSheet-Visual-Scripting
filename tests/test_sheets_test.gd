# Godot EventSheets - Test sheets: the kind, the vocabulary, and the runner's verdict.
#
# A test sheet is a sheet whose whole job is to make claims, so this file proves the claim chain end
# to end and pins the exact words of the report: the compiled script carries the discovery marker and
# the test_started signal On Test Start hangs off; the assert verbs record [name, passed, message]
# onto the node's own metadata (and the failing ones say WHY); the watch resolves both ways and reads
# back through its two conditions; and the runner turns two real fixture tests - one passing, one
# failing - into the per-test lines, the totals and the literal verdict line the repo's own suite uses.
#
# What the harness can and cannot reach: run_tests.gd has no SceneTree, so the runner's tree half
# (add_child / emit / wait) cannot run here. Everything it depends on is reachable anyway - the
# compiled script is instantiated, its generated _ready() is called by hand so the trigger connects
# for real, and test_started is emitted the way the runner emits it - and the runner's own pure
# halves (discovery, totals, report text) are driven directly. A polling watch is run against a
# stand-in tree carrying a process_frame signal, the same rewrite the flow vocabulary test uses.
@tool
class_name TestSheetsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const RUNNER_PATH := "res://addons/eventsheet/editor/test_sheet_runner.gd"
const FIXTURE_DIR := "user://ef_test_sheet_fixtures"
const TEMP_COMPILE_PATH := "user://ef_test_sheet_compile.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _test_the_kind_compiles_to_a_startable_script() and passed
	passed = _test_the_kind_round_trips_and_reads_as_a_test() and passed
	passed = _test_the_sheet_type_dialog_offers_it() and passed
	passed = _test_claims_record_name_verdict_and_reason() and passed
	passed = _test_pass_and_fail_test_finish_the_test() and passed
	passed = _test_watch_for_signal_reads_back_both_ways() and passed
	passed = _test_the_runner_reports_one_passing_and_one_failing_test() and passed
	passed = _test_a_silent_test_is_a_failure() and passed
	passed = _test_a_waiting_row_is_not_a_quiet_one() and passed
	passed = _test_a_disabled_signal_row_does_not_swallow_the_declaration() and passed
	passed = _test_the_emitted_test_sheet_reopens_byte_identically() and passed
	passed = _test_the_runner_discovers_test_scripts_by_their_marker() and passed
	passed = _test_the_report_panel_shows_the_same_claims() and passed
	return passed


# ── 1. The kind ──────────────────────────────────────────────────────────────────────────
## The Test sheet type is only worth having if what it compiles to can actually be started: a marker
## a runner can find the file by, a real signal, and a handler connected to it.
static func _test_the_kind_compiles_to_a_startable_script() -> bool:
	var source: String = _compile(_passing_sheet())
	var ok: bool = _check("a test sheet emits the discovery marker", source.contains("## @ace_test_sheet"), true)
	ok = _check("a test sheet declares the signal the runner emits",
		source.contains("signal test_started(test_name: String)"), true) and ok
	ok = _check("On Test Start connects to it in _ready",
		source.contains("\ttest_started.connect(_on_test_started)"), true) and ok
	ok = _check("On Test Start's handler takes the test name",
		source.contains("func _on_test_started(test_name: String) -> void:"), true) and ok
	ok = _check("a plain sheet emits no marker", _compile(_plain_sheet()).contains("## @ace_test_sheet"), false) and ok
	ok = _check("a plain sheet declares no test signal",
		_compile(_plain_sheet()).contains("signal test_started"), false) and ok
	return ok


## Opening the emitted .gd again has to say "this is a test" - otherwise the sheet and the runner
## disagree about the same file. The marker is metadata only, so re-emitting is byte-unaffected.
static func _test_the_kind_round_trips_and_reads_as_a_test() -> bool:
	var importer: GDScriptImporter = GDScriptImporter.new()
	var reopened: EventSheetResource = importer.import_external_source(_compile(_passing_sheet()))
	var ok: bool = _check("re-opening the emitted script recovers the test kind", reopened.test_mode, true)
	var plain: EventSheetResource = importer.import_external_source(_compile(_plain_sheet()))
	ok = _check("an ordinary script is not mistaken for a test", plain.test_mode, false) and ok
	var sheet: EventSheetResource = _passing_sheet()
	ok = _check("a test sheet classifies as the Test intent",
		EventSheetScriptIntent.of_sheet(sheet), EventSheetScriptIntent.Intent.TEST) and ok
	ok = _check("the identity banner names it",
		str(EventSheetScriptIntent.display(EventSheetScriptIntent.Intent.TEST).get("label", "")), "Test") and ok
	ok = _check("an empty test sheet is told what to add first",
		str(EventSheetScriptIntent.empty_sheet_advice(sheet).get("heading", "")), "Empty test sheet") and ok
	return ok


## The dialog's Test entry: it forces its own host like Autoload does, and hides the class-name pair
## a Create Node entry needs, because nobody instantiates a test by name.
static func _test_the_sheet_type_dialog_offers_it() -> bool:
	var shown: Dictionary = EventSheetSheetTypeDialog.field_visibility(6)
	var ok: bool = _check("Test hides the class name field", bool(shown["name"]), false)
	ok = _check("Test hides the icon field", bool(shown["icon"]), false) and ok
	ok = _check("Test hides the host field (it is forced)", bool(shown["host"]), false) and ok
	ok = _check("Test keeps the description field", bool(shown["description"]), true) and ok
	ok = _check("the Ships-as line shows the forced host",
		EventSheetSheetTypeDialog.identity_preview(6, "", "CharacterBody2D", ""), "Ships as:  extends Node") and ok
	return ok


# ── 2. The claims ────────────────────────────────────────────────────────────────────────
## Every recorded claim is [name, passed, message], and a FAILING one carries the reason - the whole
## point of the verb. Driven through the real compiled script: _ready connects, the signal starts it.
static func _test_claims_record_name_verdict_and_reason() -> bool:
	var entries: Array = _entries_of(_passing_sheet(), "passing_test")
	var ok: bool = _check("a passing test records one line per claim", entries.size(), 2)
	ok = _check("the first claim is named as written", str((entries[0] as Array)[0]), "two plus two") and ok
	ok = _check("the first claim passed", bool((entries[0] as Array)[1]), true) and ok
	ok = _check("a passing claim needs no message", str((entries[0] as Array)[2]), "") and ok
	var failed: Array = _entries_of(_failing_sheet(), "failing_test")
	ok = _check("a failing test records its claims too", failed.size(), 2) and ok
	ok = _check("the failing claim is marked failed", bool((failed[0] as Array)[1]), false) and ok
	ok = _check("Assert That says what it expected", str((failed[0] as Array)[2]), "expected true, got false") and ok
	ok = _check("Assert Equal carries BOTH values", str((failed[1] as Array)[2]), "expected 3, got 2") and ok
	return ok


## Pass Test / Fail Test state a verdict outright AND mark the test finished, which is what lets a
## runner stop waiting on a test that is done instead of sitting out its whole timeout.
static func _test_pass_and_fail_test_finish_the_test() -> bool:
	var passer: Node = _run_action("PassTest", {"uid": "p", "named": "\"the door opens\""}, "")
	var ok: bool = _check("Pass Test records a pass", bool(((passer.get_meta("__ef_test_report", []) as Array)[0] as Array)[1]), true)
	ok = _check("Pass Test marks the test finished", bool(passer.get_meta("__ef_test_finished", false)), true) and ok
	passer.free()
	var failer: Node = _run_action("FailTest", {"uid": "f", "named": "\"the door opens\"", "reason": "\"it stayed shut\""}, "")
	var entry: Array = (failer.get_meta("__ef_test_report", []) as Array)[0] as Array
	ok = _check("Fail Test records a failure", bool(entry[1]), false) and ok
	ok = _check("Fail Test keeps the reason", str(entry[2]), "it stayed shut") and ok
	ok = _check("Fail Test marks the test finished", bool(failer.get_meta("__ef_test_finished", false)), true) and ok
	failer.free()
	return ok


## The watch: an action that ends two ways, and two conditions that read WHICH - so a test can always
## say why it failed. A deadline of zero times out at once; a real emission resolves it as succeeded.
static func _test_watch_for_signal_reads_back_both_ways() -> bool:
	var timed_out: Node = _run_action("WatchForSignal",
		{"uid": "w", "signal_name": "\"died\"", "target": "self", "seconds": "0.0"}, "signal died")
	var ok: bool = _check("a watch that runs out of time stamps timed out",
		int(timed_out.get_meta(_key("__ef_watch_", "died"), 0)), 2)
	ok = _check("Watch For Signal Timed Out reads that back",
		_condition_says(timed_out, "WatchForSignalTimedOut", {"signal_name": "\"died\""}), true) and ok
	ok = _check("Watch For Signal Succeeded stays false for it",
		_condition_says(timed_out, "WatchForSignalSucceeded", {"signal_name": "\"died\""}), false) and ok
	timed_out.free()
	var watcher: Node = _polling_host(_descriptor("WatchForSignal"),
		{"uid": "w", "signal_name": "\"died\"", "target": "self", "seconds": "9.0"}, "signal died")
	var tree: Node = _instantiate("extends Node\n\nsignal process_frame\n")
	watcher.set("fake_tree", tree)
	watcher.call("run")
	ok = _check("a watch with time left suspends instead of deciding",
		watcher.has_meta(_key("__ef_watch_", "died")), false) and ok
	watcher.emit_signal("died")
	tree.emit_signal("process_frame")
	ok = _check("the signal firing stamps succeeded",
		int(watcher.get_meta(_key("__ef_watch_", "died"), 0)), 1) and ok
	ok = _check("Watch For Signal Succeeded reads that back",
		_condition_says(watcher, "WatchForSignalSucceeded", {"signal_name": "\"died\""}), true) and ok
	ok = _check("a watch nobody armed is neither outcome",
		_condition_says(watcher, "WatchForSignalTimedOut", {"signal_name": "\"landed\""}), false) and ok
	watcher.free()
	tree.free()
	return ok


# ── 3. The runner ────────────────────────────────────────────────────────────────────────
## The whole point, on two real fixture tests: the report names each test, lists every claim with its
## reason, totals them, and ends with the literal verdict line - which flips with the failures.
static func _test_the_runner_reports_one_passing_and_one_failing_test() -> bool:
	var runner: GDScript = load(RUNNER_PATH)
	var results: Array = [
		{"test": "passing_test", "entries": _entries_of(_passing_sheet(), "passing_test")},
		{"test": "failing_test", "entries": _entries_of(_failing_sheet(), "failing_test")},
	]
	var lines: PackedStringArray = runner.call("report_lines", results)
	var ok: bool = _check("the report has a line per test, per claim, plus totals and a verdict", lines.size(), 8)
	ok = _check("the passing test's heading", lines[0], "[test] passing_test: 2 passed, 0 failed") and ok
	ok = _check("a passing claim reads as a pass", lines[1], "  PASS two plus two") and ok
	ok = _check("the failing test's heading", lines[3], "[test] failing_test: 0 passed, 2 failed") and ok
	ok = _check("a failing claim carries its reason", lines[4], "  FAIL gravity pulls down - expected true, got false") and ok
	ok = _check("Assert Equal's failure names both values", lines[5], "  FAIL score - expected 3, got 2") and ok
	ok = _check("the totals count every claim", lines[6], "2 passed, 2 failed") and ok
	ok = _check("a run with a failure says so in the suite's own words", lines[7], "Some tests failed.") and ok
	var green: PackedStringArray = runner.call("report_lines", [results[0]])
	ok = _check("a run with no failures says so in the suite's own words",
		green[green.size() - 1], "All tests passed.") and ok
	return ok


## The trap this runner exists to avoid: a test that recorded NOTHING (it crashed, it never started,
## every row was disabled) must not read as a clean run.
static func _test_a_silent_test_is_a_failure() -> bool:
	var runner: GDScript = load(RUNNER_PATH)
	var silent: Array = [{"test": "silent_test", "entries": []}]
	var ok: bool = _check("a test that asserted nothing counts as a failure",
		int((runner.call("summarize", silent) as Dictionary)["failed"]), 1)
	var lines: PackedStringArray = runner.call("report_lines", silent)
	ok = _check("and the report says exactly that",
		lines[1], "  FAIL silent_test - no claims were recorded; this test asserted nothing") and ok
	ok = _check("so the verdict is not green", lines[lines.size() - 1], "Some tests failed.") and ok
	# The same rule one level up: a run that found NOTHING to run is not a clean run either.
	ok = _check("a run with no tests at all is not green",
		str(runner.call("verdict_line", [])), "Some tests failed.") and ok
	return ok


## A row that is WAITING records nothing, which from the runner's side looks exactly like a test
## with nothing left to say. Expect Signal and Watch For Signal raise a pending count for the length
## of their wait so the quiet break cannot cut a test off mid-await and report the claims that never
## ran as a clean pass.
static func _test_a_waiting_row_is_not_a_quiet_one() -> bool:
	var runner: GDScript = load(RUNNER_PATH)
	var pending_key: String = str(runner.get_script_constant_map().get("PENDING_META", ""))
	var ok: bool = _check("the runner and the vocabulary agree on the pending key",
		pending_key, EventForgeTestingACEs.PENDING_META)
	var expect_source: String = _bake(_descriptor("ExpectSignal"), {
		"named": "\"death fires\"", "signal_name": "\"died\"", "target": "self", "seconds": "2.0"})
	ok = _check("Expect Signal raises the pending count before it waits",
		expect_source.split("\n")[0].contains("%s\", int(get_meta(&\"%s\", 0)) + 1" % [pending_key, pending_key]), true) and ok
	ok = _check("…and lowers it again afterwards",
		expect_source.contains("maxi(int(get_meta(&\"%s\", 0)) - 1, 0)" % pending_key), true) and ok
	var watch_source: String = _bake(_descriptor("WatchForSignal"), {
		"signal_name": "\"died\"", "target": "self", "seconds": "2.0"})
	ok = _check("Watch For Signal does the same", watch_source.contains(pending_key), true) and ok
	return ok


## A DISABLED test_started row declares nothing - the compiler emits no `signal` line for it - so it
## must not suppress the compiler's own declaration. Otherwise the sheet connects On Test Start to a
## signal that exists nowhere, and fails at runtime after a perfectly green compile.
static func _test_a_disabled_signal_row_does_not_swallow_the_declaration() -> bool:
	var sheet: EventSheetResource = _passing_sheet()
	var declared: SignalRow = SignalRow.new()
	declared.signal_name = "test_started"
	declared.enabled = false
	sheet.events.insert(0, declared)
	var source: String = _compile(sheet)
	var ok: bool = _check("the signal is still declared exactly once",
		source.count("signal test_started"), 1)
	ok = _check("…so the handler connects to something real",
		source.contains("\ttest_started.connect(_on_test_started)"), true) and ok
	return ok


## The lossless claim the marker comment makes, checked as BYTES rather than as a flag: write the
## emitted script, open it the way the editor opens a .gd sheet, re-emit, compare. A marker that
## moved, or a prelude that swallowed it, would show up here and nowhere else.
static func _test_the_emitted_test_sheet_reopens_byte_identically() -> bool:
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)
	var path: String = FIXTURE_DIR + "/round_trip_test.gd"
	var first: String = _compile(_passing_sheet())
	_write(path, first)
	var importer: GDScriptImporter = GDScriptImporter.new()
	var reopened: EventSheetResource = importer.import_external(path)
	var ok: bool = _check("the reopened sheet is still a test", reopened.test_mode, true)
	ok = _check("re-emitting it is byte-identical", _compile(reopened), first) and ok
	ok = _check("…with the marker still declared exactly once", first.count("## @ace_test_sheet"), 1) and ok
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(FIXTURE_DIR)
	return ok


## Discovery is a text scan for the marker the compiler emits, so a folder of compiled sheets is a
## test suite with no registry, no project setting and no editor running.
static func _test_the_runner_discovers_test_scripts_by_their_marker() -> bool:
	var runner: GDScript = load(RUNNER_PATH)
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)
	_write(FIXTURE_DIR + "/failing_test.gd", _compile(_failing_sheet()))
	_write(FIXTURE_DIR + "/passing_test.gd", _compile(_passing_sheet()))
	_write(FIXTURE_DIR + "/not_a_test.gd", _compile(_plain_sheet()))
	var found: PackedStringArray = runner.call("discover", FIXTURE_DIR)
	var ok: bool = _check("only the marked scripts are found", found.size(), 2)
	ok = _check("they come back sorted, first", found[0], FIXTURE_DIR + "/failing_test.gd") and ok
	ok = _check("they come back sorted, second", found[1], FIXTURE_DIR + "/passing_test.gd") and ok
	for file_name: String in DirAccess.get_files_at(FIXTURE_DIR):
		DirAccess.remove_absolute(FIXTURE_DIR + "/" + file_name)
	DirAccess.remove_absolute(FIXTURE_DIR)
	return ok


## The Run Tests… window is only ever the sum of these rows, so its content is asserted where it is
## assembled: one table row per claim, the reason kept for the failures and blanked for the passes
## (a "Why" column repeating "it worked" for every pass is noise). Same source as the printed lines,
## which is what keeps the window and the terminal from drifting apart.
static func _test_the_report_panel_shows_the_same_claims() -> bool:
	var runner: GDScript = load(RUNNER_PATH)
	var result: Dictionary = {"test": "failing_test", "entries": _entries_of(_failing_sheet(), "failing_test")}
	var rows: Array = runner.call("claim_rows", result)
	var ok: bool = _check("the panel shows one row per claim", rows.size(), 2)
	ok = _check("the row names the claim", str((rows[0] as Array)[0]), "gravity pulls down") and ok
	ok = _check("the row states the result", str((rows[0] as Array)[1]), "FAIL") and ok
	ok = _check("the row carries the reason", str((rows[1] as Array)[2]), "expected 3, got 2") and ok
	var green: Array = runner.call("claim_rows", {"test": "passing_test", "entries": _entries_of(_passing_sheet(), "passing_test")})
	ok = _check("a passing row states PASS", str((green[0] as Array)[1]), "PASS") and ok
	ok = _check("a passing row needs no reason", str((green[0] as Array)[2]), "") and ok
	var silent: Array = runner.call("claim_rows", {"test": "silent_test", "entries": []})
	ok = _check("a silent test still gets a row", str((silent[0] as Array)[1]), "FAIL") and ok
	ok = _check("the window's verdict pill matches the printed one",
		str(runner.call("verdict_line", [result])), "Some tests failed.") and ok
	return ok


# ── Fixtures + harness ───────────────────────────────────────────────────────────────────
## The passing fixture: On Test Start, two claims that hold.
static func _passing_sheet() -> EventSheetResource:
	return _test_sheet([
		_action("AssertThat", {"uid": "a1", "named": "\"two plus two\"", "claim": "2 + 2 == 4"}),
		_action("AssertEqual", {"uid": "a2", "named": "\"score\"", "actual": "4", "expected": "4"}),
	])


## The failing fixture: the same shape, two claims that do not hold.
static func _failing_sheet() -> EventSheetResource:
	return _test_sheet([
		_action("AssertThat", {"uid": "b1", "named": "\"gravity pulls down\"", "claim": "1 > 2"}),
		_action("AssertEqual", {"uid": "b2", "named": "\"score\"", "actual": "2", "expected": "3"}),
	])


static func _test_sheet(actions: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.test_mode = true
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnTestStart"
	for action: Variant in actions:
		row.actions.append(action)
	sheet.events.append(row)
	return sheet


## An ordinary sheet with the same trigger shape, to prove the marker/signal are the TEST kind's and
## not something every sheet gets.
static func _plain_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawCode"
	action.codegen_template = "pass"
	row.actions.append(action)
	sheet.events.append(row)
	return sheet


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


## Compiles a sheet, instantiates the emitted script, calls its generated _ready() so the trigger
## really connects, and emits test_started exactly the way the runner does. Returns the report the
## rows recorded on the node.
static func _entries_of(sheet: EventSheetResource, test_name: String) -> Array:
	var node: Node = _instantiate(_compile(sheet))
	if node == null:
		return []
	node.call("_ready")
	node.emit_signal("test_started", test_name)
	var entries: Array = (node.get_meta("__ef_test_report", []) as Array).duplicate(true)
	node.free()
	return entries


## Runs ONE action's shipped template on a bare host and hands back the node it recorded onto.
static func _run_action(ace_id: String, values: Dictionary, members: String) -> Node:
	var descriptor: ACEDescriptor = _descriptor(ace_id)
	var node: Node = _instantiate(_wrap(_bake(descriptor, values), members))
	node.call("run")
	return node


## The same, but with get_tree() rewritten to a stand-in carrying process_frame, so a polling watch
## really loops and the test drives the frames.
static func _polling_host(descriptor: ACEDescriptor, values: Dictionary, members: String) -> Node:
	var source: String = _wrap(_bake(descriptor, values), members).replace("get_tree()", "_tree()")
	source += "\n\nvar fake_tree: Object = null\n\n\nfunc _tree() -> Object:\n\treturn fake_tree\n"
	return _instantiate(source)


static func _wrap(statement: String, members: String) -> String:
	var source: String = "extends Node\n\n"
	if not members.is_empty():
		source += members + "\n\n"
	source += "\nfunc run() -> void:\n"
	for line: String in statement.split("\n"):
		source += "\t%s\n" % line
	return source


## Evaluates a CONDITION descriptor's shipped template against a live node.
static func _condition_says(node: Node, ace_id: String, values: Dictionary) -> bool:
	var probe: Node = _instantiate("extends Node\n\n\nfunc ask(host: Node) -> bool:\n\treturn %s\n"
		% _bake(_descriptor(ace_id), values).replace("get_meta(", "host.get_meta("))
	if probe == null:
		return false
	var answer: bool = bool(probe.call("ask", node))
	probe.free()
	return answer


static func _descriptor(ace_id: String) -> ACEDescriptor:
	return ACERegistry.find_descriptor("Core", ace_id)


static func _bake(descriptor: ACEDescriptor, values: Dictionary) -> String:
	var output: String = descriptor.codegen_template
	for key: Variant in values.keys():
		output = output.replace("{%s}" % str(key), str(values[key]))
	return output


## The metadata key a name-keyed family really writes: the prefix plus the name's bytes as hex,
## because Object.set_meta refuses anything that is not a valid identifier.
static func _key(prefix: String, name: String) -> StringName:
	return StringName(prefix + name.to_utf8_buffer().hex_encode())


static func _compile(sheet: EventSheetResource) -> String:
	# compile() always WRITES its result somewhere - with no path given, to res://event_sheet_generated.gd
	# at the project root. A test sheet written there would be a real, discoverable test sheet sitting in
	# the project, which the runner would then find and run on every headless invocation. So the write is
	# aimed at a temporary path and removed again.
	var source: String = str(SheetCompiler.compile(sheet, TEMP_COMPILE_PATH).get("output", ""))
	DirAccess.remove_absolute(TEMP_COMPILE_PATH)
	return source


static func _instantiate(source: String) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  compiled source failed to reload:\n%s" % source)
		return null
	var node: Node = Node.new()
	node.set_script(script)
	return node


static func _write(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("test_sheets_test", label, actual, expected)
