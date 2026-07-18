# Godot EventSheets - keyboard cell navigation (C3's arrow-through-cells): Left/Right walk
# the selected event's ACE cells (trigger, conditions, actions), Enter edits the focused
# cell (the existing handler), Esc drops back to row selection. Pins: the interactive-span
# walk (kinds, order), stepping (entry, clamped ends), and the Esc clear.
@tool
class_name CellNavigationTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false


static func _action(message: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({message})"
	action.params = {"message": message}
	return action


static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnReady"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "ExpressionIsTrue"
	condition.codegen_template = "{expression}"
	condition.params = {"expression": "score > 3"}
	event_row.conditions.append(condition)
	event_row.actions.append(_action("\"one\""))
	event_row.actions.append(_action("\"two\""))
	sheet.events.append(event_row)

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var event_index: int = -1
	var flat_rows: Array = viewport.get_flat_rows()
	for index in range(flat_rows.size()):
		var row_data: EventRowData = (flat_rows[index] as Dictionary).get("row")
		if row_data != null and row_data.source_resource == event_row:
			event_index = index
	var event_row_data: EventRowData = (flat_rows[event_index] as Dictionary).get("row")

	# ---- the walk: cells in span order, kinds trigger/condition then actions ----
	var cells: Array[int] = viewport.interactive_span_indices(event_row_data)
	var kinds: Array = []
	for span_index: int in cells:
		kinds.append(str((event_row_data.spans[span_index] as SemanticSpan).metadata.get("kind", "")))
	all_passed = _check("the walk finds all four cells in lane order",
		str(kinds), str(["trigger", "condition", "action", "action"])) and all_passed

	# ---- stepping: entry from row scope, clamped ends, Esc clears ----
	viewport._select_row(event_index, -1)
	all_passed = _check("Right from row scope focuses the first cell", viewport.step_cell_focus(1), true) and all_passed
	all_passed = _check("the first cell is the trigger", viewport._selected_span_index, cells[0]) and all_passed
	all_passed = _check("Left at the first cell stays put (clamped, key falls through)", viewport.step_cell_focus(-1), false) and all_passed
	viewport.step_cell_focus(1)
	viewport.step_cell_focus(1)
	viewport.step_cell_focus(1)
	all_passed = _check("three Rights land on the last action", viewport._selected_span_index, cells[3]) and all_passed
	all_passed = _check("Right at the last cell stays put", viewport.step_cell_focus(1), false) and all_passed
	all_passed = _check("Esc clears the cell focus", viewport.clear_cell_focus(), true) and all_passed
	all_passed = _check("the row selection survives the clear", viewport._selected_row_index, event_index) and all_passed
	all_passed = _check("a second Esc has nothing to clear (key falls through)", viewport.clear_cell_focus(), false) and all_passed

	# ---- Left vs fold (review regression): with a cell focused, Left steps back - it
	# must NOT fold an unfolded parent row out from under the cell walk ----
	var parent_row: EventRow = EventRow.new()
	parent_row.trigger_provider_id = "Core"
	parent_row.trigger_id = "OnProcess"
	parent_row.actions.append(_action("\"tick\""))
	var child_row: EventRow = EventRow.new()
	child_row.trigger_provider_id = "Core"
	child_row.trigger_id = "OnReady"
	parent_row.sub_events.append(child_row)
	sheet.events.append(parent_row)
	editor._refresh_after_edit()
	viewport.select_resource(parent_row)
	all_passed = _check("Left folds an unfolded parent at row scope", viewport.left_key_folds(), true) and all_passed
	viewport.step_cell_focus(1)
	all_passed = _check("with a cell focused, Left belongs to the cell walk (no fold)", viewport.left_key_folds(), false) and all_passed
	viewport.clear_cell_focus()
	all_passed = _check("clearing the cell focus gives Left back to folding", viewport.left_key_folds(), true) and all_passed

	# ---- Right vs unfold (the mirror): a folded parent still renders its OWN cells, so a
	# focused cell must make Right step the walk, not unfold the row out from under it ----
	viewport._toggle_row_fold(viewport._selected_row_index)
	all_passed = _check("Right unfolds a folded parent at row scope", viewport.right_key_unfolds(), true) and all_passed
	viewport.step_cell_focus(1)
	all_passed = _check("with a cell focused, Right belongs to the cell walk (no unfold)", viewport.right_key_unfolds(), false) and all_passed
	viewport.clear_cell_focus()
	all_passed = _check("clearing the cell focus gives Right back to unfolding", viewport.right_key_unfolds(), true) and all_passed
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] cell_navigation_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
