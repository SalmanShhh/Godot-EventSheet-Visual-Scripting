# EventForge - Sheet functions (compiler emission + call-as-action)
#
# Verifies that EventFunction resources compile to GDScript methods and that the built-in
# "Call Function" action emits a call. Headless-safe (compiler only).
@tool
class_name SheetFunctionTest
extends RefCounted

const OUTPUT_PATH := "user://eventforge_sheet_function_test.gd"


static func run() -> bool:
	var all_passed: bool = true

	# A sheet with one function `do_thing(amount: int)` whose body prints a message.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "do_thing"
	var param: ACEParam = ACEParam.new()
	param.id = "amount"
	param.type_name = "int"
	event_function.params.append(param)
	var body_event: EventRow = EventRow.new()
	var print_action: ACEAction = ACEAction.new()
	print_action.provider_id = "Core"
	print_action.ace_id = "PrintLog"
	print_action.params = {"message": "\"hello\""}
	body_event.actions.append(print_action)
	event_function.events.append(body_event)
	sheet.functions.append(event_function)

	var result: Dictionary = SheetCompiler.compile(sheet, OUTPUT_PATH)
	var output: String = str(result.get("output", ""))
	all_passed = _check("compile succeeds", bool(result.get("success", false)), true) and all_passed
	all_passed = _check("function signature emitted (typed param)",
		output.contains("func do_thing(amount: int) -> void:"), true) and all_passed
	all_passed = _check("function body emitted", output.contains("print(\"hello\")"), true) and all_passed

	# An empty function falls back to a `pass` body.
	var empty_function: EventFunction = EventFunction.new()
	empty_function.function_name = "noop"
	var sheet2: EventSheetResource = EventSheetResource.new()
	sheet2.functions.append(empty_function)
	var output2: String = str(SheetCompiler.compile(sheet2, OUTPUT_PATH).get("output", ""))
	all_passed = _check("empty function emits signature", output2.contains("func noop() -> void:"), true) and all_passed
	all_passed = _check("empty function body is pass", output2.contains("\tpass"), true) and all_passed

	# The built-in "Call Function" action emits a call to the named function.
	var call_action: ACEAction = ACEAction.new()
	call_action.provider_id = "Core"
	call_action.ace_id = "CallFunction"
	call_action.params = {"function_name": "do_thing", "args": "5"}
	all_passed = _check("call function action emits a call",
		ActionCodegen.generate_action(call_action), "do_thing(5)") and all_passed

	var call_no_args: ACEAction = ACEAction.new()
	call_no_args.provider_id = "Core"
	call_no_args.ace_id = "CallFunction"
	call_no_args.params = {"function_name": "reset", "args": ""}
	all_passed = _check("call with no args emits empty parens",
		ActionCodegen.generate_action(call_no_args), "reset()") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sheet_function_test: %s" % label)
		return true
	print("[FAIL] sheet_function_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
