# EventForge — EventFunction.return_type_name: a function can declare a return type a Variant.Type
# can't name (a custom class, an engine class, a typed collection). The emitter uses it verbatim, the
# empty-body stub falls back to `return null` (valid for any object/collection), and the "Ships as:"
# signature formatter honours it — so a Studio-authored verb returning `-> Node2D` round-trips. The
# reverse AUTO-LIFT of such a helper stays OFF (a mid-file private helper would reorder the file and
# fail the byte-verify), so this pins the FORWARD primitive + the drift=0 baseline is unregressed.
@tool
extends RefCounted
class_name FunctionReturnTypeNameTest

static func run() -> bool:
	var ok: bool = true

	# ── The emitter uses the name verbatim, and it wins over return_type ──
	var custom: EventFunction = EventFunction.new()
	custom.function_name = "nearest_enemy"
	custom.return_type = TYPE_NIL          # would be "void"…
	custom.return_type_name = "Node2D"     # …but the name overrides it
	ok = _check("the return-type name wins over return_type", SheetCompiler._function_return_type_name(custom), "Node2D") and ok
	ok = _check("a bodiless custom-return function stubs `return null`", SheetCompiler._empty_function_stub(custom), "\treturn null") and ok
	ok = _check("the Ships-as signature honours it",
		EventSheetFunctionDialog.format_signature("nearest_enemy", TYPE_NIL, []).ends_with("-> void"), true) and ok

	# An empty name leaves the normal Variant.Type path untouched.
	var normal: EventFunction = EventFunction.new()
	normal.function_name = "is_dead"
	normal.return_type = TYPE_BOOL
	ok = _check("an empty name keeps the Variant.Type behaviour", SheetCompiler._function_return_type_name(normal), "bool") and ok

	# ── A sheet with a custom-return verb round-trips through the external path ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.tool_mode = true
	sheet.external_source_path = "user://_rtn_test.gd"
	var verb: EventFunction = EventFunction.new()
	verb.function_name = "make_pool"
	verb.return_type_name = "HealthPool"
	verb.expose_as_ace = true
	verb.ace_display_name = "Make Pool"
	sheet.functions.append(verb)
	var output: String = str(SheetCompiler.compile(sheet, "user://_rtn_test.gd").get("output", ""))
	ok = _check("the emitted signature carries the custom return", output.contains("func make_pool() -> HealthPool:"), true) and ok
	ok = _check("its empty body is `return null`", output.contains("func make_pool() -> HealthPool:\n\treturn null"), true) and ok
	# Re-import → re-emit must be byte-identical (the round-trip the covenant guarantees).
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	reopened.external_source_path = "user://_rtn_test.gd"
	var reemitted: String = str(SheetCompiler.compile(reopened, "user://_rtn_test.gd").get("output", ""))
	ok = _check("a custom-return verb round-trips byte-identically", reemitted == output, true) and ok

	# ── The whole generated script parses (custom class names don't break the load) ──
	var script: GDScript = GDScript.new()
	script.source_code = "class HealthPool:\n\tvar amount: float = 0.0\n\n" + output.substr(output.find("func make_pool"))
	ok = _check("the generated function parses with the custom class in scope", script.reload() == OK, true) and ok

	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_return_type_name_test: %s" % label)
		return true
	print("[FAIL] function_return_type_name_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
