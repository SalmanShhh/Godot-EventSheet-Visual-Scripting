# Godot EventSheets - the edit a tool cannot take back, anchored at the row that makes it.
#
# The Doctor's Tool edits section reads the project's tool sheets and files one warning about a
# change made to the open scene outside the editor's undo history. That sentence was written for the
# inbox; this file asks the very same question of the rows of ONE sheet, so the canvas can put that
# event - and only that event - into the quiet amber state, and the help strip can say the section's
# own sentence once the row is selected.
#
# THE QUIET SHEET LAW. Nothing here renders in the sheet. A finding sets the amber state and stops:
# no note row, no icon, no inline sentence, no hover. The words live in the Doctor's triage inbox and
# in the help strip under the selected row, and a sheet with nothing wrong says nothing at all.
#
# IT FIRES ONLY IN A TOOL SHEET, which is the whole of its scope and worth saying plainly: a game
# sheet setting a property on a node is simply correct, and there is no history for it to be missing
# from. The rule reads sheet.tool_mode and stops there on every other sheet, so a project with no
# tools in it runs no rule at all.
#
# THE DOOR IS THE TWIN. Three of the plain edits have an undoable row standing beside them that takes
# exactly the same parameters under exactly the same names, so the repair is a change of which row it
# is and nothing else - no value is rewritten, so nothing can be lost. An edit typed into a verbatim
# block, or made by a row with no twin, gets the sentence and no button: a button that cannot do
# anything is worse than none, and the sentence still says what to reach for.
#
# NOTHING IS STORED. Every finding is derived on every ask, so a sheet that has been made undoable
# stops reporting with no state to clean up.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetUndoableFindings
extends RefCounted

## The one finding, by id. Frozen: the amber state, the help strip, the Doctor's Tool edits section
## and the tests all address it by this - one finding under four roofs.
const KIND_NOT_UNDOABLE := "tool-edits-not-undoable"

## Where the note hangs. The finding is about a row inside an event, so it anchors at the event -
## the same anchor the spawning, networking and scene-trust notes use for the same reason.
const ANCHOR_EVENT := "event"

## The one-click answer, by the id the dock's door and the inbox chip both dispatch on.
const FIX_MAKE_IT_UNDOABLE := "make_the_edit_undoable"


## Every not-undoable note this sheet earns, one per event that changes the open scene outside the
## history. `script_path` is the file the sheet lives in and is only the label the sentence leads
## with; a sheet with no file yet leads with nothing rather than with a guess.
static func findings(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null or not sheet.tool_mode or not edits_the_open_scene(sheet):
		return found
	var label_path: String = script_path if not script_path.is_empty() else str(sheet.resource_path)
	_walk(sheet.events, label_path.get_file(), found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(_function_rows(event_function), label_path.get_file(), found)
	return found


## True when this sheet works on the scene the editor has open rather than on itself. The gate the
## whole rule stands behind, and the reason a @tool script on an ordinary node never hears from it: a
## node script setting its own properties in the editor is correct, and there is no history for it to
## be missing from. Asked of every row's emitted text, so a tool that reaches the edited scene from a
## verbatim block counts exactly as one that reaches it from a picked row.
static func edits_the_open_scene(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var seen: Array[Dictionary] = []
	_collect_text(sheet.events, seen)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_collect_text(_function_rows(event_function), seen)
	for said: Dictionary in seen:
		if EventForgeUndoableEdits.touches_open_scene(str(said.get("text", ""))):
			return true
	return false


## The findings anchored at one event row - what the canvas puts into the amber state. Matched by
## IDENTITY, so the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == ANCHOR_EVENT and is_same(entry.get("event"), event_row):
			mine.append(entry)
	return mine


## What making these edits undoable WOULD do to this sheet, as before/after pairs: the row as it is
## and the row it becomes. The reading the inbox chip shows before the reader is told anything
## worked, so a count is never the whole receipt. Only the rows that HAVE a twin are pairs - an edit
## with nothing to become is not part of what a press of the chip would do.
static func receipt(sheet: EventSheetResource) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for finding: Dictionary in findings(sheet):
		var twin: String = str(finding.get("to", ""))
		if not twin.is_empty():
			pairs.append({"before": str(finding.get("from", "")), "after": twin})
	return pairs


## One finding's answer: the same row, respelled as the undoable twin standing beside it. False when
## there is nothing to write, which is how a caller that repairs in a loop ends.
static func make_it_undoable(finding: Dictionary) -> bool:
	var event_row: EventRow = finding.get("event", null) as EventRow
	var slot: int = int(finding.get("index", -1))
	var twin: String = str(finding.get("to", "")).strip_edges()
	if event_row == null or twin.is_empty() or slot < 0 or slot >= event_row.actions.size():
		return false
	var row: Resource = event_row.actions[slot]
	if row == null or str(row.get("ace_id")) == twin:
		return false
	row.set("ace_id", twin)
	# The baked template is the row's own copy of the spelling it compiles through, and it is the OLD
	# spelling. Clearing it is what lets the undoable row's own template answer.
	row.set("codegen_template", "")
	return true


## The words, in one place, so the Doctor's line and the sentence the sheet's own help strip shows
## under the selected row are the same finding said once. `label` is the file the sheet lives in,
## `line` the change it makes, `kind` which of the three it is - and the row to reach for is named
## per kind, because "make it undoable" is three different rows depending on what is being changed.
static func not_undoable_message(label: String, line: String, kind: String) -> String:
	var message: String = EventSheetL10n.translate("%s changes the scene the editor has open without going through the editor's undo history, so the reader's Ctrl+Z walks straight past it into whatever they were doing before. First: %s.") % [
		label, line]
	message += " " + EventSheetL10n.translate("%s makes the same change as one step the editor can take back, and every undoable row of one event shares that one step.") % _row_for_kind(kind)
	message += " " + EventSheetL10n.translate("This is only asked of a Tool sheet - a sheet that runs in the game is not editing anybody's scene, and has no history to be missing from.")
	return message


## Which undoable row answers one kind of edit. Written out as literals rather than looked up in a
## table, because the translation sweep reads the words out of the call and a table's values are
## invisible to it.
static func _row_for_kind(kind: String) -> String:
	match kind:
		EventForgeUndoableEdits.EDIT_ADD:
			return EventSheetL10n.translate("Add Node (Undoable)")
		EventForgeUndoableEdits.EDIT_REMOVE:
			return EventSheetL10n.translate("Remove Node (Undoable)")
	return EventSheetL10n.translate("Set Property (Undoable)")


## One row's emitted code with its own values filled in - the text every rule here reads. A row's
## BAKED template is preferred over its descriptor's, because the baked copy is the one whose `{uid}`
## was filled in when the row was applied; a row built in memory (which is what a test does) falls
## back to the descriptor's. A verbatim block is its own code and is read exactly as written, which
## is what lets an edit somebody typed by hand earn the same note a picked row does.
static func emitted_text(entry: Variant) -> String:
	if entry is RawCodeRow:
		return (entry as RawCodeRow).code
	var ace: Resource = entry as Resource
	if ace == null:
		return ""
	var text: String = str(ace.get("codegen_template"))
	if text.strip_edges().is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
			str(ace.get("provider_id")), str(ace.get("ace_id")))
		text = "" if descriptor == null else descriptor.codegen_template
	var params: Variant = ace.get("params")
	if params is Dictionary:
		for key: Variant in (params as Dictionary).keys():
			text = text.replace("{%s}" % str(key), str((params as Dictionary)[key]))
	return text


## One walk of the rows. Recursive because a plain edit in a sub-event is still a row of the file.
static func _walk(items: Array, label: String, found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), label, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		_note_this_event(event_row, label, found)
		_walk(event_row.sub_events, label, found)


## The findings ONE event earns: one per KIND of plain edit it makes. Per kind rather than per row,
## because three properties set in a row of three rows is one thing to fix and one sentence to read;
## the slot recorded is the first of them, which is the row the door rewrites and the row the reader
## is looking at when the strip speaks.
static func _note_this_event(event_row: EventRow, label: String, found: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for slot: int in event_row.actions.size():
		var entry: Variant = event_row.actions[slot]
		if not bool(entry.get("enabled")):
			continue
		var ace_id: String = str(entry.get("ace_id"))
		if EventForgeUndoableEdits.ACE_IDS.has(ace_id):
			continue  # already through the history - this is the answer, not the question
		for line: String in emitted_text(entry).split("\n"):
			var kind: String = EventForgeUndoableEdits.raw_edit_kind(line)
			if kind.is_empty() or seen.has(kind):
				continue
			seen[kind] = true
			var twin: String = str(EventForgeUndoableEdits.TWIN_FOR_ACE.get(ace_id, ""))
			found.append({
				"kind": KIND_NOT_UNDOABLE, "severity": "warning",
				"anchor": ANCHOR_EVENT, "event": event_row,
				"subject": line.strip_edges(),
				"message": not_undoable_message(label, line.strip_edges(), kind),
				"fix": FIX_MAKE_IT_UNDOABLE if not twin.is_empty() else "",
				"fix_label": EventSheetL10n.translate("Make it undoable") if not twin.is_empty() else "",
				"lane": "action", "index": slot, "from": ace_id, "to": twin,
			})


## Every row's emitted text, gathered once - what the open-scene gate above reads. A dictionary per
## row rather than a bare string, so the walk that fills it reads the same as every other walk here.
static func _collect_text(items: Array, into: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_collect_text(EventSheetGroupFacts.children(item as EventGroup), into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for entry: Variant in event_row.actions:
			into.append({"text": emitted_text(entry)})
		for entry: Variant in event_row.conditions:
			into.append({"text": emitted_text(entry)})
		_collect_text(event_row.sub_events, into)


## One function's rows. A function built by the editor holds `events`; one lifted out of a
## hand-written file may hold `rows` instead, and every walk in this plugin reads both - a reader
## that read one of them would go quiet on exactly the files this plugin is for.
static func _function_rows(event_function: EventFunction) -> Array:
	return event_function.events if not event_function.events.is_empty() else event_function.rows
