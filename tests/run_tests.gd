# EventForge - Test runner entrypoint
# AUTO-DISCOVERS every test in tests/: any script there with `static func run() -> bool` is loaded and
# run, so adding a test is just dropping a file (no registration here). Teardown-style tests (they
# mutate shared state - remove generated files, toggle the plugin) are forced to run LAST so they
# cannot disturb earlier tests. Runs in headless Godot and exits with a status code.
@tool
class_name EventForgeTestRunner
extends SceneTree

const TESTS_DIR := "res://tests/"

## The compiler's default output path. A test that compiles a sheet without naming one writes here,
## in the project ROOT, and leaves the file behind - and while it is there it is one more script in
## res://, so a later test that walks the project's scripts counts it and a test that lists what the
## project ships names it. Which tests see it then depends on which ran first in the same process,
## which the sharding decides, so it is swept after every test rather than left to luck.
const STRAY_COMPILE_OUTPUT := "res://event_sheet_generated.gd"

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
	_start_progress()
	for test_file: String in _test_files():
		_mark_started(test_file)
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
		_sweep_stray_output()
		_mark_finished(test_file)
	if passed:
		print("All tests passed.")
		quit(0)
	else:
		push_error("Some tests failed.")
		quit(1)


## Takes the default-path compile artifact back off disk if the test just run left one, so the next
## test walks the project this repository actually ships.
func _sweep_stray_output() -> void:
	if FileAccess.file_exists(STRAY_COMPILE_OUTPUT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STRAY_COMPILE_OUTPUT))


# ── the crash sentinel ──────────────────────────────────────────────────────────
#
# A test that CRASHES the process prints no [FAIL] line - the run simply stops, and every test after
# it never happens. That failure used to cost an afternoon per sighting, because the only evidence
# was a log that ends in the middle. So the run leaves a trail: one line before each test and one
# after it, flushed to disk as they are written. A file whose last line is a start with no finish
# names the test that took the process down, and tools/test_report.gd reads it back and says so.


## Where the trail lives. Under `.godot/`, which is machine-local and ignored by git.
const PROGRESS_DIR: String = "res://.godot/test_progress/"


## The name of this process's own trail file: the shard it is running, made safe for a file name,
## or "serial" for an unsharded run.
static func progress_token() -> String:
	var shard: String = OS.get_environment(SHARD_VARIABLE).strip_edges()
	return "serial" if shard.is_empty() else shard.replace("/", "-")


## A fresh trail per run. Without this the file grows across runs and the last unfinished start is
## whatever crashed a week ago.
func _start_progress() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROGRESS_DIR))
	var file: FileAccess = FileAccess.open(PROGRESS_DIR + progress_token() + ".log", FileAccess.WRITE)
	if file != null:
		file.close()


func _mark_started(test_file: String) -> void:
	_append_progress("START %s" % test_file)


func _mark_finished(test_file: String) -> void:
	_append_progress("DONE %s" % test_file)


## One line on the trail. Opened and closed per line on purpose: a handle held open across a crash
## can lose whatever was still buffered, which is exactly the line that matters.
func _append_progress(line: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROGRESS_DIR))
	var path: String = PROGRESS_DIR + progress_token() + ".log"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path)
		else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()


## Sharding, for running the suite across several Godot processes at once (tools/run_tests_parallel.ps1
## drives it). The variable is read once, here:
##   unset      - every test, in one process, exactly as before;
##   "k/n"      - shard k of n (0-based) of the PARALLEL-SAFE tests: the alphabetical list minus the
##                shared-state tests and the timing tests, taking every n-th file from k;
##   "tail"     - only what a shard skipped: the timing tests (a loaded machine fails them for the
##                wrong reason) and then DEFERRED_LAST, serially, after every shard has finished.
## Any test suite verdict is per process; the launcher is what turns N verdicts into one.
const SHARD_VARIABLE := "EVENTFORGE_TEST_SHARD"

## Run only these tests, comma-separated, with or without the `.gd` (see `_only_requested`). The
## iteration switch of the parallel launcher sets it; so does a single-test rerun by hand.
const ONLY_VARIABLE := "EVENTFORGE_TEST_ONLY"

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
	files = _only_requested(files)
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
##
## A plain round-robin over the alphabetical list, deliberately. Packing it by RECORDED DURATION
## instead - longest test first, onto whichever shard is currently shortest - was built and measured
## twice each on a quiet machine: 4 min 30 s round-robin against 4 min 04 s and 4 min 08 s packed,
## about 9%. The bar for keeping a moving part (a durations file per process, merged and read back
## by the split) was 10%, so it came out again and this stayed.
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


## The explicit list a caller asked for (EVENTFORGE_TEST_ONLY, comma-separated file names), or
## `files` unchanged. This is what the launcher's iteration mode runs first, and what a single-test
## rerun uses; it is deliberately a filter of the discovered list rather than a second discovery, so
## a name that is not a test is dropped rather than half-run.
static func _only_requested(files: PackedStringArray) -> PackedStringArray:
	var requested: String = OS.get_environment(ONLY_VARIABLE).strip_edges()
	if requested.is_empty():
		return files
	var wanted: Dictionary = {}
	for name: String in requested.split(",", false):
		var trimmed: String = name.strip_edges()
		wanted[trimmed if trimmed.ends_with(".gd") else trimmed + ".gd"] = true
	var picked: PackedStringArray = PackedStringArray()
	for file: String in files:
		if wanted.has(file):
			picked.append(file)
	return picked


## True when the loaded script declares a run method (the test contract: static func run() -> bool).
func _has_static_run(script: GDScript) -> bool:
	for method_info: Dictionary in script.get_script_method_list():
		if str(method_info.get("name", "")) == "run":
			return true
	return false
