# EventForge — C3-style footer "Add event…" rows + red ✗ negation marker
#
# The sheet ends with an "Add event…" footer and every group keeps one as its last child
# (one level deeper). Footers are inert affordances: no source resource, never box-selected,
# clicking emits add_event_requested with the owner; the dock appends the new event into the
# owner. Also guards the C3 red ✗ (no-circle) inverted-condition marker.
@tool
extends RefCounted
class_name FooterRowsTest

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
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var group: EventGroup = EventGroup.new()
	group.group_name = "Movement"
	var grouped_event: EventRow = EventRow.new()
	grouped_event.trigger_id = "on_tick"
	group.events.append(grouped_event)
	sheet.events.append(group)
	var negated_event: EventRow = EventRow.new()
	negated_event.trigger_id = "on_ready"
	var negated_condition: ACECondition = ACECondition.new()
	negated_condition.provider_id = "Core"
	negated_condition.ace_id = "IsOnFloor"
	negated_condition.negated = true
	negated_event.conditions.append(negated_condition)
	sheet.events.append(negated_event)
	viewport.set_sheet(sheet)

	var flat: Array[Dictionary] = viewport.get_flat_rows()
	var last_row: EventRowData = flat[flat.size() - 1].get("row")
	all_passed = _check("sheet ends with an Add event footer", viewport._row_is_add_event_footer(last_row), true) and all_passed
	all_passed = _check("sheet footer owner is the sheet",
		last_row.spans[0].metadata.get("add_event_owner") == sheet, true) and all_passed
	all_passed = _check("footer has no source resource (inert)", last_row.source_resource == null, true) and all_passed

	var group_row: EventRowData = null
	for entry in flat:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == group:
			group_row = row_data
	var group_footer: EventRowData = group_row.children[group_row.children.size() - 1]
	all_passed = _check("group's last child is its Add event footer", viewport._row_is_add_event_footer(group_footer), true) and all_passed
	all_passed = _check("group footer indented one level deeper", group_footer.indent, group_row.indent + 1) and all_passed
	all_passed = _check("group footer owner is the group",
		group_footer.spans[0].metadata.get("add_event_owner") == group, true) and all_passed

	# Clicking the footer emits add_event_requested with the owner.
	var captured: Dictionary = {"owner": null}
	viewport.add_event_requested.connect(func(owner_resource: Resource) -> void:
		captured["owner"] = owner_resource
	)
	var footer_index: int = flat.size() - 1
	viewport._get_or_build_row_layout(footer_index, viewport.get_canvas_logical_width(), viewport._get_font(), viewport._get_font_size())
	var click_at: Vector2 = last_row.spans[0].rect.get_center()
	viewport._handle_mouse_button(_button(click_at, true))
	all_passed = _check("clicking the footer requests add-event for the sheet", captured["owner"] == sheet, true) and all_passed

	# Box selection never includes footers.
	viewport._apply_box_selection(Rect2(0, 0, 4000, 100000), false)
	all_passed = _check("box selection skips footers",
		not viewport._selected_row_uids.has(last_row.row_uid) and not viewport._selected_row_uids.has(group_footer.row_uid), true) and all_passed

	# Red ✗ negation marker: bare red glyph, transparent badge.
	var negated_row: EventRowData = null
	for entry in flat:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == negated_event:
			negated_row = row_data
	viewport._ensure_event_spans(negated_row)
	var marker_meta: Dictionary = {}
	for span in negated_row.spans:
		if span != null and span.text == "✕" and span.metadata is Dictionary:
			marker_meta = span.metadata
	all_passed = _check("negated condition shows the ✕ marker", not marker_meta.is_empty(), true) and all_passed
	all_passed = _check("✕ marker is C3 red", marker_meta.get("badge_fg", Color.BLACK), Color("#FF0000")) and all_passed
	all_passed = _check("✕ marker has no circle behind it", (marker_meta.get("badge_bg", Color.WHITE) as Color).a, 0.0) and all_passed
	viewport.free()

	# Dock: insert_into appends into the group / at the sheet end.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var edit_sheet: EventSheetResource = EventSheetResource.new()
	var edit_group: EventGroup = EventGroup.new()
	edit_group.group_name = "G"
	edit_sheet.events.append(edit_group)
	editor.setup(edit_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "Core"
	definition.id = "Always"
	definition.ace_type = ACEDefinition.ACEType.CONDITION
	editor._apply_ace_definition(definition, {}, {"mode": "new_condition_event", "insert_into": edit_group})
	var group_children: Array = editor._group_children_array(edit_group)
	all_passed = _check("footer add inserts the new event into the group",
		group_children.size() == 1 and group_children[0] is EventRow, true) and all_passed
	editor._apply_ace_definition(definition, {}, {"mode": "new_condition_event", "insert_into": edit_sheet})
	all_passed = _check("sheet footer add appends at the sheet end",
		edit_sheet.events.size() == 2 and edit_sheet.events[1] is EventRow, true) and all_passed
	editor.free()

	return all_passed

static func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] footer_rows_test: %s" % label)
		return true
	print("[FAIL] footer_rows_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
