# EventForge - Inline editing of comments + the group editor popup
#
# Double-clicking a comment starts inline editing; double-clicking a group header opens the
# group editor popup (name + description) via group_edit_requested, NOT an inline title field -
# so a group's description (rendered only once non-empty) is always reachable.
@tool
class_name InlineEditTest
extends RefCounted


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

	# Comment: double-clicking it opens the comment dialog (text + colour), not an inline caret that
	# reads as a whole-row highlight - the dialog is requested and no inline edit starts.
	var comment_index: int = _flat_index(viewport, comment)
	viewport._get_or_build_row_layout(comment_index, width, font, font_size)
	var comment_row: EventRowData = viewport._row_at(comment_index)
	var requested_comment: Array = [null]
	viewport.comment_edit_requested.connect(func(c: Resource) -> void: requested_comment[0] = c)
	_double_click(viewport, comment_row.spans[0].rect.get_center())
	all_passed = _check("double-click a comment opens the dialog, not inline edit",
		requested_comment[0] == comment and int(viewport.get_editing_context_for_test().get("span_index", -1)) == -1, true) and all_passed
	# The apply path still writes the edited text back onto the comment.
	viewport._apply_span_edit(comment_row, comment_row.spans[0], "new comment")
	all_passed = _check("comment text updates on commit", comment.text, "new comment") and all_passed

	# Group: double-clicking a group header opens the group editor popup (group_edit_requested),
	# not an inline title field - so the description (only rendered once non-empty) is reachable.
	var group_index: int = _flat_index(viewport, group)
	viewport._get_or_build_row_layout(group_index, width, font, font_size)
	var group_row: EventRowData = viewport._row_at(group_index)
	all_passed = _check("group header renders its title span", group_row.spans.size() >= 1, true) and all_passed
	var requested_group: Array = [null]
	viewport.group_edit_requested.connect(func(g: EventGroup) -> void: requested_group[0] = g)
	# Double-clicking the group title (the only span now the redundant badge is gone) must still open
	# the group editor popup, not start an inline title field - _begin_edit routes groups to the popup.
	_double_click(viewport, group_row.spans[0].rect.get_center())
	all_passed = _check("double-click a group opens the editor popup, not inline edit",
		requested_group[0] == group and int(viewport.get_editing_context_for_test().get("span_index", -1)) == -1, true) and all_passed
	# The popup's mutation (factored static, no dialog needed) maps name -> .name + .group_name.
	EventSheetDock.set_group_fields(group, "  NewGroup  ", "  the core loop  ")
	all_passed = _check("group name updates (trimmed, mirrored)", group.group_name == "NewGroup" and group.name == "NewGroup", true) and all_passed
	all_passed = _check("group description updates (trimmed)", group.description, "the core loop") and all_passed
	EventSheetDock.set_group_fields(group, "   ", "")
	all_passed = _check("blank group name falls back to Group", group.group_name, "Group") and all_passed

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
