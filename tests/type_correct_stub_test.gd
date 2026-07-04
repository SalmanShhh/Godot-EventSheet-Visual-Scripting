# EventForge - the type-correct empty-body stub ("published before implemented"). A verb created in
# the ACE Studio starts with no body rows; the compiler used to emit `pass` for every such function,
# which only PARSES for void - one empty bool/typed verb made the whole generated script fail to load,
# taking every other verb on the sheet down with it. Each return type now stubs with its own default
# return, and the test's teeth: the full generated script must actually parse (GDScript.reload()).
@tool
class_name TypeCorrectStubTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.functions.append(_fn("do_thing", TYPE_NIL))
	sheet.functions.append(_fn("is_dead", TYPE_BOOL))
	sheet.functions.append(_fn("count_hits", TYPE_INT))
	sheet.functions.append(_fn("health_percent", TYPE_FLOAT))
	sheet.functions.append(_fn("label_text", TYPE_STRING))
	sheet.functions.append(_fn("aim_point", TYPE_VECTOR2))
	sheet.functions.append(_fn("anything", TYPE_MAX))

	var output: String = str(SheetCompiler.compile(sheet, "user://_stub_test_out.gd").get("output", ""))
	ok = _check("void keeps pass", output.contains("func do_thing() -> void:\n\tpass"), true) and ok
	ok = _check("bool returns false", output.contains("func is_dead() -> bool:\n\treturn false"), true) and ok
	ok = _check("int returns 0", output.contains("func count_hits() -> int:\n\treturn 0"), true) and ok
	ok = _check("float returns 0.0", output.contains("func health_percent() -> float:\n\treturn 0.0"), true) and ok
	ok = _check("String returns empty", output.contains("func label_text() -> String:\n\treturn \"\""), true) and ok
	ok = _check("Vector2 returns ZERO", output.contains("func aim_point() -> Vector2:\n\treturn Vector2.ZERO"), true) and ok
	ok = _check("Variant returns null", output.contains("func anything() -> Variant:\n\treturn null"), true) and ok

	# The teeth: the WHOLE generated script parses. With the old `pass` stubs this fails with
	# "Not all code paths return a value" on the first non-void function.
	var script: GDScript = GDScript.new()
	script.source_code = output
	ok = _check("the generated script actually parses", script.reload() == OK, true) and ok

	return ok


static func _fn(fn_name: String, return_type: int) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = fn_name
	event_function.return_type = return_type
	return event_function


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] type_correct_stub_test: %s" % label)
		return true
	print("[FAIL] type_correct_stub_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
