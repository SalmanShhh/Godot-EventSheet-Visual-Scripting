# Godot EventSheets - R41. WHERE A LOCAL VARIABLE CAN BE SEEN.
#
# An event sheet declares a local at the top of an event, and that local is visible from there to the
# end of the body it was declared in, and inside everything nested under it - nothing else. A
# function body opens as a RUN of sibling events, so the scope is "this event and the ones after it
# in the same list, subtrees included", not "this event alone": an action moved down a body is still
# in scope, and one moved into another function is not.
#
# The sheet can therefore say so out loud - an action dragged out of its variable's scope is refused
# by name before it lands - and can light up every other use of the name the cursor is on.
#
# Everything here is a pure read of the sheet: nothing is written, nothing is cached, and the answer
# is only ever asked for while a drag or a hover is in the air.
@tool
class_name EventSheetLocalScope
extends RefCounted

## Identifiers that are never a local of this sheet, however they are spelled in a row.
const RESERVED: Array[String] = [
	"self", "true", "false", "null", "and", "or", "not", "in", "is", "if", "else", "elif", "for",
	"while", "return", "var", "const", "func", "await", "match", "break", "continue", "pass"
]


## {name: true} for every local this sheet declares, anywhere - the set a name has to be IN before a
## refusal can be about scope at all. A name nothing declares is a member, a global or a built-in,
## and none of those move with an event.
static func declared_locals(sheet: EventSheetResource) -> Dictionary:
	var names: Dictionary = {}
	if sheet == null:
		return names
	for event_entry: Variant in sheet.events:
		_collect_declared(event_entry, names, 0)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			for event_entry: Variant in (function_entry as EventFunction).events:
				_collect_declared(event_entry, names, 0)
	return names


## {name: true} for the locals an action sitting in `target_event` can see: the ones declared on that
## event and on every event above it. Empty when the target is not an event of this sheet, which is
## the honest answer - a target the walk cannot place says nothing about scope.
static func visible_locals(sheet: EventSheetResource, target_event: EventRow) -> Dictionary:
	var names: Dictionary = {}
	if sheet == null or target_event == null:
		return names
	var target_id: int = target_event.get_instance_id()
	for name_text: String in declared_locals(sheet):
		if scope_event_ids(sheet, name_text).has(target_id):
			names[name_text] = true
	return names


## The first name an action USES that this sheet declares as a local but that is not visible at
## `target_event`, or "" when every name it uses is in scope. The one name is what the refusal says,
## because a reader fixes one thing at a time.
##
## A name the dragged rows DECLARE is never refused here: a declaration takes its scope with it, and
## moving one is the whole point of being able to drag a Local row. What a moved declaration can
## break is the rows it leaves behind, which is the question `stranded_name` asks.
static func out_of_scope_name(sheet: EventSheetResource, target_event: EventRow,
		resources: Array) -> String:
	if sheet == null or target_event == null or resources.is_empty():
		return ""
	var declared: Dictionary = declared_locals(sheet)
	if declared.is_empty():
		return ""
	var moving: Dictionary = declared_by(resources)
	var visible: Dictionary = visible_locals(sheet, target_event)
	for resource: Variant in resources:
		for name_text: String in referenced_names(resource):
			if declared.has(name_text) and not visible.has(name_text) and not moving.has(name_text):
				return name_text
	return ""


## R41. The first local the drop would STRAND - a name the dragged rows declare that a row staying
## behind still uses, from somewhere the declaration would no longer reach - or "" when the move is
## safe. Moving a declaration is allowed to change what the sheet says; it is not allowed to leave a
## use of the name with nothing to read.
static func stranded_name(sheet: EventSheetResource, target_event: EventRow,
		resources: Array) -> String:
	if sheet == null or target_event == null or resources.is_empty():
		return ""
	var moving: Dictionary = declared_by(resources)
	if moving.is_empty():
		return ""
	var reach: Dictionary = _scope_if_declared_at(sheet, target_event)
	var staying: Dictionary = {}
	for resource: Variant in resources:
		staying[resource] = true
	for name_text: String in moving:
		if _name_used_outside(sheet, name_text, staying, reach):
			return name_text
	return ""


## {name: true} for every local the dragged rows themselves declare.
static func declared_by(resources: Array) -> Dictionary:
	var names: Dictionary = {}
	for resource: Variant in resources:
		if resource is LocalVariable:
			var variable_name: String = (resource as LocalVariable).name.strip_edges()
			if not variable_name.is_empty():
				names[variable_name] = true
			continue
		if resource is ACEAction and (resource as ACEAction).ace_id.begins_with("SetLocal"):
			var action: ACEAction = resource as ACEAction
			var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
			var action_name: String = str(params.get("name", "")).strip_edges()
			if not action_name.is_empty():
				names[action_name] = true
			continue
		if resource is RawCodeRow:
			for line: String in (resource as RawCodeRow).code.split("\n"):
				var declared_line: String = declared_name_of_line(line)
				if not declared_line.is_empty():
					names[declared_line] = true
	return names


## {EventRow instance id: true} for the events a local WOULD reach if it were declared on
## `target_event` - that event, the ones after it in the same list, and every subtree under them.
## The same rule `_scope_in_container` reads off the sheet, asked of a place rather than of a name.
static func _scope_if_declared_at(sheet: EventSheetResource, target_event: EventRow) -> Dictionary:
	var ids: Dictionary = {}
	if sheet == null or target_event == null:
		return ids
	_reach_in_container(sheet.events, target_event, ids, 0)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_reach_in_container((function_entry as EventFunction).events, target_event, ids, 0)
	return ids


static func _reach_in_container(container: Array, target_event: EventRow, ids: Dictionary,
		depth: int) -> void:
	if depth > 64:
		return
	var found_at: int = -1
	for index in container.size():
		var entry: Variant = container[index]
		if not (entry is EventRow):
			continue
		if entry == target_event:
			found_at = index
		_reach_in_container((entry as EventRow).sub_events, target_event, ids, depth + 1)
	if found_at < 0:
		return
	for index in range(found_at, container.size()):
		if container[index] is EventRow:
			_mark_subtree(container[index] as EventRow, ids, 0)


## True when some row of the sheet that is NOT moving mentions `name` from an event the declaration
## would no longer reach.
static func _name_used_outside(sheet: EventSheetResource, name: String, moving: Dictionary,
		reach: Dictionary) -> bool:
	for event_entry: Variant in sheet.events:
		if _uses_name(event_entry, name, moving, reach, 0):
			return true
	for function_entry: Variant in sheet.functions:
		if not (function_entry is EventFunction):
			continue
		for event_entry: Variant in (function_entry as EventFunction).events:
			if _uses_name(event_entry, name, moving, reach, 0):
				return true
	return false


static func _uses_name(entry: Variant, name: String, moving: Dictionary, reach: Dictionary,
		depth: int) -> bool:
	if depth > 64 or not (entry is EventRow):
		return false
	var event_row: EventRow = entry as EventRow
	if not reach.has(event_row.get_instance_id()):
		var rows: Array = []
		rows.append_array(event_row.conditions)
		rows.append_array(event_row.actions)
		for row_entry: Variant in rows:
			if row_entry == null or moving.has(row_entry):
				continue
			if mentions_name(resource_text(row_entry), name):
				return true
	for child: Variant in event_row.sub_events:
		if _uses_name(child, name, moving, reach, depth + 1):
			return true
	return false


## {EventRow instance id: true} for every event `name` can be USED in - the event that declares it
## and everything under that event. Empty when no event of this sheet declares the name, which is
## what keeps the highlight off members, globals and the language's own words.
static func scope_event_ids(sheet: EventSheetResource, name: String) -> Dictionary:
	var ids: Dictionary = {}
	if sheet == null or name.strip_edges().is_empty():
		return ids
	_scope_in_container(sheet.events, name.strip_edges(), ids, 0)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_scope_in_container((function_entry as EventFunction).events, name.strip_edges(), ids, 0)
	return ids


## One list of sibling events - a function body, or the sheet's top level. A local declared partway
## down a body is visible from THERE to the end of that body, and inside everything nested under it:
## the importer splits a body into sibling events, so the events after the declaration are the rest
## of the same scope, not a different one.
static func _scope_in_container(container: Array, name: String, ids: Dictionary, depth: int) -> void:
	if depth > 64:
		return
	var declared_at: int = -1
	for index in container.size():
		var entry: Variant = container[index]
		if not (entry is EventRow):
			continue
		if declared_at < 0:
			var own: Dictionary = {}
			_collect_own_declarations(entry as EventRow, own)
			if own.has(name):
				declared_at = index
		# A body nested under this event is its own scope: a name declared there is a different
		# variable, and the walk has to reach it wherever it is.
		_scope_in_container((entry as EventRow).sub_events, name, ids, depth + 1)
	if declared_at < 0:
		return
	for index in range(declared_at, container.size()):
		if container[index] is EventRow:
			_mark_subtree(container[index] as EventRow, ids, 0)


static func _mark_subtree(event_row: EventRow, ids: Dictionary, depth: int) -> void:
	if depth > 64 or event_row == null:
		return
	ids[event_row.get_instance_id()] = true
	for child: Variant in event_row.sub_events:
		if child is EventRow:
			_mark_subtree(child as EventRow, ids, depth + 1)


## True when `text` mentions `name` as a WHOLE word - the test a highlight needs, so `hp` never
## lights up inside `hp_bar`.
static func mentions_name(text: String, name: String) -> bool:
	if name.is_empty():
		return false
	for word: String in identifiers_in(text):
		if word == name:
			return true
	return false


## The identifiers a row's text mentions, with string literals and the language's own words left out.
## Deliberately generous: a name that only LOOKS used costs a refusal a reader can see and undo by
## dropping somewhere else, while a name missed costs a drop that breaks the file silently.
static func referenced_names(resource: Variant) -> PackedStringArray:
	return identifiers_in(resource_text(resource))


## The text a row stands for - the code of a hand-written row, the parameter values of a picked one.
static func resource_text(resource: Variant) -> String:
	if resource is RawCodeRow:
		return (resource as RawCodeRow).code
	if resource is ACEAction:
		var action: ACEAction = resource as ACEAction
		var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
		var parts: PackedStringArray = PackedStringArray()
		for key: Variant in params:
			parts.append(str(params[key]))
		return " ".join(parts)
	if resource is ACECondition:
		var condition: ACECondition = resource as ACECondition
		var condition_params: Dictionary = (condition.params if not condition.params.is_empty()
			else condition.parameters)
		var condition_parts: PackedStringArray = PackedStringArray()
		for key: Variant in condition_params:
			condition_parts.append(str(condition_params[key]))
		return " ".join(condition_parts)
	if resource is CommentRow:
		return ""
	return ""


## Every identifier in a piece of GDScript-ish text, outside string literals. Member reads keep only
## their HEAD (`t.finished` answers `t`), because that head is the name a scope owns.
static func identifiers_in(text: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	var index: int = 0
	var previous: String = ""
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			index = _string_end(text, index) + 1
			previous = "\""
			continue
		if not (character.is_valid_identifier() or character == "_"):
			previous = character
			index += 1
			continue
		var start: int = index
		while index < text.length():
			var next_character: String = text[index]
			if next_character.is_valid_identifier() or next_character == "_" or next_character.is_valid_int():
				index += 1
				continue
			break
		var word: String = text.substr(start, index - start)
		# A member read belongs to whatever is in front of the dot, so only the head is a candidate.
		if previous != "." and not RESERVED.has(word) and not word.is_valid_int() and not seen.has(word):
			seen[word] = true
			names.append(word)
		previous = "."  if index < text.length() and text[index] == "." else ""
	return names


## The index of the quote closing the string opening at `start`, or the last index when it never
## closes. Escapes are honoured, so `"a\"b"` is one string.
static func _string_end(text: String, start: int) -> int:
	var quote: String = text[start]
	var index: int = start + 1
	while index < text.length():
		if text[index] == "\\":
			index += 2
			continue
		if text[index] == quote:
			return index
		index += 1
	return text.length() - 1


static func _collect_declared(entry: Variant, names: Dictionary, depth: int) -> void:
	if depth > 64 or not (entry is EventRow):
		return
	_collect_own_declarations(entry as EventRow, names)
	for child: Variant in (entry as EventRow).sub_events:
		_collect_declared(child, names, depth + 1)


## The locals ONE event declares: the sheet's own Local variable rows, the Local Variable actions the
## picker writes, and a hand-written `var name = …` line the file still holds as text.
static func _collect_own_declarations(event_row: EventRow, names: Dictionary) -> void:
	if event_row == null:
		return
	for local_entry: Variant in event_row.local_variables:
		if local_entry is LocalVariable:
			var declared_name: String = (local_entry as LocalVariable).name.strip_edges()
			if not declared_name.is_empty():
				names[declared_name] = true
	for action_entry: Variant in event_row.actions:
		if action_entry is ACEAction:
			var action: ACEAction = action_entry as ACEAction
			if not action.ace_id.begins_with("SetLocal"):
				continue
			var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
			var action_name: String = str(params.get("name", "")).strip_edges()
			if not action_name.is_empty():
				names[action_name] = true
			continue
		if action_entry is RawCodeRow:
			for line: String in (action_entry as RawCodeRow).code.split("\n"):
				var declared_line: String = declared_name_of_line(line)
				if not declared_line.is_empty():
					names[declared_line] = true


## The local a `var name …` / `const name …` line declares, or "" when the line declares nothing.
static func declared_name_of_line(line: String) -> String:
	var text: String = line.strip_edges()
	if not (text.begins_with("var ") or text.begins_with("const ")):
		return ""
	var rest: String = text.substr(4) if text.begins_with("var ") else text.substr(6)
	var stop: int = rest.length()
	for index in rest.length():
		var character: String = rest[index]
		if character.is_valid_identifier() or character == "_" or character.is_valid_int():
			continue
		stop = index
		break
	var name_text: String = rest.substr(0, stop).strip_edges()
	return name_text if not name_text.is_empty() and not RESERVED.has(name_text) else ""
