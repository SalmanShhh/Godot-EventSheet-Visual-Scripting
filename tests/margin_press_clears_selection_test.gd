# EventForge - a press in the sheet's side margins clears the selection.
#
# The two strips either side of the sheet (the closed side panel's rail, and the part of the scroll
# area the sheet does not cover) are the dock's own controls, so the press reaches the dock's margin
# handler rather than the canvas. This pins: a plain left press clears, a modified or non-left press
# does not, the canvas still answers "canvas" past the last event, and a press on an event's number
# or in the gap between two events still selects an event.
@tool
class_name MarginPressClearsSelectionTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "margin_press_clears_selection_test"


static func run() -> bool:
	var plain: InputEventMouseButton = _press(MOUSE_BUTTON_LEFT, false)
	var ctrl: InputEventMouseButton = _press(MOUSE_BUTTON_LEFT, true)
	var right: InputEventMouseButton = _press(MOUSE_BUTTON_RIGHT, false)
	var release: InputEventMouseButton = _press(MOUSE_BUTTON_LEFT, false)
	release.pressed = false
	var all_passed: bool = SUPPORT.pins(PREFIX, [
		["a plain left press clears from a margin", EventSheetDock.margin_press_clears_selection(plain), true],
		["a Ctrl press changes nothing", EventSheetDock.margin_press_clears_selection(ctrl), false],
		["a right press changes nothing", EventSheetDock.margin_press_clears_selection(right), false],
		["a release changes nothing", EventSheetDock.margin_press_clears_selection(release), false],
		["a motion event changes nothing", EventSheetDock.margin_press_clears_selection(InputEventMouseMotion.new()), false],
	])

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_event("a"))
	sheet.events.append(_event("b"))
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var width: float = viewport._get_logical_canvas_width()
	viewport.get_row_layout_for_test(0, width)
	viewport.get_row_layout_for_test(1, width)
	var metrics: ViewportRowMetrics = viewport._row_metrics_helper
	var first_middle: float = metrics.row_top(0) + metrics.row_height(0) * 0.5
	var gap_low: float = metrics.row_top(0) + metrics.row_height(0) + 0.1
	var below_last: float = metrics.total_height() + 40.0

	all_passed = SUPPORT.pins(PREFIX, [
		["a press on an event's number still answers that event",
			int(viewport.press_target_at(Vector2(EventSheetPalette.GUTTER_WIDTH * 0.5, first_middle)).get("event_index", -9)), 0],
		["the gap just under an event still answers the nearest event",
			int(viewport.press_target_at(Vector2(width * 0.5, gap_low)).get("event_index", -9)), 0],
		["below the last event the canvas answers",
			str(viewport.press_target_at(Vector2(width * 0.5, below_last)).get("target", "")), "canvas"],
	]) and all_passed

	viewport._select_from_click(0, -1, false)
	all_passed = SUPPORT.check(PREFIX, "an event is selected before the margin press",
		int(viewport.get_editor_state_snapshot().get("selected_row_count", 0)), 1) and all_passed
	editor._on_workspace_margin_gui_input(ctrl)
	all_passed = SUPPORT.check(PREFIX, "a Ctrl margin press leaves the selection",
		int(viewport.get_editor_state_snapshot().get("selected_row_count", 0)), 1) and all_passed
	viewport.clear_selection()
	all_passed = SUPPORT.check(PREFIX, "clearing leaves nothing selected",
		int(viewport.get_editor_state_snapshot().get("selected_row_count", 0)), 0) and all_passed
	editor.free()
	return all_passed


static func _press(button: MouseButton, with_ctrl: bool) -> InputEventMouseButton:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.ctrl_pressed = with_ctrl
	return press


static func _event(uid: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.event_uid = uid
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	return row
