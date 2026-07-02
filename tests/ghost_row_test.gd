# EventForge — the Ghost Row (zero-dialog add) + the ranked quick-add matcher behind it. Pressing
# E/C/A opens a type-a-sentence popup whose list shows the top matches; Enter applies the highlighted
# candidate straight onto the sheet. Headless: the popup can't show, but open() still resets state and
# _refresh/_apply_selected drive the whole match→apply flow, so this pins it end to end.
@tool
extends RefCounted
class_name GhostRowTest

static func run() -> bool:
	var ok: bool = true

	# ── The ranked matcher ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	sheet.events.append(event)
	dock.setup(sheet)

	var ranked: Array = dock._quick_match_ranked("process", 5)
	ok = _check("ranked returns candidates", ranked.size() > 1, true) and ok
	ok = _check("ranked caps at the limit", dock._quick_match_ranked("on", 3).size() <= 3, true) and ok
	if ranked.size() > 0:
		ok = _check("shorter name wins the tie (OnProcess over OnPhysicsProcess)",
			str(((ranked[0] as Dictionary).get("definition") as ACEDefinition).id), "OnProcess") and ok
	var healed: Array = dock._quick_match_ranked("heal 5", 5)
	ok = _check("ranked fills trailing params per candidate",
		healed.size() > 0 and str(((healed[0] as Dictionary).get("params") as Dictionary).get("amount", "")) == "5", true) and ok
	ok = _check("garbage ranks nothing", dock._quick_match_ranked("zzz qqq", 5).size(), 0) and ok
	ok = _check("the single-best path agrees with rank 1",
		str((dock._quick_match("process").get("definition") as ACEDefinition).id), "OnProcess") and ok

	# ── The ghost flow: open (headless-safe) → type → apply lands on the selected event ──
	var view: EventSheetViewport = dock._active_view()
	for index: int in range(view.get_flat_rows().size()):
		var row_data: EventRowData = view.get_flat_rows()[index].get("row")
		if row_data != null and row_data.source_resource == event:
			view._selected_row_index = index
	dock._ghost_row.open("action")
	dock._ghost_row._refresh("heal 5")
	ok = _check("ghost list has candidates for 'heal 5'", dock._ghost_row._candidates.size() > 0, true) and ok
	dock._ghost_row._apply_selected()
	var live_event: EventRow = null
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			live_event = row
	ok = _check("Enter applied the action onto the selected event", live_event.actions.size() if live_event != null else -1, 1) and ok
	if live_event != null and live_event.actions.size() == 1 and live_event.actions[0] is ACEAction:
		ok = _check("the applied action carries the filled param",
			str((live_event.actions[0] as ACEAction).params.get("amount", "")), "5") and ok

	# ── Guards: empty query applies nothing; garbage applies nothing ──
	dock._ghost_row._refresh("")
	dock._ghost_row._apply_selected()
	dock._ghost_row._refresh("zzz qqq")
	dock._ghost_row._apply_selected()
	live_event = null
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			live_event = row
	ok = _check("no-match applies never add anything", live_event.actions.size(), 1) and ok

	dock.free()
	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ghost_row_test: %s" % label)
		return true
	print("[FAIL] ghost_row_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
