# Godot EventSheets — budget/coroutine ACEs (frame-spreading Solution 3).
#
# Three ACTION ACEs for hand-rolled frame-spreading inside a loop: Await Next Frame, Begin Frame Budget,
# and Await If Over Budget. They reuse the Wait/await machinery (the handler becomes an implicit
# coroutine). This asserts they register with the right await templates AND that a one-shot handler
# using them compiles to a valid coroutine.
@tool
class_name BudgetAcesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("budget ACEs registered", by_id.has("AwaitNextFrame") and by_id.has("BeginFrameBudget") and by_id.has("AwaitIfOverBudget"), true) and all_passed
	if not (by_id.has("AwaitNextFrame") and by_id.has("BeginFrameBudget") and by_id.has("AwaitIfOverBudget")):
		return all_passed

	all_passed = _check("Await Next Frame yields a frame", str((by_id["AwaitNextFrame"] as ACEDescriptor).codegen_template), "await get_tree().process_frame") and all_passed
	all_passed = _check("Begin Frame Budget arms a usec fence", str((by_id["BeginFrameBudget"] as ACEDescriptor).codegen_template).contains("Time.get_ticks_usec() + int("), true) and all_passed
	all_passed = _check("Await If Over Budget yields on its LAST line (await-last-line rule)", str((by_id["AwaitIfOverBudget"] as ACEDescriptor).codegen_template).strip_edges().ends_with("await get_tree().process_frame"), true) and all_passed

	# Compile-shape: a one-shot On Ready handler with Begin Frame Budget + Await If Over Budget compiles
	# to a valid coroutine.
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var begin: ACEAction = ACEAction.new()
	begin.provider_id = "Core"
	begin.ace_id = "BeginFrameBudget"
	begin.codegen_template = str((by_id["BeginFrameBudget"] as ACEDescriptor).codegen_template)
	begin.params = {"ms": "8.0"}
	event.actions.append(begin)
	var over: ACEAction = ACEAction.new()
	over.provider_id = "Core"
	over.ace_id = "AwaitIfOverBudget"
	over.codegen_template = str((by_id["AwaitIfOverBudget"] as ACEDescriptor).codegen_template)
	over.params = {"ms": "8.0"}
	event.actions.append(over)
	sheet.events.append(event)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_budget.gd").get("output", ""))
	all_passed = _check("Begin Frame Budget emits the fence with the param", output.contains("var __ace_budget_end := Time.get_ticks_usec() + int(8.0 * 1000.0)"), true) and all_passed
	all_passed = _check("Await If Over Budget emits the guarded await", output.contains("if Time.get_ticks_usec() >= __ace_budget_end:") and output.contains("await get_tree().process_frame"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("budget output parses (handler is a valid coroutine)", generated.reload(true) == OK, true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] budget_aces_test: %s" % label)
		return true
	print("[FAIL] budget_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
