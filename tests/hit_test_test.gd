# EventForge — Full-cell hit testing for conditions/actions
#
# Clicking anywhere on a condition/action line (including the padding/gaps to the right of
# the text and the vertical gaps between cells) should select that ACE, not fall back to the
# whole event. Guards the full-line hit-test fallback.
@tool
class_name HitTestTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "on_tick"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "IsOnFloor"
	event.conditions.append(condition)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "MoveAndSlide"
	event.actions.append(action)
	sheet.events.append(event)
	viewport.set_sheet(sheet)

	# Use the same width _hit_test() lays out with, so computed positions match the layout.
	var width: float = viewport.get_canvas_logical_width()
	var font: Font = viewport._get_font()
	var font_size: int = viewport._get_font_size()
	var event_index: int = _flat_index(viewport, event)
	all_passed = _check("event row found", event_index >= 0, true) and all_passed
	viewport._get_or_build_row_layout(event_index, width, font, font_size)
	var row_top: float = viewport._get_row_top(event_index)
	var line_height: float = viewport._get_event_line_height(font_size)
	var divider: float = viewport.get_lane_divider_x(width)

	# Condition (the explicit condition is on the 2nd condition line) — click far right in
	# the condition lane, away from the text, in the cell padding.
	var condition_y: float = row_top + line_height * 1.5
	var condition_hit: Dictionary = viewport._hit_test(Vector2(divider - 24.0, condition_y))
	all_passed = _check("far-right condition-lane click hits a condition",
		str((condition_hit.get("span_metadata", {}) as Dictionary).get("kind", "")) in ["condition", "trigger"], true) and all_passed

	# Action — click far right in the action lane (in the reserved/padding area).
	var action_y: float = row_top + line_height * 0.5
	var action_hit: Dictionary = viewport._hit_test(Vector2(width - 80.0, action_y))
	all_passed = _check("far-right action-lane click hits the action",
		str((action_hit.get("span_metadata", {}) as Dictionary).get("kind", "")), "action") and all_passed

	# A click in the vertical gap just above the action cell still resolves to it.
	var gap_hit: Dictionary = viewport._hit_test(Vector2(divider + 60.0, action_y - line_height * 0.45))
	all_passed = _check("vertical-gap action click still hits an ACE",
		(gap_hit.get("span_index", -1) as int) >= 0, true) and all_passed

	viewport.free()
	return all_passed


static func _flat_index(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] hit_test_test: %s" % label)
		return true
	print("[FAIL] hit_test_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
