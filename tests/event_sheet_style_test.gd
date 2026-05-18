# EventSheet — editor style/resource regression tests
@tool
extends RefCounted
class_name EventSheetStyleTest

static func run() -> bool:
	var passed: bool = true
	var style := EventSheetEditorStyle.new()
	passed = _check("style creates event style resource", style.event_style != null, true) and passed
	passed = _check("style creates condition style resource", style.condition_style != null, true) and passed
	passed = _check("style creates action style resource", style.action_style != null, true) and passed

	style.event_style.minimum_row_height = 40
	style.event_style.condition_lane_padding = 18
	style.event_style.action_lane_padding = 14
	style.event_style.lane_divider_width = 4
	style.event_style.minimum_conditions_lane_width = 220
	style.condition_style.font_size_delta = 3
	style.condition_style.horizontal_padding = 14
	style.condition_style.vertical_padding = 4
	style.condition_style.gap_after = 14
	style.action_style.font_size_delta = 2
	style.action_style.horizontal_padding = 12
	style.action_style.vertical_padding = 4
	style.action_style.gap_after = 12

	var style_path: String = "user://event_sheet_editor_style_roundtrip.tres"
	var save_err: Error = ResourceSaver.save(style, style_path)
	passed = _check("style round-trip save succeeds", save_err, OK) and passed
	var loaded_style: Resource = ResourceLoader.load(style_path)
	passed = _check("style round-trip loads as EventSheetEditorStyle", loaded_style is EventSheetEditorStyle, true) and passed
	if loaded_style is EventSheetEditorStyle:
		var cast_style: EventSheetEditorStyle = loaded_style as EventSheetEditorStyle
		passed = _check("style round-trip keeps event row height", cast_style.event_style.minimum_row_height, 40) and passed
		passed = _check("style round-trip keeps condition padding", cast_style.condition_style.horizontal_padding, 14) and passed
		passed = _check("style round-trip keeps action gap", cast_style.action_style.gap_after, 12) and passed

	var sheet := EventSheetResource.new()
	sheet.editor_style = style
	sheet.variables["health"] = {"type": "int", "default": 100, "const": true}

	var intro_comment := CommentRow.new()
	intro_comment.text = "Styled rows should stay readable and non-overlapping."

	var styled_group := EventGroup.new()
	styled_group.name = "Styled Group"
	styled_group.group_name = styled_group.name
	var group_child := EventRow.new()
	group_child.event_uid = "group_child"
	group_child.conditions = [_make_condition("Core", "Always", {})]
	group_child.actions = [_make_action("Core", "QueueFree", {})]
	styled_group.events = [group_child]

	var styled_event := EventRow.new()
	styled_event.event_uid = "styled_event"
	styled_event.trigger = _make_condition("Core", "OnReady", {})
	styled_event.conditions = [
		_make_condition("Missing", "Condition text that is intentionally long so custom padding and font size must still stay inside the condition lane", {})
	]
	styled_event.actions = [
		_make_action("Missing", "Action text that is intentionally long so the styled chip must still stay before the add action affordance", {})
	]
	styled_event.comment = "Styled action comment should remain inside the action lane."
	var local_variable := LocalVariable.new()
	local_variable.name = "ammo"
	local_variable.type_name = "int"
	local_variable.default_value = 5
	local_variable.is_constant = true
	styled_event.local_variables.append(local_variable)

	sheet.events = [intro_comment, styled_group, styled_event]

	var dock := EventSheetDock.new()
	dock.setup(sheet)
	var viewport: EventSheetViewport = dock.get_viewport_control()
	var rows: Array[Dictionary] = viewport.get_flat_rows()
	passed = _check("viewport exposes configured editor style", viewport.get_editor_style() == style, true) and passed

	var global_row_index: int = _find_row_index_by_uid(rows, "variable_global_health")
	var comment_row_index: int = _find_row_index_by_text(rows, intro_comment.text)
	var group_row_index: int = _find_row_index_by_text(rows, "Styled Group")
	var event_row_index: int = _find_row_index_by_uid(rows, styled_event.event_uid)
	passed = _check("styled sheet includes global variable row", global_row_index >= 0, true) and passed
	passed = _check("styled sheet includes comment row", comment_row_index >= 0, true) and passed
	passed = _check("styled sheet includes group row", group_row_index >= 0, true) and passed
	passed = _check("styled sheet includes event row", event_row_index >= 0, true) and passed

	var global_layout: Dictionary = viewport.get_row_layout_for_test(global_row_index, 780.0)
	var comment_layout: Dictionary = viewport.get_row_layout_for_test(comment_row_index, 780.0)
	var group_layout: Dictionary = viewport.get_row_layout_for_test(group_row_index, 780.0)
	var event_layout: Dictionary = viewport.get_row_layout_for_test(event_row_index, 780.0)
	var global_row: EventRowData = rows[global_row_index].get("row")
	var comment_row: EventRowData = rows[comment_row_index].get("row")
	var group_row: EventRowData = rows[group_row_index].get("row")
	var event_row: EventRowData = rows[event_row_index].get("row")

	passed = _check("styled event row height expands for custom chip sizing", float(event_layout.get("row_height", 0.0)) > float(EventSheetViewport.ROW_HEIGHT), true) and passed
	passed = _check("adjacent styled rows do not overlap vertically", _rows_are_stacked_without_overlap(viewport, rows, 780.0), true) and passed

	var group_badge_index: int = _find_span_index_by_text(group_row, "Group")
	var group_title_index: int = _find_span_index_by_text(group_row, "Styled Group")
	passed = _check(
		"group badge stays before the styled title",
		group_badge_index >= 0
			and group_title_index >= 0
			and group_row.spans[group_badge_index].rect.end.x < group_row.spans[group_title_index].rect.position.x,
		true
	) and passed

	var scope_index: int = _find_span_index_by_text(global_row, "global")
	var name_index: int = _find_span_index_by_text(global_row, "health")
	var const_index: int = _find_span_index_by_text(global_row, "const")
	var value_index: int = _find_span_index_by_text(global_row, "100")
	var global_row_rect: Rect2 = global_layout.get("row_rect", Rect2())
	passed = _check(
		"variable badge, name, and const spans remain ordered",
		scope_index >= 0
			and name_index >= 0
			and const_index >= 0
			and value_index >= 0
			and global_row.spans[scope_index].rect.end.x < global_row.spans[name_index].rect.position.x
			and global_row.spans[name_index].rect.end.x < global_row.spans[const_index].rect.position.x
			and global_row.spans[value_index].rect.end.x <= global_row_rect.end.x - EventSheetPalette.ROW_HORIZONTAL_PADDING,
		true
	) and passed

	var comment_span_index: int = _find_span_index_by_text(comment_row, intro_comment.text)
	var comment_row_rect: Rect2 = comment_layout.get("row_rect", Rect2())
	passed = _check(
		"comment row stays inside the visible row width",
		comment_span_index >= 0
			and comment_row.spans[comment_span_index].rect.end.x <= comment_row_rect.end.x - EventSheetPalette.ROW_HORIZONTAL_PADDING,
		true
	) and passed

	var condition_index: int = _find_span_index_by_kind(event_row, "condition")
	var action_index: int = _find_span_index_by_kind(event_row, "action")
	var add_action_index: int = _find_span_index_by_kind(event_row, "add_action")
	var action_lane_rect: Rect2 = event_layout.get("action_lane_rect", Rect2())
	var lane_divider_x: float = float(event_layout.get("lane_divider_x", -1.0))
	passed = _check(
		"styled condition and action spans stay in their lanes",
		condition_index >= 0
			and action_index >= 0
			and event_row.spans[condition_index].rect.end.x <= lane_divider_x
			and event_row.spans[action_index].rect.position.x >= lane_divider_x,
		true
	) and passed
	passed = _check(
		"styled action span stays before add action affordance",
		action_index >= 0
			and add_action_index >= 0
			and event_row.spans[action_index].rect.end.x < event_row.spans[add_action_index].rect.position.x
			and event_row.spans[add_action_index].rect.end.x <= action_lane_rect.end.x,
		true
	) and passed

	dock.free()
	return passed

static func _make_condition(provider_id: String, ace_id: String, params: Dictionary) -> ACECondition:
	var condition := ACECondition.new()
	condition.provider_id = provider_id
	condition.ace_id = ace_id
	condition.params = params.duplicate(true)
	return condition

static func _make_action(provider_id: String, ace_id: String, params: Dictionary) -> ACEAction:
	var action := ACEAction.new()
	action.provider_id = provider_id
	action.ace_id = ace_id
	action.params = params.duplicate(true)
	return action

static func _find_row_index_by_uid(rows: Array[Dictionary], expected_uid: String) -> int:
	for index in range(rows.size()):
		var row_data: EventRowData = rows[index].get("row")
		if row_data != null and row_data.row_uid == expected_uid:
			return index
	return -1

static func _find_row_index_by_text(rows: Array[Dictionary], expected_text: String) -> int:
	for index in range(rows.size()):
		var row_data: EventRowData = rows[index].get("row")
		if row_data != null and _find_span_index_by_text(row_data, expected_text) >= 0:
			return index
	return -1

static func _rows_are_stacked_without_overlap(viewport: EventSheetViewport, rows: Array[Dictionary], width: float) -> bool:
	for index in range(rows.size() - 1):
		var current_layout: Dictionary = viewport.get_row_layout_for_test(index, width)
		var next_layout: Dictionary = viewport.get_row_layout_for_test(index + 1, width)
		var current_rect: Rect2 = current_layout.get("row_rect", Rect2())
		var next_rect: Rect2 = next_layout.get("row_rect", Rect2())
		if next_rect.position.y + 0.01 < current_rect.end.y:
			return false
	return true

static func _find_span_index_by_kind(row_data: EventRowData, expected_kind: String) -> int:
	if row_data == null:
		return -1
	for index in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[index]
		if span == null or not (span.metadata is Dictionary):
			continue
		if str((span.metadata as Dictionary).get("kind", "")) == expected_kind:
			return index
	return -1

static func _find_span_index_by_text(row_data: EventRowData, expected_text: String) -> int:
	if row_data == null:
		return -1
	for index in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[index]
		if span != null and span.text == expected_text:
			return index
	return -1

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_sheet_style_test: %s" % label)
		return true
	print("[FAIL] event_sheet_style_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
