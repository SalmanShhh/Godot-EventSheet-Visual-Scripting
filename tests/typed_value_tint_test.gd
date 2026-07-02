# EventForge — typed value tinting. ViewportRowBuilder._value_ranges_for tags each
# highlighted parameter literal with its TYPE ("number" / "string" / "bool") so the renderer can tint it
# by kind. The kind comes straight from which regex alternate matched, so the tint can't disagree with
# the highlight; the [start, length] prefix stays index-accessible for the value hit-test (backward-compat).
@tool
extends RefCounted
class_name TypedValueTintTest

static func run() -> bool:
	var ok: bool = true

	ok = _kind("an integer", "Set health 100", "number") and ok
	ok = _kind("a negative float", "Move -3.5", "number") and ok
	ok = _kind("a quoted string", "Play \"jump\"", "string") and ok
	ok = _kind("a boolean true", "Set flag true", "bool") and ok
	ok = _kind("a boolean False", "Set flag False", "bool") and ok

	# Mixed line: number, string, bool in reading order, with the [start,length] prefix intact.
	var ranges: Array = ViewportRowBuilder._value_ranges_for("n 5 s \"hi\" b true")
	ok = _check("mixed line finds 3 values", ranges.size(), 3) and ok
	if ranges.size() == 3:
		ok = _check("kinds in reading order", "%s,%s,%s" % [ranges[0][2], ranges[1][2], ranges[2][2]], "number,string,bool") and ok
		ok = _check("first range start (hit-test prefix intact)", int(ranges[0][0]), 2) and ok
		ok = _check("first range length", int(ranges[0][1]), 1) and ok

	# Plain vocabulary is not a value — no false highlights.
	ok = _check("plain text has no values", ViewportRowBuilder._value_ranges_for("Move And Slide").size(), 0) and ok

	return ok

static func _kind(label: String, text: String, expected_kind: String) -> bool:
	var ranges: Array = ViewportRowBuilder._value_ranges_for(text)
	var actual: String = str(ranges[0][2]) if ranges.size() > 0 and (ranges[0] as Array).size() >= 3 else "(none)"
	return _check("%s tints as %s" % [label, expected_kind], actual, expected_kind)

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] typed_value_tint_test: %s" % label)
		return true
	print("[FAIL] typed_value_tint_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
