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
const STORYLET_PACK := "res://eventsheet_addons/storylet_weaver/storylet_weaver_addon.gd"


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
		["=  equal to", "≠  not equal to", "<  less than", "≤  at most", ">  greater than", "≥  at least"]) and ok
	ok = _check("it seeds == so the row reads as a sentence on drop", _default(compares, "op"), "==") and ok

	# ---- 4. Labeled options survive the trip THROUGH an emitted pack ----
	# A pack's shipped .gd IS its provider, so an option only really exists if it round-trips as an
	# annotation. It did not: the emitter str()-ed the {key,label} dict, baking raw GDScript into the
	# comment, and the scanner (which splits the list on commas) read one labeled option back as
	# several broken ones. Every dict-option dropdown in the shipped packs was silently garbage.
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var emitted: String = FileAccess.get_file_as_string(STORYLET_PACK)
	ok = _check("a labeled option emits as key=Label",
		emitted.contains("@ace_param_options(op set=Set to, inc=Increment by"), true) and ok
	# The operators are the hard case: the key CONTAINS the `=` the grammar splits on, so it ships
	# quoted. Without this `>=` came back as `>` - which is a wrong comparison, not a cosmetic bug.
	ok = _check("an operator key ships quoted so it cannot cut itself in half",
		emitted.contains("\">=\"=≥  at least"), true) and ok
	var scanned: Dictionary = analyzer._build_overrides([
		"@ace_action",
		"@ace_param_options(op \"=\"==  equal to, \"!=\"=≠  not equal to, <=<  less than, \"<=\"=≤  at most, >=>  greater than, \">=\"=≥  at least)"
	])
	var scanned_options: Array = (scanned.get("param_options", {}) as Dictionary).get("op", [])
	var scanned_keys: Array = []
	var scanned_labels: Array = []
	for option: Variant in scanned_options:
		scanned_keys.append(str((option as Dictionary).get("key", "")))
		scanned_labels.append(str((option as Dictionary).get("label", "")))
	ok = _check("and the scanner reads all six operators back intact",
		scanned_keys, ["=", "!=", "<", "<=", ">", ">="]) and ok
	ok = _check("with their labels", scanned_labels,
		["=  equal to", "≠  not equal to", "<  less than", "≤  at most", ">  greater than", "≥  at least"]) and ok

	# ---- 5. One canonical operator list, not a copy per surface ----
	# The analyzer's shorthand, the builtin Compare conditions and any pack builder all resolve to
	# the factory's list, so a wording change cannot land in one dropdown and miss the others.
	ok = _check("the shorthand points at the factory list",
		EventSheetSemanticAnalyzer.COMPARISON_OPTIONS, EventForgeACEFactory.COMPARISON_OPTIONS) and ok
	ok = _check("and the bare-token list stays in step with it",
		EventForgeACEFactory.COMPARISON_OPERATORS.size(), EventForgeACEFactory.COMPARISON_OPTIONS.size()) and ok
	var single_equals: Array = EventSheets.comparison_options("=")
	ok = _check("a pack whose runtime matches a single = gets that spelling",
		str((single_equals[0] as Dictionary).get("key", "")), "=") and ok
	ok = _check("without disturbing the rest",
		str((single_equals[5] as Dictionary).get("key", "")), ">=") and ok

	# ---- 6. The third authoring surface: a config passed to the public API ----
	# A bundled module and an annotation could both express these; a Dictionary handed to
	# simple_ace()/simple_block_kind() went through verbatim, so an author had to know the key is
	# `default_value` and not `default`, and had to hand-build the {key, label} pairs. Both papercuts
	# end as a param that silently reads 0, or a dropdown of raw tokens.
	var shorthand: Dictionary = EventSheets.param_spec({"id": "op", "hint": "comparison"})
	ok = _check("`hint: comparison` works through the API too",
		(shorthand.get("options", []) as Array).size(), 6) and ok
	ok = _check("seeded the same way", shorthand.get("default_value", ""), "==") and ok
	# Leaving the hint on would send the dialog hunting for a field factory named "comparison".
	ok = _check("and the hint is spent", shorthand.has("hint"), false) and ok
	var dictionary_options: Dictionary = EventSheets.param_spec({
		"id": "mode", "default": "set", "options": {"set": "Set to", "inc": "Increment by"}})
	ok = _check("a {value: label} dictionary becomes pairs",
		dictionary_options.get("options", []), [
			{"key": "set", "label": "Set to"}, {"key": "inc", "label": "Increment by"}]) and ok
	ok = _check("`default` is accepted as well as `default_value`",
		dictionary_options.get("default_value", ""), "set") and ok
	var plain: Dictionary = EventSheets.param_spec({"id": "axis", "options": ["x", "y"]})
	ok = _check("a plain list still labels itself",
		plain.get("options", []), [{"key": "x", "label": "x"}, {"key": "y", "label": "y"}]) and ok
	# And the normalization has to actually reach the definitions the API builds.
	var built: ACEDefinition = EventSheets.simple_ace({
		"id": "Cmp", "template": "{a} {op} {b}",
		"params": [{"id": "op", "hint": "comparison"}]})
	ok = _check("simple_ace runs its params through it",
		str(((built.parameters[0] as Dictionary).get("options", [])[0] as Dictionary).get("label", "")),
		"=  equal to") and ok

	# ---- 7. …and the CUSTOM BLOCK dialog has to speak the normalized shape back ----
	# Normalizing simple_block_kind's fields through param_spec turned every authored dropdown into
	# {key, label} pairs - but the block dialog still rendered str(option) and read back the item
	# TEXT, so the stored field value became the literal `{ "key": ..., "label": ... }` and went
	# straight into the user's emitted GDScript through the emit template. Both dialects must work.
	var kind: EventSheetBlockKind = EventSheets.simple_block_kind({
		"kind_id": "test.speed", "title": "Speed",
		"fields": [{"id": "mode", "type": TYPE_STRING, "default": "fast",
			"options": {"fast": "Fast (no easing)", "slow": "Slow (eased)"}}],
		"emit": "## speed: {mode}"})
	var dialog: EventSheetCustomBlockDialog = EventSheetCustomBlockDialog.new()
	var field_spec: Dictionary = kind.fields()[0]
	var chooser: OptionButton = dialog._make_field_control(field_spec, "slow") as OptionButton
	ok = _check("a block dropdown shows the label", chooser.get_item_text(0), "Fast (no easing)") and ok
	ok = _check("and stores the key", str(chooser.get_item_metadata(0)), "fast") and ok
	ok = _check("selecting by key finds the right item", chooser.selected, 1) and ok
	dialog._field_controls = {"mode": chooser}
	ok = _check("reading the form back yields the key, not the label",
		dialog._collect_fields(kind).get("mode", ""), "slow") and ok
	chooser.free()
	# param_spec seeds `default_value`; a hand-written schema says `default`. Reading only one left a
	# comparison field on its auto-selected first item, quietly storing the wrong operator.
	ok = _check("a normalized default is still found",
		str(dialog._field_default(EventSheets.param_spec({"id": "op", "hint": "comparison"}))), "==") and ok
	ok = _check("and a hand-written one still is",
		str(dialog._field_default({"id": "op", "default": "gte"})), "gte") and ok

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
