# EventForge — helper functions as Function rows. A behaviour's class-level `func` block (exposed
# `## @ace_condition`/`## @ace_expression` methods + private helpers) is lifted into EventFunction
# rows at build time, so it reads as Function rows instead of one code cell. Exposed functions keep
# their exposure; private helpers stay un-exposed (their leading comment relocates into the body);
# `return <expr>` bodies de-code to Return Value rows.
@tool
class_name FunctionDeclarationLiftTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "TestMover"
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_condition",
		"## @ace_name(\"Is Moving\")",
		"## @ace_category(\"Test\")",
		"## @ace_codegen_template(\"$TestMover.is_moving()\")",
		"func is_moving() -> bool:",
		"\treturn absf(host.velocity.x) > 1.0",
		"",
		"# A private jump helper.",
		"func _do_jump(power: float) -> void:",
		"\thost.velocity.y = power",
	]))
	sheet.events.append(block)

	var lifted: int = EventSheetACELifter.lift_function_declarations(sheet, false)
	ok = _check("two functions lifted", lifted, 2) and ok

	var raw_blocks: int = 0
	for row: Variant in sheet.events:
		if row is RawCodeRow:
			raw_blocks += 1
	ok = _check("the class-level code block is gone", raw_blocks, 0) and ok

	var is_moving: EventFunction = null
	var do_jump: EventFunction = null
	for fn: Variant in sheet.functions:
		if (fn as EventFunction).function_name == "is_moving":
			is_moving = fn
		elif (fn as EventFunction).function_name == "_do_jump":
			do_jump = fn
	ok = _check("the @ace_condition exposes as a bool function",
		is_moving != null and is_moving.expose_as_ace and is_moving.return_type == TYPE_BOOL and is_moving.ace_display_name == "Is Moving", true) and ok
	ok = _check("the private helper stays un-exposed", do_jump != null and not do_jump.expose_as_ace, true) and ok

	# `return <expr>` body de-codes to a Return Value row.
	var has_return_value: bool = false
	for body_row: Variant in (is_moving.events if is_moving != null else []):
		if body_row is EventRow:
			for action: Variant in (body_row as EventRow).actions:
				if action is ACEAction and (action as ACEAction).ace_id == "ReturnValue":
					has_return_value = true
	ok = _check("`return <expr>` body lifts to a Return Value row", has_return_value, true) and ok

	# The private helper's leading comment is preserved (relocated into the body).
	var comment_preserved: bool = false
	for body_row: Variant in (do_jump.events if do_jump != null else []):
		if body_row is CommentRow and (body_row as CommentRow).text.contains("private jump helper"):
			comment_preserved = true
	ok = _check("the helper's comment is preserved in its body", comment_preserved, true) and ok

	# Still compiles, and the function survives in the output.
	var result: Dictionary = SheetCompiler.compile(sheet, "user://fd_lift.gd")
	ok = _check("the sheet compiles", bool(result.get("success", false)), true) and ok
	ok = _check("output declares the function", str(result.get("output", "")).contains("func is_moving() -> bool:"), true) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_declaration_lift_test: %s" % label)
		return true
	print("[FAIL] function_declaration_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
