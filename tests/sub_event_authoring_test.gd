# EventForge - Sub-event authoring (indent / outdent reparenting)
#
# Drives the dock's indent/outdent handlers (Tab / Shift+Tab) and asserts events move into
# and out of EventRow.sub_events correctly. Headless-safe.
@tool
class_name SubEventAuthoringTest
extends RefCounted


# No-op undo manager matching the dock's EditorUndoRedoManager call shape.
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
	var first: EventRow = EventRow.new()
	first.trigger_id = "first"
	var second: EventRow = EventRow.new()
	second.trigger_id = "second"
	sheet.events.append(first)
	sheet.events.append(second)
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	# Indenting the first (top) event is a no-op - nothing above to nest under.
	_select_resource(viewport, first)
	all_passed = _check("indent of the top event is a no-op", editor._indent_selected_event(), false) and all_passed

	# Outdenting a root event is a no-op - already top level.
	_select_resource(viewport, second)
	all_passed = _check("outdent of a root event is a no-op", editor._outdent_selected_event(), false) and all_passed

	# Indent the second event under the first.
	_select_resource(viewport, second)
	all_passed = _check("indent returns true", editor._indent_selected_event(), true) and all_passed
	all_passed = _check("root now holds a single event", sheet.events.size(), 1) and all_passed
	all_passed = _check("first remains at root", sheet.events[0] == first, true) and all_passed
	all_passed = _check("second is nested under first",
		first.sub_events.size() == 1 and first.sub_events[0] == second, true) and all_passed

	# Outdent the second event back to the root, after the first.
	_select_resource(viewport, second)
	all_passed = _check("outdent returns true", editor._outdent_selected_event(), true) and all_passed
	all_passed = _check("root holds two events again", sheet.events.size(), 2) and all_passed
	all_passed = _check("first no longer has sub-events", first.sub_events.is_empty(), true) and all_passed
	all_passed = _check("second is placed after first", sheet.events[1] == second, true) and all_passed

	editor.free()
	return all_passed


static func _select_resource(viewport: EventSheetViewport, resource: Resource) -> void:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			viewport._select_row(i)
			return


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sub_event_authoring_test: %s" % label)
		return true
	print("[FAIL] sub_event_authoring_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
