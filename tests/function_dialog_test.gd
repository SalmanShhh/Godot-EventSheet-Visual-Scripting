# EventForge - the event-sheet-style function dialog. "Usable as" maps to the return type
# (Action→void / Condition→bool / Expression→typed value), parameters carry default + description,
# and "Run only when" guard expressions wrap the function body in an `if`. _apply_function_data
# builds the EventFunction; the compiler emits the default arg + the guard.
@tool
class_name FunctionDialogTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# --- dialog build_function_data: Usable-as → return type, params, guards ---
	var parent: Node = Node.new()
	var dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	dialog.init_dialog(parent)
	dialog._name_edit.text = "compute_score"
	dialog._description_edit.text = "Computes the score."
	dialog._usable_option.select(2)        # Expression
	dialog._value_type_option.select(0)    # float
	dialog.add_param_row("multiplier")
	dialog.add_guard_row("host.enabled")
	var data: Dictionary = dialog.build_function_data()
	ok = _check("no validation problem", str(data.get("problem", "")), "") and ok
	ok = _check("Expression maps to a float return", int(data.get("return_type")), TYPE_FLOAT) and ok
	ok = _check("function description captured", str(data.get("description")), "Computes the score.") and ok
	ok = _check("guard expression captured", PackedStringArray(data.get("guards")).has("host.enabled"), true) and ok
	dialog._usable_option.select(0)
	ok = _check("Action maps to void", int(dialog.build_function_data().get("return_type")), TYPE_NIL) and ok
	dialog._usable_option.select(1)
	ok = _check("Condition maps to bool", int(dialog.build_function_data().get("return_type")), TYPE_BOOL) and ok

	# A default value before a non-defaulted parameter is refused (GDScript trailing-default rule).
	dialog._usable_option.select(0)
	dialog.add_param_row("base")
	(dialog._params_box.get_child(0).get_child(2) as LineEdit).text = "2"  # multiplier gets a default; base doesn't
	ok = _check("non-trailing default is refused", not str(dialog.build_function_data().get("problem", "")).is_empty(), true) and ok
	parent.free()

	# --- dock _apply_function_data: builds the guarded function with a default param ---
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "Guard"
	dock.setup(sheet)
	dock._apply_function_data({
		"name": "act", "return_type": TYPE_NIL, "description": "",
		"params": [{"id": "amount", "type_name": "int", "default": "5", "description": "How much"}],
		"guards": PackedStringArray(["host.enabled"]),
		"expose": false, "ace_display_name": "", "ace_category": "",
	})
	var created: EventFunction = null
	for fn: Variant in sheet.functions:
		if (fn as EventFunction).function_name == "act":
			created = fn
	ok = _check("function created on the sheet", created != null, true) and ok
	ok = _check("parameter default stored", created != null and (created.params[0] as ACEParam).gdscript_default == "5", true) and ok
	ok = _check("parameter description stored", created != null and (created.params[0] as ACEParam).description == "How much", true) and ok
	var guarded: bool = created != null and created.events.size() == 1 and (created.events[0] as EventRow).conditions.size() == 1 \
		and (created.events[0] as EventRow).conditions[0].ace_id == "ExpressionIsTrue"
	ok = _check("a guard row with Expression Is True was added", guarded, true) and ok

	var output: String = str(SheetCompiler.compile(sheet, "user://fd_test.gd").get("output", ""))
	ok = _check("the default param compiles", output.contains("func act(amount: int = 5) -> void:"), true) and ok
	ok = _check("the guard compiles to an if", output.contains("\tif host.enabled:"), true) and ok
	dock.free()

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] function_dialog_test: %s" % label)
		return true
	print("[FAIL] function_dialog_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
