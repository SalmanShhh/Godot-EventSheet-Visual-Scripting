# Godot EventSheets — model-level refactors (True Rename)
#
# Word-boundary symbol rename across every surface a name can appear in:
# the variables key itself, LocalVariable rows, ACE param values and comments,
# raw-code rows (row- and ACE-level), pick filters, trigger args, other variables'
# attribute strings (show_if etc.), function names and bodies — and comments/prose,
# deliberately (a rename should keep prose honest; the opposite trade from the
# doctor's usage detection, which excludes comments).
#
# What it never touches: codegen templates, preludes and member declarations —
# those are machine-baked from descriptors and substitute params at compile time;
# a variable named "value" must not rewrite a `{value}` placeholder (covenant:
# refactors rewrite sheet model text, never baked machinery).
@tool
extends RefCounted
class_name EventSheetRefactor

## "" when the rename is allowed, else the user-facing problem.
static func validate_new_name(sheet: EventSheetResource, old_name: String, new_name: String) -> String:
	if not new_name.is_valid_identifier():
		return "\"%s\" is not a valid identifier." % new_name
	if new_name == old_name:
		return "That's already the name."
	if sheet.variables.has(new_name):
		return "A variable named \"%s\" already exists." % new_name
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction and (function_entry as EventFunction).function_name == new_name:
			return "A function named \"%s\" already exists." % new_name
	return ""

## Renames a variable or function across the sheet. Returns the replacement count
## (0 = the symbol appears nowhere, including as a declaration).
static func rename_symbol(sheet: EventSheetResource, old_name: String, new_name: String) -> int:
	if sheet == null or old_name.is_empty():
		return 0
	var counter: Dictionary = {"count": 0}
	var regex: RegEx = RegEx.create_from_string("\\b%s\\b" % old_name)
	# The declaration itself: a sheet-variables key (order preserved — Dictionaries
	# keep insertion order, so rebuild in place)…
	if sheet.variables.has(old_name):
		var rebuilt: Dictionary = {}
		for key: Variant in sheet.variables:
			rebuilt[new_name if str(key) == old_name else key] = sheet.variables[key]
		sheet.variables = rebuilt
		counter["count"] = int(counter["count"]) + 1
	# …or a function name.
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry
			if event_function.function_name == old_name:
				event_function.function_name = new_name
				counter["count"] = int(counter["count"]) + 1
			_rename_in_rows(event_function.events if not event_function.events.is_empty() else event_function.rows, regex, new_name, counter)
	# Attribute strings on every variable may reference the symbol (show_if, on_changed…).
	for key: Variant in sheet.variables:
		var descriptor: Variant = sheet.variables[key]
		if descriptor is Dictionary:
			_rename_in_dictionary(descriptor, regex, new_name, counter)
	_rename_in_rows(sheet.events, regex, new_name, counter)
	return int(counter["count"])

static func _rename_in_rows(rows: Array, regex: RegEx, new_name: String, counter: Dictionary) -> void:
	for row: Variant in rows:
		if row is CommentRow:
			(row as CommentRow).text = _rename_text((row as CommentRow).text, regex, new_name, counter)
		elif row is RawCodeRow:
			(row as RawCodeRow).code = _rename_text((row as RawCodeRow).code, regex, new_name, counter)
		elif row is LocalVariable:
			var local: LocalVariable = row
			if regex.search(local.name) != null:
				local.name = _rename_text(local.name, regex, new_name, counter)
			if local.default_value is String:
				local.default_value = _rename_text(str(local.default_value), regex, new_name, counter)
		elif row is EventGroup:
			var group: EventGroup = row
			group.description = _rename_text(group.description, regex, new_name, counter)
			_rename_in_rows(group.events if not group.events.is_empty() else group.rows, regex, new_name, counter)
		elif row is EventRow:
			var event: EventRow = row
			event.trigger_args = _rename_text(event.trigger_args, regex, new_name, counter)
			for ace: Variant in event.conditions + event.actions:
				if ace is RawCodeRow:
					(ace as RawCodeRow).code = _rename_text((ace as RawCodeRow).code, regex, new_name, counter)
				elif ace is CommentRow:
					(ace as CommentRow).text = _rename_text((ace as CommentRow).text, regex, new_name, counter)
				elif ace is Resource and ace.get("params") is Dictionary:
					_rename_in_dictionary(ace.get("params") as Dictionary, regex, new_name, counter)
					if ace.get("comment") is String:
						ace.set("comment", _rename_text(str(ace.get("comment")), regex, new_name, counter))
			for pick: Variant in event.pick_filters:
				if pick is PickFilter:
					(pick as PickFilter).collection_value = _rename_text((pick as PickFilter).collection_value, regex, new_name, counter)
					(pick as PickFilter).predicate_expression = _rename_text((pick as PickFilter).predicate_expression, regex, new_name, counter)
			_rename_in_rows(event.sub_events, regex, new_name, counter)

## Rewrites String values in place (recursing into nested Dictionaries — variable
## attributes live one level down).
static func _rename_in_dictionary(values: Dictionary, regex: RegEx, new_name: String, counter: Dictionary) -> void:
	for key: Variant in values:
		var value: Variant = values[key]
		if value is String:
			values[key] = _rename_text(value, regex, new_name, counter)
		elif value is Dictionary:
			_rename_in_dictionary(value, regex, new_name, counter)

static func _rename_text(text: String, regex: RegEx, new_name: String, counter: Dictionary) -> String:
	var matches: int = regex.search_all(text).size()
	if matches == 0:
		return text
	counter["count"] = int(counter["count"]) + matches
	return regex.sub(text, new_name, true)
