# EventForge - Phase 0 authoring ACEs (near-zero-RawCode roadmap): compound-assign (-=/*=//), type
# checks (is / typeof), and the @onready var declaration row. These were the highest-frequency
# raw-block triggers in hand-written behaviours; this pins their templates + emission.
@tool
class_name Phase0AuthoringAcesTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# Compound assigns - the -= / *= / /= siblings to Add Variable.
	ok = _action("SubtractVar", {"var_name": "hp", "amount": "1"}, "hp -= 1") and ok
	ok = _action("MultiplyVar", {"var_name": "x", "amount": "2"}, "x *= 2") and ok
	ok = _action("DivideVar", {"var_name": "y", "amount": "3"}, "y /= 3") and ok

	# Type-of expression.
	ok = _action("TypeOf", {"value": "v"}, "typeof(v)") and ok  # expression (template resolution is shared)

	# @onready var emits the deferred declaration with a VERBATIM expression default (not a string).
	var onready_var: LocalVariable = LocalVariable.new()
	onready_var.name = "sprite"
	onready_var.type_name = "Sprite2D"
	onready_var.onready = true
	onready_var.default_value = "$Sprite2D"
	ok = _check("@onready var emits the deferred form with a verbatim node ref",
		SheetCompiler._emit_tree_variable_line(onready_var), "@onready var sprite: Sprite2D = $Sprite2D") and ok

	return ok


static func _action(ace_id: String, params: Dictionary, expected: String) -> bool:
	var a: ACEAction = ACEAction.new()
	a.provider_id = "Core"
	a.ace_id = ace_id
	a.enabled = true
	a.params = params
	return _check(ace_id, ActionCodegen.generate_action(a, "", ""), expected)


static func _condition(ace_id: String, params: Dictionary, expected: String) -> bool:
	var c: ACECondition = ACECondition.new()
	c.provider_id = "Core"
	c.ace_id = ace_id
	c.enabled = true
	c.params = params
	return _check(ace_id, ConditionCodegen.generate_condition(c, ""), expected)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] phase0_authoring_aces_test: %s" % label)
		return true
	print("[FAIL] phase0_authoring_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
