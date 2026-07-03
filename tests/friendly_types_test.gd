@tool
class_name FriendlyTypesTest
extends RefCounted
# The variable dialog shows friendly type labels (Number / Text / Yes-No) that map to real Godot
# types, with a "Whole numbers only" tick splitting int vs float. The STORED type stays a real Godot
# type (so the .gd round-trip is unchanged) — only the dialog's display is friendlier. These pin the
# display ↔ stored-type mapping in both directions.


static func run() -> bool:
	var all_passed: bool = true
	var host: Node = Node.new()
	var dlg: VariableDialog = VariableDialog.new()
	dlg.init_dialog(host)

	# Display → stored: Number + whole-numbers tick → int; Number alone → float.
	dlg._select_stored_type("int")
	all_passed = _check("int → Number, whole-numbers ticked", dlg._selected_stored_type(), "int") and all_passed
	all_passed = _check("the whole-numbers tick is on for int", dlg._whole_numbers_check.button_pressed, true) and all_passed
	dlg._whole_numbers_check.button_pressed = false
	all_passed = _check("Number without the tick → float", dlg._selected_stored_type(), "float") and all_passed

	dlg._select_stored_type("String")
	all_passed = _check("Text → String", dlg._selected_stored_type(), "String") and all_passed
	dlg._select_stored_type("bool")
	all_passed = _check("Yes-No → bool", dlg._selected_stored_type(), "bool") and all_passed

	# Advanced Godot types stay literal (no friendly alias).
	dlg._select_stored_type("Vector2")
	all_passed = _check("advanced types stay literal", dlg._selected_stored_type(), "Vector2") and all_passed

	# Stored → display: editing an existing float var shows Number with the tick OFF.
	dlg.open_for_edit("global", {}, "speed", "float", "200.0", false, "Edit", false, false)
	all_passed = _check("editing a float shows the whole-numbers tick off", dlg._whole_numbers_check.button_pressed, false) and all_passed
	all_passed = _check("editing a float still stores float", dlg._selected_stored_type(), "float") and all_passed
	# ...and an existing int var shows Number with the tick ON.
	dlg.open_for_edit("global", {}, "score", "int", "0", false, "Edit", false, false)
	all_passed = _check("editing an int shows the whole-numbers tick on", dlg._whole_numbers_check.button_pressed, true) and all_passed

	host.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] friendly_types_test: %s" % label)
		return true
	print("[FAIL] friendly_types_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
