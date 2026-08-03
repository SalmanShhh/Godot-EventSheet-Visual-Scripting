# EventSheet - recent parameter values (the per-param last-5 ring behind the suggestion combo).
# Pins the ring's VALUES: most-recent-first order, exact-text dedup (move to front, never
# duplicate), the cap of 5, per-key isolation, and the empty-value guard. Headless the store is
# purely in-memory - persistence is a thin editor-metadata layer these semantics never touch.
@tool
class_name RecentParamValuesTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	EventSheetRecentParamValues.reset_for_tests()

	# Most-recent-first, and re-committing an old value MOVES it to the front (no duplicate).
	EventSheetRecentParamValues.record("Core", "PlaySound", "path", "\"res://sfx/jump.ogg\"")
	EventSheetRecentParamValues.record("Core", "PlaySound", "path", "\"res://sfx/hit.ogg\"")
	EventSheetRecentParamValues.record("Core", "PlaySound", "path", "\"res://sfx/jump.ogg\"")
	all_passed = _check("re-commit moves to front, no duplicate",
		EventSheetRecentParamValues.recent_for("Core", "PlaySound", "path"),
		PackedStringArray(["\"res://sfx/jump.ogg\"", "\"res://sfx/hit.ogg\""])) and all_passed

	# The cap: six distinct commits keep the NEWEST five.
	for i: int in range(6):
		EventSheetRecentParamValues.record("Core", "AddVar", "amount", str(i))
	all_passed = _check("ring caps at five, newest first",
		EventSheetRecentParamValues.recent_for("Core", "AddVar", "amount"),
		PackedStringArray(["5", "4", "3", "2", "1"])) and all_passed

	# Per-key isolation: same param id under another ace shares nothing.
	all_passed = _check("keys are provider::ace::param scoped",
		EventSheetRecentParamValues.recent_for("Core", "SetVar", "amount"), PackedStringArray()) and all_passed

	# Empty and whitespace-only values never record.
	EventSheetRecentParamValues.record("Core", "Print", "text", "   ")
	all_passed = _check("whitespace never records",
		EventSheetRecentParamValues.recent_for("Core", "Print", "text"), PackedStringArray()) and all_passed

	EventSheetRecentParamValues.reset_for_tests()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] recent_param_values_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
