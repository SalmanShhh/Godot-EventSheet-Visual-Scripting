# EventForge — Sub-event vs parent selection
#
# Selecting a sub-event must NOT select its parent event; selecting a parent should cascade
# to its sub-events. Guards the selection scoping.
@tool
extends RefCounted
class_name SubeventSelectionTest

static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var parent_event: EventRow = EventRow.new()
	parent_event.trigger_id = "on_tick"
	var child_event: EventRow = EventRow.new()
	child_event.trigger_id = "on_ready"
	parent_event.sub_events.append(child_event)
	sheet.events.append(parent_event)
	viewport.set_sheet(sheet)

	var parent_index: int = _flat_index(viewport, parent_event)
	var child_index: int = _flat_index(viewport, child_event)
	all_passed = _check("parent and child rows exist", parent_index >= 0 and child_index >= 0 and child_index != parent_index, true) and all_passed

	# Selecting the sub-event must not select the parent.
	viewport._select_from_click(child_index, -1, false)
	all_passed = _check("sub-event is selected", viewport._row_at(child_index).selected, true) and all_passed
	all_passed = _check("parent is NOT selected when selecting a sub-event", viewport._row_at(parent_index).selected, false) and all_passed

	# Selecting the parent cascades to the sub-event.
	viewport.clear_selection()
	viewport._select_from_click(parent_index, -1, false)
	all_passed = _check("parent is selected", viewport._row_at(parent_index).selected, true) and all_passed
	all_passed = _check("sub-event is selected too (cascade)", viewport._row_at(child_index).selected, true) and all_passed

	viewport.free()
	return all_passed

static func _flat_index(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] subevent_selection_test: %s" % label)
		return true
	print("[FAIL] subevent_selection_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
