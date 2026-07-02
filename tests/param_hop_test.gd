# EventForge — the Param Hop: a keyboard cursor over the selected row's highlighted parameter values.
# Tab already means nest/outdent at row scope (a shipped structural key), so param scope is entered
# EXPLICITLY: Enter on a row that has values. Inside it Tab/Shift+Tab cycle (wrapping), Enter opens the
# one-field editor anchored at the value's rect, Esc drops back to row scope, and any selection change
# or row rebuild clears the cursor (the spans it pointed into are replaced). Rows without values keep
# their old Enter (inline span edit) — the fallback that stops the two Enters from fighting.
@tool
extends RefCounted
class_name ParamHopTest

static func run() -> bool:
	var ok: bool = true

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	sheet.events.append(event)
	var comment: CommentRow = CommentRow.new()
	comment.text = "just a note"
	sheet.events.append(comment)
	dock.setup(sheet)

	# Two actions with a filled param each (via the ghost row's proven apply path) → two hop stops.
	var view: EventSheetViewport = dock._active_view()
	_select_resource(view, event)
	dock._ghost_row._refresh("heal 5")
	dock._ghost_row._apply_selected()
	_select_resource(view, _live_event(dock))  # the funnel replaced resources; re-anchor the selection
	dock._ghost_row._refresh("heal 7")
	dock._ghost_row._apply_selected()
	var live_event: EventRow = _live_event(dock)
	ok = _check("two actions landed", live_event.actions.size(), 2) and ok
	_select_resource(view, live_event)

	# ── Enter on a row with values ENTERS param scope, cursor on the first value ──
	ok = _check("Enter enters param scope", view.handle_enter_key(), true) and ok
	ok = _check("scope is active", view.param_scope_active(), true) and ok
	ok = _check("cursor lands on the first value", str(view._param_cursor_entry().get("text", "")), "5") and ok
	ok = _check("the cursor knows its param", str(view._param_cursor_entry().get("param_id", "")), "amount") and ok

	# ── Tab cycles with wrap; Shift direction reverses ──
	view._param_scope_step(1)
	ok = _check("Tab hops to the second value", str(view._param_cursor_entry().get("text", "")), "7") and ok
	view._param_scope_step(1)
	ok = _check("Tab wraps back to the first", str(view._param_cursor_entry().get("text", "")), "5") and ok
	view._param_scope_step(-1)
	ok = _check("Shift+Tab wraps backwards", str(view._param_cursor_entry().get("text", "")), "7") and ok

	# ── Enter inside scope opens the one-field editor on the LIVE ace, anchored at the value ──
	var captured: Dictionary = {}
	view.param_value_edit_at_rect_requested.connect(func(ace: Resource, param_id: String, current_text: String, _anchor: Rect2) -> void:
		captured["ace"] = ace
		captured["param_id"] = param_id
		captured["text"] = current_text)
	ok = _check("Enter in scope routes to the editor", view.handle_enter_key(), true) and ok
	ok = _check("the editor opens on the cursor's param", str(captured.get("param_id", "")), "amount") and ok
	ok = _check("pre-filled with the current value", str(captured.get("text", "")), "7") and ok
	ok = _check("the target is the LIVE just-applied action", captured.get("ace") == live_event.actions[1], true) and ok

	# ── Esc exits; a selection change also drops the cursor ──
	view.exit_param_scope()
	ok = _check("Esc exits param scope", view.param_scope_active(), false) and ok
	view.handle_enter_key()
	view._select_row(0)
	ok = _check("moving selection drops the cursor", view.param_scope_active(), false) and ok

	# ── A row with NO values keeps the old Enter: inline span editing, never param scope ──
	_select_resource(view, _live_comment(dock))
	view.handle_enter_key()
	ok = _check("comment row falls back to inline editing", view.param_scope_active(), false) and ok
	ok = _check("inline edit actually began", int(view.get_editing_context_for_test().get("row_index", -1)) >= 0, true) and ok
	view._cancel_edit()

	dock.free()
	return ok

static func _select_resource(view: EventSheetViewport, resource: Resource) -> void:
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view.get_flat_rows()[index].get("row")
		if row_data != null and row_data.source_resource == resource:
			view._select_row(index)
			return

static func _live_event(dock: EventSheetDock) -> EventRow:
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			return row
	return null

static func _live_comment(dock: EventSheetDock) -> CommentRow:
	for row: Variant in dock.get_current_sheet().events:
		if row is CommentRow:
			return row
	return null

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] param_hop_test: %s" % label)
		return true
	print("[FAIL] param_hop_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
