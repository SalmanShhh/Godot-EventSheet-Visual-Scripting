# Godot EventSheets - background_runner pack (frame-spreading Solution 4) off-thread compute.
#
# Run In Background hands a PURE callable to WorkerThreadPool; On Done(result) fires on the main thread
# when it finishes. This loads the COMPILED pack, runs a pure static function off-thread, and polls until
# the result comes back - proving the add_task / Mutex-guarded result / main-thread emit round-trip works.
@tool
class_name BackgroundRunnerPackTest
extends RefCounted

const PACK := "res://eventsheet_addons/background_runner/background_runner_behavior.gd"


# A PURE worker function: no scene-tree, no Node access - exactly what may run off-thread.
static func _square(n: int) -> int:
	return n * n


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("background_runner pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var runner: Node = script.new()
	var results: Array = []
	runner.done.connect(func(r: Variant) -> void: results.append(r))
	all_passed = _check("an idle runner is not running", runner.is_running(), false) and all_passed

	runner.run_in_background(BackgroundRunnerPackTest._square.bind(7))
	all_passed = _check("launching a task marks it running", runner.is_running(), true) and all_passed
	all_passed = _check("tasks_running counts it", runner.tasks_running(), 1) and all_passed

	# Poll until the worker thread finishes (each iteration is one "frame").
	var guard: int = 0
	while runner.is_running() and guard < 500:
		OS.delay_msec(2)
		runner._process(0.016)
		guard += 1
	all_passed = _check("the background task completes", runner.is_running(), false) and all_passed
	all_passed = _check("On Done fires with the off-thread result", results.size() == 1 and results[0] == 49, true) and all_passed

	runner.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] background_runner_pack_test: %s" % label)
		return true
	print("[FAIL] background_runner_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
