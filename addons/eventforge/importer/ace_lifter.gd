# EventForge — ACE-level import lifting (reverse template matching)
#
# Turns generated GDScript back into real sheet events when a file is opened as a
# GDScript-backed sheet: lifecycle trigger functions (_ready/_process/_physics_process)
# whose bodies are `if <condition templates>:` blocks + action-template lines lift into
# EventRows; statements that match no template become in-flow GDScript blocks, so the
# event still lifts. Reverse templates come from the builtin descriptor registry
# (`{param}` placeholders become named captures; params round-trip as strings because
# codegen substitutes with plain str()).
#
# THE CONTRACT (lossless rule): lifting is all-or-nothing per file and verified by
# recompiling the whole sheet — if the output is not byte-identical to the source, the
# lift is reverted and every function stays a verbatim block row. Only the trailing run of
# trigger functions is considered (EventForge's own layout); files with other layouts
# simply keep their blocks.
@tool
extends RefCounted
class_name EventSheetACELifter

## Lifecycle handlers reversible without signal-connection analysis (v1 scope).
const LIFECYCLE_TRIGGERS: Dictionary = {
	"func _ready() -> void:": "OnReady",
	"func _process(delta: float) -> void:": "OnProcess",
	"func _physics_process(delta: float) -> void:": "OnPhysicsProcess"
}

## Attempts the lift on an imported external sheet. Mutates sheet.events only when the
## byte-identical round-trip verifies; otherwise leaves the sheet untouched.
static func attempt_lift(sheet: EventSheetResource, source: String) -> bool:
	if sheet == null:
		return false
	# The trailing run: function blocks (and the blank-only separators between them) at the
	# end of the row list — EventForge's emission layout. Anything else aborts quietly.
	var first_run_index: int = sheet.events.size()
	for index in range(sheet.events.size() - 1, -1, -1):
		var row: Variant = sheet.events[index]
		if row is RawCodeRow and ((row as RawCodeRow).code.begins_with("func ") or (row as RawCodeRow).code.strip_edges().is_empty()):
			first_run_index = index
			continue
		break
	var lifted_events: Array = []
	var saw_function: bool = false
	for index in range(first_run_index, sheet.events.size()):
		var row: RawCodeRow = sheet.events[index] as RawCodeRow
		if row.code.strip_edges().is_empty():
			continue  # blank separator between functions; emission re-adds it
		saw_function = true
		var function_events: Array = _lift_function(row.code.split("\n"))
		if function_events.is_empty():
			return false  # one unliftable function → whole file stays as blocks
		lifted_events.append_array(function_events)
	if not saw_function or lifted_events.is_empty():
		return false

	var backup: Array[Resource] = sheet.events.duplicate()
	sheet.events.resize(first_run_index)
	# Emission inserts one blank line before each trigger section; the import attached that
	# blank to the function's preceding block, so drop it to avoid doubling.
	if not sheet.events.is_empty() and sheet.events[sheet.events.size() - 1] is RawCodeRow:
		var previous: RawCodeRow = sheet.events[sheet.events.size() - 1] as RawCodeRow
		if previous.code.ends_with("\n"):
			previous.code = previous.code.substr(0, previous.code.length() - 1)
		elif previous.code.strip_edges().is_empty():
			sheet.events.remove_at(sheet.events.size() - 1)
	for event: Variant in lifted_events:
		sheet.events.append(event)

	# Verify: the lifted sheet must reproduce the source byte-for-byte.
	var saved_path: String = sheet.external_source_path
	sheet.external_source_path = "user://eventforge_lift_verify.gd"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_lift_verify.gd").get("output", ""))
	sheet.external_source_path = saved_path
	if output == source:
		return true
	sheet.events = backup
	return false

## One trigger function → EventRows ([] when the shape is not liftable).
static func _lift_function(function_lines: PackedStringArray) -> Array:
	if function_lines.is_empty() or not LIFECYCLE_TRIGGERS.has(function_lines[0]):
		return []
	var trigger_id: String = str(LIFECYCLE_TRIGGERS[function_lines[0]])
	var reverse_entries: Array = _build_reverse_entries()
	var events: Array = []
	var current: EventRow = null
	var pending_raw: PackedStringArray = PackedStringArray()
	var index: int = 1
	while index < function_lines.size():
		var line: String = function_lines[index]
		if line.strip_edges().is_empty():
			return []  # blank inside a generated body never happens; bail to blocks
		if line.begins_with("\tif ") and line.ends_with(":"):
			_flush_raw(current, pending_raw)
			current = _make_event(trigger_id)
			if not _parse_conditions(line.substr(4, line.length() - 5), current, reverse_entries):
				return []
			events.append(current)
			index += 1
			# Conditioned body: depth-2 lines belong to this event.
			while index < function_lines.size() and function_lines[index].begins_with("\t\t"):
				_consume_action_line(current, function_lines[index].substr(2), 0, pending_raw, reverse_entries)
				index += 1
			_flush_raw(current, pending_raw)
			current = null
			continue
		if not line.begins_with("\t"):
			return []  # dedented content inside a function — not our shape
		# Unconditioned statement at depth 1: attach to an open conditionless event.
		if current == null:
			current = _make_event(trigger_id)
			events.append(current)
		_consume_action_line(current, line.substr(1), 0, pending_raw, reverse_entries)
		index += 1
	_flush_raw(current, pending_raw)
	for event: Variant in events:
		if (event as EventRow).actions.is_empty() and (event as EventRow).conditions.is_empty():
			return []
	return events

static func _make_event(trigger_id: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	return event

## Splits a joined condition expression on " and " and reverse-matches every term
## (supporting `not (...)` negation). All terms must match or the lift fails.
static func _parse_conditions(expression: String, event: EventRow, reverse_entries: Array) -> bool:
	for term: String in expression.split(" and "):
		var negated: bool = false
		var candidate: String = term
		if candidate.begins_with("not (") and candidate.ends_with(")"):
			negated = true
			candidate = candidate.substr(5, candidate.length() - 6)
		var matched: Dictionary = _match_entry(candidate, reverse_entries, "condition")
		if matched.is_empty():
			return false
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = str(matched.get("provider", ""))
		condition.ace_id = str(matched.get("ace_id", ""))
		condition.params = matched.get("params", {})
		condition.negated = negated
		event.conditions.append(condition)
	return true

## Action line → ACEAction when a template matches; otherwise queued as raw GDScript so the
## event still lifts (in-flow blocks re-emit verbatim at the body indent).
static func _consume_action_line(event: EventRow, line: String, _depth: int, pending_raw: PackedStringArray, reverse_entries: Array) -> void:
	var matched: Dictionary = _match_entry(line, reverse_entries, "action")
	if matched.is_empty():
		pending_raw.append(line)
		return
	_flush_raw(event, pending_raw)
	var action: ACEAction = ACEAction.new()
	action.provider_id = str(matched.get("provider", ""))
	action.ace_id = str(matched.get("ace_id", ""))
	action.params = matched.get("params", {})
	event.actions.append(action)

static func _flush_raw(event: EventRow, pending_raw: PackedStringArray) -> void:
	if pending_raw.is_empty() or event == null:
		return
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(pending_raw)
	event.actions.append(block)
	pending_raw.clear()

## Reverse index over builtin descriptors: template → anchored regex with named captures.
static func _build_reverse_entries() -> Array:
	var entries: Array = []
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		var template: String = descriptor.codegen_template.strip_edges()
		if template.is_empty() or template.contains("{,"):
			continue  # optional-segment templates are not reversible (v1)
		var kind: String = ""
		match descriptor.ace_type:
			ACEDescriptor.ACEType.CONDITION:
				kind = "condition"
			ACEDescriptor.ACEType.ACTION:
				kind = "action"
			_:
				continue
		var regex: RegEx = _template_to_regex(template)
		if regex == null:
			continue
		entries.append({"provider": descriptor.provider_id, "ace_id": descriptor.ace_id, "kind": kind, "regex": regex})
	return entries

static func _match_entry(line: String, reverse_entries: Array, kind: String) -> Dictionary:
	for entry: Variant in reverse_entries:
		if str((entry as Dictionary).get("kind", "")) != kind:
			continue
		var regex: RegEx = (entry as Dictionary).get("regex")
		var regex_match: RegExMatch = regex.search(line)
		if regex_match == null:
			continue
		var params: Dictionary = {}
		for group_name: String in regex.get_names():
			params[group_name] = regex_match.get_string(group_name)
		return {"provider": (entry as Dictionary).get("provider"), "ace_id": (entry as Dictionary).get("ace_id"), "params": params}
	return {}

## "{amount}" placeholders become lazy named captures; everything else matches literally.
static func _template_to_regex(template: String) -> RegEx:
	var pattern: String = "^"
	var cursor: int = 0
	while cursor < template.length():
		var open: int = template.find("{", cursor)
		if open == -1:
			pattern += _escape_regex(template.substr(cursor))
			break
		var close: int = template.find("}", open)
		if close == -1:
			pattern += _escape_regex(template.substr(cursor))
			break
		pattern += _escape_regex(template.substr(cursor, open - cursor))
		pattern += "(?<%s>.+?)" % template.substr(open + 1, close - open - 1)
		cursor = close + 1
	pattern += "$"
	var regex: RegEx = RegEx.new()
	return regex if regex.compile(pattern) == OK else null

static func _escape_regex(text: String) -> String:
	var escaped: String = ""
	for character in text:
		escaped += ("\\" + character) if character in "\\^$.|?*+()[]{}" else character
	return escaped
