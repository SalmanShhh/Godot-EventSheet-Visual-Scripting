# Godot EventSheets - THE REGISTRY DUMP: every verb the project publishes as one sorted, stable text.
#
# Two questions are the same question underneath: what does a pack's new version retire and add, and
# did a refactor change any verb's identity? Both are answered by diffing two of these texts, so the
# format, its escaping and the diff are pinned here on registries built in memory.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = _test_the_dump_format()
	ok = _test_the_dump_round_trips_its_escaping() and ok
	ok = _test_the_diff_between_two_dumps() and ok
	return ok


## The format, pinned on a registry of two verbs. Eight tab-separated fields in a fixed order, sorted
## by key, one comment line at the top, and a template folded onto one line by escaping.
##
## The two parameter-detail fields are on the line because a default is not decoration: it lands in
## every freshly picked row and it decides whether a forwarding address has to answer that parameter
## at all. A dump listing parameter NAMES alone said "nothing changed" about a version that re-typed
## or re-defaulted every one of them.
static func _test_the_dump_format() -> bool:
	var registry: Dictionary = {
		"Probe::Wave": {
			"ace_type": ACEDefinition.ACEType.ACTION,
			"category": "Signals",
			"params": PackedStringArray(["times"]),
			"declared_types": {"times": "int"},
			"declared_defaults": {"times": "3"},
			"template": "wave({times})\n\tpass",
			"map": {},
		},
		"Probe::IsWaving": {
			"ace_type": ACEDefinition.ACEType.CONDITION,
			"category": "Signals",
			"params": PackedStringArray(),
			"template": "is_waving()",
			"map": {"id": "Probe::IsAnimating", "renames": {}, "defaults": {}},
		},
	}
	var expected: String = "\n".join(PackedStringArray([
		"# eventsheets registry dump 2",
		"Probe::IsWaving\tcondition\tSignals\t\t\t\tProbe::IsAnimating\tis_waving()",
		"Probe::Wave\taction\tSignals\ttimes\ttimes=int\ttimes=3\t\twave({times})\\n\\tpass",
		"",
	]))
	var ok: bool = _check("the dump is eight sorted fields per verb",
		EventForgeRegistryDump.text(registry), expected)
	# A DEFAULT THAT MOVES IS A CHANGE, which is the whole reason those two fields are on the line.
	var re_defaulted: Dictionary = registry.duplicate(true)
	(re_defaulted["Probe::Wave"] as Dictionary)["declared_defaults"] = {"times": "5"}
	ok = _check("re-defaulting a parameter is reported as a change",
		EventForgeRegistryDump.diff(expected,
			EventForgeRegistryDump.text(re_defaulted))["changed"],
		[{"key": "Probe::Wave", "fields": PackedStringArray(["param_defaults"])}]) and ok
	ok = _check("and it says which format it is",
		EventForgeRegistryDump.is_current_format(expected), true) and ok
	ok = _check("a text from another shape is not read at all",
		EventForgeRegistryDump.is_current_format("Probe::Wave\taction"), false) and ok
	return ok


## Escaping is reversible, including the case that catches a chain of replaces: a template holding
## the two characters a reader typed as a backslash and an n, which must not come back as a newline.
static func _test_the_dump_round_trips_its_escaping() -> bool:
	var template: String = "print(\"a\\nb\")\n\tqueue_free()\t# tabbed"
	var registry: Dictionary = {"P::A": {
		"ace_type": ACEDefinition.ACEType.EXPRESSION, "category": "", "params": PackedStringArray(["one", "two"]),
		"template": template, "map": {}}}
	var parsed: Dictionary = EventForgeRegistryDump.parse(EventForgeRegistryDump.text(registry))
	var ok: bool = _check("one verb comes back", parsed.size(), 1)
	ok = _check("its template survives every escape",
		str((parsed.get("P::A", {}) as Dictionary).get("template", "")), template) and ok
	ok = _check("its params survive as written",
		str((parsed.get("P::A", {}) as Dictionary).get("params", "")), "one,two") and ok
	ok = _check("and an expression is called an expression",
		str((parsed.get("P::A", {}) as Dictionary).get("type", "")), "expression") and ok
	return ok


## What a diff says, over the four things that can happen to a verb between two versions.
static func _test_the_diff_between_two_dumps() -> bool:
	var before: String = EventForgeRegistryDump.text({
		"P::Kept": _entry("k()", {}),
		"P::Moved": _entry("m()", {}),
		"P::Gone": _entry("g()", {}),
		"P::Reworded": _entry("r()", {}),
	})
	var after: String = EventForgeRegistryDump.text({
		"P::Kept": _entry("k()", {}),
		"P::Moved": _entry("m()", {"id": "P::Arrived", "renames": {}, "defaults": {}}),
		"P::Reworded": _entry("r(1)", {}),
		"P::Arrived": _entry("a()", {}),
	})
	var moved: Dictionary = EventForgeRegistryDump.diff(before, after)
	var ok: bool = _check("the diff is readable", bool(moved.get("readable", false)), true)
	ok = _check("a verb that gained an address is retired, and says where to",
		moved.get("retired", []), [
			{"key": "P::Gone", "successor": "", "gone": true},
			{"key": "P::Moved", "successor": "P::Arrived", "gone": false},
		]) and ok
	ok = _check("a verb the new version publishes and the old did not is added",
		moved.get("added", PackedStringArray()), PackedStringArray(["P::Arrived"])) and ok
	ok = _check("and a verb whose line moved names the field that moved",
		moved.get("changed", []), [
			{"key": "P::Moved", "fields": PackedStringArray(["successor"])},
			{"key": "P::Reworded", "fields": PackedStringArray(["template"])},
		]) and ok
	ok = _check("a dump this build cannot read is refused rather than answered",
		bool(EventForgeRegistryDump.diff("Probe::Wave\taction", after).get("readable", true)), false) and ok
	return ok


static func _entry(template: String, map: Dictionary) -> Dictionary:
	return {"ace_type": ACEDefinition.ACEType.ACTION, "category": "Probe",
		"params": PackedStringArray(), "template": template, "map": map}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("registry_dump_test", label, actual, expected)
