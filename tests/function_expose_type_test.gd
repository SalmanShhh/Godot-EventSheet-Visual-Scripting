# EventForge — three-way function expose (C3-parity function system, spec §1).
#
# When a sheet function is exposed as an ACE, the directive follows its RETURN TYPE: a void function
# publishes as an action, a bool function as a condition, any other value as an expression. (One
# method maps to exactly one ACE — see ace_generator's one-definition-per-method — so it is one
# directive, not several.) The lifter recognizes all three so a published function round-trips; the
# exposed type is re-derived from the return type, so no extra state is stored. Existing packs expose
# only void functions, so this is byte-identical for them (verified separately by drift=0).
@tool
extends RefCounted
class_name FunctionExposeTypeTest

static func run() -> bool:
	var ok: bool = true

	# Emit: the directive follows the return type.
	ok = _check("void function exposes as an action", _expose_directive(TYPE_NIL), "## @ace_action") and ok
	ok = _check("bool function exposes as a condition", _expose_directive(TYPE_BOOL), "## @ace_condition") and ok
	ok = _check("int function exposes as an expression", _expose_directive(TYPE_INT), "## @ace_expression") and ok
	ok = _check("Vector2 function exposes as an expression", _expose_directive(TYPE_VECTOR2), "## @ace_expression") and ok

	# Lift: all three directives mark the function exposed (so a published function round-trips).
	ok = _check("lifter recognizes @ace_action", _lifts_exposed("## @ace_action"), true) and ok
	ok = _check("lifter recognizes @ace_condition", _lifts_exposed("## @ace_condition"), true) and ok
	ok = _check("lifter recognizes @ace_expression", _lifts_exposed("## @ace_expression"), true) and ok
	# A non-exposed function still lifts (hidden), and an unknown directive still rejects (falls back).
	ok = _check("an unknown directive rejects the block", EventSheetACELifter._parse_annotations("## @ace_bogus").is_empty(), true) and ok

	return ok

static func _expose_directive(return_type: int) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.custom_class_name = "TestBehavior"
	var fn: EventFunction = EventFunction.new()
	fn.function_name = "probe"
	fn.expose_as_ace = true
	fn.return_type = return_type
	var lines: PackedStringArray = PackedStringArray()
	SheetCompiler._emit_expose_annotations(fn, sheet, lines)
	return lines[0] if lines.size() > 0 else ""

static func _lifts_exposed(directive: String) -> bool:
	return bool(EventSheetACELifter._parse_annotations(directive).get("expose", false))

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_expose_type_test: %s" % label)
		return true
	print("[FAIL] function_expose_type_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
