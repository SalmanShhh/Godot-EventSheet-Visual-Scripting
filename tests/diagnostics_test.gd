# EventSheet — row-level diagnostics (the "error → row" deep-link analyzer).
#
# Verifies EventSheetDiagnostics.analyze: invalid inline GDScript blocks and bad ƒx expression
# params are flagged on the offending resource (so the editor can jump to + mark the row), and
# clean sheets stay quiet. Pure/headless — no display server needed.
@tool
class_name DiagnosticsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# A class-level GDScript block that doesn't compile is flagged on that block (registry-free).
	var sheet: EventSheetResource = EventSheetResource.new()
	var good_block: RawCodeRow = RawCodeRow.new()
	good_block.code = "var compiles_fine := 1"
	var bad_block: RawCodeRow = RawCodeRow.new()
	bad_block.code = "this is not valid gdscript ((("
	sheet.events.append(good_block)
	sheet.events.append(bad_block)
	var diagnostics: Array = EventSheetDiagnostics.analyze(sheet, null)
	all_passed = _check("exactly the invalid block is flagged", diagnostics.size(), 1) and all_passed
	if diagnostics.size() == 1:
		all_passed = _check("diagnostic targets the bad block's instance id",
			str((diagnostics[0] as Dictionary).get("uid", "")), str(bad_block.get_instance_id())) and all_passed
		all_passed = _check("message names the GDScript block",
			str((diagnostics[0] as Dictionary).get("message", "")).contains("GDScript block"), true) and all_passed

	# A sheet whose blocks all compile yields nothing.
	var clean: EventSheetResource = EventSheetResource.new()
	var clean_block: RawCodeRow = RawCodeRow.new()
	clean_block.code = "var y := 2"
	clean.events.append(clean_block)
	all_passed = _check("a clean sheet has no diagnostics", EventSheetDiagnostics.analyze(clean, null).is_empty(), true) and all_passed

	# Without a registry, ƒx params are skipped (no false positives, still headless-safe).
	var fx_sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var cond: ACECondition = ACECondition.new()
	cond.provider_id = "Core"
	cond.ace_id = "EvaluateGDScript"
	cond.params = {"code": "(1 + "}
	event.conditions.append(cond)
	fx_sheet.events.append(event)
	all_passed = _check("ƒx params are skipped without a registry", EventSheetDiagnostics.analyze(fx_sheet, null).is_empty(), true) and all_passed

	# With the registry, a broken ƒx expression flags its OWNING event row.
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	var no_sources: Array[Object] = []
	registry.refresh_from_sources(no_sources, true)
	var fx_diag: Array = EventSheetDiagnostics.analyze(fx_sheet, registry)
	all_passed = _check("a broken ƒx expression is flagged", fx_diag.size(), 1) and all_passed
	if fx_diag.size() == 1:
		all_passed = _check("ƒx diagnostic targets the owning event row",
			str((fx_diag[0] as Dictionary).get("uid", "")), str(event.get_instance_id())) and all_passed

	# A valid ƒx expression on the same ACE is clean (no false positive on good code).
	cond.params = {"code": "true"}
	all_passed = _check("a valid ƒx expression is clean", EventSheetDiagnostics.analyze(fx_sheet, registry).is_empty(), true) and all_passed

	# A local variable whose name shadows a host-class member is flagged on that variable (#4).
	var shadow_sheet: EventSheetResource = EventSheetResource.new()
	shadow_sheet.host_class = "Node2D"
	var shadow_var: LocalVariable = LocalVariable.new()
	shadow_var.name = "position"
	shadow_var.type_name = "Vector2"
	shadow_sheet.events.append(shadow_var)
	var shadow_diag: Array = EventSheetDiagnostics.analyze(shadow_sheet, null)
	all_passed = _check("a shadowing local variable is flagged", shadow_diag.size(), 1) and all_passed
	if shadow_diag.size() == 1:
		all_passed = _check("shadow diagnostic targets the variable",
			str((shadow_diag[0] as Dictionary).get("uid", "")), str(shadow_var.get_instance_id())) and all_passed
		all_passed = _check("shadow message names the owner class",
			str((shadow_diag[0] as Dictionary).get("message", "")).contains("Node2D"), true) and all_passed
	shadow_var.name = "my_custom_thing"
	all_passed = _check("a non-shadowing local variable is clean", EventSheetDiagnostics.analyze(shadow_sheet, null).is_empty(), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] diagnostics_test: %s" % label)
		return true
	print("[FAIL] diagnostics_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
