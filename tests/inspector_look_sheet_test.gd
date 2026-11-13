@tool
class_name InspectorLookSheetTest
extends RefCounted

# Godot EventSheets - a look opened as a sheet reads as triggers, and writes its file back byte for byte.
#
# A script that extends EventSheetInspectorLook has three functions Godot's Inspector calls. Opened as a
# sheet they read "On look built", "On value shown" and "On value changed from outside"; the rows that go
# with them (set the value, take the focus, read the value) are offered on such a sheet and on no other.
# Everything here is text in and text out, because an EditorProperty cannot be built outside the editor.

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "inspector_look_sheet_test"
const LOOK: String = """@tool
extends EventSheetInspectorLook

## Plain field
## Shows the value as text.

## The kinds of property this look can be put on.
@export var works_on: String = "int,float"

var _label: Label


func _look_built() -> void:
	_label = Label.new()
	add_child(_label)
	add_focusable(_label)


func _value_shown(value: Variant) -> void:
	_label.text = str(value)


func _value_changed_from_outside(value: Variant) -> void:
	set_field_value(value)
"""
const NOT_A_LOOK: String = """extends Node


func _look_built() -> void:
	print("mine")
"""


static func run() -> bool:
	var passed: bool = true
	passed = _the_three_callbacks_read_as_triggers() and passed
	passed = _the_file_comes_back_byte_for_byte() and passed
	passed = _the_same_header_elsewhere_is_an_ordinary_function() and passed
	passed = _the_rows_are_offered_on_a_look_sheet_only() and passed
	return passed


static func _trigger_ids(sheet: EventSheetResource) -> Array:
	var ids: Array = []
	for entry: Variant in sheet.events:
		if entry is EventRow:
			ids.append((entry as EventRow).trigger_id)
	return ids


static func _the_three_callbacks_read_as_triggers() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(LOOK, true, "res://eventsheet_addons/looks/plain_field.gd")
	var rows: Array = [
		["the sheet's host is the look base", sheet.host_class, "EventSheetInspectorLook"],
		["the three functions are triggers, in file order", _trigger_ids(sheet), ["OnLookBuilt", "OnValueShown", "OnValueChangedFromOutside"]],
	]
	var words: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		if descriptor.category == "Inspector Look":
			words[descriptor.ace_id] = descriptor.display_text
	rows.append(["each trigger has its sentence", words, {
		"OnLookBuilt": "On look built", "OnValueShown": "On value shown", "OnValueChangedFromOutside": "On value changed from outside"}])
	return SUPPORT.pins(NAME, rows)


static func _the_file_comes_back_byte_for_byte() -> bool:
	var path: String = "user://inspector_look_sheet_test.gd"
	var again: String = SUPPORT.reemit(LOOK, path)
	return SUPPORT.pins(NAME, [
		["a hand-written look re-emits unchanged", again == LOOK, true],
	])


static func _the_same_header_elsewhere_is_an_ordinary_function() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(NOT_A_LOOK, true, "res://elsewhere.gd")
	var path: String = "user://inspector_look_sheet_test_elsewhere.gd"
	return SUPPORT.pins(NAME, [
		["no trigger is read on a sheet that is not a look", _trigger_ids(sheet), []],
		["and the file still comes back unchanged", SUPPORT.reemit(NOT_A_LOOK, path) == NOT_A_LOOK, true],
	])


static func _the_rows_are_offered_on_a_look_sheet_only() -> bool:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var offered_on_look: Array = []
	var offered_elsewhere: Array = []
	var shelf: int = 0
	var plain: String = ""
	for definition: ACEDefinition in registry.get_all_definitions():
		if EventSheetPickerGates.is_look_row(definition):
			shelf += 1
			if EventSheetPickerGates.hidden_reason(definition, {EventSheetPickerGates.IN_LOOK_SHEET: true}).is_empty():
				offered_on_look.append(definition.id)
			if EventSheetPickerGates.hidden_reason(definition, {EventSheetPickerGates.IN_LOOK_SHEET: false}).is_empty():
				offered_elsewhere.append(definition.id)
		elif definition.id == "SetVar":
			plain = EventSheetPickerGates.hidden_reason(definition, {EventSheetPickerGates.IN_LOOK_SHEET: false})
	return SUPPORT.pins(NAME + ": picker", [
		["three rows are on the shelf", shelf, 3],
		["every one is offered on a look sheet", offered_on_look.size(), 3],
		["none is offered on any other", offered_elsewhere, []],
		["its reason is a named one", EventSheetPickerGates.HIDDEN_OUTSIDE_LOOK, "outside_inspector_look"],
		["an ordinary row is not touched", plain, ""],
	])
