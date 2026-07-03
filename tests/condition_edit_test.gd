# EventForge — Condition add/delete on existing events
#
# Adding a condition must never overwrite an existing trigger (e.g. "Every tick"); and
# conditions must be deletable, including down to zero conditions.
@tool
class_name ConditionEditTest
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
	var trigger: ACECondition = ACECondition.new()
	trigger.provider_id = "Core"
	trigger.ace_id = "OnProcess"
	event.trigger = trigger
	sheet.events.append(event)
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	# Adding a normal condition keeps the existing trigger and appends.
	editor._apply_ace_definition(_def("Always", ACEDefinition.ACEType.CONDITION), {},
		{"mode": "append_condition", "selected_resource": event})
	all_passed = _check("trigger preserved when adding a condition", event.trigger == trigger, true) and all_passed
	all_passed = _check("condition appended", event.conditions.size(), 1) and all_passed

	# Adding even a TRIGGER-type ACE must NOT overwrite the existing trigger.
	editor._apply_ace_definition(_def("OnReady", ACEDefinition.ACEType.TRIGGER), {},
		{"mode": "append_condition", "selected_resource": event})
	all_passed = _check("existing trigger not overwritten by a trigger-type add", event.trigger == trigger, true) and all_passed
	all_passed = _check("trigger-type add fell back to a condition", event.conditions.size(), 2) and all_passed

	# Conditions can be deleted (down to zero).
	editor._context_row = _row_for(viewport, event)
	editor._context_hit = {"span_metadata": {"kind": "condition", "ace_index": 0}}
	editor._delete_context_ace()
	all_passed = _check("a condition was deleted", event.conditions.size(), 1) and all_passed
	editor._context_hit = {"span_metadata": {"kind": "condition", "ace_index": 0}}
	editor._delete_context_ace()
	all_passed = _check("event can have zero conditions", event.conditions.size(), 0) and all_passed

	editor.free()
	return all_passed


static func _def(ace_id: String, ace_type: int) -> ACEDefinition:
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "Core"
	definition.id = ace_id
	definition.ace_type = ace_type
	return definition


static func _row_for(viewport: EventSheetViewport, resource: Resource) -> EventRowData:
	for entry in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == resource:
			return row_data
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] condition_edit_test: %s" % label)
		return true
	print("[FAIL] condition_edit_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
