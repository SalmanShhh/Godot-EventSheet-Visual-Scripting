# Godot EventSheets - inline colour-swatch picker (Construct-style).
#
# Clicking the colour swatch drawn on a condition/action cell opens a ColorPicker right there (no dialog)
# and writes the chosen colour back into the ACE's Color param. This pins the two pieces of logic the
# click path depends on: finding WHICH param holds the colour, and that the picked colour round-trips
# losslessly through color_to_literal (what the dock writes back).
@tool
class_name ColorSwatchPickerTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()

	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetModulateColor"
	action.params = {"target": "$Sprite2D", "color": "Color(1, 0, 0, 1)"}

	all_passed = _check("finds the Color param's key", viewport._first_color_param_id(action), "color") and all_passed
	var read_color: Variant = viewport._first_color_in_params(action)
	all_passed = _check("reads the swatch Color value",
		read_color is Color and (read_color as Color).is_equal_approx(Color(1, 0, 0, 1)), true) and all_passed

	var no_color: ACEAction = ACEAction.new()
	no_color.params = {"x": "5", "name": "\"hi\""}
	all_passed = _check("an ACE with no Color param yields an empty key",
		viewport._first_color_param_id(no_color), "") and all_passed

	# The picked colour must round-trip through color_to_literal -> str_to_var (write-back fidelity).
	var picked: Color = Color(0.25, 0.5, 0.75, 1.0)
	var literal: String = ACEParamsDialog.color_to_literal(picked)
	var parsed: Variant = str_to_var(literal)
	all_passed = _check("color_to_literal emits a Color(...) literal", literal.begins_with("Color("), true) and all_passed
	all_passed = _check("the written colour round-trips losslessly",
		parsed is Color and (parsed as Color).is_equal_approx(picked), true) and all_passed

	viewport.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] color_swatch_picker_test: %s" % label)
		return true
	print("[FAIL] color_swatch_picker_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
