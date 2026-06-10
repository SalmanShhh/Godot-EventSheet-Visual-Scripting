# EventForge — ACE params dialog logic
#
# Verifies the pure (non-GUI) logic of ACEParamsDialog: expression-template substitution,
# variable-name resolution, back/re-edit flags, and hint text. The dialog form itself needs
# a display server and is verified by opening the editor.
@tool
extends RefCounted
class_name ACEParamsLogicTest

static func run() -> bool:
	var all_passed: bool = true
	var dialog: ACEParamsDialog = ACEParamsDialog.new()

	# Expression template: codegen template with default params substituted.
	var expr: ACEDefinition = ACEDefinition.new()
	expr.metadata = {"codegen_template": "move_to({target}, {speed})"}
	expr.parameters = [
		{"id": "target", "default_value": "Vector2.ZERO"},
		{"id": "speed", "default_value": "100"}
	]
	all_passed = _check("expression template fills named params", dialog._expression_template(expr), "move_to(Vector2.ZERO, 100)") and all_passed

	# Expression template: no codegen -> falls back to display.
	var expr2: ACEDefinition = ACEDefinition.new()
	expr2.display_name = "Health"
	expr2.metadata = {}
	all_passed = _check("expression template falls back to display name", dialog._expression_template(expr2), "Health") and all_passed

	# Variable-name resolution via provider callable.
	dialog._variable_names_provider = func() -> Array: return ["hp", "speed"]
	all_passed = _check("variable provider resolves names", dialog._resolve_variable_names(), PackedStringArray(["hp", "speed"])) and all_passed
	dialog._variable_names_provider = Callable()
	all_passed = _check("missing provider yields empty names", dialog._resolve_variable_names(), PackedStringArray()) and all_passed

	# Back/re-edit flags.
	dialog._context = {"from_picker": true}
	all_passed = _check("from_picker context shows back", dialog._came_from_picker(), true) and all_passed
	dialog._context = {}
	all_passed = _check("no flag hides back", dialog._came_from_picker(), false) and all_passed
	dialog._context = {"mode": "replace_condition"}
	all_passed = _check("replace mode is re-edit", dialog._is_reedit_flow(), true) and all_passed
	dialog._context = {"mode": "append_action"}
	all_passed = _check("append mode is not re-edit", dialog._is_reedit_flow(), false) and all_passed

	# Hint text: blocked apply explains the missing-variable situation.
	dialog._apply_blocked = true
	all_passed = _check("blocked hint mentions adding a variable", dialog._build_hint_text().to_lower().contains("add a variable"), true) and all_passed
	dialog._apply_blocked = false
	dialog._context = {"mode": "append_action"}
	all_passed = _check("append_action hint", dialog._build_hint_text().begins_with("Adding an action"), true) and all_passed

	# Bool parsing (static helper used by checkbox fields).
	all_passed = _check("parse bool true", ACEParamsDialog._parse_bool("true"), true) and all_passed
	all_passed = _check("parse bool false", ACEParamsDialog._parse_bool("nope"), false) and all_passed

	# Value extraction from a LineEdit field.
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = "hello"
	all_passed = _check("extract LineEdit value", dialog._extract_value(line_edit), "hello") and all_passed
	line_edit.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_params_logic_test: %s" % label)
		return true
	print("[FAIL] ace_params_logic_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
