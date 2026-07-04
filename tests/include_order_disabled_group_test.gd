@tool
class_name IncludeOrderDisabledGroupTest
extends RefCounted
# Two compiler-behaviour fixes, pinned against real generated output:
#   #4 Include ORDER  - an included (library) sheet's events run BEFORE the root's own events,
#      matching Construct 3's "include the library at the top" (shared setup initializes first).
#   #5 Disabled group - a disabled group no longer vanishes silently; it leaves a breadcrumb
#      comment so the omission is visible in the generated .gd (its events still don't run).


static func run() -> bool:
	var all_passed: bool = true

	# ── #4: included events run first ───────────────────────────────────────────
	var library: EventSheetResource = EventSheetResource.new()
	var lib_event: EventRow = EventRow.new()
	lib_event.trigger_provider_id = "Core"
	lib_event.trigger_id = "OnReady"
	var lib_action: ACEAction = ACEAction.new()
	lib_action.codegen_template = "library_first()"
	lib_event.actions.append(lib_action)
	library.events.append(lib_event)
	var lib_path: String = "user://eventsheets_order_lib.tres"
	all_passed = _check("library saves", ResourceSaver.save(library, lib_path), OK) and all_passed

	var root: EventSheetResource = EventSheetResource.new()
	root.includes = [lib_path]
	var root_event: EventRow = EventRow.new()
	root_event.trigger_provider_id = "Core"
	root_event.trigger_id = "OnReady"
	var root_action: ACEAction = ACEAction.new()
	root_action.codegen_template = "root_second()"
	root_event.actions.append(root_action)
	root.events.append(root_event)

	var out: String = str(SheetCompiler.compile(root).get("output", ""))
	var lib_pos: int = out.find("library_first()")
	var root_pos: int = out.find("root_second()")
	all_passed = _check("both events compile into the same handler", lib_pos != -1 and root_pos != -1, true) and all_passed
	all_passed = _check("included (library) events run BEFORE the root's events", lib_pos != -1 and lib_pos < root_pos, true) and all_passed

	# ── #5: disabled group leaves a breadcrumb ──────────────────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	var group: EventGroup = EventGroup.new()
	group.name = "Combat"
	group.enabled = false
	var hidden_a: EventRow = EventRow.new()
	hidden_a.trigger_provider_id = "Core"
	hidden_a.trigger_id = "OnReady"
	var hidden_a_action: ACEAction = ACEAction.new()
	hidden_a_action.codegen_template = "never_runs_one()"
	hidden_a.actions.append(hidden_a_action)
	var hidden_b: EventRow = EventRow.new()
	hidden_b.trigger_provider_id = "Core"
	hidden_b.trigger_id = "OnProcess"
	var hidden_b_action: ACEAction = ACEAction.new()
	hidden_b_action.codegen_template = "never_runs_two()"
	hidden_b.actions.append(hidden_b_action)
	group.events = [hidden_a, hidden_b]
	sheet.events = [group]

	var disabled_out: String = str(SheetCompiler.compile(sheet).get("output", ""))
	all_passed = _check("disabled group leaves a breadcrumb",
		disabled_out.contains("(disabled group \"Combat\" — 2 rows omitted)"), true) and all_passed
	all_passed = _check("a disabled group's events are NOT emitted (still excluded)",
		not disabled_out.contains("never_runs_one()") and not disabled_out.contains("never_runs_two()"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] include_order_disabled_group_test: %s" % label)
		return true
	print("[FAIL] include_order_disabled_group_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
