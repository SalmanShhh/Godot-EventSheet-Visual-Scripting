# EventForge — Drag-to-resize the conditions/actions lane divider
#
# Simulates pressing on the lane divider, dragging it, and releasing, then asserts the
# conditions/actions split ratio changed live and was persisted onto the sheet's editor
# style (a default-themed sheet is promoted to a concrete style).
@tool
extends RefCounted
class_name LaneResizeTest

static func run() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "on_tick"
	sheet.events.append(event)
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()

	var width: float = viewport.get_canvas_logical_width()
	var initial_divider: float = viewport.get_lane_divider_x(width)
	var initial_ratio: float = viewport._get_event_style().condition_lane_ratio
	all_passed = _check("starts default-themed (no editor style)", sheet.editor_style == null, true) and all_passed

	# Press on the divider.
	viewport._handle_mouse_button(_button(initial_divider, 24.0, true))
	all_passed = _check("divider drag started", viewport._dragging_lane_divider, true) and all_passed

	# Drag the divider 80px to the right.
	viewport._handle_mouse_motion(_motion(initial_divider + 80.0, 24.0))
	var dragged_ratio: float = viewport._get_event_style().condition_lane_ratio
	all_passed = _check("ratio grew while dragging right", dragged_ratio > initial_ratio, true) and all_passed

	# Release.
	viewport._handle_mouse_button(_button(initial_divider + 80.0, 24.0, false))
	all_passed = _check("divider drag ended", viewport._dragging_lane_divider, false) and all_passed

	# Persisted onto the sheet (promoted from default theme) at the dragged ratio.
	all_passed = _check("sheet promoted to a concrete editor style", sheet.editor_style != null, true) and all_passed
	if sheet.editor_style != null:
		all_passed = _check("persisted ratio matches the drag",
			is_equal_approx(sheet.editor_style.get_event_style().condition_lane_ratio, dragged_ratio), true) and all_passed

	# Ratio is clamped to a sane range.
	viewport._handle_mouse_button(_button(viewport.get_lane_divider_x(width), 24.0, true))
	viewport._handle_mouse_motion(_motion(width + 500.0, 24.0))
	all_passed = _check("ratio clamped to <= 0.8", viewport._get_event_style().condition_lane_ratio <= 0.8001, true) and all_passed
	viewport._handle_mouse_button(_button(width, 24.0, false))

	editor.free()
	return all_passed

static func _button(x: float, y: float, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(x, y)
	return event

static func _motion(x: float, y: float) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = Vector2(x, y)
	return event

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] lane_resize_test: %s" % label)
		return true
	print("[FAIL] lane_resize_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
