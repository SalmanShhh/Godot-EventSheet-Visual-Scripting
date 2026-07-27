# EventForge - the provider param-authoring grammar: defaults, labeled options, comparison shorthand.
#
# These three closed the gap between what a BUILTIN module can express and what an addon author can.
# Builtins always could set a starting value and label a dropdown; annotations could not, so every
# provider param fell back to type-zero and every dropdown read as its own raw token.
#
# The defaults matter more than they look. A param's default is what the row shows the MOMENT it is
# dropped, so "no default" means a freshly picked verb reads `0.0` and quietly does nothing - the same
# failure the builtin compile gate catches for built-in ACEs, which nothing was catching for addons.
# The Physics-Car guide documented defaults of 1.0/1.0/5.0 that did not exist; that is now expressible.
@tool
class_name ParamAuthoringTest
extends RefCounted

const FIXTURE := "res://tests/fixtures/param_grammar_fixture.gd"


static func run() -> bool:
	var ok: bool = true
	var fixture: Object = (load(FIXTURE) as GDScript).new()
	var definitions: Array[ACEDefinition] = EventSheetACEGenerator.new().generate_from_object(fixture)
	var by_id: Dictionary = {}
	for definition: ACEDefinition in definitions:
		by_id[str(definition.id)] = definition

	# ---- 1. GDScript's OWN defaults, with no annotation at all ----
	# Godot reports default_args for the TRAILING arguments only, so the alignment matters: `angle`
	# has no default and must stay type-zero even though its neighbours do.
	var drive: Dictionary = _params(by_id, "method:drive_toward")
	ok = _check("an undefaulted argument still falls back to type-zero", _default(drive, "angle"), "0.0") and ok
	ok = _check("a GDScript default becomes the param's starting value", _default(drive, "throttle"), "1.0") and ok
	ok = _check("and the tail alignment is right for the last one too", _default(drive, "tolerance"), "5.0") and ok

	# ---- 2. Labeled dropdown options: read as English, insert the real token ----
	var quality: Dictionary = _params(by_id, "method:set_quality")
	ok = _check("options split into key and label",
		_option_pairs(quality, "level"), ["low=Potato", "med=Balanced", "high=Ultra"]) and ok
	ok = _check("an explicit default: wins, with its quotes stripped", _default(quality, "level"), "med") and ok

	# ---- 3. `hint: comparison` is the whole operator dropdown in one word ----
	var compares: Dictionary = _params(by_id, "method:stat_compares")
	ok = _check("comparison shorthand offers all six operators",
		_option_keys(compares, "op"), ["==", "!=", "<", "<=", ">", ">="]) and ok
	# The labels are why this exists: `=` cannot be typed into the enum-option parser directly, which
	# is what pushed earlier packs into word-token workarounds plus a symbol-mapper.
	ok = _check("and labels them in plain English",
		_option_labels(compares, "op"),
		["= (equal to)", "!= (not equal to)", "< (less than)", "<= (at most)", "> (greater than)", ">= (at least)"]) and ok
	ok = _check("it seeds == so the row reads as a sentence on drop", _default(compares, "op"), "==") and ok

	return ok


static func _params(by_id: Dictionary, ace_id: String) -> Dictionary:
	var output: Dictionary = {}
	if not by_id.has(ace_id):
		return output
	for entry: Variant in (by_id[ace_id] as ACEDefinition).parameters:
		if entry is Dictionary:
			output[str((entry as Dictionary).get("id", ""))] = entry
	return output


static func _default(params: Dictionary, param_id: String) -> String:
	return str((params.get(param_id, {}) as Dictionary).get("default_value", "<missing>"))


static func _option_keys(params: Dictionary, param_id: String) -> Array:
	var output: Array = []
	for option: Variant in ((params.get(param_id, {}) as Dictionary).get("options", []) as Array):
		output.append(str((option as Dictionary).get("key", "")))
	return output


static func _option_labels(params: Dictionary, param_id: String) -> Array:
	var output: Array = []
	for option: Variant in ((params.get(param_id, {}) as Dictionary).get("options", []) as Array):
		output.append(str((option as Dictionary).get("label", "")))
	return output


static func _option_pairs(params: Dictionary, param_id: String) -> Array:
	var output: Array = []
	for option: Variant in ((params.get(param_id, {}) as Dictionary).get("options", []) as Array):
		var pair: Dictionary = option as Dictionary
		output.append("%s=%s" % [str(pair.get("key", "")), str(pair.get("label", ""))])
	return output


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] param_authoring_test: %s" % label)
		return true
	print("[FAIL] param_authoring_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
