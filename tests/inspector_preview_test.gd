# Godot EventSheets - the Inspector preview card's plain-words summary. It is
# the beginner-facing statement of what the Inspector will show, so it is pinned
# as EXACT STRINGS across a matrix of attribute combinations - a wording drift is
# a test failure, not a surprise. One whole sentence per fact, so each sentence
# translates as a sentence rather than as a fragment of an English one.
@tool
class_name InspectorPreviewTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _pin("plain exported int", "int", {}, true, false,
		"A whole number.") and ok
	ok = _pin("range + progress bar + grouping", "int",
		{"range": {"min": "0", "max": "100"}, "drawer": "progress_bar", "group": "Combat", "subgroup": "Defense"}, true, false,
		"A whole number. It runs from 0 to 100. Shown as a progress bar. It is grouped under Combat > Defense.") and ok
	ok = _pin("range alone reads as a slider", "float",
		{"range": {"min": "0", "max": "1"}}, true, false,
		"A number. It runs from 0 to 1. Shown as a slider.") and ok
	ok = _pin("or_greater + suffix", "int",
		{"range": {"min": "0", "max": "300", "or_greater": true, "suffix": "px"}}, true, false,
		"A whole number. It runs from 0 to 300 px or more. Shown as a slider.") and ok
	ok = _pin("flags", "int", {"flags": [{"label": "Fire", "value": "1"}]}, true, false,
		"A whole number. Shown as checkbox flags.") and ok
	ok = _pin("folder picker", "String", {"file": {"mode": "dir", "global": false}}, true, false,
		"Text. Picked with a folder picker.") and ok
	ok = _pin("multiline text", "String", {"multiline": true}, true, false,
		"Text. Edited in a big text box.") and ok
	ok = _pin("clamped + read-only", "float",
		{"range": {"min": "0", "max": "10"}, "clamp": true, "read_only": true}, true, false,
		"A number. It runs from 0 to 10. Shown as a slider. It is clamped to the range. It is read-only.") and ok
	ok = _pin("storage overrides the tail", "int", {"storage": true, "group": "Combat"}, true, false,
		"A whole number. It is saved with the scene but hidden in the Inspector.") and ok
	ok = _pin("not exported", "int", {}, false, false,
		"Only the sheet uses it - it does not appear in the Inspector.") and ok
	ok = _pin("constant", "int", {}, true, true,
		"A constant - fixed while the game runs, not editable in the Inspector.") and ok

	# In the editor's language: every sentence is a whole one in the catalogs.
	var before_locale: String = EventSheetL10n.get_locale()
	EventSheetL10n.set_locale("de")
	ok = _pin("German reads whole German sentences", "int",
		{"range": {"min": "0", "max": "100"}, "drawer": "progress_bar", "group": "Combat"}, true, false,
		"Eine ganze Zahl. Sie reicht von 0 bis 100. Als Fortschrittsbalken angezeigt. Sie ist unter Combat gruppiert.") and ok
	EventSheetL10n.set_locale("ja")
	ok = _pin("Japanese sentences meet without a space", "int", {"flags": [{"label": "Fire", "value": "1"}]}, true, false,
		"整数。チェックボックスのフラグとして表示されます。") and ok
	EventSheetL10n.set_locale(before_locale)

	# The card mock itself: exported shows rows; unexported hides the card.
	var card := EventSheetInspectorPreviewCard.new()
	card.update_preview("max_health", "int", "100", {"group": "Combat"}, true, false)
	ok = _check("exported variable shows the card", card.visible, true) and ok
	card.update_preview("max_health", "int", "100", {}, false, false)
	ok = _check("unexported variable hides the card", card.visible, false) and ok

	# The mock draws the variable's OWN value inside its own bounds, never a fixed sample.
	var range_spec: Dictionary = {"range": {"min": "0", "max": "200"}}
	var slider: Range = _widget(card, "int", "100", range_spec)
	ok = _check("a range slider sits at the value, within the bounds",
		[slider.min_value, slider.max_value, slider.value], [0.0, 200.0, 100.0]) and ok
	var bar: Range = _widget(card, "int", "30", {"range": {"min": "0", "max": "50"}, "drawer": "progress_bar"})
	ok = _check("a progress bar fills to the value", [bar.max_value, bar.value], [50.0, 30.0]) and ok
	var flags: Control = _widget(card, "int", "2", {"flags": [{"label": "Fire"}, {"label": "Ice"}, {"label": "Poison"}]})
	ok = _check("flags tick the value's own bits under the variable's own names",
		flags.get_children().map(func(check: CheckBox) -> Array: return [check.text, check.button_pressed]),
		[["Fire", false], ["Ice", true], ["Poison", false]]) and ok
	var choices: Control = _widget(card, "int", "31", {"enum_values": [{"label": "Slow", "value": "30"}, {"label": "Fast"}]})
	var chosen: OptionButton = choices.get_child(0) as OptionButton
	ok = _check("number choices show the chosen name", chosen.get_item_text(chosen.selected), "Fast") and ok
	var swatch: ColorRect = _widget(card, "Color", "Color(1, 0, 0, 1)", {})
	ok = _check("a colour shows its own colour", swatch.color, Color(1, 0, 0, 1)) and ok
	var path_row: Control = _widget(card, "String", "\"res://sfx/hit.ogg\"", {"file": {"mode": "file"}})
	ok = _check("a file look holds the variable's own path", (path_row.get_child(0) as LineEdit).text, "res://sfx/hit.ogg") and ok
	card.free()
	return ok


## The widget the card draws for one variable: the last control on its property row.
static func _widget(card: EventSheetInspectorPreviewCard, type_name: String, default_text: String, attributes: Dictionary) -> Control:
	card.update_preview("value", type_name, default_text, attributes, true, false)
	var property_row: Node = card._rows.get_child(card._rows.get_child_count() - 1)
	return property_row.get_child(property_row.get_child_count() - 1) as Control


static func _pin(label: String, type_name: String, attributes: Dictionary, exported: bool, constant: bool, expected: String) -> bool:
	return _check(label, EventSheetInspectorPreviewCard.describe(type_name, attributes, exported, constant), expected)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("inspector_preview_test", label, actual, expected)
