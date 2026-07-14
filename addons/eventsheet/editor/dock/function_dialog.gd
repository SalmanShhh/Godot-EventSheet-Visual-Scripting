@tool
class_name EventSheetFunctionDialogGlue
extends RefCounted
# The Add-sheet-Function dialog glue (Add ▾ → Function…).
#
# Owns the lazy construction + wiring of the sheet-function dialog and its apply-to-sheet:
#   • lazily builds the EventSheetFunctionDialog widget (the name/params/return popup - it lives in
#     editor/function_dialog.gd), feeds it the "taken names" provider (existing variables + function
#     names, so the dialog blocks collisions), and connects its function_confirmed signal,
#   • _apply_function_data: turns the validated dialog payload into an EventFunction on the sheet
#     (undoable). Its "Run only when" guards become Expression-Is-True conditions on a wrapper row
#     the body is authored under; the body itself is authored as rows afterwards, and CallFunction
#     plus the publish surface pick the function up.
#
# NAMING: the widget already claims the class name EventSheetFunctionDialog (editor/function_dialog.gd),
# so this glue helper is EventSheetFunctionDialogGlue - mirroring the EventSheetPreviewGlue sibling.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • `_ensure_sheet_for_editing` (open/adopt a sheet before authoring),
#   • the active-sheet state (`_current_sheet`),
#   • the mutation funnel (`_perform_undoable_sheet_edit` / `_mark_dirty`),
#   • `init_dialog(_dock)` - the widget takes the DOCK (a Control it parents its popup under), not
#     this detached RefCounted helper.
# Globals (EventSheetFunctionDialog widget, EventFunction, ACEParam, EventRow, ACECondition) are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures) for BOTH methods: the in-file
# Add-Function button + menu_bar Add menu (id 3) + command palette reach `_open_function_dialog`, and
# the function_dialog + godot_workflow tests call `_apply_function_data` directly - so they resolve
# unchanged. The `_function_dialog` widget instance is internal to this helper (no external reader).
#
# CLOSURE NOTES:
#   • the taken-names provider lambda captures no helper/dock member other than `_dock` - it reads
#     `_dock._current_sheet` live at call time,
#   • the `_apply_function_data` undoable lambda captures the LOCAL `data` (the payload) plus `_dock`;
#     the built EventFunction / params / guard rows are locals - so it survives verbatim, only the
#     `_current_sheet` reach-in changed to `_dock._current_sheet`.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

# ── Sheet functions: the dialog with the expanding param list (Add ▾ → Function…) ────
var _function_dialog: EventSheetFunctionDialog = null


func _open_function_dialog() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_ensure_dialog()
	_function_dialog.open()


## Double-clicking a Define block on the canvas edits that verb in the same dialog (edit mode:
## pre-filled fields, the apply updates the existing function instead of appending a new one).
func _open_function_dialog_for(event_function: Resource) -> void:
	if not (event_function is EventFunction) or _dock._current_sheet == null:
		return
	_ensure_dialog()
	_function_dialog.open_for_edit(event_function as EventFunction)


## Right-click ▸ "Add Parameter" on a Define row: the same edit dialog, but pre-focused on a fresh
## parameter row so the user is naming the new argument immediately (nothing else has to be touched).
func _open_function_dialog_add_param(event_function: Resource) -> void:
	if not (event_function is EventFunction) or _dock._current_sheet == null:
		return
	_ensure_dialog()
	_function_dialog.open_for_edit_focus_new_param(event_function as EventFunction)


func _ensure_dialog() -> void:
	if _function_dialog != null:
		return
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


## Creates the EventFunction from validated dialog data (undoable). The body is
## authored as rows afterwards; CallFunction and the publish surface pick it up.
## A payload carrying a non-empty "editing" name updates that existing function instead.
func _apply_function_data(data: Dictionary) -> void:
	if not str(data.get("editing", "")).is_empty():
		_apply_function_edit(data)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Add Function", func() -> bool:
		var event_function: EventFunction = EventFunction.new()
		event_function.function_name = str(data.get("name"))
		event_function.return_type = int(data.get("return_type", TYPE_NIL))
		event_function.return_type_name = str(data.get("return_type_name", ""))
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
		# "Run only when" guards: the body runs inside an `if <guards>:` - an event-sheet-style
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


## Updates an existing function in place (undoable). The target is found by its ORIGINAL name in the
## LIVE sheet - never by a held object reference, because the undo funnel's commit restores a duplicated
## snapshot that replaces every resource. Only the dialog-owned fields are written; the body
## (events/local_variables) and the tool-button label stay untouched. Confirming with nothing changed
## returns false so the sheet is not dirtied - an accidental open-and-OK on a lifted helper stays
## byte-safe. Call sites are NOT rewritten on rename (same as renaming via the Functions dialog list).
func _apply_function_edit(data: Dictionary) -> void:
	var original_name: String = str(data.get("editing"))
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Function", func() -> bool:
		var target: EventFunction = null
		for function_entry: Variant in _dock._current_sheet.functions:
			if function_entry is EventFunction and (function_entry as EventFunction).function_name == original_name:
				target = function_entry as EventFunction
		if target == null:
			return false
		var new_params: Array[ACEParam] = []
		for param_entry: Dictionary in (data.get("params", []) as Array):
			var param: ACEParam = ACEParam.new()
			param.id = str(param_entry.get("id"))
			param.type_name = str(param_entry.get("type_name", "Variant"))
			param.gdscript_default = str(param_entry.get("default", ""))
			param.description = str(param_entry.get("description", ""))
			new_params.append(param)
		# build_function_data auto-defaults an empty display name to name.capitalize(); when the stored
		# value is empty, that default is NOT an edit - normalize it back so an untouched open-and-OK
		# compares equal (and stays byte-safe for reverse-lifted helpers).
		var incoming_display: String = str(data.get("ace_display_name", ""))
		if target.ace_display_name.is_empty() and incoming_display == str(data.get("name")).capitalize():
			incoming_display = ""
		if _function_fingerprint(target.function_name, target.return_type, target.return_type_name,
				target.description, target.expose_as_ace, target.ace_display_name, target.ace_category, target.params) \
				== _function_fingerprint(str(data.get("name")), int(data.get("return_type", TYPE_NIL)),
				str(data.get("return_type_name", "")), str(data.get("description", "")), bool(data.get("expose", false)),
				incoming_display, str(data.get("ace_category", "")), new_params):
			return false
		target.function_name = str(data.get("name"))
		target.return_type = int(data.get("return_type", TYPE_NIL))
		# return_type_name (a custom / engine class like HealthPool) wins over the int return type in codegen,
		# so it is written explicitly: a lifted `-> HealthPool` verb opened and saved unchanged compares equal
		# above (no-op, byte-safe); changing the type to a builtin card clears it so the new type takes effect.
		target.return_type_name = str(data.get("return_type_name", ""))
		target.description = str(data.get("description", ""))
		target.params = new_params
		target.expose_as_ace = bool(data.get("expose", false))
		target.ace_display_name = incoming_display
		target.ace_category = str(data.get("ace_category", ""))
		# A real edit makes this an authored function: normal annotation emission resumes (the flag
		# only ever suppressed annotations to keep an UNTOUCHED reverse-lifted helper byte-identical).
		target.lifted_unannotated = false
		return true)
	if changed:
		_dock._mark_dirty("Edited function %s()." % str(data.get("name")))


## One comparable string per (name, emitted-return-type, description, expose, display, category, params)
## tuple - the "did the dialog actually change anything" check above. The type component is the COMPILER's
## emitted `-> Type` name (return_type_name when set, else the Variant.Type name), so the two equivalent ways
## to spell one return type - (TYPE_COLOR, "") and (TYPE_MAX, "Color"), or the importer's (TYPE_MAX,
## "HealthPool") vs the dialog's rebuild - collapse to the same key. That keeps an open-and-OK on a lifted
## custom-return verb a byte-safe no-op (it never spuriously clears lifted_unannotated or the annotations).
static func _function_fingerprint(function_name: String, return_type: int, return_type_name: String,
		description: String, exposed: bool, display_name: String, category: String, params: Array) -> String:
	var type_probe: EventFunction = EventFunction.new()
	type_probe.return_type = return_type
	type_probe.return_type_name = return_type_name
	var parts: PackedStringArray = PackedStringArray([
		function_name, SheetCompiler._function_return_type_name(type_probe), description, str(exposed), display_name, category])
	for param: ACEParam in params:
		parts.append("%s|%s|%s|%s" % [param.id, param.type_name, param.gdscript_default, param.description])
	return "\n".join(parts)
