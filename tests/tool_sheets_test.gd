# Godot EventSheets - Tool sheets (Phase D, EXPERIMENTAL)
# tool_mode emits @tool ahead of class_name/extends; the Editor Tool preset pairs an
# EditorScript host with the On Editor Run trigger (File > Run); generated tools
# verify-lift back and recover tool_mode on re-open.
@tool
class_name ToolSheetsTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true

	# @tool emission ordering on a custom-node sheet.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = true
	sheet.custom_class_name = "GizmoNode"
	sheet.host_class = "Node2D"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_tool.gd").get("output", ""))
	all_passed = _check("@tool emits before class_name",
		output.find("@tool") < output.find("class_name GizmoNode") and output.contains("@tool"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("tool output parses", generated.reload(true) == OK, true) and all_passed

	# Editor Tool: EditorScript host + On Editor Run -> func _run().
	var tool_sheet: EventSheetResource = EventSheetResource.new()
	tool_sheet.tool_mode = true
	tool_sheet.host_class = "EditorScript"
	var run_event: EventRow = EventRow.new()
	run_event.trigger_provider_id = "Core"
	run_event.trigger_id = "OnEditorRun"
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "PrintLog"
	act.codegen_template = "print({message})"
	act.params = {"message": "\"tool ran\""}
	run_event.actions.append(act)
	tool_sheet.events.append(run_event)
	var tool_output: String = str(SheetCompiler.compile(tool_sheet, "user://eventsheets_editor_tool.gd").get("output", ""))
	all_passed = _check("On Editor Run compiles to _run()",
		tool_output.contains("func _run() -> void:") and tool_output.contains("print(\"tool ran\")"), true) and all_passed
	var tool_script: GDScript = GDScript.new()
	tool_script.source_code = tool_output
	all_passed = _check("editor tool parses (extends EditorScript)", tool_script.reload(true) == OK, true) and all_passed

	# Registry: the trigger is in the picker under Editor Tools.
	var found: bool = false
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		if descriptor.ace_id == "OnEditorRun" and str(descriptor.category) == "Editor Tools":
			found = true
	all_passed = _check("On Editor Run trigger registered", found, true) and all_passed

	# Verify-lift: generated tools re-open as events; tool_mode recovers.
	var external_source: String = "@tool\nextends EditorScript\n\nfunc _run() -> void:\n\tprint(\"hello\")\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	var lifted: EventRow = null
	for row in imported.events:
		if row is EventRow:
			lifted = row
	all_passed = _check("_run lifts to On Editor Run", lifted != null and lifted.trigger_id == "OnEditorRun", true) and all_passed
	all_passed = _check("tool_mode recovers on re-open", imported.tool_mode, true) and all_passed
	imported.external_source_path = "user://eventsheets_tool_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventsheets_tool_rt.gd").get("output", ""))
	all_passed = _check("tool round-trip is byte-identical", roundtrip == external_source, true) and all_passed

	# Dialog: the Editor Tool preset applies host + tool_mode undoably.
	var dialog_sheet: EventSheetResource = EventSheetResource.new()
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(dialog_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._apply_sheet_type_settings(3, "MySceneTool", "", "", false)
	all_passed = _check("Editor Tool preset sets EditorScript + @tool",
		dialog_sheet.host_class == "EditorScript" and dialog_sheet.tool_mode and not dialog_sheet.behavior_mode, true) and all_passed
	editor._apply_sheet_type_settings(1, "GizmoNode", "", "Node2D", true)
	all_passed = _check("@tool checkbox works on other types",
		dialog_sheet.tool_mode and dialog_sheet.host_class == "Node2D", true) and all_passed
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tool_sheets_test: %s" % label)
		return true
	print("[FAIL] tool_sheets_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
