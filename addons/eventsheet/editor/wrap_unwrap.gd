@tool
class_name EventSheetWrapUnwrap
extends RefCounted
# Godot EventSheets - WRAP and UNWRAP, the two reverse structure gestures.
#
# The editor could always create structure fast and never RESHAPE it: Group makes a folder,
# Region makes a fence, Add Sub-Event makes an empty child you hand-drag rows into. None of
# them puts a guard around actions you already wrote, and nothing took one back off.
#
#   WRAP   - a run of an event's actions moves inside a fresh sub-event guarded by a condition
#            you pick, in one undo step. What lands on the sheet is ordinary rows in the right
#            lanes: a condition row with those actions under it.
#   UNWRAP - the inverse: a guarded sub-event's contents are lifted into its parent and the
#            empty shell is dropped, so a guard added by reflex is removable by reflex.
#
# RUN ORDER IS THE WHOLE CONTRACT. The compiler emits an event's actions first and its
# sub-events afterwards, inside the same block. So:
#   • wrapping is only sound for a CONTIGUOUS TRAILING run of actions, and the fresh guard
#     must become the FIRST sub-event - then A1..Aj, [if cond: Aj+1..Ak], S1..Sn reads in
#     exactly the order the flat row did. Anything else silently reorders the program, so it
#     is refused with the reason rather than performed;
#   • unwrapping the FIRST sub-event appends its actions to the parent's (same position in the
#     run); a later sub-event's actions travel in a CONDITION-LESS carrier row, which the
#     compiler emits as plain statements at the same indent - byte-identical output.
#
# Both halves are pure statics over a passed sheet/rows, so the suite drives them headlessly;
# the dock-side flow (picker, undo funnel, status) lives in dock/refactor_menu.gd.


## The refusal reason for wrapping `actions` out of `event`, or "" when the wrap is sound.
## Every refusal is about RUN ORDER or about there being nothing to wrap - never a preference.
static func wrap_refusal(event: EventRow, actions: Array) -> String:
	if event == null:
		return "Right-click an event (or a run of its actions) to wrap it in a condition."
	if actions.is_empty():
		return "That event has no actions to wrap."
	var indices: Array = _action_indices(event, actions)
	if indices.size() != actions.size():
		return "Some of those actions no longer belong to this event - re-select and try again."
	for cursor: int in range(1, indices.size()):
		if int(indices[cursor]) != int(indices[cursor - 1]) + 1:
			return "Can't wrap a gapped selection - the kept action in the middle would change run order. Select a contiguous run."
	if int(indices[indices.size() - 1]) != event.actions.size() - 1:
		return "Wrap takes the LAST run of actions (a guard runs after the actions above it). Select through the final action, or wrap them all."
	return ""


## Moves `actions` out of `event` and into `guard`, then makes `guard` the event's FIRST
## sub-event. Returns how many actions moved (0 = refused, see wrap_refusal). `guard` is a
## fresh EventRow already carrying the picked condition - built by the dock's apply funnel,
## so wrap never has a second condition-building path of its own.
static func wrap_actions_into(event: EventRow, actions: Array, guard: EventRow) -> int:
	if guard == null or not wrap_refusal(event, actions).is_empty():
		return 0
	var ordered: Array = []
	for action: Variant in event.actions:
		if actions.has(action) and action is Resource:
			ordered.append(action)
	for action: Variant in ordered:
		event.actions.erase(action)
		guard.actions.append(action as Resource)
	# The guard runs after the actions that stayed and BEFORE any sub-event that was already
	# there, which is exactly index 0 of the sub-event list.
	if event.sub_events.has(guard):
		event.sub_events.erase(guard)
	event.sub_events.insert(0, guard)
	return ordered.size()


## The parent EventRow whose sub_events hold `event`, or null when it is top-level (or lives
## in a group). Walks the whole row tree, groups included.
static func parent_of(rows: Array, event: EventRow) -> EventRow:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			var found_in_group: EventRow = parent_of(group.events if not group.events.is_empty() else group.rows, event)
			if found_in_group != null:
				return found_in_group
			continue
		if not (entry is EventRow):
			continue
		var candidate: EventRow = entry as EventRow
		if candidate.sub_events.has(event):
			return candidate
		var found: EventRow = parent_of(candidate.sub_events, event)
		if found != null:
			return found
	return null


## The refusal reason for unwrapping `event`, or "" when it can be lifted. The refusals name
## the thing that would be LOST or reordered, so the message is also the fix.
static func unwrap_refusal(sheet: EventSheetResource, event: EventRow) -> String:
	if sheet == null or event == null:
		return "Right-click a sub-event to unwrap it."
	var parent: EventRow = parent_of(sheet.events, event)
	if parent == null:
		return "Unwrap lifts a sub-event's rows into the event above it - this row is already top-level."
	if event.trigger != null or not event.trigger_id.strip_edges().is_empty():
		return "This sub-event has a trigger of its own - lifting it would drop what fires it."
	if event.else_mode != EventRow.ElseMode.NONE:
		return "An Else / Else-If belongs to the event above it - clear the Else first, then unwrap."
	if not event.pick_filters.is_empty():
		return "This sub-event is a loop (For Each) - lifting its rows out would run them once instead of per item."
	var index: int = parent.sub_events.find(event)
	if index >= 0 and index + 1 < parent.sub_events.size():
		var next_sibling: Variant = parent.sub_events[index + 1]
		if next_sibling is EventRow and (next_sibling as EventRow).else_mode != EventRow.ElseMode.NONE:
			return "The sub-event below is this one's Else - clear that Else first, then unwrap."
	return ""


## Lifts `event`'s actions and sub-events into its parent and drops the empty shell. Returns
## the number of rows + actions lifted, or -1 when refused (see unwrap_refusal).
##
## The FIRST sub-event's actions append straight to the parent's own actions - the same
## position in the run they occupied inside the guard. A later one's actions travel in a
## condition-less carrier EventRow, which the compiler emits as plain statements at the same
## indent, so the generated GDScript is unchanged either way.
static func unwrap_event(sheet: EventSheetResource, event: EventRow) -> int:
	if not unwrap_refusal(sheet, event).is_empty():
		return -1
	var parent: EventRow = parent_of(sheet.events, event)
	var index: int = parent.sub_events.find(event)
	if index < 0:
		return -1
	var lifted: int = event.actions.size()
	var replacements: Array[Resource] = []
	if not event.actions.is_empty():
		# The straight append is only sound when the guard carried nothing BUT its condition. A
		# disabled guard's actions are code the author switched off (the compiler skips a disabled
		# row entirely), and a `With node` guard retargets every {target.} action it holds - merging
		# either one into the parent would change what the sheet does, so those travel in a carrier
		# exactly the way a later sibling's do.
		if index == 0 and event.enabled and event.with_node_target.strip_edges().is_empty():
			for action: Variant in event.actions:
				parent.actions.append(action as Resource)
			# Anything the guard declared for those actions travels with them.
			for local: LocalVariable in event.local_variables:
				parent.local_variables.append(local)
		else:
			var carrier: EventRow = EventRow.new()
			carrier.enabled = event.enabled
			carrier.comment = event.comment
			carrier.with_node_target = event.with_node_target
			carrier.local_variables = event.local_variables.duplicate()
			for action: Variant in event.actions:
				carrier.actions.append(action as Resource)
			replacements.append(carrier)
	for child: Variant in event.sub_events:
		if child is Resource:
			replacements.append(child as Resource)
			lifted += 1
	parent.sub_events.remove_at(index)
	for offset: int in range(replacements.size()):
		parent.sub_events.insert(index + offset, replacements[offset])
	return lifted


## The indices of `actions` inside `event.actions`, ascending. Only entries that really belong
## to the event are reported, so a stale selection is caught by the caller's size comparison.
static func _action_indices(event: EventRow, actions: Array) -> Array:
	var indices: Array = []
	for action_index: int in range(event.actions.size()):
		if actions.has(event.actions[action_index]):
			indices.append(action_index)
	return indices
