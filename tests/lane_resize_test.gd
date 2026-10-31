# EventForge - Drag-to-resize the conditions/actions lane divider, from the line on an event
#
# There is no band above the sheet naming the two lanes: they are told apart by their colour and their
# kind labels, and the line between them on any event is the handle. This presses that line through
# the canvas's own input, drags it and lets go, then asserts the pointer said ↔ first, the split ratio
# changed live and was persisted onto the sheet's editor style (a default-themed sheet is promoted to
# a concrete style), and a press inside a lane is still a press on the event. The menu's way back to
# the default is pinned beside it.
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

	var width: float = viewport.get_canvas_logical_width()
	var initial_divider: float = viewport.get_lane_divider_x(width)
	var initial_ratio: float = viewport._get_event_style().condition_lane_ratio
	var event_y: float = viewport.get_row_top(_first_event_row(viewport)) + 4.0
	all_passed = _check("starts default-themed (no editor style)", sheet.editor_style == null, true) and all_passed

	# The pointer says the line is a handle before the button goes down, and only on the line.
	viewport._gui_input(_motion(initial_divider - 30.0, event_y))
	var inside_cursor: int = viewport.mouse_default_cursor_shape
	viewport._gui_input(_motion(initial_divider, event_y))
	all_passed = _check("the pointer shows ↔ on the line and nowhere else in the event",
		[inside_cursor, viewport.mouse_default_cursor_shape], [Control.CURSOR_ARROW, Control.CURSOR_HSIZE]) and all_passed

	# A press inside a lane is a press on the event, not a resize.
	viewport._gui_input(_button(initial_divider - 30.0, event_y, true))
	all_passed = _check("a press inside a lane starts no drag", viewport._dragging_lane_divider, false) and all_passed
	viewport._gui_input(_button(initial_divider - 30.0, event_y, false))

	# Press the line on the event.
	viewport._gui_input(_button(initial_divider, event_y, true))
	all_passed = _check("a press on the event's divider starts the drag", viewport._dragging_lane_divider, true) and all_passed

	# Drag the divider 80px to the right.
	viewport._gui_input(_motion(initial_divider + 80.0, event_y))
	var dragged_ratio: float = viewport._get_event_style().condition_lane_ratio
	all_passed = _check("ratio grew while dragging right", dragged_ratio > initial_ratio, true) and all_passed

	# Release.
	viewport._gui_input(_button(initial_divider + 80.0, event_y, false))
	all_passed = _check("divider drag ended", viewport._dragging_lane_divider, false) and all_passed

	# Persisted onto the sheet (promoted from default theme) at the dragged ratio.
	all_passed = _check("sheet promoted to a concrete editor style", sheet.editor_style != null, true) and all_passed
	if sheet.editor_style != null:
		all_passed = _check("persisted ratio matches the drag",
			is_equal_approx(sheet.editor_style.get_event_style().condition_lane_ratio, dragged_ratio), true) and all_passed

	# Ratio is clamped to a sane range.
	viewport._gui_input(_button(viewport.get_lane_divider_x(width), event_y, true))
	viewport._gui_input(_motion(width + 500.0, event_y))
	all_passed = _check("ratio clamped to <= 0.8", viewport._get_event_style().condition_lane_ratio <= 0.8001, true) and all_passed
	viewport._gui_input(_button(width, event_y, false))

	# The way back that is not a gesture: View ▾ Reset Lane Split puts the theme's own share back.
	var default_ratio: float = EventSheetEventStyle.new().condition_lane_ratio
	viewport.reset_lane_split()
	all_passed = _check("reset returns the split to the theme's own share",
		is_equal_approx(viewport._get_event_style().condition_lane_ratio, default_ratio), true) and all_passed

	editor.free()
	return all_passed


static func _first_event_row(viewport: EventSheetViewport) -> int:
	for index: int in range(viewport.get_flat_rows().size()):
		var row: EventRowData = viewport._row_at(index)
		if row != null and row.row_type == EventRowData.RowType.EVENT:
			return index
	return -1


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
