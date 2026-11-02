# Godot EventSheets - the doors on a mistake check (the help strip's buttons and the Doctor's chips).
#
# Every door here is a step the reader could take by hand, taken for them and shown as one undo step
# through the dock's own funnel; none of them is a guess. A door whose cure is a decision (which node
# should this row mean, which control did you want) is a sentence, not a button.
#
#   use the name       respells the one word the finding is about, in the row it was found in: a
#                      group, a control, a node path, a file path. Nothing else in the row moves.
#   point at the node  writes the row's "On node" with the scene's own node of the class it needs.
#   known at run time  remembers, in the PROJECT, that this node or group is made while the game runs.
#                      A project setting, never the sheet file, so a .gd sheet gains not one byte.
#   stop after rounds  gives a While that cannot end the guard: a counter local called rounds, one
#                      added to it each round, and the condition and-ed with rounds < 1000.
#   add the control    puts the missing control into the Input Map (project.godot), unbound.
#
# The row is found by its lane and slot, never held across the funnel: the funnel replaces resources
# as it commits.
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
	match fix_id:
		EventSheetMistakeFindings.FIX_ADD_ACTION:
			var added: Dictionary = EventSheetQuickFixes.apply("add_input_action", finding, {"dock": dock})
			EventSheetInputMapFacts.clear_cache()
			_say(dock, str(added.get("message", "")), not bool(added.get("ok", false)))
			dock.call("_refresh_after_edit")
			return true
		EventSheetMistakeFindings.FIX_PICK_ACTION:
			_say(dock, EventSheetL10n.translate("Pick the control this row means in Project > Project Settings > Input Map, then use its name here."), false)
			return true
		EventSheetMistakeFindings.FIX_RUN_TIME:
			return _remember(dock, finding)
		EventSheetMistakeFindings.FIX_USE_NAME:
			return _use_name(dock, finding)
		EventSheetMistakeFindings.FIX_POINT_AT_NODE:
			return _point_at_node(dock, finding)
		EventSheetMistakeFindings.FIX_STOP_AFTER:
			return _stop_after_rounds(dock, finding)
	return false


## The row a finding sits in, found again on the live sheet: the entry of its lane at its slot.
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


static func _use_name(dock: Control, finding: Dictionary) -> bool:
	var subject: String = str(finding.get("subject", ""))
	var replacement: String = str(finding.get("to", ""))
	if str(finding.get("kind", "")) == EventSheetMistakeFindings.KIND_MISSING_PATH:
		subject = str(finding.get("subject", ""))
	var entry: Resource = _entry_of(finding)
	if entry == null or replacement.is_empty():
		return false
	var receipt: Dictionary = {"touched": 0}
	var done: bool = bool(dock.call("_perform_undoable_sheet_edit", EventSheetL10n.translate("Use %s") % replacement, func() -> bool:
		if entry is RawCodeRow:
			var block: RawCodeRow = entry as RawCodeRow
			var written: String = respell(block.code, subject, replacement)
			receipt["touched"] = 0 if written == block.code else 1
			block.code = written
		elif entry is PickFilter:
			var pick: PickFilter = entry as PickFilter
			for property: String in ["collection_value", "source_expression", "predicate_expression", "order_by_expression"]:
				var before: String = str(pick.get(property))
				var after: String = respell(before, subject, replacement)
				if after != before:
					pick.set(property, after)
					receipt["touched"] = int(receipt["touched"]) + 1
		else:
			var params: Dictionary = entry.get("params")
			for key: Variant in params.keys():
				if params[key] is String:
					var after_value: String = respell(str(params[key]), subject, replacement)
					if after_value != params[key]:
						params[key] = after_value
						receipt["touched"] = int(receipt["touched"]) + 1
			# A baked template (a lifted line) holds the word itself.
			var template: String = str(entry.get("codegen_template"))
			var after_template: String = respell(template, subject, replacement)
			if after_template != template:
				entry.set("codegen_template", after_template)
				receipt["touched"] = int(receipt["touched"]) + 1
		return int(receipt["touched"]) > 0))
	if done:
		_say(dock, EventSheetL10n.translate("Now %s.") % replacement, false)
	else:
		_say(dock, EventSheetL10n.translate("That word could not be found in the row to change it."), true)
	return true


static func _point_at_node(dock: Control, finding: Dictionary) -> bool:
	var entry: Resource = _entry_of(finding)
	var target: String = str(finding.get("to", ""))
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
## `var rounds := 0`, `rounds += 1` as the first line of the body, and `and rounds < 1000`.
static func _stop_after_rounds(dock: Control, finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event") as EventRow
	var slot: int = int(finding.get("index", -1))
	if event_row == null or slot < 0 or slot >= event_row.pick_filters.size():
		return false
	var pick: PickFilter = event_row.pick_filters[slot] as PickFilter
	if pick == null:
		return false
	var sheet: EventSheetResource = dock.get("_current_sheet") as EventSheetResource
	var holder: Variant = _list_holding(sheet.events, event_row) if sheet != null else null
	if holder == null and sheet != null:
		for entry: Variant in sheet.functions:
			var event_function: EventFunction = entry as EventFunction
			if event_function != null:
				holder = _list_holding(event_function.events if not event_function.events.is_empty() else event_function.rows, event_row)
				if holder != null:
					break
	if holder == null:
		return false
	var siblings: Array = holder as Array
	var place: int = siblings.find(event_row)
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
		var before: EventRow = EventRow.new()
		before.actions.append(declare)
		siblings.insert(place, before)
		var step: ACEAction = ACEAction.new()
		step.provider_id = "Core"
		step.ace_id = "AddVar"
		step.params = {"var_name": EventSheetMistakeFindings.GUARD_COUNTER, "amount": "1"}
		event_row.actions.insert(0, step)
		return true))
	if done:
		_say(dock, EventSheetL10n.translate("The loop now stops after %d rounds.") % EventSheetMistakeFindings.GUARD_LIMIT, false)
	return true


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
