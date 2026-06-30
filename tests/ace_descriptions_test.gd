# Godot EventSheets — built-in ACE descriptions (hover help).
#
# Every built-in ACE authors its plain-language description INLINE, chained on its make_descriptor call via
# .described("..."), so the help lives in the same file as the ACE — exactly how a custom behaviour addon
# would author it. This test ENFORCES full coverage (0 blank): a new built-in without a .described(...) call
# fails here, so authors can't ship an undescribed ACE. It also pins that the registry exposes the
# description, the viewport resolves it for hover, and a Call-Function row shows the function's own.
@tool
extends RefCounted
class_name AceDescriptionsTest

static func run() -> bool:
	var all_passed: bool = true

	# Every built-in descriptor has a non-empty description (full coverage of the generated map).
	var blank: int = 0
	var total: int = 0
	for descriptor: Variant in EventForgeBuiltinACEs.get_descriptors():
		if descriptor is ACEDescriptor:
			total += 1
			if str((descriptor as ACEDescriptor).description).strip_edges().is_empty():
				blank += 1
	all_passed = _check("every built-in ACE has a description (0 blank of %d)" % total, blank, 0) and all_passed

	# The registry exposes the description on a known built-in.
	var add_child: ACEDescriptor = ACERegistry.find_descriptor("Core", "AddChild")
	all_passed = _check("registry exposes a built-in's description",
		add_child != null and not str(add_child.description).strip_edges().is_empty(), true) and all_passed

	# The viewport resolves an ACE's description (the hover source).
	var viewport: EventSheetViewport = EventSheetViewport.new()
	all_passed = _check("viewport resolves a built-in ACE description",
		not viewport._tooltip_helper.ace_description("Core", "AddChild").strip_edges().is_empty(), true) and all_passed

	# A Call-Function row shows the targeted Function's own description.
	var sheet: EventSheetResource = EventSheetResource.new()
	var function: EventFunction = EventFunction.new()
	function.function_name = "apply_physics"
	function.description = "Applies gravity and friction to the body."
	sheet.functions.append(function)
	viewport._sheet = sheet
	var call: ACEAction = ACEAction.new()
	call.provider_id = "Core"
	call.ace_id = "CallFunction"
	call.params = {"function_name": "apply_physics", "args": ""}
	all_passed = _check("a function-call hover shows the function's description",
		viewport._tooltip_helper.function_call_description(call), "Applies gravity and friction to the body.") and all_passed
	viewport.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_descriptions_test: %s" % label)
		return true
	print("[FAIL] ace_descriptions_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
