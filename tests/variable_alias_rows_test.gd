# Godot EventSheets - R38: "Set boolean" and "Boolean is true / is false" are ALIAS rows.
#
# They are the names everyone who has used an event sheet already says, but neither is a descriptor
# of its own: minting one would put a second template in the lifter matching the same line, and an
# earlier attempt at exactly that stole every `muted = true` line from Set value. So this pins the
# thing that must stay true - each alias names a SHIPPED, FROZEN ace_id, and carries only the
# prefill that answers the boolean half of the form.
@tool
class_name VariableAliasRowsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var aliases: Array[Dictionary] = ACEPickerDialog.VARIABLE_ALIASES

	ok = _check("both aliases are offered, by those names",
		_displays(aliases), "Set boolean, Boolean is true / is false") and ok

	var set_boolean: Dictionary = _alias(aliases, "Set boolean")
	ok = _check("Set boolean IS Set value",
		"%s/%s" % [str(set_boolean.get("provider", "")), str(set_boolean.get("ace_id", ""))],
		"Core/SetVar") and ok
	ok = _check("…with the value already true",
		set_boolean.get("prefill", {}), {"value": "true"}) and ok

	var is_true: Dictionary = _alias(aliases, "Boolean is true / is false")
	ok = _check("the boolean question IS Compare variable",
		"%s/%s" % [str(is_true.get("provider", "")), str(is_true.get("ace_id", ""))],
		"Core/CompareVar") and ok
	ok = _check("…asking == true, which the invert mark then flips to == false",
		is_true.get("prefill", {}), {"op": "==", "value": "true"}) and ok

	# The whole point: no alias may name an id nothing ships, and none may invent one. Both ids are
	# public API and frozen, so a rename would break every sheet that already uses the row.
	for alias: Dictionary in aliases:
		ok = _check("%s names a variable descriptor, never a new one" % str(alias.get("display", "")),
			str(alias.get("provider", "")), "Core") and ok
		ok = _check("%s says nothing the prefill cannot fill" % str(alias.get("display", "")),
			(alias.get("prefill", {}) as Dictionary).is_empty(), false) and ok
		ok = _check("%s is findable by typing its own words" % str(alias.get("display", "")),
			str(alias.get("search", "")).contains("boolean"), true) and ok

	# The quick-add bar has no tree to show an alias row in, so it finds the descriptor through the
	# synonym table instead - the two surfaces must agree about what "set boolean" means.
	ok = _check("the quick-add bar maps \"set boolean\" to Set value",
		str(ACEPickerDialog.SEARCH_SYNONYMS.get("set boolean", "")), "set value") and ok
	ok = _check("…and both boolean questions to Compare variable",
		"%s|%s" % [
			str(ACEPickerDialog.SEARCH_SYNONYMS.get("boolean is true", "")),
			str(ACEPickerDialog.SEARCH_SYNONYMS.get("boolean is false", ""))
		], "compare variable|compare variable") and ok

	return ok


static func _displays(aliases: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for alias: Dictionary in aliases:
		parts.append(str(alias.get("display", "")))
	return ", ".join(parts)


static func _alias(aliases: Array[Dictionary], display: String) -> Dictionary:
	for alias: Dictionary in aliases:
		if str(alias.get("display", "")) == display:
			return alias
	return {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_alias_rows_test: %s" % label)
		return true
	print("[FAIL] variable_alias_rows_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
