# Godot EventSheets - the row whose name was renamed out from under it.
#
# Somebody renames a function in the script editor, or a node in the Scene dock, and the rows that
# called it are suddenly holding a name nothing answers to. The row is not corrupt - it still says
# what it always said and still compiles to the line it always compiled to - but the thing it points
# at has moved, and nobody told it.
#
# THE QUIET SHEET LAW. Nothing here renders in the sheet. A finding sets the quiet amber state and
# stops: no block, no icon, no inline sentence, no hover. The words live in the Doctor's triage inbox
# and in the help strip under the selected row, and a sheet with nothing to answer says nothing.
#
# EVIDENCE, NEVER A GUESS. A finding is only made at all when the file's own last save shows the name
# vanishing out of it - so this never reports a call to something that was always somewhere else, and
# never reports an inherited method it happens not to recognise. The "did you mean" beside it is
# offered only when that same save shows a replacement arriving, and the rule that decides it lives
# in one place. Anything weaker is a plainly amber row with the sentence and no door: the reader
# retypes the name in the cell, which is one double-click away and was never the hard part.
#
# ONE DOOR, AND IT MOVES THE WHOLE SHEET. A rename broke every row that used the name, so pointing
# them somewhere new is one gesture over all of them, through the sheet's own undo funnel, after a
# receipt naming each. Two rows fixed and four left is not a state anybody wants to be in.
#
# NOTHING IS STORED. Every finding is derived on every ask, so a sheet that has been pointed
# somewhere new stops reporting with no state to clean up.
#
# PURE + STATIC: no viewport, no dialog, no display server. The witness is handed IN, so every branch
# below is pinned headless with two lists of names.
@tool
class_name EventSheetRenameFindings
extends RefCounted

## The two findings, by id. Frozen: the amber state, the help strip, the Doctor's section and the
## tests all address one by this.
const KIND_CALL_GONE := "rename-call-gone"
const KIND_NODE_GONE := "rename-node-gone"

## Where a note hangs. Both findings are about a row inside an event, so both anchor at the event -
## the same anchor every other note in this pass uses for the same reason.
const ANCHOR_EVENT := "event"

## The one door, by the id the dock's strip and the inbox chip both dispatch on. It is only ever
## offered when the file proved where the name went.
const FIX_POINT_THE_ROWS := "point_the_rows_there"

## The verb a sheet calls its own functions with. A row of any other kind is not a call by this
## name and is none of this file's business.
## The two lanes, spelled the way every other finding in this pass spells them - a finding carries
## the lane it was found in so the door can address the row it is about.
const LANE_CONDITION := "condition"
const LANE_ACTION := "action"

## What may sit in front of a name without the name being the one written there. Spelled out rather
## than asked of a regex, because this runs over every parameter of every row of every sheet built.
const IDENTIFIER_CHARACTERS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"

const CALL_PROVIDER := "Core"
const CALL_ACE := "CallFunction"
const CALL_PARAM := "function_name"

## The node-reference token grammar, borrowed from the refactor core rather than spelled again -
## the walk that finds a reference and the rewrite that moves it must agree about what one is.
static var _node_ref_re: RegEx = null


## Every rename note this sheet earns. `witness` is what the file's last save did, as
## `EventSheetRenameEvidence.witness_for` builds it; a witness with nothing in it earns no findings
## at all, which is the ordinary case and costs one dictionary read. `label_path` is the file the
## sheet lives in and is only the label the sentence leads with.
static func findings(sheet: EventSheetResource, label_path: String = "",
		witness: Dictionary = {}) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null or witness.is_empty():
		return found
	var names_gone: PackedStringArray = witness.get("names_gone", PackedStringArray())
	var nodes_gone: PackedStringArray = witness.get("nodes_gone", PackedStringArray())
	if names_gone.is_empty() and nodes_gone.is_empty():
		return found
	var label: String = label_path.get_file() if not label_path.is_empty() \
		else str(sheet.resource_path).get_file()
	var declared: PackedStringArray = declared_functions(sheet)
	_walk(sheet.events, sheet, label, declared, witness, found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(_function_rows(event_function), sheet, label, declared, witness, found)
	return found


## The findings anchored at one event row - what the canvas puts into the amber state. Matched by
## IDENTITY, so the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == ANCHOR_EVENT and entry.get("event") == event_row:
			mine.append(entry)
	return mine


## The function names this sheet declares, sorted. A call to one of them resolves however loudly the
## file's last save changed around it, so it is never reported.
static func declared_functions(sheet: EventSheetResource) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if sheet == null:
		return names
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null:
			continue
		var name: String = event_function.function_name.strip_edges()
		if not name.is_empty() and not names.has(name):
			names.append(name)
	names.sort()
	return names


## The sentence a row whose call no longer resolves says, in the ONE place it is written - so the
## Doctor's line and the sheet's own help strip are the same finding said once. `answer` is what the
## file's save proved the name became, or "" when it proved nothing.
static func call_gone_message(name: String, label: String, answer: String) -> String:
	var message: String = EventSheetL10n.translate("%s is no longer declared in %s - it went out of the file in the same save that wrote it.") % [
		name, label]
	if answer.is_empty():
		return message + " " + EventSheetL10n.translate("Nothing in that save says what it became, so nothing here will guess: type the name this row should call into its cell.")
	return message + " " + EventSheetL10n.translate("That same save added %s, and nothing else - point the rows there, or leave them and type the name yourself.") % answer


## The same sentence for a node reference, which reads about the SCENE rather than about the file.
## The `$` and `%` are kept in the words because that is how the row spells the node.
static func node_gone_message(token: String, scene_label: String, answer: String) -> String:
	var message: String = EventSheetL10n.translate("%s is gone from %s.") % [token, scene_label]
	if answer.is_empty():
		return message + " " + EventSheetL10n.translate("That save added no node this one could have become, so nothing here will guess: pick the node this row means.")
	return message + " " + EventSheetL10n.translate("That same save gained %s - point the rows there, or leave them and pick the node yourself.") % answer


## What the door WOULD do, as the receipt a dialog draws before anybody presses anything: the name
## as it stands and the name it would become. Pure, so the receipt and the edit can never be two
## different answers.
static func point_receipt(finding: Dictionary) -> Dictionary:
	return {
		"before": str(finding.get("subject", "")),
		"after": str(finding.get("to", "")),
		"kind": str(finding.get("kind", "")),
	}


## Every node reference one run of text holds, in the order it holds them. The refactor core's own
## token grammar, so a reference this finds is a reference the rewrite can move.
static func node_references_in(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if text.strip_edges().is_empty():
		return found
	if _node_ref_re == null:
		_node_ref_re = RegEx.create_from_string(EventSheetRefactor.NODE_REF_PATTERN)
	for hit: RegExMatch in _node_ref_re.search_all(text):
		var token: String = hit.get_string()
		if not found.has(token):
			found.append(token)
	return found


## The node names one reference token walks through, outermost first: `$UI/Bars/Torch` is three
## names, and renaming any one of them breaks the row exactly as renaming the last one does.
static func names_in_reference(token: String) -> PackedStringArray:
	var body: String = token
	if body.begins_with("$"):
		body = body.substr(1)
	elif body.begins_with("%"):
		body = body.substr(1)
	if body.begins_with("\"") and body.ends_with("\"") and body.length() >= 2:
		body = body.substr(1, body.length() - 2)
	var names: PackedStringArray = PackedStringArray()
	for part: String in body.split("/", false):
		var name: String = part.strip_edges()
		if not name.is_empty():
			names.append(name)
	return names


## That same token with ONE of its names swapped - what the rows would say afterwards, and what the
## rewrite moves them to. The rest of the path is untouched, because only one name moved.
static func reference_with(token: String, old_name: String, new_name: String) -> String:
	var lead: String = ""
	var body: String = token
	if body.begins_with("$") or body.begins_with("%"):
		lead = body.substr(0, 1)
		body = body.substr(1)
	var quoted: bool = body.begins_with("\"") and body.ends_with("\"") and body.length() >= 2
	if quoted:
		body = body.substr(1, body.length() - 2)
	var parts: PackedStringArray = body.split("/", false)
	var rebuilt: PackedStringArray = PackedStringArray()
	for part: String in parts:
		rebuilt.append(new_name if part.strip_edges() == old_name else part)
	var joined: String = "/".join(rebuilt)
	return "%s%s" % [lead, "\"%s\"" % joined if quoted else joined]


## One walk of the rows, following groups and sub-events down - a row in a sub-event is still a row
## of the file, and a rename broke it exactly as it broke the rows above it.
static func _walk(items: Array, sheet: EventSheetResource, label: String,
		declared: PackedStringArray, witness: Dictionary, found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), sheet, label, declared,
				witness, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		_note_this_event(event_row, label, declared, witness, found)
		_walk(event_row.sub_events, sheet, label, declared, witness, found)


## The findings ONE event earns: the calls in it that no longer resolve, then the node references in
## it whose node is gone. Both lanes, in reading order.
##
## A CALL IS A CALL WHEREVER IT IS WRITTEN. The picked Call function row is the common one and it is
## read first, in BOTH lanes - a `bool` sheet function published as a condition is picked into the
## condition lane and used to be invisible here. But a renamed function also breaks a name written
## into an expression field, a trigger's parameter or a Script block, and those are text rather than
## rows: they are swept afterwards, once per event per name, and only for a name the picked pass has
## not already reported. The node half has always been thorough across every surface; the call half
## is now the same shape, because "a rename broke every row that used the name, so pointing them
## somewhere new is one gesture over all of them" is only true if every row is seen.
static func _note_this_event(event_row: EventRow, label: String, declared: PackedStringArray,
		witness: Dictionary, found: Array[Dictionary]) -> void:
	for slot: int in event_row.conditions.size():
		_note_a_call(event_row, event_row.conditions[slot] as Resource, slot, LANE_CONDITION, label,
			declared, witness, found)
	for slot: int in event_row.actions.size():
		_note_a_call(event_row, event_row.actions[slot] as Resource, slot, LANE_ACTION, label,
			declared, witness, found)
	_note_a_written_call(event_row, label, declared, witness, found)
	_note_the_nodes(event_row, witness, found)


## One action, measured against the call rule. Everything it declines to report is declined for a
## named reason, because a section that reports a row nobody can act on is one its reader scrolls past.
static func _note_a_call(event_row: EventRow, entry: Resource, slot: int, lane: String,
		label: String, declared: PackedStringArray, witness: Dictionary,
		found: Array[Dictionary]) -> void:
	if not (entry is ACEAction or entry is ACECondition):
		return
	if str(entry.get("provider_id")).strip_edges() != CALL_PROVIDER \
			or str(entry.get("ace_id")).strip_edges() != CALL_ACE:
		return
	var params: Variant = entry.get("params")
	if not (params is Dictionary):
		return
	var name: String = str((params as Dictionary).get(CALL_PARAM, "")).strip_edges()
	if name.is_empty() or declared.has(name):
		return
	# THE EVIDENCE GATE. Only a name this file's own last save took out of it is reported at all - a
	# call to something that always lived elsewhere is not a rename and must never be dressed as one.
	var names_gone: PackedStringArray = witness.get("names_gone", PackedStringArray())
	if not names_gone.has(name):
		return
	var answer: String = EventSheetRenameEvidence.did_you_mean(names_gone,
		witness.get("names_arrived", PackedStringArray()), name)
	found.append({
		"kind": KIND_CALL_GONE, "severity": "warning",
		"anchor": ANCHOR_EVENT, "event": event_row,
		"subject": name, "to": answer,
		"message": call_gone_message(name, label, answer),
		"fix": FIX_POINT_THE_ROWS if not answer.is_empty() else "",
		"fix_label": EventSheetL10n.translate("Point the rows at %s") % answer \
			if not answer.is_empty() else "",
		"second_fix": "", "second_fix_label": "",
		"lane": lane, "index": slot, "path": label,
	})


## THE OTHER HALF OF THE CALL RULE: a name that went out of this file and is still WRITTEN somewhere
## in this event - an expression field, a trigger's parameter, a Script block. Those are text rather
## than a picked row, so they carry no lane and no slot, and the door they get is the same one: point
## the rows at the name the save proves it became.
##
## One finding per name per event, and never for a name a picked row above already reported: two
## sentences about one broken call is a list its reader learns to scroll past.
static func _note_a_written_call(event_row: EventRow, label: String, declared: PackedStringArray,
		witness: Dictionary, found: Array[Dictionary]) -> void:
	var names_gone: PackedStringArray = witness.get("names_gone", PackedStringArray())
	if names_gone.is_empty():
		return
	var said: PackedStringArray = PackedStringArray()
	for entry: Dictionary in found:
		if str(entry.get("kind", "")) == KIND_CALL_GONE and entry.get("event", null) == event_row:
			said.append(str(entry.get("subject", "")))
	for name: String in names_gone:
		if said.has(name) or declared.has(name):
			continue
		if not _calls_by_name(_written_text_of(event_row), name):
			continue
		said.append(name)
		var answer: String = EventSheetRenameEvidence.did_you_mean(names_gone,
			witness.get("names_arrived", PackedStringArray()), name)
		found.append({
			"kind": KIND_CALL_GONE, "severity": "warning",
			"anchor": ANCHOR_EVENT, "event": event_row,
			"subject": name, "to": answer,
			"message": call_gone_message(name, label, answer),
			"fix": FIX_POINT_THE_ROWS if not answer.is_empty() else "",
			"fix_label": EventSheetL10n.translate("Point the rows at %s") % answer \
				if not answer.is_empty() else "",
			"second_fix": "", "second_fix_label": "",
			"lane": "", "index": -1, "path": label,
		})


## Every piece of TEXT one event writes that could hold a call: each parameter of the trigger and of
## both lanes, and any verbatim code. Joined with newlines, because what is asked of it is only
## whether a name appears in it as a call.
static func _written_text_of(event_row: EventRow) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if event_row.trigger != null:
		_gather_text(event_row.trigger, parts)
	for condition: Variant in event_row.conditions:
		if condition is ACECondition:
			_gather_text(condition as Resource, parts)
		elif condition is RawCodeRow:
			parts.append((condition as RawCodeRow).code)
	for action: Variant in event_row.actions:
		if action is ACEAction:
			_gather_text(action as Resource, parts)
		elif action is RawCodeRow:
			parts.append((action as RawCodeRow).code)
	return "\n".join(parts)


static func _gather_text(entry: Resource, parts: PackedStringArray) -> void:
	var params: Variant = entry.get("params")
	if not (params is Dictionary):
		return
	for key: Variant in (params as Dictionary).keys():
		var value: Variant = (params as Dictionary)[key]
		if value is String:
			parts.append(value as String)


## True when this text CALLS that name: the name followed by an opening bracket, with no identifier
## character in front of it. That last part is what keeps `on_hit` out of `_on_hit` and out of
## `refresh_on_hit(` - a plain substring search would have reported both.
static func _calls_by_name(text: String, name: String) -> bool:
	if text.is_empty() or name.is_empty():
		return false
	var wanted: String = "%s(" % name
	var at: int = text.find(wanted)
	while at >= 0:
		if at == 0 or not IDENTIFIER_CHARACTERS.contains(text[at - 1]):
			return true
		at = text.find(wanted, at + 1)
	return false


## The node references one event holds, measured against the same rule against the SCENE's names.
## Every surface of the event that can carry one is read - its scope, its parameters, its verbatim
## code - because a rename broke the row wherever the name was written.
static func _note_the_nodes(event_row: EventRow, witness: Dictionary,
		found: Array[Dictionary]) -> void:
	var nodes_gone: PackedStringArray = witness.get("nodes_gone", PackedStringArray())
	if nodes_gone.is_empty():
		return
	var scene_label: String = str(witness.get("scene", "")).get_file()
	var said: PackedStringArray = PackedStringArray()
	for token: String in _tokens_of_event(event_row):
		for name: String in names_in_reference(token):
			if not nodes_gone.has(name) or said.has(token):
				continue
			said.append(token)
			var answer: String = EventSheetRenameEvidence.did_you_mean(nodes_gone,
				witness.get("nodes_arrived", PackedStringArray()), name)
			found.append({
				"kind": KIND_NODE_GONE, "severity": "warning",
				"anchor": ANCHOR_EVENT, "event": event_row,
				"subject": token, "to": reference_with(token, name, answer) if not answer.is_empty() else "",
				"node_was": name, "node_is": answer,
				"message": node_gone_message(token, scene_label,
					reference_with(token, name, answer) if not answer.is_empty() else ""),
				"fix": FIX_POINT_THE_ROWS if not answer.is_empty() else "",
				"fix_label": EventSheetL10n.translate("Point the rows at %s") \
					% reference_with(token, name, answer) if not answer.is_empty() else "",
				"second_fix": "", "second_fix_label": "",
				"lane": "", "index": -1, "path": scene_label,
			})


## Every node reference ONE event writes, across every surface of it that can hold one: the "With
## node X:" scope, each parameter of each lane, and any verbatim code in it.
static func _tokens_of_event(event_row: EventRow) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	_gather(event_row.with_node_target, tokens)
	if event_row.trigger != null:
		_gather_params(event_row.trigger, tokens)
	for condition: Variant in event_row.conditions:
		if condition is ACECondition:
			_gather_params(condition as Resource, tokens)
	for action: Variant in event_row.actions:
		if action is ACEAction:
			_gather_params(action as Resource, tokens)
		elif action is RawCodeRow:
			_gather((action as RawCodeRow).code, tokens)
	return tokens


static func _gather_params(entry: Resource, tokens: PackedStringArray) -> void:
	var params: Variant = entry.get("params")
	if not (params is Dictionary):
		return
	for key: Variant in (params as Dictionary).keys():
		var value: Variant = (params as Dictionary)[key]
		if value is String:
			_gather(value as String, tokens)


static func _gather(text: String, tokens: PackedStringArray) -> void:
	for token: String in node_references_in(text):
		if not tokens.has(token):
			tokens.append(token)


## One function's rows. A function built by the editor holds `events`; one lifted out of a
## hand-written file may hold `rows` instead, and every walk in this plugin reads both.
static func _function_rows(event_function: EventFunction) -> Array:
	return event_function.events if not event_function.events.is_empty() else event_function.rows
