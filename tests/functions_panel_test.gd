# EventForge - the Functions overview panel. Now its OWN dockable left-rail panel (it used to be
# welded inside the Generated-GDScript side panel, so seeing your functions meant opening the code
# view): a fold header ("▸ Functions · N") expands on demand, ＋ adds a function, every sheet
# function shows its signature (✦ = exposed as an ACE), right-click deletes one, and the collapsed
# header still carries the count so the sheet's weight reads without expanding.
@tool
class_name FunctionsPanelTest
extends RefCounted


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

	# ── Independent of the code view: the panel lives in the left rail, populated on setup ──
	ok = _check("the panel exists WITHOUT the GDScript view open", dock._functions_panel != null and dock._side_panel == null, true) and ok
	ok = _check("it is docked in the left rail", dock._workspace_body.is_ancestor_of(dock._functions_panel), true) and ok
	ok = _check("panel lists both functions", dock._functions_list.item_count, 2) and ok
	ok = _check("signature shows the parameter", dock._functions_list.get_item_text(0), "do_thing(amount)") and ok
	ok = _check("exposed function gets the badge", dock._functions_list.get_item_text(1).ends_with("✦"), true) and ok

	# ── Fold behaviour: collapsed header still tells the count; expanding shows the list ──
	dock._functions_panel.set_expanded(false)
	ok = _check("collapsed hides the list", dock._functions_list.visible, false) and ok
	ok = _check("the collapsed header still carries the count",
		dock._functions_panel._header_button.text.contains("Functions · 2"), true) and ok
	dock._functions_panel.set_expanded(true)
	ok = _check("expanding shows the list", dock._functions_list.visible, true) and ok

	# ── Right-click delete removes it from the sheet (undoable) and refreshes list + count ──
	dock._functions_list.select(0)
	dock._delete_selected_function()
	ok = _check("delete removes the function from the sheet", sheet.functions.size(), 1) and ok
	ok = _check("list refreshes after delete", dock._functions_list.item_count, 1) and ok
	ok = _check("the remaining function is the survivor", (sheet.functions[0] as EventFunction).function_name, "compute") and ok
	ok = _check("the header count follows", dock._functions_panel._header_button.text.contains("Functions · 1"), true) and ok

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
