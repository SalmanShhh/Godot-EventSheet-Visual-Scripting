# EventForge — Test runner entrypoint
# AUTO-DISCOVERS every test in tests/: any script there with `static func run() -> bool` is loaded and
# run, so adding a test is just dropping a file (no registration here). Teardown-style tests (they
# mutate shared state — remove generated files, toggle the plugin) are forced to run LAST so they
# cannot disturb earlier tests. Runs in headless Godot and exits with a status code.
@tool
extends SceneTree
class_name EventForgeTestRunner

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
		if script == null or not _has_static_run(script):
			continue
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
	return files

## True when the loaded script declares a run method (the test contract: static func run() -> bool).
func _has_static_run(script: GDScript) -> bool:
	for method_info: Dictionary in script.get_script_method_list():
		if str(method_info.get("name", "")) == "run":
			return true
	return false
