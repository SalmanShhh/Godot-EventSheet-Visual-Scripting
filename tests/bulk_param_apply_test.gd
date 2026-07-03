# EventForge — bulk retune, "Apply to all N": box-select rows, edit one shared value, Ctrl+Enter
# writes it into the SAME verb's same param on every selected row — structure-aware (only matching
# provider+ace_id verbs that actually carry the param), one undo step, one dirty mark. Pins the
# matching-set collection (trigger/conditions/actions + sub-events + group children; different verbs
# and params untouched), the live re-fetch discipline (the undo funnel replaces resources on commit),
# the no-change no-op, and the hint that advertises the gesture only when several rows are selected.
@tool
class_name BulkParamApplyTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	for amount: String in ["5", "10", "15"]:
		sheet.events.append(_heal_event(amount))
	# A decoy on the second event: same param NAME on a DIFFERENT verb — must stay untouched.
	var decoy: ACEAction = ACEAction.new()
	decoy.provider_id = "Core"
	decoy.ace_id = "method:poison"
	decoy.params = {"amount": "99"}
	(sheet.events[1] as EventRow).actions.append(decoy)
	# A sub-event under the third row carrying the same verb — bulk should reach it.
	var sub: EventRow = EventRow.new()
	var sub_heal: ACEAction = ACEAction.new()
	sub_heal.provider_id = "Core"
	sub_heal.ace_id = "method:heal"
	sub_heal.params = {"amount": "20"}
	sub.actions.append(sub_heal)
	(sheet.events[2] as EventRow).sub_events.append(sub)

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()

	# Box-select all three events (range selection from the first to the last event row).
	var event_indices: Array = []
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view.get_flat_rows()[index].get("row")
		if row_data != null and row_data.source_resource is EventRow and row_data.indent == 0:
			event_indices.append(index)
	view._select_row(int(event_indices[0]))
	view._select_range(int(event_indices[event_indices.size() - 1]))
	ok = _check("three top-level rows selected", dock._top_level_selected_resources().size(), 3) and ok

	# Open the editor on the FIRST event's heal (state only — headless has no window to pop).
	var editor: EventSheetInlineParamEditor = dock._inline_params
	editor.on_param_value_edit_requested((_live_events(dock)[0] as EventRow).actions[0], "amount", "5")
	ok = _check("bulk hint is visible with 3 rows selected", editor._param_edit_hint.visible, true) and ok
	ok = _check("hint names the count", editor._param_edit_hint.text.contains("all 3 selected"), true) and ok

	# ── Ctrl+Enter: one bulk commit ──
	editor._param_edit_field.text = "42"
	editor._commit_inline_param_edit(true)
	var live: Array = _live_events(dock)
	ok = _check("first heal updated", str(((live[0] as EventRow).actions[0] as ACEAction).params.get("amount")), "42") and ok
	ok = _check("second heal updated", str(((live[1] as EventRow).actions[0] as ACEAction).params.get("amount")), "42") and ok
	ok = _check("third heal updated", str(((live[2] as EventRow).actions[0] as ACEAction).params.get("amount")), "42") and ok
	ok = _check("sub-event heal under a selected row updated",
		str((((live[2] as EventRow).sub_events[0] as EventRow).actions[0] as ACEAction).params.get("amount")), "42") and ok
	ok = _check("a DIFFERENT verb with the same param name is untouched",
		str(((live[1] as EventRow).actions[1] as ACEAction).params.get("amount")), "99") and ok

	# ── No-change bulk is a no-op (nothing re-dirtied) ──
	editor.on_param_value_edit_requested((_live_events(dock)[0] as EventRow).actions[0], "amount", "42")
	editor._param_edit_field.text = "42"
	var before_status: String = dock._status_label.text if dock._status_label != null else ""
	editor._commit_inline_param_edit(true)
	var after_status: String = dock._status_label.text if dock._status_label != null else ""
	ok = _check("same-value bulk commit changes nothing", before_status == after_status, true) and ok

	# ── Single selection: the hint hides; plain commit touches only the edited verb ──
	view._select_row(int(event_indices[0]))
	editor.on_param_value_edit_requested((_live_events(dock)[0] as EventRow).actions[0], "amount", "42")
	ok = _check("hint hidden for a single row", editor._param_edit_hint.visible, false) and ok
	editor._param_edit_field.text = "7"
	editor._commit_inline_param_edit()
	live = _live_events(dock)
	ok = _check("plain Enter edits only this row", str(((live[0] as EventRow).actions[0] as ACEAction).params.get("amount")), "7") and ok
	ok = _check("other rows keep the bulk value", str(((live[1] as EventRow).actions[0] as ACEAction).params.get("amount")), "42") and ok

	dock.free()
	return ok


static func _heal_event(amount: String) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var heal: ACEAction = ACEAction.new()
	heal.provider_id = "Core"
	heal.ace_id = "method:heal"
	heal.params = {"amount": amount}
	event.actions.append(heal)
	return event


static func _live_events(dock: EventSheetDock) -> Array:
	var events: Array = []
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			events.append(row)
	return events


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] bulk_param_apply_test: %s" % label)
		return true
	print("[FAIL] bulk_param_apply_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
