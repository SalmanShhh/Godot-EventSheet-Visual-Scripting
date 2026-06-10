# EventForge — Inline editing of comments and group names
#
# Double-clicking a comment or a group row must start inline editing (even when the click
# lands on the group's badge/icon rather than the exact label), and committing the edit must
# update the underlying resource.
@tool
extends RefCounted
class_name InlineEditTest

static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var comment: CommentRow = CommentRow.new()
	comment.text = "old comment"
	var group: EventGroup = EventGroup.new()
	group.name = "OldGroup"
	group.group_name = "OldGroup"
	sheet.events.append(comment)
	sheet.events.append(group)
	viewport.set_sheet(sheet)

	var width: float = viewport.get_canvas_logical_width()
	var font: Font = viewport._get_font()
	var font_size: int = viewport._get_font_size()

	# Comment: double-clicking it starts editing, and applying updates the text.
	var comment_index: int = _flat_index(viewport, comment)
	viewport._get_or_build_row_layout(comment_index, width, font, font_size)
	var comment_row: EventRowData = viewport._row_at(comment_index)
	_double_click(viewport, comment_row.spans[0].rect.get_center())
	all_passed = _check("double-click starts editing the comment",
		int(viewport.get_editing_context_for_test().get("row_index", -1)), comment_index) and all_passed
	viewport._cancel_edit()
	viewport._apply_span_edit(comment_row, comment_row.spans[0], "new comment")
	all_passed = _check("comment text updates on commit", comment.text, "new comment") and all_passed

	# Group: double-clicking the (non-editable) badge still starts editing the name.
	var group_index: int = _flat_index(viewport, group)
	viewport._get_or_build_row_layout(group_index, width, font, font_size)
	var group_row: EventRowData = viewport._row_at(group_index)
	var badge_span_index: int = _first_non_editable_span(group_row)
	all_passed = _check("group has a non-editable badge span to click", badge_span_index >= 0, true) and all_passed
	_double_click(viewport, group_row.spans[badge_span_index].rect.get_center())
	var editing_span: int = int(viewport.get_editing_context_for_test().get("span_index", -1))
	all_passed = _check("double-click group badge edits the name (falls back to editable span)",
		editing_span >= 0 and viewport._span_is_editable(group_row, editing_span), true) and all_passed
	viewport._cancel_edit()
	var title_index: int = viewport._find_first_editable_span(group_row)
	viewport._apply_span_edit(group_row, group_row.spans[title_index], "NewGroup")
	all_passed = _check("group name updates on commit", group.group_name, "NewGroup") and all_passed

	viewport.free()
	return all_passed

static func _double_click(viewport: EventSheetViewport, at: Vector2) -> void:
	viewport._handle_mouse_button(_button(at, true, false))
	viewport._handle_mouse_button(_button(at, false, false))
	viewport._handle_mouse_button(_button(at, true, true))

static func _button(at: Vector2, pressed: bool, double_click: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double_click
	event.position = at
	return event

static func _first_non_editable_span(row_data: EventRowData) -> int:
	for index in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[index]
		if span != null and span.metadata is Dictionary and not bool((span.metadata as Dictionary).get("editable", false)):
			return index
	return -1

static func _flat_index(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inline_edit_test: %s" % label)
		return true
	print("[FAIL] inline_edit_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
