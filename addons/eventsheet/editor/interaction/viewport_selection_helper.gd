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
		selected_row_uids[row_data.row_uid] = true
		var is_group: bool = row_data.row_type == EventRowData.RowType.GROUP
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

static func sync_row_selection_flags(flat_rows: Array, selected_row_uids: Dictionary) -> void:
	for entry in flat_rows:
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		row_data.selected = selected_row_uids.has(row_data.row_uid)

static func apply_hover_state(flat_rows: Array, hovered_row_index: int) -> void:
	for index in range(flat_rows.size()):
		var row_data: EventRowData = flat_rows[index].get("row")
		if row_data == null:
			continue
		row_data.hovered = index == hovered_row_index
