@tool
class_name EventSheetMultiViewManager
extends RefCounted
# Multi-view: the "split view" subsystem — a second pane over the SAME sheet (VSCode-style),
# for debugging / reading / comparing distant regions. Breakpoints/bookmarks/disabled state are
# shared by reference; scroll/zoom/selection/folds are per-pane. Owns the split widgets and the
# split-pane lifecycle (open/close, signal wiring, "Open in Split", linked-pane mirroring, the
# refresh bus). Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# The view-access core stays on the dock: _active_view() / _active_viewport_ref /
# _mirroring_selection / _linked_views and the detached-view (P2) state are shared by the
# primary, split, AND detached panes, so the dock owns them. This helper reaches them (and the
# dock's _viewport / _scroll / _current_sheet / _ace_registry) through the `_dock` back-reference,
# the same pattern as the other dock/ helpers. The dock keeps a one-line delegate for every
# external caller (and for the detached-view code that reuses _connect_view_signals).

var _dock: Control = null
var _split_container: HSplitContainer = null
var _split_scroll: ScrollContainer = null
var _split_viewport: EventSheetViewport = null


func init(dock: Control) -> void:
	_dock = dock


## Toggles a second, read/navigate-only pane over the SAME sheet (debugging, reading,
## comparing distant regions). Breakpoints/bookmarks/disabled state are shared by
## reference; scroll/zoom/selection/folds are per-pane.
func _toggle_split_view() -> void:
	if _split_viewport != null:
		_close_split_view()
		_dock._set_status("Split view closed.")
		return
	if _dock._scroll == null or _dock._scroll.get_parent() == null:
		return
	var slot: Node = _dock._scroll.get_parent()
	var slot_index: int = _dock._scroll.get_index()
	slot.remove_child(_dock._scroll)
	_split_container = HSplitContainer.new()
	_split_container.name = "EventSheetSplit"
	_split_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.add_child(_split_container)
	slot.move_child(_split_container, slot_index)
	_split_container.add_child(_dock._scroll)
	_split_scroll = ScrollContainer.new()
	_split_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split_container.add_child(_split_scroll)
	_split_viewport = EventSheetViewport.new()
	_split_viewport.name = "EventSheetSplitViewport"
	_split_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split_viewport.set_ace_registry(_dock._ace_registry)
	_split_viewport.adopt_shared_state(_dock._viewport.get_shared_state())
	_split_scroll.add_child(_split_viewport)
	_connect_view_signals(_split_viewport)
	_split_viewport.set_sheet(_dock._current_sheet)
	_dock._set_status("Split view: the right pane navigates independently (editing happens in the left pane).")


## Wires a secondary pane for FULL editing: the dock's handlers are payload-driven
## (signals carry the row/resource), so the same set serves any number of panes;
## selection-driven toolbar ops route through _active_view(). Shared by the split pane and
## the detached pane (the dock's _toggle_detached_view delegates here).
func _connect_view_signals(view: EventSheetViewport) -> void:
	view.selection_changed.connect(func(row_data: EventRowData) -> void:
		if _dock._mirroring_selection:
			return  # a mirrored selection must not steal the active view
		_dock._active_viewport_ref = view
		_mirror_selection(view, row_data)
		_dock._on_viewport_selection_changed(row_data)
	)
	view.row_drop_requested.connect(_dock._on_row_drop_requested)
	view.rows_drop_requested.connect(_dock._on_rows_drop_requested)
	view.ace_picker_requested.connect(_dock._on_viewport_ace_picker_requested)
	view.span_edit_requested.connect(_dock._on_viewport_span_edit_requested)
	view.ace_edit_requested.connect(_dock._on_viewport_ace_edit_requested)
	view.param_value_edit_requested.connect(_dock._on_param_value_edit_requested)
	view.color_swatch_edit_requested.connect(_dock._on_color_swatch_edit_requested)
	view.param_node_drop_requested.connect(_dock._on_param_node_drop_requested)
	view.variable_edit_requested.connect(_dock._on_viewport_variable_edit_requested)
	view.comment_edit_requested.connect(_dock._open_comment_dialog)
	view.group_edit_requested.connect(_dock._on_group_edit_requested)
	view.pick_filter_edit_requested.connect(_dock._open_pick_filter_dialog)
	view.with_node_edit_requested.connect(_dock._open_with_node_dialog)
	view.enum_edit_requested.connect(_dock._open_enum_dialog)
	view.signal_edit_requested.connect(_dock._open_signal_dialog)
	view.match_edit_requested.connect(_dock._open_match_dialog)
	view.row_disable_toggle_requested.connect(_dock._toggle_selected_rows_enabled)
	view.row_move_requested.connect(_dock._move_selected_row)
	view.delete_requested.connect(_dock._delete_selected_content)
	view.find_requested.connect(_dock._show_find_bar)
	view.find_step_requested.connect(_dock._find_step)
	view.context_menu_requested.connect(_dock._on_viewport_context_menu_requested)
	view.raw_code_edit_requested.connect(_dock._on_viewport_raw_code_edit_requested)


## "Open in Split": pins the given row in the other pane (opens the split if needed).
func _open_row_in_split(row_data: EventRowData) -> void:
	if row_data == null:
		return
	if _split_viewport == null:
		_toggle_split_view()
	if _split_viewport == null:
		return
	for attempt in range(2):
		for index in range(_split_viewport.get_flat_rows().size()):
			var split_row: EventRowData = _split_viewport.get_flat_rows()[index].get("row")
			if split_row != null and split_row.source_resource == row_data.source_resource:
				_split_viewport._select_row(index, -1)
				_split_viewport.ensure_selection_visible()
				_split_viewport.queue_redraw()
				return
		# Not in the flat list — it's inside a folded group: unfold the split and retry.
		_split_viewport._fold_state.clear()
		_split_viewport.set_sheet(_dock._current_sheet)


## Mirrors a selection into every OTHER pane (guarded against recursion). Reads the dock's
## linked/mirroring flags (shared by all panes) and iterates the primary + split + detached panes.
func _mirror_selection(from_view: EventSheetViewport, row_data: EventRowData) -> void:
	if not _dock._linked_views or _dock._mirroring_selection or row_data == null or row_data.source_resource == null:
		return
	_dock._mirroring_selection = true
	for view: EventSheetViewport in [_dock._viewport, _split_viewport, _dock._detached_viewport]:
		if view == null or view == from_view or not is_instance_valid(view):
			continue
		for index in range(view.get_flat_rows().size()):
			var candidate: EventRowData = view.get_flat_rows()[index].get("row")
			if candidate != null and candidate.source_resource == row_data.source_resource:
				view._select_row(index, -1)
				view.ensure_selection_visible()
				view.queue_redraw()
				break
	_dock._mirroring_selection = false


func _close_split_view() -> void:
	if _split_container == null:
		return
	if _dock._active_viewport_ref == _split_viewport:
		_dock._active_viewport_ref = null
	var slot: Node = _split_container.get_parent()
	var slot_index: int = _split_container.get_index()
	_split_container.remove_child(_dock._scroll)
	if slot != null:
		slot.add_child(_dock._scroll)
		slot.move_child(_dock._scroll, slot_index)
	_split_container.queue_free()
	_split_container = null
	_split_scroll = null
	_split_viewport = null


## Keeps every secondary pane on the current sheet after edits/opens (the refresh bus).
func _sync_split_sheet() -> void:
	if _split_viewport != null:
		_split_viewport.set_sheet(_dock._current_sheet)
	if _dock._detached_viewport != null:
		_dock._detached_viewport.set_sheet(_dock._current_sheet)


## Find-bar "Open in Split": jumps the split pane to the current match (opening the
## split if needed) — marrying search and multi-view.
func _open_match_in_split() -> void:
	if _dock._find_resource_matches.is_empty():
		_dock._set_status("Find something first.", true)
		return
	var match_resource: Resource = _dock._find_resource_matches[clampi(_dock._find_cursor, 0, _dock._find_resource_matches.size() - 1)]
	if _split_viewport == null:
		_toggle_split_view()
	if _split_viewport != null:
		_split_viewport.reveal_resource(match_resource)
		_dock._set_status("Match opened in the split pane.")
