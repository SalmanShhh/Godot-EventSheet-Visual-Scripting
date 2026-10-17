# Godot EventSheets - what enabling the plugin and opening the first sheet cost in a REAL editor.
#
# `huge_project_budget_test` budgets the same two waits from a bare `--script` process, which has no
# editor around it. This one starts an actual editor (`--editor --headless`) on this project with
# the plugin left out of its boot, and runs `tools/measure_editor_boot.gd` inside it: the plugin is
# enabled through EditorInterface, then the first sheet is opened through the plugin's own door and
# timed until its lift lands. Those are the two numbers a person meets, and every later wave of
# work is held to them.
#
# EVERY NUMBER WAS MEASURED three times at the commit that set it, on a quiet machine:
#   headless (what this test runs)   enable 497, 446, 460 ms     first open 29,300, 27,326, 27,599 ms
#   a visible editor                 enable 465, 447, 443 ms     first open 26,516, 26,572, 23,536 ms
# Those first opens also reopened whatever tabs the last editor closed on the machine had left in
# the session file, which is what made them wander by seconds; the tool keeps session restore off now.
# Measured again 2026-10-17 once the first open stopped compiling the Doctor and the dialogs, three
# runs of this test in the repository: enable 315, 312, 314 ms, first open 16,453, 16,277, 16,485 ms
# (16,091-16,174 in a copy outside OneDrive). The budgets are about three times the headless
# medians, because a timing pin with less room than that flaps on a shared runner. What they exist to catch is a regression IN KIND: a heavy class
# named on the boot path (enabling used to cost about 2,000 ms), or a first open that starts building
# per sheet what it builds once.
#
# THE WARN LINES are the tighter half: about one and a half times the same medians. Past one, the
# test prints a loud `[boot] WARN` line and still passes - a slower first open is seen on the run that
# made it, without a shared runner's bad minute failing the suite. The launcher repeats every
# `[boot]` line under its verdict and CI writes them into the tail job's summary, so the two numbers
# can be read side by side across runs.
#
# The editor child takes about a minute; the `*BUDGET_MS` constants put this file in the launcher's
# serial tail, where nothing else competes with it for the machine.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "editor_boot_budget_test"
const MEASURE_TOOL: String = "res://tools/measure_editor_boot.gd"
const RESULT_PREFIX: String = "editor boot: "

## Enabling the plugin in a running editor, through the next frame. Median measured 314 ms.
const ENABLE_BUDGET_MS: int = 1500
## Opening the first sheet of the session through the plugin, until its lift lands: the lazy
## workspace build, the once-per-session registries and the lift. Median measured 16,453 ms.
const FIRST_OPEN_BUDGET_MS: int = 49400
## The WARN thresholds: about 1.5 times each median. Crossing one prints, never fails.
const ENABLE_WARN_MS: int = 470
const FIRST_OPEN_WARN_MS: int = 24700


static func run() -> bool:
	var output: Array = []
	var arguments: PackedStringArray = PackedStringArray(["--editor", "--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", MEASURE_TOOL])
	OS.execute(OS.get_executable_path(), arguments, output, true)
	var numbers: Dictionary = _numbers(output)
	if not numbers.has("first_open_ms"):
		# A budget nobody measured is worse than none, so an editor that answered nothing fails.
		print("  the editor printed no result line; its output was:")
		for chunk: Variant in output:
			print("  %s" % str(chunk))
	var enable_ms: float = float(numbers.get("enable_ms", -1.0))
	var first_open_ms: float = float(numbers.get("first_open_ms", -1.0))
	# The blank sheet the workspace seeds and the one sheet the tool opens, and nothing else: the
	# tool keeps session restore off, so the figure is never one sheet plus whatever the last editor
	# anybody closed on this machine had open.
	var tabs: int = int(numbers.get("tabs", -1.0))
	print("  [boot] enable %d ms (budget %d), first open %d ms (budget %d)" % [
		roundi(enable_ms), ENABLE_BUDGET_MS, roundi(first_open_ms), FIRST_OPEN_BUDGET_MS])
	for line: String in warnings(enable_ms, first_open_ms):
		print(line)
	return SUPPORT.pins(TEST_NAME, [
		["the editor measured enabling the plugin", enable_ms >= 0.0, true],
		["the editor measured the first sheet open", first_open_ms >= 0.0, true],
		["the timed open reopened no earlier session (the blank sheet and the one opened)", tabs, 2],
		["enabling the plugin stays inside its budget", enable_ms <= float(ENABLE_BUDGET_MS), true],
		["the first sheet open stays inside its budget", first_open_ms <= float(FIRST_OPEN_BUDGET_MS), true],
		["numbers inside their warn lines say nothing more", warnings(314.0, 16453.0), PackedStringArray()],
		["a first open past its warn line is said loudly", warnings(314.0, 30000.0), PackedStringArray([
			"  [boot] WARN the first sheet open took 30000 ms, past the 24700 ms warn line (median 16,453)"])],
	])


## The loud lines for a number past its WARN threshold but (perhaps) inside its budget.
static func warnings(enable_ms: float, first_open_ms: float) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if enable_ms > float(ENABLE_WARN_MS):
		lines.append("  [boot] WARN enabling the plugin took %d ms, past the %d ms warn line (median 314)" % [
			roundi(enable_ms), ENABLE_WARN_MS])
	if first_open_ms > float(FIRST_OPEN_WARN_MS):
		lines.append("  [boot] WARN the first sheet open took %d ms, past the %d ms warn line (median 16,453)" % [
			roundi(first_open_ms), FIRST_OPEN_WARN_MS])
	return lines


## The `key=value` pairs off the tool's one result line.
static func _numbers(output: Array) -> Dictionary:
	var numbers: Dictionary = {}
	for chunk: Variant in output:
		for line: String in str(chunk).split("\n"):
			if not line.begins_with(RESULT_PREFIX):
				continue
			for pair: String in line.trim_prefix(RESULT_PREFIX).strip_edges().split(" ", false):
				var parts: PackedStringArray = pair.split("=")
				if parts.size() == 2 and parts[1].is_valid_float():
					numbers[parts[0]] = float(parts[1])
	return numbers
