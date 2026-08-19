# Godot EventSheets - the pattern registry: claims are per sheet, per rebuild, deduped by row, and the
# coverage summary counts distinct patterns and the ones a behavior could replace.
@tool
class_name PatternFactsTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var other: EventSheetResource = EventSheetResource.new()
	EventSheetPatternFacts.clear(sheet)
	all_passed = _check("a fresh sheet has no claims", EventSheetPatternFacts.claims(sheet).size(), 0) and all_passed
	EventSheetPatternFacts.claim(sheet, "countdown", "row-1", "ev-1", PackedStringArray(["cooldown -= delta"]), "Cooldown", "", PackedStringArray(["Core/SetVar"]))
	EventSheetPatternFacts.claim(sheet, "countdown", "row-1", "ev-1")
	EventSheetPatternFacts.claim(sheet, "object_pool", "row-2", "ev-2", PackedStringArray(), "Object pool", "object_pool")
	EventSheetPatternFacts.claim(sheet, "not_a_pattern", "row-3", "ev-3")
	all_passed = _check("a claim is recorded once per pattern and row", EventSheetPatternFacts.claims(sheet).size(), 2) and all_passed
	all_passed = _check("an unknown pattern id is refused", EventSheetPatternFacts.claims_for_row(sheet, "row-3").size(), 0) and all_passed
	var first: Dictionary = EventSheetPatternFacts.claims_for_row(sheet, "row-1")[0]
	all_passed = _check("the claim keeps its evidence", first.get("evidence", PackedStringArray()), PackedStringArray(["cooldown -= delta"])) and all_passed
	all_passed = _check("the claim keeps its words", str(first.get("words", "")), "Cooldown") and all_passed
	var summary: Dictionary = EventSheetPatternFacts.summary(sheet)
	all_passed = _check("the summary counts distinct patterns", int(summary.get("patterns", 0)), 2) and all_passed
	all_passed = _check("the summary counts the adoptable ones", int(summary.get("adoptable", 0)), 1) and all_passed
	all_passed = _check("another sheet sees nothing", EventSheetPatternFacts.claims(other).size(), 0) and all_passed
	EventSheetPatternFacts.clear(sheet)
	all_passed = _check("clear forgets the sheet's claims", EventSheetPatternFacts.claims(sheet).size(), 0) and all_passed
	all_passed = _check("every pattern id is unique", _unique(EventSheetPatternFacts.PATTERN_IDS), EventSheetPatternFacts.PATTERN_IDS.size()) and all_passed
	return all_passed


static func _unique(list: PackedStringArray) -> int:
	var seen: Dictionary = {}
	for entry: String in list:
		seen[entry] = true
	return seen.size()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pattern_facts_test: %s" % label)
		return true
	print("[FAIL] pattern_facts_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
