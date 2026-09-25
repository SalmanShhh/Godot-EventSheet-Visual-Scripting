@tool
class_name RegexAcesTest
extends RefCounted
# The RegEx module compiles to direct Godot RegEx one-liners (parity-clean, null-safe). This pins that
# every one of its descriptors is registered under the module.

const SUPPORT := preload("res://tests/support.gd")
const RegexACEs := preload("res://addons/eventforge/registration/modules/regex_aces.gd")


static func run() -> bool:
	var all_passed: bool = true
	# All descriptors are registered under the module.
	var ids: Array = []
	for d: ACEDescriptor in RegexACEs.get_descriptors():
		ids.append(d.ace_id)
	for want: String in ["RegexMatches", "RegexReplace", "RegexFirstMatch", "RegexMatchCount", "RegexAllMatches", "RegexCaptureGroup", "FormatDecimals"]:
		all_passed = _check("registers %s" % want, want in ids, true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("regex_aces_test", label, actual, expected)
