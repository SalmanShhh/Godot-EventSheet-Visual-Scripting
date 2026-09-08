# EventForge - Drag-to-resize the conditions/actions lane divider, from the column header
#
# The divider is grabbed in the band at the top of the sheet that names the two lanes, never down
# the sheet (where a press five pixels from the line used to start a resize instead of selecting
# the event it landed in). This presses the header's grabber, drags it and lets go, then asserts
# the split ratio changed live and was persisted onto the sheet's editor style (a default-themed
# sheet is promoted to a concrete style). The menu's way back to the default is pinned beside it.
@tool
class_name LaneResizeTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "on_tick"
	sheet.events.append(event)
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var header: SheetColumnHeader = SheetColumnHeader.new()
	header.setup(viewport)

	var width: float = viewport.get_canvas_logical_width()
	var initial_divider: float = viewport.get_lane_divider_x(width)
	var initial_ratio: float = viewport._get_event_style().condition_lane_ratio
	all_passed = _check("starts default-themed (no editor style)", sheet.editor_style == null, true) and all_passed

	# A press on the same line DOWN THE SHEET is not a resize any more - it is a press on the event.
	viewport._handle_mouse_button(_button(initial_divider, 24.0, true))
	all_passed = _check("a press on the divider mid-sheet starts no drag", viewport._dragging_lane_divider, false) and all_passed
	viewport._handle_mouse_button(_button(initial_divider, 24.0, false))

	# Press the header's grabber.
	header.handle_pointer(_button(header.header_x_at(initial_divider), 8.0, true))
	all_passed = _check("divider drag started from the header", viewport._dragging_lane_divider, true) and all_passed

	# Drag the divider 80px to the right.
	header.handle_pointer(_motion(header.header_x_at(initial_divider + 80.0), 8.0))
	var dragged_ratio: float = viewport._get_event_style().condition_lane_ratio
	all_passed = _check("ratio grew while dragging right", dragged_ratio > initial_ratio, true) and all_passed

	# Release.
	header.handle_pointer(_button(header.header_x_at(initial_divider + 80.0), 8.0, false))
	all_passed = _check("divider drag ended", viewport._dragging_lane_divider, false) and all_passed

	# Persisted onto the sheet (promoted from default theme) at the dragged ratio.
	all_passed = _check("sheet promoted to a concrete editor style", sheet.editor_style != null, true) and all_passed
	if sheet.editor_style != null:
		all_passed = _check("persisted ratio matches the drag",
			is_equal_approx(sheet.editor_style.get_event_style().condition_lane_ratio, dragged_ratio), true) and all_passed

	# Ratio is clamped to a sane range.
	header.handle_pointer(_button(header.header_x_at(viewport.get_lane_divider_x(width)), 8.0, true))
	header.handle_pointer(_motion(header.header_x_at(width + 500.0), 8.0))
	all_passed = _check("ratio clamped to <= 0.8", viewport._get_event_style().condition_lane_ratio <= 0.8001, true) and all_passed
	header.handle_pointer(_button(header.header_x_at(width), 8.0, false))

	# The way back that is not a gesture: View ▾ Reset Lane Split puts the theme's own share back.
	var default_ratio: float = EventSheetEventStyle.new().condition_lane_ratio
	viewport.reset_lane_split()
	all_passed = _check("reset returns the split to the theme's own share",
		is_equal_approx(viewport._get_event_style().condition_lane_ratio, default_ratio), true) and all_passed

	header.free()
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
	return SUPPORT.check("lane_resize_test", label, actual, expected)
