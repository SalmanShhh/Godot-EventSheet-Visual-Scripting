@tool
class_name EventSheetRefactorMenu
extends RefCounted
# The row menu's Refactor ▸ submenu - the reverse gestures, all in one place.
#
#   Wrap in Condition…          guard a run of actions you already wrote (editor/wrap_unwrap.gd)
#   Unwrap Event                lift a guarded sub-event's rows back up (editor/wrap_unwrap.gd)
#   Inline This Call            put a verb's body back at the call site (editor/inline_function.gd)
#   Inline Everywhere, Remove   fold a verb into every caller and un-publish it
#   Duplicate as Variant…       copy the selection with names swapped (editor/duplicate_variant.gd)
#
# They sit together because they are one idea with several directions: the editor could always
# CREATE structure (Group, Region, Add Sub-Event, Extract to Function) and never reshape it. Each
# one produces ORDINARY ROWS in the right lanes and lands as ONE undo step, so a refactor is
# something you try rather than something you commit to.
#
# All state-free: every entry point takes the dock, so nothing new is stored on it and the submenu
# node is found by name (the same way the shipped Insert ▸ / More ▸ submenus are reached). The
# transforms themselves are pure statics in editor/*.gd, which is what lets the suite drive them
# with no menu on screen at all.

const SUBMENU_NAME := "RowRefactorSubmenu"

## Submenu ids. Private to this file: the submenu owns its own id_pressed (like the shipped New
## Function ▸ submenu), so these never meet the dock's ROW_MENU_* numbering.
const MENU_WRAP := 1
const MENU_UNWRAP := 2
const MENU_INLINE_EVERYWHERE := 3
const MENU_DUPLICATE_VARIANT := 4

## The action context menu's "Inline This Call" id. Deliberately far outside the dock's
## ACTION_MENU_* range: that dispatcher matches its own ids and ignores everything else, so the
## two handlers on one popup never collide.
const ACTION_MENU_INLINE_CALL := 720


## Creates the Refactor ▸ submenu as a child of the row menu, once, wired to its own dispatcher.
static func build_submenu(dock: Control) -> PopupMenu:
	var submenu: PopupMenu = PopupMenu.new()
	submenu.name = SUBMENU_NAME
	submenu.id_pressed.connect(func(id: int) -> void: dispatch(dock, id))
	return submenu


## Fills the submenu for the clicked row and answers whether it has anything to offer. Items that
## cannot apply are shown DISABLED with the reason as their tooltip - a refusal you can read beats
## a gesture that silently is not there.
static func configure_submenu(dock: Control, row_data: EventRowData) -> bool:
	var submenu: PopupMenu = dock._row_context_menu.get_node_or_null(SUBMENU_NAME) as PopupMenu
	if submenu == null:
		return false
	submenu.clear()
	var event: EventRow = row_data.source_resource as EventRow if row_data != null else null
	var function: EventFunction = row_data.source_resource as EventFunction if row_data != null else null
	if event != null:
		submenu.add_item("Wrap in Condition…", MENU_WRAP)
		var wrap_problem: String = EventSheetWrapUnwrap.wrap_refusal(event, _wrap_targets(dock, event))
		submenu.set_item_disabled(submenu.item_count - 1, not wrap_problem.is_empty())
		submenu.set_item_tooltip(submenu.item_count - 1, wrap_problem if not wrap_problem.is_empty()
			else "Move these actions into a fresh sub-event guarded by a condition you pick.")
		submenu.add_item("Unwrap Event", MENU_UNWRAP)
		var unwrap_problem: String = EventSheetWrapUnwrap.unwrap_refusal(dock._current_sheet, event)
		submenu.set_item_disabled(submenu.item_count - 1, not unwrap_problem.is_empty())
		submenu.set_item_tooltip(submenu.item_count - 1, unwrap_problem if not unwrap_problem.is_empty()
			else "Lift this sub-event's rows into the event above it and drop the empty shell.")
	if function != null:
		submenu.add_item("Inline Everywhere and Remove", MENU_INLINE_EVERYWHERE)
		var fold_problem: String = EventSheetInlineOps.inline_everywhere_refusal(dock._current_sheet, function)
		submenu.set_item_disabled(submenu.item_count - 1, not fold_problem.is_empty())
		submenu.set_item_tooltip(submenu.item_count - 1, fold_problem if not fold_problem.is_empty()
			else "Put this verb's rows back at every call site, then remove the verb.")
	submenu.add_item("Duplicate as Variant…", MENU_DUPLICATE_VARIANT)
	submenu.set_item_tooltip(submenu.item_count - 1, "Copy the selection with objects and variable names swapped, in one step.")
	return submenu.item_count > 0


static func dispatch(dock: Control, id: int) -> void:
	match id:
		MENU_WRAP:
			wrap_requested(dock)
		MENU_UNWRAP:
			unwrap_requested(dock)
		MENU_INLINE_EVERYWHERE:
			inline_everywhere_requested(dock)
		MENU_DUPLICATE_VARIANT:
			duplicate_variant_requested(dock)


## Wrap: the ACE picker opens in its sub-condition mode (so it lists conditions and triggers, and
## titles itself Add Sub-Event, which is what a wrap makes), carrying the actions to re-parent.
## The dock's apply funnel builds the guard from the picked condition and hands the actions to
## EventSheetWrapUnwrap inside the SAME undoable edit, which is why the whole wrap is one step.
static func wrap_requested(dock: Control) -> void:
	var event: EventRow = dock._context_row.source_resource as EventRow if dock._context_row != null else null
	if event == null:
		dock._set_status("Right-click an event (or a run of its actions) to wrap it in a condition.", true)
		return
	var to_wrap: Array = _wrap_targets(dock, event)
	var problem: String = EventSheetWrapUnwrap.wrap_refusal(event, to_wrap)
	if not problem.is_empty():
		dock._set_status(problem, true)
		return
	dock._ace_picker.open("new_sub_condition_event", false, event, {"wrap_actions": to_wrap})


static func unwrap_requested(dock: Control) -> void:
	var event: EventRow = dock._context_row.source_resource as EventRow if dock._context_row != null else null
	var problem: String = EventSheetWrapUnwrap.unwrap_refusal(dock._current_sheet, event)
	if not problem.is_empty():
		dock._set_status(problem, true)
		return
	var lifted: Dictionary = {"count": 0}
	var changed: bool = dock._perform_undoable_sheet_edit("Unwrap Event", func() -> bool:
		lifted["count"] = EventSheetWrapUnwrap.unwrap_event(dock._current_sheet, event)
		return int(lifted["count"]) >= 0
	)
	if changed:
		dock._mark_dirty("Unwrapped the sub-event - %d row(s) moved up one level." % int(lifted["count"]))


## Inline This Call: the right-clicked action cell, replaced by the verb's own rows.
static func inline_call_requested(dock: Control) -> void:
	var event: EventRow = dock._context_row.source_resource as EventRow if dock._context_row != null else null
	var call_index: int = int(dock._context_hit.get("ace_index", -1))
	var problem: String = EventSheetInlineOps.inline_refusal(dock._current_sheet, event, call_index)
	if not problem.is_empty():
		dock._set_status(problem, true)
		return
	var verb_name: String = EventSheetInlineOps.called_function_name(event.actions[call_index])
	var body_rows: int = EventSheetInlineOps.body_actions(EventSheetInlineOps.find_function(dock._current_sheet, verb_name)).size()
	var changed: bool = dock._perform_undoable_sheet_edit("Inline This Call", func() -> bool:
		return EventSheetInlineOps.inline_function_call(dock._current_sheet, event, call_index)
	)
	if changed:
		dock._mark_dirty(EventSheetInlineOps.summary(verb_name, 1, body_rows))


## Inline Everywhere and Remove: every call site folded back in and the verb un-published, as one
## undo step - the exact inverse of Extract to Function, so a premature abstraction is reversible.
static func inline_everywhere_requested(dock: Control) -> void:
	var function: EventFunction = dock._context_row.source_resource as EventFunction if dock._context_row != null else null
	var problem: String = EventSheetInlineOps.inline_everywhere_refusal(dock._current_sheet, function)
	if not problem.is_empty():
		dock._set_status(problem, true)
		return
	var verb_name: String = function.function_name
	var body_rows: int = EventSheetInlineOps.body_actions(function).size()
	var folded: Dictionary = {"sites": 0}
	var changed: bool = dock._perform_undoable_sheet_edit("Inline Everywhere and Remove", func() -> bool:
		# Re-fetched from the LIVE sheet: the funnel replaces resources on commit, and the row that
		# opened this menu belongs to the sheet as it was when the menu opened.
		var live: EventFunction = EventSheetInlineOps.find_function(dock._current_sheet, verb_name)
		folded["sites"] = EventSheetInlineOps.inline_everywhere_and_remove(dock._current_sheet, live)
		return int(folded["sites"]) >= 0
	)
	if changed:
		dock._refresh_functions_list()
		dock._mark_dirty(EventSheetInlineOps.summary(verb_name, int(folded["sites"]), body_rows))


static func duplicate_variant_requested(dock: Control) -> void:
	var rows: Array = dock._top_level_selected_resources()
	if rows.is_empty() and dock._context_row != null and dock._context_row.source_resource != null:
		rows = [dock._context_row.source_resource]
	if rows.is_empty():
		dock._set_status("Select the rows to make a variant of first.", true)
		return
	EventSheetDuplicateVariantDialog.open_for(dock, rows)


## What a wrap would take: the selected action cells of this event, or - with none selected - all
## of its actions, which is the everyday gesture ("guard everything this event does").
static func _wrap_targets(dock: Control, event: EventRow) -> Array:
	if event == null:
		return []
	var selected: Array = []
	var view: EventSheetViewport = dock._active_view()
	if view != null:
		for entry: Variant in view.get_selected_ace_entries():
			if not (entry is Dictionary) or (entry as Dictionary).get("source_resource") != event:
				continue
			if str((entry as Dictionary).get("kind", "")) != "action":
				continue
			var action_index: int = int((entry as Dictionary).get("ace_index", -1))
			if action_index >= 0 and action_index < event.actions.size() and not selected.has(event.actions[action_index]):
				selected.append(event.actions[action_index])
	return selected if not selected.is_empty() else event.actions.duplicate()
