# EventForge - Test runner entrypoint
# AUTO-DISCOVERS every test in tests/: any script there with `static func run() -> bool` is loaded and
# run, so adding a test is just dropping a file (no registration here). Teardown-style tests (they
# mutate shared state - remove generated files, toggle the plugin) are forced to run LAST so they
# cannot disturb earlier tests. Runs in headless Godot and exits with a status code.
@tool
class_name EventForgeTestRunner
extends SceneTree

const TESTS_DIR := "res://tests/"

# Tests that mutate shared state (filesystem / plugin enablement / workspace) must run AFTER everything
# else, in this order, so they never tear down state an earlier test still needs.
const DEFERRED_LAST: Array[String] = [
	"clean_removal_test.gd",
	"plugin_teardown_test.gd",
	"plugin_workspace_test.gd",
	"workspace_shell_test.gd",
	"perf_smoke_test.gd",
]


func _init() -> void:
	var passed: bool = true
	for test_file: String in _test_files():
		var script: GDScript = load(TESTS_DIR + test_file)
		# A test file with a PARSE ERROR does not load as null - it loads as a GDScript with no methods
		# that cannot be instantiated. That used to look exactly like a helper file with no run(), so a
		# broken test VANISHED from the run and the suite still printed "All tests passed.": a false
		# green hiding however many assertions went with it. can_instantiate() separates the two (every
		# real test instantiates; only a broken parse does not). It prints a [FAIL] line as well as
		# failing the verdict, so the usual grep-for-FAIL catches it too.
		if script == null or not script.can_instantiate():
			print("[FAIL] run_tests: %s failed to load - see the Parse Error above." % test_file)
			push_error("Test %s failed to load (parse error?)." % test_file)
			passed = false
			continue
		if not _has_static_run(script):
			continue  # a shared helper living in tests/, not a test
		var result: Variant = script.call("run")
		if result is bool:
			passed = bool(result) and passed
		else:
			push_error("Test %s did not return a bool from run()." % test_file)
			passed = false
	if passed:
		print("All tests passed.")
		quit(0)
	else:
		push_error("Some tests failed.")
		quit(1)


## Sharding, for running the suite across several Godot processes at once (tools/run_tests_parallel.ps1
## drives it). The variable is read once, here:
##   unset      - every test, in one process, exactly as before;
##   "k/n"      - shard k of n (0-based) of the PARALLEL-SAFE tests: the alphabetical list minus the
##                shared-state tests and the timing tests, taking every n-th file from k;
##   "tail"     - only what a shard skipped: the timing tests (a loaded machine fails them for the
##                wrong reason) and then DEFERRED_LAST, serially, after every shard has finished.
## Any test suite verdict is per process; the launcher is what turns N verdicts into one.
const SHARD_VARIABLE := "EVENTFORGE_TEST_SHARD"

## What makes a test a TIMING test, asked of its own source rather than of its file name: any
## `*BUDGET_MS*` constant (an absolute budget) or a `PARALLEL_UNSAFE` constant (a relative
## measurement, or any other reason a test must have the machine to itself). A name-based rule missed
## `doc_library_test.gd`'s 12-second parse budget for exactly as long as it existed, which is the one
## failure that costs the most to diagnose: a red verdict with nothing wrong in the tree.
const TIMING_MARKER_PATTERN := "(?m)^const\\s+[A-Za-z_]*(BUDGET_MS|PARALLEL_UNSAFE)\\b"


## Test .gd files in a stable order: sorted alphabetically, with the shared-state DEFERRED_LAST tests
## appended last (in their listed order, not alphabetical). run_tests.gd excludes itself; the
## tests/fixtures/ subfolder is excluded automatically (get_files_at is non-recursive).
func _test_files() -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var deferred: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(TESTS_DIR):
		if not file.ends_with(".gd") or file == "run_tests.gd":
			continue  # skips the .gd.uid sidecars too
		if DEFERRED_LAST.has(file):
			deferred.append(file)
		else:
			files.append(file)
	files.sort()
	for deferred_file: String in DEFERRED_LAST:
		if deferred.has(deferred_file):
			files.append(deferred_file)
	return _shard_of(files, OS.get_environment(SHARD_VARIABLE).strip_edges(), timing_files(files))


## The tests that must have the machine to themselves, out of `files`: the ones whose own source
## declares a timing marker (see TIMING_MARKER_PATTERN). Reading the file is what keeps the rule
## honest - a budget lives in the test, not in its name.
static func timing_files(files: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var marker: RegEx = RegEx.new()
	if marker.compile(TIMING_MARKER_PATTERN) != OK:
		return found
	for file: String in files:
		if marker.search(FileAccess.get_file_as_string(TESTS_DIR + file)) != null:
			found.append(file)
	return found


## The slice of `files` a process should run for `shard` (see SHARD_VARIABLE), given the timing tests
## that belong in the serial tail. Pure, so the split itself is testable: every file lands in exactly
## one of the n shards or the tail, never in two and never in neither.
static func _shard_of(files: PackedStringArray, shard: String,
		serial_files: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	if shard.is_empty():
		return files
	var tail: PackedStringArray = PackedStringArray()
	var parallel_safe: PackedStringArray = PackedStringArray()
	for file: String in files:
		if DEFERRED_LAST.has(file) or serial_files.has(file):
			tail.append(file)
		else:
			parallel_safe.append(file)
	if shard == "tail":
		return tail
	var parts: PackedStringArray = shard.split("/")
	var index: int = int(parts[0]) if parts.size() == 2 else 0
	var count: int = maxi(int(parts[1]) if parts.size() == 2 else 1, 1)
	var picked: PackedStringArray = PackedStringArray()
	for position: int in range(parallel_safe.size()):
		if position % count == index:
			picked.append(parallel_safe[position])
	return picked


## True when the loaded script declares a run method (the test contract: static func run() -> bool).
func _has_static_run(script: GDScript) -> bool:
	for method_info: Dictionary in script.get_script_method_list():
		if str(method_info.get("name", "")) == "run":
			return true
	return false
