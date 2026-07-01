@tool
extends RefCounted
class_name EventSheetFunctionDialogGlue
# The Add-sheet-Function dialog glue (Add ▾ → Function…).
#
# Owns the lazy construction + wiring of the sheet-function dialog and its apply-to-sheet:
#   • lazily builds the EventSheetFunctionDialog widget (the name/params/return popup — it lives in
#     editor/function_dialog.gd), feeds it the "taken names" provider (existing variables + function
#     names, so the dialog blocks collisions), and connects its function_confirmed signal,
#   • _apply_function_data: turns the validated dialog payload into an EventFunction on the sheet
#     (undoable). Its "Run only when" guards become Expression-Is-True conditions on a wrapper row
#     the body is authored under; the body itself is authored as rows afterwards, and CallFunction
#     plus the publish surface pick the function up.
#
# NAMING: the widget already claims the class name EventSheetFunctionDialog (editor/function_dialog.gd),
# so this glue helper is EventSheetFunctionDialogGlue — mirroring the EventSheetPreviewGlue sibling.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • `_ensure_sheet_for_editing` (open/adopt a sheet before authoring),
#   • the active-sheet state (`_current_sheet`),
#   • the mutation funnel (`_perform_undoable_sheet_edit` / `_mark_dirty`),
#   • `init_dialog(_dock)` — the widget takes the DOCK (a Control it parents its popup under), not
#     this detached RefCounted helper.
# Globals (EventSheetFunctionDialog widget, EventFunction, ACEParam, EventRow, ACECondition) are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures) for BOTH methods: the in-file
# Add-Function button + menu_bar Add menu (id 3) + command palette reach `_open_function_dialog`, and
# the function_dialog + godot_workflow tests call `_apply_function_data` directly — so they resolve
# unchanged. The `_function_dialog` widget instance is internal to this helper (no external reader).
#
# CLOSURE NOTES:
#   • the taken-names provider lambda captures no helper/dock member other than `_dock` — it reads
#     `_dock._current_sheet` live at call time,
#   • the `_apply_function_data` undoable lambda captures the LOCAL `data` (the payload) plus `_dock`;
#     the built EventFunction / params / guard rows are locals — so it survives verbatim, only the
#     `_current_sheet` reach-in changed to `_dock._current_sheet`.

var _dock: Control = null

func init(dock: Control) -> void:
	_dock = dock

# ── Sheet functions: the dialog with the expanding param list (Add ▾ → Function…) ────
var _function_dialog: EventSheetFunctionDialog = null

func _open_function_dialog() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	if _function_dialog == null:
		_function_dialog = EventSheetFunctionDialog.new()
		_function_dialog.init_dialog(_dock)
		_function_dialog.set_taken_names_provider(func() -> PackedStringArray:
			var taken: PackedStringArray = PackedStringArray()
			if _dock._current_sheet != null:
				for variable_name: Variant in _dock._current_sheet.variables:
					taken.append(str(variable_name))
				for function_entry: Variant in _dock._current_sheet.functions:
					if function_entry is EventFunction:
						taken.append((function_entry as EventFunction).function_name)
			return taken)
		_function_dialog.function_confirmed.connect(_apply_function_data)
	_function_dialog.open()

## Creates the EventFunction from validated dialog data (undoable). The body is
## authored as rows afterwards; CallFunction and the publish surface pick it up.
func _apply_function_data(data: Dictionary) -> void:
	var changed: bool = _dock._perform_undoable_sheet_edit("Add Function", func() -> bool:
		var event_function: EventFunction = EventFunction.new()
		event_function.function_name = str(data.get("name"))
		event_function.return_type = int(data.get("return_type", TYPE_NIL))
		event_function.description = str(data.get("description", ""))
		for param_entry: Dictionary in (data.get("params", []) as Array):
			var param: ACEParam = ACEParam.new()
			param.id = str(param_entry.get("id"))
			param.type_name = str(param_entry.get("type_name", "Variant"))
			param.gdscript_default = str(param_entry.get("default", ""))
			param.description = str(param_entry.get("description", ""))
			event_function.params.append(param)
		event_function.expose_as_ace = bool(data.get("expose", false))
		event_function.ace_display_name = str(data.get("ace_display_name", ""))
		event_function.ace_category = str(data.get("ace_category", ""))
		# "Run only when" guards: the body runs inside an `if <guards>:` — an event-sheet-style
		# function gate (e.g. only act when a node setting is enabled). Each expression becomes an
		# Expression Is True condition on a wrapper row the body actions are authored under.
		var guards: PackedStringArray = PackedStringArray(data.get("guards", PackedStringArray()))
		if not guards.is_empty():
			var guard_row: EventRow = EventRow.new()
			for guard_expression: String in guards:
				var condition: ACECondition = ACECondition.new()
				condition.provider_id = "Core"
				condition.ace_id = "ExpressionIsTrue"
				condition.params = {"expr": guard_expression}
				guard_row.conditions.append(condition)
			event_function.events.append(guard_row)
		_dock._current_sheet.functions.append(event_function)
		return true)
	if changed:
		_dock._mark_dirty("Added function %s()." % str(data.get("name")))
