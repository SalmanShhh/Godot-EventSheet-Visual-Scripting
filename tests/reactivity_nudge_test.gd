# Godot EventSheets — Reactivity nudge (poll -> signal-twin map).
#
# The picker shows "Reactive alternative: On Timeout" on a polling condition that has a clean signal
# twin, steering a Construct-3 user from "check every frame" toward Godot's "react to a signal". This
# guards the curated ACEDescriptor.REACTS_TO map: every mapped polling condition really exists and IS a
# condition, every reactive trigger really exists and IS a trigger with the named display (so a rename
# can't silently rot the nudge), and the deliberate omissions (is_on_floor, input-action polls — no
# real signal twin) stay omitted so the plugin never suggests a cargo-cult signal.
@tool
extends RefCounted
class_name ReactivityNudgeTest

static func run() -> bool:
	var all_passed: bool = true
	var by_key: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_key["%s::%s" % [descriptor.provider_id, descriptor.ace_id]] = descriptor

	all_passed = _check("the map has a curated handful of pairs (not over-reaching)",
		ACEDescriptor.REACTS_TO.size() >= 5 and ACEDescriptor.REACTS_TO.size() <= 12, true) and all_passed

	for key: String in ACEDescriptor.REACTS_TO:
		var condition: ACEDescriptor = by_key.get(key, null)
		all_passed = _check("polling condition exists: %s" % key, condition != null, true) and all_passed
		if condition != null:
			all_passed = _check("%s is a CONDITION" % key, condition.ace_type == ACEDescriptor.ACEType.CONDITION, true) and all_passed
		var twin: Dictionary = ACEDescriptor.REACTS_TO[key]
		var trigger_key: String = "Core::%s" % str(twin.get("trigger_id", ""))
		var trigger: ACEDescriptor = by_key.get(trigger_key, null)
		all_passed = _check("reactive trigger exists: %s" % trigger_key, trigger != null, true) and all_passed
		if trigger != null:
			all_passed = _check("%s is a TRIGGER" % trigger_key, trigger.ace_type == ACEDescriptor.ACEType.TRIGGER, true) and all_passed
			all_passed = _check("%s display matches the map" % trigger_key, trigger.display_name, str(twin.get("trigger_name", ""))) and all_passed

	# Cargo-cult guards: conditions with NO real signal twin must stay OUT of the map.
	for omitted: String in ["Core::IsOnFloor", "Core::IsActionPressed", "Core::IsActionJustPressed"]:
		all_passed = _check("not mapped (no real signal twin): %s" % omitted, ACEDescriptor.REACTS_TO.has(omitted), false) and all_passed

	# The shared lookup the picker (and later the Doctor / hint) read.
	all_passed = _check("reactive_alternative finds a mapped condition",
		str(ACEDescriptor.reactive_alternative("Core", "OverlapsBody").get("trigger_name", "")), "On Body Entered") and all_passed
	all_passed = _check("reactive_alternative is empty for an unmapped ACE",
		ACEDescriptor.reactive_alternative("Core", "Print").is_empty(), true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reactivity_nudge_test: %s" % label)
		return true
	print("[FAIL] reactivity_nudge_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
