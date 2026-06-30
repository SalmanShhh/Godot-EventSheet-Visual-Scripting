@tool
extends RefCounted
class_name ExpressionBuilderTest
# The "Insert Expression" window's operator palette and its tree results both insert at the caret of
# the expression field via _insert_into_expression_target(). That field is always a CodeEdit, but the
# old insert path only handled LineEdit — so picking a result (or, now, an operator) silently did
# nothing. These pin the shared helper for both the CodeEdit (the real case) and a LineEdit fallback.

static func run() -> bool:
	var all_passed: bool = true
	var host: Node = Node.new()
	var dlg: ACEParamsDialog = ACEParamsDialog.new()
	dlg.init_dialog(host)

	# A CodeEdit expression field, as registered by _create_expression_field (the fx picker's target).
	var edit: CodeEdit = CodeEdit.new()
	edit.text = "health"
	host.add_child(edit)
	dlg._fields["value"] = edit
	dlg._expression_target_key = "value"
	edit.set_caret_column(edit.text.length())  # caret at end, as after focusing the field

	# Operator palette (" + ") then a chained value ("10") compose at the caret — the regression guard:
	# before the fix this CodeEdit branch was missing, so both inserts were no-ops.
	dlg._insert_into_expression_target(" + ")
	dlg._insert_into_expression_target("10")
	all_passed = _check("inserts compose at the CodeEdit caret", edit.text, "health + 10") and all_passed

	# The LineEdit fallback still works (parity for any future LineEdit-backed expression field).
	var line: LineEdit = LineEdit.new()
	line.text = "x"
	host.add_child(line)
	dlg._fields["other"] = line
	dlg._expression_target_key = "other"
	line.caret_column = line.text.length()
	dlg._insert_into_expression_target(" > 5")
	all_passed = _check("inserts into a LineEdit target too", line.text, "x > 5") and all_passed

	host.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] expression_builder_test: %s" % label)
		return true
	print("[FAIL] expression_builder_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
