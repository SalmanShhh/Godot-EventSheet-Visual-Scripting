# Godot EventSheets — readable text rendering of a sheet (the team-diff backbone)
#
# Renders an EventSheetResource as stable, deterministic plain text so git can diff
# sheets row-by-row (see CONTRIBUTING "Reviewable sheet diffs": a one-line textconv
# driver turns every .tres PR into readable events). Format goals: one fact per line,
# model order preserved, no timestamps or volatile ids — identical sheets must dump
# identical text.
@tool
extends RefCounted
class_name EventSheetTextDump

static func dump(sheet: EventSheetResource) -> String:
	if sheet == null:
		return "(not an event sheet)"
	var lines: PackedStringArray = PackedStringArray()
	lines.append("EVENT SHEET%s" % (" class %s" % sheet.custom_class_name if not sheet.custom_class_name.is_empty() else ""))
	if sheet.behavior_mode:
		lines.append("  behavior (host: %s)" % sheet.host_class)
	elif sheet.autoload_mode:
		lines.append("  autoload %s" % sheet.autoload_name)
	else:
		lines.append("  extends %s" % sheet.host_class)
	var variable_names: Array = sheet.variables.keys()
	variable_names.sort()
	for variable_name: Variant in variable_names:
		var descriptor: Variant = sheet.variables[variable_name]
		if descriptor is Dictionary:
			lines.append("VAR %s: %s = %s%s" % [str(variable_name), str(descriptor.get("type", "Variant")), str(descriptor.get("default")), "" if bool(descriptor.get("exported", true)) else " (private)"])
	_dump_rows(sheet.events, lines, 0)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry
			lines.append("FUNCTION %s(%s)%s" % [event_function.function_name, ", ".join(_param_names(event_function)), " [ACE: %s]" % event_function.ace_display_name if event_function.expose_as_ace else ""])
			_dump_rows(event_function.events if not event_function.events.is_empty() else event_function.rows, lines, 1)
	return "\n".join(lines) + "\n"

static func _dump_rows(rows: Array, lines: PackedStringArray, depth: int) -> void:
	var pad: String = "  ".repeat(depth)
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			lines.append("%sGROUP %s%s%s" % [pad, group.group_name, "" if group.enabled else " (disabled)", " (runtime-toggleable)" if group.runtime_toggleable else ""])
			if not group.description.is_empty():
				lines.append("%s  : %s" % [pad, group.description.replace("\n", " / ")])
			_dump_rows(group.events if not group.events.is_empty() else group.rows, lines, depth + 1)
		elif row is CommentRow:
			lines.append("%s# %s" % [pad, (row as CommentRow).text.replace("\n", "\n%s# " % pad)])
		elif row is RawCodeRow:
			lines.append("%sGDSCRIPT:" % pad)
			for code_line: String in (row as RawCodeRow).code.split("\n"):
				lines.append("%s| %s" % [pad, code_line])
		elif row is LocalVariable:
			var local: LocalVariable = row
			lines.append("%sVAR %s: %s = %s" % [pad, local.name, local.type_name, str(local.default_value)])
		elif row is EventRow:
			var event: EventRow = row
			var mode: String = " [OR]" if event.condition_mode == EventRow.ConditionMode.OR else ""
			lines.append("%sEVENT %s/%s%s%s" % [pad, event.trigger_provider_id, event.trigger_id, mode, "" if event.enabled else " (disabled)"])
			for condition: Variant in event.conditions:
				if condition is ACECondition:
					lines.append("%s  IF %s%s %s" % [pad, "NOT " if (condition as ACECondition).negated else "", (condition as ACECondition).ace_id, _params_text((condition as ACECondition).params)])
			for action: Variant in event.actions:
				if action is ACEAction:
					lines.append("%s  DO %s %s" % [pad, (action as ACEAction).ace_id, _params_text((action as ACEAction).params)])
				elif action is RawCodeRow:
					for code_line: String in (action as RawCodeRow).code.split("\n"):
						lines.append("%s  | %s" % [pad, code_line])
				elif action is CommentRow:
					lines.append("%s  # %s" % [pad, (action as CommentRow).text.replace("\n", " / ")])
			_dump_rows(event.sub_events, lines, depth + 1)

static func _params_text(params: Dictionary) -> String:
	if params.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var keys: Array = params.keys()
	keys.sort()
	for key: Variant in keys:
		parts.append("%s=%s" % [str(key), str(params[key])])
	return "{%s}" % ", ".join(parts)

static func _param_names(event_function: EventFunction) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if param is ACEParam:
			names.append((param as ACEParam).id)
	return names
