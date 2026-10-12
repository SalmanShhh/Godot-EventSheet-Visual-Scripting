extends RefCounted

# EventForge - Text From Pattern's values field fills itself from the {names} in its pattern.
#
# A reader who writes "{player} scored {score}!" should not then have to type the same two names again
# as dictionary keys. What these pins hold:
#   1. the slots are read off a quoted pattern in order, once each, and a pattern held in a variable
#      says nothing;
#   2. the dictionary keeps every value the field already gave a name it still uses, names the
#      variable of the same name for a new slot, and drops a key the pattern no longer asks for;
#   3. the field is left alone when it holds something that is not a plain dictionary - a variable,
#      a call - because that is the reader's own answer;
#   4. in the dialog, typing into the pattern rewrites the values field, read off the row's template.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = _the_slots()
	ok = _the_dictionary() and ok
	ok = _in_the_dialog() and ok
	return ok


static func _the_slots() -> bool:
	return SUPPORT.pins("pattern_values_fill_test", [
		["in order, once each", ACEParamsDialog.pattern_slot_names("\"{player} hit {enemy}, {player} wins\""),
			PackedStringArray(["player", "enemy"])],
		["a pattern held in a variable says nothing", ACEParamsDialog.pattern_slot_names("greeting"), PackedStringArray()],
		["a brace that is not a name is not a slot", ACEParamsDialog.pattern_slot_names("\"{} and {1}\""), PackedStringArray()],
	])


static func _the_dictionary() -> bool:
	return SUPPORT.pins("pattern_values_fill_test", [
		["the default's value is kept, the new slot names its variable",
			ACEParamsDialog.values_for_pattern("\"{player} scored {score}!\"", "{\"score\": 100}"),
			"{\"player\": player, \"score\": 100}"],
		["an empty field is filled", ACEParamsDialog.values_for_pattern("\"{hp}\"", ""), "{\"hp\": hp}"],
		["a key the pattern dropped goes", ACEParamsDialog.values_for_pattern("\"{hp}\"", "{\"hp\": health, \"mp\": mana}"),
			"{\"hp\": health}"],
		["a value with commas inside stays whole",
			ACEParamsDialog.values_for_pattern("\"{at} {who}\"", "{\"at\": Vector2(1, 2)}"),
			"{\"at\": Vector2(1, 2), \"who\": who}"],
		["a field that already says it is left alone", ACEParamsDialog.values_for_pattern("\"{hp}\"", "{\"hp\": hp}"), ""],
		["a variable is the reader's own answer", ACEParamsDialog.values_for_pattern("\"{hp}\"", "stats"), ""],
		["a pattern with no slot leaves the field alone", ACEParamsDialog.values_for_pattern("\"Game over\"", "{}"), ""],
	])


static func _in_the_dialog() -> bool:
	var definition: ACEDefinition = null
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	definition = registry.find_definition("Core", "TextFromPattern")
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog._definition = definition
	var form: VBoxContainer = VBoxContainer.new()
	dialog._form = form
	dialog._build_form(definition, {})
	var pattern: CodeEdit = dialog._fields.get("pattern") as CodeEdit
	var values: CodeEdit = dialog._fields.get("values") as CodeEdit
	var opened: String = values.text
	pattern.text = "\"{player} scored {score}!\""
	pattern.text_changed.emit()
	var ok: bool = SUPPORT.pins("pattern_values_fill_test", [
		["the form opens on the row's own default", opened, "{\"score\": 100}"],
		["typing the pattern fills the values", values.text, "{\"player\": player, \"score\": 100}"],
	])
	form.free()
	return ok
