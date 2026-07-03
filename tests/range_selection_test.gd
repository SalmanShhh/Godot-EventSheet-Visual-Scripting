# EventForge — Shift-range row selection
#
# Shift+click / Shift+Arrow select every row between the selection anchor and the target,
# inclusive, while preserving the anchor so the range can grow OR shrink from the same origin.
# Guards _select_range and its anchor bookkeeping.
@tool
class_name RangeSelectionTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var events: Array[EventRow] = []
	for i in range(5):
		var ev: EventRow = EventRow.new()
		ev.trigger_id = "on_tick"
		sheet.events.append(ev)
		events.append(ev)
	viewport.set_sheet(sheet)

	var idx0: int = _flat_index(viewport, events[0])
	var idx3: int = _flat_index(viewport, events[3])
	all_passed = _check("rows laid out in order", idx0 >= 0 and idx3 > idx0, true) and all_passed

	# Anchor on the first row, then Shift-range to the fourth: rows idx0..idx3 select, anchor kept.
	viewport._select_from_click(idx0, -1, false)
	viewport._select_range(idx3)
	all_passed = _check("range selects the inclusive span", _selected_count(viewport), idx3 - idx0 + 1) and all_passed
	all_passed = _check("range target becomes the lead row", viewport._row_at(idx3).selected, true) and all_passed
	all_passed = _check("anchor row stays selected", viewport._row_at(idx0).selected, true) and all_passed
	all_passed = _check("anchor index is preserved at the origin", viewport._selection_anchor_index, idx0) and all_passed

	# Shrinking the range back toward the anchor deselects the dropped rows (same origin).
	viewport._select_range(idx0 + 1)
	all_passed = _check("range shrinks from the same anchor", _selected_count(viewport), 2) and all_passed
	all_passed = _check("anchor still preserved after shrink", viewport._selection_anchor_index, idx0) and all_passed

	# Shift+Down from an EMPTY selection lands on the FIRST row (it used to skip past it to row 1).
	viewport.clear_selection()
	var shift_down: InputEventKey = InputEventKey.new()
	shift_down.keycode = KEY_DOWN
	shift_down.shift_pressed = true
	shift_down.pressed = true
	viewport._handle_key(shift_down)
	all_passed = _check("Shift+Down from empty selects the first row", viewport._row_at(0).selected, true) and all_passed
	all_passed = _check("Shift+Down from empty selects exactly one row", _selected_count(viewport), 1) and all_passed

	viewport.free()
	return all_passed


static func _selected_count(viewport: EventSheetViewport) -> int:
	var count: int = 0
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.selected:
			count += 1
	return count


static func _flat_index(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] range_selection_test: %s" % label)
		return true
	print("[FAIL] range_selection_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
