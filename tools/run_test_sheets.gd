# EventForge - run every Test sheet in the project, headlessly, and print a verdict.
#
#   godot --headless --path . --script tools/run_test_sheets.gd
#   godot --headless --path . --script tools/run_test_sheets.gd -- --root user://my_tests --timeout 10
#
# A thin shell: discovery, running a test and the wording of the report all live in
# addons/eventsheet/editor/test_sheet_runner.gd, so this command and the editor's Tools > Run Tests…
# panel print the same lines. Exits 0 when the run ends "All tests passed." and 1 when it ends
# "Some tests failed.", so a CI step can gate on either the line or the status.
#
# The work runs from _initialize rather than _init: a test has to enter a real tree and live across
# frames, and during _init there is no main loop to enter yet.
@tool
extends SceneTree

const RUNNER_PATH := "res://addons/eventsheet/editor/test_sheet_runner.gd"


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	var runner: GDScript = load(RUNNER_PATH)
	if runner == null:
		push_error("Test runner not found at %s - is the EventSheets plugin installed?" % RUNNER_PATH)
		print("Some tests failed.")
		quit(1)
		return
	var constants: Dictionary = runner.get_script_constant_map()
	var root_path: String = _argument("--root", "res://")
	var timeout: float = float(_argument("--timeout", str(constants.get("DEFAULT_TIMEOUT", 5.0))))
	var paths: PackedStringArray = runner.call("discover", root_path)
	if paths.is_empty():
		# Nothing to run must never READ as a clean run: a project whose tests all stopped being
		# found would otherwise print the same green line, and pass the same CI gate, as a project
		# whose tests all passed. So the verdict line is the failing one and the status is 1 - the
		# printed sentence says plainly that nothing ran, which is the fact to act on.
		print("No test sheets found under %s (a Test sheet's script carries the %s marker on a line of its own)."
			% [root_path, str(constants.get("MARKER", ""))])
		print("Some tests failed.")
		quit(1)
		return
	var results: Array = []
	for path: String in paths:
		results.append(await runner.call("run_script", self, path, timeout))
	for line: String in runner.call("report_lines", results):
		print(line)
	quit(0 if int((runner.call("summarize", results) as Dictionary)["failed"]) == 0 else 1)


## A `--name value` pair from the arguments after `--`, or the fallback.
func _argument(argument_name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		if args[index] == argument_name and index + 1 < args.size():
			return args[index + 1]
	return fallback
