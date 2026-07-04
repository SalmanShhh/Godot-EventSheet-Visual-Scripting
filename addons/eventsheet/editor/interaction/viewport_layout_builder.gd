@tool
class_name ViewportLayoutBuilder
extends RefCounted
# The per-row LAYOUT pass of the event sheet's virtualized viewport, extracted from
# event_sheet_viewport.gd to keep that file maintainable. One concern lives here: turning a
# flat-row index into the geometry dictionary the renderer paints and the hit-tester reads -
# span rects per lane (badge column / condition track / action track / non-event flow, with
# comment word-wrap stacking), the row chrome rects (gutter, fold arrow, icon, lanes,
# divider), and the drag-preview rects (row insert line / group outline / ACE drop line /
# feedback bubble).
#
# The body was moved VERBATIM - only member access was rewritten through the `_viewport.`
# back-reference, so caching semantics are untouched: the layout cache and its key (row uid +
# index + width + drag signature + style signature) stay on the viewport, selection/hover are
# refreshed on every read because they are NOT part of the key, and span rects are written
# onto the shared SemanticSpan objects exactly as before. The viewport keeps a one-line
# _get_or_build_row_layout delegate, so every call site (draw, hit-test, box selection,
# param scope) needed no edits.

var _viewport: Control = null


func init(viewport: Control) -> void:
	_viewport = viewport


func get_or_build_row_layout(index: int, width: float, font: Font, font_size: int) -> Dictionary:
	var row_data: EventRowData = _viewport._row_at(index)
	if row_data == null:
		return {}
	# Build this row's spans on demand. This is the single choke point for both
	# drawing (_draw) and hit-testing (_hit_test), so any laid-out/interacted row
	# always has its spans before they are read downstream.
	_viewport._ensure_event_spans(row_data)
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var line_height: float = _viewport._get_event_line_height(font_size)
	# Cache key components: row uid, visible row index, canvas width, active drag
	# target index, and the current layout style signature.
	# Drag state is part of the key so the drop preview (row reorder + ACE drop line) updates
	# as the drag target moves; it is constant when idle, so no churn outside a drag.
	var drag_signature: String = "%d:%s:%d:%s:%d:%s" % [
		_viewport._drag_target_index, _viewport._drag_target_mode,
		_viewport._drag_ace_target_row_index, _viewport._drag_ace_target_lane, _viewport._drag_ace_target_ace_index, _viewport._drag_ace_insert_mode
	]
	var key: String = "%s:%d:%d:%s:%s" % [row_data.row_uid, index, int(width), drag_signature, _viewport._layout_style_signature]
	if _viewport._layout_cache.has(key):
		var cached_layout: Dictionary = _viewport._layout_cache.get_layout(key)
		# Selection/hover are NOT part of the cache key (geometry is unchanged by them), so they
		# must be refreshed on every read - otherwise a click/hover reads stale state and the
		# whole event highlights instead of the clicked cell, and hover never appears.
		cached_layout["selected_span_indices"] = _viewport._selected_span_indices.get(row_data.row_uid, []).duplicate()
		cached_layout["hovered_span_index"] = _viewport._hovered_span_index if index == _viewport._hovered_row_index else -1
		return cached_layout
	var row_top: float = _viewport._get_row_top(index)
	var row_height: float = _viewport._get_row_height(index)
	var row_rect := Rect2(0.0, row_top, width, row_height)
	var gutter_rect := Rect2(0.0, row_top, EventSheetPalette.GUTTER_WIDTH, row_height)
	var x: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + EventSheetPalette.GUTTER_WIDTH + float(row_data.indent * _viewport.INDENT_WIDTH)
	var fold_rect: Rect2 = Rect2(x - 14.0, row_top + 6.0, 12.0, 16.0) if not row_data.children.is_empty() else Rect2()
	# No row-type glyph: the old colored square here said nothing the row itself doesn't
	# (tempo badges, chips and labels carry the type). The 18px advance stays so every
	# row's geometry - and every cached span position - is untouched.
	x += 18.0
	var condition_lane_rect := Rect2()
	var action_lane_rect := Rect2()
	var lane_divider_rect := Rect2()
	var lane_divider_x: float = -1.0
	var row_right_limit: float = width - EventSheetPalette.ROW_HORIZONTAL_PADDING
	if row_data.row_type == EventRowData.RowType.EVENT:
		lane_divider_x = _viewport.get_lane_divider_x(width)
		condition_lane_rect = Rect2(x, row_top, max(lane_divider_x - x, 1.0), row_height)
		lane_divider_rect = Rect2(lane_divider_x, row_top, float(event_style.lane_divider_width), row_height)
		action_lane_rect = Rect2(lane_divider_x + float(event_style.lane_divider_width), row_top, max(width - lane_divider_x - float(event_style.lane_divider_width), 1.0), row_height)
	var condition_x: float = _viewport._get_condition_track_start(row_data, x, condition_lane_rect)
	var condition_badge_column_width: float = max(float(event_style.condition_badge_column_width), 0.0)
	var condition_badge_column_gap: float = EventSheetPalette.SPAN_GAP if condition_badge_column_width > 0.0 else 0.0
	var condition_text_start_x: float = condition_x + condition_badge_column_width + condition_badge_column_gap
	var condition_line_x: Dictionary = {}
	# Tracks the next available X in the badge area for each condition line.
	var condition_badge_next_x: Dictionary = {}
	var action_x: float = (
		lane_divider_x + float(event_style.lane_divider_width) + float(event_style.action_lane_padding)
		if lane_divider_x > 0.0
		else x
	)
	var action_line_x: Dictionary = {}
	var action_line_reservations: Dictionary = _viewport._build_action_line_reservations(row_data, action_lane_rect, font, font_size)
	# Running X per line for non-event rows (group / variable / comment / GDScript block),
	# which lay out left-to-right; multi-line rows stack by span line_index.
	var non_event_origin_x: float = x
	# Indent comment text to line up with where an event's condition text begins (past the
	# trigger/badge column), so comments align with the event blocks they annotate.
	if row_data.row_type == EventRowData.RowType.COMMENT:
		var comment_badge_column: float = max(float(event_style.condition_badge_column_width), 0.0)
		if comment_badge_column > 0.0:
			non_event_origin_x += comment_badge_column + EventSheetPalette.SPAN_GAP
	var non_event_line_x: Dictionary = {}
	# Comment wrapping: each logical line wraps to the row width, so a span can be several
	# visual lines tall. Precompute, per span, the visual-line offset it starts at and how
	# many visual lines it spans, so spans stack without overlapping (height matches the
	# reserved row height from _measure_comment_height).
	var is_comment_row: bool = row_data.row_type == EventRowData.RowType.COMMENT
	var comment_wrap_width: float = _viewport._row_metrics_helper._comment_wrap_width(row_data.indent, width) if is_comment_row else 0.0
	var comment_line_tops: Array[int] = []
	var comment_line_counts: Array[int] = []
	if is_comment_row:
		var visual_top: int = 0
		for comment_span: SemanticSpan in row_data.spans:
			var span_lines: int = _viewport._row_metrics_helper._comment_span_line_count(comment_span, comment_wrap_width, font, font_size)
			comment_line_tops.append(visual_top)
			comment_line_counts.append(span_lines)
			visual_top += span_lines
	for span_index in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[span_index]
		if span == null:
			continue
		var span_lane: String = _viewport._resolve_span_lane(span)
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		var span_x: float = x
		var span_y: float = row_top + 3.0
		if lane_divider_x <= 0.0:
			# Non-event rows (group / variable / comment / GDScript block) flow their spans
			# left-to-right per line; without this every span stayed at the same X and
			# overlapped. Multi-line rows stack via span line_index.
			var flow_line: int = int(metadata.get("line_index", 0))
			span_y = row_top + float(flow_line) * line_height + 3.0
			span_x = float(non_event_line_x.get(flow_line, non_event_origin_x))
			# Comment spans stack by accumulated WRAPPED height, not raw line index, so a
			# multi-line wrapped span pushes the next one down past its full height.
			if is_comment_row and span_index < comment_line_tops.size():
				span_y = row_top + float(comment_line_tops[span_index]) * line_height + 3.0
		elif span_lane == "action":
			var action_line_index: int = int(metadata.get("line_index", 0))
			span_y = row_top + float(action_line_index) * line_height + 3.0
			if bool(metadata.get("align_right", false)) and action_lane_rect.size.x > 0.0:
				span_x = action_lane_rect.end.x - float(event_style.action_lane_padding)
			else:
				if not action_line_x.has(action_line_index):
					action_line_x[action_line_index] = action_x
				span_x = float(action_line_x[action_line_index])
		elif lane_divider_x > 0.0:
			var line_index: int = int(metadata.get("line_index", 0))
			if bool(metadata.get("badge", false)):
				if not condition_badge_next_x.has(line_index):
					condition_badge_next_x[line_index] = condition_x
				span_x = float(condition_badge_next_x[line_index])
			else:
				if not condition_line_x.has(line_index):
					# If badges were drawn first on this line, start the condition text
					# after the rightmost badge; otherwise use the default badge-column offset.
					condition_line_x[line_index] = float(
						condition_badge_next_x.get(line_index, condition_text_start_x)
					)
				span_x = float(condition_line_x[line_index])
			span_y = row_top + float(line_index) * line_height + 3.0
		var display_text: String = _viewport._editing_buffer if index == _viewport._editing_row_index and span_index == _viewport._editing_span_index else span.text
		var span_width: float = _viewport._measure_span_width(span, display_text, font, font_size)
		if lane_divider_x > 0.0 and span_lane != "action":
			var max_condition_right: float = lane_divider_x - float(event_style.condition_lane_padding)
			if bool(metadata.get("badge", false)):
				var badge_width: float = condition_badge_column_width if condition_badge_column_width > 0.0 else span_width
				span_width = max(min(badge_width, max_condition_right - span_x), _viewport.MIN_SPAN_WIDTH)
			elif str(metadata.get("kind", "")) in ["condition", "trigger"]:
				span_width = max(max_condition_right - span_x, _viewport.MIN_SPAN_WIDTH)
			else:
				span_width = max(min(span_width, max_condition_right - span_x), _viewport.MIN_SPAN_WIDTH)
		elif span_lane == "action" and action_lane_rect.size.x > 0.0:
			var reserved_start: float = float(
				action_line_reservations.get(
					int(metadata.get("line_index", 0)),
					action_lane_rect.end.x - float(event_style.action_lane_padding)
				)
			)
			if bool(metadata.get("align_right", false)):
				span_x = max(
					action_lane_rect.position.x + float(event_style.action_lane_padding),
					action_lane_rect.end.x - float(event_style.action_lane_padding) - span_width - 2.0
				)
			else:
				var max_action_width: float = reserved_start - max(_viewport._get_span_gap(span), EventSheetPalette.SPAN_GAP) - span_x
				if str(metadata.get("kind", "")) == "action":
					span_width = max(max_action_width, 1.0)
				else:
					span_width = max(min(span_width, max_action_width), 1.0)
		else:
			# -2.0 accounts for the +2.0 the rect adds below, so non-event spans (comments,
			# variables, blocks) never bleed past the row's right padding.
			span_width = max(min(span_width, row_right_limit - span_x - 2.0), 1.0)
		# Event-sheet-style contiguous cells: chip cells (conditions/actions/comments) fill their full
		# line minus a 1px hairline, so stacked cells read as one solid block. Badges and
		# plain text keep the original vertical inset.
		if bool(metadata.get("chip", false)):
			span.rect = Rect2(span_x, span_y - 2.5, span_width + 2.0, line_height - 1.0)
		elif is_comment_row and span_index < comment_line_counts.size():
			# A wrapped comment span is as tall as its visual-line count; flag it so the
			# renderer draws it with word-wrapping instead of a single clipped line.
			var comment_height: float = float(comment_line_counts[span_index]) * line_height - 6.0
			span.rect = Rect2(span_x, span_y, span_width + 2.0, comment_height)
			if (metadata.get("bbcode_segments", []) as Array).is_empty():
				metadata["comment_wrap"] = true
				metadata["comment_line_height"] = line_height
		else:
			span.rect = Rect2(span_x, span_y, span_width + 2.0, line_height - 6.0)
		# Store absolute X for the next span start on this line.
		var next_span_start_x: float = span.rect.end.x + _viewport._get_span_gap(span)
		if lane_divider_x <= 0.0:
			non_event_line_x[int(metadata.get("line_index", 0))] = next_span_start_x
		elif span_lane == "action":
			var action_line_index_next: int = int(metadata.get("line_index", 0))
			if not bool(metadata.get("align_right", false)):
				action_line_x[action_line_index_next] = next_span_start_x
		else:
			var condition_line_index: int = int(metadata.get("line_index", 0))
			if bool(metadata.get("badge", false)):
				condition_badge_next_x[condition_line_index] = next_span_start_x
			else:
				condition_line_x[condition_line_index] = next_span_start_x
	var drag_rect := Rect2()
	if _viewport._drag_row_index >= 0 and _viewport._drag_target_index == index:
		match _viewport._drag_target_mode:
			"after":
				drag_rect = Rect2(0.0, row_rect.end.y - 1.0, width, 2.0)
			"group":
				# The whole target row outlines (not a thin insert line): dropping here FOLDS the
				# dragged variable into this one's Inspector-group folder.
				drag_rect = Rect2(2.0, row_rect.position.y + 1.0, width - 4.0, row_rect.size.y - 2.0)
			"inside":
				# Indent the drop line to the child level so it clearly reads as "nest this
				# as a sub-event of the target", not just "drop after".
				var child_indent_x: float = EventSheetPalette.GUTTER_WIDTH + float((row_data.indent + 1) * _viewport.INDENT_WIDTH) + EventSheetPalette.ROW_HORIZONTAL_PADDING
				drag_rect = Rect2(child_indent_x, row_rect.end.y - 2.0, max(width - child_indent_x, 1.0), 3.0)
			_:
				drag_rect = Rect2(0.0, row_rect.position.y - 1.0, width, 2.0)
	var ace_drag_rect := Rect2()
	if not _viewport._drag_ace_entries.is_empty() and _viewport._drag_ace_target_row_index == index:
		ace_drag_rect = _viewport._build_ace_drag_preview_rect(
			row_data,
			_viewport._drag_ace_target_lane,
			_viewport._drag_ace_target_ace_index,
			_viewport._drag_ace_insert_mode,
			condition_lane_rect,
			action_lane_rect
		)
	var drag_feedback_rect := Rect2()
	if not _viewport._drag_feedback_text.is_empty() and _viewport._drag_ace_target_row_index == index:
		var feedback_lane_rect: Rect2 = (
			action_lane_rect if _viewport._drag_ace_target_lane == "action" else condition_lane_rect
		)
		drag_feedback_rect = _viewport._build_drag_feedback_rect(
			ace_drag_rect,
			feedback_lane_rect,
			_viewport._drag_feedback_text,
			font,
			font_size
		)
	var layout := {
		"row_rect": row_rect,
		"row_height": row_height,
		"gutter_rect": gutter_rect,
		"fold_rect": fold_rect,
		"condition_lane_rect": condition_lane_rect,
		"action_lane_rect": action_lane_rect,
		"lane_divider_rect": lane_divider_rect,
		"lane_divider_x": lane_divider_x,
		"alternating": index % 2 == 1,
		"debug_text": row_data.debug_state,
		"drag_rect_outline": _viewport._drag_row_index >= 0 and _viewport._drag_target_index == index and _viewport._drag_target_mode == "group",
		"drag_rect": drag_rect,
		"ace_drag_rect": ace_drag_rect,
		"ace_drag_error": not _viewport._drag_ace_drop_valid and _viewport._drag_ace_target_row_index == index,
		"drag_feedback_rect": drag_feedback_rect,
		"drag_feedback_text": _viewport._drag_feedback_text if _viewport._drag_ace_target_row_index == index else "",
		"drag_feedback_error": _viewport._drag_feedback_is_error and _viewport._drag_ace_target_row_index == index,
		"line_number": row_data.line_number,
		"breakpoint_enabled": row_data.breakpoint_enabled,
		"disabled": row_data.disabled,
		"editing_span_index": _viewport._editing_span_index if index == _viewport._editing_row_index else -1,
		"editing_buffer": _viewport._editing_buffer if index == _viewport._editing_row_index else "",
		"editing_caret": _viewport._editing_caret if index == _viewport._editing_row_index else -1,
		"total_selected_spans": _viewport._get_selected_span_count(),
		"selected_span_indices": _viewport._selected_span_indices.get(row_data.row_uid, []).duplicate(),
		"hovered_span_index": _viewport._hovered_span_index if index == _viewport._hovered_row_index else -1,
		"drag_mode": _viewport._drag_target_mode if _viewport._drag_target_index == index else ""
	}
	_viewport._layout_cache.store(key, layout)
	return layout
