# Godot EventSheets - stable event numbers (the C3 margin numbers)
# Every EventRow gets a 1-based number in sheet order - flat and sequential through groups
# and sub-events - computed from the SHEET, so folding or filtering never renumbers and
# "check event 34" stays meaningful. Pins: the numbering walk (groups descend, sub-events
# count, comments don't), event_by_number, the flat-row stamping, and non-events at 0.
@tool
class_name EventNumbersTest
extends RefCounted


static func _event() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	return row


static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	var first: EventRow = _event()
	var comment: CommentRow = CommentRow.new()
	comment.text = "not numbered"
	var parent_row: EventRow = _event()
	var nested: EventRow = _event()
	parent_row.sub_events.append(nested)
	var group: EventGroup = EventGroup.new()
	group.group_name = "Grouped"
	var grouped_event: EventRow = _event()
	group.events.append(grouped_event)
	sheet.events.append(first)
	sheet.events.append(comment)
	sheet.events.append(parent_row)
	sheet.events.append(group)

	# ---- the walk: 1 first, 2 parent, 3 its sub-event, 4 inside the group ----
	var numbers: Dictionary = EventSheetViewport.event_numbers_for(sheet.events)
	all_passed = _check("the first event is 1", int(numbers.get(first.get_instance_id(), 0)), 1) and all_passed
	all_passed = _check("comments are not numbered", numbers.has(comment.get_instance_id()), false) and all_passed
	all_passed = _check("the parent counts next", int(numbers.get(parent_row.get_instance_id(), 0)), 2) and all_passed
	all_passed = _check("its sub-event counts flat after it", int(numbers.get(nested.get_instance_id(), 0)), 3) and all_passed
	all_passed = _check("group members keep counting", int(numbers.get(grouped_event.get_instance_id(), 0)), 4) and all_passed

	# ---- go-to lookup ----
	all_passed = _check("event_by_number finds the sub-event", EventSheetViewport.event_by_number(sheet.events, 3) == nested, true) and all_passed
	all_passed = _check("a number past the end is null", EventSheetViewport.event_by_number(sheet.events, 99) == null, true) and all_passed

	# ---- the viewport stamps numbers onto its rows ----
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var stamped: Dictionary = {}
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource != null:
			stamped[row_data.source_resource] = row_data.event_number
	all_passed = _check("event rows carry their numbers", int(stamped.get(parent_row, -1)), 2) and all_passed
	all_passed = _check("non-events stamp 0", int(stamped.get(comment, -1)), 0) and all_passed
	viewport.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] event_numbers_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
