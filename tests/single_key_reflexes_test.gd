# EventForge — the single-key reflexes B / I / R + the shortcut-map
# collision audit. B adds a blank sub-event under the selected event, I inverts the selected condition,
# R replaces the selected ACE — each seeding the context state from the SELECTION and reusing the
# right-click handlers verbatim. The audit asserts every DEFAULTS binding is pairwise-unique.
@tool
class_name SingleKeyReflexesTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Shortcut map: B/I/R present + the whole DEFAULTS table is collision-free ──
	ok = _check("B bound to add_blank_subevent", EventSheetShortcuts.binding_for("add_blank_subevent"), "B") and ok
	ok = _check("I bound to invert_condition", EventSheetShortcuts.binding_for("invert_condition"), "I") and ok
	ok = _check("R bound to replace_ace", EventSheetShortcuts.binding_for("replace_ace"), "R") and ok
	var conflict_free: bool = true
	for action: Variant in EventSheetShortcuts.DEFAULTS:
		var clash: String = EventSheetShortcuts.conflicting_action(str(action), EventSheetShortcuts.binding_for(str(action)))
		if not clash.is_empty():
			conflict_free = false
			print("  clash: %s <-> %s" % [str(action), clash])
	ok = _check("every DEFAULTS binding is pairwise-unique", conflict_free, true) and ok
	var order_covers: bool = true
	for action: Variant in EventSheetShortcuts.DEFAULTS:
		if not EventSheetShortcuts.ORDER.has(str(action)):
			order_covers = false
			print("  missing from ORDER: %s" % str(action))
	ok = _check("every action appears in the shortcuts editor (ORDER)", order_covers, true) and ok

	# ── Behavior on a real dock: select → key → effect ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "ExpressionIsTrue"
	condition.params = {"expr": "hp > 0"}
	event.conditions.append(condition)
	sheet.events.append(event)
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()

	# TWO staleness traps this test must respect: (1) every undoable edit REPLACES the sheet's resources
	# (_restore_sheet_snapshot restores a duplicated snapshot), so held EventRow/ACECondition refs go
	# stale — always re-fetch the live objects from the dock; (2) each refresh rebuilds the flat rows and
	# inverting adds the negation badge span, shifting span indices — always re-locate the selection.
	ok = _check("test sheet exposes the condition span", _select_condition(view, _live_event(dock)), true) and ok

	# I with the condition span selected inverts it (and again, un-inverts).
	dock._on_invert_condition_key()
	ok = _check("I inverts the selected condition", _live_condition(dock).negated, true) and ok
	ok = _check("re-locate after the refresh", _select_condition(view, _live_event(dock)), true) and ok
	dock._on_invert_condition_key()
	ok = _check("I again un-inverts", _live_condition(dock).negated, false) and ok

	# B with the event row selected (no span) adds a blank sub-event under it.
	ok = _check("re-locate the row for B", _select_row(view, _live_event(dock)), true) and ok
	dock._on_add_blank_subevent_key()
	ok = _check("B adds a blank sub-event", _live_event(dock).sub_events.size(), 1) and ok

	# Guards: I with no condition span selected and the keys with nothing selected are safe no-ops.
	ok = _check("re-locate the row for the guard", _select_row(view, _live_event(dock)), true) and ok
	dock._on_invert_condition_key()
	ok = _check("I without a condition cell is a no-op", _live_condition(dock).negated, false) and ok
	view._selected_row_index = -1
	view._selected_span_index = -1
	dock._on_add_blank_subevent_key()
	ok = _check("B without a selection is a no-op", _live_event(dock).sub_events.size(), 1) and ok
	dock._on_replace_ace_key()  # no selection → status message, no picker, no crash
	ok = _check("R without a selection is a no-op", true, true) and ok

	dock.free()
	return ok


## The LIVE first EventRow on the dock's current sheet (edits replace resources — never hold refs).
static func _live_event(dock: EventSheetDock) -> EventRow:
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			return row
	return null


static func _live_condition(dock: EventSheetDock) -> ACECondition:
	var event: EventRow = _live_event(dock)
	return event.conditions[0] if event != null and event.conditions.size() > 0 else null


## Selects `event`'s flat row (span cleared). False when the row isn't found.
static func _select_row(view: EventSheetViewport, event: EventRow) -> bool:
	var flat_rows: Array[Dictionary] = view.get_flat_rows()
	for index: int in range(flat_rows.size()):
		var row_data: EventRowData = flat_rows[index].get("row")
		if row_data != null and row_data.source_resource == event:
			view._selected_row_index = index
			view._selected_span_index = -1
			return true
	return false


## Selects `event`'s condition span (building the lazy spans first). False when not found.
static func _select_condition(view: EventSheetViewport, event: EventRow) -> bool:
	if not _select_row(view, event):
		return false
	var row_data: EventRowData = view.get_selected_row_data()
	view._ensure_event_spans(row_data)
	for span_index: int in range(row_data.spans.size()):
		if str((row_data.spans[span_index].metadata as Dictionary).get("kind", "")) == "condition":
			view._selected_span_index = span_index
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] single_key_reflexes_test: %s" % label)
		return true
	print("[FAIL] single_key_reflexes_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
