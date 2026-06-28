# Godot EventSheets — syntax-error guardrails (help users not write broken GDScript).
#
# Three layers, all to keep "little chance of syntax errors by the user":
#   1. structural_syntax_error() — a context-free check for unbalanced ()/[]/{} or unterminated strings.
#      ALWAYS an error (no false positives on runtime-only refs), skipping brackets/quotes inside strings
#      and # comments, handling \ escapes + triple quotes.
#   2. The param dialog blocks Apply on a structural error EVEN when the symbol-aware lint can't run.
#   3. configure_code_editor() turns on auto-close brackets/quotes so they're rarely typed wrong at all.
@tool
extends RefCounted
class_name SyntaxGuardrailsTest

static func run() -> bool:
	var all_passed: bool = true

	# ── structural_syntax_error: structurally sound code is clean ("") ──
	var ok_cases: Array[String] = [
		"velocity.y += gravity * delta",
		"a[b(c)] + maxf(d, e)",
		'"a string with ) and ] inside"',
		"x = 1  # a comment with ( an unbalanced bracket",
		"print(\"escaped \\\" quote\")",
		'value = """triple ( quoted"""',
		"",
	]
	for ok_code: String in ok_cases:
		all_passed = _check("structurally sound: %s" % ok_code.replace("\n", "\\n"),
			EventSheetGDScriptLint.structural_syntax_error(ok_code), "") and all_passed

	# ── structural_syntax_error: malformed code is flagged (non-empty) ──
	var bad_cases: Array[String] = ["(a + b", "a + b)", "arr[0", "foo(]", '"unterminated', "{a: b"]
	for bad_code: String in bad_cases:
		all_passed = _check("structurally broken: %s" % bad_code,
			not EventSheetGDScriptLint.structural_syntax_error(bad_code).is_empty(), true) and all_passed

	# ── configure_code_editor: auto-close brackets/quotes are on (prevent errors at the source) ──
	var edit: CodeEdit = CodeEdit.new()
	EventSheetPopupUI.configure_code_editor(edit)
	all_passed = _check("auto-brace completion enabled", edit.auto_brace_completion_enabled, true) and all_passed
	all_passed = _check("'(' auto-closes with ')'", str(edit.auto_brace_completion_pairs.get("(", "")), ")") and all_passed
	all_passed = _check("'\"' is an auto-close pair", edit.auto_brace_completion_pairs.has("\""), true) and all_passed
	edit.free()

	# ── The param dialog blocks Apply on a structural error — even with NO lint context (the closed hole) ──
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var broken_field: CodeEdit = CodeEdit.new()
	broken_field.text = "(speed * 2"  # unbalanced — would not compile
	dialog._fields = {"amount": broken_field}
	all_passed = _check("dialog finds the structurally-broken expression field",
		dialog._first_structural_error_field() == broken_field, true) and all_passed
	var blocker: Dictionary = dialog._blocking_expression_field()
	all_passed = _check("dialog blocks Apply with a clear message",
		not blocker.is_empty() and str(blocker.get("message", "")).begins_with("✗"), true) and all_passed
	broken_field.text = "(speed * 2)"  # now balanced
	all_passed = _check("a balanced expression no longer blocks on structure",
		dialog._first_structural_error_field() == null, true) and all_passed
	broken_field.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] syntax_guardrails_test: %s" % label)
		return true
	print("[FAIL] syntax_guardrails_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
