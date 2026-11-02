# Godot EventSheets - the doors on a mistake check (the help strip's buttons and the Doctor's chips).
#
# Every door here is a step the reader could take by hand, taken for them and shown as one undo step
# through the dock's own funnel; none of them is a guess. A door whose cure is a decision opens the
# place the decision is made (Godot's own node or file picker, the row's parameters, the signal's row).
#
#   use the name       respells the one word the finding is about, in the row it was found in: a
#                      group, a control, a node path, a file path. Nothing else in the row moves.
#   point at the node  writes the row's "On node" with the scene's own node of the class it needs.
#   known at run time  remembers, in the PROJECT, that this node or group is made while the game runs.
#                      A project setting, never the sheet file, so a .gd sheet gains not one byte.
#   stop after rounds  gives a While that cannot end the guard: a counter local called rounds, one
#                      added to it each round, and the condition and-ed with rounds < 1000.
#   change the variable  adds the one row that ends a plain counting loop.
#   make it an If      the loop's condition becomes an If on the same event; its body runs once.
#   fit the values     gives an emit the values its signal declares, or a handler the ones it is sent.
#   add to the signal  widens the declaration to what the handler takes.
#   rename the local   follows every use inside the event; remove the local leaves them on what it hid.
#   add the control    puts the missing control into the Input Map (project.godot), unbound.
#
# The row is found again on the LIVE sheet when a door is pressed: a finding was read when the row was
# built, and the funnel replaces every resource with a snapshot copy when it commits.
@tool
class_name EventSheetMistakeFixes
extends RefCounted


## What the last door said, for a caller (the Doctor's chip) that reports it its own way.
static var receipt: String = ""


## The Doctor's chip pressed: the same door, found again on the OPEN sheet by its kind and subject
## (the report is about the file; the funnel edits the open sheet). A report about another file only
## says to open it, because a fix must never replace the reader's tab.
static func apply_from_report(dock: Control, fix_id: String, report: Dictionary) -> Dictionary:
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource if dock != null else null
	var path: String = str(report.get("path", ""))
	if sheet == null or (sheet.external_source_path != path and sheet.resource_path != path):
		return {"ok": false, "message": EventSheetL10n.translate("Open %s first: this door changes the open sheet.") % path.get_file()}
	for live: Dictionary in EventSheetMistakeFindings.findings(sheet, path):
		if str(live.get("kind", "")) != str(report.get("kind", "")) or str(live.get("subject", "")) != str(report.get("subject", "")):
			continue
		var door: Dictionary = live.duplicate()
		door["fix"] = fix_id
		receipt = ""
		var done: bool = apply(dock, door, "fix")
		return {"ok": done, "message": receipt}
	return {"ok": false, "message": EventSheetL10n.translate("That row no longer says it - nothing to change.")}


static func _say(dock: Control, text: String, is_error: bool) -> void:
	receipt = text
	dock.call("_set_status", text, is_error)


## Runs one door of one finding on the open sheet. `which` is "fix", "second_fix" or "third_fix".
## Returns true when the door did something (or told the reader what to do).
static func apply(dock: Control, finding: Dictionary, which: String) -> bool:
	var fix_id: String = str(finding.get(which, ""))
	if fix_id.is_empty() or dock == null:
		return false
	var live: Dictionary = _live_finding(dock, finding)
	if live.is_empty():
		_say(dock, EventSheetL10n.translate("That row no longer says it - nothing to change."), false)
		return true
	match fix_id:
		EventSheetMistakeFindings.FIX_ADD_ACTION:
			var added: Dictionary = EventSheetQuickFixes.apply("add_input_action", live, {"dock": dock})
			EventSheetInputMapFacts.clear_cache()
			_say(dock, str(added.get("message", "")), not bool(added.get("ok", false)))
			dock.call("_refresh_after_edit")
			return true
		EventSheetMistakeFindings.FIX_PICK_ACTION:
			return _pick_action(dock, live)
		EventSheetMistakeFindings.FIX_RUN_TIME:
			return _remember(dock, live)
		EventSheetMistakeFindings.FIX_USE_NAME:
			return _use_name(dock, live, str(live.get("to", "")))
		EventSheetMistakeFindings.FIX_POINT_AT_NODE:
			return _point_at_node(dock, live, str(live.get("to", "")))
		EventSheetMistakeFindings.FIX_STOP_AFTER:
			return _stop_after_rounds(dock, live)
		EventSheetMistakeFindings.FIX_PICK_NODE:
			return _pick_node(dock, live)
		EventSheetMistakeFindings.FIX_PICK_ROW:
			return _pick_row(dock, live)
		EventSheetMistakeFindings.FIX_PICK_FILE:
			return _pick_file(dock, live)
		EventSheetMistakeFindings.FIX_GROUP_ON_NODE:
			return _group_on_node(dock, live)
		EventSheetMistakeFindings.FIX_EMIT_VALUES:
			return _fit_emit(dock, live)
		EventSheetMistakeFindings.FIX_OPEN_SIGNAL:
			return _open_signal(dock, live)
		EventSheetMistakeFindings.FIX_HANDLER_VALUES:
			return _fit_handler(dock, live)
		EventSheetMistakeFindings.FIX_ADD_TO_SIGNAL:
			return _add_to_signal(dock, live)
		EventSheetMistakeFindings.FIX_CHANGE_VARIABLE:
			return _change_variable(dock, live)
		EventSheetMistakeFindings.FIX_MAKE_IF:
			return _make_if(dock, live)
		EventSheetMistakeFindings.FIX_RENAME_LOCAL:
			return _rename_local(dock, live)
		EventSheetMistakeFindings.FIX_REMOVE_LOCAL:
			return _remove_local(dock, live)
		EventSheetMistakeFindings.FIX_OPEN_VALUE:
			return _open_value(dock, live)
		EventSheetMistakeFindings.FIX_USE_VALUE:
			return _use_value(dock, live)
		EventSheetMistakeFindings.FIX_GO_TO_VARIABLE:
			return _go_to_variable(dock, live)
	return false


## The finding as it stands on the live sheet: the same kind about the same subject in the same place, and on
## the same event when the event can still be named. {} when the sheet no longer says it.
static func _live_finding(dock: Control, finding: Dictionary) -> Dictionary:
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	if sheet == null:
		return finding
	var old_event: EventRow = finding.get("event") as EventRow
	var same_kind: Dictionary = {}
	for live: Dictionary in EventSheetMistakeFindings.findings(sheet, sheet.external_source_path):
		if str(live.get("kind", "")) != str(finding.get("kind", "")) or str(live.get("subject", "")) != str(finding.get("subject", "")) \
				or str(live.get("lane", "")) != str(finding.get("lane", "")) or int(live.get("index", -1)) != int(finding.get("index", -1)):
			continue
		var live_event: EventRow = live.get("event") as EventRow
		if live_event == old_event or (live_event != null and old_event != null and not old_event.event_uid.is_empty() and live_event.event_uid == old_event.event_uid):
			return _with_door_ids(live, finding)
		if same_kind.is_empty():
			same_kind = live
	return _with_door_ids(same_kind, finding) if not same_kind.is_empty() else {}


## The live finding keeps the ids of the finding that was pressed: the Doctor's chip names its door by id.
static func _with_door_ids(live: Dictionary, finding: Dictionary) -> Dictionary:
	var merged: Dictionary = live.duplicate()
	for key: String in ["fix", "second_fix", "third_fix"]:
		if finding.has(key):
			merged[key] = finding[key]
	return merged


## The row a finding sits in, found on the live sheet: the entry of its lane at its slot.
static func _entry_of(finding: Dictionary) -> Resource:
	var event_row: EventRow = finding.get("event") as EventRow
	if event_row == null:
		return null
	var slot: int = int(finding.get("index", -1))
	match str(finding.get("lane", "")):
		"action":
			return event_row.actions[slot] if slot >= 0 and slot < event_row.actions.size() else null
		"condition":
			return event_row.conditions[slot] if slot >= 0 and slot < event_row.conditions.size() else null
		"trigger":
			return event_row.trigger
		"pick":
			return event_row.pick_filters[slot] if slot >= 0 and slot < event_row.pick_filters.size() else null
	return null


## The one word of a line changed: a node reference at its boundary, or a quoted name in any quote.
static func respell(text: String, subject: String, replacement: String) -> String:
	if subject.is_empty() or replacement.is_empty() or subject == replacement:
		return text
	if subject.begins_with("$") or subject.begins_with("%"):
		var result: String = ""
		var cursor: int = 0
		var at: int = text.find(subject)
		while at >= 0:
			var after: int = at + subject.length()
			var boundary: bool = after >= text.length() or not (text[after].is_valid_identifier() or text[after] == "_" or text[after].is_valid_int() or text[after] == "/")
			result += text.substr(cursor, at - cursor) + (replacement if boundary else subject)
			cursor = after
			at = text.find(subject, after)
		return result + text.substr(cursor)
	var changed: String = text
	for quote: String in ["\"", "'"]:
		changed = changed.replace(quote + subject + quote, quote + replacement + quote)
	return changed


## The word a row holds for this finding: a declaring row's subject is its own name, the word is the path.
static func _word_of(finding: Dictionary) -> String:
	return str(finding.get("path", finding.get("subject", "")))


static func _use_name(dock: Control, finding: Dictionary, replacement: String) -> bool:
	var subject: String = _word_of(finding)
	if replacement.is_empty():
		return false
	var event_row: EventRow = finding.get("event") as EventRow
	var entry: Resource = _entry_of(finding)
	var lane: String = str(finding.get("lane", ""))
	var block: CustomBlockRow = finding.get("block") as CustomBlockRow
	var touched: Array[int] = [0]
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Use %s") % replacement, func() -> bool:
		if lane == "block" and block != null:
			if str(block.fields.get("path", "")) == subject:
				block.fields["path"] = replacement
				touched[0] += 1
		elif lane == "variable":
			var variable: LocalVariable = _variable_named(dock, str(finding.get("subject", "")))
			if variable != null:
				var written_default: String = respell(str(variable.default_value), subject, replacement)
				if written_default != str(variable.default_value):
					variable.default_value = written_default
					touched[0] += 1
		elif lane == "local" and event_row != null:
			for local: Variant in event_row.local_variables:
				if local is LocalVariable and respell(str((local as LocalVariable).default_value), subject, replacement) != str((local as LocalVariable).default_value):
					(local as LocalVariable).default_value = respell(str((local as LocalVariable).default_value), subject, replacement)
					touched[0] += 1
		else:
			# A control named by the trigger lives in the event's own table of trigger values.
			if lane == "trigger" and event_row != null:
				touched[0] += _respell_table(event_row.trigger_params, subject, replacement)
			touched[0] += _respell_entry(entry, subject, replacement)
		return touched[0] > 0))
	if done:
		_say(dock, EventSheetL10n.translate("Now %s.") % replacement, false)
	else:
		_say(dock, EventSheetL10n.translate("That word could not be found in the row to change it."), true)
	return true


## The one word changed everywhere one row holds it. Returns how many places changed.
static func _respell_entry(entry: Resource, subject: String, replacement: String) -> int:
	if entry == null:
		return 0
	var touched: int = 0
	if entry is RawCodeRow:
		var block: RawCodeRow = entry as RawCodeRow
		var written: String = respell(block.code, subject, replacement)
		touched += 0 if written == block.code else 1
		block.code = written
	elif entry is PickFilter:
		var pick: PickFilter = entry as PickFilter
		for property: String in ["collection_value", "source_expression", "predicate_expression", "order_by_expression"]:
			var before: String = str(pick.get(property))
			var after: String = respell(before, subject, replacement)
			if after != before:
				pick.set(property, after)
				touched += 1
	else:
		if entry.get("params") is Dictionary:
			touched += _respell_table(entry.get("params") as Dictionary, subject, replacement)
		# A baked template (a lifted line) holds the word itself.
		var template: String = str(entry.get("codegen_template"))
		var after_template: String = respell(template, subject, replacement)
		if after_template != template:
			entry.set("codegen_template", after_template)
			touched += 1
	return touched


static func _respell_table(params: Dictionary, subject: String, replacement: String) -> int:
	var touched: int = 0
	for key: Variant in params.keys():
		if params[key] is String:
			var after_value: String = respell(str(params[key]), subject, replacement)
			if after_value != params[key]:
				params[key] = after_value
				touched += 1
	return touched


## The variable row of this name on the open sheet.
static func _variable_named(dock: Control, variable_name: String) -> LocalVariable:
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	return _variable_in(sheet.events, variable_name) if sheet != null else null


static func _variable_in(items: Array, variable_name: String) -> LocalVariable:
	for item: Variant in items:
		if item is LocalVariable and (item as LocalVariable).name.strip_edges() == variable_name:
			return item as LocalVariable
		if item is EventGroup:
			var inner: LocalVariable = _variable_in(EventSheetGroupFacts.children(item as EventGroup), variable_name)
			if inner != null:
				return inner
	return null


static func _point_at_node(dock: Control, finding: Dictionary, target: String) -> bool:
	var entry: Resource = _entry_of(finding)
	if entry == null or target.is_empty() or not (entry.get("params") is Dictionary):
		return false
	var params: Dictionary = entry.get("params")
	dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Point at %s") % target, func() -> bool:
		params["target"] = target
		return true)
	_say(dock, EventSheetL10n.translate("The row now acts on %s.") % target, false)
	return true


static func _remember(dock: Control, finding: Dictionary) -> bool:
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	if sheet == null:
		return false
	var path: String = sheet.external_source_path if not sheet.external_source_path.is_empty() else sheet.resource_path
	var kind: String = str(finding.get("kind", ""))
	var subject: String = str(finding.get("subject", ""))
	EventSheetMistakeFindings.remember(path, kind, subject)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		ProjectSettings.save()
	EventSheetMistakeFindings.clear_cache()
	_say(dock, EventSheetL10n.translate("Noted: %s is made while the game runs, so this sheet will not be asked about it again.") % subject, false)
	dock.call("_refresh_after_edit")
	return true


## The guard for a While nothing inside can end. All of it is plain GDScript the sheet reads back:
## `var rounds := 0`, `rounds += 1` as the first line of the body, and `and rounds < 1000`. A plain event has
## its line before the loop in a sibling. An event with a trigger or a condition has none (its first line IS
## the loop), so the event keeps those and the counter, and the loop goes one level in, under them.
static func _stop_after_rounds(dock: Control, finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	var slot: int = int(finding.get("index", -1))
	if event_row == null or slot < 0 or slot >= event_row.pick_filters.size():
		return false
	var pick: PickFilter = event_row.pick_filters[slot] as PickFilter
	if pick == null:
		return false
	var plain: bool = event_row.trigger_id.is_empty() and event_row.trigger == null \
		and event_row.conditions.is_empty() and event_row.else_mode == EventRow.ElseMode.NONE
	var siblings: Variant = _list_of_event(dock, event_row) if plain else null
	if plain and siblings == null:
		return false
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Stop after %d rounds") % EventSheetMistakeFindings.GUARD_LIMIT, func() -> bool:
		var condition: String = pick.collection_value.strip_edges()
		if condition.contains(" or "):
			condition = "(%s)" % condition
		pick.collection_value = "%s and %s < %d" % [condition, EventSheetMistakeFindings.GUARD_COUNTER, EventSheetMistakeFindings.GUARD_LIMIT]
		# The counter is a local declared on its own line just before the loop, as plain code would.
		var declare: ACEAction = ACEAction.new()
		declare.provider_id = "Core"
		declare.ace_id = "SetLocalVarInferred"
		declare.params = {"name": EventSheetMistakeFindings.GUARD_COUNTER, "value": "0"}
		var step: ACEAction = ACEAction.new()
		step.provider_id = "Core"
		step.ace_id = "AddVar"
		step.params = {"var_name": EventSheetMistakeFindings.GUARD_COUNTER, "amount": "1"}
		if plain:
			var before: EventRow = EventRow.new()
			before.actions.append(declare)
			(siblings as Array).insert((siblings as Array).find(event_row), before)
			event_row.actions.insert(0, step)
			return true
		var inner: EventRow = EventRow.new()
		inner.pick_filters = event_row.pick_filters.duplicate()
		inner.actions = event_row.actions.duplicate()
		inner.actions.insert(0, step)
		inner.sub_events = event_row.sub_events.duplicate()
		event_row.pick_filters = []
		event_row.actions = [declare]
		event_row.sub_events = [inner]
		return true))
	if done:
		_say(dock, EventSheetL10n.translate("The loop now stops after %d rounds.") % EventSheetMistakeFindings.GUARD_LIMIT, false)
	return true


## The one row that ends a plain counting loop, as the body's last line.
static func _change_variable(dock: Control, finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	var change: Dictionary = finding.get("change", {})
	if event_row == null or change.is_empty():
		return false
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", str(change["label"]), func() -> bool:
		var step: ACEAction = ACEAction.new()
		step.provider_id = "Core"
		step.ace_id = str(change["ace_id"])
		step.params = {"var_name": str(change["name"]), "amount": "1"}
		event_row.actions.append(step)
		return true))
	if done:
		_say(dock, EventSheetL10n.translate("The loop now changes %s each round.") % str(change["name"]), false)
	return true


## The loop's condition becomes an If on the same event: the same words, one run of the body.
static func _make_if(dock: Control, finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	var slot: int = int(finding.get("index", -1))
	if event_row == null or slot < 0 or slot >= event_row.pick_filters.size():
		return false
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Make it an If"), func() -> bool:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = "ExpressionIsTrue"
		condition.params = {"expr": (event_row.pick_filters[slot] as PickFilter).collection_value.strip_edges()}
		event_row.conditions.append(condition)
		event_row.pick_filters.remove_at(slot)
		return true))
	if done:
		_say(dock, EventSheetL10n.translate("Now an If: the body runs once when it is true."), false)
	return true


## The list that holds an event, among the sheet's events and every function's.
static func _list_of_event(dock: Control, event_row: EventRow) -> Variant:
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	if sheet == null:
		return null
	var holder: Variant = _list_holding(sheet.events, event_row)
	if holder == null:
		for entry: Variant in sheet.functions:
			var event_function: EventFunction = entry as EventFunction
			if event_function != null:
				holder = _list_holding(event_function.events if not event_function.events.is_empty() else event_function.rows, event_row)
				if holder != null:
					break
	return holder


## The list that holds an event, searched through groups and sub-events; null when it is nowhere in `items`.
static func _list_holding(items: Array, target: EventRow) -> Variant:
	for item: Variant in items:
		if item == target:
			return items
		var inner: Variant = null
		if item is EventRow:
			inner = _list_holding((item as EventRow).sub_events, target)
		elif item is EventGroup:
			inner = _list_holding((item as EventGroup).child_rows(), target)
		if inner != null:
			return inner
	return null


# -- Signals -------------------------------------------------------------------------------------


## An emit given the values its signal declares. A value the row can name (a local, a parameter, a sheet
## variable called what the signal calls it) is sent by name; otherwise the type's plain empty value, so the
## line compiles at once and the reader changes one word. An emit with too many keeps the first ones.
static func _fit_emit(dock: Control, finding: Dictionary) -> bool:
	var entry: Resource = _entry_of(finding)
	var signal_name: String = str(finding.get("signal", ""))
	var wanted: PackedStringArray = finding.get("wanted_names", PackedStringArray())
	var sent: int = int(finding.get("sent", 0))
	if entry == null or signal_name.is_empty():
		return false
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	var known: Dictionary = {}
	for known_name: String in EventSheetGDScriptLint.scope_names_of(sheet, finding.get("event") as EventRow):
		known[known_name] = true
	for variable_name: Variant in sheet.variables.keys():
		known[str(variable_name)] = true
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Emit %s") % signal_name, func() -> bool:
		return _rewrite_emit(entry, signal_name, func(args: PackedStringArray) -> PackedStringArray:
			var fitted: PackedStringArray = args.slice(0, mini(args.size(), wanted.size()))
			for index: int in range(mini(sent, args.size()), wanted.size()):
				var word: String = wanted[index].get_slice(":", 0).strip_edges()
				fitted.append(word if known.has(word) else empty_value_of(wanted[index].get_slice(":", 1).strip_edges()))
			return fitted)))
	if done:
		_say(dock, EventSheetL10n.translate("%s now sends what it declares.") % signal_name, false)
	else:
		_say(dock, EventSheetL10n.translate("That word could not be found in the row to change it."), true)
	return true


## The empty value a type starts at, as a line writes it; null for what has no plain empty value.
static func empty_value_of(type_name: String) -> String:
	match type_name:
		"int":
			return "0"
		"float":
			return "0.0"
		"bool":
			return "false"
		"String":
			return "\"\""
		"StringName":
			return "&\"\""
		"Array":
			return "[]"
		"Dictionary":
			return "{}"
		"Color":
			return "Color.WHITE"
	if type_name in EventSheetGDScriptLint.VALUE_TYPE_NAMES and type_name != "RID" and type_name != "Callable" and type_name != "Signal":
		return "%s()" % type_name
	return "null"


## The argument list of the row's emit put through `fit`. A row of the emit verb holds it in its `args`; a
## verbatim or lifted line holds it in its code.
static func _rewrite_emit(entry: Resource, signal_name: String, fit: Callable) -> bool:
	if entry.get("params") is Dictionary and (entry.get("params") as Dictionary).has("args") and str(entry.get("codegen_template")).is_empty():
		var params: Dictionary = entry.get("params")
		params["args"] = ", ".join(fit.call(EventSheetMistakeFindings.split_top_level(str(params["args"]))))
		return true
	var property: String = "code" if entry is RawCodeRow else "codegen_template"
	var text: String = str(entry.get(property))
	var opened: int = text.find(signal_name + ".emit(")
	var prefix_arguments: int = 0
	if opened >= 0:
		opened += signal_name.length() + ".emit".length()
	else:
		opened = text.find("emit_signal(")
		prefix_arguments = 1
		if opened < 0:
			return false
		opened += "emit_signal".length()
	var inside: String = EventSheetMistakeFindings._balanced_after(text, opened)
	var arguments: PackedStringArray = EventSheetMistakeFindings.split_top_level(inside)
	var kept: PackedStringArray = arguments.slice(0, prefix_arguments)
	kept.append_array(fit.call(arguments.slice(prefix_arguments)))
	entry.set(property, text.substr(0, opened + 1) + ", ".join(kept) + text.substr(opened + 1 + inside.length()))
	return true


## Goes to the row that declares the signal.
static func _open_signal(dock: Control, finding: Dictionary) -> bool:
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	var declared: SignalRow = _signal_in(sheet.events, str(finding.get("signal", ""))) if sheet != null else null
	if declared == null:
		return false
	var view: Variant = dock.call("_active_view")
	if view != null:
		view.call("reveal_resource", declared)
	return true


static func _signal_in(items: Array, signal_name: String) -> SignalRow:
	for item: Variant in items:
		if item is SignalRow and (item as SignalRow).signal_name.strip_edges() == signal_name:
			return item as SignalRow
		if item is EventGroup:
			var inner: SignalRow = _signal_in(EventSheetGroupFacts.children(item as EventGroup), signal_name)
			if inner != null:
				return inner
	return null


static func _fit_handler(dock: Control, finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	if event_row == null or not finding.has("handler_args"):
		return false
	var written: String = str(finding["handler_args"])
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Fit the handler to %s") % str(finding.get("signal", "")), func() -> bool:
		event_row.trigger_args = written
		return true))
	if done:
		_say(dock, EventSheetL10n.translate("The handler now takes what %s sends.") % str(finding.get("signal", "")), false)
	return true


static func _add_to_signal(dock: Control, finding: Dictionary) -> bool:
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	var signal_name: String = str(finding.get("signal", ""))
	var declared: SignalRow = _signal_in(sheet.events, signal_name) if sheet != null else null
	if declared == null or not finding.has("signal_params"):
		return false
	var widened: PackedStringArray = finding["signal_params"]
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Add to %s") % signal_name, func() -> bool:
		declared.params = widened
		return true))
	if done:
		_say(dock, EventSheetL10n.translate("%s now declares %s. Check the rows that emit it.") % [signal_name, ", ".join(widened)], false)
	return true


# -- Locals --------------------------------------------------------------------------------------


## The local takes a free name, and every use inside its event follows it. Strings are left as they are.
static func _rename_local(dock: Control, finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	var old_name: String = str(finding.get("subject", ""))
	var new_name: String = str(finding.get("new_name", ""))
	if event_row == null or new_name.is_empty():
		return false
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Rename the local to %s") % new_name, func() -> bool:
		var counter: Dictionary = {"count": 0, "skip_string_literals": true}
		var whole_word: RegEx = RegEx.create_from_string("\\b%s\\b" % old_name)
		for local: Variant in event_row.local_variables:
			EventSheetRefactor._rename_in_rows([local], whole_word, new_name, counter)
		EventSheetRefactor._rename_in_rows([event_row], whole_word, new_name, counter)
		return int(counter["count"]) > 0))
	if done:
		_say(dock, EventSheetL10n.translate("The local is now %s.") % new_name, false)
	return true


## The declaring row goes; the uses of the name in the event now read what it hid.
static func _remove_local(dock: Control, finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	var local_name: String = str(finding.get("subject", ""))
	var declaring: Resource = EventSheetMistakeFindings.declaring_row(event_row, local_name) if event_row != null else null
	if declaring == null:
		return false
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Remove the local %s") % local_name, func() -> bool:
		if declaring is LocalVariable:
			event_row.local_variables.erase(declaring as LocalVariable)
		else:
			event_row.actions.erase(declaring)
		return true))
	if done:
		_say(dock, EventSheetL10n.translate("The local is gone; %s now means what it hid.") % local_name, false)
	return true


# -- Values --------------------------------------------------------------------------------------


## The rewrite the check found, in the one parameter it is about.
static func _use_value(dock: Control, finding: Dictionary) -> bool:
	var entry: Resource = _entry_of(finding)
	var param: String = str(finding.get("param", ""))
	var rewrite: String = str(finding.get("to", ""))
	if entry == null or param.is_empty() or rewrite.is_empty() or not (entry.get("params") is Dictionary):
		return false
	var params: Dictionary = entry.get("params")
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Use %s") % rewrite, func() -> bool:
		params[param] = rewrite
		return true))
	if done:
		_say(dock, EventSheetL10n.translate("Now %s.") % rewrite, false)
	return true


## Opens the row's own parameters, on the event the finding is about.
static func _open_value(dock: Control, finding: Dictionary) -> bool:
	var row_data: EventRowData = _row_of(dock, finding)
	if row_data == null:
		return false
	dock.get("_ace_apply")._on_viewport_ace_edit_requested(row_data, -1, {"kind": str(finding.get("lane", "")), "ace_index": int(finding.get("index", -1))})
	return true


## Selects the event a finding is about and hands back its row.
static func _row_of(dock: Control, finding: Dictionary) -> EventRowData:
	var view: Variant = dock.call("_active_view")
	var event_row: EventRow = finding.get("event") as EventRow
	if view == null or event_row == null or not bool(view.call("reveal_resource", event_row)):
		return null
	return view.call("_row_at", int(view.get("_selected_row_index"))) as EventRowData


static func _go_to_variable(dock: Control, finding: Dictionary) -> bool:
	var variable: LocalVariable = _variable_named(dock, str(finding.get("variable", "")))
	var view: Variant = dock.call("_active_view")
	if variable == null or view == null:
		return false
	view.call("reveal_resource", variable)
	return true


# -- Doors that open Godot's own pickers ---------------------------------------------------------


## True where a picker of the editor's can open: not in a headless run, not in a test.
static func _can_pick() -> bool:
	return Engine.is_editor_hint() and DisplayServer.get_name() != "headless"


static func _pick_node(dock: Control, finding: Dictionary) -> bool:
	if not _can_pick() or EditorInterface.get_edited_scene_root() == null:
		_say(dock, EventSheetL10n.translate("Open the scene that runs this sheet to pick a node from it."), false)
		return true
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	var kept: Dictionary = finding
	EditorInterface.popup_node_selector(func(picked: NodePath) -> void:
		if picked.is_empty():
			return
		var root: Node = EditorInterface.get_edited_scene_root()
		var node: Node = root.get_node_or_null(picked) if root != null else null
		var host: Node = EventSheetTypeCheck.host_in_scene(root, sheet)
		if node == null:
			return
		var written: String = "self" if node == host else "$%s" % str((host if host != null else root).get_path_to(node))
		var again: Dictionary = _live_finding(dock, kept)
		if not again.is_empty():
			_point_at_node(dock, again, written))
	return true


static func _pick_row(dock: Control, finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	if event_row == null:
		return false
	var lane: String = str(finding.get("lane", ""))
	var picker: Variant = dock.get("_ace_picker")
	if picker != null:
		picker.open("replace_condition" if lane == "condition" else "replace_action", false, event_row,
			{"selected_resource": event_row, "ace_index": int(finding.get("index", -1))})
	return true


static func _pick_file(dock: Control, finding: Dictionary) -> bool:
	if not _can_pick():
		_say(dock, EventSheetL10n.translate("Open the row and choose the file there."), false)
		return true
	var kept: Dictionary = finding
	EditorInterface.popup_quick_open(func(picked: String) -> void:
		if picked.is_empty():
			return
		var again: Dictionary = _live_finding(dock, kept)
		if not again.is_empty():
			_use_name(dock, again, picked), ["Resource", "Script"])
	return true


## The group goes on a node of the open scene, picked in Godot's own selector, through the editor's undo. It
## stops being a group nothing is in when the scene is saved, because that is what the check reads.
static func _group_on_node(dock: Control, finding: Dictionary) -> bool:
	var group_name: String = str(finding.get("subject", ""))
	if not _can_pick() or EditorInterface.get_edited_scene_root() == null:
		_say(dock, EventSheetL10n.translate("Open a scene to add \"%s\" to a node in it.") % group_name, false)
		return true
	EditorInterface.popup_node_selector(func(picked: NodePath) -> void:
		var root: Node = EditorInterface.get_edited_scene_root()
		var node: Node = root.get_node_or_null(picked) if root != null and not picked.is_empty() else null
		if node == null:
			return
		var history: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
		history.create_action(EventSheetL10n.translate("Add to group %s") % group_name)
		history.add_do_method(node, "add_to_group", group_name, true)
		history.add_undo_method(node, "remove_from_group", group_name)
		history.commit_action()
		_say(dock, EventSheetL10n.translate("%s is in \"%s\" now. Save the scene and this row stops asking.") % [node.name, group_name], false))
	return true


## The project's controls in a menu at the pointer; the pick is written into the row.
static func _pick_action(dock: Control, finding: Dictionary) -> bool:
	var names: PackedStringArray = EventSheetInputMapFacts.project_action_names()
	if not _can_pick() or names.is_empty():
		_say(dock, EventSheetL10n.translate("Pick the control this row means in Project > Project Settings > Input Map, then use its name here."), false)
		return true
	var menu: PopupMenu = PopupMenu.new()
	for action_name: String in names:
		menu.add_item(action_name)
	dock.add_child(menu)
	var kept: Dictionary = finding
	menu.index_pressed.connect(func(index: int) -> void:
		var again: Dictionary = _live_finding(dock, kept)
		if not again.is_empty():
			_use_name(dock, again, menu.get_item_text(index)))
	menu.popup_hide.connect(menu.queue_free, CONNECT_DEFERRED)
	EventSheetWindowPlacement.popup_at(menu, EventSheetWindowPlacement.pointer_for(menu))
	return true
