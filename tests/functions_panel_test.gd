# EventForge - the Functions tab of the side panel (functions_panel.gd). Every function in the file
# at a glance, drawn the way Godot's own docks are: a filter with ＋ beside it, then plain rows with
# a name and a count - the sheet's own functions first (✦ = published as an ACE) with how many times
# the file calls them, then the functions still written as code, marked "code". Right-click deletes
# a sheet function (undoable), and the rows follow.
@tool
class_name FunctionsPanelTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _rows_of_a_sheet() and ok
	ok = _the_built_tab() and ok
	return ok


## The rows a sheet reads as: name, count, and which kind - pure, so no editor is needed.
static func _rows_of_a_sheet() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet()
	var rows: Array = EventSheetFunctionsPanel.function_rows(sheet)
	var read: Array = []
	for row: Dictionary in rows:
		read.append([row.get("kind"), row.get("label"), row.get("count")])
	ok = _check("sheet functions first, then the ones written as code, each with its count", read, [
		["sheet", "do_thing", "2 calls"],
		["sheet", "compute  ✦", ""],
		["sheet", "juice_tile", "1 call"],
		["code", "_process", "code"],
		["code", "_physics_process", "code"],
	]) and ok
	ok = _check("a sheet function's hover opens with its signature",
		str((rows[0] as Dictionary).get("tooltip", "")).get_slice("\n", 0), "do_thing(amount)") and ok
	ok = _check("the definition line is not a call, and a comment is not either",
		EventSheetFunctionsPanel.call_count(sheet, "juice_tile", PackedStringArray([
			"func juice_tile(index: int) -> void:\n\tpass  # juice_tile(1)"])), 0) and ok
	ok = _check("a method of something else with the same name is not this file's call",
		EventSheetFunctionsPanel.call_count(sheet, "juice_tile", PackedStringArray([
			"func _ready() -> void:\n\t$Other.juice_tile(1)\n\tjuice_tile(2)"])), 1) and ok
	return ok


## The tab as the dock builds it: filter, list, right-click delete.
static func _the_built_tab() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = _sheet()
	dock.setup(sheet)

	ok = _check("the tab exists WITHOUT the GDScript view open",
		[dock._functions_panel != null, dock._side_panel == null], [true, true]) and ok
	ok = _check("it sits in the side panel", dock._workspace_body.is_ancestor_of(dock._functions_panel), true) and ok
	ok = _check("its list is the rows above, name then count", _list_rows(dock._functions_list), [
		["do_thing", "2 calls"], ["compute  ✦", ""], ["juice_tile", "1 call"],
		["_process", "code"], ["_physics_process", "code"],
	]) and ok

	# The filter narrows by name.
	dock._functions_panel.filter_edit.text = "process"
	dock._functions_panel.filter_edit.text_changed.emit("process")
	ok = _check("the filter narrows the rows by name", _list_rows(dock._functions_list),
		[["_process", "code"], ["_physics_process", "code"]]) and ok
	dock._functions_panel.filter_edit.text_changed.emit("")

	# A function written as code is not a sheet function: nothing to delete.
	var code_item: TreeItem = dock._functions_list.get_root().get_child(3)
	code_item.select(0)
	ok = _check("a code row selects no sheet function", dock._functions_panel.selected_function_index(), -1) and ok

	# Right-click delete removes it from the sheet (undoable) and refreshes the rows.
	dock._functions_panel.select_function(0)
	dock._code_panel_glue.delete_selected_function()
	ok = _check("delete removes the function from the sheet",
		[sheet.functions.size(), (sheet.functions[0] as EventFunction).function_name], [2, "compute"]) and ok
	ok = _check("the rows follow", _list_rows(dock._functions_list), [
		["compute  ✦", ""], ["juice_tile", "1 call"], ["_process", "code"], ["_physics_process", "code"],
	]) and ok

	dock.free()
	return ok


## A sheet with three functions and two blocks of code: do_thing is called by two Call rows,
## juice_tile once from code, compute never.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var with_param: EventFunction = EventFunction.new()
	with_param.function_name = "do_thing"
	var param: ACEParam = ACEParam.new()
	param.id = "amount"
	param.type_name = "int"
	with_param.params.append(param)
	var exposed: EventFunction = EventFunction.new()
	exposed.function_name = "compute"
	exposed.expose_as_ace = true
	var juice: EventFunction = EventFunction.new()
	juice.function_name = "juice_tile"
	sheet.functions.append(with_param)
	sheet.functions.append(exposed)
	sheet.functions.append(juice)
	var event: EventRow = EventRow.new()
	event.actions.append(_call("do_thing"))
	var nested: EventRow = EventRow.new()
	nested.actions.append(_call("do_thing"))
	event.sub_events.append(nested)
	sheet.events.append(event)
	var process: RawCodeRow = RawCodeRow.new()
	process.code = "func _process(delta: float) -> void:\n\tjuice_tile(1, delta)"
	sheet.events.append(process)
	var physics: RawCodeRow = RawCodeRow.new()
	physics.code = "func _physics_process(delta: float) -> void:\n\tpass"
	sheet.events.append(physics)
	return sheet


static func _call(function_name: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "CallFunction"
	action.params = {"function_name": function_name}
	return action


static func _list_rows(list: Tree) -> Array:
	var rows: Array = []
	var item: TreeItem = list.get_root().get_first_child() if list.get_root() != null else null
	while item != null:
		rows.append([item.get_text(0).trim_prefix("ƒ  "), item.get_text(1)])
		item = item.get_next()
	return rows


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("functions_panel_test", label, actual, expected)
