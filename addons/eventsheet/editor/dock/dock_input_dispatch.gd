@tool
class_name EventSheetDockInputDispatch
extends RefCounted
# The dock's INPUT DISPATCH layer, extracted from event_sheet_dock.gd to keep that file
# maintainable. Three surfaces route user intent into the dock's edit operations here:
#
#   - the row context menu dispatcher (one match arm per ROW_MENU_* id, each a thin
#     call into the dock facade / its delegates),
#   - the workspace keyboard shortcuts (_unhandled_key_input: script-editor-style
#     bindings - save, find, palette, breakpoints, row ops...),
#   - "Surround with Region…" (wraps the selection in a fence pair as one undo step,
#     then opens the fence editor for naming).
#
# Menu CONSTRUCTION stays in dock/context_menus.gd and the operation BODIES stay in
# their delegates (row_edit_ops, author_actions, ...) - this layer is only the
# routing between them. Bodies moved VERBATIM with member access rewritten through
# the `_dock.` back-reference; the dock keeps one-line delegates (its
# _unhandled_key_input virtual must live on the Control) so no wiring changed.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


func on_row_context_menu_id_pressed(id: int) -> void:
	if _dock._context_row == null:
		return
	# Extension row-menu items (EventSheets.register_row_menu_item) occupy ids 900+.
	if id >= 900:
		var applicable: Array[Dictionary] = EventSheets.row_menu_items_for(_dock._context_row.source_resource)
		var extension_index: int = id - 900
		if extension_index < applicable.size():
			var action: Callable = applicable[extension_index].get("action", Callable())
			if action.is_valid():
				action.call(_dock._context_row.source_resource)
		return
	match id:
		_dock.ROW_MENU_ADD_SUB_EVENT:
			_dock._insert_child_event_for_context_row()
		_dock.ROW_MENU_ADD_COMMENT_SUB_EVENT:
			_dock._insert_child_comment_for_context_row()
		_dock.ROW_MENU_ADD_EVENT_BELOW:
			_dock._insert_context_row_below(EventRow.new(), "Added event.")
		_dock.ROW_MENU_ADD_EVENT_ABOVE:
			_dock._insert_context_row_above(EventRow.new(), "Added event above.")
		_dock.ROW_MENU_ADD_GROUP_BELOW:
			var group: EventGroup = EventGroup.new()
			group.name = "Group"
			group.group_name = group.name
			_dock._insert_context_row_below(group, "Added group.")
		_dock.ROW_MENU_ADD_COMMENT_BELOW:
			var comment: CommentRow = CommentRow.new()
			comment.text = "Comment"
			_dock._insert_context_row_below(comment, "Added comment.")
		_dock.ROW_MENU_ADD_VARIABLE_BELOW:
			_dock._add_tree_variable_below_context_row()
		_dock.ROW_MENU_ADD_GDSCRIPT_BELOW:
			var raw_block: RawCodeRow = RawCodeRow.new()
			raw_block.code = "# GDScript - emitted verbatim at class level"
			_dock._insert_context_row_below(raw_block, "Added GDScript block.")
		_dock.ROW_MENU_ADD_GDSCRIPT_ACTION:
			_dock._add_gdscript_action_to_context_row()
		_dock.ROW_MENU_COPY:
			_dock._on_copy_requested()
		_dock.ROW_MENU_CUT:
			_dock._cut_selected_rows()
		_dock.ROW_MENU_COPY_AS_TEXT:
			_dock._copy_selection_as_text()
		_dock.ROW_MENU_SURROUND_REGION:
			_dock._surround_selection_with_region()
		_dock.ROW_MENU_PASTE:
			_dock._on_paste_requested()
		_dock.ROW_MENU_DELETE:
			_dock._delete_selected_rows()
		_dock.ROW_MENU_TOGGLE_CONDITION_BLOCK:
			_dock._toggle_context_condition_block()
		_dock.ROW_MENU_TOGGLE_GROUP_FOLD:
			_dock._toggle_context_group_fold()
		_dock.ROW_MENU_ADD_SUB_CONDITION:
			_dock._open_sub_condition_picker_for_context_row()
		_dock.ROW_MENU_MAKE_ELSE:
			_dock._set_context_else_mode(EventRow.ElseMode.ELSE)
		_dock.ROW_MENU_MAKE_ELIF:
			_dock._set_context_else_mode(EventRow.ElseMode.ELIF)
		_dock.ROW_MENU_EXTRACT_GDSCRIPT_FN:
			_dock._extract_to_function_requested()
		_dock.ROW_MENU_BREAKPOINT_CONDITION:
			_dock._set_breakpoint_condition_requested()
		_dock.ROW_MENU_TOGGLE_ENABLED:
			_dock._toggle_context_row_enabled()
		_dock.ROW_MENU_EDIT_COMMENT:
			if _dock._context_row.source_resource is CommentRow:
				_dock._open_comment_dialog(_dock._context_row.source_resource)
			else:
				_dock._set_status("Select a comment row to edit it.", true)
		_dock.ROW_MENU_ATTACH_COMMENT:
			if _dock._context_row.source_resource is CommentRow:
				_dock._attach_comment_to_event_above(_dock._context_row.source_resource as CommentRow)
			else:
				_dock._set_status("Only comment rows can attach to an event.", true)
		_dock.ROW_MENU_EDIT_FUNCTION:
			if _dock._context_row != null and _dock._context_row.source_resource is EventFunction:
				_dock._function_dialog_glue._open_function_dialog_for(_dock._context_row.source_resource)
			else:
				_dock._set_status("Select a published verb row to edit it.", true)
		_dock.ROW_MENU_ADD_FUNCTION_PARAM:
			if _dock._context_row != null and _dock._context_row.source_resource is EventFunction:
				_dock._function_dialog_glue._open_function_dialog_add_param(_dock._context_row.source_resource)
			else:
				_dock._set_status("Select a published verb row to add a parameter to it.", true)
		_dock.ROW_MENU_MAKE_FUNCTION_EDITABLE:
			# Opt THIS opened-pack verb's body in/out of editing (editor state only - never dirties the .gd).
			if _dock._context_row != null and _dock._context_row.source_resource is EventFunction:
				var verb_name: String = (_dock._context_row.source_resource as EventFunction).function_name
				_dock._active_view().toggle_function_body_editable(verb_name)
				_dock._set_status("%s is now %s." % [verb_name, "editable" if _dock._active_view().is_function_body_editable_opt_in(verb_name) else "read-only"])
			else:
				_dock._set_status("Select a published verb row to change its body editability.", true)
		_dock.ROW_MENU_ADD_PICK_FILTER:
			_dock._open_pick_filter_dialog(_dock._context_row.source_resource, -1)
		_dock.ROW_MENU_SCOPE_TO_NODE:
			if _dock._context_row != null and _dock._context_row.source_resource is EventRow:
				_dock._open_with_node_dialog(_dock._context_row.source_resource)
		_dock.ROW_MENU_ADD_ENUM:
			var new_enum: EnumRow = EnumRow.new()
			_dock._insert_context_row_below(new_enum, "Added enum.")
			_dock._open_enum_dialog(new_enum)
		_dock.ROW_MENU_OPEN_IN_SPLIT:
			_dock._open_row_in_split(_dock._context_row)
		_dock.ROW_MENU_ADD_SIGNAL:
			var new_signal: SignalRow = SignalRow.new()
			_dock._insert_context_row_below(new_signal, "Added signal.")
			_dock._open_signal_dialog(new_signal)
		_dock.ROW_MENU_ADD_MATCH:
			if _dock._context_row.source_resource is EventRow:
				var new_match: MatchRow = MatchRow.new()
				var match_host: EventRow = _dock._context_row.source_resource as EventRow
				var added_match: bool = _dock._perform_undoable_sheet_edit("Add Match", func() -> bool:
					match_host.actions.append(new_match)
					return true
				)
				if added_match:
					_dock._refresh_after_edit()
					_dock._open_match_dialog(new_match)
			else:
				_dock._set_status("Select an event to add a match to its actions.", true)
		_dock.ROW_MENU_FIND_USAGES:
			var usage_target: Resource = _dock._context_row.source_resource if _dock._context_row != null else null
			var usage_query: String = ""
			if usage_target is LocalVariable:
				usage_query = (usage_target as LocalVariable).name
			elif usage_target is EventGroup:
				usage_query = (usage_target as EventGroup).group_name
			elif _dock._context_row != null and not _dock._context_row.spans.is_empty():
				usage_query = str(_dock._context_row.spans[0].text).get_slice(":", 0).strip_edges()
			if usage_query.is_empty():
				_dock._set_status("Nothing identifiable to search for on this row.", true)
			else:
				_dock._open_project_find(usage_query)
		_dock.ROW_MENU_GROUP_RUNTIME:
			_dock._toggle_group_runtime()
		_dock.ROW_MENU_GROUP_COLOR:
			_dock._open_group_color_picker()
		_dock.ROW_MENU_BULK_TOGGLE_ENABLED:
			_dock._bulk_set_enabled_on(_dock._top_level_selected_resources())
		_dock.ROW_MENU_BULK_DUPLICATE:
			_dock._bulk_duplicate_rows(_dock._top_level_selected_resources())
		_dock.ROW_MENU_BULK_GROUP:
			var group_problem: String = _dock._bulk_group_rows(_dock._top_level_selected_resources())
			if not group_problem.is_empty():
				_dock._set_status(group_problem, true)
		_dock.ROW_MENU_SAVE_SNIPPET:
			_dock._open_save_snippet_dialog()
		_dock.ROW_MENU_INSERT_SNIPPET:
			_dock._open_insert_snippet()
		_dock.ROW_MENU_EDIT_GROUP_DESC:
			if _dock._context_row.source_resource is EventGroup:
				var described_group: EventGroup = _dock._context_row.source_resource as EventGroup
				if described_group.description.strip_edges().is_empty():
					var seeded: bool = _dock._perform_undoable_sheet_edit("Add Group Description", func() -> bool:
						described_group.description = "Description"
						return true
					)
					if seeded:
						_dock._refresh_after_edit()
				_dock._set_status("Double-click the description line (or slow-double-click) to edit it.")
			else:
				_dock._set_status("Select a group to edit its description.", true)


func unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE and _dock._ace_picker.is_open():
		_dock._ace_picker.close()
		_dock.accept_event()
		return
	# Structural/letter shortcuts are suppressed while typing in a text field so authoring
	# keys never fire mid-edit (text fields already consume their own text shortcuts).
	var typing: bool = _dock._text_field_has_focus()
	var shift: bool = key_event.shift_pressed
	# Rebindable shortcuts (EventSheetShortcuts - edit via Tools ▸ Keyboard Shortcuts, saved per-user):
	# exact modifier matching, so a chord never shadows its plain form. Entries:
	# [action, suppressed-while-typing, handler]. Core reflexes by default: E event,
	# C condition, A action (each opens the Ghost Row - the type-a-sentence add popup; the Ctrl
	# chords + toolbar keep the classic pickers), Q comment, G group, X toggle.
	for entry: Array in [
		["add_condition_chord", true, _dock._on_add_condition_requested],
		["add_action_chord", true, _dock._on_add_action_requested],
		["add_variable_chord", true, _dock._on_add_global_variable_requested],
		["add_event_chord", true, _dock._on_add_event_requested],
		["duplicate", true, _dock._on_duplicate_requested],
		["save_as", false, _dock._on_save_as_requested],
		["save", false, _dock._on_save_requested],
		["open", false, _dock._on_open_requested],
		["copy", false, _dock._on_copy_requested],
		["paste", false, _dock._on_paste_requested],
		["redo", false, _dock._on_redo_requested],
		["undo", false, _dock._on_undo_requested],
		["add_comment", true, _dock._on_add_comment_requested],
		["add_event", true, _dock._open_ghost_event],
		["add_condition", true, _dock._open_ghost_condition],
		["add_action", true, _dock._open_ghost_action],
		["add_group", true, _dock._on_add_group_requested],
		["toggle_enabled", true, _dock._toggle_selected_enabled],
		["add_blank_subevent", true, _dock._on_add_blank_subevent_key],
		["add_sub_condition", true, _dock._on_add_sub_condition_key],
		["add_variable", true, _dock._on_add_global_variable_requested],
		["invert_condition", true, _dock._on_invert_condition_key],
		["replace_ace", true, _dock._on_replace_ace_key],
		["history_back", true, _dock._navigate.go_back],
		["history_forward", true, _dock._navigate.go_forward],
	]:
		if EventSheetShortcuts.matches(key_event, str(entry[0])):
			if bool(entry[1]) and typing:
				return  # let the text field keep the keystroke
			(entry[2] as Callable).call()
			_dock.accept_event()
			return
	# Fixed alternates + structural keys (grammar, not preference - never rebindable):
	# Ctrl+Y redo, Ctrl+± zoom, Tab nesting, Delete, Enter/F2 inline edit.
	if key_event.ctrl_pressed or key_event.meta_pressed:
		if key_event.keycode == KEY_P:
			_dock._open_command_palette()
			_dock.accept_event()
		elif key_event.keycode == KEY_Y:
			_dock._on_redo_requested()
			_dock.accept_event()
		elif key_event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			_dock._on_zoom_in_requested()
			_dock.accept_event()
		elif key_event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_dock._on_zoom_out_requested()
			_dock.accept_event()
		return
	if typing:
		return
	if key_event.keycode == KEY_TAB and shift:
		# Outdent (un-nest); only consume Tab when the move actually applies so normal
		# focus traversal still works when there is nothing to outdent.
		if _dock._outdent_selected_event():
			_dock.accept_event()
	elif key_event.keycode == KEY_TAB:
		if _dock._indent_selected_event():
			_dock.accept_event()
	elif key_event.keycode == KEY_BACKTAB:
		if _dock._outdent_selected_event():
			_dock.accept_event()
	elif key_event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		_dock._delete_selected_content()
		_dock.accept_event()
	elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		# Same param-scope-aware funnel as the viewport's own Enter, so both paths agree.
		if _dock._viewport != null and _dock._viewport.handle_enter_key():
			_dock.accept_event()
	elif key_event.keycode == KEY_F2:
		if _dock._viewport != null and _dock._viewport.begin_edit_selected():
			_dock.accept_event()


## "Surround with Region…": wraps the selected top-level rows (or the right-clicked
## row) in a fresh #region / #endregion fence pair as ONE undo step, then opens the
## fence editor so the region gets its name/description/color right away - the
## script editor's surround gesture, event-sheet style. Rows nested inside groups
## are skipped (fences pair per level; wrap the group itself instead).
func surround_selection_with_region() -> void:
	if _dock._current_sheet == null:
		return
	var entry_indices: Array[int] = []
	var selected_rows: Array[EventRowData] = _dock._viewport.get_selected_rows() if _dock._viewport != null else []
	if selected_rows.is_empty() and _dock._context_row != null:
		selected_rows = [_dock._context_row]
	for row_data: EventRowData in selected_rows:
		if row_data == null or row_data.source_resource == null:
			continue
		var entry_index: int = _dock._current_sheet.events.find(row_data.source_resource)
		if entry_index != -1 and not entry_indices.has(entry_index):
			entry_indices.append(entry_index)
	if entry_indices.is_empty():
		_dock._set_status("Select top-level rows to surround with a region.", true)
		return
	entry_indices.sort()
	var first_index: int = entry_indices[0]
	var last_index: int = entry_indices[entry_indices.size() - 1]
	var opener: CustomBlockRow = CustomBlockRow.new()
	opener.kind_id = "region"
	opener.fields = {"label": "New Region", "is_end": false}
	var closer: CustomBlockRow = CustomBlockRow.new()
	closer.kind_id = "region"
	closer.fields = {"label": "", "is_end": true}
	var changed: bool = _dock._perform_undoable_sheet_edit("Surround with Region", func() -> bool:
		_dock._current_sheet.events.insert(last_index + 1, closer)
		_dock._current_sheet.events.insert(first_index, opener)
		return true)
	if not changed:
		return
	_dock._refresh_after_edit()
	_dock._mark_dirty("Surrounded %d row%s with a region." % [entry_indices.size(), "" if entry_indices.size() == 1 else "s"])
	# Name it right away. The undo funnel replaces resources with snapshot duplicates
	# on commit, so re-fetch the live opener from the sheet instead of trusting `opener`.
	var live_opener: Resource = _dock._current_sheet.events[first_index] if first_index < _dock._current_sheet.events.size() else null
	if live_opener is CustomBlockRow and (live_opener as CustomBlockRow).kind_id == "region":
		_dock._open_block_editor(live_opener)
