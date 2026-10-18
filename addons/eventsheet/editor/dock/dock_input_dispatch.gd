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

## The list the public API keeps the extension row items on, in a file that names nothing:
## asking the API itself here would compile it, and everything it names, into the first open.
const DOCK_REGISTRY := preload("res://addons/eventsheet/api/dock_registry.gd")
## The answers to "the selection skips rows": take them in, or make one region per run.
const SURROUND_INCLUDE := "include"
const SURROUND_SPLIT := "split"

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


func on_row_context_menu_id_pressed(id: int) -> void:
	if _dock._context_row == null:
		return
	# Extension row-menu items (EventSheets.register_row_menu_item) occupy ids 900+.
	if id >= 900:
		var applicable: Array[Dictionary] = DOCK_REGISTRY.row_menu_items_for(_dock._context_row.source_resource)
		var extension_index: int = id - 900
		if extension_index < applicable.size():
			var action: Callable = applicable[extension_index].get("action", Callable())
			if action.is_valid():
				action.call(_dock._context_row.source_resource)
		return
	match id:
		_dock.ACTION_MENU_DECL_ADD_ENTRY:
			_dock._quick_prompts.prompt_collection_entry(_dock._context_decl(), -1)
		_dock.ACTION_MENU_DECL_EDIT_ENTRY:
			_dock._quick_prompts.prompt_collection_entry(_dock._context_decl(), _dock._context_decl_entry_index())
		_dock.ACTION_MENU_DECL_REMOVE_ENTRY:
			_dock._remove_collection_entry(_dock._context_decl(), _dock._context_decl_entry_index())
		_dock.ROW_MENU_ADD_SUB_EVENT:
			_dock._row_edit_ops._insert_child_event_for_context_row()
		_dock.ROW_MENU_ADD_COMMENT_SUB_EVENT:
			_dock._row_edit_ops._insert_child_comment_for_context_row()
		_dock.ROW_MENU_ADD_EVENT_BELOW:
			_dock._row_edit_ops._insert_context_row_below(EventRow.new(), "Added event.")
		_dock.ROW_MENU_ADD_EVENT_ABOVE:
			_dock._row_edit_ops._insert_context_row_above(EventRow.new(), "Added event above.")
		_dock.ROW_MENU_ADD_GROUP_BELOW:
			var group: EventGroup = EventGroup.new()
			group.name = "Group"
			group.group_name = group.name
			_dock._row_edit_ops._insert_context_row_below(group, "Added group.")
		_dock.ROW_MENU_ADD_COMMENT_BELOW:
			var comment: CommentRow = CommentRow.new()
			comment.text = "Comment"
			_dock._row_edit_ops._insert_context_row_below(comment, "Added comment.")
		_dock.ROW_MENU_ADD_VARIABLE_BELOW:
			_dock._variables._add_tree_variable_below_context_row()
		_dock.ROW_MENU_ADD_TIMELINE_BELOW:
			# A Timeline suspends, so it arrives inside its own ready-trigger event with one
			# starter beat; right-click the beat (or the caption) for "Add Step...".
			var timeline_event: EventRow = EventRow.new()
			timeline_event.trigger_id = "OnReady"
			timeline_event.trigger_provider_id = "Core"
			var timeline: TimelineRow = TimelineRow.new()
			var starter: RawCodeRow = RawCodeRow.new()
			starter.code = "print(\"timeline started\")"
			timeline.add_step(0.0, starter)
			timeline_event.actions.append(timeline)
			_dock._row_edit_ops._insert_context_row_below(timeline_event, "Added timeline.")
		_dock.ROW_MENU_ADD_GDSCRIPT_BELOW:
			var raw_block: RawCodeRow = RawCodeRow.new()
			raw_block.code = "# GDScript - emitted verbatim at class level"
			_dock._row_edit_ops._insert_context_row_below(raw_block, "Added script block.")
		_dock.ROW_MENU_ADD_GDSCRIPT_ACTION:
			_dock._add_gdscript_action_to_context_row()
		_dock.ROW_MENU_COPY:
			_dock._on_copy_requested()
		_dock.ROW_MENU_CUT:
			_dock._cut_selected_rows()
		_dock.ROW_MENU_COPY_AS_TEXT:
			_dock._clipboard_glue._copy_selection_as_text()
		_dock.ROW_MENU_SURROUND_REGION:
			_dock._input_dispatch.surround_selection_with_region()
		_dock.ROW_MENU_REPLACE_OBJECT:
			_dock._open_replace_object_dialog()
		_dock.ROW_MENU_PASTE_SPECIAL:
			_dock._paste_special_dialog.open()
		_dock.ROW_MENU_BATCH_EDIT_PARAMS:
			_dock._open_batch_param_edit()
		_dock.ROW_MENU_DATA_CLASS_ADD_FIELD:
			_dock._open_data_class_add_field()
		_dock.ROW_MENU_DATA_CLASS_REMOVE_FIELD:
			_dock._remove_data_class_field_from_context()
		_dock.ROW_MENU_PASTE:
			_dock._on_paste_requested()
		_dock.ROW_MENU_DELETE:
			_dock._row_edit_ops._delete_selected_rows()
		_dock.ROW_MENU_TOGGLE_CONDITION_BLOCK:
			_dock._row_edit_ops._toggle_context_condition_block()
		_dock.ROW_MENU_TOGGLE_GROUP_FOLD:
			_dock._row_edit_ops._toggle_context_group_fold()
		_dock.ROW_MENU_ADD_SUB_CONDITION:
			_dock._row_edit_ops._open_sub_condition_picker_for_context_row()
		_dock.ROW_MENU_MAKE_ELSE:
			_dock._row_edit_ops._set_context_else_mode(EventRow.ElseMode.ELSE)
		_dock.ROW_MENU_MAKE_ELIF:
			_dock._row_edit_ops._set_context_else_mode(EventRow.ElseMode.ELIF)
		_dock.ROW_MENU_EXTRACT_GDSCRIPT_FN:
			_dock._extract_ops.extract_to_function_requested()
		_dock.ROW_MENU_BREAKPOINT_CONDITION:
			_dock._quick_prompts.set_breakpoint_condition_requested()
		_dock.ROW_MENU_TOGGLE_ENABLED:
			_dock._row_edit_ops._toggle_context_row_enabled()
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
				_dock._set_status("Select a published function's row to edit it.", true)
		_dock.ROW_MENU_RENAME_FUNCTION:
			if _dock._context_row != null and _dock._context_row.source_resource is EventFunction:
				_dock.open_rename_receipt(
					(_dock._context_row.source_resource as EventFunction).function_name)
			else:
				_dock._set_status("Select a function's row to rename it.", true)
		_dock.ROW_MENU_ADD_TOOL_BUTTON:
			if _dock._context_row != null and _dock._context_row.source_resource is EventFunction:
				_dock.prompt_inspector_button_for((_dock._context_row.source_resource as EventFunction).function_name)
		_dock.ROW_MENU_MAKE_MESSAGE:
			if _dock._context_row != null and _dock._context_row.source_resource is EventFunction:
				_dock._messages.open_message(_dock._context_row.source_resource)
			else:
				_dock._set_status("Select a function's row to make it a message.", true)
		_dock.ROW_MENU_ADD_FUNCTION_PARAM:
			if _dock._context_row != null and _dock._context_row.source_resource is EventFunction:
				_dock._function_dialog_glue._open_function_dialog_add_param(_dock._context_row.source_resource)
			else:
				_dock._set_status("Select a published function's row to add a parameter to it.", true)
		_dock.ROW_MENU_MAKE_FUNCTION_EDITABLE:
			# Opt THIS opened-pack verb's body in/out of editing (editor state only - never dirties the .gd).
			if _dock._context_row != null and _dock._context_row.source_resource is EventFunction:
				var verb_name: String = (_dock._context_row.source_resource as EventFunction).function_name
				_dock._active_view().toggle_function_body_editable(verb_name)
				_dock._set_status("%s is now %s." % [verb_name, "editable" if _dock._active_view().is_function_body_editable_opt_in(verb_name) else "read-only"])
			else:
				_dock._set_status("Select a published function's row to change its body editability.", true)
		_dock.ROW_MENU_ADD_PICK_FILTER:
			_dock._open_pick_filter_dialog(_dock._context_row.source_resource, -1)
		_dock.ROW_MENU_SCOPE_TO_NODE:
			if _dock._context_row != null and _dock._context_row.source_resource is EventRow:
				_dock._open_with_node_dialog(_dock._context_row.source_resource)
		_dock.ROW_MENU_ADD_ENUM:
			var new_enum: EnumRow = EnumRow.new()
			_dock._row_edit_ops._insert_context_row_below(new_enum, "Added enum.")
			_dock._open_enum_dialog(new_enum)
		_dock.ROW_MENU_OPEN_IN_SPLIT:
			_dock._open_row_in_split(_dock._context_row)
		_dock.ROW_MENU_ADD_SIGNAL:
			var new_signal: SignalRow = SignalRow.new()
			_dock._row_edit_ops._insert_context_row_below(new_signal, "Added signal.")
			_dock._open_signal_dialog(new_signal)
		_dock.ROW_MENU_ADD_MATCH:
			if _dock._context_row.source_resource is EventRow:
				# Nothing lands until Done: the window adds the match and its branches in one undo step.
				_dock._struct_rows.open_match_dialog(MatchRow.new(), _dock._context_row.source_resource as EventRow)
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
		_dock.ROW_MENU_GROUP_ENABLED:
			_dock._toggle_group_enabled()
		_dock.ROW_MENU_GROUP_SWITCHABLE:
			_dock._quick_prompts.on_group_switchable_toggled()
		_dock.ROW_MENU_EDIT_GROUP:
			_dock._open_group_editor_for_context()
		_dock.ROW_MENU_FOLD_ALL_GROUPS:
			_dock._toggle_all_group_folds()
		_dock.ROW_MENU_GROUP_ADD_LOCAL:
			_dock._add_group_local_variable()
		_dock.ROW_MENU_UNGROUP:
			_dock._ungroup_context_group()
		_dock.ROW_MENU_GROUP_COLOR:
			_dock._open_group_color_picker()
		_dock.ROW_MENU_GROUP_TO_REGION:
			_dock._turn_group_into_region()
		_dock.ROW_MENU_REGION_RENAME:
			_dock._begin_region_rename()
		_dock.ROW_MENU_TOGGLE_REGION_FOLD:
			_dock._toggle_context_region_fold()
		_dock.ROW_MENU_FOLD_ALL_REGIONS:
			_dock._toggle_all_region_folds()
		_dock.ROW_MENU_REGION_TO_GROUP:
			_dock._turn_region_into_group()
		_dock.ROW_MENU_REGION_REMOVE:
			_dock._remove_context_region()
		_dock.ROW_MENU_BULK_TOGGLE_ENABLED:
			_dock._row_edit_ops._bulk_set_enabled_on(_dock._top_level_selected_resources())
		_dock.ROW_MENU_BULK_DUPLICATE:
			_dock._row_edit_ops._bulk_duplicate_rows(_dock._top_level_selected_resources())
		_dock.ROW_MENU_BULK_GROUP:
			var group_problem: String = _dock._row_edit_ops._bulk_group_rows(_dock._top_level_selected_resources())
			if not group_problem.is_empty():
				_dock._set_status(group_problem, true)
		_dock.ROW_MENU_SAVE_SNIPPET:
			_dock._open_save_snippet_dialog()
		_dock.ROW_MENU_INSERT_SNIPPET:
			_dock._open_insert_snippet()


func unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# The built flag first: reading the field builds the picker, and Escape is no reason to compile it.
	if key_event.keycode == KEY_ESCAPE and _dock._ace_picker_built and _dock._ace_picker.is_open():
		_dock._ace_picker.close()
		_dock.accept_event()
		return
	# F1 explains the selected row. Deliberately ABOVE the typing suppression and outside the
	# rebindable table: help is the one key a reader expects to work mid-edit, and it is the
	# universal help key rather than a preference. With nothing selected it opens the index.
	if key_event.keycode == KEY_F1:
		# Ctrl+F1 is the OTHER half of the reflex: not "explain this row" but "take me back to what
		# I was reading". A reader who left the Manual mid-page gets that page, not the index.
		if key_event.ctrl_pressed:
			_dock.open_documentation(_dock.last_read_doc_id())
		else:
			_dock.open_documentation()
		_dock.accept_event()
		return
	# Esc clears the live filter lens (after the picker check - closing a popup wins).
	if key_event.keycode == KEY_ESCAPE and _dock._viewport != null and _dock._viewport.lens_active():
		_dock._apply_lens("")
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
		["add_condition_chord", true, _dock._add_rows.on_add_condition_requested],
		["add_action_chord", true, _dock._add_rows.on_add_action_requested],
		["add_variable_chord", true, _dock._on_add_global_variable_requested],
		["add_event_chord", true, _dock._add_rows.on_add_event_requested],
		["duplicate", true, _dock._add_rows.on_duplicate_requested],
		["apply_to_running_game", false, _dock._live_edit_bar.apply],
		["save_as", false, _dock._sheet_io._on_save_as_requested],
		["save", false, _dock._sheet_io._on_save_requested],
		["open", false, _dock._on_open_requested],
		["copy", false, _dock._on_copy_requested],
		["copy_as_text", false, _dock._clipboard_glue._copy_selection_as_text],
		["paste", false, _dock._on_paste_requested],
		["redo", false, _dock._on_redo_requested],
		["undo", false, _dock._on_undo_requested],
		["add_comment", true, _dock._add_rows.on_add_comment_requested],
		["add_event", true, _dock._open_ghost_event],
		["add_condition", true, _dock._open_ghost_condition],
		["add_action", true, _dock._open_ghost_action],
		["add_group", true, _dock._add_rows.on_add_group_requested],
		["toggle_enabled", true, _dock._row_edit_ops._toggle_selected_enabled],
		["add_blank_subevent", true, _dock._on_add_blank_subevent_key],
		["add_sub_condition", true, _dock._on_add_sub_condition_key],
		["add_variable", true, _dock._on_add_project_global_requested],
		["add_function", true, _dock._open_function_dialog],
		# Preview layout / project / debug. Godot's own run keys by default, so the sheet's
		# buttons and the editor's play bar always mean the same thing.
		["preview_layout", false, func() -> void: _dock._run_controls.activate("preview_layout")],
		["preview_project", false, func() -> void: _dock._run_controls.activate("preview_project")],
		["debug_layout", false, func() -> void: _dock._run_controls.activate("debug_layout")],
		# Unbound by default (Left / Right already collapse and expand, and those are grammar);
		# it exists so the "Another event-sheet editor" preset can put collapse/expand on Ctrl+E.
		["toggle_collapse", true, _dock._toggle_selected_collapse],
		["invert_condition", true, _dock._on_invert_condition_key],
		["replace_ace", true, _dock._on_replace_ace_key],
		["project_search", false, _dock._open_project_find],
		["run_editor_tool", false, _dock._editor_tool_bar.run_now],
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
		elif key_event.keycode == KEY_G:
			if key_event.shift_pressed:
				# Ctrl+Shift+G: open all groups, or close them all when any is open. One key for
				# the whole sheet, beside the G that makes one.
				_dock._toggle_all_group_folds()
			else:
				# Ctrl+G: Go to event. The margin number is how two people name the same row, so
				# jumping to one is grammar rather than a preference - fixed, like the zoom keys.
				_dock._open_go_to_event_dialog()
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
		elif key_event.keycode in [KEY_0, KEY_KP_0]:
			_dock._on_zoom_reset_requested()
			_dock.accept_event()
		return
	if typing:
		return
	if key_event.keycode == KEY_TAB and shift:
		# Outdent (un-nest); only consume Tab when the move actually applies so normal
		# focus traversal still works when there is nothing to outdent.
		if _dock._row_edit_ops._outdent_selected_event():
			_dock.accept_event()
	elif key_event.keycode == KEY_TAB:
		if _dock._row_edit_ops._indent_selected_event():
			_dock.accept_event()
	elif key_event.keycode == KEY_BACKTAB:
		if _dock._row_edit_ops._outdent_selected_event():
			_dock.accept_event()
	elif key_event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		_dock._row_edit_ops._delete_selected_content()
		_dock.accept_event()
	elif key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		# Same param-scope-aware funnel as the viewport's own Enter, so both paths agree.
		if _dock._viewport != null and _dock._viewport.handle_enter_key():
			_dock.accept_event()
	elif key_event.keycode == KEY_F2:
		if _dock._viewport != null and _dock._viewport.begin_edit_selected():
			_dock.accept_event()


## "Surround with Region…": wraps the selected rows (or the right-clicked row) in a fresh
## #region / #endregion pair as ONE undo step, then opens the fence editor so the region gets its
## name right away - the script editor's surround gesture. The fences go into the container the rows
## live in, so rows inside a group get a region inside that group. A region is one run of rows: when
## the selection skips rows, the gesture asks rather than swallowing them (`skipped` is that answer,
## SURROUND_INCLUDE or SURROUND_SPLIT).
func surround_selection_with_region(skipped: String = "") -> void:
	var plan: Dictionary = _surround_plan()
	if plan.has("problem"):
		_dock._set_status(str(plan["problem"]), true)
		return
	var runs: Array = plan["runs"]
	if runs.size() > 1 and skipped.is_empty():
		_ask_about_skipped_rows(plan)
		return
	if skipped == SURROUND_INCLUDE:
		runs = [[runs[0][0], runs[runs.size() - 1][1]]]
	var container: Array = plan["container"]
	var opener_rank: Array[int] = []
	var changed: bool = _dock._perform_undoable_sheet_edit("Surround with Region", func() -> bool:
		# Back to front, so each pair's indices are still true when it lands.
		for run_index: int in range(runs.size() - 1, -1, -1):
			container.insert(int(runs[run_index][1]) + 1, EventSheetRegionFacts.make_fence("", true))
			container.insert(int(runs[run_index][0]), EventSheetRegionFacts.make_fence("New Region"))
		opener_rank.append(_opening_fences(_dock._current_sheet.events).find(container[int(runs[0][0])]))
		return true)
	if not changed:
		return
	_dock._refresh_after_edit()
	_dock._mark_dirty(EventSheetL10n.translate("Surrounded the selection with a region.") if runs.size() == 1
		else EventSheetL10n.translate("Surrounded the selection with %d regions.") % runs.size())
	# Name it right away. The undo funnel replaces resources with snapshot duplicates on commit, so
	# the live opener is found again by its place among the sheet's openers, never by `container`.
	var live_openers: Array[CustomBlockRow] = _opening_fences(_dock._current_sheet.events)
	if not opener_rank.is_empty() and opener_rank[0] >= 0 and opener_rank[0] < live_openers.size():
		_dock._open_block_editor(live_openers[opener_rank[0]])


## What surrounding the selection would wrap: {container, runs} where each run is [first, last]
## index of consecutive selected rows in that container, or {problem} said in the reader's words.
func _surround_plan() -> Dictionary:
	if _dock._current_sheet == null:
		return {"problem": EventSheetL10n.translate("Open a sheet to surround its rows with a region.")}
	var container: Array = []
	var indices: Array[int] = []
	for resource: Variant in _dock._top_level_selected_resources():
		var location: Dictionary = _dock._ace_apply._find_resource_location(resource as Resource)
		if location.is_empty():
			continue
		if indices.is_empty():
			container = location["container"]
		elif not is_same(location["container"], container):
			return {"problem": EventSheetL10n.translate("A region is one run of rows in one place. Select rows that sit together, at the same level.")}
		indices.append(int(location["index"]))
	if indices.is_empty():
		return {"problem": EventSheetL10n.translate("Select the rows to surround with a region.")}
	if not _holds_rows_of_the_sheet(container):
		return {"problem": EventSheetL10n.translate("A region goes around rows of the sheet or of a group, not inside an event.")}
	indices.sort()
	var runs: Array = [[indices[0], indices[0]]]
	for index: int in indices.slice(1):
		if index == int(runs[runs.size() - 1][1]) + 1:
			runs[runs.size() - 1][1] = index
		else:
			runs.append([index, index])
	return {"container": container, "runs": runs}


## True for the sheet's own rows and a group's rows - the two places a fence pair is read back from.
func _holds_rows_of_the_sheet(container: Array) -> bool:
	if is_same(container, _dock._current_sheet.events):
		return true
	for group: EventGroup in EventSheetGroupFacts.collect(_dock._current_sheet.events):
		if is_same(group.child_rows(), container):
			return true
	return false


## The question a selection with gaps asks: the rows it skips by their gutter numbers, and the three
## answers - take them in, one region per run, or leave everything as it is.
func _ask_about_skipped_rows(plan: Dictionary) -> void:
	var container: Array = plan["container"]
	var runs: Array = plan["runs"]
	var numbers: PackedStringArray = PackedStringArray()
	var view: EventSheetViewport = _dock._active_view()
	for run_index: int in range(runs.size() - 1):
		for index: int in range(int(runs[run_index][1]) + 1, int(runs[run_index + 1][0])):
			numbers.append(str(_gutter_number(view, container[index])))
	var single: bool = numbers.size() == 1
	load(_dock.SMALL_PROMPT_PATH).open(_dock, {
		"title": EventSheetL10n.translate("Surround with a region"),
		"say": (EventSheetL10n.translate("The selection skips row %s. A region is one run of rows.") if single
			else EventSheetL10n.translate("The selection skips rows %s. A region is one run of rows.")) % ", ".join(numbers),
		"main": (EventSheetL10n.translate("Include row %s") if single
			else EventSheetL10n.translate("Include rows %s")) % ", ".join(numbers),
		"on_main": func() -> void: surround_selection_with_region(SURROUND_INCLUDE),
		"also": EventSheetL10n.translate("Two regions") if runs.size() == 2
			else EventSheetL10n.translate("%d regions") % runs.size(),
		"on_also": func() -> void: surround_selection_with_region(SURROUND_SPLIT),
		"note": EventSheetL10n.translate("Ctrl+Z removes the region again."),
	})


## The number the gutter shows beside `resource`'s row, or "?" when the row is not on the canvas.
func _gutter_number(view: EventSheetViewport, resource: Variant) -> String:
	for entry: Dictionary in view.get_flat_rows() if view != null else []:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == resource and row_data.line_number > 0:
			return str(row_data.line_number)
	return "?"


## Every opening fence on the sheet and inside its groups, in reading order.
func _opening_fences(entries: Array, into: Array[CustomBlockRow] = []) -> Array[CustomBlockRow]:
	for entry: Variant in entries:
		if EventSheetRegionFacts.is_opening_fence(entry):
			into.append(entry as CustomBlockRow)
		elif entry is EventGroup:
			_opening_fences((entry as EventGroup).child_rows(), into)
	return into
