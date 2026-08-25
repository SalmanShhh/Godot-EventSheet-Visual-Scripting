@tool
class_name EventSheetContextMenus
extends RefCounted
# The dock's right-click context menus: the static condition/action/variable/empty-space PopupMenus
# built once, plus the row menu (rebuilt per right-click to show only what applies to the clicked
# row type + selection) and its Insert ▸ / More ▸ submenus. Building + per-click configuration
# only - every menu item targets a dock handler that STAYS on the dock (the _on_*_context_menu_id_pressed
# dispatchers and the per-item actions), reached through the `_dock` back-reference, the same pattern as
# the other dock/ helpers. The seven PopupMenu members the dock + 20+ tests read later
# (_condition_context_menu / _action_context_menu / _row_context_menu / _row_insert_submenu /
# _row_more_submenu / _variable_context_menu / _empty_space_context_menu) stay DECLARED on the dock;
# build_all() constructs them and assigns them back so nothing else changes. Extracted from
# event_sheet_dock.gd to keep that file maintainable; the dock keeps thin delegates so the
# context-menu sites and the tests don't change.

## The row-menu id for "Why didn't this fire?" (appended seam - see build_all). Deliberately far
## above the 900+ extension range so the shared dispatcher recognises it as neither.
const ROW_MENU_WHY_DIDNT_FIRE := 9700

## The id for "Find all references", which rides four menus (variable / condition / action / the
## row's More ▸). Same rule as above: far outside every shared dispatcher's range.
const ROW_MENU_FIND_ALL_REFERENCES := 9710

## The two items an event that a reading claimed a PATTERN on gains: swap the
## hand-written shape for the shipped behavior, and read why the sheet called it that. Same rule as
## the ids above: far outside every shared dispatcher's range.
const ROW_MENU_ADOPT_BEHAVIOR := 9720
const ROW_MENU_EXPLAIN_READING := 9730
const FIND_ALL_REFERENCES_TOOLTIP := "Every place this name is used, across the open sheets and the project - grouped by sheet, with event numbers. F3 / Shift+F3 step through them."

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock


## The key that does the same thing, shown at the right of a menu item, so the shortcut is
## learned from the menu the reader is already in. `binding` is the shortcut table's own spelling
## ("F2", "Ctrl+Shift+V") and goes through its parser, so passing binding_for(action) hints a REBOUND
## key as the key it was bound to.
##
## A HINT: the shortcut is never registered as global. Every one of these keys is already routed
## where it belongs (the viewport's own key handling), and a second listener living on a hidden
## popup would run the same gesture twice.
static func hint_key(menu: PopupMenu, item_id: int, binding: String) -> void:
	var index: int = menu.get_item_index(item_id)
	if index < 0 or binding.strip_edges().is_empty():
		return
	var parsed: Dictionary = EventSheetShortcuts.parse(binding)
	if int(parsed.get("keycode", KEY_NONE)) == KEY_NONE:
		return
	var pressed := InputEventKey.new()
	pressed.keycode = int(parsed["keycode"]) as Key
	pressed.ctrl_pressed = bool(parsed.get("ctrl", false))
	pressed.shift_pressed = bool(parsed.get("shift", false))
	pressed.alt_pressed = bool(parsed.get("alt", false))
	var shortcut := Shortcut.new()
	shortcut.events = [pressed]
	menu.set_item_shortcut(index, shortcut, false)


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
	_dock._condition_context_menu.add_item("Select All Events Using This", _dock.ACE_MENU_SELECT_ALL_MATCHING)
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
	_dock._action_context_menu.add_item("Select All Events Using This", _dock.ACE_MENU_SELECT_ALL_MATCHING)
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
	_dock._row_context_menu.add_theme_font_size_override("font_size", EventSheetPalette.scaled(14))
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

	# The group head's "Runs on". Built once and parented to the ROW menu, because the row menu
	# is where a group head is right-clicked; it is filled from the group under the cursor each time.
	_dock._group_runs_on_submenu = PopupMenu.new()
	_dock._group_runs_on_submenu.name = "GroupRunsOnSubmenu"
	_dock._group_runs_on_submenu.about_to_popup.connect(_fill_group_runs_on_submenu)
	_dock._group_runs_on_submenu.id_pressed.connect(_dock._on_group_runs_on_menu_id_pressed)
	_dock._row_context_menu.add_child(_dock._group_runs_on_submenu)

	_dock._variable_context_menu = PopupMenu.new()
	_dock._variable_context_menu.add_item("Edit Variable", _dock.VARIABLE_MENU_EDIT)
	_dock._variable_context_menu.add_item("Rename Everywhere…", _dock.VARIABLE_MENU_RENAME)
	# The type twin of Rename Everywhere: retyping a variable rewrites every row that sets or
	# compares it, in the same undo step, after showing the list of what it will touch.
	_dock._variable_context_menu.add_item("Change Type Everywhere…", _dock.VARIABLE_MENU_CHANGE_TYPE)
	_dock._variable_context_menu.add_item("Convert Scope", _dock.VARIABLE_MENU_CONVERT_SCOPE)
	_dock._variable_context_menu.add_item("Toggle Constant", _dock.VARIABLE_MENU_TOGGLE_CONST)
	_dock._variable_context_menu.add_item("Remember Between Runs", _dock.VARIABLE_MENU_REMEMBER)
	_dock._variable_context_menu.add_item("Group Under a Heading…", _dock.VARIABLE_MENU_GROUP)
	# The list is in the order it was written; this is how you ask for alphabetical, and it
	# WRITES that order rather than sorting the view behind your back.
	_dock._variable_context_menu.add_item("Sort A-Z", _dock.VARIABLE_MENU_SORT_AZ)
	# The two verbs the row menu was missing. "Copy as expression" hands over the name a
	# parameter field or a script would need (a global as `Game.Score`, which is the spelling that
	# runs); "Show in Inspector" is the one tick that turns a variable into a designer knob.
	_dock._variable_context_menu.add_item("Copy as Expression", _dock.VARIABLE_MENU_COPY_EXPRESSION)
	_dock._variable_context_menu.add_check_item("Show in Inspector", _dock.VARIABLE_MENU_SHOW_IN_INSPECTOR)
	# "Keep in step": whether a MultiplayerSynchronizer in this object's SCENE replicates this
	# value, and in which of the three modes. Filled the moment it opens, because the answer is a
	# fact of a file this dock does not own - and the submenu is named after the synchronizer that
	# holds it, since that is the node the mode is written on.
	_dock._variable_sync_submenu = PopupMenu.new()
	_dock._variable_sync_submenu.name = "VariableSyncSubmenu"
	_dock._variable_sync_submenu.about_to_popup.connect(_fill_variable_sync_submenu)
	_dock._variable_sync_submenu.id_pressed.connect(_dock._on_variable_sync_menu_id_pressed)
	_dock._variable_context_menu.add_submenu_node_item("Keep in Step", _dock._variable_sync_submenu,
		_dock.VARIABLE_MENU_KEEP_IN_STEP)
	# The two accessor events. A setter fires when the value is set, so it reads as a trigger;
	# a getter gives a value, so it reads as an expression. Enabled only on a sheet-level (tree)
	# variable that does not already have that accessor.
	_dock._variable_context_menu.add_item("Add setter", _dock.VARIABLE_MENU_ADD_SETTER)
	_dock._variable_context_menu.add_item("Add getter", _dock.VARIABLE_MENU_ADD_GETTER)
	# The spreadsheet round trip - enabled only on a GRID variable (one with the table drawer);
	# _configure_context_menu disables them with the reason on every other variable.
	_dock._variable_context_menu.add_item("Export Grid to CSV…", _dock.VARIABLE_MENU_GRID_EXPORT)
	_dock._variable_context_menu.add_item("Import Grid from CSV…", _dock.VARIABLE_MENU_GRID_IMPORT)
	# The translator's file beside the designer's: same grid, different shape (one row per key,
	# one column per language - Godot's own catalog), so a balance pass and a translation pass
	# can never overwrite each other.
	_dock._variable_context_menu.add_item("Export Text for Translation…", _dock.VARIABLE_MENU_TEXT_EXPORT)
	_dock._variable_context_menu.add_item("Import Translations…", _dock.VARIABLE_MENU_TEXT_IMPORT)
	# The keys that do the same thing, at the right of the items that do it.
	hint_key(_dock._variable_context_menu, _dock.VARIABLE_MENU_RENAME, "F2")
	_dock._variable_context_menu.id_pressed.connect(_dock._on_variable_context_menu_id_pressed)
	_dock.add_child(_dock._variable_context_menu)

	_dock._empty_space_context_menu = PopupMenu.new()
	_dock._empty_space_context_menu.name = "EventSheetEmptySpaceContextMenu"
	_dock._empty_space_context_menu.add_item("New Event", _dock.EMPTY_MENU_NEW_EVENT)
	_dock._empty_space_context_menu.add_item("New Condition", _dock.EMPTY_MENU_NEW_CONDITION)
	# New Function ▸ a plain helper, or a published Action / Condition / Expression. A submenu owns its
	# own id_pressed, so its four items route through _on_new_function_submenu_id_pressed, not the parent.
	_dock._new_function_submenu = PopupMenu.new()
	_dock._new_function_submenu.name = "EventSheetNewFunctionSubmenu"
	_dock._new_function_submenu.add_item("Function", _dock.NEW_FUNCTION_MENU_PLAIN)
	_dock._new_function_submenu.add_item("Action", _dock.NEW_FUNCTION_MENU_ACTION)
	_dock._new_function_submenu.add_item("Condition", _dock.NEW_FUNCTION_MENU_CONDITION)
	_dock._new_function_submenu.add_item("Expression", _dock.NEW_FUNCTION_MENU_EXPRESSION)
	# A message is a function other peers call, so it is added the same way and then marked.
	_dock._new_function_submenu.add_item("Message…", _dock.NEW_FUNCTION_MENU_MESSAGE)
	_dock._new_function_submenu.id_pressed.connect(_dock._on_new_function_submenu_id_pressed)
	_dock._empty_space_context_menu.add_submenu_node_item("New Function", _dock._new_function_submenu)
	# "add a variable" is three questions, so the submenu asks the one that matters: where does
	# the declaration go. Global writes into an autoload, Local lives inside the event it sits in,
	# Instance belongs to this object. Same dialog behind all three, opened on that scope.
	_dock._add_variable_submenu = PopupMenu.new()
	_dock._add_variable_submenu.name = "EventSheetAddVariableSubmenu"
	_dock._add_variable_submenu.add_item("Global variable…", _dock.EMPTY_MENU_ADD_VARIABLE)
	_dock._add_variable_submenu.add_item("Local variable…", _dock.EMPTY_MENU_ADD_LOCAL_VARIABLE)
	_dock._add_variable_submenu.add_item("Instance variable…", _dock.EMPTY_MENU_ADD_INSTANCE_VARIABLE)
	# And the two of these three that have a key say which. Read off the shortcut table, so a
	# rebound key hints as the key it was rebound to; Local has no key of its own to name.
	hint_key(_dock._add_variable_submenu, _dock.EMPTY_MENU_ADD_VARIABLE,
		EventSheetShortcuts.binding_for("add_variable"))
	hint_key(_dock._add_variable_submenu, _dock.EMPTY_MENU_ADD_INSTANCE_VARIABLE,
		EventSheetShortcuts.binding_for("add_variable_chord"))
	_dock._add_variable_submenu.id_pressed.connect(_dock._on_empty_space_context_menu_id_pressed)
	_dock._empty_space_context_menu.add_submenu_node_item("Add Variable", _dock._add_variable_submenu)
	# The smallest editor tool there is, one menu item away: a button in the Inspector and the
	# empty function it calls. It sits beside Add New Variable because that is what it adds - a knob,
	# one you press instead of one you type into.
	_dock._empty_space_context_menu.add_item("Add Inspector Button…", _dock.EMPTY_MENU_ADD_INSPECTOR_BUTTON)
	_dock._empty_space_context_menu.add_separator()
	# Inserting a saved snippet is "add to the sheet" - it belongs on the canvas menu,
	# not buried in a row's More submenu.
	_dock._empty_space_context_menu.add_item("Insert Snippet…", _dock.EMPTY_MENU_INSERT_SNIPPET)
	_dock._empty_space_context_menu.id_pressed.connect(_dock._on_empty_space_context_menu_id_pressed)
	_dock.add_child(_dock._empty_space_context_menu)

	# ── Refactor seam (dock/refactor_menu.gd) ────────────────────────────────────────────────
	# The reverse gestures - Wrap, Unwrap, Inline, Duplicate as Variant. The submenu owns its own
	# id_pressed (like New Function ▸ above), so its ids never meet the dock's ROW_MENU_* numbering,
	# and it is found by NAME per right-click rather than stored on the dock.
	_dock._row_context_menu.add_child(EventSheetRefactorMenu.build_submenu(_dock))
	# Inline This Call sits on an ACTION's own menu, beside Extract All Actions to Function… - the
	# same gesture with the other direction. The dock's action dispatcher matches its own ids and
	# ignores anything else, so this second listener on one popup cannot collide with it.
	_dock._action_context_menu.add_item("Inline This Call", EventSheetRefactorMenu.ACTION_MENU_INLINE_CALL)
	_dock._action_context_menu.set_item_tooltip(_dock._action_context_menu.item_count - 1,
		"Replace this call with the function's own rows (the inverse of Extract to Function).")
	_dock._action_context_menu.id_pressed.connect(func(id: int) -> void:
		if id == EventSheetRefactorMenu.ACTION_MENU_INLINE_CALL:
			EventSheetRefactorMenu.inline_call_requested(_dock))
	# ── "Why didn't this fire?" (appended block - keep together) ───────────────────────────────
	# Its own handler on the row menu, so the item costs the shared dispatcher nothing: id 9700 is
	# far above the 900+ extension range, where that dispatcher finds no extension item and returns.
	_dock._row_context_menu.id_pressed.connect(func(id: int) -> void:
		if id == ROW_MENU_WHY_DIDNT_FIRE:
			_dock._open_why_didnt_this_fire())
	# ── Find all references (appended block - keep together) ───────────────────────────────────
	# Every place the clicked variable / function / object / signal / behavior is used, in the Find
	# results bar under the sheet. It rides four menus, so the gesture is the same wherever the name
	# is. The three static menus get the item here; the row's More ▸ is rebuilt per right-click, so
	# its item is added there and only the listener lives here.
	for menu: PopupMenu in [_dock._variable_context_menu, _dock._condition_context_menu, _dock._action_context_menu]:
		menu.add_item("Find all references", ROW_MENU_FIND_ALL_REFERENCES)
		menu.set_item_tooltip(menu.item_count - 1, FIND_ALL_REFERENCES_TOOLTIP)
	for menu: PopupMenu in [_dock._variable_context_menu, _dock._condition_context_menu,
			_dock._action_context_menu, _dock._row_more_submenu]:
		menu.id_pressed.connect(func(id: int) -> void:
			if id == ROW_MENU_FIND_ALL_REFERENCES:
				_dock.open_find_all_references())
	# ── The pattern items (appended block - keep together) ────────────────────────────────────
	# Their own listener on the row menu, for the same reason as the two blocks above: 9720 / 9730
	# are far outside every shared dispatcher's range, so these items cost it nothing.
	_dock._row_context_menu.id_pressed.connect(func(id: int) -> void:
		if id == ROW_MENU_EXPLAIN_READING:
			_dock.explain_pattern_reading()
		elif id == ROW_MENU_ADOPT_BEHAVIOR:
			_dock.adopt_pattern_behavior())


## Rebuilds the row context menu for the clicked row: only the items that apply to its
## type (event / group / comment) at the top, universal clipboard/lifecycle next, and
## the rest folded into Insert ▸ / More ▸ submenus - replacing the old flat ~30-item
## list shown for every row regardless of type.
## True for a caption row - a prose line welded above the row it describes, drawn as a COMMENT row but
## backed by no CommentRow. Identified by its span kind so it never depends on a uid convention.
func _is_caption_row(row_data: EventRowData) -> bool:
	if row_data == null or row_data.spans.is_empty():
		return false
	var metadata: Dictionary = row_data.spans[0].metadata if row_data.spans[0].metadata is Dictionary else {}
	return str(metadata.get("kind", "")) == "caption"


func _build_row_context_menu(row_data: EventRowData) -> void:
	var menu: PopupMenu = _dock._row_context_menu
	menu.clear()
	var row_type: int = row_data.row_type if row_data != null else EventRowData.RowType.EVENT
	# A synthetic row (EVENT-typed but with no sheet resource - a data-class field row) must
	# never get the real event menu: its items would act on a null anchor / the sheet root.
	var is_event: bool = row_type == EventRowData.RowType.EVENT and (row_data == null or row_data.source_resource != null)
	var is_group: bool = row_type == EventRowData.RowType.GROUP
	# A region is its own row type with its own verbs: it holds no locals, it cannot be
	# switched off, and the two things it CAN become (a group, or nothing at all) are refactors the
	# group menu has no item for. Only an OPENING fence gets them - a closer is the same region.
	var is_region: bool = row_type == EventRowData.RowType.REGION \
		and row_data != null and EventSheetRegionFacts.is_opening_fence(row_data.source_resource)
	# A CAPTION row (a published verb's @ace_description, or any caption an extension builds through
	# EventSheets.build_caption_row) renders as a COMMENT row but has NO CommentRow behind it, so it must
	# not offer Edit Comment / Attach To Event Above - both handlers cast source_resource to CommentRow
	# and would act on null. Captions are identified by their span kind, not by a null resource: plenty
	# of ordinary comment rows are built without one.
	var is_comment: bool = row_type == EventRowData.RowType.COMMENT and not _is_caption_row(row_data)
	var multi: bool = _dock._get_selected_rows_from_context().size() > 1
	# Type-specific authoring first. (Open/Close Group and the disable label below are
	# relabeled to the live state by _configure_context_menu before the popup shows.)
	# Data-class rows are checked BEFORE the row-type chain: both the holder and its field
	# rows report RowType.EVENT (they read like events), so an is_event-first dispatch
	# would swallow them and the field-authoring items could never appear.
	var added_type_items: bool = true
	# A published verb (Define) row reads as an EVENT row so it lays out in the two-lane model, so it is
	# checked BEFORE the row-type chain for the same reason data-class rows are: an is_event-first
	# dispatch would swallow it, replacing verb authoring with Add Sub-Event / Make Else - whose handlers
	# assume an EventRow anchor the verb does not have.
	# A top-level structured collection declaration gets a scoped menu: its whole vocabulary is
	# entries. Checked before the row-type chain for the same reason verb and data-class rows
	# are - it reads as a SECTION row, and the generic items would act on the wrong anchor.
	var decl_row: CollectionDeclRow = row_data.source_resource as CollectionDeclRow if row_data != null else null
	if decl_row != null:
		menu.add_item("Add Entry…", _dock.ACTION_MENU_DECL_ADD_ENTRY)
		var decl_entry: int = _dock._context_decl_entry_index()
		if decl_entry >= 0 and decl_entry < decl_row.entry_values.size():
			menu.add_item("Edit Entry…", _dock.ACTION_MENU_DECL_EDIT_ENTRY)
			menu.add_item("Remove Entry", _dock.ACTION_MENU_DECL_REMOVE_ENTRY)
		return
	var verb_function: EventFunction = row_data.source_resource as EventFunction if row_data != null else null
	var data_class_raw: RawCodeRow = _data_class_row_target(row_data)
	if verb_function != null:
		# A published-verb (Define) header row: edit the verb, or add a parameter to it right here -
		# the same right-click-to-add-an-argument gesture a visual event editor gives its functions.
		menu.add_item("Edit Function…", _dock.ROW_MENU_EDIT_FUNCTION)
		menu.add_item("Add Parameter", _dock.ROW_MENU_ADD_FUNCTION_PARAM)
		# What makes this function a message is an `@rpc` line above it, so the gesture that
		# writes that line lives on the function's own row. The menu is built per right-click, so the
		# item reads the live state: a function that already is one opens the same dialog to change it.
		menu.add_item(
			"Change The Message…" if EventSheetMessageFacts.is_message(verb_function) else "Make It A Message…",
			_dock.ROW_MENU_MAKE_MESSAGE)
		# On an OPENED behaviour pack a verb's body is read-only by default (protecting the .gd round-trip);
		# offer a per-function opt-in to edit THIS verb's body. Authored sheets edit every body already, and
		# a read-only preview edits nothing, so the toggle only appears for an editable opened pack.
		var verb_sheet: EventSheetResource = _dock._current_sheet
		if verb_sheet != null and not verb_sheet.read_only and not verb_sheet.external_source_path.strip_edges().is_empty():
			var verb_name: String = verb_function.function_name
			var already_editable: bool = _dock._active_view().is_function_body_editable_opt_in(verb_name)
			menu.add_item("Lock Function Body (read-only)" if already_editable else "Make Function Body Editable", _dock.ROW_MENU_MAKE_FUNCTION_EDITABLE)
	elif data_class_raw != null:
		# A lifting data-class holder row, or one of its FIELD rows: field authoring
		# follows the add/remove-action gesture (one resolver decides for menu + handlers).
		menu.add_item("Add Field…", _dock.ROW_MENU_DATA_CLASS_ADD_FIELD)
		if _data_class_field_index(row_data) >= 0:
			menu.add_item("Remove Field", _dock.ROW_MENU_DATA_CLASS_REMOVE_FIELD)
		if row_data != null and row_data.source_resource == null:
			# A FIELD row is synthetic (no sheet resource): the universal Cut / Insert /
			# Delete items would act on the sheet root, so its menu stays field-only.
			return
	elif is_event:
		# The three event-shape commands every event sheet has, in the words the sheet reads them
		# in: everything the reading shows must be authorable in the same words, so a beginner who
		# reads "Or" can also type "Or". All three are greyed while the sheet is a read-only
		# preview (_configure_context_menu), because a preview never rewrites the file.
		menu.add_item("Add blank sub-event (B)", _dock.ROW_MENU_ADD_SUB_EVENT)
		menu.add_item("Make 'Or' block", _dock.ROW_MENU_TOGGLE_CONDITION_BLOCK)
		# The event-sheet Else block, top-level like the other event transforms (a reflex authors expect, so it is
		# NOT gated behind Expert mode). Clicking again clears it; _configure_context_menu relabels to
		# the live state ("Clear 'Else'" / "Clear 'Else If'").
		menu.add_item("Add 'Else'", _dock.ROW_MENU_MAKE_ELSE)
		menu.add_item("Add 'Else If'", _dock.ROW_MENU_MAKE_ELIF)
	elif is_group:
		# The group verbs in the order an author reaches for them: everything the group IS in one
		# dialog, the on/off tick, the folds, then the things you do TO a group. Duplicate and Delete
		# are the universal items below, so the group menu does not repeat them.
		menu.add_item("Edit Group…", _dock.ROW_MENU_EDIT_GROUP)
		# Who runs this group over a network, without opening the dialog for the one answer.
		# Filled as it opens, ticked at what the group says now.
		menu.add_submenu_node_item("Runs On", _dock._group_runs_on_submenu, _dock.ROW_MENU_GROUP_RUNS_ON)
		menu.add_check_item("Active On Start", _dock.ROW_MENU_GROUP_ENABLED)
		menu.add_item("Open / Close Group", _dock.ROW_MENU_TOGGLE_GROUP_FOLD)
		menu.add_item("Open All / Close All Groups", _dock.ROW_MENU_FOLD_ALL_GROUPS)
		menu.add_separator()
		menu.add_item("Add Local Variable…", _dock.ROW_MENU_GROUP_ADD_LOCAL)
		menu.add_item("Group Color…", _dock.ROW_MENU_GROUP_COLOR)
		# The way back to the file's own kind of grouping. A group carries two things a region
		# cannot (locals, the runtime switch), so the item says WHY before the click rather than
		# failing after it.
		# A synthetic Arrange-by header reports as a group row but stands for no EventGroup, so it is
		# offered nothing to convert.
		if _dock._context_group() != null:
			menu.add_item("Turn Into Region", _dock.ROW_MENU_GROUP_TO_REGION)
			var region_problem: String = EventSheetRefactor.group_to_region_problem(_dock._context_group())
			if not region_problem.is_empty():
				menu.set_item_text(menu.item_count - 1, "%s - %s" % [
					menu.get_item_text(menu.item_count - 1), region_problem
				])
				menu.set_item_disabled(menu.item_count - 1, true)
		menu.add_item("Ungroup - Keep The Rows", _dock.ROW_MENU_UNGROUP)
	elif is_region:
		# What a region offers: rename the fence, fold it, and the two things it can become.
		# No locals, no on/off switch, no ungroup - a region holds none of that.
		menu.add_item("Rename Region…", _dock.ROW_MENU_REGION_RENAME)
		menu.add_item("Open / Close Region", _dock.ROW_MENU_TOGGLE_GROUP_FOLD)
		menu.add_item("Open All / Close All Regions", _dock.ROW_MENU_FOLD_ALL_REGIONS)
		menu.add_separator()
		menu.add_item("Turn Into Group", _dock.ROW_MENU_REGION_TO_GROUP)
		menu.add_item("Region Color…", _dock.ROW_MENU_GROUP_COLOR)
		menu.add_item("Remove Region - Keep The Rows", _dock.ROW_MENU_REGION_REMOVE)
	elif is_comment:
		menu.add_item("Edit Comment…", _dock.ROW_MENU_EDIT_COMMENT)
		menu.add_item("Attach To Event Above", _dock.ROW_MENU_ATTACH_COMMENT)
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
		menu.add_item("Replace object…", _dock.ROW_MENU_REPLACE_OBJECT)
		menu.add_item("Edit Values Across Selection…", _dock.ROW_MENU_BATCH_EDIT_PARAMS)
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
	# ── "Why didn't this fire?" (appended block - keep together) ───────────────────────────────
	# Only on a real event row with conditions: it explains which condition said no, and a row
	# with nothing to say no has no explanation to give. It opens a panel and draws nothing on
	# the sheet, which is why it can sit on the plain menu instead of behind Simple Mode.
	var why_row: EventRow = row_data.source_resource as EventRow if row_data != null else null
	if is_event and why_row != null and not why_row.conditions.is_empty():
		menu.add_separator()
		menu.add_item("Why didn't this fire?", ROW_MENU_WHY_DIDNT_FIRE)
	# ── The pattern items (appended block - keep together) ────────────────────────────────────
	# An event a reading claimed a pattern on can say why it was read that way, and - when a shipped
	# behavior could take the shape over and this build knows how - offer to do it, preview first.
	var pattern_row: EventRow = row_data.source_resource as EventRow if row_data != null else null
	if is_event and pattern_row != null and _dock._current_sheet != null:
		var claims: Array = EventSheetPatternFacts.claims_for_row(_dock._current_sheet, pattern_row.event_uid)
		if not claims.is_empty():
			menu.add_separator()
			menu.add_item("Explain this reading", ROW_MENU_EXPLAIN_READING)
			for entry: Variant in claims:
				if not EventSheetPatternAdopt.is_adoptable(entry as Dictionary):
					continue
				# Formatted here rather than left as a literal, because the behavior's NAME is part of
				# the offer: an item reading "Adopt behavior:" with nothing after it says nothing.
				menu.add_item(EventSheetL10n.translate("Adopt behavior: %s…") % EventSheetPatternVocabulary.pack_label(
					EventSheetPatternAdopt.adoptable_of(entry as Dictionary)), ROW_MENU_ADOPT_BEHAVIOR)
				break
	# ── Refactor ▸ (appended block - keep together; dock/refactor_menu.gd) ─────────────────────
	# The reverse gestures, grouped: Wrap in Condition…, Unwrap Event, Inline Everywhere and
	# Remove, Duplicate as Variant…. Each lands ordinary rows in ONE undo step; an item that cannot
	# apply to THIS row shows disabled with the reason as its tooltip.
	if EventSheetRefactorMenu.configure_submenu(_dock, row_data):
		menu.add_separator()
		menu.add_submenu_item("Refactor", EventSheetRefactorMenu.SUBMENU_NAME, 882)


## THE data-class resolver - the ONE answer to "which RawCodeRow does this context click
## concern?", used by BOTH the menu builder (visibility) and the dock's Add/Remove Field
## handlers (action targets), so the two can never disagree. Resolution order: the holder
## row's own source_resource (lifting classes only), the clicked span's raw_row metadata,
## then - for dead-space or metadata-less spans on a synthetic FIELD row (source null by
## design) - any of the row's own spans carrying the identity.
func _data_class_row_target(row_data: EventRowData) -> RawCodeRow:
	if row_data != null and row_data.source_resource is RawCodeRow \
			and ViewportRowBuilder.data_class_lifts((row_data.source_resource as RawCodeRow).code):
		return row_data.source_resource as RawCodeRow
	var span_raw: Variant = _dock._context_hit.get("span_metadata", {}).get("raw_row", null)
	if span_raw is RawCodeRow:
		return span_raw as RawCodeRow
	if row_data != null and row_data.source_resource == null:
		for span: SemanticSpan in row_data.spans:
			var row_span_raw: Variant = (span.metadata as Dictionary).get("raw_row", null) if span.metadata is Dictionary else null
			if row_span_raw is RawCodeRow:
				return row_span_raw as RawCodeRow
	return null


## The clicked field's index, resolved the same layered way (hit metadata first, then the
## row's own spans for dead-space clicks). -1 = not a field (the holder row).
func _data_class_field_index(row_data: EventRowData) -> int:
	var hit_index: int = int(_dock._context_hit.get("span_metadata", {}).get("field_index", -1))
	if hit_index >= 0:
		return hit_index
	if row_data != null and row_data.source_resource == null:
		for span: SemanticSpan in row_data.spans:
			if span.metadata is Dictionary and int((span.metadata as Dictionary).get("field_index", -1)) >= 0:
				return int((span.metadata as Dictionary).get("field_index", -1))
	return -1


## The Insert ▸ submenu - a sibling row of any type below the clicked one (plus Event Above,
## the event-sheet reflex for slotting a new event before the current one).
func _build_row_insert_submenu() -> void:
	var m: PopupMenu = _dock._row_insert_submenu
	m.clear()
	m.add_item("Event Above", _dock.ROW_MENU_ADD_EVENT_ABOVE)
	m.add_item("Event Below", _dock.ROW_MENU_ADD_EVENT_BELOW)
	m.add_item("Group", _dock.ROW_MENU_ADD_GROUP_BELOW)
	m.add_item("Comment", _dock.ROW_MENU_ADD_COMMENT_BELOW)
	m.add_item("Variable", _dock.ROW_MENU_ADD_VARIABLE_BELOW)
	m.add_item("Timeline", _dock.ROW_MENU_ADD_TIMELINE_BELOW)
	if _dock._simple_mode:
		# Simple mode keeps Insert to the four everyday row types; the code-leaning ones
		# (raw GDScript, signal handlers, enums) stay available in Expert mode.
		return
	m.add_item("Script Block", _dock.ROW_MENU_ADD_GDSCRIPT_BELOW)
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
		# Make Else / Make Else-If moved to the TOP-LEVEL event menu (an event-sheet reflex, Simple Mode too).
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
	m.add_item("Find all references", ROW_MENU_FIND_ALL_REFERENCES)
	m.set_item_tooltip(m.item_count - 1, FIND_ALL_REFERENCES_TOOLTIP)
	m.add_item("Open in Split", _dock.ROW_MENU_OPEN_IN_SPLIT)
	m.add_separator()
	m.add_item("Save Selection as Snippet…", _dock.ROW_MENU_SAVE_SNIPPET)
	m.add_item("Insert Snippet…", _dock.ROW_MENU_INSERT_SNIPPET)
	m.add_item("Create Code Region…", _dock.ROW_MENU_SURROUND_REGION)
	m.add_item("Replace object…", _dock.ROW_MENU_REPLACE_OBJECT)
	# Paste Special sits beside Replace Object References because it IS that remap, applied on the
	# way in instead of as a second step. Disabled (with the reason) when the clipboard holds no
	# snippet, so the gesture stays discoverable rather than silently absent.
	m.add_item("Paste Special…", _dock.ROW_MENU_PASTE_SPECIAL)
	var has_snippet: bool = EventSheetSnippet.is_snippet_text(EventSheetSnippet.clipboard_text())
	m.set_item_disabled(m.item_count - 1, not has_snippet)
	m.set_item_tooltip(m.item_count - 1, "Paste the copied rows pointed at another object or variable." if has_snippet
		else "Copy some rows first - Paste Special retargets a copied snippet.")


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
		# A read-only preview reads the file but never rewrites it, so the three event-shape
		# commands are greyed there rather than silently doing nothing. Press Edit Events first.
		var previewing: bool = _dock._current_sheet != null and _dock._current_sheet.read_only
		var preview_reason: String = "This is a read-only preview - press Edit Events to change the file." if previewing else ""
		var toggle_index: int = menu.get_item_index(_dock.ROW_MENU_TOGGLE_CONDITION_BLOCK)
		if toggle_index >= 0:
			var selected_events: Array[EventRow] = _dock._get_selected_event_rows_from_context()
			var has_events: bool = not selected_events.is_empty()
			menu.set_item_disabled(toggle_index, previewing or not has_events)
			menu.set_item_tooltip(toggle_index, preview_reason)
			if has_events:
				menu.set_item_text(
					toggle_index,
					(
						"Make 'And' block"
						if _dock._event_rows_use_or_mode(selected_events)
						else "Make 'Or' block"
					)
				)
		var blank_sub_index: int = menu.get_item_index(_dock.ROW_MENU_ADD_SUB_EVENT)
		if blank_sub_index >= 0:
			menu.set_item_disabled(blank_sub_index, previewing)
			menu.set_item_tooltip(blank_sub_index, preview_reason)
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
				menu.set_item_disabled(else_index, previewing or not has_else_events)
				menu.set_item_tooltip(else_index, preview_reason)
				menu.set_item_text(else_index, "Clear 'Else'" if all_else else "Add 'Else'")
			if elif_index >= 0:
				menu.set_item_disabled(elif_index, previewing or not has_else_events)
				menu.set_item_tooltip(elif_index, preview_reason)
				menu.set_item_text(elif_index, "Clear 'Else If'" if all_elif else "Add 'Else If'")
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
		# Active on start is a TICK, so the menu shows the group's live state rather than a verb
		# that has to be read twice to work out which way it goes.
		var group_enabled_index: int = menu.get_item_index(_dock.ROW_MENU_GROUP_ENABLED)
		if group_enabled_index >= 0:
			var switched_group: EventGroup = _dock._context_row.source_resource as EventGroup if _dock._context_row != null else null
			menu.set_item_disabled(group_enabled_index, switched_group == null)
			menu.set_item_checked(group_enabled_index, switched_group != null and switched_group.enabled)
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
		# The Inspector tick shows what is true right now, and a local can never be a property.
		var inspector_index: int = menu.get_item_index(_dock.VARIABLE_MENU_SHOW_IN_INSPECTOR)
		if inspector_index >= 0:
			var can_export: bool = has_variable and str(
				_dock._variables._context_variable.get("scope", "")) != "local"
			menu.set_item_disabled(inspector_index, not can_export)
			menu.set_item_checked(inspector_index,
				can_export and _dock._variables.context_variable_exported())
			menu.set_item_tooltip(inspector_index, "" if can_export
				else "A local lives inside its event - it is never a property of the object.")
		# A scene is where replication lives, so a script no scene runs has nothing to keep in
		# step, and a local lives inside its event rather than on the object a synchronizer watches.
		var sync_index: int = menu.get_item_index(_dock.VARIABLE_MENU_KEEP_IN_STEP)
		if sync_index >= 0:
			var scene_node: String = _dock._variables.context_variable_scene_node()
			var syncable: bool = has_variable and not scene_node.is_empty() \
				and str(_dock._variables._context_variable.get("scope", "")) != "local"
			menu.set_item_disabled(sync_index, not syncable)
			menu.set_item_tooltip(sync_index, "" if syncable
				else "Replication is a fact of the scene, and no scene runs this script on an object yet.")
		var copy_index: int = menu.get_item_index(_dock.VARIABLE_MENU_COPY_EXPRESSION)
		if copy_index >= 0:
			menu.set_item_disabled(copy_index, not has_variable)
		var grid_variable: bool = has_variable and EventSheetGridCSVDialog.is_grid_variable(_dock._variables._context_variable)
		for grid_id: int in [_dock.VARIABLE_MENU_GRID_EXPORT, _dock.VARIABLE_MENU_GRID_IMPORT,
				_dock.VARIABLE_MENU_TEXT_EXPORT, _dock.VARIABLE_MENU_TEXT_IMPORT]:
			var grid_index: int = menu.get_item_index(grid_id)
			if grid_index >= 0:
				menu.set_item_disabled(grid_index, not grid_variable)
				menu.set_item_tooltip(grid_index, "" if grid_variable
					else "Only a grid variable (one shown as a table in the Inspector) has columns to line up in a spreadsheet.")
		# An accessor belongs to a sheet-level variable that does not already have one. A local
		# lives and dies with its event, and a constant never changes, so neither can take an accessor.
		var accessor_variable: LocalVariable = _dock._variables._context_variable.get("resource", null) if has_variable else null
		var accessor_scope: bool = accessor_variable != null and not accessor_variable.is_constant
		accessor_scope = accessor_scope and str(_dock._variables._context_variable.get("scope", "")) == "tree"
		for accessor: Array in [[_dock.VARIABLE_MENU_ADD_SETTER, "setter"], [_dock.VARIABLE_MENU_ADD_GETTER, "getter"]]:
			var accessor_index: int = menu.get_item_index(int(accessor[0]))
			if accessor_index < 0:
				continue
			var body: String = ""
			if accessor_variable != null:
				body = accessor_variable.setter_body if str(accessor[1]) == "setter" else accessor_variable.getter_body
			var already: bool = not body.strip_edges().is_empty()
			menu.set_item_disabled(accessor_index, not accessor_scope or already)
			menu.set_item_tooltip(accessor_index, "This variable already has one." if already and accessor_scope
				else ("" if accessor_scope else "Only a sheet variable can carry a setter or a getter."))
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


## The Runs on submenu: the three answers, ticked at the one this group carries now. Built as
## it opens, from the group under the cursor, so a second group's head never shows the first's answer.
func _fill_group_runs_on_submenu() -> void:
	var menu: PopupMenu = _dock._group_runs_on_submenu
	menu.clear()
	var group: EventGroup = _dock._context_group()
	var current: String = group.runs_on.strip_edges() if group != null else ""
	for mode_id: int in [_dock.GROUP_RUNS_ON_EVERYONE, _dock.GROUP_RUNS_ON_HOST, _dock.GROUP_RUNS_ON_OWNER]:
		var value: String = str(_dock.GROUP_RUNS_ON_VALUES[mode_id])
		var choices: Array[Dictionary] = EventSheetGroupFacts.runs_on_choices()
		menu.add_radio_check_item(str(choices[EventSheetGroupFacts.runs_on_index(value)].get("label", "")), mode_id)
		menu.set_item_checked(menu.get_item_count() - 1, current == value)


## The Keep in step submenu, built from the SCENE every time it opens. With a synchronizer it
## leads with that node's name (the mode is written on it, so the reader has to know which one) and
## then the four modes, ticked at the one that is true now. With none it is the single offer to add
## one, because a scene with nothing to replicate cannot be asked in which mode.
func _fill_variable_sync_submenu() -> void:
	var menu: PopupMenu = _dock._variable_sync_submenu
	menu.clear()
	var entry: Dictionary = _dock._variables.context_variable_sync_entry()
	if entry.is_empty() and _dock._variables.context_variable_synchronizer().is_empty():
		menu.add_item(EventSheetL10n.translate("Add a synchronizer to %s…")
			% _dock._variables.context_variable_scene_node(), _dock.VARIABLE_SYNC_ADD)
		return
	var holder: String = str(entry.get("synchronizer", "")) if not entry.is_empty() \
		else _dock._variables.context_variable_synchronizer()
	# A LABELLED separator, not an item: the synchronizer's name is what the four modes are written
	# on, and a heading nobody can press is exactly what a separator is.
	menu.add_separator(holder)
	var current: String = str(entry.get("mode", EventSheetSceneReplication.MODE_OFF)) if not entry.is_empty() \
		else EventSheetSceneReplication.MODE_OFF
	for mode_id: int in [_dock.VARIABLE_SYNC_OFF, _dock.VARIABLE_SYNC_ALWAYS,
			_dock.VARIABLE_SYNC_ON_CHANGE, _dock.VARIABLE_SYNC_AT_SPAWN]:
		var mode: String = str(_dock.VARIABLE_SYNC_MODES[mode_id])
		menu.add_radio_check_item(EventSheetSceneReplication.mode_menu_word(mode), mode_id)
		menu.set_item_checked(menu.get_item_count() - 1, current == mode)
