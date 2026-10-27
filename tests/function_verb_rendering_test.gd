# Godot EventSheets - function calls render as first-class named VERBS (show abstraction level).
#
# A Call to a sheet Function is an abstraction you created (e.g. via Extract to Function), not just another
# action. It reads under the object that owns the function and shows the verb's friendly name
# ("Player | Apply Physics") instead of the generic "System → Call apply_physics()". This pins that.
@tool
class_name FunctionVerbRenderingTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var function: EventFunction = EventFunction.new()
	function.function_name = "apply_physics"
	function.ace_display_name = "Apply Physics"
	sheet.functions.append(function)
	viewport._sheet = sheet

	# A function call reads under the object that owns the function, not the generic "System" -
	# and "Functions" only where the sheet names no object of its own.
	all_passed = _check("a sheet with no object of its own files the call under Functions",
		viewport._row_builder._object_label_for("Core", "CallFunction"), "Functions") and all_passed
	var named: EventSheetResource = sheet.duplicate()
	named.custom_class_name = "Player"
	viewport._sheet = named
	all_passed = _check("a call to the sheet's own function reads under the sheet's own object",
		viewport._row_builder._object_label_for("Core", "CallFunction"), "Player") and all_passed
	viewport._sheet = sheet

	# A call to a known Function reads as its name - the name is the verb, so no "Call" leads it.
	# What this has always guarded against is the RAW form leaking into the cell (`apply_physics()`
	# - a code name and a pair of parentheses); that still holds, and the verb is the display name.
	var call_known: ACEAction = _call_action("apply_physics", "")
	all_passed = _check("known function renders its friendly verb name",
		viewport._function_call_label(call_known), "Apply Physics") and all_passed
	all_passed = _check("the action descriptor shows the verb, not the raw name()",
		viewport._row_builder._format_action_descriptor_base(call_known), "Apply Physics") and all_passed
	all_passed = _check("the raw function name never reaches the cell",
		viewport._function_call_label(call_known).contains("apply_physics"), false) and all_passed

	# An unknown function keeps its name as written; args are appended only when the call passes them.
	var call_unknown: ACEAction = _call_action("do_stuff", "1, 2")
	all_passed = _check("unknown function keeps its name + appends args",
		viewport._function_call_label(call_unknown), "do_stuff(1, 2)") and all_passed

	# A non-function-call action is untouched (still goes through the normal descriptor path).
	var plain: ACEAction = ACEAction.new()
	plain.provider_id = "Core"
	plain.ace_id = "AddVar"
	plain.codegen_template = "score += 1"
	all_passed = _check("a plain action is NOT treated as a function call",
		viewport._row_builder._is_function_call_action(plain), false) and all_passed

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
	return SUPPORT.check("function_verb_rendering_test", label, actual, expected)
