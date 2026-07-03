@tool
class_name RegexAcesTest
extends RefCounted
# The RegEx module compiles to direct Godot RegEx one-liners (parity-clean, null-safe). These pin the
# BEHAVIOUR of the exact expressions the ACE templates emit — not just that they parse — so a regression
# in the template (a wrong method, a lost null-guard) is caught here.

const RegexACEs := preload("res://addons/eventforge/registration/modules/regex_aces.gd")


static func run() -> bool:
	var all_passed: bool = true
	var re: RegEx = RegEx.create_from_string("[0-9]+")

	# RegexMatches (condition)
	all_passed = _check("matches when present", re.search("score: 42") != null, true) and all_passed
	all_passed = _check("no match when absent", re.search("no digits") != null, false) and all_passed
	# RegexReplace (sub all)
	all_passed = _check("replace every match", re.sub("a1b2c3", "#", true), "a#b#c#") and all_passed
	# RegexMatchCount
	all_passed = _check("match count", re.search_all("a1b2c3").size(), 3) and all_passed
	# RegexAllMatches (map → strings)
	all_passed = _check("all matches", re.search_all("a1b2c3").map(func(__m): return __m.get_string()), ["1", "2", "3"]) and all_passed
	# RegexFirstMatch (null-safe front)
	all_passed = _check("first match", (re.search_all("a1b2").map(func(__m): return __m.get_string()) + [""]).front(), "1") and all_passed
	all_passed = _check("first match empty on miss", (re.search_all("xyz").map(func(__m): return __m.get_string()) + [""]).front(), "") and all_passed
	# RegexCaptureGroup (group N of first match)
	var re2: RegEx = RegEx.create_from_string("([a-z])([0-9])")
	all_passed = _check("capture group 1", (re2.search_all("a1b2").map(func(__m): return __m.get_string(1)) + [""]).front(), "a") and all_passed
	all_passed = _check("capture group 2", (re2.search_all("a1b2").map(func(__m): return __m.get_string(2)) + [""]).front(), "1") and all_passed
	# FormatDecimals
	all_passed = _check("format decimals", String.num(3.14159, 2), "3.14") and all_passed

	# All descriptors are registered under the module.
	var ids: Array = []
	for d: ACEDescriptor in RegexACEs.get_descriptors():
		ids.append(d.ace_id)
	for want: String in ["RegexMatches", "RegexReplace", "RegexFirstMatch", "RegexMatchCount", "RegexAllMatches", "RegexCaptureGroup", "FormatDecimals"]:
		all_passed = _check("registers %s" % want, want in ids, true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] regex_aces_test: %s" % label)
		return true
	print("[FAIL] regex_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
