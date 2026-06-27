# Godot EventSheets — Visual completeness: multiline comments, per-comment colors,
# comment ↔ action-cell conversion (the final event-sheet-parity comment features).
@tool
extends RefCounted
class_name VisualCompletenessTest

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

	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "QueueFree"
	event.actions.append(action)
	sheet.events.append(event)
	var comment: CommentRow = CommentRow.new()
	comment.text = "first line\nsecond line"
	comment.custom_color = Color(0.3, 0.2, 0.1, 1.0)
	sheet.events.append(comment)

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	# Multiline comment rows: one span per line, row height follows, color carried.
	var comment_row_data: EventRowData = null
	for index in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._flat_rows[index].get("row")
		if row != null and row.source_resource == comment:
			comment_row_data = row
	all_passed = _check("comment row found", comment_row_data != null, true) and all_passed
	if comment_row_data != null:
		all_passed = _check("multiline comment spans per line", comment_row_data.spans.size(), 2) and all_passed
		all_passed = _check("multiline comment line_count", comment_row_data.line_count, 2) and all_passed
		all_passed = _check("custom color carried to the row", comment_row_data.custom_color, Color(0.3, 0.2, 0.1, 1.0)) and all_passed

	# Attach: comment row → action-cell comment of the event above.
	editor._attach_comment_to_event_above(comment)
	all_passed = _check("comment attached into the event's actions", event.actions.has(comment), true) and all_passed
	all_passed = _check("comment removed from the sheet rows", sheet.events.has(comment), false) and all_passed

	# Action-cell comments compile to comment lines inside the body.
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_action_comment.gd").get("output", ""))
	all_passed = _check("action-cell comment compiles",
		output.contains("\t# first line") and output.contains("\t# second line"), true) and all_passed

	# Action-cell comment renders as comment-styled action cells (per line, shared index).
	editor._refresh_after_edit()
	var event_row_data: EventRowData = null
	for index in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._flat_rows[index].get("row")
		if row != null and row.source_resource == event:
			event_row_data = row
	viewport._ensure_event_spans(event_row_data)
	var action_comment_spans: int = 0
	for span in event_row_data.spans:
		if bool((span.metadata if span.metadata is Dictionary else {}).get("action_comment", false)):
			action_comment_spans += 1
	all_passed = _check("action-cell comment spans render per line", action_comment_spans, 2) and all_passed
	all_passed = _check("line counting includes action comments",
		viewport._count_event_lines(event), event_row_data.line_count) and all_passed

	# Detach: back to a standalone row directly below the event.
	editor._detach_comment_to_row(comment)
	all_passed = _check("comment detached from actions", event.actions.has(comment), false) and all_passed
	all_passed = _check("comment re-inserted after its event",
		sheet.events.find(comment), sheet.events.find(event) + 1) and all_passed

	# Top-level comments now compile to real comment lines (no TODO placeholder).
	var top_output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_top_comment.gd").get("output", ""))
	all_passed = _check("top-level comments compile to text", top_output.contains("# first line"), true) and all_passed
	all_passed = _check("no TODO placeholder for comments",
		top_output.contains("# TODO: row type not yet implemented"), false) and all_passed

	editor.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] visual_completeness_test: %s" % label)
		return true
	print("[FAIL] visual_completeness_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
