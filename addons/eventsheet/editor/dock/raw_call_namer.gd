# EventSheet - Sheet ▸ Name Raw Calls: give every raw one-call code row its real verb name.
#
# A sheet accumulates escape-hatch rows: a call typed into a GDScript block, or a line the
# lifter could not attribute because the class was not scanned yet. Each of those is a plain
# call - `item.set_collapsed(true)` - and the vocabulary that NAMES it usually already
# exists (an engine class through ClassDB reflection, one of the project's own classes, a
# pack's published verbs). This sweep binds those rows to that vocabulary, so they read as
# real actions with editable parameter fields instead of grey code.
#
# THREE LAWS, and the feature is nothing without them.
#
# 1. THE ROW MUST KEEP COMPILING IDENTICALLY. Every conversion is byte-gated one row at a
#    time: the replacement action is emitted through the very call the compiler uses, and it
#    is kept only when that emission equals the raw line CHARACTER FOR CHARACTER. Anything
#    else - a different argument order, a template that adds a space, a target that does not
#    round-trip - is dropped and the row is left exactly as it was.
# 2. AMBIGUITY IS SKIPPED. Zero matches or two matches both mean the tool does not actually
#    know which verb this is, and a confidently WRONG name is worse than no name at all: the
#    row would still compile, so no gate could ever catch the lie. Exactly one candidate, or
#    the row stays raw.
# 3. IT IS A USER ACT. This never fires on load, on save, or on import. A lift is a pure
#    function of the file's bytes; attribution depends on mutable editor state (the class
#    scan, reflection caches, which packs are installed), so making it automatic would mean
#    the same file opened differently on two machines - and the byte-drift audit could not
#    see the difference, because renamed attribution re-emits the same bytes. The user runs
#    the command, gets a count of what changed, and owns one undo step for the whole sweep.
@tool
class_name EventSheetRawCallNamer
extends RefCounted

## `var name: Type` written by hand inside a code row - the local's declared type is what
## tells us which class a later `name.method()` call is talking to.
const TYPED_VAR_PATTERN: String = "^var\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*:\\s*([A-Z][A-Za-z0-9_]*)"

static var _typed_var_re: RegEx = null

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## Sheet ▸ Name Raw Calls…: sweeps the open sheet, converts what it can, reports the rest.
## Returns the same counters sweep_sheet() does, so a caller can assert on them.
func run() -> Dictionary:
	if _dock == null or _dock._current_sheet == null:
		return {"named": 0, "skipped": 0, "total": 0}
	# The undo funnel REPLACES the sheet's resources with snapshot duplicates when it
	# commits, so every mutation has to happen inside this closure and no row reference may
	# outlive it. The counters ride out in a dictionary the closure writes into.
	var counters: Dictionary = {"named": 0, "skipped": 0, "total": 0}
	var vocabulary: Array = []
	if _dock._ace_registry != null:
		vocabulary = _dock._ace_registry.get_all_definitions()
	_dock._perform_undoable_sheet_edit("Name Raw Calls", func() -> bool:
		var result: Dictionary = sweep_sheet(_dock._current_sheet, vocabulary)
		counters["named"] = int(result.get("named", 0))
		counters["skipped"] = int(result.get("skipped", 0))
		counters["total"] = int(result.get("total", 0))
		return int(counters["named"]) > 0
	)
	var named: int = int(counters["named"])
	var total: int = int(counters["total"])
	var skipped: int = int(counters["skipped"])
	if total == 0:
		_dock._set_status("Nothing to name - this sheet has no raw single-call code rows.")
	elif named == 0:
		_dock._set_status("Named 0 of %d raw calls (%d had no single match)." % [total, skipped])
	else:
		# _mark_dirty writes the status itself (with the unsaved-changes marker), so the
		# report goes through it rather than being printed twice.
		_dock._mark_dirty("Named %d of %d raw calls (%d had no single match)." % [named, total, skipped])
	return counters


## The whole sweep, minus the undo wrapper and the status line: mutates `sheet` in place and
## returns {"named": int, "skipped": int, "total": int}, where `total` counts the raw rows
## that parsed as a single call (so named + skipped == total). Dock-free on purpose - this is
## the part worth testing, and it needs no editor to run.
##
## `extra_definitions` is additional vocabulary to search BEFORE reflection: the dock passes
## the ACE registry, so a pack's own published verb (with the author's name for it) wins over
## the reflected twin of the same method.
static func sweep_sheet(sheet: EventSheetResource, extra_definitions: Array = []) -> Dictionary:
	var counters: Dictionary = {"named": 0, "skipped": 0, "total": 0}
	if sheet == null:
		return counters
	var types: Dictionary = _collect_types(sheet)
	_sweep_rows(sheet.events, types, extra_definitions, counters)
	for function_row: Variant in sheet.functions:
		if not (function_row is EventFunction):
			continue
		var function: EventFunction = function_row as EventFunction
		# A helper's body mostly acts on its own ARGUMENTS, so its typed parameters are the
		# type map that matters in here - and they shadow anything of the same name outside.
		var scoped: Dictionary = types.duplicate()
		for param: Variant in function.params:
			if not (param is ACEParam):
				continue
			var param_type: String = str((param as ACEParam).type_name).strip_edges()
			var param_id: String = str((param as ACEParam).id).strip_edges()
			if param_id.is_empty() or param_type.is_empty() or param_type[0] != param_type[0].to_upper():
				continue
			scoped[param_id] = param_type
		_sweep_rows(function.events, scoped, extra_definitions, counters)
	return counters


## Walks one row array (events, sub-events, group children) converting what it can.
static func _sweep_rows(rows: Array, types: Dictionary, extra_definitions: Array, counters: Dictionary) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			_sweep_rows((row as EventGroup).events, types, extra_definitions, counters)
			continue
		if not (row is EventRow):
			continue
		var event: EventRow = row as EventRow
		for index: int in range(event.actions.size()):
			if not (event.actions[index] is RawCodeRow):
				continue
			var raw: RawCodeRow = event.actions[index] as RawCodeRow
			var replacement: Variant = _named_action_for(raw, types, extra_definitions, counters)
			if replacement is ACEAction:
				event.actions[index] = replacement as ACEAction
		_sweep_rows(event.sub_events, types, extra_definitions, counters)


## The ACEAction one raw row should become, or null when it must stay raw. Counts itself into
## `counters`: any row that parses as a single call is a candidate (total), and it is either
## named or skipped - so the report never claims a row it did not look at.
static func _named_action_for(raw: RawCodeRow, types: Dictionary, extra_definitions: Array, counters: Dictionary) -> Variant:
	if raw == null or not raw.enabled or raw.code.contains("\n"):
		return null
	var call_parts: Dictionary = _parse_call(raw.code.strip_edges())
	if call_parts.is_empty():
		return null
	counters["total"] = int(counters["total"]) + 1
	counters["skipped"] = int(counters["skipped"]) + 1
	# An indented line lives deeper than the action lane it sits in (inside an `if` the row
	# also carries, say). A converted action re-emits at the lane's own indent, which would
	# silently move the statement, so a deeper line is never a candidate for naming.
	if raw.code.begins_with("\t") or raw.code.begins_with(" "):
		return null
	var class_id: String = _class_for_target(str(call_parts.get("target", "")), types)
	if class_id.is_empty():
		return null
	var arguments: PackedStringArray = EventSheetVerbSuggestion.split_arguments(str(call_parts.get("args", "")))
	var definition: ACEDefinition = _single_candidate(class_id, str(call_parts.get("method", "")), arguments, extra_definitions)
	if definition == null:
		return null
	var action: ACEAction = _action_from_definition(definition, str(call_parts.get("target", "")), arguments)
	if action == null:
		return null
	# THE BYTE GATE. Same call the compiler makes for one action; anything but a character-
	# for-character reproduction of the line the user already has means we got it wrong.
	if ActionCodegen.generate_action(action, "", "") != raw.code:
		return null
	counters["skipped"] = int(counters["skipped"]) - 1
	counters["named"] = int(counters["named"]) + 1
	return action


## Builds the replacement action exactly the way applying a verb from the picker does: the
## codegen template is BAKED onto the row (rows carry their own template, so the sheet keeps
## compiling even if the vocabulary moves), and the arguments map positionally onto the
## verb's parameters. `{uid}` is baked here for the same reason the dock bakes it at apply
## time - the compiler never does, and an unbaked token would sail into the emitted code.
static func _action_from_definition(definition: ACEDefinition, target: String, arguments: PackedStringArray) -> ACEAction:
	var params: Dictionary = EventSheetVerbSuggestion.mapped_params(definition, arguments)
	if params.is_empty() and definition.parameters.size() > 0:
		return null
	var template: String = str(definition.metadata.get("codegen_template", ""))
	if template.strip_edges().is_empty():
		template = definition.instance_backed_template()
	if template.strip_edges().is_empty():
		return null
	# A retargetable template gets the call's own target expression; a verb that already owns
	# a "target" parameter (the argument mapping filled it) is left alone.
	if (template.contains("{target.}") or template.contains("{target}")) and not params.has("target"):
		params["target"] = target
	if template.contains("{uid}"):
		template = template.replace("{uid}", "raw_named_%d" % (Time.get_ticks_usec() & 0xFFFFFF))
	var action: ACEAction = ACEAction.new()
	action.provider_id = definition.provider_id
	action.ace_id = definition.id
	action.params = params
	action.codegen_template = template
	return action


## The one ACTION definition of `class_id` whose method and arity match, or null. The
## registry's own verbs are searched first, and reflection is consulted only when they have
## nothing to say, so an annotated pack verb is never tied with its reflected twin.
static func _single_candidate(class_id: String, method: String, arguments: PackedStringArray, extra_definitions: Array) -> ACEDefinition:
	if class_id.is_empty() or method.is_empty():
		return null
	var wanted_id: String = "method:%s" % method
	var found: ACEDefinition = _match_in(extra_definitions, class_id, wanted_id, arguments)
	if found == _AMBIGUOUS:
		return null
	if found != null:
		return found
	var reflected: ACEDefinition = _match_in(EventSheetClassDBSource.definitions_for_class(class_id), class_id, wanted_id, arguments)
	return null if reflected == _AMBIGUOUS else reflected


## Sentinel for "more than one candidate": distinct from null ("nothing here, look further"),
## because a tie in the registry must NOT fall through to reflection and get resolved there.
static var _AMBIGUOUS: ACEDefinition = ACEDefinition.new()


static func _match_in(definitions: Array, class_id: String, wanted_id: String, arguments: PackedStringArray) -> ACEDefinition:
	var found: ACEDefinition = null
	for candidate: Variant in definitions:
		if not (candidate is ACEDefinition):
			continue
		var definition: ACEDefinition = candidate as ACEDefinition
		if definition.ace_type != ACEDefinition.ACEType.ACTION:
			continue
		if str(definition.provider_id) != class_id or str(definition.id) != wanted_id:
			continue
		# Arity must agree exactly - a mismatch is a different overload or a changed
		# signature, and inventing or dropping an argument would corrupt the row.
		if definition.parameters.size() != arguments.size():
			continue
		if found != null:
			return _AMBIGUOUS
		found = definition
	return found


## The class a call's target names: a local whose declared type we know wins, then the plain
## `$Node` / `%Unique` / `ClassName` reading. "" when nothing can be said for certain.
static func _class_for_target(target: String, types: Dictionary) -> String:
	var text: String = target.strip_edges()
	if types.has(text):
		return str(types[text])
	return EventSheetVerbSuggestion.class_from_target(text)


## Every `name -> Class` this sheet declares, from all three places a typed local can come
## from: a hand-written `var x: Type` still sitting in a code row, a structured local variable
## row, and the typed-local action the picker produces.
static func _collect_types(sheet: EventSheetResource) -> Dictionary:
	var types: Dictionary = {}
	_collect_types_in_rows(sheet.events, types)
	for function_row: Variant in sheet.functions:
		if function_row is EventFunction:
			_collect_types_in_rows((function_row as EventFunction).events, types)
	return types


static func _collect_types_in_rows(rows: Array, types: Dictionary) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			_collect_types_in_code(str((row as RawCodeRow).code), types)
			continue
		if row is LocalVariable:
			_record_type(str((row as LocalVariable).name), str((row as LocalVariable).type_name), types)
			continue
		if row is EventGroup:
			for group_variable: Variant in (row as EventGroup).local_variables:
				if group_variable is LocalVariable:
					_record_type(str((group_variable as LocalVariable).name), str((group_variable as LocalVariable).type_name), types)
			_collect_types_in_rows((row as EventGroup).events, types)
			continue
		if not (row is EventRow):
			continue
		var event: EventRow = row as EventRow
		for local: LocalVariable in event.local_variables:
			if local != null:
				_record_type(str(local.name), str(local.type_name), types)
		for action: Variant in event.actions:
			if action is RawCodeRow:
				_collect_types_in_code(str((action as RawCodeRow).code), types)
			elif action is ACEAction and str((action as ACEAction).ace_id) == "SetLocalVarTyped":
				var params: Dictionary = (action as ACEAction).params
				_record_type(str(params.get("name", "")), str(params.get("var_type", "")), types)
		_collect_types_in_rows(event.sub_events, types)


static func _collect_types_in_code(code: String, types: Dictionary) -> void:
	if _typed_var_re == null:
		_typed_var_re = RegEx.new()
		_typed_var_re.compile(TYPED_VAR_PATTERN)
	for line: String in code.split("\n"):
		var found: RegExMatch = _typed_var_re.search(line.strip_edges())
		if found != null:
			_record_type(found.get_string(1), found.get_string(2), types)


## Records one declared type, keeping only class-shaped names (a capitalised identifier) -
## `float` or `Variant` says nothing about which vocabulary a call belongs to.
static func _record_type(variable_name: String, type_name: String, types: Dictionary) -> void:
	var name_text: String = variable_name.strip_edges()
	var type_text: String = type_name.strip_edges()
	if name_text.is_empty() or type_text.is_empty() or type_text == "Variant":
		return
	if not name_text.is_valid_identifier() or not type_text.is_valid_identifier():
		return
	if type_text[0] != type_text[0].to_upper():
		return
	types[name_text] = type_text


## Splits `TARGET.method(args)` into {target, method, args}, or {} when the line is anything
## else. Deliberately strict: the call must be the WHOLE line, its parentheses balanced with
## the closing one last, and the target a simple reference (no nested call, no space) - we
## will not guess through an expression.
##
## The row renderer is growing a similar view-side parser in parallel; unifying the two is
## follow-up work, kept out of this sweep so neither side has to wait on the other.
static func _parse_call(text: String) -> Dictionary:
	if text.is_empty() or not text.ends_with(")"):
		return {}
	var open: int = -1
	var depth: int = 0
	var quote: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote and (index == 0 or text[index - 1] != "\\"):
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
			continue
		if character == "(" or character == "[" or character == "{":
			if open < 0 and character == "(":
				open = index
			depth += 1
			continue
		if character == ")" or character == "]" or character == "}":
			depth -= 1
			# The call's own parenthesis must close on the LAST character; closing earlier
			# means the line continues past it (`a.b().c` or `a.b() + 1`), which is not one call.
			if depth == 0 and index != text.length() - 1:
				return {}
	if open <= 0 or depth != 0 or not quote.is_empty():
		return {}
	var head: String = text.substr(0, open)
	var dot: int = head.rfind(".")
	if dot <= 0:
		return {}
	var target: String = head.substr(0, dot)
	var method: String = head.substr(dot + 1)
	if target.is_empty() or target.contains(" ") or target.contains("(") or target.contains("\""):
		return {}
	if not method.is_valid_identifier():
		return {}
	return {
		"target": target,
		"method": method,
		"args": text.substr(open + 1, text.length() - open - 2),
	}
