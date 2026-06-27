# EventSheet — Shareable snippet serialization (event-sheet-style)
# Serializes sheet rows to a portable, versioned TEXT form for the system clipboard, so
# events paste across projects, editor instances, and forum/Discord posts. Pure data via
# Godot's var_to_str (no JSON, no script paths, no UIDs): provider ids, params, baked
# codegen templates, and code travel; nothing project-specific does. Deserialization
# rebuilds only whitelisted row kinds, so unexpected content in pasted text is ignored.
@tool
class_name EventSheetSnippet
extends RefCounted

const HEADER := "[eventsheet-snippet v1]"
const FOOTER := "[/eventsheet-snippet]"

static func is_snippet_text(text: String) -> bool:
	var stripped: String = text.strip_edges()
	return stripped.begins_with(HEADER) and stripped.ends_with(FOOTER)

## Serializes top-level row resources (events/groups/comments/raw blocks/tree variables)
## plus the sheet variables they reference, into shareable text.
static func serialize_rows(resources: Array, sheet: EventSheetResource) -> String:
	var rows: Array = []
	for resource in resources:
		var row_data: Dictionary = _row_to_dict(resource)
		if not row_data.is_empty():
			rows.append(row_data)
	var payload: Dictionary = {
		"version": 1,
		"rows": rows,
		"required_variables": _collect_required_variables(rows, sheet),
		"providers": _collect_provider_ids(rows)
	}
	return "%s\n%s\n%s" % [HEADER, var_to_str(payload), FOOTER]

## Parses snippet text back into {rows: Array[Resource], required_variables: Dictionary,
## providers: Array}. Returns an empty Dictionary when the text is not a valid snippet.
static func deserialize(text: String) -> Dictionary:
	if not is_snippet_text(text):
		return {}
	var stripped: String = text.strip_edges()
	var body: String = stripped.substr(HEADER.length(), stripped.length() - HEADER.length() - FOOTER.length())
	var payload: Variant = str_to_var(body.strip_edges())
	if not (payload is Dictionary) or int((payload as Dictionary).get("version", 0)) != 1:
		return {}
	var rows: Array = []
	for row_data in (payload as Dictionary).get("rows", []):
		if row_data is Dictionary:
			var resource: Resource = _dict_to_row(row_data as Dictionary)
			if resource != null:
				rows.append(resource)
	return {
		"rows": rows,
		"required_variables": (payload as Dictionary).get("required_variables", {}),
		"providers": (payload as Dictionary).get("providers", [])
	}

# ── Serialization ────────────────────────────────────────────────────────────

static func _row_to_dict(resource: Variant) -> Dictionary:
	if resource is EventRow:
		var event: EventRow = resource as EventRow
		var event_data: Dictionary = {
			"kind": "event",
			"trigger_provider_id": event.trigger_provider_id,
			"trigger_id": event.trigger_id,
			"condition_mode": int(event.condition_mode),
			"else_mode": int(event.else_mode),
			"comment": event.comment,
			"enabled": event.enabled,
			"trigger": _ace_to_dict(event.trigger) if event.trigger != null else {},
			"conditions": [],
			"actions": [],
			"sub_events": [],
			"local_variables": []
		}
		for condition in event.conditions:
			if condition is ACECondition:
				(event_data["conditions"] as Array).append(_ace_to_dict(condition))
		for action_item in event.actions:
			if action_item is ACEAction:
				(event_data["actions"] as Array).append(_action_to_dict(action_item as ACEAction))
			elif action_item is RawCodeRow:
				(event_data["actions"] as Array).append({"kind": "raw", "code": (action_item as RawCodeRow).code, "enabled": (action_item as RawCodeRow).enabled})
		for sub_event in event.sub_events:
			var sub_data: Dictionary = _row_to_dict(sub_event)
			if not sub_data.is_empty():
				(event_data["sub_events"] as Array).append(sub_data)
		for local_variable in event.local_variables:
			if local_variable is LocalVariable:
				(event_data["local_variables"] as Array).append(_variable_to_dict(local_variable as LocalVariable))
		return event_data
	if resource is EventGroup:
		var group: EventGroup = resource as EventGroup
		var group_data: Dictionary = {"kind": "group", "name": group.group_name, "description": group.description, "enabled": group.enabled, "children": []}
		var children: Array = group.events if not group.events.is_empty() else group.rows
		for child in children:
			var child_data: Dictionary = _row_to_dict(child)
			if not child_data.is_empty():
				(group_data["children"] as Array).append(child_data)
		return group_data
	if resource is CommentRow:
		return {"kind": "comment", "text": (resource as CommentRow).text, "enabled": (resource as CommentRow).enabled}
	if resource is RawCodeRow:
		return {"kind": "raw", "code": (resource as RawCodeRow).code, "enabled": (resource as RawCodeRow).enabled}
	if resource is LocalVariable:
		return _variable_to_dict(resource as LocalVariable).merged({"kind": "variable"}, true)
	if resource is EnumRow:
		return {"kind": "enum", "name": (resource as EnumRow).enum_name, "members": Array((resource as EnumRow).members), "enabled": (resource as EnumRow).enabled}
	if resource is SignalRow:
		return {"kind": "signal", "name": (resource as SignalRow).signal_name, "params": Array((resource as SignalRow).params), "enabled": (resource as SignalRow).enabled}
	return {}

static func _ace_to_dict(condition: ACECondition) -> Dictionary:
	return {
		"provider_id": condition.provider_id,
		"ace_id": condition.ace_id,
		"params": condition.params.duplicate(true) if not condition.params.is_empty() else condition.parameters.duplicate(true),
		"negated": condition.negated,
		"enabled": condition.enabled,
		"codegen_template": condition.codegen_template
	}

static func _action_to_dict(action: ACEAction) -> Dictionary:
	return {
		"kind": "action",
		"provider_id": action.provider_id,
		"ace_id": action.ace_id,
		"params": action.params.duplicate(true) if not action.params.is_empty() else action.parameters.duplicate(true),
		"is_awaited": action.is_awaited or action.await_call,
		"comment": action.comment,
		"enabled": action.enabled,
		"codegen_template": action.codegen_template
	}

static func _variable_to_dict(local_variable: LocalVariable) -> Dictionary:
	return {
		"name": local_variable.name,
		"type_name": local_variable.type_name,
		"default_value": local_variable.default_value,
		"is_constant": local_variable.is_constant,
		"exported": local_variable.exported,
		"description": local_variable.description
	}

# ── Deserialization (whitelisted kinds only) ─────────────────────────────────

static func _dict_to_row(row_data: Dictionary) -> Resource:
	match str(row_data.get("kind", "")):
		"event":
			var event: EventRow = EventRow.new()
			event.trigger_provider_id = str(row_data.get("trigger_provider_id", ""))
			event.trigger_id = str(row_data.get("trigger_id", ""))
			event.condition_mode = int(row_data.get("condition_mode", 0))
			event.else_mode = int(row_data.get("else_mode", 0))
			event.comment = str(row_data.get("comment", ""))
			event.enabled = bool(row_data.get("enabled", true))
			var trigger_data: Dictionary = row_data.get("trigger", {})
			if not trigger_data.is_empty():
				event.trigger = _dict_to_condition(trigger_data)
			for condition_data in row_data.get("conditions", []):
				if condition_data is Dictionary:
					event.conditions.append(_dict_to_condition(condition_data as Dictionary))
			for action_data in row_data.get("actions", []):
				if not (action_data is Dictionary):
					continue
				if str((action_data as Dictionary).get("kind", "action")) == "raw":
					var inline_raw: RawCodeRow = RawCodeRow.new()
					inline_raw.code = str((action_data as Dictionary).get("code", ""))
					inline_raw.enabled = bool((action_data as Dictionary).get("enabled", true))
					event.actions.append(inline_raw)
				else:
					event.actions.append(_dict_to_action(action_data as Dictionary))
			for sub_data in row_data.get("sub_events", []):
				if sub_data is Dictionary:
					var sub_row: Resource = _dict_to_row(sub_data as Dictionary)
					if sub_row != null:
						event.sub_events.append(sub_row)
			for variable_data in row_data.get("local_variables", []):
				if variable_data is Dictionary:
					event.local_variables.append(_dict_to_variable(variable_data as Dictionary))
			return event
		"group":
			var group: EventGroup = EventGroup.new()
			group.group_name = str(row_data.get("name", "Group"))
			group.name = group.group_name
			group.description = str(row_data.get("description", ""))
			group.enabled = bool(row_data.get("enabled", true))
			for child_data in row_data.get("children", []):
				if child_data is Dictionary:
					var child_row: Resource = _dict_to_row(child_data as Dictionary)
					if child_row != null:
						group.events.append(child_row)
			return group
		"comment":
			var comment: CommentRow = CommentRow.new()
			comment.text = str(row_data.get("text", ""))
			comment.enabled = bool(row_data.get("enabled", true))
			return comment
		"raw":
			var raw_block: RawCodeRow = RawCodeRow.new()
			raw_block.code = str(row_data.get("code", ""))
			raw_block.enabled = bool(row_data.get("enabled", true))
			return raw_block
		"signal":
			var signal_row: SignalRow = SignalRow.new()
			signal_row.signal_name = str(row_data.get("name", "my_signal"))
			signal_row.params = PackedStringArray(row_data.get("params", []))
			signal_row.enabled = bool(row_data.get("enabled", true))
			return signal_row
		"enum":
			var enum_row: EnumRow = EnumRow.new()
			enum_row.enum_name = str(row_data.get("name", "State"))
			enum_row.members = PackedStringArray(row_data.get("members", []))
			enum_row.enabled = bool(row_data.get("enabled", true))
			return enum_row
		"variable":
			return _dict_to_variable(row_data)
	return null

static func _dict_to_condition(data: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = str(data.get("provider_id", "Core"))
	condition.ace_id = str(data.get("ace_id", ""))
	condition.params = data.get("params", {}) if data.get("params", {}) is Dictionary else {}
	condition.negated = bool(data.get("negated", false))
	condition.enabled = bool(data.get("enabled", true))
	condition.codegen_template = str(data.get("codegen_template", ""))
	return condition

static func _dict_to_action(data: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = str(data.get("provider_id", "Core"))
	action.ace_id = str(data.get("ace_id", ""))
	action.params = data.get("params", {}) if data.get("params", {}) is Dictionary else {}
	action.is_awaited = bool(data.get("is_awaited", false))
	action.comment = str(data.get("comment", ""))
	action.enabled = bool(data.get("enabled", true))
	action.codegen_template = str(data.get("codegen_template", ""))
	return action

static func _dict_to_variable(data: Dictionary) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = str(data.get("name", ""))
	variable.type_name = str(data.get("type_name", "Variant"))
	variable.default_value = data.get("default_value", null)
	variable.is_constant = bool(data.get("is_constant", false))
	variable.exported = bool(data.get("exported", false))
	variable.description = str(data.get("description", ""))
	return variable

# ── Dependencies ─────────────────────────────────────────────────────────────

## Sheet variables the snippet's params/templates/code reference (whole-word match), so
## paste can auto-create the missing ones in the target sheet.
static func _collect_required_variables(rows: Array, sheet: EventSheetResource) -> Dictionary:
	var required: Dictionary = {}
	if sheet == null or sheet.variables.is_empty():
		return required
	var haystack: String = var_to_str(rows)
	for variable_name in sheet.variables.keys():
		var name_text: String = str(variable_name)
		if name_text.is_empty():
			continue
		var regex: RegEx = RegEx.new()
		regex.compile("\\b%s\\b" % name_text)
		if regex.search(haystack) != null:
			var descriptor: Variant = sheet.variables[variable_name]
			required[name_text] = descriptor.duplicate(true) if descriptor is Dictionary else descriptor
	return required

static func _collect_provider_ids(rows: Array) -> Array:
	var providers: Dictionary = {}
	var stack: Array = rows.duplicate()
	while not stack.is_empty():
		var entry: Variant = stack.pop_back()
		if entry is Array:
			stack.append_array(entry)
		elif entry is Dictionary:
			var provider_id: String = str((entry as Dictionary).get("provider_id", ""))
			if not provider_id.is_empty() and provider_id != "Core":
				providers[provider_id] = true
			for value in (entry as Dictionary).values():
				if value is Dictionary or value is Array:
					stack.append(value)
	var output: Array = providers.keys()
	output.sort()
	return output
