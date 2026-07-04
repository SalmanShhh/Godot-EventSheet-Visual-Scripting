# Godot EventSheets - ACE deprecation (the compatibility covenant).
#
# A deprecated ACE keeps compiling so existing sheets never break, but it's hidden from the picker (can't be
# added anew), flagged on hover with its replacement, and warned about at compile time. This pins the whole
# chain: the .deprecated() data model, propagation to ACEDefinition.metadata (adapter for built-ins,
# generator for custom @ace_deprecated addons), the compile-time warning, and the hover prefix.
@tool
class_name AceDeprecationTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# 1. Data model - .deprecated() chains and sets the fields; deprecation_note() reads cleanly.
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	var returned: ACEDescriptor = descriptor.deprecated("Move Toward is smoother.", "Core::MoveToward")
	all_passed = _check(".deprecated() returns self (chainable)", returned == descriptor, true) and all_passed
	all_passed = _check(".deprecated() sets is_deprecated", descriptor.is_deprecated, true) and all_passed
	all_passed = _check("deprecation_note() combines message + replacement",
		descriptor.deprecation_note(),
		"(Deprecated) Move Toward is smoother. Use Core::MoveToward instead.") and all_passed
	all_passed = _check("a non-deprecated descriptor has an empty note",
		ACEDescriptor.new().deprecation_note(), "") and all_passed

	# 2. Adapter - deprecation flows into ACEDefinition.metadata (the picker + hover input).
	var definition: ACEDefinition = EventSheetACEAdapter.from_eventforge_descriptor(descriptor)
	all_passed = _check("adapter carries the deprecated flag", bool(definition.metadata.get("deprecated", false)), true) and all_passed
	all_passed = _check("adapter carries the deprecation note",
		str(definition.metadata.get("deprecation_note", "")).begins_with("(Deprecated)"), true) and all_passed

	# 3. Generator - a custom addon's @ace_deprecated override sets the same metadata.
	var custom: ACEDefinition = ACEDefinition.new()
	EventSheetACEGenerator._apply_deprecation_metadata(custom, {"deprecated": true, "deprecation_message": "Use knock_back() instead."})
	all_passed = _check("generator marks a custom ACE deprecated", bool(custom.metadata.get("deprecated", false)), true) and all_passed
	all_passed = _check("generator note includes the message",
		str(custom.metadata.get("deprecation_note", "")), "(Deprecated) Use knock_back() instead.") and all_passed

	# 4 + 5. Registry-backed paths: temporarily deprecate a real built-in to exercise the compile warning
	#        and the viewport hover, then restore the cache so later tests see the clean built-ins.
	ACERegistry.clear_cache()
	var victim: ACEDescriptor = ACERegistry.find_descriptor("Core", "PrintLog")
	if victim != null:
		victim.deprecated("", "Core::Log")
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "PrintLog"
		var row: EventRow = EventRow.new()
		row.actions.append(action)
		var warnings: Array = []
		SheetCompiler._collect_deprecated_aces([row], warnings, {})
		all_passed = _check("compiler warns once for a used deprecated ACE", warnings.size(), 1) and all_passed
		if warnings.size() == 1:
			all_passed = _check("the warning names the ACE + its replacement",
				str(warnings[0]).contains("Print Log") and str(warnings[0]).contains("Core::Log"), true) and all_passed
		var viewport: EventSheetViewport = EventSheetViewport.new()
		all_passed = _check("hover description is prefixed (Deprecated)",
			viewport._tooltip_helper.ace_description("Core", "PrintLog").begins_with("(Deprecated)"), true) and all_passed
		viewport.free()
	else:
		all_passed = _check("found Core::PrintLog to deprecate for the test", false, true) and all_passed
	ACERegistry.clear_cache()  # restore: the next access rebuilds fresh, non-deprecated descriptors

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_deprecation_test: %s" % label)
		return true
	print("[FAIL] ace_deprecation_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
