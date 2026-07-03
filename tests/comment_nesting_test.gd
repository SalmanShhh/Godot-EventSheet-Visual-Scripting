# EventForge — Comments nestable as sub-events
#
# A comment can sit inside an event as a sub-event (to describe the events beneath it). It
# renders indented under its parent event, and the context-menu helper appends one.
@tool
class_name CommentNestingTest
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

	# A comment placed in an event's sub_events renders indented under it.
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "on_tick"
	var note: CommentRow = CommentRow.new()
	note.text = "describes the events below"
	event.sub_events.append(note)
	sheet.events.append(event)
	viewport.set_sheet(sheet)

	var event_indent: int = -1
	var comment_indent: int = -100
	for entry in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		if row_data.source_resource == event:
			event_indent = row_data.indent
		elif row_data.source_resource == note and row_data.row_type == EventRowData.RowType.COMMENT:
			comment_indent = row_data.indent
	all_passed = _check("nested comment renders as a comment row", comment_indent >= 0, true) and all_passed
	all_passed = _check("nested comment is indented under its event", comment_indent > event_indent, true) and all_passed
	viewport.free()

	# The context-menu helper nests a fresh comment under the selected event.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var edit_sheet: EventSheetResource = EventSheetResource.new()
	var host_event: EventRow = EventRow.new()
	host_event.trigger_id = "on_ready"
	edit_sheet.events.append(host_event)
	editor.setup(edit_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._context_row = _row_for(editor.get_viewport_control(), host_event)
	editor._insert_child_comment_for_context_row()
	all_passed = _check("context menu nests a comment sub-event",
		host_event.sub_events.size() == 1 and host_event.sub_events[0] is CommentRow, true) and all_passed
	editor.free()

	return all_passed


static func _row_for(viewport: EventSheetViewport, resource: Resource) -> EventRowData:
	for entry in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == resource:
			return row_data
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] comment_nesting_test: %s" % label)
		return true
	print("[FAIL] comment_nesting_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
