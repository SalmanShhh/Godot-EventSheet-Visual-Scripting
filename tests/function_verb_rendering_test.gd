# Godot EventSheets — function calls render as first-class named VERBS (show abstraction level).
#
# A Call to a sheet Function is an abstraction you created (e.g. via Extract to Function), not just another
# action. The renderer marks it with a "ƒ" object chip and shows the verb's friendly name ("Apply Physics")
# instead of the generic "System → Call apply_physics()". This pins that legibility treatment.
@tool
class_name FunctionVerbRenderingTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var function: EventFunction = EventFunction.new()
	function.function_name = "apply_physics"
	function.ace_display_name = "Apply Physics"
	sheet.functions.append(function)
	viewport._sheet = sheet

	# A function call gets the "ƒ" object chip (a named verb), not the generic "System".
	all_passed = _check("function-call object chip is ƒ",
		viewport._object_label_for("Core", "CallFunction"), "ƒ") and all_passed

	# A no-arg call to a known Function reads as its friendly display name.
	var call_known: ACEAction = _call_action("apply_physics", "")
	all_passed = _check("known function renders its friendly verb name",
		viewport._function_call_label(call_known), "Apply Physics") and all_passed
	all_passed = _check("the action descriptor shows the verb, not Call name()",
		viewport._format_action_descriptor_base(call_known), "Apply Physics") and all_passed

	# An unknown function humanizes its name; args are appended only when the call passes them.
	var call_unknown: ACEAction = _call_action("do_stuff", "1, 2")
	all_passed = _check("unknown function humanizes + appends args",
		viewport._function_call_label(call_unknown), "Do Stuff(1, 2)") and all_passed

	# A non-function-call action is untouched (still goes through the normal descriptor path).
	var plain: ACEAction = ACEAction.new()
	plain.provider_id = "Core"
	plain.ace_id = "AddVar"
	plain.codegen_template = "score += 1"
	all_passed = _check("a plain action is NOT treated as a function call",
		viewport._is_function_call_action(plain), false) and all_passed

	viewport.free()
	return all_passed


static func _call_action(fn_name: String, args: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "CallFunction"
	action.codegen_template = "{function_name}({args})"
	action.params = {"function_name": fn_name, "args": args}
	return action


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_verb_rendering_test: %s" % label)
		return true
	print("[FAIL] function_verb_rendering_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
