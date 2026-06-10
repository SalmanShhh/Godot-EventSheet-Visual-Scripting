# Godot EventSheets — Multi-view phase 1 (split view)
# The same sheet in two panes: per-sheet state (breakpoints/bookmarks/disabled overlay)
# is shared by reference, edits refresh both panes through the refresh bus, the
# companion pane never starts inline edits, and closing the split restores the layout.
@tool
extends RefCounted
class_name MultiViewTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass

static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	for index in range(3):
		var comment: CommentRow = CommentRow.new()
		comment.text = "row %d" % index
		sheet.events.append(comment)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var primary: EventSheetViewport = editor.get_viewport_control()

	# Open the split.
	editor._toggle_split_view()
	var split: EventSheetViewport = editor._split_viewport
	all_passed = _check("split pane exists", split != null, true) and all_passed
	all_passed = _check("split pane shows the same sheet",
		split.get_flat_rows().size(), primary.get_flat_rows().size()) and all_passed
	all_passed = _check("split pane is a full editor (phase 1.5)", split.companion_mode, false) and all_passed

	# Shared per-sheet state: a breakpoint toggled in the primary is true in the split.
	primary._select_row(0, -1)
	primary._toggle_breakpoint(0)
	split.set_sheet(sheet)
	var split_first: EventRowData = split.get_flat_rows()[0].get("row")
	all_passed = _check("breakpoints are shared across panes", split_first.breakpoint_enabled, true) and all_passed
	primary.toggle_bookmark_selected()
	split.set_sheet(sheet)
	split_first = split.get_flat_rows()[0].get("row")
	all_passed = _check("bookmarks are shared across panes", split_first.bookmark_enabled, true) and all_passed

	# Phase 1.5: the split pane is a FULL editor — selection there drives toolbar ops.
	split._select_row(1, -1)
	split.selection_changed.emit(split.get_flat_rows()[1].get("row"))
	all_passed = _check("selection in the split makes it the active view",
		editor._active_view() == split, true) and all_passed
	var second_comment: CommentRow = sheet.events[1] as CommentRow
	editor._toggle_selected_rows_enabled()
	all_passed = _check("Ctrl+/ acts on the SPLIT's selection", second_comment.enabled, false) and all_passed
	editor._toggle_selected_rows_enabled()
	primary._select_row(0, -1)
	primary.selection_changed.emit(primary.get_flat_rows()[0].get("row"))
	all_passed = _check("primary selection reclaims the active view",
		editor._active_view() == primary, true) and all_passed

	# Open in Split pins a row in the other pane.
	var pin_target: EventRowData = primary.get_flat_rows()[2].get("row")
	editor._open_row_in_split(pin_target)
	all_passed = _check("Open in Split selects the row in the other pane",
		split.get_selected_context().get("source_resource", null), sheet.events[2]) and all_passed

	# The refresh bus: a dock edit updates BOTH panes.
	var before: int = split.get_flat_rows().size()
	var added: CommentRow = CommentRow.new()
	added.text = "added"
	var changed: bool = editor._perform_undoable_sheet_edit("Add Row", func() -> bool:
		sheet.events.append(added)
		return true
	)
	if changed:
		editor._refresh_after_edit()
	all_passed = _check("edits refresh the split pane too", split.get_flat_rows().size(), before + 1) and all_passed
	all_passed = _check("edits refresh the primary too", primary.get_flat_rows().size(), before + 1) and all_passed

	# P2: detached window — another full pane sharing state + the refresh bus.
	editor._toggle_detached_view()
	var detached: EventSheetViewport = editor._detached_viewport
	all_passed = _check("detached pane exists", detached != null, true) and all_passed
	all_passed = _check("detached pane shows the sheet",
		detached.get_flat_rows().size(), primary.get_flat_rows().size()) and all_passed
	var detached_first: EventRowData = detached.get_flat_rows()[0].get("row")
	all_passed = _check("detached pane shares breakpoints", detached_first.breakpoint_enabled, true) and all_passed

	# P3: linked panes — selection mirrors across views (no recursion).
	editor._toggle_linked_views()
	primary._select_row(2, -1)
	primary.selection_changed.emit(primary.get_flat_rows()[2].get("row"))
	all_passed = _check("linked panes mirror selection to the split",
		split.get_selected_context().get("source_resource", null), sheet.events[2]) and all_passed
	all_passed = _check("linked panes mirror selection to the detached pane",
		detached.get_selected_context().get("source_resource", null), sheet.events[2]) and all_passed
	# Regression (silent bug): the mirrored panes' selection_changed must NOT steal the
	# active view from the pane the user actually clicked.
	all_passed = _check("mirroring never steals the active view",
		editor._active_view() == primary, true) and all_passed
	editor._toggle_linked_views()
	primary._select_row(0, -1)
	primary.selection_changed.emit(primary.get_flat_rows()[0].get("row"))
	all_passed = _check("unlinking stops the mirroring",
		split.get_selected_context().get("source_resource", null), sheet.events[2]) and all_passed
	editor._toggle_detached_view()
	all_passed = _check("closing clears the detached pane", editor._detached_viewport == null, true) and all_passed

	# Closing restores the original layout and the primary keeps working.
	editor._toggle_split_view()
	all_passed = _check("closing clears the split", editor._split_viewport == null, true) and all_passed
	all_passed = _check("active view falls back to the primary after close",
		editor._active_view() == primary, true) and all_passed
	editor._refresh_after_edit()
	all_passed = _check("primary survives the close", primary.get_flat_rows().size(), before + 1) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] multi_view_test: %s" % label)
		return true
	print("[FAIL] multi_view_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
