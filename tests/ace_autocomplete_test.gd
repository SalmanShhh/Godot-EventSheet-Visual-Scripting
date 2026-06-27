# Godot EventSheets — behavior-declared autocomplete + richer collection helpers.
#
# Covers two slices added together:
#  (1) The `## @ace_param_autocomplete(...)` annotation → an EDITABLE suggest combo
#      (event-sheet-style: type any value, or filter/pick from suggestions). The value
#      flows analyzer → generator → adapter → ACEParam, and the params dialog renders a
#      LineEdit (the value field) + a filtered suggestion popup.
#  (2) The new Array / Dictionary / Vector / String Helper ACEs register with the exact
#      direct GDScript one-liners they advertise (parity covenant).
@tool
extends RefCounted
class_name ACEAutocompleteTest

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func run() -> bool:
	var passed: bool = true

	# ── 1. Annotation parsing: directive → overrides["param_autocomplete"] ──────────
	var analyzer := EventSheetSemanticAnalyzer.new()
	var quoted_directives: Array[String] = ["@ace_param_autocomplete(anim \"idle\", \"run\", \"jump\")"]
	var overrides: Dictionary = analyzer._build_overrides(quoted_directives)
	passed = _check("annotation keeps verbatim quoted suggestions (no trailing-quote loss)",
		(overrides.get("param_autocomplete", {}) as Dictionary).get("anim", []),
		["\"idle\"", "\"run\"", "\"jump\""]) and passed
	var bare_directives: Array[String] = ["@ace_param_autocomplete(dir north, south, east)"]
	passed = _check("annotation parses unquoted suggestions",
		(analyzer._build_overrides(bare_directives).get("param_autocomplete", {}) as Dictionary).get("dir", []),
		["north", "south", "east"]) and passed

	# ── 2. Generator carries autocomplete into the param definition dict ────────────
	var generator := EventSheetACEGenerator.new()
	var defs: Array = generator._build_parameter_definitions([{"name": "anim", "type": TYPE_STRING}],
		{"param_autocomplete": {"anim": ["\"idle\"", "\"run\""]}})
	passed = _check("generator param dict carries autocomplete",
		(defs[0] as Dictionary).get("autocomplete", []), ["\"idle\"", "\"run\""]) and passed
	var plain_defs: Array = generator._build_parameter_definitions([{"name": "x", "type": TYPE_INT}], {})
	passed = _check("a plain param gets an empty autocomplete list (not missing)",
		(plain_defs[0] as Dictionary).get("autocomplete", "MISSING"), []) and passed

	# ── 3. make_param + adapter round-trip (the builtin/descriptor path) ───────────
	var param: ACEParam = F.make_param("anim", "String", "\"idle\"", "Animation", "Anim name.", "", [], ["\"idle\"", "\"run\""])
	var expected_suggestions: Array[String] = ["\"idle\"", "\"run\""]
	passed = _check("make_param stores autocomplete suggestions", param.autocomplete, expected_suggestions) and passed
	var mapped: Array = EventSheetACEAdapter._map_params([param] as Array[ACEParam])
	passed = _check("adapter exposes autocomplete on the param dict",
		(mapped[0] as Dictionary).get("autocomplete", []), ["\"idle\"", "\"run\""]) and passed

	# ── 4. Params-dialog widget: LineEdit value field + filtered popup ─────────────
	var dialog := ACEParamsDialog.new()
	var field: Control = dialog._create_autocomplete_field("anim", ["\"idle\"", "\"run\"", "\"jump\""], "\"idle\"")
	var stored: Variant = dialog._fields.get("anim", null)
	passed = _check("the value field is a LineEdit (free text, read like any text field)", stored is LineEdit, true) and passed
	passed = _check("the field seeds the current value",
		(stored as LineEdit).text if stored is LineEdit else "", "\"idle\"") and passed
	var popup := PopupMenu.new()
	dialog._rebuild_autocomplete_popup(popup, PackedStringArray(["\"idle\"", "\"run\"", "\"jump\""]), "ru")
	passed = _check("popup filters to case-insensitive substring matches", popup.item_count, 1) and passed
	passed = _check("a filtered item's id is its index in the FULL list", popup.get_item_id(0), 1) and passed
	dialog._rebuild_autocomplete_popup(popup, PackedStringArray(["\"idle\"", "\"run\""]), "")
	passed = _check("an empty filter shows every suggestion", popup.item_count, 2) and passed
	dialog._rebuild_autocomplete_popup(popup, PackedStringArray(["\"idle\""]), "zzz")
	passed = _check("no match shows one disabled hint item",
		popup.item_count == 1 and popup.is_item_disabled(0), true) and passed
	popup.free()
	field.free()
	# dialog is RefCounted — it auto-frees; calling .free() on it would error.

	# ── 5. New collection / vector / string Helper ACEs (parity one-liners) ─────────
	var by_id: Dictionary = {}
	for descriptor in EventForgeCollectionACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	var expected_templates: Array = [
		["ArrayFront", "{var_name}.front()"],
		["ArrayPopBack", "{var_name}.pop_back()"],
		["ArrayJoin", "{separator}.join({var_name})"],
		["ArrayAppendArray", "{var_name}.append_array({other})"],
		["DictDuplicate", "{var_name}.duplicate()"],
		["DictHasValue", "{var_name}.values().has({value})"],
		["MakeVector2", "Vector2({x}, {y})"],
		["VectorDistanceTo", "{a}.distance_to({b})"],
		["VectorLerp", "{a}.lerp({b}, {weight})"],
		["StringContains", "{text}.contains({needle})"],
		["StringSplit", "{text}.split({separator})"],
		["StringPadZeros", "str({number}).pad_zeros({digits})"],
	]
	for spec in expected_templates:
		var descriptor: ACEDescriptor = by_id.get(spec[0], null)
		passed = _check("helper %s registered with its direct one-liner" % spec[0],
			descriptor != null and descriptor.codegen_template == spec[1], true) and passed

	return passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_autocomplete_test: %s" % label)
		return true
	print("[FAIL] ace_autocomplete_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
