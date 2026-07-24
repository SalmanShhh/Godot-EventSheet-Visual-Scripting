# EventForge - higher-order + typed-array ACE module ("Variables: Array").
# Proves the 9 descriptors are discovered with the right shapes, and that their ACTUAL shipped codegen
# templates (substituted through the real ActionCodegen) produce GDScript that behaves correctly:
# filter / map / reduce / any / all over the element `x`, and typed-array is_typed / assign / element type.
@tool
class_name ArrayFunctionalAcesTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var by_id: Dictionary = {}
	for d: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[d.ace_id] = d

	# --- Registry shape ---
	for aid: String in ["ArrayFilter", "ArrayMap", "ArrayReduce", "ArrayAny", "ArrayAll", "ArrayIsTyped", "ArrayAssign", "ArrayTypedBuiltin", "ArrayTypedClassName"]:
		ok = _check("%s registered" % aid, by_id.has(aid), true) and ok
	ok = _check("all group under Variables: Array",
		str(by_id["ArrayFilter"].category) == "Variables: Array" and str(by_id["ArrayIsTyped"].category) == "Variables: Array", true) and ok
	ok = _check("filter template names the element from a param (never a baked name that could shadow)",
		str(by_id["ArrayFilter"].codegen_template), "{var_name}.filter(func({element}): return {predicate})") and ok
	ok = _check("reduce template folds an accumulator over the element from a seed",
		str(by_id["ArrayReduce"].codegen_template), "{var_name}.reduce(func({accumulator}, {element}): return {expression}, {seed})") and ok
	ok = _check("the element name defaults to x (and the accumulator to acc)",
		str((by_id["ArrayFilter"].params[2] as ACEParam).default_value) == "x"
		and str((by_id["ArrayReduce"].params[4] as ACEParam).default_value) == "acc", true) and ok
	ok = _check("the array param carries the typed variable hint",
		str((by_id["ArrayFilter"].params[0] as ACEParam).hint), "variable_reference:Array") and ok
	ok = _check("filter/map/reduce are expressions, any/all conditions, assign an action",
		by_id["ArrayFilter"].ace_type == ACEDescriptor.ACEType.EXPRESSION
		and by_id["ArrayAny"].ace_type == ACEDescriptor.ACEType.CONDITION
		and by_id["ArrayAll"].ace_type == ACEDescriptor.ACEType.CONDITION
		and by_id["ArrayAssign"].ace_type == ACEDescriptor.ACEType.ACTION, true) and ok

	# --- Runtime: the SHIPPED templates, substituted through the real codegen, behave correctly ---
	var filter_line: String = ActionCodegen._apply_template(str(by_id["ArrayFilter"].codegen_template), {"var_name": "arr", "predicate": "x > 0", "element": "x"})
	var map_line: String = ActionCodegen._apply_template(str(by_id["ArrayMap"].codegen_template), {"var_name": "arr", "expression": "x * 2", "element": "x"})
	var reduce_line: String = ActionCodegen._apply_template(str(by_id["ArrayReduce"].codegen_template), {"var_name": "arr", "expression": "acc + x", "seed": "0", "element": "x", "accumulator": "acc"})
	var any_line: String = ActionCodegen._apply_template(str(by_id["ArrayAny"].codegen_template), {"var_name": "arr", "predicate": "x > 0", "element": "x"})
	var all_line: String = ActionCodegen._apply_template(str(by_id["ArrayAll"].codegen_template), {"var_name": "arr", "predicate": "x > 0", "element": "x"})
	# The escape hatch: renaming the element keeps a same-named sheet variable reachable in the body.
	var renamed_line: String = ActionCodegen._apply_template(str(by_id["ArrayFilter"].codegen_template), {"var_name": "arr", "predicate": "item > x", "element": "item"})
	ok = _check("renaming the element emits that name, leaving `x` free for the sheet variable",
		renamed_line, "arr.filter(func(item): return item > x)") and ok
	var assign_line: String = ActionCodegen._apply_template(str(by_id["ArrayAssign"].codegen_template), {"var_name": "typed", "source": "src"})
	var is_typed_line: String = ActionCodegen._apply_template(str(by_id["ArrayIsTyped"].codegen_template), {"var_name": "typed"})
	var typed_builtin_line: String = ActionCodegen._apply_template(str(by_id["ArrayTypedBuiltin"].codegen_template), {"var_name": "typed"})

	ok = _check("filter substitutes to plain GDScript", filter_line, "arr.filter(func(x): return x > 0)") and ok

	var src: String = "\n".join([
		"@tool",
		"extends RefCounted",
		"func f_filter(arr: Array) -> Array:",
		"\treturn %s" % filter_line,
		"func f_map(arr: Array) -> Array:",
		"\treturn %s" % map_line,
		"func f_reduce(arr: Array) -> int:",
		"\treturn %s" % reduce_line,
		"func f_any(arr: Array) -> bool:",
		"\treturn %s" % any_line,
		"func f_all(arr: Array) -> bool:",
		"\treturn %s" % all_line,
		"func f_typed() -> Array:",
		"\tvar typed: Array[int] = []",
		"\tvar src: Array = [1, 2, 3]",
		"\t%s" % assign_line,
		"\treturn [%s, %s, typed.size()]" % [is_typed_line, typed_builtin_line],
		"func f_renamed(arr: Array, x) -> Array:",
		"\treturn %s" % renamed_line,
		"",
	])  # NOTE the trailing "": a single-line lambda needs a terminating newline, so a script whose LAST
		# line is one fails to parse ("Expected end of file"). Real compiler output always has the newline.
	var script: GDScript = GDScript.new()
	script.source_code = src
	ok = _check("the assembled template script parses", script.reload() == OK, true) and ok
	var inst: RefCounted = script.new()
	ok = _check("filter keeps only x > 0", inst.f_filter([1, -2, 3, -4]), [1, 3]) and ok
	ok = _check("map doubles each x", inst.f_map([1, 2, 3]), [2, 4, 6]) and ok
	ok = _check("reduce sums from 0", inst.f_reduce([1, 2, 3, 4]), 10) and ok
	ok = _check("any is true when one matches", inst.f_any([-1, -2, 3]), true) and ok
	ok = _check("any is false when none match", inst.f_any([-1, -2]), false) and ok
	ok = _check("all is true when every element matches", inst.f_all([1, 2, 3]), true) and ok
	ok = _check("all is false when one fails", inst.f_all([1, -2, 3]), false) and ok
	ok = _check("assign fills a typed array (is_typed true, element type TYPE_INT, size 3)",
		inst.f_typed(), [true, TYPE_INT, 3]) and ok
	# With the element renamed to `item`, the outer `x` really is the surrounding variable, not the element.
	ok = _check("a renamed element leaves the same-named outer variable readable in the body",
		inst.f_renamed([1, 5, 9], 4), [5, 9]) and ok
	# Empty-array semantics are Godot's and are documented on the two conditions.
	ok = _check("any is false and all is true for an empty array",
		[inst.f_any([]), inst.f_all([])], [false, true]) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] array_functional_aces_test: %s" % label)
		return true
	print("[FAIL] array_functional_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
