# Godot EventSheets - the first-time tour's step script.
#
# The tour is data-driven (EventSheetTourWindow.steps()): 7 steps teaching the core loop, each with
# an optional live check the poll evaluates against the open sheet. This pins the content shape and
# drives every check with synthetic sheets, so a tour regression names the exact step.
@tool
class_name TourWindowTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	var steps: Array[Dictionary] = EventSheetTourWindow.steps()
	passed = _check("the tour is 7 steps", steps.size(), 7) and passed
	for index: int in range(steps.size()):
		var step: Dictionary = steps[index]
		passed = _check("step %d has a title, body and task" % (index + 1),
			not str(step.get("title", "")).is_empty() and not str(step.get("body", "")).is_empty() and not str(step.get("task", "")).is_empty(), true) and passed

	# The live checks: steps 2-4 watch the sheet for the asked-for edit; 1, 5, 6 and 7 are read-only.
	var checked_steps: Array = []
	for index: int in range(steps.size()):
		if (steps[index]["check"] as Callable).is_valid():
			checked_steps.append(index + 1)
	passed = _check("steps 2, 3 and 4 carry live checks", checked_steps, [2, 3, 4]) and passed

	var empty_sheet: EventSheetResource = EventSheetResource.new()
	var event_sheet: EventSheetResource = EventSheetResource.new()
	var row: EventRow = EventRow.new()
	event_sheet.events.append(row)
	passed = _check("step 2 stays pending on an empty sheet",
		bool((steps[1]["check"] as Callable).call(empty_sheet)), false) and passed
	passed = _check("step 2 completes once an event exists",
		bool((steps[1]["check"] as Callable).call(event_sheet)), true) and passed
	passed = _check("step 3 stays pending without a condition",
		bool((steps[2]["check"] as Callable).call(event_sheet)), false) and passed
	row.conditions.append(ACECondition.new())
	passed = _check("step 3 completes once a condition exists",
		bool((steps[2]["check"] as Callable).call(event_sheet)), true) and passed
	passed = _check("step 4 stays pending without an action",
		bool((steps[3]["check"] as Callable).call(event_sheet)), false) and passed
	row.actions.append(ACEAction.new())
	passed = _check("step 4 completes once an action exists",
		bool((steps[3]["check"] as Callable).call(event_sheet)), true) and passed
	passed = _check("checks survive a null sheet (no open sheet = pending, never a crash)",
		bool((steps[1]["check"] as Callable).call(null)), false) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tour_window_test: %s" % label)
		return true
	print("[FAIL] tour_window_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
