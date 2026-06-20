# EventForge — ACE template substitution (_apply_template)
#
# Param values must be OPAQUE: a value that itself contains `{...}` must be emitted verbatim, never
# re-scanned. An earlier iterative replace() pass corrupted such values (e.g. "{a}-{b}" with a="{b}"
# produced "X-X"). Also guards the optional `{, key}` comma idiom and unknown-placeholder behavior.
@tool
extends RefCounted
class_name TemplateSubstitutionTest

static func run() -> bool:
	var all_passed: bool = true
	# A value containing {b} must NOT be re-substituted by a later key.
	all_passed = _check("value with {placeholder} is not re-substituted",
		ActionCodegen._apply_template("{a}-{b}", {"a": "{b}", "b": "X"}), "{b}-X") and all_passed
	# Optional {, key}: leading comma only when the value is non-empty; dropped when empty/missing.
	all_passed = _check("optional arg present gets a leading comma",
		ActionCodegen._apply_template("f({x}{, args})", {"x": "1", "args": "2, 3"}), "f(1, 2, 3)") and all_passed
	all_passed = _check("optional arg empty drops the comma",
		ActionCodegen._apply_template("f({x}{, args})", {"x": "1", "args": ""}), "f(1)") and all_passed
	all_passed = _check("optional arg missing is stripped",
		ActionCodegen._apply_template("f({x}{, args})", {"x": "1"}), "f(1)") and all_passed
	# A value that itself contains the optional-comma form is preserved literally, not re-expanded.
	all_passed = _check("value with {, x} preserved literally",
		ActionCodegen._apply_template("a{, args}", {"args": "{, x}", "x": "BAD"}), "a, {, x}") and all_passed
	# Unknown plain placeholder stays literal (back-compat); repeated key replaced at every site.
	all_passed = _check("unknown plain {key} kept literal",
		ActionCodegen._apply_template("{known}-{unknown}", {"known": "K"}), "K-{unknown}") and all_passed
	all_passed = _check("repeated key substituted at each site",
		ActionCodegen._apply_template("{t}.x = {t}.y", {"t": "node"}), "node.x = node.y") and all_passed
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] template_substitution_test: %s" % label)
		return true
	print("[FAIL] template_substitution_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
