# Godot EventSheets - the object column of a list row names the list.
#
# A "Variables: Array" row is about one list, so the column that names what a row acts on reads
# `undo_stack | Pop back of undo_stack into last` where it used to read System. The name is the one the
# row writes (`undo_stack`, `$Enemy.draw_pile`), the row wears the variable mark, and only the reading
# moves: the ids and templates are the ones they always were, so the file is byte for byte unchanged.
@tool
class_name ArrayObjectColumnTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "array_object_column"

const SOURCE := """extends Node

var undo_stack: Array[Vector2i] = []
var redo_stack: Array[Vector2i] = []


func _process(_delta: float) -> void:
	if not undo_stack.is_empty():
		var last = undo_stack.pop_back()
		redo_stack.append(last)
		$Enemy.draw_pile.clear()
		print("done")
"""


static func _objects_of(sheet: EventSheetResource) -> Array:
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	var objects: Array = []
	var flat: Array[Dictionary] = view.get_flat_rows()
	for index: int in flat.size():
		var row_data: EventRowData = flat[index].get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		view._layout_builder.get_or_build_row_layout(index, view.get_canvas_logical_width(), view._get_font(), view._get_font_size())
		for span: EventSheetSemanticSpan in view._row_at(index).spans:
			if span.metadata is Dictionary and str(span.metadata.get("kind", "")) in ["condition", "action"] 					and not str(span.metadata.get("object_label", "")).is_empty():
				objects.append([str(span.metadata.get("kind", "")), str(span.metadata.get("object_label", "")),
					str(span.metadata.get("object_glyph", ""))])
	view.free()
	return objects


static func run() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	sheet.external_source_path = "user://array_object_column.gd"
	var opened: Array = _objects_of(sheet).filter(func(entry: Array) -> bool: return entry[2] == "local")
	var built: EventSheetResource = EventSheetResource.new()
	built.host_class = "Node"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnProcess"
	var test: ACECondition = ACECondition.new()
	test.provider_id = "Core"
	test.ace_id = "ArrayIsEmpty"
	test.params = {"var_name": "undo_stack"}
	event_row.conditions.append(test)
	var clear: ACEAction = ACEAction.new()
	clear.provider_id = "Core"
	clear.ace_id = "ArrayClear"
	clear.params = {"var_name": "$Enemy.draw_pile"}
	event_row.actions.append(clear)
	var other: ACEAction = ACEAction.new()
	other.provider_id = "Core"
	other.ace_id = "PrintMessage"
	other.params = {"text": "\"x\""}
	event_row.actions.append(other)
	built.events.append(event_row)
	var picked: Array = _objects_of(built)
	return SUPPORT.pins(NAME, [
		["the opened sheet round-trips", SUPPORT.compile_output(sheet, "user://array_object_column_out.gd"), SOURCE],
		["opened list rows name their list in the object column, with the variable mark", opened,
			[["action", "undo_stack", "local"], ["action", "redo_stack", "local"]]],
		["a picked list condition and another object's list read the same way",
			picked.filter(func(entry: Array) -> bool: return entry[2] == "local"),
			[["condition", "undo_stack", "local"], ["action", "$Enemy.draw_pile", "local"]]],
		["a row about something else keeps its own object", picked.filter(func(entry: Array) -> bool: return entry[2] != "local").size() >= 1, true],
	])
