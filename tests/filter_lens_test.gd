# Godot EventSheets - the live filter lens (C3's "show only matching events")
# A view-layer predicate: with a lens set, only top-level rows whose subtree mentions the
# term stay in the flattened view - the sheet itself is never mutated, the hidden count is
# reported, and clearing restores everything. Pins: filtering in/out, sub-event matches
# keeping their parent visible, the hidden count, mutation-free round trip, and clearing.
@tool
class_name FilterLensTest
extends RefCounted


static func _event_with_print(uid: String, value: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.event_uid = uid
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({value})"
	action.params = {"value": value}
	row.actions.append(action)
	return row


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_event_with_print("aa", "\"health low\""))
	sheet.events.append(_event_with_print("bb", "\"score up\""))
	var parent_row: EventRow = _event_with_print("cc", "\"tick\"")
	parent_row.sub_events.append(_event_with_print("dd", "\"health regen\""))
	sheet.events.append(parent_row)
	viewport.set_sheet(sheet)

	var total_rows: int = viewport.get_flat_rows().size()
	viewport.set_lens("health")
	var lensed: Array[Dictionary] = viewport.get_flat_rows()
	var visible_uids: Array = []
	for entry: Dictionary in lensed:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is EventRow:
			visible_uids.append((row_data.source_resource as EventRow).event_uid)
	all_passed = _check("matching events stay visible", visible_uids.has("aa"), true) and all_passed
	all_passed = _check("non-matching events hide", visible_uids.has("bb"), false) and all_passed
	all_passed = _check("a sub-event match keeps its parent visible", visible_uids.has("cc") and visible_uids.has("dd"), true) and all_passed
	all_passed = _check("the hidden count reports the collapsed roots", viewport.lens_hidden_count(), 1) and all_passed
	all_passed = _check("the lens reads active", viewport.lens_active(), true) and all_passed
	all_passed = _check("the sheet itself is untouched", sheet.events.size(), 3) and all_passed

	viewport.clear_lens()
	all_passed = _check("clearing restores every row", viewport.get_flat_rows().size(), total_rows) and all_passed
	all_passed = _check("a cleared lens reads inactive", viewport.lens_active(), false) and all_passed
	viewport.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] filter_lens_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
