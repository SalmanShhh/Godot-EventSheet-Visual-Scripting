@tool
class_name EventSheetContextMenus
extends RefCounted
# The dock's right-click context menus: the static condition/action/variable/empty-space PopupMenus
# built once, plus the row menu (rebuilt per right-click to show only what applies to the clicked
# row type + selection) and its Insert ▸ / More ▸ submenus. Construction + per-click configuration
# only - every menu item targets a dock handler that STAYS on the dock (the _on_*_context_menu_id_pressed
# dispatchers and the per-item actions), reached through the `_dock` back-reference, the same pattern as
# the other dock/ helpers. The seven PopupMenu members the dock + 20+ tests read later
# (_condition_context_menu / _action_context_menu / _row_context_menu / _row_insert_submenu /
# _row_more_submenu / _variable_context_menu / _empty_space_context_menu) stay DECLARED on the dock;
# build_all() constructs them and assigns them back so nothing else changes. Extracted from
# event_sheet_dock.gd to keep that file maintainable; the dock keeps thin delegates so the
# context-menu sites and the tests don't change.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## Builds every right-click context menu once and assigns each back onto the dock (the members
## the dock + tests read by name). The row menu + its Insert/More submenus are created empty here;
## they're (re)populated per right-click by _build_row_context_menu / the submenu builders.
func build_all() -> void:
	if _dock._condition_context_menu != null:
		return
	_dock._condition_context_menu = PopupMenu.new()
	_dock._condition_context_menu.add_item("Edit Condition", _dock.CONDITION_MENU_EDIT)
	_dock._condition_context_menu.add_item("Add Condition", _dock.CONDITION_MENU_ADD)
	_dock._condition_context_menu.add_item("Replace Condition", _dock.CONDITION_MENU_REPLACE)
	_dock._condition_context_menu.add_separator()
	_dock._condition_context_menu.add_item("Invert Condition", _dock.CONDITION_MENU_INVERT)
	_dock._condition_context_menu.add_item("Disable Condition", _dock.CONDITION_MENU_TOGGLE_ENABLED)
	_dock._condition_context_menu.add_item("Edit Note…", _dock.CONDITION_MENU_EDIT_ACE_COMMENT)
	_dock._condition_context_menu.add_separator()
	_dock._condition_context_menu.add_item("Delete Condition", _dock.CONDITION_MENU_DELETE)
	_dock._condition_context_menu.id_pressed.connect(_dock._on_condition_context_menu_id_pressed)
	_dock.add_child(_dock._condition_context_menu)

	_dock._action_context_menu = PopupMenu.new()
	_dock._action_context_menu.add_item("Edit Action", _dock.ACTION_MENU_EDIT)
	_dock._action_context_menu.add_item("Add Action", _dock.ACTION_MENU_ADD)
	_dock._action_context_menu.add_item("Replace Action", _dock.ACTION_MENU_REPLACE)
	_dock._action_context_menu.add_separator()
	_dock._action_context_menu.add_item("Disable Action", _dock.ACTION_MENU_TOGGLE_ENABLED)
	_dock._action_context_menu.add_item("Edit Note…", _dock.ACTION_MENU_EDIT_ACE_COMMENT)
	_dock._action_context_menu.add_item("Detach Comment To Row", _dock.ACTION_MENU_DETACH_COMMENT)
	_dock._action_context_menu.add_item("Delete Action", _dock.ACTION_MENU_DELETE)
	_dock._action_context_menu.add_separator()
	# The "create abstraction" gesture: turn this event's actions into one named, reusable verb. Labelled
	# "All" so the all-or-nothing scope is explicit (it extracts every action of the event, not just the
	# right-clicked one).
	_dock._action_context_menu.add_item("Extract All Actions to Function…", _dock.ACTION_MENU_EXTRACT_FN)
	_dock._action_context_menu.id_pressed.connect(_dock._on_action_context_menu_id_pressed)
	_dock.add_child(_dock._action_context_menu)

	# The row menu is rebuilt per right-click (_build_row_context_menu) showing only
	# what applies to the clicked row type + selection - it used to be a flat ~30-item
	# list shown for everything. Insert/More are submenus, built the same way.
	_dock._row_context_menu = PopupMenu.new()
	_dock._row_context_menu.add_theme_font_size_override("font_size", 14)
	_dock._row_context_menu.id_pressed.connect(_dock._on_row_context_menu_id_pressed)
	_dock.add_child(_dock._row_context_menu)
	_dock._row_insert_submenu = PopupMenu.new()
	_dock._row_insert_submenu.name = "RowInsertSubmenu"
	_dock._row_insert_submenu.id_pressed.connect(_dock._on_row_context_menu_id_pressed)
	_dock._row_context_menu.add_child(_dock._row_insert_submenu)
	_dock._row_more_submenu = PopupMenu.new()
	_dock._row_more_submenu.name = "RowMoreSubmenu"
	_dock._row_more_submenu.id_pressed.connect(_dock._on_row_context_menu_id_pressed)
	_dock._row_context_menu.add_child(_dock._row_more_submenu)

	_dock._variable_context_menu = PopupMenu.new()
	_dock._variable_context_menu.add_item("Edit Variable", _dock.VARIABLE_MENU_EDIT)
	_dock._variable_context_menu.add_item("Rename Everywhere…", _dock.VARIABLE_MENU_RENAME)
	_dock._variable_context_menu.add_item("Convert Scope", _dock.VARIABLE_MENU_CONVERT_SCOPE)
	_dock._variable_context_menu.add_item("Toggle Constant", _dock.VARIABLE_MENU_TOGGLE_CONST)
	_dock._variable_context_menu.add_item("Group Under a Heading…", _dock.VARIABLE_MENU_GROUP)
	_dock._variable_context_menu.id_pressed.connect(_dock._on_variable_context_menu_id_pressed)
	_dock.add_child(_dock._variable_context_menu)

	_dock._empty_space_context_menu = PopupMenu.new()
	_dock._empty_space_context_menu.name = "EventSheetEmptySpaceContextMenu"
	_dock._empty_space_context_menu.add_item("New Event", _dock.EMPTY_MENU_NEW_EVENT)
	_dock._empty_space_context_menu.add_item("New Condition", _dock.EMPTY_MENU_NEW_CONDITION)
	_dock._empty_space_context_menu.add_item("Add New Variable", _dock.EMPTY_MENU_ADD_VARIABLE)
	_dock._empty_space_context_menu.add_separator()
	# Inserting a saved snippet is "add to the sheet" - it belongs on the canvas menu,
	# not buried in a row's More submenu.
	_dock._empty_space_context_menu.add_item("Insert Snippet…", _dock.EMPTY_MENU_INSERT_SNIPPET)
	_dock._empty_space_context_menu.id_pressed.connect(_dock._on_empty_space_context_menu_id_pressed)
	_dock.add_child(_dock._empty_space_context_menu)


## Rebuilds the row context menu for the clicked row: only the items that apply to its
## type (event / group / comment) at the top, universal clipboard/lifecycle next, and
## the rest folded into Insert ▸ / More ▸ submenus - replacing the old flat ~30-item
## list shown for every row regardless of type.
func _build_row_context_menu(row_data: EventRowData) -> void:
	var menu: PopupMenu = _dock._row_context_menu
	menu.clear()
	var row_type: int = row_data.row_type if row_data != null else EventRowData.RowType.EVENT
	var is_event: bool = row_type == EventRowData.RowType.EVENT
	var is_group: bool = row_type == EventRowData.RowType.GROUP
	var is_comment: bool = row_type == EventRowData.RowType.COMMENT
	var multi: bool = _dock._get_selected_rows_from_context().size() > 1
	# Type-specific authoring first. (Open/Close Group and the disable label below are
	# relabeled to the live state by _configure_context_menu before the popup shows.)
	var added_type_items: bool = true
	if is_event:
		menu.add_item("Add Sub-Event", _dock.ROW_MENU_ADD_SUB_EVENT)
		menu.add_item("Convert to OR Block", _dock.ROW_MENU_TOGGLE_CONDITION_BLOCK)
		# The event-sheet Else block, top-level like the other event transforms (a C3 reflex, so it is
		# NOT gated behind Expert mode). Clicking again clears it; _configure_context_menu relabels to
		# the live state ("Clear Else" / "Clear Else-If").
		menu.add_item("Make Else", _dock.ROW_MENU_MAKE_ELSE)
		menu.add_item("Make Else-If", _dock.ROW_MENU_MAKE_ELIF)
	elif is_group:
		menu.add_item("Open / Close Group", _dock.ROW_MENU_TOGGLE_GROUP_FOLD)
		menu.add_item("Edit Description…", _dock.ROW_MENU_EDIT_GROUP_DESC)
		menu.add_item("Group Color…", _dock.ROW_MENU_GROUP_COLOR)
		menu.add_item("Runtime Toggleable", _dock.ROW_MENU_GROUP_RUNTIME)
	elif is_comment:
		menu.add_item("Edit Comment…", _dock.ROW_MENU_EDIT_COMMENT)
		menu.add_item("Attach To Event Above", _dock.ROW_MENU_ATTACH_COMMENT)
	elif row_type == EventRowData.RowType.SECTION and row_data != null and row_data.source_resource is EventFunction:
		# A published-verb (Define) header row: edit the verb, or add a parameter to it right here -
		# the same right-click-to-add-an-argument gesture a visual event editor gives its functions.
		menu.add_item("Edit Verb…", _dock.ROW_MENU_EDIT_FUNCTION)
		menu.add_item("Add Parameter", _dock.ROW_MENU_ADD_FUNCTION_PARAM)
		# On an OPENED behaviour pack a verb's body is read-only by default (protecting the .gd round-trip);
		# offer a per-function opt-in to edit THIS verb's body. Authored sheets edit every body already, and
		# a read-only preview edits nothing, so the toggle only appears for an editable opened pack.
		var sheet: EventSheetResource = _dock._current_sheet
		if sheet != null and not sheet.read_only and not sheet.external_source_path.strip_edges().is_empty():
			var fn_name: String = (row_data.source_resource as EventFunction).function_name
			var already: bool = _dock._active_view().is_function_body_editable_opt_in(fn_name)
			menu.add_item("Lock Verb Body (read-only)" if already else "Make Verb Body Editable", _dock.ROW_MENU_MAKE_FUNCTION_EDITABLE)
	else:
		# SECTION / unknown rows get only the universal items - no leading separator.
		added_type_items = false
	if added_type_items:
		menu.add_separator()
	# Universal clipboard + lifecycle (Disable/Duplicate act on the selection, or the
	# clicked row when nothing is selected - _top_level_selected_resources).
	menu.add_item("Cut", _dock.ROW_MENU_CUT)
	menu.add_item("Copy", _dock.ROW_MENU_COPY)
	menu.add_item("Paste", _dock.ROW_MENU_PASTE)
	menu.add_item("Duplicate Selection" if multi else "Duplicate", _dock.ROW_MENU_BULK_DUPLICATE)
	# Single row uses the singular id so _configure_context_menu can relabel it
	# "Disable Row" / "Enable Row" to the row's live state; multi uses the bulk id.
	if multi:
		menu.add_item("Disable / Enable Selection", _dock.ROW_MENU_BULK_TOGGLE_ENABLED)
	else:
		menu.add_item("Disable Row", _dock.ROW_MENU_TOGGLE_ENABLED)
	if multi:
		menu.add_item("Group Selection into New Group", _dock.ROW_MENU_BULK_GROUP)
		# The script editor's selection gesture, surfaced top-level on a multi-selection (the single-row
		# form stays under More): wraps the selected rows in a #region fence pair and opens the name editor.
		menu.add_item("Create Code Region", _dock.ROW_MENU_SURROUND_REGION)
		menu.add_item("Replace Object References…", _dock.ROW_MENU_REPLACE_OBJECT)
	menu.add_separator()
	_build_row_insert_submenu()
	# Explicit ids: an id-less submenu item gets its INDEX as its id, which collided with
	# ROW_MENU_TOGGLE_ENABLED (11) on a multi-selection - the live-state relabel in
	# _configure_context_menu then renamed the submenu entry to "Disable Row". 880+ is clear
	# of every ROW_MENU_* const and below the 900+ extension range.
	menu.add_submenu_item("Insert", "RowInsertSubmenu", 880)
	_build_row_more_submenu(is_event)
	if _dock._row_more_submenu.item_count > 0:
		menu.add_submenu_item("More", "RowMoreSubmenu", 881)
	menu.add_separator()
	menu.add_item("Delete", _dock.ROW_MENU_DELETE)
	# Extension seam (EventSheets.register_row_menu_item): registered items whose filter accepts
	# this row append at the end, ids 900+ in registration order (dispatched by dock_input_dispatch).
	var extension_items: Array[Dictionary] = EventSheets.row_menu_items_for(row_data.source_resource if row_data != null else null)
	if not extension_items.is_empty():
		menu.add_separator()
		for extension_index: int in range(extension_items.size()):
			menu.add_item(str(extension_items[extension_index].get("label", "")), 900 + extension_index)


## The Insert ▸ submenu - a sibling row of any type below the clicked one (plus Event Above,
## the C3 reflex for slotting a new event before the current one).
func _build_row_insert_submenu() -> void:
	var m: PopupMenu = _dock._row_insert_submenu
	m.clear()
	m.add_item("Event Above", _dock.ROW_MENU_ADD_EVENT_ABOVE)
	m.add_item("Event Below", _dock.ROW_MENU_ADD_EVENT_BELOW)
	m.add_item("Group", _dock.ROW_MENU_ADD_GROUP_BELOW)
	m.add_item("Comment", _dock.ROW_MENU_ADD_COMMENT_BELOW)
	m.add_item("Variable", _dock.ROW_MENU_ADD_VARIABLE_BELOW)
	if _dock._simple_mode:
		# Simple mode keeps Insert to the four everyday row types; the code-leaning ones
		# (raw GDScript, signal handlers, enums) stay available in Expert mode.
		return
	m.add_item("GDScript Block", _dock.ROW_MENU_ADD_GDSCRIPT_BELOW)
	m.add_item("Signal Handler", _dock.ROW_MENU_ADD_SIGNAL)
	m.add_item("Enum", _dock.ROW_MENU_ADD_ENUM)


## The More ▸ submenu - advanced authoring (events only) + navigation + snippets.
func _build_row_more_submenu(is_event: bool) -> void:
	var m: PopupMenu = _dock._row_more_submenu
	m.clear()
	# Advanced/code-leaning authoring is Expert-only; Simple mode keeps More to navigation
	# and snippet reuse so a beginner's right-click stays short and unintimidating.
	if is_event and not _dock._simple_mode:
		m.add_item("Add Sub-Condition", _dock.ROW_MENU_ADD_SUB_CONDITION)
		# Make Else / Make Else-If moved to the TOP-LEVEL event menu (a C3 reflex, Simple Mode included).
		m.add_item("Extract All Actions to Function…", _dock.ROW_MENU_EXTRACT_GDSCRIPT_FN)
		m.add_item("Add Comment Sub-Event", _dock.ROW_MENU_ADD_COMMENT_SUB_EVENT)
		m.add_item("Add GDScript Action", _dock.ROW_MENU_ADD_GDSCRIPT_ACTION)
		m.add_item("Set Breakpoint Condition…", _dock.ROW_MENU_BREAKPOINT_CONDITION)
		m.add_item("Add Pick Filter (For Each)…", _dock.ROW_MENU_ADD_PICK_FILTER)
		m.add_item("Scope Actions To Node…", _dock.ROW_MENU_SCOPE_TO_NODE)
		m.add_item("Add Match To Actions…", _dock.ROW_MENU_ADD_MATCH)
		m.add_separator()
	m.add_item("Copy as Text", _dock.ROW_MENU_COPY_AS_TEXT)
	m.add_item("Find Usages (project)", _dock.ROW_MENU_FIND_USAGES)
	m.add_item("Open in Split", _dock.ROW_MENU_OPEN_IN_SPLIT)
	m.add_separator()
	m.add_item("Save Selection as Snippet…", _dock.ROW_MENU_SAVE_SNIPPET)
	m.add_item("Insert Snippet…", _dock.ROW_MENU_INSERT_SNIPPET)
	m.add_item("Create Code Region…", _dock.ROW_MENU_SURROUND_REGION)
	m.add_item("Replace Object References…", _dock.ROW_MENU_REPLACE_OBJECT)


func _show_popup_menu(menu: PopupMenu, global_position: Vector2) -> void:
	if menu == null:
		return
	_configure_context_menu(menu)
	menu.reset_size()
	menu.popup(Rect2i(Vector2i(global_position), Vector2i.ONE))


func _configure_context_menu(menu: PopupMenu) -> void:
	if menu == _dock._condition_context_menu:
		var invert_index: int = menu.get_item_index(_dock.CONDITION_MENU_INVERT)
		if invert_index >= 0:
			# A trigger ("On X" event header) can't be inverted - there's no "not On X", and the compiler
			# never reads trigger.negated, so it would have silently no-op'd. Only regular conditions
			# invert (compiled as `not (…)`). Disable the item + explain when the user right-clicked a trigger.
			var inverting_trigger: bool = str(_dock._context_hit.get("span_metadata", {}).get("kind", "")) == "trigger"
			menu.set_item_disabled(invert_index, inverting_trigger)
			menu.set_item_tooltip(invert_index, "Triggers can't be inverted - there's no \"not On X\"." if inverting_trigger else "")
			menu.set_item_text(invert_index, "Remove Inversion" if _dock._context_condition_is_negated() else "Invert Condition")
		var condition_toggle_index: int = menu.get_item_index(_dock.CONDITION_MENU_TOGGLE_ENABLED)
		if condition_toggle_index >= 0:
			menu.set_item_text(
				condition_toggle_index,
				"Enable Condition" if _dock._context_ace_is_disabled() else "Disable Condition"
			)
	elif menu == _dock._row_context_menu:
		var toggle_index: int = menu.get_item_index(_dock.ROW_MENU_TOGGLE_CONDITION_BLOCK)
		if toggle_index >= 0:
			var selected_events: Array[EventRow] = _dock._get_selected_event_rows_from_context()
			var has_events: bool = not selected_events.is_empty()
			menu.set_item_disabled(toggle_index, not has_events)
			if has_events:
				menu.set_item_text(
					toggle_index,
					(
						"Convert to AND Block"
						if _dock._event_rows_use_or_mode(selected_events)
						else "Convert to OR Block"
					)
				)
		# Make Else / Make Else-If relabel to the live state: when every selected event already carries
		# that mode, the click clears it (the toggle in _set_context_else_mode), so say so.
		var else_index: int = menu.get_item_index(_dock.ROW_MENU_MAKE_ELSE)
		var elif_index: int = menu.get_item_index(_dock.ROW_MENU_MAKE_ELIF)
		if else_index >= 0 or elif_index >= 0:
			var else_events: Array[EventRow] = _dock._get_selected_event_rows_from_context()
			var has_else_events: bool = not else_events.is_empty()
			var all_else: bool = has_else_events
			var all_elif: bool = has_else_events
			for else_event: EventRow in else_events:
				all_else = all_else and else_event.else_mode == EventRow.ElseMode.ELSE
				all_elif = all_elif and else_event.else_mode == EventRow.ElseMode.ELIF
			if else_index >= 0:
				menu.set_item_disabled(else_index, not has_else_events)
				menu.set_item_text(else_index, "Clear Else" if all_else else "Make Else")
			if elif_index >= 0:
				menu.set_item_disabled(elif_index, not has_else_events)
				menu.set_item_text(elif_index, "Clear Else-If" if all_elif else "Make Else-If")
		var sub_condition_index: int = menu.get_item_index(_dock.ROW_MENU_ADD_SUB_CONDITION)
		if sub_condition_index >= 0:
			var context_event: EventRow = _dock._context_row.source_resource as EventRow if _dock._context_row != null else null
			menu.set_item_disabled(sub_condition_index, context_event == null)
		var group_toggle_index: int = menu.get_item_index(_dock.ROW_MENU_TOGGLE_GROUP_FOLD)
		if group_toggle_index >= 0:
			var context_group: EventGroup = null
			if _dock._context_row != null and _dock._context_row.source_resource is EventGroup:
				context_group = _dock._context_row.source_resource as EventGroup
			menu.set_item_disabled(group_toggle_index, context_group == null)
			if context_group != null:
				menu.set_item_text(
					group_toggle_index,
					"Open Group" if context_group.is_collapsed() else "Close Group"
				)
		var row_toggle_index: int = menu.get_item_index(_dock.ROW_MENU_TOGGLE_ENABLED)
		if row_toggle_index >= 0:
			menu.set_item_text(
				row_toggle_index,
				"Enable Row" if _dock._context_row_is_disabled() else "Disable Row"
			)
	elif menu == _dock._variable_context_menu:
		var has_variable: bool = not _dock._variables._context_variable.is_empty()
		var convert_index: int = menu.get_item_index(_dock.VARIABLE_MENU_CONVERT_SCOPE)
		if convert_index >= 0:
			menu.set_item_disabled(convert_index, not has_variable)
			if has_variable:
				var scope_label: String = str(_dock._variables._context_variable.get("scope", "global"))
				menu.set_item_text(
					convert_index,
					"Convert to Global" if scope_label == "local" else "Convert to Local"
				)
		var const_index: int = menu.get_item_index(_dock.VARIABLE_MENU_TOGGLE_CONST)
		if const_index >= 0:
			var supports_const: bool = has_variable and bool(_dock._variables._context_variable.get("supports_const", false))
			menu.set_item_disabled(const_index, not supports_const)
			if has_variable:
				var is_constant: bool = bool(_dock._variables._context_variable.get("is_constant", false))
				menu.set_item_text(
					const_index,
					"Unset Constant" if is_constant else "Set Constant"
				)
	elif menu == _dock._action_context_menu:
		var action_toggle_index: int = menu.get_item_index(_dock.ACTION_MENU_TOGGLE_ENABLED)
		if action_toggle_index >= 0:
			menu.set_item_text(
				action_toggle_index,
				"Enable Action" if _dock._context_ace_is_disabled() else "Disable Action"
			)
