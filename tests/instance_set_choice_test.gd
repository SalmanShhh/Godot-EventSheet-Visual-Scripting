# Godot EventSheets - a pick row's From box can be filled from a group or a list, groups first.
@tool
class_name InstanceSetChoiceTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "instance_set_choice"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"targets": {"type": "Array[Node2D]", "default": [], "exported": false},
		"score": {"type": "int", "default": 0, "exported": false},
	}
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	dialog._variable_names = PackedStringArray(["targets", "score"])
	var choices: Array = dialog.instance_set_choices()
	var expressions: PackedStringArray = PackedStringArray()
	var first_list: int = -1
	var last_group: int = -1
	for index: int in choices.size():
		var expression: String = str((choices[index] as Array)[1])
		expressions.append(expression)
		if expression.begins_with("get_tree().get_nodes_in_group("):
			last_group = index
		elif first_list < 0:
			first_list = index
	var ok: bool = true
	ok = SUPPORT.check(NAME, "the sheet's own list is offered", expressions.has("targets"), true) and ok
	ok = SUPPORT.check(NAME, "a number is not a list", expressions.has("score"), false) and ok
	ok = SUPPORT.check(NAME, "every group comes before the first list", last_group < first_list or first_list < 0 or last_group < 0, true) and ok
	ok = SUPPORT.check(NAME, "the pick rows that take the box are the picking ones",
		[ACEParamsDialog.INSTANCE_SET_ACES.has("PickNearest"), ACEParamsDialog.INSTANCE_SET_ACES.has("PickWhere"), ACEParamsDialog.INSTANCE_SET_ACES.has("Delete")], [true, true, false]) and ok
	return ok
