# Godot EventSheets - the Inspector preview card's plain-sentence summary
# (v0.11 chapter 2, P2). The sentence is the beginner-facing statement of what
# the Inspector will show, so it is pinned as EXACT STRINGS across a matrix of
# attribute combinations - a wording drift is a test failure, not a surprise.
@tool
class_name InspectorPreviewTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _pin("plain exported int", "int", {}, true, false,
		"A whole number.") and ok
	ok = _pin("range + progress bar + grouping", "int",
		{"range": {"min": "0", "max": "100"}, "drawer": "progress_bar", "group": "Combat", "subgroup": "Defense"}, true, false,
		"A whole number, from 0 to 100, shown as a progress bar, grouped under Combat > Defense.") and ok
	ok = _pin("range alone reads as a slider", "float",
		{"range": {"min": "0", "max": "1"}}, true, false,
		"A number, from 0 to 1, shown as a slider.") and ok
	ok = _pin("or_greater + suffix", "int",
		{"range": {"min": "0", "max": "300", "or_greater": true, "suffix": "px"}}, true, false,
		"A whole number, from 0 to 300 or more (in px), shown as a slider.") and ok
	ok = _pin("flags", "int", {"flags": [{"label": "Fire", "value": "1"}]}, true, false,
		"A whole number, shown as checkbox flags.") and ok
	ok = _pin("folder picker", "String", {"file": {"mode": "dir", "global": false}}, true, false,
		"Text, picked with a folder picker.") and ok
	ok = _pin("multiline text", "String", {"multiline": true}, true, false,
		"Text, with a big text box.") and ok
	ok = _pin("clamped + read-only", "float",
		{"range": {"min": "0", "max": "10"}, "clamp": true, "read_only": true}, true, false,
		"A number, from 0 to 10, shown as a slider, clamped to the range, read-only.") and ok
	ok = _pin("storage overrides the tail", "int", {"storage": true, "group": "Combat"}, true, false,
		"A whole number, saved with the scene but hidden in the Inspector.") and ok
	ok = _pin("not exported", "int", {}, false, false,
		"Only the sheet uses it - it does not appear in the Inspector.") and ok
	ok = _pin("constant", "int", {}, true, true,
		"A constant - fixed while the game runs, not editable in the Inspector.") and ok

	# The card mock itself: exported shows rows; unexported hides the card.
	var card := EventSheetInspectorPreviewCard.new()
	card.update_preview("max_health", "int", "100", {"group": "Combat"}, true, false)
	ok = _check("exported variable shows the card", card.visible, true) and ok
	card.update_preview("max_health", "int", "100", {}, false, false)
	ok = _check("unexported variable hides the card", card.visible, false) and ok
	card.free()
	return ok


static func _pin(label: String, type_name: String, attributes: Dictionary, exported: bool, constant: bool, expected: String) -> bool:
	return _check(label, EventSheetInspectorPreviewCard.describe(type_name, attributes, exported, constant), expected)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inspector_preview_test: %s" % label)
		return true
	print("[FAIL] inspector_preview_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
