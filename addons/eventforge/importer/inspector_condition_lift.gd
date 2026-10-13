# EventForge - a sheet-written _validate_property, read back as the Show if / Lock unless it came from.
#
# THE CANONICAL SHAPE. A variable's Show if / Lock unless compiles to one generated function after the
# last variable, plus a setter on each variable a condition reads, so the Inspector refreshes the moment
# that variable changes:
#
#     @export var use_noise: bool = true:
#         set(value):
#             use_noise = value
#             notify_property_list_changed()
#     @export var noise_seed: int = 1234
#
#     ## Inspector conditions (Show If / Lock Unless) ... generated; edit via the Variable dialog.
#     func _validate_property(property: Dictionary) -> void:
#         if str(property.name) == "noise_seed" and not bool(use_noise):
#             property.usage &= ~PROPERTY_USAGE_EDITOR
#
# Opened again, that file would read as a function and a setter event that nobody wrote by hand. This
# takes them back to what wrote them: the conditions onto the variables, and the refresh-only setters
# dropped, because the compiler writes them again from the conditions. Byte-gated as a whole - the file
# must recompile to exactly the text it was opened from - so any hand-edited variant stays the function
# and the setters it already was.
extends RefCounted

const HEADER: String = "func _validate_property(property: Dictionary) -> void:"
const HIDE_LINE: String = "\t\tproperty.usage &= ~PROPERTY_USAGE_EDITOR"
const LOCK_LINE: String = "\t\tproperty.usage |= PROPERTY_USAGE_READ_ONLY"
const VERIFY_PATH: String = "user://eventforge_lift_verify.gd"


## Lifts the generated function in `sheet` (an import of `source`, before any statement lift) back onto
## its variables. Returns true when it did; false leaves the sheet exactly as it was.
static func lift(sheet: EventSheetResource, source: String) -> bool:
	if sheet == null or not source.contains("\n" + HEADER):
		return false
	var function_index: int = -1
	for index: int in range(1, sheet.events.size()):
		if sheet.events[index] is RawCodeRow and (sheet.events[index] as RawCodeRow).code.begins_with(HEADER + "\n"):
			function_index = index
			break
	if function_index < 0 or not (sheet.events[function_index - 1] is RawCodeRow):
		return false
	var doc_row: RawCodeRow = sheet.events[function_index - 1] as RawCodeRow
	var doc_lines: PackedStringArray = doc_row.code.split("\n")
	if doc_lines.size() < 2 or doc_lines[doc_lines.size() - 1] != SheetCompiler.INSPECTOR_CONDITIONS_DOC or doc_lines[doc_lines.size() - 2] != "":
		return false
	var conditions: Array = _read_conditions((sheet.events[function_index] as RawCodeRow).code)
	var variables: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			variables[(entry as LocalVariable).name] = entry
	# Everything this touches, so a refusal puts it all back.
	var saved_events: Array = sheet.events.duplicate()
	var saved_doc: String = doc_row.code
	var saved_variables: Array = []
	for row: Variant in variables.values():
		var variable: LocalVariable = row as LocalVariable
		saved_variables.append([variable, (variable.attributes as Dictionary).duplicate(true) if variable.attributes is Dictionary else {}, variable.setter_body])
	if conditions.is_empty() or not _apply_conditions(conditions, variables):
		_restore(sheet, saved_events, doc_row, saved_doc, saved_variables)
		return false
	_drop_refresh_setters(conditions, variables)
	sheet.events.remove_at(function_index)
	if doc_lines.size() == 2:
		sheet.events.remove_at(function_index - 1)
	else:
		doc_row.code = "\n".join(doc_lines.slice(0, doc_lines.size() - 2))
	var saved_path: String = sheet.external_source_path
	sheet.external_source_path = VERIFY_PATH
	var output: String = str(SheetCompiler.compile(sheet, VERIFY_PATH).get("output", ""))
	sheet.external_source_path = saved_path
	if output == source:
		return true
	_restore(sheet, saved_events, doc_row, saved_doc, saved_variables)
	return false


## The function's entries as [name, predicate, kind], or [] when any line is not one the compiler writes.
static func _read_conditions(code: String) -> Array:
	var lines: PackedStringArray = code.split("\n")
	var entries: Array = []
	var index: int = 1
	while index < lines.size():
		var test: String = lines[index]
		var prefix: String = "\tif str(property.name) == \""
		var middle: String = "\" and not bool("
		if index + 1 >= lines.size() or not test.begins_with(prefix) or not test.ends_with("):") or not test.contains(middle):
			return []
		var inner: String = test.substr(prefix.length(), test.length() - prefix.length() - 2)
		var name: String = inner.substr(0, inner.find(middle))
		var predicate: String = inner.substr(inner.find(middle) + middle.length())
		if not name.is_valid_identifier() or not predicate.is_valid_identifier():
			return []
		var effect: String = lines[index + 1]
		if effect != HIDE_LINE and effect != LOCK_LINE:
			return []
		entries.append([name, predicate, "show_if" if effect == HIDE_LINE else "lock_unless"])
		index += 2
	return entries


## Writes each entry onto its variable. A hide whose predicate is the variable's group show-if (read off
## the comment above its group line) is that group form, not a second field-level show-if.
static func _apply_conditions(conditions: Array, variables: Dictionary) -> bool:
	var group_form_used: Dictionary = {}
	for condition: Array in conditions:
		var variable: LocalVariable = variables.get(str(condition[0])) as LocalVariable
		if variable == null:
			return false
		var attributes: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
		var predicate: String = str(condition[1])
		var key: String = str(condition[2])
		if key == "show_if" and str(attributes.get("group_show_if", "")) == predicate and not group_form_used.has(variable.name):
			group_form_used[variable.name] = true
			continue
		if attributes.has(key):
			return false
		attributes[key] = predicate
		variable.attributes = attributes
	return true


## The setters that only refresh the Inspector go: the compiler writes them again from the conditions.
static func _drop_refresh_setters(conditions: Array, variables: Dictionary) -> void:
	for condition: Array in conditions:
		var controller: LocalVariable = variables.get(str(condition[1])) as LocalVariable
		if controller != null and controller.getter_body.is_empty() and controller.setter_param == "value" \
				and controller.setter_body == "%s = value\nnotify_property_list_changed()" % controller.name:
			controller.setter_body = ""


static func _restore(sheet: EventSheetResource, events: Array, doc_row: RawCodeRow, doc_code: String, variables: Array) -> void:
	sheet.events.assign(events)
	doc_row.code = doc_code
	for saved: Array in variables:
		(saved[0] as LocalVariable).attributes = saved[1]
		(saved[0] as LocalVariable).setter_body = str(saved[2])
