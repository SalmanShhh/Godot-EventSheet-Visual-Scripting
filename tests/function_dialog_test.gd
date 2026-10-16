# EventForge - the event-sheet-style function dialog. "Usable as" maps to the return type
# (Action→void / Condition→bool / Expression→typed value), parameters carry default + description,
# and "Run only when" guard expressions wrap the function body in an `if`. _apply_function_data
# builds the EventFunction; the compiler emits the default arg + the guard.
@tool
class_name FunctionDialogTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	# --- dialog build_function_data: kind → return type ---
	var parent: Node = Node.new()
	var dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	dialog.init_dialog(parent)
	dialog._name_edit.text = "compute_score"
	dialog._usable_option.select(2)        # Expression
	dialog._value_type_option.select(0)    # float
	var data: Dictionary = dialog.build_function_data()
	ok = _check("no validation problem", str(data.get("problem", "")), "") and ok
	ok = _check("Expression maps to a float return", int(data.get("return_type")), TYPE_FLOAT) and ok
	# A NEW function carries no picker metadata - description / display name / category are edited on
	# the row afterwards, so the payload reports them empty (nothing extra is emitted).
	ok = _check("a new function has no picker description", str(data.get("description")), "") and ok
	ok = _check("a new function has no display name", str(data.get("ace_display_name")), "") and ok
	ok = _check("a new function has no category", str(data.get("ace_category")), "") and ok
	dialog._usable_option.select(0)
	ok = _check("Action maps to void", int(dialog.build_function_data().get("return_type")), TYPE_NIL) and ok
	dialog._usable_option.select(1)
	ok = _check("Condition maps to bool", int(dialog.build_function_data().get("return_type")), TYPE_BOOL) and ok

	# The trailing-default rule now lives where parameters are actually authored - the focused param
	# dialog's apply path - so it is pinned there (see EventSheetFunctionDialogGlue._defaults_stay_trailing),
	# not here. This dialog never sees a parameter the user typed.
	parent.free()

	# --- dock _apply_function_data: builds the guarded function with a default param ---
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "Guard"
	dock.setup(sheet)
	dock._function_dialog_glue._apply_function_data({
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
	ok = _test_param_names_are_checked(dock) and ok
	dock.free()
	ok = _test_problems_said_while_typing() and ok
	ok = _test_preview_names_the_real_shelf() and ok

	return ok


## A parameter name lands verbatim in the generated `func` line, so one that is not an identifier,
## or one a sibling already uses, is refused before it reaches the sheet - in the dialog, which stays
## open on the typing, and again at the apply for a caller that skips the dialog.
static func _test_param_names_are_checked(dock: EventSheetDock) -> bool:
	var ok: bool = true
	var glue: EventSheetFunctionDialogGlue = dock._function_dialog_glue
	var live_params: Callable = func() -> Array:
		var names: Array = []
		for fn: Variant in dock._current_sheet.functions:
			if (fn as EventFunction).function_name == "act":
				for param: ACEParam in (fn as EventFunction).params:
					names.append(param.id)
		return names
	ok = _check("a spaced name is refused with the way to write it",
		EventSheetParamDialog.param_name_problem("move speed", PackedStringArray()),
		"\"move speed\" can't be a parameter name - use letters, digits and underscores (move_speed, not move speed), and not a GDScript keyword.") and ok
	ok = _check("a keyword is refused", EventSheetParamDialog.param_name_problem("class", PackedStringArray()).is_empty(), false) and ok
	ok = _check("a second input of the same name is refused",
		EventSheetParamDialog.param_name_problem("amount", PackedStringArray(["amount"])),
		"This function already has a parameter called \"amount\".") and ok
	ok = _check("a good name passes", EventSheetParamDialog.param_name_problem("move_speed", PackedStringArray(["amount"])), "") and ok
	glue._apply_param_edit({"function": "act", "index": -1, "id": "move speed", "type_name": "float", "default": "", "description": "", "removed": false})
	ok = _check("the apply never stores a spaced name", live_params.call(), ["amount"]) and ok
	glue._apply_param_edit({"function": "act", "index": -1, "id": "amount", "type_name": "float", "default": "", "description": "", "removed": false})
	ok = _check("nor a duplicate", live_params.call(), ["amount"]) and ok
	# Renaming a parameter to its OWN current name is not a duplicate.
	glue._apply_param_edit({"function": "act", "index": 0, "id": "amount", "type_name": "int", "default": "5", "description": "How much more", "removed": false})
	ok = _check("a parameter keeps its own name through an edit",
		((dock._current_sheet.functions[0] as EventFunction).params[0] as ACEParam).description, "How much more") and ok
	# The dialog itself: a refused name stays in the open form, with the reason under it.
	glue._ensure_param_dialog()
	var param_dialog: EventSheetParamDialog = glue._param_dialog
	ok = _check("Apply does not close the parameter dialog by itself", param_dialog._dialog.dialog_hide_on_ok, false) and ok
	param_dialog._function_name = "act"
	param_dialog._param_index = -1
	param_dialog._taken_param_names = PackedStringArray(["amount"])
	param_dialog._delete_button.visible = false
	param_dialog._name_edit.text = "move speed"
	var emitted: Array = []
	param_dialog.param_confirmed.connect(func(data: Dictionary) -> void: emitted.append(data))
	param_dialog._on_confirmed()
	ok = _check("a refused name emits nothing", emitted.size(), 0) and ok
	ok = _check("and says why inside the dialog", param_dialog._problem_label.visible, true) and ok
	ok = _check("the typed name survives the refusal", param_dialog._name_edit.text, "move speed") and ok
	param_dialog._name_edit.text = "move_speed"
	param_dialog._on_confirmed()
	ok = _check("a good name goes through", emitted.size(), 1) and ok
	return ok


## The function dialog judges the name as it is typed, and OK never closes on a refused one.
static func _test_problems_said_while_typing() -> bool:
	var ok: bool = true
	var parent: Node = Node.new()
	var dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	dialog.init_dialog(parent)
	ok = _check("OK does not close the function dialog by itself", dialog._dialog.dialog_hide_on_ok, false) and ok
	dialog._name_edit.text = "1st"
	dialog._refresh_studio()
	ok = _check("a bad name is said while typing", dialog._problem_label.text,
		"✗ Function names must be valid identifiers (e.g. take_damage).") and ok
	ok = _check("and shown", dialog._problem_label.visible, true) and ok
	dialog._name_edit.text = "take_damage"
	dialog._refresh_studio()
	ok = _check("a good one clears it", dialog._problem_label.visible, false) and ok
	dialog._name_edit.text = ""
	dialog._refresh_studio()
	ok = _check("an empty name is not judged yet", dialog._problem_label.visible, false) and ok
	parent.free()
	return ok


## The preview's shelf is the one the picker will really use - never a "(this behaviour)" placeholder.
static func _test_preview_names_the_real_shelf() -> bool:
	var ok: bool = true
	var parent: Node = Node.new()
	var dialog: EventSheetFunctionDialog = EventSheetFunctionDialog.new()
	dialog.init_dialog(parent)
	dialog._name_edit.text = "Take Damage"
	dialog._refresh_studio()
	ok = _check("an uncategorised function lands on the shelf the picker infers",
		dialog._preview_sub.text, "Combat › Take Damage") and ok
	dialog.set_sheet_category_context("Health")
	dialog._refresh_studio()
	ok = _check("a class-level category wins over the inferred one", dialog._preview_sub.text, "Health › Take Damage") and ok
	parent.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("function_dialog_test", label, actual, expected)
