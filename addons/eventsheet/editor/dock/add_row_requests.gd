@tool
class_name EventSheetAddRowRequests
extends RefCounted
# The dock's ADD-ROW request handlers, extracted from event_sheet_dock.gd: the
# toolbar/menu entry points that append events, signal events, conditions,
# actions, comments, and groups, plus duplicate-selection (with fresh event
# uids) and the group rename/edit prompts. Each is thin glue into the undo
# funnel; bodies moved verbatim behind the `_dock.` back-reference.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


func on_add_event_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_dock._ace_picker.open("new_event", false, _dock._active_view().get_selected_context().get("source_resource", null))


func on_add_signal_event_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	_dock._ace_picker.open("new_event", true, _dock._active_view().get_selected_context().get("source_resource", null))


func on_add_condition_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	var selected_resource: Resource = _dock._active_view().get_selected_context().get("source_resource", null)
	if selected_resource is EventRow:
		_dock._ace_picker.open("append_condition", false, selected_resource)
		return
	_dock._ace_picker.open("new_condition_event", false, selected_resource)


func on_add_action_requested() -> void:
	if not _dock._ensure_selected_event():
		return
	_dock._ace_picker.open("append_action", false, _dock._active_view().get_selected_context().get("source_resource", null))


func on_add_comment_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	var comment: CommentRow = CommentRow.new()
	comment.text = "Comment"
	var changed: bool = _dock._perform_undoable_sheet_edit("Add Comment", func() -> bool:
		_dock._insert_row_below_selection(comment)
		return true
	)
	if changed:
		_dock._mark_dirty("Added comment.")


func on_add_group_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	var group: EventGroup = EventGroup.new()
	group.name = "Group"
	group.group_name = group.name
	var changed: bool = _dock._perform_undoable_sheet_edit("Add Group", func() -> bool:
		_dock._insert_row_below_selection(group)
		return true
	)
	if changed:
		_dock._mark_dirty("Added group.")
		# Drop straight into renaming the new group so naming it is obvious and immediate —
		# the same inline title edit you'd reach by double-clicking it or pressing Enter,
		# just triggered for you. Deferred so it runs after the viewport rebuilds.
		call_deferred("_begin_group_rename", group)


## Selects a group and opens its editor popup (used right after Add Group so the user can name it
## immediately, and on double-click / slow-click / Enter of an existing group header).
func begin_group_rename(group: EventGroup) -> void:
	var view: EventSheetViewport = _dock._active_view()
	if view != null:
		view.select_resource(group)
	_dock._on_group_edit_requested(group)


# Group editor popup → dock/quick_prompt_dialogs.gd; delegates keep signal wiring + tests stable.
func on_group_edit_requested(group: EventGroup) -> void:
	_dock._quick_prompts.on_group_edit_requested(group)


func apply_group_edit(group: EventGroup, new_name: String, new_desc: String) -> bool:
	return _dock._quick_prompts.apply_group_edit(group, new_name, new_desc)


func on_duplicate_requested() -> void:
	if not _dock._ensure_sheet_for_editing():
		return
	var selected_resource: Resource = _dock._active_view().get_selected_context().get("source_resource", null)
	if not (selected_resource is EventRow):
		_dock._set_status("Select an event row to duplicate.", true)
		return
	var clone: EventRow = (selected_resource as EventRow).duplicate(true)
	_dock._assign_fresh_event_uids(clone)
	var changed: bool = _dock._perform_undoable_sheet_edit("Duplicate Event", func() -> bool:
		_dock._insert_row_below_selection(clone, selected_resource)
		return true
	)
	if changed:
		_dock._mark_dirty("Duplicated event.")


## Recursively assigns fresh event UIDs to a cloned event row and its sub-events so the
## duplicate does not share selection/fold identity with the source.
func assign_fresh_event_uids(row: EventRow) -> void:
	row.event_uid = EventRow._generate_short_uid()
	# Stateful conditions (Every X Seconds…): the COPY must own its own accumulator —
	# re-bake the member uid across all four baked fields, or both timers silently
	# share one member (copies are independent timers).
	for condition: Variant in row.conditions:
		if condition is ACECondition and not (condition as ACECondition).member_declaration.is_empty():
			var stateful: ACECondition = condition as ACECondition
			var uid_regex: RegEx = RegEx.new()
			uid_regex.compile("__[a-z_]+_([0-9a-f]{8})\\b")
			var uid_match: RegExMatch = uid_regex.search(stateful.member_declaration)
			if uid_match == null:
				continue
			var old_uid: String = uid_match.get_string(1)
			var new_uid: String = _dock._fresh_uid_token()
			stateful.member_declaration = stateful.member_declaration.replace(old_uid, new_uid)
			stateful.codegen_template = stateful.codegen_template.replace(old_uid, new_uid)
			stateful.codegen_prelude = stateful.codegen_prelude.replace(old_uid, new_uid)
			stateful.codegen_on_true = stateful.codegen_on_true.replace(old_uid, new_uid)
	# Multi-line action templates bake `__spawn_<uid>`/`__sfx_<uid>` locals — pasting the
	# same event twice into one trigger would declare the same local twice in one
	# function body. Re-bake every baked uid the template carries.
	for action: Variant in row.actions:
		if action is ACEAction and (action as ACEAction).codegen_template.contains("__"):
			var baked: ACEAction = action as ACEAction
			var action_uid_regex: RegEx = RegEx.new()
			action_uid_regex.compile("__[a-z_]+_([0-9a-f]{8})\\b")
			var seen_uids: Dictionary = {}
			for action_match: RegExMatch in action_uid_regex.search_all(baked.codegen_template):
				seen_uids[action_match.get_string(1)] = true
			for stale_uid: Variant in seen_uids.keys():
				baked.codegen_template = baked.codegen_template.replace(str(stale_uid), _dock._fresh_uid_token())
	for sub_event in row.sub_events:
		if sub_event is EventRow:
			_dock._assign_fresh_event_uids(sub_event as EventRow)
