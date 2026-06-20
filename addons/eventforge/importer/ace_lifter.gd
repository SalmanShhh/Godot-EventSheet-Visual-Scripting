# EventForge — ACE-level import lifting (reverse template matching)
#
# Turns generated GDScript back into real sheet events when a file is opened as a
# GDScript-backed sheet: lifecycle trigger functions (_ready/_process/_physics_process)
# lift into EventRows — `if <condition templates>:` blocks become conditioned events,
# adjacent `elif`/`else:` chains become else_mode siblings, NESTED if/elif/else become
# sub-events (recursively), and action-template lines become ACEActions; statements
# that match no template become in-flow GDScript blocks, so the event still lifts.
# Reverse templates come from the builtin descriptor registry (`{param}` placeholders
# become named captures; params round-trip as strings because codegen substitutes with
# plain str()).
#
# THE CONTRACT (lossless rule): lifting is all-or-nothing per file and verified by
# recompiling the whole sheet — if the output is not byte-identical to the source, the
# lift is reverted and every function stays a verbatim block row. Only the trailing run of
# trigger functions is considered (EventForge's own layout); files with other layouts
# simply keep their blocks.
@tool
extends RefCounted
class_name EventSheetACELifter

## Lifecycle handlers reversible from the header alone (signal handlers reverse via the
## `_ready` connection map — see _parse_connections/_lift_function).
const LIFECYCLE_TRIGGERS: Dictionary = {
	"func _ready() -> void:": "OnReady",
	"func _process(delta: float) -> void:": "OnProcess",
	"func _physics_process(delta: float) -> void:": "OnPhysicsProcess",
	"func _input(event: InputEvent) -> void:": "OnInput",
	"func _unhandled_input(event: InputEvent) -> void:": "OnUnhandledInput",
	"func _run() -> void:": "OnEditorRun"
}

## Attempts the lift on an imported external sheet. Mutates sheet.events only when the
## byte-identical round-trip verifies; otherwise leaves the sheet untouched.
## Two-pass: the full lift (events + sheet functions + trailing comments) is tried first;
## if its byte-verify fails (e.g. annotations we can't regenerate), the event-only lift is
## retried so files keep at least the coverage older versions had.
static func attempt_lift(sheet: EventSheetResource, source: String, lift_functions: bool = true) -> bool:
	if sheet == null:
		return false
	# The trailing run: function blocks, their @ace annotation blocks, blank separators,
	# and a final top-level comment block — EventForge's emission layout in row form.
	var first_run_index: int = sheet.events.size()
	for index in range(sheet.events.size() - 1, -1, -1):
		var row: Variant = sheet.events[index]
		if row is RawCodeRow and _run_row_kind((row as RawCodeRow).code, lift_functions) != "other":
			first_run_index = index
			continue
		break
	# When the first run function directly follows the prelude, its annotation block is
	# glued to that preceding "other" row — split it off (stripped at mutation time).
	var boundary_annotations_text: String = ""
	var pending_annotations: Dictionary = {}
	if lift_functions and first_run_index > 0 and sheet.events[first_run_index - 1] is RawCodeRow:
		var boundary_lines: PackedStringArray = (sheet.events[first_run_index - 1] as RawCodeRow).code.split("\n")
		var annotation_start: int = boundary_lines.size()
		while annotation_start > 0 and boundary_lines[annotation_start - 1].begins_with("## "):
			annotation_start -= 1
		if annotation_start < boundary_lines.size():
			var annotation_lines: PackedStringArray = boundary_lines.slice(annotation_start)
			boundary_annotations_text = "\n" + "\n".join(annotation_lines)
			pending_annotations = _parse_annotations("\n".join(annotation_lines))
	# `_ready`'s leading connect lines reveal which functions are signal handlers
	# (and for which signal/source node). Emission regenerates the connects.
	var connections: Dictionary = {}
	for index in range(first_run_index, sheet.events.size()):
		var ready_row: RawCodeRow = sheet.events[index] as RawCodeRow
		if ready_row != null and ready_row.code.begins_with("func _ready() -> void:"):
			connections = _parse_connections(ready_row.code.split("\n"))
	# Lift every run row (all-or-nothing). Annotation blocks attach to the NEXT function.
	var lifted_events: Array = []
	var lifted_functions: Array = []
	var lifted_comments: Array = []
	var saw_function: bool = false
	for index in range(first_run_index, sheet.events.size()):
		var row: RawCodeRow = sheet.events[index] as RawCodeRow
		match _run_row_kind(row.code, lift_functions):
			"blank":
				continue  # separator; emission re-adds it
			"annotations":
				pending_annotations = _parse_annotations(row.code)
				if pending_annotations.is_empty():
					return _retry_or_fail(sheet, source, lift_functions)
			"comments":
				# Trailing top-level comments (deferred emission): one CommentRow per
				# blank-separated chunk.
				for chunk: String in row.code.strip_edges().split("\n\n"):
					var comment: CommentRow = CommentRow.new()
					comment.text = chunk.trim_prefix("# ").replace("\n# ", "\n")
					lifted_comments.append(comment)
			"func":
				saw_function = true
				var header: String = row.code.split("\n")[0]
				if LIFECYCLE_TRIGGERS.has(header) or _is_connected_handler(header, connections):
					if not pending_annotations.is_empty():
						return _retry_or_fail(sheet, source, lift_functions)
					# Lenient ifs: unmatched control flow becomes in-flow GDScript inside
					# the event instead of failing the file (byte-verify still gates).
					var lift: Dictionary = _lift_function(row.code.split("\n"), connections, true)
					if not bool(lift.get("ok", false)):
						return _retry_or_fail(sheet, source, lift_functions)
					lifted_events.append_array(lift.get("events", []))
				else:
					if not lift_functions:
						return false
					var function_lift: Dictionary = _lift_sheet_function(row.code.split("\n"), pending_annotations)
					pending_annotations = {}
					if not bool(function_lift.get("ok", false)):
						return _retry_or_fail(sheet, source, lift_functions)
					lifted_functions.append(function_lift.get("function"))
			_:
				return _retry_or_fail(sheet, source, lift_functions)
	if not saw_function or (lifted_events.is_empty() and lifted_functions.is_empty()):
		return false

	var backup: Array[Resource] = sheet.events.duplicate()
	var functions_backup: Array[Resource] = sheet.functions.duplicate()
	sheet.events.resize(first_run_index)
	# Emission inserts one blank line before each section; the import attached that blank
	# (and possibly the first function's annotation block) to the preceding row, so drop
	# them to avoid doubling. The backup array is SHALLOW — the boundary row's original
	# code must be restored explicitly on revert.
	var boundary: RawCodeRow = null
	var boundary_code: String = ""
	if not sheet.events.is_empty() and sheet.events[sheet.events.size() - 1] is RawCodeRow:
		boundary = sheet.events[sheet.events.size() - 1] as RawCodeRow
		boundary_code = boundary.code
		if not boundary_annotations_text.is_empty() and boundary.code.ends_with(boundary_annotations_text):
			boundary.code = boundary.code.substr(0, boundary.code.length() - boundary_annotations_text.length())
		if boundary.code.ends_with("\n"):
			boundary.code = boundary.code.substr(0, boundary.code.length() - 1)
		elif boundary.code.strip_edges().is_empty():
			sheet.events.remove_at(sheet.events.size() - 1)
	for event: Variant in lifted_events:
		sheet.events.append(event)
	for comment: Variant in lifted_comments:
		sheet.events.append(comment)
	for function: Variant in lifted_functions:
		sheet.functions.append(function)

	# Verify: the lifted sheet must reproduce the source byte-for-byte.
	var saved_path: String = sheet.external_source_path
	sheet.external_source_path = "user://eventforge_lift_verify.gd"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_lift_verify.gd").get("output", ""))
	sheet.external_source_path = saved_path
	if output == source:
		return true
	sheet.events = backup
	sheet.functions = functions_backup
	if boundary != null:
		boundary.code = boundary_code
	return _retry_or_fail(sheet, source, lift_functions)

## The two-pass fallback: a failed full lift retries event-only before giving up, so the
## function/comment upgrades can never regress what already lifted before them.
static func _retry_or_fail(sheet: EventSheetResource, source: String, lift_functions: bool) -> bool:
	if lift_functions:
		return attempt_lift(sheet, source, false)
	return false

## Classifies a trailing-run row: "func", "annotations" (## @ace block), "blank",
## "comments" (top-level # lines), or "other" (breaks the run).
static func _run_row_kind(code: String, lift_functions: bool) -> String:
	if code.begins_with("func "):
		return "func"
	if code.strip_edges().is_empty():
		return "blank"
	var saw_annotation: bool = false
	var saw_comment: bool = false
	for line: String in code.split("\n"):
		if line.strip_edges().is_empty():
			continue
		if line.begins_with("## "):
			saw_annotation = true
		elif line.begins_with("# "):
			saw_comment = true
		else:
			return "other"
	if saw_annotation and not saw_comment and lift_functions:
		return "annotations"
	if saw_comment and not saw_annotation and lift_functions:
		return "comments"
	return "other"

## True when the header is a signal handler present in the `_ready` connection map.
static func _is_connected_handler(header: String, connections: Dictionary) -> bool:
	var header_regex: RegEx = RegEx.new()
	header_regex.compile("^func ([A-Za-z_][A-Za-z0-9_]*)")
	var header_match: RegExMatch = header_regex.search(header)
	return header_match != null and connections.has(header_match.get_string(1))

## Reverse of _emit_expose_annotations: parses a `## @ace_*` block into EventFunction
## exposure fields. {} = unrecognized shape (lift falls back).
static func _parse_annotations(code: String) -> Dictionary:
	var fields: Dictionary = {"expose": false, "name": "", "category": "", "description": ""}
	var recognized: bool = false
	for line: String in code.split("\n"):
		var text: String = line.strip_edges()
		if text.is_empty():
			continue
		if text == "## @ace_hidden":
			recognized = true
		elif text == "## @ace_action":
			fields["expose"] = true
			recognized = true
		elif text.begins_with("## @ace_name(\"") and text.ends_with("\")"):
			fields["name"] = text.substr(14, text.length() - 16)
		elif text.begins_with("## @ace_category(\"") and text.ends_with("\")"):
			fields["category"] = text.substr(18, text.length() - 20)
		elif text.begins_with("## @ace_description(\"") and text.ends_with("\")"):
			fields["description"] = text.substr(21, text.length() - 23)
		elif text.begins_with("## @ace_codegen_template("):
			pass  # regenerated from the function shape; byte-verify confirms it matches
		elif text.begins_with("## @ace_icon("):
			pass  # regenerated from the sheet's custom_class_icon; byte-verify confirms
		else:
			return {}
	return fields if recognized else {}

## A non-trigger function → EventFunction (sheet function), body parsed with the same
## grammar as event bodies (events without triggers). {} fields come from the preceding
## annotation block (every generated sheet function has one: @ace_action… or @ace_hidden).
static func _lift_sheet_function(function_lines: PackedStringArray, annotations: Dictionary) -> Dictionary:
	if annotations.is_empty():
		return {"ok": false}  # generated sheet functions always carry an annotation block
	var header_regex: RegEx = RegEx.new()
	header_regex.compile("^func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\) -> ([A-Za-z_][A-Za-z0-9_]*):$")
	var header_match: RegExMatch = header_regex.search(function_lines[0])
	if header_match == null:
		return {"ok": false}
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = header_match.get_string(1)
	var return_name: String = header_match.get_string(3) if header_match.get_group_count() >= 3 else "void"
	var return_types: Dictionary = {"void": TYPE_NIL, "bool": TYPE_BOOL, "int": TYPE_INT, "float": TYPE_FLOAT, "String": TYPE_STRING, "Vector2": TYPE_VECTOR2, "Vector3": TYPE_VECTOR3, "Color": TYPE_COLOR, "Array": TYPE_ARRAY, "Dictionary": TYPE_DICTIONARY, "Variant": TYPE_MAX}
	if not return_types.has(return_name):
		return {"ok": false}
	event_function.return_type = return_types[return_name]
	for argument: String in header_match.get_string(2).split(", ", false):
		var param: ACEParam = ACEParam.new()
		var colon: int = argument.find(": ")
		if colon >= 0:
			param.id = argument.substr(0, colon)
			param.type_name = argument.substr(colon + 2)
		else:
			param.id = argument
		event_function.params.append(param)
	event_function.expose_as_ace = bool(annotations.get("expose", false))
	event_function.ace_display_name = str(annotations.get("name", ""))
	event_function.ace_category = str(annotations.get("category", ""))
	event_function.description = str(annotations.get("description", ""))
	var body: Dictionary = _lift_function(PackedStringArray(["func _ready() -> void:"]) + function_lines.slice(1), {}, true)
	if not bool(body.get("ok", false)):
		return {"ok": false}
	# Function-body events carry no trigger (the function header is the entry point).
	for event: Variant in body.get("events", []):
		(event as EventRow).trigger_provider_id = ""
		(event as EventRow).trigger_id = ""
		event_function.events.append(event)
	return {"ok": true, "function": event_function}

## Core signal names ↔ trigger ids, mirroring TriggerResolver's signal-backed table.
const CORE_SIGNAL_TRIGGERS: Dictionary = {
	"body_entered": "OnBodyEntered",
	"area_entered": "OnAreaEntered",
	"body_exited": "OnBodyExited",
	"area_exited": "OnAreaExited",
	"timeout": "OnTimeout",
	"animation_finished": "OnAnimationFinished"
}

## Parses `_ready`'s leading connect lines into {handler_name: {signal, source}}.
## Shapes (exactly what _emit_grouped_trigger_functions emits):
##   	body_entered.connect(_on_body_entered)
##   	get_node("Platform").landed.connect(_on_platform_landed)
static func _parse_connections(ready_lines: PackedStringArray) -> Dictionary:
	var connections: Dictionary = {}
	var regex: RegEx = RegEx.new()
	if regex.compile("^\t(?:get_node\\(\"([^\"]+)\"\\)\\.)?([A-Za-z_][A-Za-z0-9_]*)\\.connect\\(([A-Za-z_][A-Za-z0-9_]*)\\)$") != OK:
		return connections
	for index in range(1, ready_lines.size()):
		var regex_match: RegExMatch = regex.search(ready_lines[index])
		if regex_match == null:
			break  # connects are emitted first; the rest is OnReady body
		connections[regex_match.get_string(3)] = {
			"signal": regex_match.get_string(2),
			"source": regex_match.get_string(1)
		}
	return connections

## One trigger function → {ok: bool, events: Array}. Recognizes lifecycle headers and —
## via the `_ready` connection map — signal handlers, which lift to signal-trigger events
## (Core signals reverse to their trigger ids; others become "signal:<name>" triggers with
## the handler's argument signature baked as trigger_args and the connect's source node as
## trigger_source_path). `_ready`'s connect lines are skipped: emission regenerates them.
static func _lift_function(function_lines: PackedStringArray, connections: Dictionary = {}, lenient_ifs: bool = false) -> Dictionary:
	if function_lines.is_empty():
		return {"ok": false}
	var trigger_id: String = ""
	var trigger_provider: String = "Core"
	var trigger_args: String = ""
	var trigger_source: String = ""
	var index: int = 1
	if LIFECYCLE_TRIGGERS.has(function_lines[0]):
		trigger_id = str(LIFECYCLE_TRIGGERS[function_lines[0]])
		if function_lines[0].begins_with("func _ready()"):
			# Skip the regenerated connect lines; what remains is the OnReady body.
			while index < function_lines.size() and _is_connect_line(function_lines[index]):
				index += 1
			if index >= function_lines.size():
				return {"ok": true, "events": []}  # connects-only _ready
	else:
		var header_regex: RegEx = RegEx.new()
		header_regex.compile("^func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\) -> void:$")
		var header_match: RegExMatch = header_regex.search(function_lines[0])
		if header_match == null or not connections.has(header_match.get_string(1)):
			return {"ok": false}
		var connection: Dictionary = connections[header_match.get_string(1)]
		var signal_name: String = str(connection.get("signal", ""))
		trigger_source = str(connection.get("source", ""))
		if CORE_SIGNAL_TRIGGERS.has(signal_name):
			trigger_id = str(CORE_SIGNAL_TRIGGERS[signal_name])
		else:
			trigger_id = "signal:%s" % signal_name
			trigger_provider = ""
			trigger_args = header_match.get_string(2)
	var reverse_entries: Array = _build_reverse_entries()
	var parsed: Dictionary = _parse_body(function_lines, index, 1, trigger_id, trigger_provider, trigger_args, trigger_source, reverse_entries, lenient_ifs)
	if not bool(parsed.get("ok", false)) or int(parsed.get("next", 0)) < function_lines.size():
		return {"ok": false}  # dedented/blank content inside a function — not our shape
	var events: Array = parsed.get("rows", [])
	for event: Variant in events:
		if _is_plain_collector(event as EventRow) and (event as EventRow).actions.is_empty():
			return {"ok": false}
	return {"ok": true, "events": events}

## Recursive body grammar (the reverse of _emit_event_body): at each depth,
## `if <conds>:` opens a conditioned row, an adjacent `elif <conds>:`/`else:` chains
## onto it via else_mode (ELSE + conditions == ELIF — the emitter's rule), and the
## block's own body parses one level deeper — statements become the row's actions,
## nested blocks its sub_events. Anything unrepresentable (unmatched conditions,
## statements interleaved AFTER a nested block, arbitrary control flow) falls back to
## the lenient path: the raw line + its deeper lines stay in-flow GDScript with their
## relative indentation, exactly as before this grammar existed. The byte-identical
## recompile in attempt_lift gates every shape this parser produces.
## Returns {ok, rows: Array[EventRow], next: int}; a "plain collector" row (no
## conditions, no else_mode) holds the statements between blocks.
static func _parse_body(lines: PackedStringArray, start: int, depth: int, trigger_id: String, trigger_provider: String, trigger_args: String, trigger_source: String, reverse_entries: Array, lenient_ifs: bool) -> Dictionary:
	var indent: String = "\t".repeat(depth)
	var rows: Array = []
	var current: EventRow = null
	var pending_raw: PackedStringArray = PackedStringArray()
	var chain_open: bool = false
	var index: int = start
	while index < lines.size():
		var line: String = lines[index]
		if line.strip_edges().is_empty():
			return {"ok": false}  # blank inside a generated body never happens; bail to blocks
		if not line.begins_with(indent):
			break  # dedent: this body is done; the caller resumes here
		var rest: String = line.substr(depth)
		var at_this_depth: bool = not rest.begins_with("\t")
		var is_if: bool = at_this_depth and rest.begins_with("if ") and rest.ends_with(":")
		var is_elif: bool = at_this_depth and chain_open and rest.begins_with("elif ") and rest.ends_with(":")
		var is_else: bool = at_this_depth and chain_open and rest == "else:"
		if is_if or is_elif or is_else:
			var expression: String = ""
			if is_if:
				expression = rest.substr(3, rest.length() - 4)
			elif is_elif:
				expression = rest.substr(5, rest.length() - 6)
			var block_event: EventRow = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			if not is_if:
				block_event.else_mode = EventRow.ElseMode.ELSE
			var representable: bool = expression.is_empty() or _parse_conditions(expression, block_event, reverse_entries)
			var inner: Dictionary = {}
			if representable:
				inner = _parse_body(lines, index + 1, depth + 1, "", "", "", "", reverse_entries, lenient_ifs)
				representable = bool(inner.get("ok", false)) and _adopt_block_body(block_event, inner.get("rows", []))
			if not representable:
				if not lenient_ifs:
					return {"ok": false}
				# Raw fallback: the header line joins the open collector; its deeper
				# lines arrive through the statement branch below, tabs preserved.
				if current == null:
					current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
					rows.append(current)
				pending_raw.append(rest)
				index += 1
				chain_open = false
				continue
			_flush_raw(current, pending_raw)
			current = null
			rows.append(block_event)
			index = int(inner.get("next"))
			chain_open = true
			continue
		# Statement at this depth (or deeper, inside an unlifted block): collect with
		# relative indentation intact.
		if current == null:
			current = _make_event(trigger_id, trigger_provider, trigger_args, trigger_source)
			rows.append(current)
		_consume_action_line(current, rest, 0, pending_raw, reverse_entries)
		index += 1
		chain_open = false
	_flush_raw(current, pending_raw)
	return {"ok": true, "rows": rows, "next": index}

## Folds a parsed block body into its event: a leading plain collector's statements
## become the event's actions, every conditioned/chained row becomes a sub-event.
## False when the shape can't survive emission (actions emit BEFORE sub-events, so
## statements after a nested block have no faithful home).
static func _adopt_block_body(block_event: EventRow, inner_rows: Array) -> bool:
	var cursor: int = 0
	if cursor < inner_rows.size() and _is_plain_collector(inner_rows[cursor] as EventRow):
		for action: Variant in (inner_rows[cursor] as EventRow).actions:
			block_event.actions.append(action)
		cursor += 1
	while cursor < inner_rows.size():
		var child: EventRow = inner_rows[cursor] as EventRow
		if _is_plain_collector(child):
			return false
		block_event.sub_events.append(child)
		cursor += 1
	return true

static func _is_plain_collector(event: EventRow) -> bool:
	return event != null and event.conditions.is_empty() and event.else_mode == EventRow.ElseMode.NONE

## True for a `_ready` body line that is a regenerated signal connection.
static func _is_connect_line(line: String) -> bool:
	return line.begins_with("\t") and line.ends_with(")") and line.contains(".connect(")

static func _make_event(trigger_id: String, trigger_provider: String = "Core", trigger_args: String = "", trigger_source: String = "") -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = trigger_provider
	event.trigger_id = trigger_id
	event.trigger_args = trigger_args
	event.trigger_source_path = trigger_source
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
	# Import triage: these lines matched no ACE template, so they stayed verbatim. Record why
	# (non-emitted — never affects the byte-exact round-trip) so the editor can show an
	# actionable "stayed as code" hint instead of an opaque block. See RawCodeRow.lift_note.
	block.lift_note = "no matching ACE template"
	event.actions.append(block)
	pending_raw.clear()

## Reverse index over builtin descriptors: template → anchored regex with named captures.
static func _build_reverse_entries() -> Array:
	var entries: Array = []
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		var template: String = descriptor.codegen_template.strip_edges()
		if template.is_empty() or template.contains("{,"):
			continue  # optional-segment templates are not reversible (v1)
		if descriptor.category == "Helpers":
			# Helper ACEs are FORWARD-authoring conveniences whose templates are deliberately
			# generic ({code}, {target}.{method}({args}), {target}.{property} = {value}). They
			# match almost anything, so reverse-lifting through them would shadow specific ACEs
			# and swallow lines that should stay verbatim blocks — keep them out of the index.
			continue
		if template in ["break", "continue", "pass"]:
			# Bare loop-control keywords also appear in generated pick-loop bodies, so
			# reverse-lifting them would mis-claim the compiler's own break/continue lines.
			continue
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
