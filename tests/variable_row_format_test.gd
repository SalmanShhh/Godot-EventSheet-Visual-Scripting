# EventForge — VariableRowUI format_summary tests
# Validates that format_summary produces correct display strings for all common types.
@tool
extends RefCounted
class_name VariableRowFormatTest

## Runs all format_summary test cases. Returns true if all pass.
static func run() -> bool:
	var all_passed: bool = true

	all_passed = _check("int default",
		VariableRowUI.format_summary("health", {"type": "int", "default": 100}),
		"health (int) = 100"
	) and all_passed

	all_passed = _check("String default",
		VariableRowUI.format_summary("player_name", {"type": "String", "default": "Player"}),
		'player_name (String) = "Player"'
	) and all_passed

	all_passed = _check("pre-quoted String default",
		VariableRowUI.format_summary("msg", {"type": "String", "default": '"Hello"'}),
		'msg (String) = "Hello"'
	) and all_passed

	all_passed = _check("embedded quote String default",
		VariableRowUI.format_summary("msg", {"type": "String", "default": 'say "hi"'}),
		'msg (String) = "say \\"hi\\""'
	) and all_passed

	all_passed = _check("float default",
		VariableRowUI.format_summary("speed", {"type": "float", "default": 200.0}),
		"speed (float) = 200.0"
	) and all_passed

	all_passed = _check("bool default",
		VariableRowUI.format_summary("active", {"type": "bool", "default": true}),
		"active (bool) = true"
	) and all_passed

	all_passed = _check("null default",
		VariableRowUI.format_summary("thing", {"type": "Variant", "default": null}),
		"thing (Variant) = null"
	) and all_passed

	all_passed = _check("missing default key",
		VariableRowUI.format_summary("count", {"type": "int"}),
		"count (int) = null"
	) and all_passed

	all_passed = _check("value key fallback",
		VariableRowUI.format_summary("x", {"type": "float", "value": 1.5}),
		"x (float) = 1.5"
	) and all_passed

	all_passed = _check("missing type key",
		VariableRowUI.format_summary("n", {"default": 42}),
		"n (Variant) = 42"
	) and all_passed

	all_passed = _check("tooltip with description",
		VariableRowUI.format_tooltip("health", {"type": "int", "default": 100, "description": "Current HP"}),
		"health (int)\nDefault: 100\n\nCurrent HP"
	) and all_passed

	all_passed = _check("tooltip without description",
		VariableRowUI.format_tooltip("speed", {"type": "float", "default": 5.0}),
		"speed (float)\nDefault: 5.0"
	) and all_passed

	return all_passed

static func _check(label: String, actual: String, expected: String) -> bool:
	if actual == expected:
		print("[PASS] variable_row_format_test: %s" % label)
		return true
	else:
		print("[FAIL] variable_row_format_test: %s" % label)
		print("  expected: %s" % expected)
		print("  actual:   %s" % actual)
		return false
