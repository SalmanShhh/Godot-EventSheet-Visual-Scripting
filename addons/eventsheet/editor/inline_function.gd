@tool
class_name EventSheetInlineOps
extends RefCounted
# Godot EventSheets - INLINE, the inverse of Extract to Function.
#
# Extract to Function (dock/extract_ops.gd) is a one-way door: a run of actions becomes a named
# verb and a Call row, and nothing anywhere puts the body back. That matters more than it sounds -
# extraction refuses when a captured local is not visible, so authors extract, hit the refusal
# shape, and have no clean way back; and a verb published early cannot be un-published without
# leaving broken Call rows behind.
#
#   INLINE THIS CALL          - replaces one Call row with the verb's body rows, in place.
#   INLINE EVERYWHERE, REMOVE - does that at every call site, then deletes the verb.
#
# It mirrors extract_actions_to_function deliberately: both are pure statics over a passed sheet,
# so the suite pins them headlessly, and the dock only supplies the undo funnel.
#
# ARGUMENTS ARE THE HONEST LIMIT. A verb with parameters is inlined by RENAMING each parameter to
# the expression the call passes - and only a plain identifier can be renamed safely, because the
# rename is EventSheetRefactor.rename_symbol, the same whole-word rewrite "Rename Everywhere…"
# runs. A call passing `speed * 2` would need real expression substitution to stay correct, so it
# is refused with the reason rather than inlined into something that reads right and runs wrong.
# The renames run through the two-phase sentinel dance Paste Special uses, so swapping two
# parameters is a swap rather than a collapse.

## The sentinel a parameter name is parked on between its own name and the argument's, so
## inlining `move(a, b)` into `func move(b, a)` cannot collapse both onto one name.
const _PARAM_SENTINEL := "__eventsheet_inline_param_%d"


## The verb's body actions, or [] when its body is not a plain statement run this can splice in.
## Extract to Function writes exactly one trigger-less, condition-less event holding the actions;
## anything else (a guarded body, several events, a loop) is real structure that would change
## meaning if it were flattened into a caller, so it reads as "not inlinable" here.
static func body_actions(function: EventFunction) -> Array:
	if function == null:
		return []
	var rows: Array = function.events if not function.events.is_empty() else function.rows
	if rows.size() != 1 or not (rows[0] is EventRow):
		return []
	var body: EventRow = rows[0] as EventRow
	if body.trigger != null or not body.trigger_id.strip_edges().is_empty():
		return []
	if not body.conditions.is_empty() or not body.sub_events.is_empty() or not body.pick_filters.is_empty():
		return []
	return body.actions


## The function a Call action targets, or "" when the action is not a call to a sheet function.
## A call is always Core/CallFunction carrying the name in its params - the same shape Extract to
## Function writes and the renderer draws under the ƒ chip.
static func called_function_name(action: Variant) -> String:
	if not (action is ACEAction):
		return ""
	var call_action: ACEAction = action as ACEAction
	if not (call_action.provider_id.is_empty() or call_action.provider_id == "Core") or call_action.ace_id != "CallFunction":
		return ""
	var params: Dictionary = call_action.params if not call_action.params.is_empty() else call_action.parameters
	return str(params.get("function_name", "")).strip_edges()


static func find_function(sheet: EventSheetResource, function_name: String) -> EventFunction:
	if sheet == null or function_name.is_empty():
		return null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


## The refusal reason for inlining the action at `call_index` of `event`, or "" when it can be
## inlined. Each refusal names what would go wrong, so the message doubles as the fix.
static func inline_refusal(sheet: EventSheetResource, event: EventRow, call_index: int) -> String:
	if sheet == null or event == null or call_index < 0 or call_index >= event.actions.size():
		return "Right-click a Call row to inline the verb it calls."
	var function_name: String = called_function_name(event.actions[call_index])
	if function_name.is_empty():
		return "That row isn't a call to a sheet verb - inline replaces a Call with the verb's own rows."
	var function: EventFunction = find_function(sheet, function_name)
	if function == null:
		return "This sheet has no verb called %s to inline." % function_name
	if body_actions(function).is_empty():
		return "%s's body isn't a plain run of actions (it has conditions, loops or several events), so it can't be spliced into the caller." % function_name
	var argument_problem: String = _argument_refusal(function, event.actions[call_index] as ACEAction)
	if not argument_problem.is_empty():
		return argument_problem
	return ""


## Replaces the Call at `call_index` with a COPY of the verb's body actions, parameters renamed
## to the arguments the call passes. Returns true when rows were spliced in. The verb itself is
## untouched - other callers keep working, which is what makes this safe to try and undo.
static func inline_function_call(sheet: EventSheetResource, event: EventRow, call_index: int) -> bool:
	if not inline_refusal(sheet, event, call_index).is_empty():
		return false
	var call_action: ACEAction = event.actions[call_index] as ACEAction
	var function: EventFunction = find_function(sheet, called_function_name(call_action))
	var spliced: Array[Resource] = _bound_body_copy(function, call_action)
	if spliced.is_empty():
		return false
	event.actions.remove_at(call_index)
	for offset: int in range(spliced.size()):
		event.actions.insert(call_index + offset, spliced[offset])
	return true


## Every call site of `function_name` in the sheet, as [{event, index}] - the sheet's own rows,
## rows nested in groups and sub-events, and the bodies of the OTHER verbs (a verb calling a verb
## is an ordinary call, and leaving those behind is exactly how a removed verb breaks a sheet).
static func calls_to(sheet: EventSheetResource, function_name: String) -> Array:
	var found: Array = []
	if sheet == null or function_name.is_empty():
		return found
	_collect_calls(sheet.events, function_name, found)
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name != function_name:
			_collect_calls((entry as EventFunction).events, function_name, found)
	return found


## The refusal reason for folding `function` back into its callers and deleting it, or "".
static func inline_everywhere_refusal(sheet: EventSheetResource, function: EventFunction) -> String:
	if sheet == null or function == null:
		return "Right-click a verb's Define row to fold it back into its callers."
	if body_actions(function).is_empty():
		return "%s's body isn't a plain run of actions, so it can't be spliced into its callers." % function.function_name
	for site: Dictionary in calls_to(sheet, function.function_name):
		var problem: String = inline_refusal(sheet, site.get("event", null) as EventRow, int(site.get("index", -1)))
		if not problem.is_empty():
			return problem
	# A verb that calls ITSELF would inline forever; the caller list above cannot see that.
	for action: Variant in body_actions(function):
		if called_function_name(action) == function.function_name:
			return "%s calls itself - inlining it would never finish." % function.function_name
	return ""


## Inlines every call to `function` and removes the verb from the sheet. Returns the number of
## call sites folded back in, or -1 when refused. One pass over a re-resolved call list per site,
## so a body that itself contains calls to OTHER verbs travels in untouched.
static func inline_everywhere_and_remove(sheet: EventSheetResource, function: EventFunction) -> int:
	if not inline_everywhere_refusal(sheet, function).is_empty():
		return -1
	var function_name: String = function.function_name
	var inlined: int = 0
	# Re-resolved every round: splicing a body in shifts the indices of the sites after it.
	var guard: int = 0
	while guard < 1000:
		guard += 1
		var sites: Array = calls_to(sheet, function_name)
		if sites.is_empty():
			break
		var site: Dictionary = sites[0]
		if not inline_function_call(sheet, site.get("event", null) as EventRow, int(site.get("index", -1))):
			break
		inlined += 1
	sheet.functions.erase(function)
	return inlined


## The status sentence both inline gestures report, so the two read as one gesture.
static func summary(function_name: String, sites: int, rows: int) -> String:
	return "Inlined %s at %d call site(s) - %d row(s) landed where the call was." % [function_name, sites, rows]


## A deep copy of the verb's body actions with each parameter renamed to the argument the call
## passes. The rename runs on a SCRATCH sheet holding just those rows, which is what lets the
## shipped rename_symbol (params, templates, raw code and pick filters in one pass) do the work.
static func _bound_body_copy(function: EventFunction, call_action: ACEAction) -> Array[Resource]:
	var copies: Array[Resource] = []
	for action: Variant in body_actions(function):
		if action is Resource:
			copies.append((action as Resource).duplicate(true))
	if copies.is_empty():
		return copies
	var pairs: Array = _argument_pairs(function, call_action)
	if pairs.is_empty():
		return copies
	var carrier: EventRow = EventRow.new()
	carrier.actions = copies
	var scratch: EventSheetResource = EventSheetResource.new()
	var scratch_rows: Array[Resource] = [carrier]
	scratch.events = scratch_rows
	# String literals are left alone (the fourth argument): this is a VALUE substitution, not the
	# author renaming a concept, so a body that prints "who is out" keeps printing "who is out"
	# after `who` is bound to the argument the call passed.
	for index: int in range(pairs.size()):
		EventSheetRefactor.rename_symbol(scratch, str((pairs[index] as Array)[0]), _PARAM_SENTINEL % index, true)
	for index: int in range(pairs.size()):
		EventSheetRefactor.rename_symbol(scratch, _PARAM_SENTINEL % index, str((pairs[index] as Array)[1]), true)
	return carrier.actions


## [param_name, argument] for every parameter the verb declares, in order. Empty when the verb
## takes none (the common Extract-to-Function shape) - then the body copies in verbatim.
static func _argument_pairs(function: EventFunction, call_action: ACEAction) -> Array:
	var pairs: Array = []
	if function.params.is_empty():
		return pairs
	var params: Dictionary = call_action.params if not call_action.params.is_empty() else call_action.parameters
	var arguments: PackedStringArray = _split_arguments(str(params.get("args", "")))
	for index: int in range(function.params.size()):
		if index >= arguments.size():
			break
		var parameter: ACEParam = function.params[index]
		var argument: String = arguments[index].strip_edges()
		if parameter == null or parameter.id.strip_edges().is_empty() or argument == parameter.id.strip_edges():
			continue
		pairs.append([parameter.id.strip_edges(), argument])
	return pairs


## Why this call's arguments block the inline, or "". Only a whole identifier can be substituted
## by the whole-word rename; an expression would need real substitution to stay correct.
static func _argument_refusal(function: EventFunction, call_action: ACEAction) -> String:
	if function.params.is_empty() or call_action == null:
		return ""
	var params: Dictionary = call_action.params if not call_action.params.is_empty() else call_action.parameters
	var arguments: PackedStringArray = _split_arguments(str(params.get("args", "")))
	if arguments.size() != function.params.size():
		return "%s takes %d value(s) and this call passes %d - inline needs them to line up." % [
			function.function_name, function.params.size(), arguments.size()]
	for argument: String in arguments:
		if not argument.strip_edges().is_valid_identifier():
			return "This call passes the expression \"%s\" - inline can only re-point a plain name. Put the expression in a variable first, then inline." % argument.strip_edges()
	return ""


## Splits a call's argument text on top-level commas only, so `max(a, b), c` stays two arguments.
static func _split_arguments(text: String) -> PackedStringArray:
	var arguments: PackedStringArray = PackedStringArray()
	if text.strip_edges().is_empty():
		return arguments
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var current: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if in_string:
			current += character
			if character == quote and (index == 0 or text[index - 1] != "\\"):
				in_string = false
			continue
		if character == "\"" or character == "'":
			in_string = true
			quote = character
			current += character
			continue
		if character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		if character == "," and depth == 0:
			arguments.append(current)
			current = ""
			continue
		current += character
	arguments.append(current)
	return arguments


static func _collect_calls(rows: Array, function_name: String, found: Array) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_collect_calls(group.events if not group.events.is_empty() else group.rows, function_name, found)
			continue
		if not (entry is EventRow):
			continue
		var event: EventRow = entry as EventRow
		for action_index: int in range(event.actions.size()):
			if called_function_name(event.actions[action_index]) == function_name:
				found.append({"event": event, "index": action_index})
		_collect_calls(event.sub_events, function_name, found)
