@tool
class_name EventSheetRowEditOps
extends RefCounted
# The CONTEXT-DRIVEN ROW / ACE EDIT-OPS subsystem. This helper owns the operations that MUTATE
# rows and ACEs in response to the right-click context menu and the multi-selection: enable/disable
# (per-ACE, per-row, whole-selection), delete (ACE spans, rows, selection), indent / outdent, Else /
# Else-If chaining, sub-event + row insertion, group fold, and the condition-block toggle (invert a
# single condition, or flip the whole event between AND and OR). It also carries the bulk-selection
# trio (disable/enable, duplicate, group) invoked from the toolbar's bulk actions.
#
# Extracted from event_sheet_dock.gd to keep that file maintainable. What DELIBERATELY stayed on the
# dock: the DISPATCHERS (`_on_condition_context_menu_id_pressed`, `_on_action_context_menu_id_pressed`,
# `_on_row_context_menu_id_pressed`, `_on_empty_space_context_menu_id_pressed`) - context_menus.gd
# wires those by name and the tests call them - and the shared context STATE `_context_row` /
# `_context_hit`, which `_on_viewport_context_menu_requested` writes and many callers (context_menus.gd,
# variables_manager.gd, ~15 test sites) read via `dock._context_row`. The ops here READ that state as
# `_dock._context_row` / `_dock._context_hit`.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`): the mutation funnel
# (`_perform_undoable_sheet_edit`, `_mark_dirty`, `_set_status`, `_refresh_after_edit`), the active
# state/view accessors (`_current_sheet`, `_viewport`, `_active_view`), the resource locators
# (`_find_resource_location`, `_group_children_array` - both live on ace_apply.gd with dock delegates,
# so call them as `_dock.`), the selection collectors (`_get_selected_rows_from_context`,
# `_get_selected_event_rows_from_context`), the OR-mode probe `_event_rows_use_or_mode`, the descendant
# check `_resource_contains_descendant`, `_ensure_sheet_for_editing`, the insert helper
# `_insert_row_below_selection`, the picker (`_ace_picker`) + comment dialog (`_open_ace_comment_dialog`),
# and CRUCIALLY `_refresh_clone_uids` (the duplicate op's lambda calls `_dock._refresh_clone_uids`).
#
# The dock keeps thin one-line delegates (original names + signatures, incl. return types) for every op
# reached from outside this helper - the dispatchers above, context_menus.gd
# (`_context_ace_is_disabled` / `_context_row_is_disabled` / `_context_condition_is_negated`),
# multi_view_manager.gd (`_delete_selected_content`), and the tests (`_toggle_selected_enabled`,
# `_indent_selected_event`, `_outdent_selected_event`, `_bulk_*`, `_delete_context_ace`,
# `_insert_child_comment_for_context_row`). Ops called ONLY by other ops here need no delegate.
#
# CLOSURE NOTE: several ops hand a lambda to `_dock._perform_undoable_sheet_edit(...)`. Those lambdas
# capture `self`, which is now THIS helper - so every dock STATE / STAY reference inside them is written
# `_dock.` while calls to methods that live here stay bare. In particular FOUR ops read `_context_row`
# INSIDE the lambda and MUST prefix it: `_toggle_context_row_enabled`,
# `_insert_child_event_for_context_row`, `_insert_child_comment_for_context_row`,
# `_insert_context_row_below`. `_bulk_duplicate_rows`'s lambda calls `_dock._refresh_clone_uids` +
# `_dock._find_resource_location`, and `_delete_selected_rows`'s lambda calls `_dock._find_resource_location`
# (with bare `_resource_sort_key` / `_delete_context_row`, which live here).

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

# ── Bulk operations on the multi-selection (one undo action each) ─────────────────────


## Disables every selected row that can be disabled - or re-enables them all when the
## first one is already off (uniform result, never a mixed toggle).
func _bulk_set_enabled_on(targets: Array) -> void:
	var rows: Array = targets.filter(func(resource: Variant) -> bool:
		return resource is EventRow or resource is EventGroup)
	if rows.is_empty():
		_dock._set_status("Select event or group rows to disable/enable.", true)
		return
	var make_enabled: bool = not bool(rows[0].get("enabled"))
	var changed: bool = _dock._perform_undoable_sheet_edit("Toggle Selection", func() -> bool:
		for row: Variant in rows:
			(row as Resource).set("enabled", make_enabled)
		return true)
	if changed:
		_dock._mark_dirty("%s %d row(s)." % ["Enabled" if make_enabled else "Disabled", rows.size()])


## Duplicates every selected row in place (each copy lands right under its source,
## event uids re-baked so stateful conditions never share accumulators).
func _bulk_duplicate_rows(targets: Array) -> void:
	if targets.is_empty():
		_dock._set_status("Nothing selected to duplicate.", true)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Duplicate Selection", func() -> bool:
		var any: bool = false
		for resource: Variant in targets:
			var location: Dictionary = _dock._find_resource_location(resource)
			if location.is_empty():
				continue
			var copy: Resource = (resource as Resource).duplicate(true)
			_dock._refresh_clone_uids(copy)
			(location.get("container") as Array).insert(int(location.get("index")) + 1, copy)
			any = true
		return any)
	if changed:
		_dock._mark_dirty("Duplicated %d row(s)." % targets.size())


## Wraps a same-parent selection in a fresh group (selection order preserved).
## Returns "" or the user-facing problem - mixed-parent selections are refused
## because silent cross-depth reparenting is how sheets get scrambled.
func _bulk_group_rows(targets: Array) -> String:
	if targets.is_empty():
		return "Nothing selected to group."
	var first_location: Dictionary = _dock._find_resource_location(targets[0])
	if first_location.is_empty():
		return "Couldn't locate the selection."
	var container: Array = first_location.get("container")
	for resource: Variant in targets:
		var location: Dictionary = _dock._find_resource_location(resource)
		# is_same: Array == compares CONTENTS; the parent rail needs identity.
		if location.is_empty() or not is_same(location.get("container"), container):
			return "Group Selection needs rows with the same parent."
	var ordered: Array = targets.duplicate()
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool:
		return container.find(a) < container.find(b))
	var changed: bool = _dock._perform_undoable_sheet_edit("Group Selection", func() -> bool:
		var group: EventGroup = EventGroup.new()
		group.group_name = "Group"
		var insert_at: int = container.find(ordered[0])
		for resource: Variant in ordered:
			container.erase(resource)
			group.events.append(resource)
		container.insert(mini(insert_at, container.size()), group)
		return true)
	if changed:
		_dock._mark_dirty("Grouped %d row(s)." % ordered.size())
	return ""

# ── Context-menu ACE edit ops (the right-clicked condition/action/trigger) ─────────────


func _delete_context_ace() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		return
	var event_row: EventRow = _dock._context_row.source_resource as EventRow
	var metadata: Dictionary = _dock._context_hit.get("span_metadata", {})
	var ace_index: int = int(metadata.get("ace_index", -1))
	var kind: String = str(metadata.get("kind", ""))
	var deleted: bool = _dock._perform_undoable_sheet_edit("Delete Cell", func() -> bool:
		match kind:
			"trigger":
				if event_row.trigger != null:
					event_row.trigger = null
					return true
			"condition":
				if ace_index >= 0 and ace_index < event_row.conditions.size():
					event_row.conditions.remove_at(ace_index)
					return true
			"action":
				if ace_index >= 0 and ace_index < event_row.actions.size():
					event_row.actions.remove_at(ace_index)
					return true
		return false
	)
	if deleted:
		_dock._mark_dirty("Deleted the cell.")


func _toggle_context_condition_inversion() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		return
	var event_row: EventRow = _dock._context_row.source_resource as EventRow
	var metadata: Dictionary = _dock._context_hit.get("span_metadata", {})
	var kind: String = str(metadata.get("kind", ""))
	var ace_index: int = int(metadata.get("ace_index", -1))
	var toggled: bool = _dock._perform_undoable_sheet_edit("Invert Condition", func() -> bool:
		# Only regular conditions invert (compiled as `not (…)`). A trigger has no "not On X", and the
		# compiler never reads trigger.negated - toggling it was a SILENT no-op that left a misleading
		# "inverted" trigger on the sheet. The menu disables Invert for triggers; this guards the path too.
		if kind == "condition" and ace_index >= 0 and ace_index < event_row.conditions.size():
			event_row.conditions[ace_index].negated = not event_row.conditions[ace_index].negated
			return true
		return false
	)
	if toggled:
		_dock._mark_dirty("Updated condition inversion.")


## The ACE resource the context menu was opened on (condition/trigger/action lanes).
func _context_ace_resource(lane: String) -> Resource:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		return null
	var event_row: EventRow = _dock._context_row.source_resource as EventRow
	var metadata: Dictionary = _dock._context_hit.get("span_metadata", {})
	var ace_index: int = int(metadata.get("ace_index", -1))
	if lane == "condition":
		if str(metadata.get("kind", "")) == "trigger":
			return event_row.trigger
		return event_row.conditions[ace_index] if ace_index >= 0 and ace_index < event_row.conditions.size() else null
	return event_row.actions[ace_index] if ace_index >= 0 and ace_index < event_row.actions.size() else null


func _context_ace_is_disabled() -> bool:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		return false
	var event_row: EventRow = _dock._context_row.source_resource as EventRow
	var metadata: Dictionary = _dock._context_hit.get("span_metadata", {})
	var kind: String = str(metadata.get("kind", ""))
	var ace_index: int = int(metadata.get("ace_index", -1))
	match kind:
		"trigger":
			return event_row.trigger != null and not event_row.trigger.enabled
		"condition":
			return ace_index >= 0 and ace_index < event_row.conditions.size() and not event_row.conditions[ace_index].enabled
		"action":
			return ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction and not ((event_row.actions[ace_index] as ACEAction).enabled)
	return false


func _toggle_context_ace_enabled() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		return
	var event_row: EventRow = _dock._context_row.source_resource as EventRow
	var metadata: Dictionary = _dock._context_hit.get("span_metadata", {})
	var kind: String = str(metadata.get("kind", ""))
	var ace_index: int = int(metadata.get("ace_index", -1))
	var changed: bool = _dock._perform_undoable_sheet_edit("Toggle Cell Enabled", func() -> bool:
		match kind:
			"trigger":
				if event_row.trigger != null:
					event_row.trigger.enabled = not event_row.trigger.enabled
					return true
			"condition":
				if ace_index >= 0 and ace_index < event_row.conditions.size():
					event_row.conditions[ace_index].enabled = not event_row.conditions[ace_index].enabled
					return true
			"action":
				if ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction:
					var target_action: ACEAction = event_row.actions[ace_index] as ACEAction
					target_action.enabled = not target_action.enabled
					return true
		return false
	)
	if changed:
		_dock._mark_dirty("Cell enabled state updated.")


## Disables (or re-enables) everything currently selected at once: individual conditions /
## actions when ACE spans are selected, otherwise the selected rows (events/groups/comments).
## If anything in the selection is enabled it disables the whole lot; otherwise it enables it.
func _toggle_selected_enabled() -> void:
	if _dock._viewport == null:
		return
	var span_targets: Array = _dock._active_view().get_selected_span_targets()
	var row_targets: Array[EventRowData] = []
	if span_targets.is_empty():
		row_targets = _dock._get_selected_rows_from_context()
	if span_targets.is_empty() and row_targets.is_empty():
		return
	var any_enabled: bool = false
	for target in span_targets:
		if _ace_target_enabled(target):
			any_enabled = true
			break
	if not any_enabled:
		for row_data in row_targets:
			if _row_data_resource_enabled(row_data):
				any_enabled = true
				break
	var new_enabled: bool = not any_enabled
	var changed: bool = _dock._perform_undoable_sheet_edit("Toggle Enabled", func() -> bool:
		var did_change: bool = false
		for target in span_targets:
			if _set_ace_target_enabled(target, new_enabled):
				did_change = true
		for row_data in row_targets:
			if _set_row_data_resource_enabled(row_data, new_enabled):
				did_change = true
		return did_change
	)
	if changed:
		_dock._mark_dirty("%s selection." % ("Enabled" if new_enabled else "Disabled"))


func _ace_target_enabled(target: Dictionary) -> bool:
	var event_row: EventRow = target.get("source_resource", null) as EventRow
	if event_row == null:
		return true
	var ace_index: int = int(target.get("ace_index", -1))
	match str(target.get("kind", "")):
		"trigger":
			return event_row.trigger == null or event_row.trigger.enabled
		"condition":
			return ace_index < 0 or ace_index >= event_row.conditions.size() or event_row.conditions[ace_index].enabled
		"action":
			return ace_index < 0 or ace_index >= event_row.actions.size() or not (event_row.actions[ace_index] is ACEAction) or (event_row.actions[ace_index] as ACEAction).enabled
	return true


func _set_ace_target_enabled(target: Dictionary, enabled: bool) -> bool:
	var event_row: EventRow = target.get("source_resource", null) as EventRow
	if event_row == null:
		return false
	var ace_index: int = int(target.get("ace_index", -1))
	match str(target.get("kind", "")):
		"trigger":
			if event_row.trigger != null:
				event_row.trigger.enabled = enabled
				return true
		"condition":
			if ace_index >= 0 and ace_index < event_row.conditions.size():
				event_row.conditions[ace_index].enabled = enabled
				return true
		"action":
			if ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction:
				(event_row.actions[ace_index] as ACEAction).enabled = enabled
				return true
	return false


func _row_data_resource_enabled(row_data: EventRowData) -> bool:
	if row_data == null or row_data.source_resource == null:
		return true
	var resource: Resource = row_data.source_resource
	if resource is EventRow:
		return (resource as EventRow).enabled
	if resource is EventGroup:
		return (resource as EventGroup).enabled
	if resource is CommentRow:
		return (resource as CommentRow).enabled
	return true


func _set_row_data_resource_enabled(row_data: EventRowData, enabled: bool) -> bool:
	if row_data == null or row_data.source_resource == null:
		return false
	var resource: Resource = row_data.source_resource
	if resource is EventRow:
		(resource as EventRow).enabled = enabled
		return true
	if resource is EventGroup:
		(resource as EventGroup).enabled = enabled
		return true
	if resource is CommentRow:
		(resource as CommentRow).enabled = enabled
		return true
	return false


func _context_row_is_disabled() -> bool:
	if _dock._context_row == null or _dock._context_row.source_resource == null:
		return false
	if _dock._context_row.source_resource is EventRow:
		return not (_dock._context_row.source_resource as EventRow).enabled
	if _dock._context_row.source_resource is EventGroup:
		return not (_dock._context_row.source_resource as EventGroup).enabled
	if _dock._context_row.source_resource is CommentRow:
		return not (_dock._context_row.source_resource as CommentRow).enabled
	return false


func _toggle_context_row_enabled() -> void:
	if _dock._context_row == null or _dock._context_row.source_resource == null:
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Toggle Row Enabled", func() -> bool:
		if _dock._context_row.source_resource is EventRow:
			var event_row: EventRow = _dock._context_row.source_resource as EventRow
			event_row.enabled = not event_row.enabled
			return true
		if _dock._context_row.source_resource is EventGroup:
			var group: EventGroup = _dock._context_row.source_resource as EventGroup
			group.enabled = not group.enabled
			return true
		if _dock._context_row.source_resource is CommentRow:
			var comment_row: CommentRow = _dock._context_row.source_resource as CommentRow
			comment_row.enabled = not comment_row.enabled
			return true
		return false
	)
	if changed:
		_dock._mark_dirty("Updated row enabled state.")


func _toggle_context_condition_block() -> void:
	var selected_events: Array[EventRow] = _dock._get_selected_event_rows_from_context()
	if selected_events.is_empty():
		return
	var target_mode: int = (
		EventRow.ConditionMode.AND
		if _dock._event_rows_use_or_mode(selected_events)
		else EventRow.ConditionMode.OR
	)
	var toggled: bool = _dock._perform_undoable_sheet_edit("Toggle Condition Block", func() -> bool:
		for event_row in selected_events:
			event_row.condition_mode = target_mode
		return true
	)
	if toggled:
		_dock._mark_dirty("Updated condition block.")


## Sets (or toggles off) Else / Else-If chaining on the selected events. They compile to
## `else:` / `elif:` chained onto the previous sibling's `if` (sheet_compiler ~873) and the
## viewport prefixes them with "Else"/"Else if". Clicking the active mode again clears it.
func _set_context_else_mode(mode: int) -> void:
	var selected_events: Array[EventRow] = _dock._get_selected_event_rows_from_context()
	if selected_events.is_empty():
		return
	var all_already: bool = true
	for event_row in selected_events:
		if event_row.else_mode != mode:
			all_already = false
			break
	var target_mode: int = EventRow.ElseMode.NONE if all_already else mode
	var changed: bool = _dock._perform_undoable_sheet_edit("Set Else Mode", func() -> bool:
		for event_row in selected_events:
			event_row.else_mode = target_mode
		return true
	)
	if changed:
		_dock._mark_dirty("Updated Else mode.")


func _toggle_context_group_fold() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventGroup):
		return
	var context_group: EventGroup = _dock._context_row.source_resource as EventGroup
	context_group.set_collapsed_state(not context_group.is_collapsed())
	_dock._viewport.toggle_row_fold_by_uid(_dock._context_row.row_uid)
	_dock._mark_dirty("Updated group fold state.")


func _delete_context_row() -> void:
	if _dock._context_row == null or _dock._context_row.source_resource == null:
		return
	var target_resource: Resource = _dock._context_row.source_resource
	var location: Dictionary = _dock._find_resource_location(target_resource)
	if location.is_empty():
		return
	var container: Array = location.get("container", [])
	var index: int = int(location.get("index", -1))
	if index < 0 or index >= container.size():
		return
	var deleted: bool = _dock._perform_undoable_sheet_edit("Delete Row", func() -> bool:
		container.remove_at(index)
		return true
	)
	if deleted:
		_dock._mark_dirty("Deleted row.")


func _delete_selected_content() -> void:
	if _delete_selected_spans():
		return
	_delete_selected_rows()


func _delete_selected_spans() -> bool:
	if _dock._viewport == null:
		return false
	var selected_targets: Array = _dock._active_view().get_selected_span_targets()
	if selected_targets.is_empty():
		return false
	var deleted: bool = _dock._perform_undoable_sheet_edit("Delete Cell", func() -> bool:
		var targets_by_row: Dictionary = {}
		for target in selected_targets:
			if not (target is Dictionary):
				continue
			var target_dict: Dictionary = target as Dictionary
			var row_uid: String = str(target_dict.get("row_uid", ""))
			if row_uid.is_empty():
				continue
			if not targets_by_row.has(row_uid):
				targets_by_row[row_uid] = []
			(targets_by_row[row_uid] as Array).append(target_dict)
		for row_targets in targets_by_row.values():
			var targets_for_row: Array = row_targets as Array
			targets_for_row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("ace_index", -1)) > int(b.get("ace_index", -1))
			)
			for target_dict in targets_for_row:
				var event_row: EventRow = target_dict.get("source_resource", null) as EventRow
				if event_row == null:
					continue
				var kind: String = str(target_dict.get("kind", ""))
				var ace_index: int = int(target_dict.get("ace_index", -1))
				match kind:
					"trigger":
						if event_row.trigger != null:
							event_row.trigger = null
					"condition":
						if ace_index >= 0 and ace_index < event_row.conditions.size():
							event_row.conditions.remove_at(ace_index)
					"action":
						if ace_index >= 0 and ace_index < event_row.actions.size():
							event_row.actions.remove_at(ace_index)
		return true
	)
	if not deleted:
		return false
	_dock._viewport.clear_selection()
	_dock._mark_dirty("Deleted the cell.")
	return true


func _delete_selected_rows() -> void:
	var selected_rows: Array[EventRowData] = _dock._get_selected_rows_from_context()
	if selected_rows.is_empty():
		_delete_context_row()
		return
	var resources_to_delete: Array[Resource] = []
	for row_data in selected_rows:
		var source_resource: Resource = row_data.source_resource if row_data != null else null
		if source_resource == null:
			continue
		var covered_by_parent: bool = false
		for existing_resource in resources_to_delete:
			if _dock._resource_contains_descendant(existing_resource, source_resource):
				covered_by_parent = true
				break
		if covered_by_parent:
			continue
		var filtered_resources: Array[Resource] = []
		for existing_resource in resources_to_delete:
			if not _dock._resource_contains_descendant(source_resource, existing_resource):
				filtered_resources.append(existing_resource)
		resources_to_delete = filtered_resources
		resources_to_delete.append(source_resource)
	if resources_to_delete.is_empty():
		return
	var deleted: bool = _dock._perform_undoable_sheet_edit("Delete Row", func() -> bool:
		resources_to_delete.sort_custom(func(a: Resource, b: Resource) -> bool:
			return _resource_sort_key(a) > _resource_sort_key(b)
		)
		for resource_entry in resources_to_delete:
			var location: Dictionary = _dock._find_resource_location(resource_entry)
			if location.is_empty():
				continue
			var container: Array = location.get("container", [])
			var index: int = int(location.get("index", -1))
			if index >= 0 and index < container.size():
				container.remove_at(index)
		return true
	)
	if deleted:
		_dock._viewport.clear_selection()
		_dock._mark_dirty("Deleted row.")


func _insert_child_event_for_context_row() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Add Sub Event", func() -> bool:
		(_dock._context_row.source_resource as EventRow).sub_events.append(EventRow.new())
		return true
	)
	if changed:
		_dock._mark_dirty("Added sub-event.")


## Nests a comment inside the right-clicked event (as a sub-event), so it can describe the
## events beneath it. Comments are the one non-event row allowed as a sub-event.
func _insert_child_comment_for_context_row() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		_dock._set_status("Add a comment sub-event from an event row.", true)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Add Comment Sub-Event", func() -> bool:
		var comment: CommentRow = CommentRow.new()
		comment.text = "Comment"
		(_dock._context_row.source_resource as EventRow).sub_events.append(comment)
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Added comment sub-event.")


func _open_sub_condition_picker_for_context_row() -> void:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		return
	_dock._ace_picker.open("new_sub_condition_event", false, _dock._context_row.source_resource)


## The currently selected EventRow resource, or null when the selection is not an event.
func _selected_event_resource() -> EventRow:
	if _dock._viewport == null:
		return null
	var resource: Variant = _dock._active_view().get_selected_context().get("source_resource", null)
	return resource as EventRow if resource is EventRow else null


## Nests the selected event under the event directly above it (its preceding sibling),
## moving it into that event's sub_events. Returns true when the move happened.
func _indent_selected_event() -> bool:
	if not _dock._ensure_sheet_for_editing():
		return false
	var target: EventRow = _selected_event_resource()
	if target == null:
		return false
	var location: Dictionary = _dock._find_resource_location(target)
	var container: Array = location.get("container", [])
	var index: int = int(location.get("index", -1))
	if index <= 0:
		_dock._set_status("Nothing above to nest this event under.", true)
		return false
	var previous: Variant = container[index - 1]
	if not (previous is EventRow):
		_dock._set_status("Events can only be nested under another event.", true)
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit("Indent Event", func() -> bool:
		container.remove_at(index)
		(previous as EventRow).sub_events.append(target)
		return true
	)
	if changed:
		_dock._mark_dirty("Nested event under the one above.")
	return changed


## Un-nests the selected sub-event, moving it out to its parent's container just after the
## parent. Returns true when the move happened.
func _outdent_selected_event() -> bool:
	if not _dock._ensure_sheet_for_editing():
		return false
	var target: EventRow = _selected_event_resource()
	if target == null:
		return false
	var parent_info: Dictionary = _find_parent_event(target)
	var parent: Variant = parent_info.get("parent", null)
	if not bool(parent_info.get("found", false)) or not (parent is EventRow):
		_dock._set_status("Event is already at the top level.", true)
		return false
	var parent_event: EventRow = parent as EventRow
	var parent_location: Dictionary = _dock._find_resource_location(parent_event)
	var parent_container: Array = parent_location.get("container", [])
	var parent_index: int = int(parent_location.get("index", -1))
	if parent_index < 0:
		return false
	var changed: bool = _dock._perform_undoable_sheet_edit("Outdent Event", func() -> bool:
		parent_event.sub_events.erase(target)
		parent_container.insert(parent_index + 1, target)
		return true
	)
	if changed:
		_dock._mark_dirty("Un-nested event to the parent level.")
	return changed


## Finds the EventRow whose sub_events directly contains target.
## Returns {found: bool, parent: EventRow|null} (parent is null at root/group level).
func _find_parent_event(target: Resource) -> Dictionary:
	if _dock._current_sheet == null:
		return {"found": false, "parent": null}
	return _find_parent_event_recursive(target, _dock._current_sheet.events, null)


func _find_parent_event_recursive(target: Resource, container: Array, parent: EventRow) -> Dictionary:
	for entry in container:
		if entry == target:
			return {"found": true, "parent": parent}
		if entry is EventGroup:
			var grouped: Dictionary = _find_parent_event_recursive(target, _dock._group_children_array(entry as EventGroup), null)
			if bool(grouped.get("found", false)):
				return grouped
		elif entry is EventRow:
			var nested: Dictionary = _find_parent_event_recursive(target, (entry as EventRow).sub_events, entry as EventRow)
			if bool(nested.get("found", false)):
				return nested
	return {"found": false, "parent": null}


func _insert_context_row_below(resource_entry: Resource, message: String) -> void:
	if resource_entry == null or _dock._context_row == null:
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Insert Row", func() -> bool:
		_dock._insert_row_below_selection(resource_entry, _dock._context_row.source_resource)
		return true
	)
	if changed:
		_dock._mark_dirty(message)


func _insert_context_row_above(resource_entry: Resource, message: String) -> void:
	if resource_entry == null or _dock._context_row == null:
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Insert Row", func() -> bool:
		_dock._insert_row_above_selection(resource_entry, _dock._context_row.source_resource)
		return true
	)
	if changed:
		_dock._mark_dirty(message)

# ── Support helpers (used only by the ops above + context_menus.gd) ───────────────────


func _resource_sort_key(resource_entry: Resource) -> int:
	return _find_row_index_for_resource(resource_entry)


func _find_row_index_for_resource(resource_entry: Resource) -> int:
	if _dock._viewport == null or resource_entry == null:
		return -1
	var flat_rows: Array[Dictionary] = _dock._viewport.get_flat_rows()
	for index in range(flat_rows.size()):
		var row_data: EventRowData = flat_rows[index].get("row")
		if row_data != null and row_data.source_resource == resource_entry:
			return index
	return -1


func _context_condition_is_negated() -> bool:
	if _dock._context_row == null or not (_dock._context_row.source_resource is EventRow):
		return false
	var event_row: EventRow = _dock._context_row.source_resource as EventRow
	var metadata: Dictionary = _dock._context_hit.get("span_metadata", {})
	var kind: String = str(metadata.get("kind", ""))
	var ace_index: int = int(metadata.get("ace_index", -1))
	if kind == "trigger" and event_row.trigger != null:
		return event_row.trigger.negated
	if kind == "condition" and ace_index >= 0 and ace_index < event_row.conditions.size():
		return event_row.conditions[ace_index].negated
	return false
