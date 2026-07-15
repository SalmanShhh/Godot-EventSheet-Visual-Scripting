# EventForge - the null / validity guard conditions (Is Valid, Is Null) that let you check a node or object
# reference before touching it, code-free, instead of dropping to a raw GDScript block. These ship in the
# Helpers vocabulary (helper_aces.gd). This pins their FROZEN public API - ace_id + codegen_template are
# compatibility promises once shipped (deprecate, never rename) - and that each template still compiles with
# a real value, so a future edit to the module cannot silently break the classic freed-instance crash guard.
@tool
class_name NullCheckAceTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var descriptors: Array[ACEDescriptor] = EventForgeBuiltinACEs.get_descriptors()
	var is_valid: ACEDescriptor = _find(descriptors, "IsValid")
	var is_null: ACEDescriptor = _find(descriptors, "IsNull")
	ok = _check("Is Valid condition is registered", is_valid != null, true) and ok
	ok = _check("Is Null condition is registered", is_null != null, true) and ok
	if is_valid == null or is_null == null:
		return false

	# Frozen API: ace_id + codegen_template are compatibility promises once shipped.
	ok = _check("Is Valid template is is_instance_valid({target})", is_valid.codegen_template, "is_instance_valid({target})") and ok
	ok = _check("Is Null template is {target} == null", is_null.codegen_template, "{target} == null") and ok
	ok = _check("Is Valid is a CONDITION", is_valid.ace_type, ACEDescriptor.ACEType.CONDITION) and ok
	ok = _check("Is Null is a CONDITION", is_null.ace_type, ACEDescriptor.ACEType.CONDITION) and ok
	ok = _check("Is Valid takes one `target` param", is_valid.params.size() == 1 and str((is_valid.params[0] as ACEParam).id) == "target", true) and ok
	ok = _check("Is Null takes one `target` param", is_null.params.size() == 1 and str((is_null.params[0] as ACEParam).id) == "target", true) and ok

	# Each template compiles with a real value substituted (a template typo would fail here, not in a game).
	ok = _check("Is Valid compiles guarding a node reference", _compiles(is_valid.codegen_template.replace("{target}", "$Player")), true) and ok
	ok = _check("Is Null compiles testing a variable", _compiles(is_null.codegen_template.replace("{target}", "target")), true) and ok

	return ok


static func _find(descriptors: Array, ace_id: String) -> ACEDescriptor:
	for d: Variant in descriptors:
		if d is ACEDescriptor and (d as ACEDescriptor).ace_id == ace_id:
			return d as ACEDescriptor
	return null


static func _compiles(condition_expr: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\n\nvar target: Variant = null\n\nfunc _t() -> void:\n\tif %s:\n\t\tpass\n" % condition_expr
	return script.reload() == OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] null_check_ace_test: %s" % label)
		return true
	print("[FAIL] null_check_ace_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
