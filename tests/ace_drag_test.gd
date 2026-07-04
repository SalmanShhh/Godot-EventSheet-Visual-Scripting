# EventForge - ACE drag-and-drop move logic
#
# Drives the dock's ace-drop handler (the model side of dragging an individual condition or
# action) and asserts reordering within an event and moving across events. The raw mouse
# drag is in the viewport and is verified by using the editor; this guards the move logic.
@tool
class_name ACEDragTest
extends RefCounted


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
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "on_tick"
	var cond_a: ACECondition = ACECondition.new()
	cond_a.provider_id = "Core"
	cond_a.ace_id = "IsOnFloor"
	var cond_b: ACECondition = ACECondition.new()
	cond_b.provider_id = "Core"
	cond_b.ace_id = "Always"
	event.conditions.append(cond_a)
	event.conditions.append(cond_b)
	var event2: EventRow = EventRow.new()
	event2.trigger_id = "on_ready"
	sheet.events.append(event)
	sheet.events.append(event2)
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	# Reorder: drag condition A (index 0) to after condition B (index 1) -> [B, A].
	var event_row: EventRowData = _find_row(viewport, event)
	all_passed = _check("event row resolved", event_row != null, true) and all_passed
	editor._on_viewport_ace_drop_requested(
		[{"source_resource": event, "kind": "condition", "ace_index": 0}],
		event_row, "condition", 1, "after", false)
	all_passed = _check("conditions reordered to [B, A]",
		event.conditions.size() == 2 and event.conditions[0] == cond_b and event.conditions[1] == cond_a, true) and all_passed

	# Move across events: drag condition A (now index 1) onto event2.
	var event2_row: EventRowData = _find_row(viewport, event2)
	editor._on_viewport_ace_drop_requested(
		[{"source_resource": event, "kind": "condition", "ace_index": 1}],
		event2_row, "condition", -1, "append", false)
	all_passed = _check("source event keeps only B", event.conditions.size() == 1 and event.conditions[0] == cond_b, true) and all_passed
	all_passed = _check("condition A moved to event2", event2.conditions.has(cond_a), true) and all_passed

	# Copy (Ctrl-drag): copy B into event2 without removing it from the source.
	editor._on_viewport_ace_drop_requested(
		[{"source_resource": event, "kind": "condition", "ace_index": 0}],
		event2_row, "condition", -1, "append", true)
	all_passed = _check("copy leaves B in source", event.conditions.has(cond_b), true) and all_passed
	all_passed = _check("copy adds a clone to event2 (now 2 conditions)", event2.conditions.size(), 2) and all_passed

	editor.free()
	return all_passed


static func _find_row(viewport: EventSheetViewport, resource: Resource) -> EventRowData:
	for entry in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == resource:
			return row_data
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_drag_test: %s" % label)
		return true
	print("[FAIL] ace_drag_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
