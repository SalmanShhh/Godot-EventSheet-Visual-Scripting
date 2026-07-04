# EventForge - Keyboard authoring action handlers
#
# Drives the dock's new keyboard-shortcut handlers directly (out of tree, like
# event_sheet_editor_test) and asserts the model changes. The raw key dispatch +
# text-field-focus guard need the editor GUI and are verified by opening the editor.
@tool
class_name KeyboardActionsTest
extends RefCounted


# No-op undo manager matching the EditorUndoRedoManager call shape the dock uses
# (add_do_method(target, method, ...args)). The dock's default plain UndoRedo rejects that
# arg shape; the real editor injects an EditorUndoRedoManager. This keeps the headless test
# free of undo-API errors while still exercising the real model mutation in each handler.
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
	var sheet: EventSheetResource = _build_sheet()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())

	# G - add group (no selection -> appended at root).
	var before_group: int = sheet.events.size()
	editor._on_add_group_requested()
	all_passed = _check("add group grows events", sheet.events.size(), before_group + 1) and all_passed
	all_passed = _check("added row is a group", sheet.events[sheet.events.size() - 1] is EventGroup, true) and all_passed

	# Q - add comment.
	var before_comment: int = sheet.events.size()
	editor._on_add_comment_requested()
	all_passed = _check("add comment grows events", sheet.events.size(), before_comment + 1) and all_passed
	all_passed = _check("added row is a comment", sheet.events[sheet.events.size() - 1] is CommentRow, true) and all_passed

	# Ctrl+D - duplicate requires an EventRow selection; no selection is a no-op.
	var before_noop: int = sheet.events.size()
	editor.get_viewport_control().clear_selection()
	editor._on_duplicate_requested()
	all_passed = _check("duplicate no-ops without event selection", sheet.events.size(), before_noop) and all_passed

	# Ctrl+D - with the event row selected, clone is inserted after it with a fresh UID.
	var source_event: EventRow = sheet.events[0] as EventRow
	var source_index: int = sheet.events.find(source_event)
	var flat_index: int = _flat_index_of(editor.get_viewport_control(), source_event)
	all_passed = _check("source event resolves to a flat row", flat_index >= 0, true) and all_passed
	if flat_index >= 0:
		editor.get_viewport_control()._select_row(flat_index)
		var before_dup: int = sheet.events.size()
		editor._on_duplicate_requested()
		all_passed = _check("duplicate grows events", sheet.events.size(), before_dup + 1) and all_passed
		var clone: Variant = sheet.events[source_index + 1]
		all_passed = _check("clone is an event row", clone is EventRow, true) and all_passed
		all_passed = _check("clone has a fresh uid", clone is EventRow and (clone as EventRow).event_uid != source_event.event_uid, true) and all_passed
		all_passed = _check("clone preserves condition count", clone is EventRow and (clone as EventRow).conditions.size() == source_event.conditions.size(), true) and all_passed

	editor.free()
	return all_passed


static func _build_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "on_tick"
	var condition: ACECondition = ACECondition.new()
	condition.ace_id = "is_thing"
	event.conditions.append(condition)
	sheet.events.append(event)
	return sheet


static func _flat_index_of(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] keyboard_actions_test: %s" % label)
		return true
	print("[FAIL] keyboard_actions_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
