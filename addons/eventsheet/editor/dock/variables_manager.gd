@tool
class_name EventSheetVariablesManager
extends RefCounted
# All sheet-VARIABLE authoring: the add/edit/convert/toggle-const flows for global, local (event-scoped),
# and tree-placed variables; the variable dialog confirm handler that commits them (with name guardrails
# + reference renaming); the variable context menu's edit/convert/const actions; the create-variable
# quick-fix; the "is this variable used?" usage scan that gates rename-vs-clear; and the (currently
# headless) variable-panel refresh that materializes the global/local entry lists. Extracted from
# event_sheet_dock.gd to keep that file maintainable; the shared sheet/edit/status services and the
# variable dialog + context-menu components stay on the dock, reached through the `_dock` back-reference,
# the same pattern as the other dock/ helpers.

const VARIABLE_USAGE_MAX_DEPTH := 8

var _dock: Control = null

# The variable the variable context menu / viewport edit is acting on. Written by the dock's context-menu
# dispatcher (and reset on every empty-space / row context open) and read back here — public on this helper
# precisely because the dock populates it before delegating in.
var _context_variable: Dictionary = {}
var _global_variable_entries: Array[Dictionary] = []
var _local_variable_entries: Array[Dictionary] = []
# Vestigial: the dock never builds these ItemLists (the variable panel was folded into the viewport's
# inline variable rows), so they stay null and the null-guards below no-op. Kept so _refresh_variable_panel
# still materializes the entry arrays its activations index into.
var _global_var_list: ItemList = null
var _local_var_list: ItemList = null


func init(dock: Control) -> void:
	_dock = dock


func _on_add_global_variable_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_dock._variable_dlg.open("global")


func _on_add_local_variable_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	var target_event: EventRow = _dock._find_first_event_row_resource()
	var context: Dictionary = {"create_event_if_missing": true}
	if target_event != null:
		_dock._select_first_event_row()
		context["selected_resource"] = target_event
	_dock._variable_dlg.open_for_edit("local", context, "", "int", "", false, "Create Variable")


## Opens the variable dialog to add a tree-placed variable directly below the right-clicked
## row (so variables can sit between/above/under events like comments do).
func _add_tree_variable_below_context_row() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	if _dock._context_row == null or _dock._context_row.source_resource == null:
		_dock._set_status("Select a row to add a variable below.", true)
		return
	_dock._variable_dlg.open_for_edit(
		"tree", {"insert_below": _dock._context_row.source_resource}, "", "int", "0", false, "Add Variable", false, false
	)


## Returns the sheet's variable names for variable-reference parameter dropdowns.
func _collect_sheet_variable_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if _dock._current_sheet == null:
		return names
	for key: Variant in _dock._current_sheet.variables.keys():
		names.append(str(key))
	names.sort()
	return names


func _on_viewport_variable_edit_requested(row_data: EventRowData, metadata: Dictionary) -> void:
	_context_variable = _context_variable_entry_from_metadata(row_data, metadata)
	if _context_variable.is_empty():
		_dock._set_status("Select a valid variable before editing.", true)
		return
	_edit_context_variable()


func _on_variable_context_menu_id_pressed(id: int) -> void:
	if _context_variable.is_empty():
		return
	match id:
		_dock.VARIABLE_MENU_EDIT:
			_edit_context_variable()
		_dock.VARIABLE_MENU_RENAME:
			_dock._open_rename_dialog(str(_context_variable.get("name", "")))
		_dock.VARIABLE_MENU_CONVERT_SCOPE:
			_convert_context_variable_scope()
		_dock.VARIABLE_MENU_TOGGLE_CONST:
			_toggle_context_variable_constant()


## The create-variable quick-fix behind the params dialog's "+ var" button: declares
## the identifier as a float (the "number" default — retype via Edit Variable) so
## the expression lints clean without leaving the dialog.
func _create_variable_quickfix(variable_name: String) -> bool:
	if _dock._current_sheet == null or not variable_name.is_valid_identifier() or _dock._current_sheet.variables.has(variable_name):
		return false
	return _dock._perform_undoable_sheet_edit("Create variable %s" % variable_name, func() -> bool:
		_dock._current_sheet.variables[variable_name] = {"type": "float", "default": 0.0, "exported": true}
		return true)


## The Inspector attributes a tree-placed LocalVariable round-trips (tooltip + group/subgroup + a Tier 3
## drawer with its bounds) — the subset the tree-var emission supports. Keeps a reopened variable editable:
## the dialog populates these (via the edit context) and this stores back what the user changes, so they
## aren't stuck or cleared.
static func _tree_group_attributes(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for attr_key: String in ["tooltip", "group", "subgroup", "drawer"]:
		var attr_value: String = str(source.get(attr_key, "")).strip_edges()
		if not attr_value.is_empty():
			result[attr_key] = attr_value
	# A Tier 3 drawer's numeric bounds (progress_bar/vector_dial) ride along as the range dict so the
	# @export_custom marker can re-emit them; the tree path can't express the other dict-only attributes,
	# so they're intentionally dropped (degrade to a plain field, never a corrupt one).
	if result.has("drawer") and source.get("range") is Dictionary and not (source.get("range") as Dictionary).is_empty():
		result["range"] = (source.get("range") as Dictionary).duplicate()
	return result


func _on_variable_dialog_confirmed(
	var_name: String,
	type_name: String,
	default_value: Variant,
	scope: String,
	context: Dictionary = {},
	is_constant: bool = false,
	exported: bool = true,
	combo_options: PackedStringArray = PackedStringArray(),
	attributes: Dictionary = {}
) -> void:
	# Guardrail (event-sheet-style): auto-correct what's fixable, block what isn't — BEFORE commit.
	var sanitized_name: String = EventSheetIdentifierRules.sanitize(var_name)
	if sanitized_name.is_empty() or not EventSheetIdentifierRules.is_valid(sanitized_name):
		_dock._set_status("\"%s\" can't be a variable name (letters/digits/underscores, not a GDScript keyword)." % var_name, true)
		return
	if sanitized_name != var_name:
		_dock._set_status("Variable name auto-corrected to \"%s\"." % sanitized_name)
	var_name = sanitized_name
	# A name shadowing a host member would make the generated script unparseable
	# AND blind expression lint (field-test catch) — refuse at the source; the
	# doctor catches pre-existing ones.
	if scope == "global" and _dock._current_sheet != null:
		var shadow_owner: String = EventSheetProjectDoctor.shadowed_member_class(_dock._current_sheet, var_name)
		if not shadow_owner.is_empty():
			_dock._set_status("\"%s\" is already a %s member — pick another name (e.g. %s_value)." % [var_name, shadow_owner, var_name], true)
			return
	var selected: Resource = context.get("selected_resource", _dock._active_view().get_selected_context().get("source_resource", null))
	var original_name: String = str(context.get("original_name", ""))
	var editing: bool = bool(context.get("editing", false))
	var action_verb: String = "Updated" if editing else "Added"
	var message := {"text": ""}
	var supports_const: bool = _variable_type_supports_const(type_name)
	var resolved_constant: bool = is_constant and supports_const
	var added: bool = _dock._perform_undoable_sheet_edit("Create Variable", func() -> bool:
		if scope == "tree":
			var editing_resource: Variant = context.get("variable_resource", null)
			if editing and editing_resource is LocalVariable:
				var existing: LocalVariable = editing_resource as LocalVariable
				existing.options = combo_options
				var previous_tree_name: String = existing.name
				existing.name = var_name
				if previous_tree_name != var_name:
					message["renamed"] = _dock._rename_variable_references(previous_tree_name, var_name)
				existing.type_name = type_name
				existing.default_value = default_value
				existing.is_constant = resolved_constant
				existing.exported = exported
				existing.attributes = _tree_group_attributes(attributes)
				message["text"] = "Updated variable %s." % var_name
				return true
			var tree_var: LocalVariable = LocalVariable.new()
			tree_var.options = combo_options
			tree_var.name = var_name
			tree_var.type_name = type_name
			tree_var.default_value = default_value
			tree_var.is_constant = resolved_constant
			tree_var.exported = exported
			tree_var.attributes = _tree_group_attributes(attributes)
			var anchor: Variant = context.get("insert_below", null)
			if anchor is Resource:
				var location: Dictionary = _dock._find_resource_location(anchor as Resource)
				var container: Array = location.get("container", _dock._current_sheet.events)
				var anchor_index: int = int(location.get("index", container.size() - 1))
				container.insert(anchor_index + 1, tree_var)
			else:
				_dock._current_sheet.events.append(tree_var)
			message["text"] = "Added variable %s." % var_name
			return true
		if scope == "global":
			if editing and not original_name.is_empty() and original_name != var_name:
				_dock._current_sheet.variables.erase(original_name)
				message["renamed"] = _dock._rename_variable_references(original_name, var_name)
			_dock._current_sheet.variables[var_name] = {
				"type": type_name,
				"default": default_value,
				"const": resolved_constant,
				"exported": exported,
				"exposed": exported,
				"options": Array(combo_options),
				"attributes": attributes
			}
			message["text"] = "%s %s variable %s." % [action_verb, "global" if exported else "private", var_name]
			return true
		var target_event: EventRow = null
		if selected is EventRow:
			target_event = selected as EventRow
		else:
			target_event = _dock._find_first_event_row_resource()
		if target_event == null and not editing and bool(context.get("create_event_if_missing", true)):
			target_event = EventRow.new()
			_dock._current_sheet.events.append(target_event)
		if target_event == null:
			return false
		var variable_index: int = int(context.get("variable_index", -1))
		var local_var: LocalVariable = null
		if editing and variable_index >= 0 and variable_index < target_event.local_variables.size():
			local_var = target_event.local_variables[variable_index]
		else:
			local_var = LocalVariable.new()
			target_event.local_variables.append(local_var)
		local_var.name = var_name
		local_var.type_name = type_name
		local_var.type = _dock._type_from_name(type_name)
		local_var.default_value = default_value
		local_var.is_constant = resolved_constant
		message["text"] = "%s local variable %s." % [action_verb, var_name]
		return true
	)
	if not added and scope != "global":
		_dock._set_status("Add or select an event row before editing local variables.", true)
		return
	if added:
		var status_text: String = str(message.get("text", "Saved variable."))
		var renamed_references: int = int(message.get("renamed", 0))
		if renamed_references > 0:
			status_text += " %d reference(s) updated across the sheet." % renamed_references
		_dock._mark_dirty(status_text)
		if scope == "local" and not (selected is EventRow):
			_dock._select_first_event_row()


func _context_variable_entry_from_metadata(row_data: EventRowData, metadata: Dictionary) -> Dictionary:
	if row_data == null or metadata.is_empty() or _dock._current_sheet == null:
		return {}
	var var_name: String = str(metadata.get("variable_name", ""))
	var scope: String = str(metadata.get("variable_scope", "global"))
	if var_name.is_empty():
		return {}
	if scope == "tree":
		var tree_var: LocalVariable = row_data.source_resource as LocalVariable
		if tree_var == null:
			return {}
		return {
			"name": tree_var.name,
			"scope": "tree",
			"type": tree_var.type_name,
			"default": tree_var.default_value,
			"is_constant": tree_var.is_constant,
			"exported": tree_var.exported,
			"resource": tree_var
		}
	var type_name: String = "Variant"
	var default_value: Variant = null
	var is_constant: bool = false
	var index: int = int(metadata.get("variable_index", -1))
	var owner_event: EventRow = null
	if scope == "local":
		if row_data.source_resource is EventRow:
			owner_event = row_data.source_resource as EventRow
		if owner_event == null and _dock._viewport != null:
			var selected_resource: Resource = _dock._active_view().get_selected_context().get("source_resource", null)
			if selected_resource is EventRow:
				owner_event = selected_resource as EventRow
		if owner_event == null:
			return {}
		var local_var: LocalVariable = _resolve_local_variable(owner_event, var_name, index)
		if local_var == null:
			return {}
		type_name = local_var.type_name
		default_value = local_var.default_value
		is_constant = local_var.is_constant
		index = owner_event.local_variables.find(local_var)
	else:
		var descriptor: Dictionary = _dock._current_sheet.variables.get(var_name, {})
		if descriptor.is_empty():
			return {}
		type_name = str(descriptor.get("type", "Variant"))
		default_value = descriptor.get("default", null)
		is_constant = bool(descriptor.get("const", descriptor.get("is_constant", false)))
	return {
		"scope": scope,
		"name": var_name,
		"type": type_name,
		"default": default_value,
		"is_constant": is_constant,
		"supports_const": _variable_type_supports_const(type_name),
		"event_row": owner_event,
		"index": index
	}


func _resolve_local_variable(event_row: EventRow, var_name: String, index: int = -1) -> LocalVariable:
	if event_row == null:
		return null
	if index >= 0 and index < event_row.local_variables.size():
		var indexed: LocalVariable = event_row.local_variables[index]
		if indexed != null and indexed.name == var_name:
			return indexed
	for local_var in event_row.local_variables:
		if local_var is LocalVariable and (local_var as LocalVariable).name == var_name:
			return local_var as LocalVariable
	return null


func _edit_context_variable() -> void:
	if _context_variable.is_empty():
		return
	var scope: String = str(_context_variable.get("scope", "global"))
	if scope == "tree":
		var tree_var: LocalVariable = _context_variable.get("resource", null)
		if tree_var == null:
			_dock._set_status("Could not resolve the variable to edit.", true)
			return
		_dock._variable_dlg.open_for_edit(
			"tree",
			{"editing": true, "variable_resource": tree_var, "attributes": tree_var.attributes},
			tree_var.name,
			tree_var.type_name,
			tree_var.default_value,
			false,
			"Edit Variable",
			tree_var.is_constant,
			tree_var.exported
		)
		return
	if scope == "local":
		var owner_event: EventRow = _context_variable.get("event_row", null)
		if owner_event == null:
			_dock._set_status("Select the owning event before editing this local variable.", true)
			return
		_dock._variable_dlg.open_for_edit(
			"local",
			{
				"editing": true,
				"original_name": str(_context_variable.get("name", "")),
				"variable_index": int(_context_variable.get("index", -1)),
				"selected_resource": owner_event
			},
			str(_context_variable.get("name", "")),
			str(_context_variable.get("type", "Variant")),
			_context_variable.get("default", null),
			_is_local_variable_in_use(str(_context_variable.get("name", "")), owner_event),
			"Edit Variable",
			bool(_context_variable.get("is_constant", false))
		)
		return
	var global_name: String = str(_context_variable.get("name", ""))
	_dock._variable_dlg.open_for_edit(
		"global",
		{"editing": true, "original_name": global_name},
		global_name,
		str(_context_variable.get("type", "Variant")),
		_context_variable.get("default", null),
		_is_global_variable_in_use(global_name),
		"Edit Variable",
		bool(_context_variable.get("is_constant", false)),
		bool(_context_variable.get("exported", _context_variable.get("exposed", true)))
	)


func _convert_context_variable_scope() -> void:
	if _context_variable.is_empty():
		return
	var scope: String = str(_context_variable.get("scope", "global"))
	if scope == "global":
		_prompt_convert_global_variable_to_local(_context_variable)
		return
	var converted: bool = _convert_variable_scope(_context_variable, "global")
	if not converted:
		_dock._set_status("Could not convert variable to global scope.", true)


func _toggle_context_variable_constant() -> void:
	if _context_variable.is_empty():
		return
	if not bool(_context_variable.get("supports_const", false)):
		_dock._set_status("Const is unavailable for this variable type.", true)
		return
	var scope: String = str(_context_variable.get("scope", "global"))
	var var_name: String = str(_context_variable.get("name", ""))
	var new_constant: bool = not bool(_context_variable.get("is_constant", false))
	var changed: bool = _dock._perform_undoable_sheet_edit("Toggle Variable Constant", func() -> bool:
		if scope == "global":
			var descriptor: Dictionary = _dock._current_sheet.variables.get(var_name, {})
			if descriptor.is_empty():
				return false
			descriptor["const"] = new_constant
			_dock._current_sheet.variables[var_name] = descriptor
			return true
		var owner_event: EventRow = _context_variable.get("event_row", null)
		var local_var: LocalVariable = _resolve_local_variable(owner_event, var_name, int(_context_variable.get("index", -1)))
		if local_var == null:
			return false
		local_var.is_constant = new_constant
		return true
	)
	if changed:
		_dock._mark_dirty("%s variable %s as constant." % ["Marked" if new_constant else "Unmarked", var_name])
		_context_variable["is_constant"] = new_constant


func _prompt_convert_global_variable_to_local(entry: Dictionary) -> void:
	if _dock._current_sheet == null:
		return
	var options: Array[Dictionary] = _dock._collect_event_row_options()
	if options.is_empty():
		_dock._set_status("Add an event row first, then convert this variable to local.", true)
		return
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Convert Global Variable to Local"
	var content: VBoxContainer = VBoxContainer.new()
	content.custom_minimum_size = Vector2(420.0, 120.0)
	dialog.add_child(content)
	var summary: Label = Label.new()
	summary.text = "Select the target event for local variable %s." % str(entry.get("name", ""))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Width-bound the label itself — the parent VBox's custom_minimum_size.x does not bound the
	# child's min-height pass, so an unbounded autowrap label would balloon this dialog on launch.
	summary.custom_minimum_size = Vector2(400.0, 0.0)
	content.add_child(summary)
	var picker: OptionButton = OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in options:
		picker.add_item(str(option.get("label", "")))
		picker.set_item_metadata(picker.item_count - 1, str(option.get("uid", "")))
	content.add_child(picker)
	dialog.confirmed.connect(func() -> void:
		var selected_uid: String = str(picker.get_item_metadata(picker.selected))
		var converted: bool = _convert_variable_scope(entry, "local", selected_uid)
		if not converted:
			_dock._set_status("Could not convert variable to local scope.", true)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.close_requested.connect(func() -> void: dialog.queue_free())
	_dock.add_child(dialog)
	dialog.popup_centered(Vector2i(460, 180))


func _convert_variable_scope(entry: Dictionary, target_scope: String, target_event_uid: String = "") -> bool:
	if _dock._current_sheet == null or entry.is_empty():
		return false
	var source_scope: String = str(entry.get("scope", "global"))
	var var_name: String = str(entry.get("name", ""))
	var type_name: String = str(entry.get("type", "Variant"))
	var default_value: Variant = entry.get("default", null)
	var is_constant: bool = bool(entry.get("is_constant", false))
	if source_scope == target_scope:
		return false
	var converted: bool = _dock._perform_undoable_sheet_edit("Convert Variable Scope", func() -> bool:
		if source_scope == "global" and target_scope == "local":
			var descriptor: Dictionary = _dock._current_sheet.variables.get(var_name, {})
			if descriptor.is_empty():
				_dock._set_status("Global variable %s no longer exists." % var_name, true)
				return false
			var target_event: EventRow = _dock._find_event_row_by_uid(target_event_uid)
			if target_event == null:
				_dock._set_status("Select a target event for local conversion.", true)
				return false
			if _resolve_local_variable(target_event, var_name) != null:
				_dock._set_status("Target event already has a local variable named %s." % var_name, true)
				return false
			var local_var: LocalVariable = LocalVariable.new()
			local_var.name = var_name
			local_var.type_name = type_name
			local_var.type = _dock._type_from_name(type_name)
			local_var.default_value = default_value
			local_var.is_constant = is_constant
			target_event.local_variables.append(local_var)
			_dock._current_sheet.variables.erase(var_name)
			return true
		if source_scope == "local" and target_scope == "global":
			var owner_event: EventRow = entry.get("event_row", null)
			var local_var: LocalVariable = _resolve_local_variable(owner_event, var_name, int(entry.get("index", -1)))
			if local_var == null:
				_dock._set_status("Local variable %s no longer exists." % var_name, true)
				return false
			if _dock._current_sheet.variables.has(var_name):
				_dock._set_status("A global variable named %s already exists." % var_name, true)
				return false
			_dock._current_sheet.variables[var_name] = {
				"type": local_var.type_name,
				"default": local_var.default_value,
				"const": local_var.is_constant,
				"exposed": true
			}
			owner_event.local_variables.remove_at(owner_event.local_variables.find(local_var))
			return true
		return false
	)
	if converted:
		_dock._mark_dirty("Converted variable %s to %s scope." % [var_name, target_scope])
	return converted


func _variable_type_supports_const(type_name: String) -> bool:
	return type_name != "Variant"


func _on_global_variable_activated(index: int) -> void:
	if index < 0 or index >= _global_variable_entries.size():
		return
	var entry: Dictionary = _global_variable_entries[index]
	var var_name: String = str(entry.get("name", ""))
	_dock._variable_dlg.open_for_edit(
		"global",
		{"editing": true, "original_name": var_name},
		var_name,
		str(entry.get("type", "Variant")),
		entry.get("default", null),
		_is_global_variable_in_use(var_name),
		"Edit Variable",
		bool(entry.get("const", false)),
		bool(entry.get("exported", entry.get("exposed", true)))
	)


func _on_local_variable_activated(index: int) -> void:
	if index < 0 or index >= _local_variable_entries.size():
		return
	var entry: Dictionary = _local_variable_entries[index]
	var var_name: String = str(entry.get("name", ""))
	var selected_resource: Resource = entry.get("selected_resource", null)
	_dock._variable_dlg.open_for_edit(
		"local",
		{
			"editing": true,
			"original_name": var_name,
			"variable_index": int(entry.get("index", -1)),
			"selected_resource": selected_resource
		},
		var_name,
		str(entry.get("type", "Variant")),
		entry.get("default", null),
		_is_local_variable_in_use(var_name, selected_resource),
		"Edit Variable",
		bool(entry.get("const", false))
	)


func _is_global_variable_in_use(var_name: String) -> bool:
	if _dock._current_sheet == null or var_name.is_empty():
		return false
	return _resource_array_uses_variable(_dock._current_sheet.events, var_name)


func _is_local_variable_in_use(var_name: String, selected_resource: Resource) -> bool:
	if var_name.is_empty() or not (selected_resource is EventRow):
		return false
	return _event_row_uses_variable(selected_resource as EventRow, var_name)


func _resource_array_uses_variable(resources: Array, var_name: String) -> bool:
	for resource_entry in resources:
		if _resource_uses_variable(resource_entry, var_name):
			return true
	return false


func _resource_uses_variable(resource_entry: Resource, var_name: String) -> bool:
	if resource_entry == null:
		return false
	if resource_entry is EventRow:
		return _event_row_uses_variable(resource_entry as EventRow, var_name)
	if resource_entry is EventGroup:
		return _resource_array_uses_variable(_dock._group_children_array(resource_entry as EventGroup), var_name)
	return false


func _event_row_uses_variable(event_row: EventRow, var_name: String) -> bool:
	if event_row == null:
		return false
	if _ace_entry_uses_variable(event_row.trigger, var_name):
		return true
	for condition in event_row.conditions:
		if _ace_entry_uses_variable(condition, var_name):
			return true
	for action_entry in event_row.actions:
		if _ace_entry_uses_variable(action_entry, var_name):
			return true
	return _resource_array_uses_variable(event_row.sub_events, var_name)


func _ace_entry_uses_variable(entry: Resource, var_name: String) -> bool:
	if entry == null:
		return false
	if entry is ACECondition:
		var condition_entry: ACECondition = entry as ACECondition
		var condition_params: Dictionary = condition_entry.params
		if condition_params.is_empty():
			condition_params = condition_entry.parameters
		return _dictionary_uses_variable(condition_params, var_name, 0)
	if entry is ACEAction:
		var action_entry: ACEAction = entry as ACEAction
		var action_params: Dictionary = action_entry.params
		if action_params.is_empty():
			action_params = action_entry.parameters
		return _dictionary_uses_variable(action_params, var_name, 0)
	return false


func _dictionary_uses_variable(values: Dictionary, var_name: String, depth: int) -> bool:
	if depth >= VARIABLE_USAGE_MAX_DEPTH or var_name.is_empty() or values.is_empty():
		return false
	for value in values.values():
		if value is Dictionary and _dictionary_uses_variable(value as Dictionary, var_name, depth + 1):
			return true
		if value is Array:
			for nested_value in value:
				if nested_value is Dictionary and _dictionary_uses_variable(nested_value as Dictionary, var_name, depth + 1):
					return true
				if nested_value == var_name:
					return true
		elif str(value) == var_name:
			return true
	return false


func _refresh_variable_panel() -> void:
	_global_variable_entries.clear()
	_local_variable_entries.clear()
	if _global_var_list != null:
		_global_var_list.clear()
	if _local_var_list != null:
		_local_var_list.clear()
	if _dock._current_sheet != null:
		var names: Array = _dock._current_sheet.variables.keys()
		names.sort()
		for var_name in names:
			var descriptor: Dictionary = _dock._current_sheet.variables.get(var_name, {})
			var is_constant: bool = bool(descriptor.get("const", descriptor.get("is_constant", false)))
			if _global_var_list != null:
				_global_var_list.add_item(
					"%s%s : %s = %s"
					% [
						"const " if is_constant else "",
						var_name,
						str(descriptor.get("type", "Variant")),
						str(descriptor.get("default", ""))
					]
				)
			_global_variable_entries.append({
				"name": var_name,
				"type": str(descriptor.get("type", "Variant")),
				"default": descriptor.get("default", ""),
				"const": is_constant
			})
	var selected_resource: Resource = _dock._active_view().get_selected_context().get("source_resource", null)
	if selected_resource is EventRow:
		for index in range((selected_resource as EventRow).local_variables.size()):
			var local_var: LocalVariable = (selected_resource as EventRow).local_variables[index]
			if local_var == null:
				continue
			if _local_var_list != null:
				_local_var_list.add_item(
					"%s%s : %s = %s"
					% [
						"const " if local_var.is_constant else "",
						local_var.name,
						local_var.type_name,
						str(local_var.default_value)
					]
				)
			_local_variable_entries.append({
				"index": index,
				"name": local_var.name,
				"type": local_var.type_name,
				"default": local_var.default_value,
				"const": local_var.is_constant,
				"selected_resource": selected_resource
			})
