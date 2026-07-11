# Godot EventSheets - Input helper vocabulary + the live Input Map picker.
#
# Pins the new Mouse/Keyboard/InputMap/Gamepad ACEs (present, unique ids - the duplicate-id trap
# has bitten before), the "input_action" hint on every existing-action parameter (what routes the
# params dialog to the LIVE Input Map combo instead of the stale options snapshot), and the
# picker's enumeration itself (quoted literals, ui_* built-ins always present). Template
# compilability is covered by builtin_ace_compile_test automatically.
@tool
class_name InputHelpersTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var descriptors: Array[ACEDescriptor] = EventForgeBuiltinACEs.get_descriptors()
	var by_id: Dictionary = {}
	var duplicate_ids: Array[String] = []
	for descriptor: ACEDescriptor in descriptors:
		if by_id.has(descriptor.ace_id):
			duplicate_ids.append(descriptor.ace_id)
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("no duplicate ace ids across all builtin modules", duplicate_ids, [] as Array[String]) and all_passed

	# The new vocabulary exists, in the right category, as the right kind.
	var expected: Dictionary = {
		"WarpMouse": ["Mouse", ACEDescriptor.ACEType.ACTION],
		"GetMouseVelocity": ["Mouse", ACEDescriptor.ACEType.EXPRESSION],
		"IsMouseCaptured": ["Mouse", ACEDescriptor.ACEType.CONDITION],
		"MouseButtonEventPressed": ["Mouse", ACEDescriptor.ACEType.CONDITION],
		"MouseButtonEventReleased": ["Mouse", ACEDescriptor.ACEType.CONDITION],
		"MouseWheelUpEvent": ["Mouse", ACEDescriptor.ACEType.CONDITION],
		"MouseWheelDownEvent": ["Mouse", ACEDescriptor.ACEType.CONDITION],
		"SetCustomCursor": ["Mouse", ACEDescriptor.ACEType.ACTION],
		"ClearCustomCursor": ["Mouse", ACEDescriptor.ACEType.ACTION],
		"IsAnythingPressed": ["Keyboard", ACEDescriptor.ACEType.CONDITION],
		"KeyName": ["Keyboard", ACEDescriptor.ACEType.EXPRESSION],
		"KeycodeFromName": ["Keyboard", ACEDescriptor.ACEType.EXPRESSION],
		"GamepadCount": ["Gamepad", ACEDescriptor.ACEType.EXPRESSION],
		"GamepadName": ["Gamepad", ACEDescriptor.ACEType.EXPRESSION],
		"GamepadIsKnown": ["Gamepad", ACEDescriptor.ACEType.CONDITION],
		"JoyButtonEventPressed": ["Gamepad", ACEDescriptor.ACEType.CONDITION],
		"InputRemoveAction": ["Input", ACEDescriptor.ACEType.ACTION],
		"InputRebindToMouseButton": ["Input", ACEDescriptor.ACEType.ACTION],
		"InputRebindToJoyButton": ["Input", ACEDescriptor.ACEType.ACTION],
		"InputSetDeadzone": ["Input", ACEDescriptor.ACEType.ACTION],
		"InputBindingText": ["Input", ACEDescriptor.ACEType.EXPRESSION],
		"InputActionsList": ["Input", ACEDescriptor.ACEType.EXPRESSION],
		"InputLoadDefaults": ["Input", ACEDescriptor.ACEType.ACTION],
	}
	for ace_id: String in expected:
		var descriptor: ACEDescriptor = by_id.get(ace_id)
		if descriptor == null:
			all_passed = _check("ace %s exists" % ace_id, false, true) and all_passed
			continue
		all_passed = _check("%s category" % ace_id, descriptor.category, (expected[ace_id] as Array)[0]) and all_passed
		all_passed = _check("%s kind" % ace_id, descriptor.ace_type, (expected[ace_id] as Array)[1]) and all_passed

	# Exact templates for the load-bearing new verbs (emitted-shape pins).
	all_passed = _check("InputLoadDefaults template", (by_id["InputLoadDefaults"] as ACEDescriptor).codegen_template, "InputMap.load_from_project_settings()") and all_passed
	all_passed = _check("WarpMouse template", (by_id["WarpMouse"] as ACEDescriptor).codegen_template, "Input.warp_mouse({position})") and all_passed
	all_passed = _check("InputSetDeadzone template", (by_id["InputSetDeadzone"] as ACEDescriptor).codegen_template, "InputMap.action_set_deadzone({action}, {deadzone})") and all_passed

	# Every existing-action parameter routes to the live Input Map picker via its hint.
	for hinted_id: String in ["IsActionPressed", "IsActionJustPressed", "IsActionJustReleased", "InputActionStrength", "InputMoveVector", "InputMoveAxis", "InputRebindToKey", "InputHasAction", "ActionAddEvent", "ActionEraseEvents", "InputRemoveAction", "InputBindingText"]:
		var hinted: ACEDescriptor = by_id.get(hinted_id)
		if hinted == null:
			all_passed = _check("hinted ace %s exists" % hinted_id, false, true) and all_passed
			continue
		var action_hints: Array[String] = []
		for parameter: ACEParam in hinted.params:
			if parameter.id in ["action", "left", "right", "up", "down", "negative", "positive"]:
				action_hints.append(parameter.hint)
		all_passed = _check("%s action param(s) carry the input_action hint" % hinted_id,
			not action_hints.is_empty() and action_hints.count("input_action") == action_hints.size(), true) and all_passed

	# InputAddAction names a NEW action - it must NOT be locked to the existing-actions picker.
	all_passed = _check("InputAddAction keeps a free-text action param",
		((by_id["InputAddAction"] as ACEDescriptor).params[0] as ACEParam).hint, "expression") and all_passed

	# The live picker enumeration: quoted literals, ui_* built-ins always offered.
	var choices: Array = ACEParamsDialog.input_action_choices()
	all_passed = _check("choices include ui_accept", choices.has("\"ui_accept\""), true) and all_passed
	all_passed = _check("choices include ui_left", choices.has("\"ui_left\""), true) and all_passed
	var all_quoted: bool = true
	for choice: Variant in choices:
		if not (str(choice).begins_with("\"") and str(choice).ends_with("\"")):
			all_quoted = false
	all_passed = _check("every choice is a quoted literal (template-ready)", all_quoted, true) and all_passed
	all_passed = _check("no duplicate choices", choices.size(), _unique_count(choices)) and all_passed

	return all_passed


static func _unique_count(values: Array) -> int:
	var seen: Dictionary = {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] input_helpers_test: %s" % label)
		return true
	print("[FAIL] input_helpers_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
