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
#     (undoable). The body is authored as rows afterwards, and CallFunction plus the publish surface
#     pick the function up. The payload MAY carry a "guards" array (a programmatic caller can pass one);
#     each guard becomes an Expression-Is-True condition on a wrapper row. The dialog itself no longer
#     produces guards - gating a verb is a condition on an event inside its body, authored on the canvas.
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
	_function_dialog.set_tool_mode_context(_dock._current_sheet != null and _dock._current_sheet.tool_mode)
	_function_dialog.open()


## The right-click "New Function ▸" submenu entry point: opens the dialog pre-set to a kind and publish
## state. `kind` is "" / "action" / "condition" / "expression"; `publish` pre-ticks the picker checkbox.
func _open_function_dialog_new(kind: String, publish: bool) -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_ensure_dialog()
	_function_dialog.set_tool_mode_context(_dock._current_sheet != null and _dock._current_sheet.tool_mode)
	_function_dialog.open(kind, publish)


## Double-clicking a Define block on the canvas edits that verb in the same dialog (edit mode:
## pre-filled fields, the apply updates the existing function instead of appending a new one).
func _open_function_dialog_for(event_function: Resource) -> void:
	if not (event_function is EventFunction) or _dock._current_sheet == null:
		return
	_ensure_dialog()
	_function_dialog.set_tool_mode_context(_dock._current_sheet.tool_mode)
	_function_dialog.open_for_edit(event_function as EventFunction)


## Right-click ▸ "Add Parameter" on a Define row, and the row's own "+ Add parameter" cell: the small
## parameter dialog, blank. Adding an input is a four-field job; the whole verb dialog is not the ask.
func _open_function_dialog_add_param(event_function: Resource) -> void:
	if not (event_function is EventFunction) or _dock._current_sheet == null:
		return
	_ensure_param_dialog()
	_param_dialog.open_for_new_param(event_function as EventFunction)


## Click on a verb row's parameter CELL: the small parameter dialog, on THAT parameter - so a parameter
## cell behaves like a condition cell (click the thing you want to change, land in ITS editor, not in a
## form that can restructure the whole verb). "Edit the whole verb…" inside it is the way up.
func _open_function_dialog_for_param(event_function: Resource, param_index: int) -> void:
	if not (event_function is EventFunction) or _dock._current_sheet == null:
		return
	_ensure_param_dialog()
	_param_dialog.open_for_param(event_function as EventFunction, param_index)


# ── One parameter at a time: the focused dialog behind a verb row's param cells ───────
var _param_dialog: EventSheetParamDialog = null


func _ensure_param_dialog() -> void:
	if _param_dialog != null:
		return
	_param_dialog = EventSheetParamDialog.new()
	_param_dialog.init_dialog(_dock)
	_param_dialog.param_confirmed.connect(_apply_param_edit)
	# Its escape hatch: the reader wanted the verb, not the parameter. Route by NAME rather than by a
	# captured resource - an undo-funnel commit replaces resources, so a held reference would go stale.
	_param_dialog.full_editor_requested.connect(func(function_name: String) -> void:
		var target: EventFunction = _find_function(function_name)
		if target != null:
			_open_function_dialog_for(target))


## The verb of this name on the live sheet, or null. Always re-fetched: the undo funnel REPLACES
## resources on commit, so any reference held across an edit points at a discarded snapshot.
func _find_function(function_name: String) -> EventFunction:
	if _dock._current_sheet == null:
		return null
	for function_entry: Variant in _dock._current_sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == function_name:
			return function_entry as EventFunction
	return null


## Applies one parameter's edit (or its deletion, or a fresh append) through the same undo funnel the
## full verb dialog writes through, so the two dialogs are interchangeable and a param edit is a single
## undo step. Returns silently when nothing actually changed - an open-and-Apply must not dirty the
## sheet, which for an opened .gd would mean a rewrite that has to survive the byte-exact round trip.
func _apply_param_edit(data: Dictionary) -> void:
	var function_name: String = str(data.get("function", ""))
	var param_index: int = int(data.get("index", -1))
	var removed: bool = bool(data.get("removed", false))
	var new_id: String = str(data.get("id", "")).strip_edges()
	if not removed and new_id.is_empty():
		_dock._set_status("A parameter needs a name.", true)
		return
	# GDScript requires defaulted parameters to be trailing, and this dialog is now the ONLY way to
	# author them - the verb dialog's parameter list is gone. Without this check a default on an early
	# parameter emits a `func` that will not parse, which the sheet would then fail to compile.
	var target_now: EventFunction = _find_function(function_name)
	if target_now != null and not _defaults_stay_trailing(target_now, data):
		_dock._set_status(
			"Parameters with a default value must come after those without - move this one down, or give the ones after it defaults too.",
			true
		)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Parameter", func() -> bool:
		var target: EventFunction = _find_function(function_name)
		if target == null:
			return false
		if removed:
			if param_index < 0 or param_index >= target.params.size():
				return false
			target.params.remove_at(param_index)
			return true
		var param: ACEParam = null
		if param_index < 0:
			param = ACEParam.new()
			target.params.append(param)
		else:
			if param_index >= target.params.size():
				return false
			param = target.params[param_index]
			if param.id == new_id and param.type_name == str(data.get("type_name", "Variant")) \
					and param.gdscript_default == str(data.get("default", "")) \
					and param.description == str(data.get("description", "")):
				return false
		param.id = new_id
		param.type_name = str(data.get("type_name", "Variant"))
		param.gdscript_default = str(data.get("default", ""))
		param.description = str(data.get("description", ""))
		return true
	)
	if changed:
		_dock._set_status("Removed the parameter." if removed else "Updated the parameter.")


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
		event_function.doc_comment = str(data.get("doc_comment", ""))
		event_function.tool_button_label = str(data.get("tool_button_label", ""))
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
		# The display name / description / category are carried through the dialog untouched (they are
		# edited inline on the row now), so the payload already reports the function's own stored values -
		# no capitalize() fabrication to normalize back. An untouched open-and-save therefore fingerprints
		# equal on its own.
		var incoming_display: String = str(data.get("ace_display_name", ""))
		if _function_fingerprint(target.function_name, target.return_type, target.return_type_name,
				target.description, target.expose_as_ace, target.ace_display_name, target.ace_category, target.params, target.doc_comment, target.tool_button_label) \
				== _function_fingerprint(str(data.get("name")), int(data.get("return_type", TYPE_NIL)),
				str(data.get("return_type_name", "")), str(data.get("description", "")), bool(data.get("expose", false)),
				incoming_display, str(data.get("ace_category", "")), new_params, str(data.get("doc_comment", "")), str(data.get("tool_button_label", ""))):
			return false
		target.function_name = str(data.get("name"))
		target.return_type = int(data.get("return_type", TYPE_NIL))
		# return_type_name (a custom / engine class like HealthPool) wins over the int return type in codegen,
		# so it is written explicitly: a lifted `-> HealthPool` verb opened and saved unchanged compares equal
		# above (no-op, byte-safe); changing the type to a builtin card clears it so the new type takes effect.
		target.return_type_name = str(data.get("return_type_name", ""))
		target.description = str(data.get("description", ""))
		target.doc_comment = str(data.get("doc_comment", ""))
		target.tool_button_label = str(data.get("tool_button_label", ""))
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
		description: String, exposed: bool, display_name: String, category: String, params: Array, doc_comment: String = "", tool_button_label: String = "") -> String:
	var type_probe: EventFunction = EventFunction.new()
	type_probe.return_type = return_type
	type_probe.return_type_name = return_type_name
	var parts: PackedStringArray = PackedStringArray([
		function_name, SheetCompiler._function_return_type_name(type_probe), description, str(exposed), display_name, category, doc_comment, tool_button_label])
	for param: ACEParam in params:
		parts.append("%s|%s|%s|%s" % [param.id, param.type_name, param.gdscript_default, param.description])
	return "\n".join(parts)


## True when applying `data` to `target` leaves every defaulted parameter after every non-defaulted
## one - GDScript's rule for a `func` signature. Simulates the edit rather than inspecting the stored
## params, so it catches the case the user is about to create, not the one that already exists.
func _defaults_stay_trailing(target: EventFunction, data: Dictionary) -> bool:
	var index: int = int(data.get("index", -1))
	var removed: bool = bool(data.get("removed", false))
	var defaults: Array[bool] = []
	for position in range(target.params.size()):
		var param: ACEParam = target.params[position]
		if position == index:
			if removed:
				continue
			defaults.append(not str(data.get("default", "")).strip_edges().is_empty())
			continue
		defaults.append(not param.gdscript_default.strip_edges().is_empty())
	if index < 0 and not removed:
		defaults.append(not str(data.get("default", "")).strip_edges().is_empty())
	var seen_default: bool = false
	for has_default: bool in defaults:
		if has_default:
			seen_default = true
		elif seen_default:
			return false
	return true
