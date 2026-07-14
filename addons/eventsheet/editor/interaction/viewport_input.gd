@tool
class_name ViewportInputHandlers
extends RefCounted
# The INPUT handling of the event sheet's virtualized viewport, extracted from
# event_sheet_viewport.gd to keep that file maintainable. The four handlers behind
# the viewport's _gui_input virtual live here:
#
#   - MOUSE MOTION: hover tracking, drag-target updates, lane-resize affordance,
#   - MOUSE BUTTONS: the whole click grammar - select / range / toggle, fold arrows,
#     breakpoint gutter, inline edit triggers, drag begins/completes, wheel zoom,
#     context-menu requests,
#   - KEYS: the row-scope keyboard map (navigation, folding incl. the region bracket
#     shortcuts, bookmarks, breakpoints, param scope entry, clipboard, zoom),
#   - EDITING KEYS: the inline cell editor's caret/typing/commit/cancel handling.
#
# All interaction STATE stays on the viewport (selection, hover, drag, editing
# buffers) - handlers read and write it through the `_viewport.` back-reference,
# so multi-view panes and the layout cache behave exactly as before. Bodies were
# moved VERBATIM; the viewport keeps its _gui_input virtual plus one-line handler
# delegates, so the input flow and every test stay untouched.

var _viewport: Control = null


func init(viewport: Control) -> void:
	_viewport = viewport


func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Ctrl-hover affordance: the hand cursor advertises the Ctrl+Click jump on resolvable cells.
	if _viewport.navigation_probe.is_valid() and (event.ctrl_pressed or event.meta_pressed):
		var nav_hit: Dictionary = _viewport._hit_test(_viewport._to_logical_position(event.position))
		var nav_row: EventRowData = _viewport._row_at(int(nav_hit.get("row_index", -1)))
		var navigable: bool = nav_row != null and bool(_viewport.navigation_probe.call(nav_row, nav_hit.get("span_metadata", {})))
		_viewport.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if navigable else Control.CURSOR_ARROW
	elif _viewport.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
		_viewport.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var local_position: Vector2 = _viewport._to_logical_position(event.position)
	if _viewport._dragging_lane_divider:
		_viewport._set_lane_ratio_from_x(local_position.x)
		return
	if _viewport._box_select_active:
		_viewport._box_select_current = local_position
		_viewport.queue_redraw()
		return
	var hit: Dictionary = _viewport._hit_test(local_position)
	_viewport._set_hover_state(int(hit.get("row_index", -1)), int(hit.get("span_index", -1)))
	# Cursor affordance, in priority order: the lane divider resizes (↔); the empty non-cell area of
	# an event row is the whole-event DRAG handle (✥ move cursor) - dragging there reorders the event
	# or nests it as a sub-event, so the previously-dead space now reads as grabbable; everything else
	# is the arrow. (Ctrl-hover's hand cursor is set above and left alone here.)
	var over_drag_zone: bool = _viewport.is_event_drag_zone(_viewport._row_at(int(hit.get("row_index", -1))), int(hit.get("span_index", -1)))
	if _viewport._hover_is_drag_zone != over_drag_zone:
		_viewport._hover_is_drag_zone = over_drag_zone
		_viewport.queue_redraw()  # brighten the grip handle on the hovered row
	if _viewport._is_near_lane_divider(local_position):
		_viewport.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif over_drag_zone:
		_viewport.mouse_default_cursor_shape = Control.CURSOR_MOVE
	else:
		_viewport.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_viewport._drag_pointer_position = local_position
	if not _viewport._drag_ace_entries.is_empty():
		_viewport._drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
		_viewport._update_ace_drag_target(hit, local_position)
	elif _viewport._drag_row_index >= 0:
		_viewport._drag_row_copy_mode = event.ctrl_pressed or event.meta_pressed
		_viewport._drag_target_index = int(hit.get("row_index", -1))
		_viewport._drag_target_mode = _viewport._resolve_drop_mode(hit, local_position)
		_viewport.queue_redraw()


func handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and (event.ctrl_pressed or event.meta_pressed):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_viewport.zoom_in(event.position)
			_viewport.accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_viewport.zoom_out(event.position)
			_viewport.accept_event()
			return
	var local_position: Vector2 = _viewport._to_logical_position(event.position)
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _viewport._box_select_active:
		_viewport._box_select_current = local_position
		_viewport._complete_box_selection()
		_viewport.accept_event()
		return
	var hit: Dictionary = _viewport._hit_test(local_position)
	var row_index: int = int(hit.get("row_index", -1))
	var span_index: int = int(hit.get("span_index", -1))
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if not event.pressed:
			return
		_viewport.grab_focus()
		# Footer "Add event…" rows are pure affordances - no context menu / selection.
		if _viewport._row_is_add_event_footer(_viewport._row_at(row_index)):
			_viewport.accept_event()
			return
		if row_index >= 0:
			if not _viewport._is_selection_hit(row_index, span_index):
				_viewport._select_from_click(row_index, span_index, false)
			var row_data: EventRowData = _viewport._row_at(row_index)
			if row_data != null:
				_viewport.context_menu_requested.emit(
					row_data,
					hit.duplicate(true),
					DisplayServer.mouse_get_position()
				)
				_viewport.accept_event()
		else:
			_viewport.empty_space_context_menu_requested.emit(DisplayServer.mouse_get_position())
			_viewport.accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_viewport.grab_focus()
		if _viewport._is_near_lane_divider(local_position):
			_viewport._dragging_lane_divider = true
			_viewport.accept_event()
			return
		if row_index < 0:
			# The centered getting-started CTAs are real buttons: a single click activates them.
			# "add_event" routes through the same signal as the double-click gesture, so the dock's
			# self-healing (open the starter menu when no sheet is loaded) covers both.
			var cta_action: String = _viewport._empty_state_helper.cta_action_at(local_position)
			if cta_action == "add_event":
				_viewport.empty_space_double_clicked.emit()
				_viewport.accept_event()
				return
			if cta_action == "template_menu":
				_viewport.template_menu_requested.emit()
				_viewport.accept_event()
				return
			if event.double_click:
				_viewport.empty_space_double_clicked.emit()
				_viewport.accept_event()
				return
			_viewport._begin_box_selection(local_position, event.ctrl_pressed or event.meta_pressed)
			_viewport.accept_event()
			return
		var row_data: EventRowData = _viewport._row_at(row_index)
		var metadata: Dictionary = hit.get("span_metadata", {})
		# Click the inline colour swatch -> open the colour picker directly (no params dialog). The
		# renderer stored the swatch's drawn rect in span.metadata; if the click landed inside
		# it and the cell's ACE has a Color param, hand off to the dock's picker popup.
		if row_data != null and metadata.get("swatch_color") is Color and metadata.get("swatch_rect") is Rect2 \
				and (metadata["swatch_rect"] as Rect2).has_point(local_position) and row_data.source_resource is EventRow:
			var swatch_kind: String = str(metadata.get("kind", ""))
			var swatch_ace: Resource = (row_data.source_resource as EventRow).trigger if swatch_kind == "trigger" else _viewport._resolve_ace_resource(row_data.source_resource, "action" if swatch_kind == "action" else "condition", int(metadata.get("ace_index", -1)))
			if swatch_ace != null:
				var color_param: String = _viewport._first_color_param_id(swatch_ace)
				if not color_param.is_empty():
					_viewport.color_swatch_edit_requested.emit(swatch_ace, color_param, metadata["swatch_color"] as Color)
					_viewport.accept_event()
					return
		if row_data != null and row_data.source_resource != null and str(metadata.get("kind", "")) == "add_action":
			_viewport.ace_picker_requested.emit(row_data, "action")
			_viewport.accept_event()
			return
		if row_data != null and row_data.source_resource != null and str(metadata.get("kind", "")) == "add_condition":
			_viewport.ace_picker_requested.emit(row_data, "condition")
			_viewport.accept_event()
			return
		if row_data != null and str(metadata.get("kind", "")) == "add_event":
			_viewport.add_event_requested.emit(metadata.get("add_event_owner", null))
			_viewport.accept_event()
			return
		if bool(hit.get("fold", false)):
			_viewport._select_from_click(row_index, span_index, false)
			_viewport._toggle_row_fold(row_index)
			return
		# Ctrl+Click go-to-definition: when the clicked cell resolves to a jump target (the dock's
		# probe decides), navigate instead of toggling multi-select - unresolvable cells keep
		# Ctrl+Click's multi-select meaning, so both gestures coexist.
		if (event.ctrl_pressed or event.meta_pressed) and not event.double_click and row_data != null 				and _viewport.navigation_probe.is_valid() and bool(_viewport.navigation_probe.call(row_data, metadata)):
			_viewport.navigate_requested.emit(row_data, span_index, metadata)
			_viewport.accept_event()
			return
		if event.shift_pressed and _viewport._selection_anchor_index >= 0:
			# Shift+click extends a whole-row range from the anchor to the clicked row.
			_viewport._select_range(row_index)
			_viewport.accept_event()
			return
		_viewport._select_from_click(row_index, span_index, event.ctrl_pressed or event.meta_pressed)
		if event.double_click:
			# In-flow GDScript blocks (actions) open the code dialog, not the ACE editor.
			var double_click_meta: Dictionary = hit.get("span_metadata", {})
			if bool(double_click_meta.get("match_action", false)) and row_data != null and row_data.source_resource is EventRow:
				var match_target: Resource = _viewport._resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
				if match_target is MatchRow:
					_viewport.match_edit_requested.emit(match_target)
					_viewport.accept_event()
					return
			if bool(double_click_meta.get("raw_action", false)) and row_data != null and row_data.source_resource is EventRow:
				var inline_raw: Resource = _viewport._resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
				if inline_raw is RawCodeRow:
					_viewport.raw_code_edit_requested.emit(inline_raw, true)
					_viewport.accept_event()
					return
			# Action-cell comments open the comment dialog (text + color).
			if bool(double_click_meta.get("action_comment", false)) and row_data != null and row_data.source_resource is EventRow:
				var inline_comment: Resource = _viewport._resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
				if inline_comment is CommentRow:
					_viewport.comment_edit_requested.emit(inline_comment)
					_viewport.accept_event()
					return
			# Enum rows open the enum dialog.
			if row_data != null and row_data.source_resource is EnumRow:
				_viewport.enum_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Custom Block API rows open the kind's schema dialog.
			if row_data != null and row_data.source_resource is CustomBlockRow:
				_viewport.custom_block_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Signal rows open the signal dialog.
			if row_data != null and row_data.source_resource is SignalRow:
				_viewport.signal_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Define blocks (published verbs) open the ACE Studio on that function.
			if row_data != null and row_data.source_resource is EventFunction:
				_viewport.function_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Pick-filter rows open the pick-filter dialog.
			if str(double_click_meta.get("kind", "")) == "pick_filter" and row_data != null and row_data.source_resource is EventRow:
				_viewport.pick_filter_edit_requested.emit(row_data.source_resource, int(double_click_meta.get("pick_index", -1)))
				_viewport.accept_event()
				return
			# "With node X:" scope chip opens the target editor.
			if str(double_click_meta.get("kind", "")) == "with_node" and row_data != null and row_data.source_resource is EventRow:
				_viewport.with_node_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			# Single-param inline editing: a double-click landing on a highlighted VALUE
			# within an ACE edits just that parameter.
			var value_kind: String = str(double_click_meta.get("kind", ""))
			if value_kind in ["condition", "trigger", "action"] and row_data != null and row_data.source_resource is EventRow and span_index >= 0 and span_index < row_data.spans.size():
				var value_hit: Array = _viewport._value_text_at(row_data.spans[span_index], local_position.x, _viewport._get_font(), _viewport._get_font_size())
				if not value_hit.is_empty():
					var clicked_lane: String = "action" if value_kind == "action" else "condition"
					var clicked_ace: Resource = row_data.source_resource.trigger if value_kind == "trigger" else _viewport._resolve_ace_resource(row_data.source_resource, clicked_lane, int(double_click_meta.get("ace_index", -1)))
					if clicked_ace != null:
						var clicked_param: String = _viewport.param_id_for_value(clicked_ace, str(value_hit[0]), int(value_hit[1]))
						if not clicked_param.is_empty():
							_viewport.param_value_edit_requested.emit(clicked_ace, clicked_param, str(value_hit[0]))
							_viewport.accept_event()
							return
			# Double-clicking a comment opens its edit dialog (text + colour) - what the user expects
			# from "edit this comment", instead of dropping into a per-line inline caret that reads as a
			# whole-row highlight. The dialog is also the only safe editor for multi-line comment text.
			if row_data != null and row_data.source_resource is CommentRow:
				_viewport.comment_edit_requested.emit(row_data.source_resource)
				_viewport.accept_event()
				return
			if _viewport._maybe_request_ace_edit(hit, row_index):
				_viewport.accept_event()
				return
			# The variable-group chip renames the folder (empty name in the popup ungroups).
			if bool(double_click_meta.get("group_chip", false)) \
					and not str(double_click_meta.get("variable_group", "")).is_empty():
				_viewport.variable_group_rename_requested.emit(str(double_click_meta.get("variable_group")))
				_viewport.accept_event()
				return
			if _viewport._maybe_request_variable_edit(hit, row_index):
				_viewport.accept_event()
				return
			if row_data != null and row_data.source_resource is RawCodeRow:
				_viewport.raw_code_edit_requested.emit(row_data.source_resource, false)
				_viewport.accept_event()
				return
			_viewport._begin_edit(row_index, span_index)
			_viewport.accept_event()
			return
		if _viewport._maybe_begin_slow_edit(row_index, span_index):
			_viewport.accept_event()
			return
		_viewport._drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
		_viewport._drag_row_copy_mode = event.ctrl_pressed or event.meta_pressed
		if _viewport._maybe_begin_ace_drag(hit, row_index):
			# Accept so this control keeps receiving motion/release for the drag.
			_viewport.accept_event()
			return
		_viewport._begin_row_drag(row_index)
		_viewport.accept_event()
		return
	if _viewport._dragging_lane_divider:
		_viewport._dragging_lane_divider = false
		_viewport.lane_ratio_changed.emit(_viewport._get_event_style().condition_lane_ratio)
		_viewport.accept_event()
		return
	if not _viewport._drag_ace_entries.is_empty():
		_viewport._drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
		_viewport._complete_ace_drag()
		_viewport._clear_ace_drag()
		_viewport.queue_redraw()
		return
	if _viewport._drag_row_index >= 0 and _viewport._drag_target_index >= 0 and not _viewport._drag_row_indices.has(_viewport._drag_target_index):
		var target_row: EventRowData = _viewport._row_at(_viewport._drag_target_index)
		if target_row != null:
			if _viewport._drag_row_indices.size() > 1:
				var dragged_rows: Array = []
				for source_index in _viewport._drag_row_indices:
					var source_row: EventRowData = _viewport._row_at(source_index)
					if source_row != null:
						dragged_rows.append(source_row)
				if not dragged_rows.is_empty():
					_viewport.rows_drop_requested.emit(dragged_rows, target_row, _viewport._drag_target_mode, _viewport._drag_row_copy_mode)
			else:
				var source_row: EventRowData = _viewport._row_at(_viewport._drag_row_index)
				if source_row != null:
					if _viewport._drag_target_mode == "group":
						# Variable dropped ONTO a variable: fold them into one Inspector-group
						# "folder" (named right after, like a fresh Discord folder) - not a reorder.
						_viewport.variable_group_requested.emit(source_row, target_row)
					else:
						_viewport.row_drop_requested.emit(source_row, target_row, _viewport._drag_target_mode, _viewport._drag_row_copy_mode)
	_viewport._clear_row_drag()
	_viewport.queue_redraw()


func handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if _viewport._editing_row_index >= 0:
		_viewport._handle_editing_key(event)
		return
	# Param scope owns Tab / Esc / Enter / typing while active. The scope is entered explicitly
	# (Enter below), so Tab at plain row scope still falls through to the dock's nest/outdent -
	# the two Tabs never fight.
	if _viewport.param_scope_active():
		if event.keycode in [KEY_TAB, KEY_BACKTAB]:
			_viewport._param_scope_step(-1 if (event.shift_pressed or event.keycode == KEY_BACKTAB) else 1)
			_viewport.accept_event()
			return
		if event.keycode == KEY_ESCAPE:
			_viewport.exit_param_scope()
			_viewport.accept_event()
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] or (event.unicode > 32 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed):
			_viewport._open_param_cursor_editor()
			_viewport.accept_event()
			return
	if (event.keycode == KEY_UP or event.keycode == KEY_DOWN) and event.shift_pressed and not event.alt_pressed:
		# Shift+Arrow grows or shrinks a whole-row range from the selection anchor. From an empty
		# selection it lands on the first row (Shift+Down used to skip past row 0 to row 1).
		if _viewport._selected_row_index < 0:
			_viewport._select_range(0)
		else:
			_viewport._select_range(_viewport._selected_row_index + (-1 if event.keycode == KEY_UP else 1))
		_viewport.ensure_selection_visible()
		_viewport.accept_event()
	elif event.keycode == KEY_UP and not event.alt_pressed:
		_viewport._select_row(_viewport._selected_row_index - 1, _viewport._selected_span_index)
		_viewport.ensure_selection_visible()
		_viewport.accept_event()
	elif event.keycode == KEY_DOWN and not event.alt_pressed:
		_viewport._select_row(_viewport._selected_row_index + 1, _viewport._selected_span_index)
		_viewport.ensure_selection_visible()
		_viewport.accept_event()
	elif event.keycode == KEY_BRACKETLEFT and event.ctrl_pressed and event.shift_pressed:
		# Ctrl+Shift+[ folds the REGION containing the selection (script-editor muscle
		# memory); the selection lands on the opener so it never vanishes into the fold.
		var fold_region_index: int = _viewport._enclosing_region_flat_index(_viewport._selected_row_index)
		if fold_region_index >= 0:
			var fold_region: EventRowData = _viewport._row_at(fold_region_index)
			fold_region.folded = true
			_viewport._fold_state[fold_region.row_uid] = true
			_viewport._select_row(fold_region_index, -1)
			_viewport._refresh_rows()
			_viewport._persist_region_folds()
			_viewport.accept_event()
	elif event.keycode == KEY_BRACKETRIGHT and event.ctrl_pressed and event.shift_pressed:
		# Ctrl+Shift+] unfolds the selected/containing region.
		var unfold_region_index: int = _viewport._enclosing_region_flat_index(_viewport._selected_row_index)
		if unfold_region_index >= 0:
			var unfold_region: EventRowData = _viewport._row_at(unfold_region_index)
			unfold_region.folded = false
			_viewport._fold_state[unfold_region.row_uid] = false
			_viewport._refresh_rows()
			_viewport._persist_region_folds()
			_viewport.accept_event()
	elif event.keycode == KEY_LEFT and not event.alt_pressed:
		# Plain Left folds; Alt+Left is the dock's jump-history Back and must pass through.
		var left_row: EventRowData = _viewport._row_at(_viewport._selected_row_index)
		if left_row != null and not left_row.children.is_empty() and not left_row.folded:
			_viewport._toggle_row_fold(_viewport._selected_row_index)
			_viewport.accept_event()
	elif event.keycode == KEY_RIGHT and not event.alt_pressed:
		# Plain Right unfolds; Alt+Right is the dock's jump-history Forward.
		var right_row: EventRowData = _viewport._row_at(_viewport._selected_row_index)
		if right_row != null and not right_row.children.is_empty() and right_row.folded:
			_viewport._toggle_row_fold(_viewport._selected_row_index)
			_viewport.accept_event()
	elif event.keycode == KEY_B and (event.ctrl_pressed or event.meta_pressed):
		_viewport._toggle_breakpoint(_viewport._selected_row_index)
		_viewport.accept_event()
	elif event.keycode == KEY_M and (event.ctrl_pressed or event.meta_pressed):
		_viewport.toggle_bookmark_selected()
		_viewport.accept_event()
	elif event.keycode == KEY_F4:
		_viewport.jump_to_bookmark(-1 if event.shift_pressed else 1)
		_viewport.accept_event()
	elif event.keycode == KEY_F9:
		# Script-editor convention (Ctrl+B remains as an alias).
		_viewport._toggle_breakpoint(_viewport._selected_row_index)
		_viewport.accept_event()
	elif event.keycode == KEY_SLASH and (event.ctrl_pressed or event.meta_pressed):
		# Ctrl+/: the "comment out" of event sheets - toggle the row's enabled state.
		_viewport.row_disable_toggle_requested.emit()
		_viewport.accept_event()
	elif event.keycode == KEY_UP and event.alt_pressed:
		_viewport.row_move_requested.emit(-1)
		_viewport.accept_event()
	elif event.keycode == KEY_DOWN and event.alt_pressed:
		_viewport.row_move_requested.emit(1)
		_viewport.accept_event()
	elif event.keycode == KEY_F and (event.ctrl_pressed or event.meta_pressed):
		_viewport.find_requested.emit()
		_viewport.accept_event()
	elif event.keycode == KEY_F3:
		_viewport.find_step_requested.emit(-1 if event.shift_pressed else 1)
		_viewport.accept_event()
	elif event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		# Consume here (the focused viewport) so Delete acts on the event sheet and can NEVER reach
		# the editor's Scene-tree dock, which would delete the selected scene node. The dock does the
		# actual removal via _delete_selected_content (same as its _unhandled_key_input fallback).
		_viewport.delete_requested.emit()
		_viewport.accept_event()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		# Param-scope aware: a row with parameter values enters the value cursor; anything else
		# falls back to inline span editing. F2 below stays a pure begin-edit escape hatch.
		_viewport.handle_enter_key()
		_viewport.accept_event()
	elif event.keycode == KEY_F2:
		_viewport._begin_edit(_viewport._selected_row_index, _viewport._selected_span_index)
		_viewport.accept_event()


func handle_editing_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_viewport._cancel_edit()
		_viewport.accept_event()
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_viewport._commit_edit()
		_viewport.accept_event()
		return
	if event.keycode == KEY_BACKSPACE:
		# A selection deletes as one unit (standard text-editing semantics).
		if _viewport._editing_has_selection():
			_viewport._delete_editing_selection()
			_viewport._update_inline_format_bar()
			_viewport.queue_redraw()
		elif _viewport._editing_caret > 0:
			_viewport._editing_buffer = _viewport._editing_buffer.substr(0, _viewport._editing_caret - 1) + _viewport._editing_buffer.substr(_viewport._editing_caret)
			_viewport._editing_caret -= 1
			_viewport.queue_redraw()
		_viewport.accept_event()
		return
	if event.keycode == KEY_LEFT:
		# Shift extends the selection (anchoring on the first shifted move); a plain
		# arrow collapses it.
		if event.shift_pressed and _viewport._editing_select_anchor < 0:
			_viewport._editing_select_anchor = _viewport._editing_caret
		elif not event.shift_pressed:
			_viewport._editing_select_anchor = -1
		_viewport._editing_caret = maxi(_viewport._editing_caret - 1, 0)
		_viewport._update_inline_format_bar()
		_viewport.queue_redraw()
		_viewport.accept_event()
		return
	if event.keycode == KEY_RIGHT:
		if event.shift_pressed and _viewport._editing_select_anchor < 0:
			_viewport._editing_select_anchor = _viewport._editing_caret
		elif not event.shift_pressed:
			_viewport._editing_select_anchor = -1
		_viewport._editing_caret = mini(_viewport._editing_caret + 1, _viewport._editing_buffer.length())
		_viewport._update_inline_format_bar()
		_viewport.queue_redraw()
		_viewport.accept_event()
		return
	if event.keycode == KEY_A and (event.ctrl_pressed or event.meta_pressed):
		_viewport._editing_select_anchor = 0
		_viewport._editing_caret = _viewport._editing_buffer.length()
		_viewport._update_inline_format_bar()
		_viewport.queue_redraw()
		_viewport.accept_event()
		return
	# Discord keyboard parity on comment rows: Ctrl+B/I/U toggles the BBCode wrap on the
	# inline selection (same shortcuts the comment dialog's bar answers to).
	if (event.ctrl_pressed or event.meta_pressed) and event.keycode in [KEY_B, KEY_I, KEY_U] and _viewport._editing_has_selection() and _viewport._editing_span_is_comment():
		match event.keycode:
			KEY_B:
				_viewport._wrap_editing_selection("[b]", "[/b]")
			KEY_I:
				_viewport._wrap_editing_selection("[i]", "[/i]")
			KEY_U:
				_viewport._wrap_editing_selection("[u]", "[/u]")
		_viewport.accept_event()
		return
	if event.unicode > 0 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		var typed_char: String = char(event.unicode)
		if not typed_char.is_empty():
			# Typing over a selection replaces it (standard text-editing semantics).
			if _viewport._editing_has_selection():
				_viewport._delete_editing_selection()
				_viewport._update_inline_format_bar()
			_viewport._editing_buffer = _viewport._editing_buffer.substr(0, _viewport._editing_caret) + typed_char + _viewport._editing_buffer.substr(_viewport._editing_caret)
			_viewport._editing_caret += typed_char.length()
			_viewport.queue_redraw()
			_viewport.accept_event()
