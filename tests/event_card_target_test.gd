# EventForge - one event, one outline, and the whole card is the click target.
#
# An event is drawn as a card: its number in the gutter, both lanes, the padding around the cells,
# the gaps between them, the band under the shorter lane, and half the gap to the next event. This
# pins that EVERY point on that card answers with the same event - and that the three things which
# used to take the press first no longer do: the gap between two events (which cleared the
# selection), the number gutter, and the lane divider five pixels wide down the whole sheet (which
# started a resize). The divider is grabbed in the column header band instead, which is asked here
# in the same breath so the two answers can never drift apart.
#
# The frame the selection draws is pinned as a VALUE: the union of the event's own rows, gutter
# included, which is what "one event, one outline" means in geometry.
@tool
class_name EventCardTargetTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "event_card_target_test"


static func run() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_or_event())
	sheet.events.append(_plain_event())
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var width: float = viewport._get_logical_canvas_width()
	viewport.get_row_layout_for_test(0, width)
	viewport.get_row_layout_for_test(1, width)

	var first_top: float = viewport._get_row_top(0)
	var first_height: float = viewport._get_row_height(0)
	var second_top: float = viewport._get_row_top(1)
	var gap_start: float = first_top + first_height
	var gap_middle: float = (gap_start + second_top) * 0.5

	# ── the gap between two events belongs to the nearer of them ──
	all_passed = SUPPORT.pins(PREFIX, [
		["there is a gap between the two events", gap_start < second_top, true],
		["a point in the gap's top half answers the event above",
			_event_at(viewport, Vector2(width * 0.5, gap_start + (gap_middle - gap_start) * 0.5)), 0],
		["a point in the gap's bottom half answers the event below",
			_event_at(viewport, Vector2(width * 0.5, gap_middle + (second_top - gap_middle) * 0.5)), 1],
	]) and all_passed

	# ── the gutter, the divider band and the space beside an OR'd condition ──
	var divider_x: float = viewport.get_lane_divider_x(width)
	var middle_y: float = first_top + first_height * 0.5
	var or_band_x: float = maxf(divider_x - 6.0, 1.0)
	all_passed = SUPPORT.pins(PREFIX, [
		["a point in the number gutter answers its event",
			_event_at(viewport, Vector2(EventSheetPalette.GUTTER_WIDTH * 0.5, middle_y)), 0],
		["the gutter is a whole-event press, not a cell press",
			str(viewport.press_target_at(Vector2(EventSheetPalette.GUTTER_WIDTH * 0.5, middle_y)).get("target", "")), "event"],
		["a point on the lane divider mid-sheet answers the event, not the divider",
			str(viewport.press_target_at(Vector2(divider_x, middle_y)).get("target", "")), "event"],
		["that same point still answers the event it landed in",
			_event_at(viewport, Vector2(divider_x, middle_y)), 0],
		["the band beside an OR'd condition answers the whole event",
			str(viewport.press_target_at(Vector2(or_band_x, middle_y)).get("target", "")), "event"],
		["the event drew its OR dividers (the stack is really one)",
			viewport._row_at(0).or_condition_lines.size() > 0, true],
	]) and all_passed

	# ── the outline rect IS the union of the event's rows ──
	var expected_card := Rect2(0.0, first_top, width, first_height)
	all_passed = SUPPORT.pins(PREFIX, [
		["the card rect is the union of the event's rows, gutter included",
			viewport.event_card_rect(0), expected_card],
		["the card starts at the gutter's left edge", viewport.event_card_rect(0).position.x, 0.0],
		["the card runs to the end of the action lane", viewport.event_card_rect(0).end.x, width],
	]) and all_passed

	# ── the header band is where the divider is grabbed ──
	var header_grab: Dictionary = viewport.column_header_grab_at(divider_x)
	var header_miss: Dictionary = viewport.column_header_grab_at(divider_x - 60.0)
	all_passed = SUPPORT.pins(PREFIX, [
		["the header band answers the divider", str(header_grab.get("kind", "")), "lane_divider"],
		["it answers with the boundary it will drag",
			is_equal_approx(float(header_grab.get("boundary_x", -1.0)), divider_x), true],
		["away from every boundary the header grabs nothing", header_miss.is_empty(), true],
	]) and all_passed

	# ── what a press actually does ──
	viewport._handle_mouse_button(_press(Vector2(divider_x, middle_y), true))
	viewport._handle_mouse_button(_press(Vector2(divider_x, middle_y), false))
	var after_divider_press: Dictionary = viewport.get_editor_state_snapshot()
	all_passed = SUPPORT.pins(PREFIX, [
		["a press on the divider mid-sheet selects the event",
			int(after_divider_press.get("selected_row_count", 0)), 1],
		["and selects it whole, not by the cell", int(after_divider_press.get("selected_span_count", 0)), 0],
		["it starts no divider drag", viewport._dragging_lane_divider, false],
	]) and all_passed

	viewport._handle_mouse_button(_press(Vector2(EventSheetPalette.GUTTER_WIDTH * 0.5, viewport._get_row_top(1) + viewport._get_row_height(1) * 0.5), true))
	var after_gutter_press: Dictionary = viewport.get_editor_state_snapshot()
	all_passed = SUPPORT.pins(PREFIX, [
		["a press in the gutter selects that event whole",
			int(after_gutter_press.get("selected_row_count", 0)), 1],
		["and no box selection began there", viewport._box_select_active, false],
	]) and all_passed
	viewport._handle_mouse_button(_press(Vector2(EventSheetPalette.GUTTER_WIDTH * 0.5, viewport._get_row_top(1) + viewport._get_row_height(1) * 0.5), false))

	# A press ON a cell still selects that cell alone - the difference the outline is drawn to show.
	var cell: SemanticSpan = _first_condition_span(viewport)
	all_passed = SUPPORT.check(PREFIX, "the event has a condition cell to press", cell != null, true)
	if cell != null:
		var cell_point: Vector2 = cell.rect.get_center()
		all_passed = SUPPORT.check(PREFIX, "a point on a cell answers the cell",
			str(viewport.press_target_at(cell_point).get("target", "")), "cell") and all_passed
		viewport._handle_mouse_button(_press(cell_point, true))
		viewport._handle_mouse_button(_press(cell_point, false))
		all_passed = SUPPORT.pins(PREFIX, [
			["pressing a cell keeps per-cell selection",
				int(viewport.get_editor_state_snapshot().get("selected_span_count", 0)), 1],
			# The frame is the EVENT's mark, so a cell's selection must not wear it.
			["a cell selection draws no card frame", viewport._statement_has_selected_span(0), true],
		]) and all_passed
		viewport._handle_mouse_button(_press(Vector2(EventSheetPalette.GUTTER_WIDTH * 0.5, viewport._get_row_top(0) + viewport._get_row_height(0) * 0.5), true))
		viewport._handle_mouse_button(_press(Vector2(EventSheetPalette.GUTTER_WIDTH * 0.5, viewport._get_row_top(0) + viewport._get_row_height(0) * 0.5), false))
		all_passed = SUPPORT.check(PREFIX, "selecting the event back draws the frame again",
			viewport._statement_has_selected_span(0), false) and all_passed

	# ── box selection starts only outside every card ──
	var below_last: float = viewport._get_row_top(1) + viewport._get_row_height(1) + 40.0
	viewport._handle_mouse_button(_press(Vector2(width * 0.5, below_last), true))
	all_passed = SUPPORT.pins(PREFIX, [
		["a press below the last card starts a box selection", viewport._box_select_active, true],
		["that point belongs to no event", _event_at(viewport, Vector2(width * 0.5, below_last)), -1],
	]) and all_passed
	viewport._handle_mouse_button(_press(Vector2(width * 0.5, below_last), false))

	editor.free()
	return all_passed


## The event index a point lands on, or -1 for the canvas outside every card.
static func _event_at(viewport: EventSheetViewport, point: Vector2) -> int:
	return int(viewport.press_target_at(point).get("event_index", -1))


static func _first_condition_span(viewport: EventSheetViewport) -> SemanticSpan:
	var row_data: EventRowData = viewport._row_at(0)
	if row_data == null:
		return null
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		if str(metadata.get("kind", "")) == "condition" and span.hoverable:
			return span
	return null


## An event whose two conditions are OR'd, which is what draws as one stack in one lane.
static func _or_event() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.condition_mode = EventRow.ConditionMode.OR
	row.conditions.append(_condition("health > 0"))
	row.conditions.append(_condition("shield > 0"))
	return row


static func _plain_event() -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.conditions.append(_condition("armour > 0"))
	return row


static func _condition(expression: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "ExpressionIsTrue"
	condition.params = {"expr": expression}
	return condition


static func _press(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	return event
