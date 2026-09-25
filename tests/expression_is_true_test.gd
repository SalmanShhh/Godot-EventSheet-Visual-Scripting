# Godot EventSheets - the generic "Expression Is True" condition.
#
# The code-free escape hatch for a boolean expression: any GDScript that returns a bool can be a
# condition (e.g. a behavior method like $Player/WeaponKit.can_fire()) without dropping the row to a
# raw GDScript block. Pins: the descriptor is a condition whose template is the bare `{expr}`, so it
# compiles into a bare `if {expr}:` head.
@tool
class_name ExpressionIsTrueTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	# A modern, single-param condition.
	var descriptor: ACEDescriptor = null
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if d.ace_id == "ExpressionIsTrue":
			descriptor = d
			break
	# Whether it is registered at all is pinned by the GDScript-basics coverage receipt; a miss still
	# names this test rather than turning the suite red without a line.
	if descriptor == null:
		return _check("ExpressionIsTrue is registered", false, true)
	ok = _check("template is {expr}", str(descriptor.codegen_template), "{expr}") and ok
	ok = _check("is a CONDITION", descriptor.ace_type == ACEDescriptor.ACEType.CONDITION, true) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("expression_is_true_test", label, actual, expected)
