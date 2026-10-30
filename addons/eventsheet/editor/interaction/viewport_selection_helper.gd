@tool
class_name ViewportSelectionHelper
extends RefCounted


static func build_single_selection(
	flat_rows: Array,
	row_index: int,
	span_index: int,
	focused_lane: String,
	include_descendants: Callable,
	resolve_lane: Callable
) -> Dictionary:
	var selected_row_uids: Dictionary = {}
	var selected_span_indices: Dictionary = {}
	var selected_row_index: int = -1
	var selected_span_index: int = -1
	var selection_anchor_index: int = -1
	var resolved_focused_lane: String = focused_lane
	if flat_rows.is_empty():
		return {
			"selected_row_uids": selected_row_uids,
			"selected_span_indices": selected_span_indices,
			"selected_row_index": selected_row_index,
			"selected_span_index": selected_span_index,
			"selection_anchor_index": selection_anchor_index,
			"focused_lane": resolved_focused_lane
		}
	selected_row_index = clampi(row_index, 0, flat_rows.size() - 1)
	selected_span_index = span_index
	selection_anchor_index = selected_row_index
	var row_data: EventRowData = flat_rows[selected_row_index].get("row")
	if row_data != null:
		# The ROW set is keyed on the statement, so clicking any row of a ternary pair selects the one
		# statement all of its rows read. The SPAN set stays keyed on the clicked row's own uid - a span
		# index only means anything against the spans it was measured on.
		selected_row_uids[row_data.statement_uid()] = true
		var is_group: bool = row_data.row_type in [
			EventRowData.RowType.GROUP, EventRowData.RowType.REGION
		]
		if span_index >= 0 and not is_group:
			selected_span_indices[row_data.row_uid] = [span_index]
		if not row_data.children.is_empty() and (span_index < 0 or is_group):
			var descendant_uids: Array = include_descendants.call(row_data)
			for descendant_uid in descendant_uids:
				selected_row_uids[str(descendant_uid)] = true
		resolved_focused_lane = str(resolve_lane.call(row_data, span_index))
	return {
		"selected_row_uids": selected_row_uids,
		"selected_span_indices": selected_span_indices,
		"selected_row_index": selected_row_index,
		"selected_span_index": selected_span_index,
		"selection_anchor_index": selection_anchor_index,
		"focused_lane": resolved_focused_lane
	}


## Paints the selection highlight. A row is lit when its STATEMENT is selected, which is what makes a
## ternary pair highlight as ONE selection: the head, both branch rows and the Else all answer with
## the same statement uid, so one click lights the whole pair and none of them can be lit alone.
static func sync_row_selection_flags(flat_rows: Array, selected_row_uids: Dictionary) -> void:
	for entry in flat_rows:
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		row_data.selected = selected_row_uids.has(row_data.statement_uid())


static func apply_hover_state(flat_rows: Array, hovered_row_index: int) -> void:
	for index in range(flat_rows.size()):
		var row_data: EventRowData = flat_rows[index].get("row")
		if row_data == null:
			continue
		row_data.hovered = index == hovered_row_index


## THE SELECTION AS RUNS. Selected rows that touch are one selection mark: one frame and one fill
## around the run, never a frame per row. Rows `first` to `last` are read in order, and each run comes
## back as {"first", "last", "has_event", "statements"}:
##   - an EVENT starts its own run and keeps every selected row under it (its local lines, its
##     sub-events, the rows of a statement that reads as several) - selecting a parent selects its
##     subtree, so the branch is one frame from the parent's top to its last child's bottom;
##   - a second event at the parent's own depth or shallower starts a new run: two events picked
##     side by side are two things, and two frames say so;
##   - neighbouring variable, enum and signal lines are one run, and an event after them starts its own;
##   - a row that is not selected, or a statement whose CELL is the selection, ends the run - a cell
##     keeps its own small outline, which is how a cell reads apart from an event.
## `statements` counts the statements in the run (the rows of one ternary pair count once).
## The rows are asked through callables so a test can hand in plain rows:
##   row_at(index) -> EventRowData, lead_of(index) -> int (the statement's first row),
##   cell_selected(index) -> bool.
static func selection_runs(first: int, last: int, row_at: Callable, lead_of: Callable,
		cell_selected: Callable) -> Array:
	var runs: Array = []
	var run: Dictionary = {}
	var head_indent: int = -1
	for index: int in range(first, last + 1):
		var row_data: EventRowData = row_at.call(index) as EventRowData
		if row_data == null or not row_data.selected or bool(cell_selected.call(index)):
			if not run.is_empty():
				runs.append(run)
			run = {}
			continue
		var lead: int = int(lead_of.call(index))
		var continues_statement: bool = lead != index and not run.is_empty() and int(run["last"]) >= lead
		var starts_event: bool = row_data.row_type == EventRowData.RowType.EVENT and not continues_statement
		var joins: bool = false
		if not run.is_empty():
			if continues_statement:
				joins = true
			elif head_indent >= 0:
				joins = row_data.indent > head_indent
			else:
				joins = not starts_event
		if not joins:
			if not run.is_empty():
				runs.append(run)
			run = {"first": index, "last": index, "has_event": starts_event, "statements": 1}
			head_indent = row_data.indent if starts_event else -1
			continue
		run["last"] = index
		if not continues_statement:
			run["statements"] = int(run["statements"]) + 1
	if not run.is_empty():
		runs.append(run)
	return runs
