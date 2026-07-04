# EventForge - the ACE Studio's "Ships as:" signature strip. EventSheetFunctionDialog.format_signature
# builds the exact generated func header from the SAME compiler formatters the codegen uses, so the
# preview can never disagree with what actually ships (the Godot-dev trust surface).
@tool
class_name ACEStudioSignatureTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	ok = _check("void action",
		EventSheetFunctionDialog.format_signature("take_damage", TYPE_NIL, [{"id": "amount", "type_name": "int"}]),
		"func take_damage(amount: int) -> void") and ok
	ok = _check("bool condition",
		EventSheetFunctionDialog.format_signature("is_dead", TYPE_BOOL, []),
		"func is_dead() -> bool") and ok
	ok = _check("float expression",
		EventSheetFunctionDialog.format_signature("health_percent", TYPE_FLOAT, []),
		"func health_percent() -> float") and ok
	ok = _check("typed param with a default",
		EventSheetFunctionDialog.format_signature("heal", TYPE_NIL, [{"id": "amount", "type_name": "int", "default": "10"}]),
		"func heal(amount: int = 10) -> void") and ok

	# The anti-lie guarantee: format_signature must equal what the compiler's own formatters emit for the
	# same function - so if it's ever reimplemented by hand this fails.
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "knock_back"
	event_function.return_type = TYPE_VECTOR2
	var param: ACEParam = ACEParam.new()
	param.id = "force"
	param.type_name = "float"
	event_function.params.append(param)
	var compiler_line: String = "func %s(%s) -> %s" % [
		event_function.function_name,
		SheetCompiler._emit_function_params(event_function),
		SheetCompiler._function_return_type_name(event_function),
	]
	ok = _check("matches the compiler formatters exactly",
		EventSheetFunctionDialog.format_signature("knock_back", TYPE_VECTOR2, [{"id": "force", "type_name": "float"}]),
		compiler_line) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_studio_signature_test: %s" % label)
		return true
	print("[FAIL] ace_studio_signature_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
