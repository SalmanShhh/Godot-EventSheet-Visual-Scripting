# EventForge — the Functions overview panel (Construct's function list). Every sheet function shows
# at a glance with its signature (and an ✦ when exposed as an ACE); right-click deletes one.
@tool
extends RefCounted
class_name FunctionsPanelTest

static func run() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())

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
	sheet.functions.append(with_param)
	sheet.functions.append(exposed)

	dock.setup(sheet)
	dock._ensure_code_panel()
	dock._side_panel.visible = true
	dock._refresh_functions_list()

	ok = _check("panel lists both functions", dock._functions_list.item_count, 2) and ok
	ok = _check("signature shows the parameter", dock._functions_list.get_item_text(0), "do_thing(amount)") and ok
	ok = _check("exposed function gets the badge", dock._functions_list.get_item_text(1).ends_with("✦"), true) and ok

	# Right-click delete removes it from the sheet (undoable) and refreshes the list.
	dock._functions_list.select(0)
	dock._delete_selected_function()
	ok = _check("delete removes the function from the sheet", sheet.functions.size(), 1) and ok
	ok = _check("list refreshes after delete", dock._functions_list.item_count, 1) and ok
	ok = _check("the remaining function is the survivor", (sheet.functions[0] as EventFunction).function_name, "compute") and ok

	dock.free()
	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] functions_panel_test: %s" % label)
		return true
	print("[FAIL] functions_panel_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
