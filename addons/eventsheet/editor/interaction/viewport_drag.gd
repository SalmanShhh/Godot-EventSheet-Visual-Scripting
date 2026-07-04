@tool
class_name ViewportDragInteractions
extends RefCounted
# The DRAG interactions of the event sheet's virtualized viewport, extracted from
# event_sheet_viewport.gd to keep that file maintainable. Three gestures live here,
# plus their shared feedback painting:
#
#   - BOX SELECTION: click-drag on empty canvas sweeps rows/ACE cells into the
#     selection (begin / complete / apply / the translucent overlay rect),
#   - WHOLE-ROW DRAG: grab an event's empty lane band to reorder or nest rows
#     (multi-select aware; the ghost label names the payload),
#   - ACE DRAG: grab a condition/action cell to reorder within a lane or move/copy
#     it across events (target tracking, before/after resolution against the cell
#     midpoint, drop validation with error feedback, the drop request signal).
#
# All drag STATE (_drag_* fields, box-select fields) stays on the viewport - the
# layout pass keys its cache on that state and multi-view panes isolate it, so it
# must not move. Bodies were rewritten VERBATIM through the `_viewport.` backref;
# the viewport keeps one-line delegates so input handlers and tests are untouched.

var _viewport: Control = null


func init(viewport: Control) -> void:
	_viewport = viewport


func begin_box_selection(position: Vector2, additive: bool) -> void:
	_viewport._clear_row_drag()
	_viewport._clear_ace_drag()
	_viewport._box_select_active = true
	_viewport._box_select_additive = additive
	_viewport._box_select_start = position
	_viewport._box_select_current = position
	if not additive:
		_viewport._clear_selection()
	_viewport.queue_redraw()


func complete_box_selection() -> void:
	if not _viewport._box_select_active:
		return
	var selection_rect: Rect2 = Rect2(_viewport._box_select_start, Vector2.ZERO).expand(_viewport._box_select_current)
	if selection_rect.size.length_squared() <= _viewport.MIN_BOX_SELECT_DISTANCE_SQ:
		_viewport._box_select_active = false
		_viewport._box_select_additive = false
		_viewport.queue_redraw()
		return
	_viewport._apply_box_selection(selection_rect, _viewport._box_select_additive)
	_viewport._box_select_active = false
	_viewport._box_select_additive = false
	_viewport.queue_redraw()


func draw_box_selection_overlay() -> void:
	if not _viewport._box_select_active:
		return
	var selection_rect: Rect2 = Rect2(_viewport._box_select_start, Vector2.ZERO).expand(_viewport._box_select_current)
	if selection_rect.size.length_squared() <= _viewport.MIN_BOX_SELECT_DISTANCE_SQ:
		return
	var selection_fill: Color = _viewport._get_event_style().selection_fill_color
	var selection_outline: Color = selection_fill.lightened(0.22)
	selection_outline.a = max(selection_fill.a, 0.9)
	_viewport.draw_rect(selection_rect, selection_fill, true)
	_viewport.draw_rect(selection_rect, selection_outline, false, 1.0)


func apply_box_selection(selection_rect: Rect2, additive: bool) -> void:
	if not additive:
		_viewport._selected_row_uids.clear()
		_viewport._selected_span_indices.clear()
		_viewport._span_only_row_uids.clear()
		_viewport._selected_row_index = -1
		_viewport._selected_span_index = -1
	var selected_any: bool = false
	var sel_top: float = minf(selection_rect.position.y, selection_rect.end.y)
	var sel_bottom: float = maxf(selection_rect.position.y, selection_rect.end.y)
	for row_index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._row_at(row_index)
		if row_data == null:
			continue
		# Footer "Add event…" affordances are never part of a selection.
		if _viewport._row_is_add_event_footer(row_data):
			continue
		# Skip rows whose vertical extent does not overlap the selection box using the
		# cheap precomputed metrics, so a box drag never builds layout/spans for the
		# whole sheet (only for rows the box actually touches).
		var row_top: float = _viewport._get_row_top(row_index)
		if row_top + _viewport._get_row_height(row_index) < sel_top or row_top > sel_bottom:
			continue
		var layout: Dictionary = _viewport._get_or_build_row_layout(
			row_index,
			_viewport._get_logical_canvas_width(),
			_viewport._get_font(),
			_viewport._get_font_size()
		)
		var row_rect: Rect2 = layout.get("row_rect", Rect2())
		if not row_rect.intersects(selection_rect):
			continue
		_viewport._selected_row_uids[row_data.row_uid] = true
		# Box selection selects the whole row, so it is no longer span-only provenance.
		_viewport._span_only_row_uids.erase(row_data.row_uid)
		_viewport._selected_row_index = row_index
		_viewport._selected_span_index = -1
		selected_any = true
		for span_index in range(row_data.spans.size()):
			var span: SemanticSpan = row_data.spans[span_index]
			if span == null or not span.rect.intersects(selection_rect):
				continue
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			var kind: String = str(metadata.get("kind", ""))
			if kind not in ["trigger", "condition", "action"]:
				continue
			var span_indices: Array = _viewport._selected_span_indices.get(row_data.row_uid, [])
			if not span_indices.has(span_index):
				span_indices.append(span_index)
				_viewport._selected_span_indices[row_data.row_uid] = span_indices
			_viewport._selected_row_index = row_index
			_viewport._selected_span_index = span_index
			_viewport._focused_lane = _viewport._resolve_lane_for_row(row_data, span_index)
			selected_any = true
	if selected_any:
		_viewport._selection_anchor_index = _viewport._selected_row_index
	_viewport._sync_row_selection_flags()
	_viewport.selection_changed.emit(_viewport._row_at(_viewport._selected_row_index))


func is_selection_hit(row_index: int, span_index: int) -> bool:
	var row_data: EventRowData = _viewport._row_at(row_index)
	if row_data == null:
		return false
	var row_uid: String = row_data.row_uid
	if not _viewport._selected_row_uids.has(row_uid):
		return false
	if span_index < 0:
		return true
	var span_indices: Array = _viewport._selected_span_indices.get(row_uid, [])
	if span_indices.is_empty():
		return true
	return span_indices.has(span_index)


func begin_row_drag(row_index: int) -> void:
	if row_index < 0:
		_viewport._clear_row_drag()
		return
	var selected_indices: Array[int] = _viewport._get_selected_row_indices()
	if selected_indices.size() > 1 and selected_indices.has(row_index):
		_viewport._drag_row_indices = selected_indices
	else:
		_viewport._drag_row_indices = [row_index] as Array[int]
	_viewport._drag_row_index = row_index
	_viewport._drag_target_index = -1
	_viewport._drag_target_mode = "before"
	_viewport._drag_ghost_label = (
		"%d rows" % _viewport._drag_row_indices.size()
		if _viewport._drag_row_indices.size() > 1
		else _viewport._row_ghost_label(_viewport._row_at(row_index))
	)


## First meaningful text on a row, used as the drag-ghost label.
func row_ghost_label(row_data: EventRowData) -> String:
	if row_data == null:
		return "Row"
	for span in row_data.spans:
		if span == null or span.text.strip_edges().is_empty():
			continue
		if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("badge", false)):
			continue
		return span.text
	return "Row"


func clear_row_drag() -> void:
	_viewport._drag_row_index = -1
	_viewport._drag_row_indices.clear()
	_viewport._drag_target_index = -1
	_viewport._drag_target_mode = "before"
	_viewport._drag_row_copy_mode = false
	_viewport._drag_ghost_label = ""


func maybe_begin_ace_drag(hit: Dictionary, row_index: int) -> bool:
	if row_index < 0:
		_viewport._clear_ace_drag()
		return false
	var row_data: EventRowData = _viewport._row_at(row_index)
	if row_data == null:
		_viewport._clear_ace_drag()
		return false
	var metadata: Dictionary = hit.get("span_metadata", {})
	var kind: String = str(metadata.get("kind", ""))
	if not ["trigger", "condition", "action"].has(kind):
		_viewport._clear_ace_drag()
		return false
	var span_index: int = int(hit.get("span_index", -1))
	var ace_index: int = int(metadata.get("ace_index", -1))
	if ace_index < 0:
		_viewport._clear_ace_drag()
		return false
	_viewport._drag_ace_entries = _viewport._get_draggable_ace_entries(row_data, kind, ace_index, span_index)
	if _viewport._drag_ace_entries.is_empty():
		_viewport._clear_ace_drag()
		return false
	_viewport._drag_ace_target_row_index = -1
	_viewport._drag_ace_target_lane = ""
	_viewport._drag_ace_target_ace_index = -1
	_viewport._drag_ace_insert_mode = "append"
	_viewport._drag_ace_drop_valid = true
	_viewport._clear_drag_feedback()
	_viewport._clear_row_drag()
	# Ghost label set after _viewport._clear_row_drag(), which resets it.
	if _viewport._drag_ace_entries.size() > 1:
		_viewport._drag_ghost_label = "%d selected" % _viewport._drag_ace_entries.size()
	elif span_index >= 0 and span_index < row_data.spans.size() and row_data.spans[span_index] != null:
		_viewport._drag_ghost_label = row_data.spans[span_index].text
	else:
		_viewport._drag_ghost_label = kind.capitalize()
	return true


func clear_ace_drag() -> void:
	_viewport._drag_ace_entries.clear()
	_viewport._drag_ace_target_row_index = -1
	_viewport._drag_ace_target_lane = ""
	_viewport._drag_ace_target_ace_index = -1
	_viewport._drag_ace_insert_mode = "append"
	_viewport._drag_ace_copy_mode = false
	_viewport._drag_ace_drop_valid = true
	_viewport._drag_ghost_label = ""
	_viewport._clear_drag_feedback()


func clear_drag_feedback() -> void:
	_viewport._drag_feedback_text = ""
	_viewport._drag_feedback_is_error = false
	_viewport.tooltip_text = ""


func update_ace_drag_target(hit: Dictionary, position: Vector2) -> void:
	_viewport._drag_ace_target_row_index = -1
	_viewport._drag_ace_target_lane = ""
	_viewport._drag_ace_target_ace_index = -1
	_viewport._drag_ace_insert_mode = "append"
	_viewport._drag_ace_drop_valid = true
	_viewport._clear_drag_feedback()
	if _viewport._drag_ace_entries.is_empty():
		return
	var row_index: int = int(hit.get("row_index", -1))
	if row_index < 0:
		_viewport.queue_redraw()
		return
	var row_data: EventRowData = _viewport._row_at(row_index)
	if row_data == null or not (row_data.source_resource is EventRow):
		_viewport.queue_redraw()
		return
	var drag_kind: String = str(_viewport._drag_ace_entries[0].get("kind", ""))
	var drag_lane: String = "action" if drag_kind == "action" else "condition"
	var lane: String = str(hit.get("lane", drag_lane))
	if lane != drag_lane:
		_viewport.queue_redraw()
		return
	var metadata: Dictionary = hit.get("span_metadata", {})
	var kind: String = str(metadata.get("kind", ""))
	_viewport._drag_ace_target_row_index = row_index
	_viewport._drag_ace_target_lane = lane
	if kind == drag_kind:
		_viewport._drag_ace_target_ace_index = int(metadata.get("ace_index", -1))
		var span_index: int = int(hit.get("span_index", -1))
		if span_index >= 0 and span_index < row_data.spans.size():
			var span_rect: Rect2 = row_data.spans[span_index].rect
			# Conditions/actions stack vertically, so before/after is decided by the vertical
			# position over the target cell, not the horizontal one.
			_viewport._drag_ace_insert_mode = (
				"after" if position.y >= span_rect.get_center().y else "before"
			)
	elif kind == "trigger" and drag_lane == "condition":
		_viewport._drag_ace_target_ace_index = 0
		_viewport._drag_ace_insert_mode = "before"
	else:
		var fallback_target: Dictionary = _viewport._resolve_lane_drop_target(row_data, lane, position)
		_viewport._drag_ace_target_ace_index = int(fallback_target.get("ace_index", -1))
		_viewport._drag_ace_insert_mode = str(fallback_target.get("insert_mode", "append"))
	var validation: Dictionary = _viewport._validate_ace_drag_target(row_data, lane)
	_viewport._drag_ace_drop_valid = bool(validation.get("valid", true))
	if not _viewport._drag_ace_drop_valid:
		_viewport._drag_feedback_text = str(validation.get("message", "This drop target is not valid."))
		_viewport._drag_feedback_is_error = true
		_viewport.tooltip_text = _viewport._drag_feedback_text
	_viewport.queue_redraw()


func complete_ace_drag() -> bool:
	if _viewport._drag_ace_entries.is_empty():
		return false
	if _viewport._drag_ace_target_row_index < 0:
		return true
	if not _viewport._drag_ace_drop_valid:
		if not _viewport._drag_feedback_text.is_empty():
			_viewport.drag_status_requested.emit(_viewport._drag_feedback_text, true)
		return true
	var target_row: EventRowData = _viewport._row_at(_viewport._drag_ace_target_row_index)
	if target_row == null:
		return true
	_viewport.ace_drop_requested.emit(
		_viewport._drag_ace_entries.duplicate(),
		target_row,
		_viewport._drag_ace_target_lane,
		_viewport._drag_ace_target_ace_index,
		_viewport._drag_ace_insert_mode,
		_viewport._drag_ace_copy_mode
	)
	return true


## Event-sheet-style drag ghost: a faint (~0.66 opacity) label of the dragged content following the
## cursor while an ACE/row drag has an active target (i.e. after actual mouse motion).
func draw_drag_ghost(font: Font, font_size: int) -> void:
	if _viewport._drag_ghost_label.is_empty():
		return
	var ace_dragging: bool = not _viewport._drag_ace_entries.is_empty() and _viewport._drag_ace_target_row_index >= 0
	var row_dragging: bool = _viewport._drag_row_index >= 0 and _viewport._drag_target_index >= 0
	if not ace_dragging and not row_dragging:
		return
	var ghost_font_size: int = maxi(font_size - 1, 10)
	var text_width: float = font.get_string_size(_viewport._drag_ghost_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ghost_font_size).x
	var ghost_rect := Rect2(
		_viewport._drag_pointer_position + Vector2(14.0, 10.0),
		Vector2(min(text_width, 280.0) + 14.0, font.get_height(ghost_font_size) + 6.0)
	)
	_viewport.draw_rect(ghost_rect, Color(0.12, 0.14, 0.18, 0.62), true)
	_viewport.draw_rect(ghost_rect, Color(1.0, 1.0, 1.0, 0.18), false, 1.0)
	_viewport.draw_string(
		font,
		Vector2(ghost_rect.position.x + 7.0, ghost_rect.position.y + 3.0 + font.get_ascent(ghost_font_size)),
		_viewport._drag_ghost_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		ghost_rect.size.x - 14.0,
		ghost_font_size,
		Color(1.0, 1.0, 1.0, 0.66)
	)
