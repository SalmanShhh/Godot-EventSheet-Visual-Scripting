# Godot EventSheets — the generic "Expression Is True" condition.
#
# The code-free escape hatch for a boolean expression: any GDScript that returns a bool can be a
# condition (e.g. a behavior method like $Player/WeaponKit.can_fire()) without dropping the row to a
# raw GDScript block. Pins: the descriptor is registered, compiles into a bare `if {expr}:` head, and
# inverts to `not (...)`.
@tool
extends RefCounted
class_name ExpressionIsTrueTest

static func run() -> bool:
	var ok: bool = true

	# Registered, modern, single-param condition.
	var descriptor: ACEDescriptor = null
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if d.ace_id == "ExpressionIsTrue":
			descriptor = d
			break
	ok = _check("ExpressionIsTrue is registered", descriptor != null, true) and ok
	if descriptor == null:
		return ok
	ok = _check("template is {expr}", str(descriptor.codegen_template), "{expr}") and ok
	ok = _check("is a CONDITION", descriptor.ace_type == ACEDescriptor.ACEType.CONDITION, true) and ok

	# Compiles into a bare if-head (template set explicitly so the test does not depend on registry order).
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var cond: ACECondition = ACECondition.new()
	cond.provider_id = "Core"
	cond.ace_id = "ExpressionIsTrue"
	cond.codegen_template = "{expr}"
	cond.params = {"expr": "$Player/WeaponKit.can_fire()"}
	event.conditions.append(cond)
	var log_action: ACEAction = ACEAction.new()
	log_action.provider_id = "Core"
	log_action.ace_id = "PrintLog"
	log_action.codegen_template = "print({message})"
	log_action.params = {"message": "\"fire\""}
	event.actions.append(log_action)
	sheet.events.append(event)
	var out: String = str(SheetCompiler.compile(sheet, "user://eventsheets_expr_true.gd").get("output", ""))
	ok = _check("compiles into `if $Player/WeaponKit.can_fire():`", out.contains("if $Player/WeaponKit.can_fire():"), true) and ok

	# Inversion wraps the expression in not (...).
	cond.negated = true
	var out2: String = str(SheetCompiler.compile(sheet, "user://eventsheets_expr_true2.gd").get("output", ""))
	ok = _check("negated wraps not (...)", out2.contains("not ($Player/WeaponKit.can_fire())"), true) and ok

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] expression_is_true_test: %s" % label)
		return true
	print("[FAIL] expression_is_true_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
