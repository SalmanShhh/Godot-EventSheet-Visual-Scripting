# EventForge - ACE-level import lifting (reverse template matching)
#
# Opening generated GDScript as a sheet lifts trigger functions back into real EventRows:
# conditions/actions reverse-match builtin codegen templates (params captured as strings),
# unmatched statements become in-flow GDScript blocks. The lift is all-or-nothing per file
# and ONLY kept when recompiling reproduces the source byte-for-byte; otherwise everything
# stays verbatim block rows (the lossless rule).
@tool
class_name ACELiftTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Author a sheet, compile it (normal mode), then open the OUTPUT as a sheet.
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "CharacterBody2D"
	authored.variables = {"health": {"type": "int", "default": 100, "exported": true}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var grounded: ACECondition = ACECondition.new()
	grounded.provider_id = "Core"
	grounded.ace_id = "IsOnFloor"
	event.conditions.append(grounded)
	var vanish: ACEAction = ACEAction.new()
	vanish.provider_id = "Core"
	vanish.ace_id = "QueueFree"
	event.actions.append(vanish)
	var custom_line: RawCodeRow = RawCodeRow.new()
	custom_line.code = "health -= 1"  # now reverse-lifts to SubtractVar (Phase 0 compound-assign ACE)
	event.actions.append(custom_line)
	var irreducible_line: RawCodeRow = RawCodeRow.new()
	# A bitwise-or-assign has no ACE (and isn't a `x = y` SetVar nor an arithmetic compound-assign), so it
	# stays an in-flow code cell - the honest fallback for a statement no template can reproduce.
	irreducible_line.code = "flags |= 2"
	event.actions.append(irreducible_line)
	authored.events.append(event)
	var source: String = str(SheetCompiler.compile(authored, "user://eventforge_lift_source.gd").get("output", ""))

	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var lifted_event: EventRow = null
	var function_blocks: int = 0
	for row in imported.events:
		if row is EventRow:
			lifted_event = row
		elif row is RawCodeRow and (row as RawCodeRow).code.begins_with("func "):
			function_blocks += 1
	all_passed = _check("trigger function lifts to a real event", lifted_event != null, true) and all_passed
	all_passed = _check("no function blocks remain after the lift", function_blocks, 0) and all_passed
	if lifted_event != null:
		all_passed = _check("trigger reverses to OnProcess", lifted_event.trigger_id, "OnProcess") and all_passed
		all_passed = _check("condition reverse-matches its template",
			lifted_event.conditions.size() == 1 and lifted_event.conditions[0].ace_id == "IsOnFloor", true) and all_passed
		var lifted_action_ids: Array = []
		var inflow_blocks: int = 0
		for entry in lifted_event.actions:
			if entry is ACEAction:
				lifted_action_ids.append((entry as ACEAction).ace_id)
			elif entry is RawCodeRow:
				inflow_blocks += 1
		all_passed = _check("QueueFree action reverse-matches its template", lifted_action_ids.has("QueueFree"), true) and all_passed
		all_passed = _check("compound-assign reverse-matches (health -= 1 -> SubtractVar)", lifted_action_ids.has("SubtractVar"), true) and all_passed
		all_passed = _check("unmatched statement becomes an in-flow block", inflow_blocks, 1) and all_passed

	# The contract: the lifted sheet recompiles byte-identically.
	imported.external_source_path = "user://eventforge_lift_roundtrip.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventforge_lift_roundtrip.gd").get("output", ""))
	all_passed = _check("lifted sheet round-trips byte-identically", roundtrip == source, true) and all_passed

	# Params survive the reverse match as strings and re-emit identically.
	var param_sheet: EventSheetResource = EventSheetResource.new()
	var param_event: EventRow = EventRow.new()
	param_event.trigger_provider_id = "Core"
	param_event.trigger_id = "OnReady"
	var set_velocity: ACEAction = ACEAction.new()
	set_velocity.provider_id = "Core"
	set_velocity.ace_id = "SetVelocity2D"
	set_velocity.params = {"vel": "Vector2(120, -30)"}
	param_event.actions.append(set_velocity)
	param_sheet.events.append(param_event)
	var param_source: String = str(SheetCompiler.compile(param_sheet, "user://eventforge_lift_params.gd").get("output", ""))
	var param_imported: EventSheetResource = GDScriptImporter.new().import_external_source(param_source)
	var reversed_action: ACEAction = null
	for row in param_imported.events:
		if row is EventRow and not (row as EventRow).actions.is_empty():
			reversed_action = (row as EventRow).actions[0] as ACEAction
	all_passed = _check("template params are captured", reversed_action != null and not reversed_action.params.is_empty(), true) and all_passed
	# Specific ACEs must win over the generic Core catch-alls: `velocity = {vel}` (SetVelocity2D) must
	# not reverse-lift to the generic `{var_name} = {value}` (SetVar). Pins the specificity-sort fix -
	# the byte-roundtrip alone never caught this (SetVar re-emits the identical line).
	all_passed = _check("specific ACE wins over the generic SetVar catch-all",
		reversed_action != null and reversed_action.ace_id == "SetVelocity2D", true) and all_passed
	param_imported.external_source_path = "user://eventforge_lift_params_rt.gd"
	var param_roundtrip: String = str(SheetCompiler.compile(param_imported, "user://eventforge_lift_params_rt.gd").get("output", ""))
	all_passed = _check("captured params re-emit identically", param_roundtrip == param_source, true) and all_passed

	# Non-trigger functions never lift, and the file still round-trips byte-identically.
	var helper_source: String = "extends Node\n\nfunc helper() -> void:\n\tprint(\"hi\")\n"
	var helper_imported: EventSheetResource = GDScriptImporter.new().import_external_source(helper_source)
	var helper_lifted: bool = false
	for row in helper_imported.events:
		if row is EventRow:
			helper_lifted = true
	all_passed = _check("non-trigger functions stay verbatim blocks", helper_lifted, false) and all_passed
	helper_imported.external_source_path = "user://eventforge_lift_helper.gd"
	var helper_roundtrip: String = str(SheetCompiler.compile(helper_imported, "user://eventforge_lift_helper.gd").get("output", ""))
	all_passed = _check("unlifted files keep the byte-identical contract", helper_roundtrip == helper_source, true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_lift_test: %s" % label)
		return true
	print("[FAIL] ace_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
