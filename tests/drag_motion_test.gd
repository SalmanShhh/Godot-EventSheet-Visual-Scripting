@tool
extends RefCounted
# Godot EventSheets - a drag you can see
#
# Carrying a row, an event or a cell: the thing pressed lifts (the ghost is the real row), the place
# it would land opens a dashed gap the height of what is carried while the rows round it slide apart
# over SLIDE_MSEC, the place it came from folds away once the pointer has left it, a condition over
# the action lane opens no gap and says why, Esc slides everything back, and Reduced Motion snaps.
# The drop target is read off the sheet AS DRAWN: a point inside an open gap keeps the target, and a
# point on a moved row is read back to that row's own place. Pinned as values on a small sheet:
#   1. an event carried down the sheet: the fold and the gap are in motion, then at rest, the rows
#      after the gap moved by its height, the pointer read back through the drawing;
#   2. an event over the right half of another nests (inside), over the left half it is a sibling;
#   3. a condition carried into another event's lane: the later cells move down by the gap, the row
#      grows by what it needs, the carried cell is left out of its own row;
#   4. a condition over the action lane: no gap, and the reason; the in-row line and bubble are not
#      drawn while the motion is (the gap and the ghost say it);
#   5. Esc: the slide home, then the motion over; Reduced Motion: everything at its end at once.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "drag_motion_test"
## Long enough for any slide to have finished.
const SETTLE_MSEC: int = int(ViewportDragMotion.SLIDE_MSEC) + 60


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
	EventSheetAccessibility.set_reduced_motion(false)
	var ok: bool = true
	ok = _test_event_carried() and ok
	ok = _test_halves() and ok
	ok = _test_cell_carried() and ok
	ok = _test_refused() and ok
	ok = _test_escape_and_reduced_motion() and ok
	ok = _test_several_stack() and ok
	EventSheetAccessibility.set_reduced_motion(false)
	EventSheetAccessibility.invalidate()
	return ok


static func _test_event_carried() -> bool:
	var setup: Dictionary = _setup()
	var viewport: EventSheetViewport = setup["viewport"]
	var first: int = int(setup["first"])
	var third: int = int(setup["third"])
	var motion: ViewportDragMotion = viewport._drag_motion
	var row_height: float = viewport._row_metrics_helper.row_height(third)
	var third_top: float = viewport._row_metrics_helper.row_top(third)
	var first_top: float = viewport._row_metrics_helper.row_top(first)
	viewport._drag_row_index = third
	viewport._drag_row_indices = [third] as Array[int]
	motion.press(Vector2(10.0, third_top + 4.0))
	motion.lift_rows([third], Vector2(10.0, third_top + 6.0))
	var lifted: Array = [motion.active, motion.kind, motion.carried_height, motion.carried_count, motion.left_source]
	# Up the sheet, over the first event: the source starts folding and the gap before event 1 opens.
	motion.pointer_moved(Vector2(10.0, first_top + 2.0))
	motion.target_row_slot(first, 0)
	var moving: Array = [motion.is_animating(), motion._value("fold") < row_height - 0.5,
		motion._value(motion._target_key) < row_height - 0.5]
	OS.delay_msec(SETTLE_MSEC)
	motion.advance()
	var gap: Rect2 = (motion.gap_rects()[0] as Dictionary)["rect"]
	var rested: Array = [motion.is_animating(), motion._value("fold"), gap.size.y, gap.position.y,
		motion.row_offset(first), motion.row_offset(third + 1)]
	# A point inside the gap keeps the target; a point on the moved first event reads back to it.
	var in_gap: Dictionary = motion.to_logical(Vector2(300.0, gap.position.y + gap.size.y * 0.5))
	var on_first: Dictionary = motion.to_logical(Vector2(300.0, first_top + row_height + 3.0))
	motion.finish()
	(setup["editor"] as Node).free()
	return SUPPORT.pins(TEST_NAME, [
		["an event lifts: rows, its own height, one thing carried, still over its place", lifted,
			[true, "rows", row_height, 1, false]],
		["on the first frame the fold and the gap are on their way, not there", moving, [true, true, true]],
		["at rest: still, folded, the gap its height at event 1's place, rows moved by it", rested,
			[false, row_height, row_height, first_top, row_height, 0.0]],
		["a point inside the gap keeps the target", bool(in_gap.get("in_gap", false)), true],
		["a point on the moved event 1 reads back to event 1's own place",
			[bool(on_first.get("in_gap", true)), (on_first.get("position", Vector2.ZERO) as Vector2).y], [false, first_top + 3.0]],
	])


static func _test_halves() -> bool:
	var setup: Dictionary = _setup()
	var viewport: EventSheetViewport = setup["viewport"]
	var first: int = int(setup["first"])
	var third: int = int(setup["third"])
	viewport._drag_row_index = third
	viewport._drag_row_indices = [third] as Array[int]
	var middle_y: float = viewport._row_metrics_helper.row_top(first) + viewport._row_metrics_helper.row_height(first) * 0.25
	var width: float = viewport._get_logical_canvas_width()
	var right: String = viewport._resolve_drop_mode({"row_index": first}, Vector2(width * 0.75, middle_y))
	var left: String = viewport._resolve_drop_mode({"row_index": first}, Vector2(width * 0.25, middle_y))
	viewport._drag_motion.lift_rows([third], Vector2(10.0, viewport._row_metrics_helper.row_top(third)))
	viewport._drag_target_index = first
	viewport._drag_target_mode = "inside"
	viewport.place_drag_gap({"row_index": first})
	var nested_slot: Array = viewport._drag_motion._gaps.values()
	viewport._drag_motion.finish()
	(setup["editor"] as Node).free()
	return SUPPORT.pins(TEST_NAME, [
		["an event over the right half of another nests", right, "inside"],
		["over the left half it is a sibling", left, "before"],
		["the nested gap opens after the event, one step in",
			[int((nested_slot[0] as Dictionary)["slot"]), int((nested_slot[0] as Dictionary)["indent"])], [first + 1, 1]],
	])


static func _test_cell_carried() -> bool:
	var setup: Dictionary = _setup()
	var viewport: EventSheetViewport = setup["viewport"]
	var first: int = int(setup["first"])
	var second: int = int(setup["second"])
	var motion: ViewportDragMotion = viewport._drag_motion
	EventSheetAccessibility.set_reduced_motion(true)
	var source: EventRowData = viewport._row_at(first)
	var carried: int = _span_of(source, "condition", 1)
	var kept: int = _span_of(source, "action", 0)
	var carried_rect: Rect2 = source.spans[carried].rect
	motion.press(carried_rect.get_center())
	motion.lift_cells(first, "condition", [carried], 1, carried_rect.get_center())
	var target_row: EventRowData = viewport._row_at(second)
	var target_cell: int = _span_of(target_row, "condition", 0)
	var gap_y: float = target_row.spans[target_cell].rect.position.y
	motion.pointer_moved(Vector2(carried_rect.get_center().x, viewport._row_metrics_helper.row_top(second) + 2.0))
	motion.target_lane(second, "condition", gap_y)
	var target_plan: Dictionary = motion.row_plan(second)
	var source_plan: Dictionary = motion.row_plan(first)
	var result: Array = [motion.carried_height, (target_plan["span_shift"] as Dictionary).get(target_cell, 0.0),
		(target_plan["span_shift"] as Dictionary).has(_span_of(target_row, "action", 0)),
		motion.lane_growth(second) > 0.0, source_plan["hidden"], motion.row_offset(second + 1) == motion.lane_growth(second)]
	motion.finish()
	EventSheetAccessibility.set_reduced_motion(false)
	(setup["editor"] as Node).free()
	return SUPPORT.pins(TEST_NAME, [
		["a condition into another lane: the cell there moves down by the gap, the action lane does not, the row grows, the carried cell leaves its own row, the rows below move by the growth",
			result, [carried_rect.size.y + 2.0, carried_rect.size.y + 2.0, false, true, [carried], true]],
	])


static func _test_refused() -> bool:
	var setup: Dictionary = _setup()
	var viewport: EventSheetViewport = setup["viewport"]
	var first: int = int(setup["first"])
	var second: int = int(setup["second"])
	var source: EventRowData = viewport._row_at(first)
	var carried: int = _span_of(source, "condition", 1)
	viewport._drag_ace_entries = [viewport._build_ace_drag_entry(source, "condition", 1)]
	viewport._drag_press_hit = {"row_index": first, "span_index": carried}
	viewport.lift_drag(source.spans[carried].rect.get_center())
	var action_cell: Rect2 = viewport._row_at(second).spans[_span_of(viewport._row_at(second), "action", 0)].rect
	viewport._drag.update_ace_drag_target({"row_index": second, "lane": "action", "span_index": -1, "span_metadata": {}},
		action_cell.get_center())
	viewport.place_drag_gap({"row_index": second, "lane": "action"})
	var facts: Dictionary = viewport.drag_display_facts()
	# An invalid target the drag knows about: the ghost says the drag's own reason, and the row's
	# insertion line and bubble are not drawn under the motion.
	viewport._drag_ace_target_row_index = second
	viewport._drag_ace_target_lane = "condition"
	viewport._drag_ace_target_ace_index = 0
	viewport._drag_feedback_text = "This event already has a trigger."
	viewport._drag_ace_drop_valid = false
	viewport.place_drag_gap({"row_index": second, "lane": "condition"})
	var layout: Dictionary = viewport._layout_builder.get_or_build_row_layout(second,
		viewport._get_logical_canvas_width(), viewport._get_font(), viewport._get_font_size())
	var said: Array = [viewport.drag_display_facts()["refusal"], layout.get("ace_drag_rect", Rect2()),
		layout.get("drag_feedback_rect", Rect2())]
	viewport._drag.clear_ace_drag()
	var after: bool = viewport.drag_display_facts()["active"]
	(setup["editor"] as Node).free()
	return SUPPORT.pins(TEST_NAME, [
		["a condition over the action lane opens no gap and says why", [facts["gaps"], facts["refusal"]],
			[[], "Conditions go on the left"]],
		["an invalid target: the ghost says the reason, no line, no bubble", said,
			["This event already has a trigger.", Rect2(), Rect2()]],
		["letting go ends the motion", after, false],
	])


static func _test_escape_and_reduced_motion() -> bool:
	var setup: Dictionary = _setup()
	var viewport: EventSheetViewport = setup["viewport"]
	var first: int = int(setup["first"])
	var third: int = int(setup["third"])
	var motion: ViewportDragMotion = viewport._drag_motion
	var height: float = viewport._row_metrics_helper.row_height(third)
	viewport._drag_row_index = third
	viewport._drag_row_indices = [third] as Array[int]
	viewport.lift_drag(Vector2(10.0, viewport._row_metrics_helper.row_top(third) + 4.0))
	motion.pointer_moved(Vector2(10.0, viewport._row_metrics_helper.row_top(first) + 2.0))
	motion.target_row_slot(first, 0)
	OS.delay_msec(SETTLE_MSEC)
	motion.advance()
	viewport.cancel_drag()
	var sliding: Array = [motion.active, motion.cancelling, motion.is_animating(), viewport._drag_row_index]
	OS.delay_msec(SETTLE_MSEC)
	motion.advance()
	var home: Array = [motion.active, motion.row_offset(first)]
	EventSheetAccessibility.set_reduced_motion(true)
	viewport._drag_row_index = third
	viewport._drag_row_indices = [third] as Array[int]
	viewport.lift_drag(Vector2(10.0, viewport._row_metrics_helper.row_top(third) + 4.0))
	motion.pointer_moved(Vector2(10.0, viewport._row_metrics_helper.row_top(first) + 2.0))
	motion.target_row_slot(first, 0)
	var snapped: Array = [motion.is_animating(), motion._value("fold"), ((motion.gap_rects()[0] as Dictionary)["rect"] as Rect2).size.y]
	viewport.cancel_drag()
	var reduced_cancel: bool = motion.active
	EventSheetAccessibility.set_reduced_motion(false)
	(setup["editor"] as Node).free()
	return SUPPORT.pins(TEST_NAME, [
		["Esc: the drag is let go, and the gap and the fold slide home", sliding, [true, true, true, -1]],
		["then the motion is over and every row is back in its place", home, [false, 0.0]],
		["Reduced Motion: the fold and the gap are at their ends at once", snapped, [false, height, height]],
		["Reduced Motion: Esc is over at once", reduced_cancel, false],
	])


## Two events selected: a plain press on one keeps both, a drag from it carries both as a stack of
## two, and a press let go without dragging narrows the selection to the pressed event.
static func _test_several_stack() -> bool:
	var setup: Dictionary = _setup()
	var viewport: EventSheetViewport = setup["viewport"]
	var first: int = int(setup["first"])
	var third: int = int(setup["third"])
	var number_at: Vector2 = Vector2(4.0, viewport._row_metrics_helper.row_top(first)
		+ viewport._row_metrics_helper.row_height(first) * 0.5)
	viewport._select_row(first)
	viewport._select_from_click(third, -1, true)
	viewport._input_handlers.handle_mouse_button(_button(number_at, true))
	var kept: int = viewport._get_selected_row_indices().size()
	var moved: InputEventMouseMotion = InputEventMouseMotion.new()
	moved.position = number_at + Vector2(0.0, 30.0)
	moved.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport._input_handlers.handle_mouse_motion(moved)
	var carried: Array = [viewport.drag_display_facts()["active"], viewport.drag_display_facts()["count"]]
	viewport.cancel_drag()
	viewport._drag_motion.finish()
	viewport._drag_motion._reset()
	viewport._select_row(first)
	viewport._select_from_click(third, -1, true)
	viewport._input_handlers.handle_mouse_button(_button(number_at, true))
	viewport._input_handlers.handle_mouse_button(_button(number_at, false))
	var clicked: Array = viewport._get_selected_row_indices()
	(setup["editor"] as Node).free()
	return SUPPORT.pins(TEST_NAME, [
		["a plain press on one of two selected events keeps both", kept, 2],
		["dragging from it carries both, stacked with their count", carried, [true, 2]],
		["let go without dragging, the click selects just that event", clicked, [first]],
	])


static func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return button


## A small sheet: event 1 with two conditions and an action, event 2 with a condition and an
## action, event 3 with a condition. {"editor", "viewport", "first", "second", "third"}.
static func _setup() -> Dictionary:
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_event(["IsOnFloor", "Always"], ["QueueFree"]))
	sheet.events.append(_event(["IsInstanceValid"], ["SetVar"]))
	sheet.events.append(_event(["Always"], []))
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var width: float = viewport.get_canvas_logical_width()
	var found: Array = []
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row != null and row.source_resource is EventRow:
			viewport._layout_builder.get_or_build_row_layout(index, width, viewport._get_font(), viewport._get_font_size())
			found.append(index)
	return {"editor": editor, "viewport": viewport, "first": found[0], "second": found[1], "third": found[2]}


static func _event(conditions: Array, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	for ace_id: Variant in conditions:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = str(ace_id)
		event.conditions.append(condition)
	for ace_id: Variant in actions:
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = str(ace_id)
		event.actions.append(action)
	return event


static func _span_of(row: EventRowData, kind: String, ace_index: int) -> int:
	for index: int in range(row.spans.size()):
		var span: SemanticSpan = row.spans[index]
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("kind", "")) == kind \
				and int((span.metadata as Dictionary).get("ace_index", -1)) == ace_index:
			return index
	return -1
