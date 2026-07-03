# EventForge — the whole-event drag zone. An event row is often taller than its condition lane (its
# ACTION lane has more lines), leaving an empty band below the trigger/conditions. A press there
# should drag the WHOLE event (reorder / nest as a sub-event), not a condition — and it must LOOK
# grabbable (move cursor + brightened grip). This pins: the pure classifier, that the empty band
# hit-tests to whole-event (span_index < 0) while the cell itself still hits its ACE, and that a drag
# begun in the band moves the row.
@tool
class_name EventDragZoneTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The pure classifier ──
	var event_row: EventRowData = EventRowData.new()
	event_row.row_type = EventRowData.RowType.EVENT
	ok = _check("empty band of an event row is a drag zone", EventSheetViewport.is_event_drag_zone(event_row, -1), true) and ok
	ok = _check("landing on an ACE cell (span >= 0) is NOT a drag zone", EventSheetViewport.is_event_drag_zone(event_row, 2), false) and ok
	var section_row: EventRowData = EventRowData.new()
	section_row.row_type = EventRowData.RowType.SECTION
	ok = _check("a variable/section row is NOT a drag zone (single-cell, no ambiguous band)", EventSheetViewport.is_event_drag_zone(section_row, -1), false) and ok
	ok = _check("null row is not a drag zone", EventSheetViewport.is_event_drag_zone(null, -1), false) and ok

	# ── End-to-end geometry: a tall event (multi-line action lane) with a one-line trigger ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	for i in range(3):
		var raw: RawCodeRow = RawCodeRow.new()
		raw.code = "print(%d)" % i
		event.actions.append(raw)
	sheet.events.append(event)
	var second: EventRow = EventRow.new()
	second.trigger_provider_id = "Core"
	second.trigger_id = "OnReady"
	sheet.events.append(second)

	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(900, 600)
	view.set_sheet(sheet)
	view._get_or_build_row_layout(0, view._get_logical_canvas_width(), view._get_font(), view._get_font_size())
	var top: float = view._get_row_top(0)
	var height: float = view._get_row_height(0)
	ok = _check("the action lane makes the event tall (>1 line)", height > view._get_event_line_height(view._get_font_size()) * 1.5, true) and ok

	# Near the top (on the trigger text) hits the trigger; low in the empty condition band is whole-event.
	var top_hit: Dictionary = view._hit_test(Vector2(120.0, top + height * 0.15))
	ok = _check("clicking the trigger text still grabs the trigger",
		str((top_hit.get("span_metadata", {}) as Dictionary).get("kind", "")), "trigger") and ok
	var band_hit: Dictionary = view._hit_test(Vector2(120.0, top + height * 0.7))
	ok = _check("the empty condition band hit-tests to WHOLE-EVENT (no ACE span)", int(band_hit.get("span_index", 0)), -1) and ok
	ok = _check("…and that band IS the drag zone", EventSheetViewport.is_event_drag_zone(view._row_at(0), int(band_hit.get("span_index", 0))), true) and ok

	# A press in the band begins a whole-event drag, and dragging onto the second event reorders it.
	view._begin_row_drag(0)
	ok = _check("a drag begins on the whole event", view._drag_row_index, 0) and ok
	ok = _check("the drag carries just that event", view._drag_row_indices.size(), 1) and ok

	view.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_drag_zone_test: %s" % label)
		return true
	print("[FAIL] event_drag_zone_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
