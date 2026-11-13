# Godot EventSheets - a tool that builds without clearing what it built last time, anchored at the event.
#
# A tool sheet that adds nodes to the open scene when a button is pressed adds ANOTHER copy every time it
# is pressed, unless something removes the last one first. The Building rows mark what a tool sheet
# builds, and Remove What This Sheet Built finds the marked nodes again; this file asks of ONE sheet
# whether an event builds without anything clearing before it, so the canvas can put that event - and only
# that event - into the quiet amber state, and the help strip and the Doctor can say the sentence.
#
# THE QUIET SHEET LAW. Nothing here renders in the sheet: a finding sets the amber state and stops. The
# words live in the help strip under the selected row and in the Doctor's Tool edits inbox.
#
# IT FIRES ONLY IN A TOOL SHEET, and only for an event that holds a Building row dropped in as a tool row
# (the row carries the mark lines). An event that clears first - itself or an earlier event answering the
# same trigger - is quiet, and so is a sheet nobody is building in.
#
# THE DOOR adds the clearing row at the top of the event, under the parent the building row names, so a
# press is the whole repair and one undo step takes it back. Nothing is stored: every finding is derived
# on every ask.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetRebuildFindings
extends RefCounted

## The one finding, by id. Frozen: the amber state, the help strip, the Doctor and the tests address it by
## this - one finding under three roofs.
const KIND_REBUILD := "tool-builds-without-clearing"

## Where the note hangs: the event, like the other tool findings.
const ANCHOR_EVENT := "event"

## The one-click answer, by the id the dock's door and the inbox chip both dispatch on.
const FIX_CLEAR_FIRST := "clear_what_it_built_first"

## The row that clears, and the text a building row carries once it was dropped into a tool sheet.
const CLEAR_ACE_ID := "RemoveBuiltNodes"
const BUILT_MARK := "set_meta(&\"built_by_sheet\""


## Every rebuild note this sheet earns, one per event that builds without clearing first. `script_path` is
## only the label the sentence leads with.
static func findings(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null or not sheet.tool_mode:
		return found
	var label: String = (script_path if not script_path.is_empty() else str(sheet.resource_path)).get_file()
	_walk(sheet.events, label, {}, found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events if not event_function.events.is_empty() else event_function.rows,
				label, {}, found)
	return found


## The words, in one place, so the Doctor's line and the sentence the sheet's own help strip shows under
## the selected row are the same finding said once.
static func message(label: String) -> String:
	var said: String = EventSheetL10n.translate("%s builds nodes in the scene the editor has open, and nothing in this event or an earlier one for the same trigger removes what the last run built, so every run adds another copy.") % label
	return said + " " + EventSheetL10n.translate("Remove What This Sheet Built clears what an earlier run built; Clear what it built first puts it at the top of this event.")


## The index of the first row of an event that builds as a tool row, or -1.
static func building_slot(event_row: EventRow) -> int:
	for slot: int in event_row.actions.size():
		var action: ACEAction = event_row.actions[slot] as ACEAction
		if action == null or not action.enabled:
			continue
		# The mark lines are in the row's own text only once it was dropped into a tool sheet; a row
		# that still holds them as an optional segment writes nothing of the kind.
		var template: String = str(action.codegen_template)
		if template.contains(BUILT_MARK) and not template.contains("{?tool"):
			return slot
	return -1


## Whether an event holds the clearing row.
static func clears(event_row: EventRow) -> bool:
	for entry: Variant in event_row.actions:
		var action: ACEAction = entry as ACEAction
		if action != null and action.enabled and action.ace_id == CLEAR_ACE_ID:
			return true
	return false


## One finding's answer: the clearing row at the top of the event, under the node the building row builds
## under. False when there is nothing to write. `uid` is the id the row's throwaway local is baked with.
static func clear_first(finding: Dictionary, uid: String) -> bool:
	var event_row: EventRow = finding.get("event", null) as EventRow
	if event_row == null or clears(event_row):
		return false
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", CLEAR_ACE_ID)
	if descriptor == null:
		return false
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = CLEAR_ACE_ID
	var under: String = str(finding.get("to", "")).strip_edges()
	action.params = {"parent": under if not under.is_empty() else str(descriptor.params[0].default_value)}
	action.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	event_row.actions.insert(0, action)
	return true


## One walk of the rows. `cleared` holds the triggers an earlier event of this list already clears for;
## a sub-event belongs to its parent's event, so it is walked with what the parent knew.
static func _walk(items: Array, label: String, cleared: Dictionary, found: Array[Dictionary]) -> void:
	var seen: Dictionary = cleared.duplicate()
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), label, seen, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var trigger: String = event_row.trigger_id
		var here_clears: bool = clears(event_row)
		var slot: int = building_slot(event_row)
		if slot >= 0 and not here_clears and not seen.has(trigger):
			var built: ACEAction = event_row.actions[slot] as ACEAction
			found.append({
				"kind": KIND_REBUILD, "severity": "warning", "anchor": ANCHOR_EVENT, "event": event_row,
				"subject": built.ace_id, "message": message(label),
				"fix": FIX_CLEAR_FIRST, "fix_label": EventSheetL10n.translate("Clear what it built first"),
				"lane": "action", "index": slot,
				"to": str(built.params.get("parent", built.params.get("target", "get_tree().edited_scene_root"))),
			})
		if here_clears:
			seen[trigger] = true
		_walk(event_row.sub_events, label, seen, found)
