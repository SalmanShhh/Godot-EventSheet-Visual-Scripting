@tool
class_name EventSheetDockQueries
extends RefCounted
# The dock's SHEET QUERY helpers, extracted from event_sheet_dock.gd: pure-ish
# lookups over the live sheet and the current selection - event-row collection
# and labeling for target pickers, uid lookup, OR-mode detection, the selected
# rows/events from context, the ACE edit-context builder, and definition lookup.
# No state of their own; everything reads through the `_dock.` back-reference.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


func collect_event_row_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if _dock._current_sheet == null:
		return options
	var event_rows: Array[EventRow] = []
	_dock._collect_event_rows_recursive(_dock._current_sheet.events, event_rows)
	for event_row in event_rows:
		options.append(
			{
				"uid": event_row.event_uid,
				"label": _dock._format_event_target_label(event_row)
			}
		)
	return options


func collect_event_rows_recursive(resources: Array, output: Array[EventRow]) -> void:
	for resource_entry in resources:
		if resource_entry is EventRow:
			output.append(resource_entry as EventRow)
			_dock._collect_event_rows_recursive((resource_entry as EventRow).sub_events, output)
		elif resource_entry is EventGroup:
			_dock._collect_event_rows_recursive(_dock._group_children_array(resource_entry as EventGroup), output)


func format_event_target_label(event_row: EventRow) -> String:
	if event_row == null:
		return "(invalid event)"
	var label: String = "Event %s" % event_row.event_uid
	if not event_row.comment.is_empty():
		label += " - %s" % event_row.comment
	elif not event_row.trigger_id.is_empty():
		label += " - %s" % event_row.trigger_id
	elif event_row.trigger != null and not event_row.trigger.ace_id.is_empty():
		label += " - %s" % event_row.trigger.ace_id
	return label


func find_event_row_by_uid(event_uid: String) -> EventRow:
	if _dock._current_sheet == null or event_uid.is_empty():
		return null
	var event_rows: Array[EventRow] = []
	_dock._collect_event_rows_recursive(_dock._current_sheet.events, event_rows)
	for event_row in event_rows:
		if event_row.event_uid == event_uid:
			return event_row
	return null


func type_from_name(type_name: String) -> int:
	match type_name:
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"bool":
			return TYPE_BOOL
		"String":
			return TYPE_STRING
		_:
			return TYPE_NIL


func event_row_uses_or_mode(event_row: EventRow) -> bool:
	return event_row != null and event_row.condition_mode == EventRow.ConditionMode.OR


func event_rows_use_or_mode(event_rows: Array[EventRow]) -> bool:
	if event_rows.is_empty():
		return false
	for event_row in event_rows:
		if not _dock._event_row_uses_or_mode(event_row):
			return false
	return true


func get_selected_rows_from_context() -> Array[EventRowData]:
	if _dock._viewport == null:
		return []
	var selected_rows: Array[EventRowData] = _dock._active_view().get_selected_rows()
	if selected_rows.is_empty():
		if _dock._context_row != null:
			return [_dock._context_row]
		return []
	if _dock._context_row == null:
		return selected_rows
	for row_data in selected_rows:
		if row_data.row_uid == _dock._context_row.row_uid:
			return selected_rows
	return [_dock._context_row]


func get_selected_event_rows_from_context() -> Array[EventRow]:
	var event_rows: Array[EventRow] = []
	for row_data in _dock._get_selected_rows_from_context():
		if row_data != null and row_data.source_resource is EventRow:
			event_rows.append(row_data.source_resource as EventRow)
	return event_rows


func build_ace_edit_context(event_row: EventRow, span_index: int, metadata: Dictionary) -> Dictionary:
	if event_row == null:
		return {}
	var ace_index: int = int(metadata.get("ace_index", -1))
	var kind: String = str(metadata.get("kind", ""))
	var definition: ACEDefinition = null
	var existing_params: Dictionary = {}
	var mode: String = ""
	match kind:
		"trigger":
			if event_row.trigger == null:
				return {}
			definition = _dock._find_definition(event_row.trigger.provider_id, event_row.trigger.ace_id)
			existing_params = event_row.trigger.params if not event_row.trigger.params.is_empty() else event_row.trigger.parameters
			mode = "replace_trigger"
		"condition":
			if ace_index < 0 or ace_index >= event_row.conditions.size():
				return {}
			var condition_entry: ACECondition = event_row.conditions[ace_index]
			definition = _dock._find_definition(condition_entry.provider_id, condition_entry.ace_id)
			existing_params = condition_entry.params if not condition_entry.params.is_empty() else condition_entry.parameters
			mode = "replace_condition"
		"action":
			if ace_index < 0 or ace_index >= event_row.actions.size() or not (event_row.actions[ace_index] is ACEAction):
				return {}
			var action_entry: ACEAction = event_row.actions[ace_index] as ACEAction
			definition = _dock._find_definition(action_entry.provider_id, action_entry.ace_id)
			existing_params = action_entry.params if not action_entry.params.is_empty() else action_entry.parameters
			mode = "replace_action"
		_:
			return {}
	return {
		"mode": mode,
		"selected_resource": event_row,
		"row_data": _dock._context_row,
		"definition": definition,
		"existing_params": existing_params.duplicate(true),
		"ace_index": ace_index,
		"span_index": span_index,
		"kind": kind
	}


func find_definition(provider_id: String, ace_id: String) -> ACEDefinition:
	if _dock._ace_registry == null:
		return null
	return _dock._ace_registry.find_definition(provider_id, ace_id)


func find_first_event_row_resource() -> EventRow:
	if _dock._viewport == null:
		return null
	for row_entry: Dictionary in _dock._viewport.get_flat_rows():
		var row_data: EventRowData = row_entry.get("row")
		if row_data != null and row_data.source_resource is EventRow:
			return row_data.source_resource as EventRow
	return null


func select_first_event_row() -> void:
	if _dock._viewport == null:
		return
	var rows: Array[Dictionary] = _dock._viewport.get_flat_rows()
	for row_index: int in range(rows.size()):
		var row_data: EventRowData = rows[row_index].get("row")
		if row_data != null and row_data.source_resource is EventRow:
			_dock._viewport._select_row(row_index)
			return
