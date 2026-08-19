# EventForge - the reading check a pack passes before it publishes.
#
# The readability promise only holds if the packs keep it, so the rule is written down once
# (EventSheetPackReadingCheck) and read from three places: the Publish dialog, a Doctor check on
# this project's packs, and this gate over the shipped ones.
#
# Two halves here, and both matter:
#   the RULE, pinned on hand-made definitions, so a change to what "reads as a sentence" means
#   shows up as a named value rather than as a moved number; and
#   the SHIPPED PACKS, every one of which must read. That half is what caught six packs calling
#   their own actions "verbs" in text a reader sees.
@tool
class_name PackReadingCheckTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _check("a bare snake_case member is not a sentence",
		EventSheetPackReadingCheck._is_bare_call("set_thing"), true) and all_passed
	all_passed = _check("a call with brackets is not a sentence",
		EventSheetPackReadingCheck._is_bare_call("do_thing()"), true) and all_passed
	all_passed = _check("a dotted path is not a sentence",
		EventSheetPackReadingCheck._is_bare_call("node.thing"), true) and all_passed
	all_passed = _check("one plain word IS a sentence for an expression",
		EventSheetPackReadingCheck._is_bare_call("Prefab"), false) and all_passed
	all_passed = _check("a sentence with a parameter in it reads",
		EventSheetPackReadingCheck._is_bare_call("Set health to {value}"), false) and all_passed
	all_passed = _check("placeholders alone are not a sentence",
		EventSheetPackReadingCheck._is_bare_call("{value}"), true) and all_passed

	var reads: ACEDefinition = _definition("Set health to {value}", "Sets the object's health.", "value", "Health")
	all_passed = _check("a definition that reads has nothing to fix",
		EventSheetPackReadingCheck.check_definition(reads).size(), 0) and all_passed

	var bare: ACEDefinition = _definition("set_health", "", "value", "")
	var bare_problems: Array[Dictionary] = EventSheetPackReadingCheck.check_definition(bare)
	all_passed = _check("a bare call with no description and an unnamed parameter fails three ways",
		bare_problems.size(), 3) and all_passed
	all_passed = _check("the first failure names the words a reader sees",
		str(bare_problems[0].get("problem", "")),
		"the words a reader sees are a bare call, not a sentence") and all_passed
	all_passed = _check("the missing description is named second",
		str(bare_problems[1].get("problem", "")), "it publishes no description") and all_passed

	var product_word: ACEDefinition = _definition("Teach a verb", "Publishes a verb.", "value", "Value")
	all_passed = _check("a word the sheet does not use about itself is one failure",
		EventSheetPackReadingCheck.check_definition(product_word).size(), 1) and all_passed

	var verdict: Dictionary = EventSheetPackReadingCheck.check_definitions([reads, bare])
	all_passed = _check("one of two definitions reads", int(verdict.get("passed", -1)), 1) and all_passed
	all_passed = _check("half of two, floored and never rounded up to 100",
		int(verdict.get("percent", -1)), 50) and all_passed
	all_passed = _check("a set where every definition reads is 100%",
		int(EventSheetPackReadingCheck.check_definitions([reads]).get("percent", -1)), 100) and all_passed
	all_passed = _check("the summary of a passing set says so",
		EventSheetPackReadingCheck.summary_text(
			EventSheetPackReadingCheck.combine(EventSheetPackReadingCheck.check_definitions([reads]), {})),
		"Reads as sentences - every condition, action and expression, and the demo sheet.") and all_passed
	all_passed = _check("a failure lists as name, problem and fix",
		EventSheetPackReadingCheck.failure_line(bare_problems[1]),
		"set_health: it publishes no description - give it @ace_description(\"…\") - one line saying what it does") and all_passed

	all_passed = _shipped_packs_read() and all_passed
	return all_passed


## Every shipped pack must read. This is the CI half of the check - the Doctor says the same thing
## about a user's own packs, and the Publish dialog says it before one goes out.
static func _shipped_packs_read() -> bool:
	var failing: PackedStringArray = PackedStringArray()
	var packs: Array[Dictionary] = EventSheetPackCatalog.packs()
	for pack: Dictionary in packs:
		var result: Dictionary = EventSheetPackReadingCheck.check_script(str(pack.get("path", "")))
		if not bool(result.get("reads", false)):
			failing.append("%s (%d%%)" % [str(pack.get("dir", "")), int(result.get("percent", 0))])
	var counted: bool = _check("there are shipped packs to measure", packs.size() > 50, true)
	return _check("every shipped pack reads as sentences", failing, PackedStringArray()) and counted


static func _definition(display_name: String, description: String, parameter_id: String,
		parameter_name: String) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.id = "probe"
	definition.provider_id = "Probe"
	definition.display_name = display_name
	definition.description = description
	definition.parameters = [{"id": parameter_id, "display_name": parameter_name}]
	return definition


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pack_reading_check_test: %s" % label)
		return true
	print("[FAIL] pack_reading_check_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
