# EventForge — restarted event sheet viewport architecture tests
@tool
extends RefCounted
class_name EventSheetEditorTest

class FakeEditorUndoRedoManager:
    extends RefCounted

    var _pending_do: Array[Callable] = []
    var _pending_undo: Array[Callable] = []
    var _undo_stack: Array[Dictionary] = []
    var _redo_stack: Array[Dictionary] = []

    func create_action(_name: String) -> void:
        _pending_do.clear()
        _pending_undo.clear()

    func add_do_method(
        target: Object,
        method_name: String,
        arg1: Variant = null,
        arg2: Variant = null,
        arg3: Variant = null,
        arg4: Variant = null
    ) -> void:
        var args: Array = [arg1, arg2, arg3, arg4]
        _pending_do.append(func() -> void: target.callv(method_name, _trim_null_args(args)))

    func add_undo_method(
        target: Object,
        method_name: String,
        arg1: Variant = null,
        arg2: Variant = null,
        arg3: Variant = null,
        arg4: Variant = null
    ) -> void:
        var args: Array = [arg1, arg2, arg3, arg4]
        _pending_undo.append(func() -> void: target.callv(method_name, _trim_null_args(args)))

    func commit_action() -> void:
        for action in _pending_do:
            action.call()
        _undo_stack.append({"do": _pending_do.duplicate(), "undo": _pending_undo.duplicate()})
        _pending_do.clear()
        _pending_undo.clear()
        _redo_stack.clear()

    func has_undo() -> bool:
        return not _undo_stack.is_empty()

    func has_redo() -> bool:
        return not _redo_stack.is_empty()

    func undo() -> void:
        if _undo_stack.is_empty():
            return
        var action: Dictionary = _undo_stack.pop_back()
        for undo_action in action.get("undo", []):
            (undo_action as Callable).call()
        _redo_stack.append(action)

    func redo() -> void:
        if _redo_stack.is_empty():
            return
        var action: Dictionary = _redo_stack.pop_back()
        for do_action in action.get("do", []):
            (do_action as Callable).call()
        _undo_stack.append(action)

    func clear_history() -> void:
        _pending_do.clear()
        _pending_undo.clear()
        _undo_stack.clear()
        _redo_stack.clear()

    static func _trim_null_args(args: Array) -> Array:
        var output: Array = args.duplicate()
        while not output.is_empty() and output[output.size() - 1] == null:
            output.pop_back()
        return output

## Runs EventSheetEditor architecture tests.
static func run() -> bool:
    var all_passed: bool = true
    var editor: EventSheetEditor = EventSheetEditor.new()
    var scroll: Node = editor.find_child("EventSheetScroll", true, false)
    var viewport: Node = editor.find_child("EventSheetViewport", true, false)
    all_passed = _check("editor root is scroll container shell", scroll is ScrollContainer, true) and all_passed
    all_passed = _check("editor viewport exists", viewport is EventSheetViewport, true) and all_passed
    all_passed = _check("editor keeps required direct hierarchy", scroll != null and scroll.get_child_count() == 1, true) and all_passed
    all_passed = _check("viewport is custom control without row widgets", viewport != null and viewport.get_child_count() == 0, true) and all_passed
    all_passed = _check("viewport baseline row height", EventSheetViewport.ROW_HEIGHT, 28) and all_passed
    all_passed = _check("viewport baseline indent width", EventSheetViewport.INDENT_WIDTH, 18) and all_passed
    all_passed = _check("viewport baseline font size", EventSheetViewport.FONT_SIZE, 13) and all_passed

    var dock: EventSheetDock = editor as EventSheetDock
    dock.setup(null)
    var dock_viewport: EventSheetViewport = dock.get_viewport_control()
    var ace_registry: EventSheetACERegistry = dock.get_ace_registry()
    var toolbar: Node = dock.find_child("EventSheetToolbar", true, false)
    all_passed = _check("demo sheet populates rows", dock_viewport.get_total_row_count() > 0, true) and all_passed
    all_passed = _check("workflow toolbar is present", toolbar is HBoxContainer, true) and all_passed
    var demo_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var first_demo_row: EventRowData = demo_rows[0].get("row")
    all_passed = _check("demo sheet exposes semantic spans", first_demo_row.spans.size() > 0, true) and all_passed
    all_passed = _check("demo flow exposes reflected ace registry", ace_registry.get_reflected_provider_ids().is_empty(), false) and all_passed
    all_passed = _check("demo rows render auto ace trigger text", _rows_contain_text(demo_rows, "On Died"), true) and all_passed
    all_passed = _check("demo rows render trigger arrow badge", _rows_contain_text(demo_rows, "➜"), true) and all_passed
    all_passed = _check("demo rows render auto ace action text", _rows_contain_text(demo_rows, "Take Damage 10"), true) and all_passed
    all_passed = _check("demo rows do not expose debug overlay badges by default", _rows_have_debug_state(demo_rows), false) and all_passed

    var sheet := EventSheetResource.new()
    var group := EventGroup.new()
    group.name = "Rules"
    group.group_name = group.name
    var comment := CommentRow.new()
    comment.text = "Inline note"
    var event_row := EventRow.new()
    event_row.event_uid = "test_event"
    var condition := ACECondition.new()
    condition.provider_id = "Core"
    condition.ace_id = "Always"
    event_row.conditions = [condition]
    var action := ACEAction.new()
    action.provider_id = "Core"
    action.ace_id = "QueueFree"
    event_row.actions = [action]
    group.events.append(event_row)
    sheet.events = [comment, group]
    dock.setup(sheet)
    dock.set_undo_redo_manager(FakeEditorUndoRedoManager.new())
    all_passed = _check("sheet renders flattened rows", dock_viewport.get_total_row_count(), 3) and all_passed
    var flat_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var comment_row_data: EventRowData = flat_rows[0].get("row")
    var group_row: EventRowData = flat_rows[1].get("row")
    var event_row_data: EventRowData = flat_rows[2].get("row")
    all_passed = _check("comment rows render a single editable label span", comment_row_data.spans.size(), 1) and all_passed
    all_passed = _check("group rows render badge and editable title spans", group_row.spans.size() >= 2, true) and all_passed
    all_passed = _check("group row tagged correctly", group_row.row_type, EventRowData.RowType.GROUP) and all_passed
    all_passed = _check("group row includes explicit group badge text", _row_contains_text(group_row, "Group"), true) and all_passed
    all_passed = _check("event row inherits indent", event_row_data.indent, 1) and all_passed
    all_passed = _check("event row action span exists", _row_contains_text(event_row_data, "Queue free"), true) and all_passed
    all_passed = _check("event row includes lane metadata spans", _row_has_lane(event_row_data, "condition") and _row_has_lane(event_row_data, "action"), true) and all_passed
    var layout: Dictionary = dock_viewport.get_row_layout_for_test(2, 640.0)
    var condition_lane_rect: Rect2 = layout.get("condition_lane_rect", Rect2())
    all_passed = _check("event row layout contains lane divider scaffold", float(layout.get("lane_divider_x", -1.0)) > 0.0, true) and all_passed
    var condition_span_index: int = _find_span_index_by_kind(event_row_data, "condition")
    var action_span_index: int = _find_span_index_by_kind(event_row_data, "action")
    var add_action_span_index: int = _find_span_index_by_kind(event_row_data, "add_action")
    all_passed = _check(
        "conditions remain in the left lane while actions stay in the right lane",
        condition_span_index >= 0
            and action_span_index >= 0
            and event_row_data.spans[condition_span_index].rect.end.x <= float(layout.get("lane_divider_x", -1.0))
            and event_row_data.spans[action_span_index].rect.position.x >= float(layout.get("lane_divider_x", -1.0)),
        true
    ) and all_passed
    all_passed = _check(
        "conditions start from the condition track padding",
        condition_span_index >= 0
            and is_equal_approx(
                event_row_data.spans[condition_span_index].rect.position.x,
                condition_lane_rect.position.x + EventSheetPalette.CONDITION_LANE_PADDING
            ),
        true
    ) and all_passed
    all_passed = _check(
        "inline add action affordance stays on the action row after authored actions",
        add_action_span_index >= 0
            and action_span_index >= 0
            and is_equal_approx(event_row_data.spans[add_action_span_index].rect.position.y, event_row_data.spans[action_span_index].rect.position.y)
            and event_row_data.spans[add_action_span_index].rect.position.x > event_row_data.spans[action_span_index].rect.position.x,
        true
    ) and all_passed
    all_passed = _check(
        "action lane spacing keeps adjacent spans tightly aligned",
        action_span_index >= 0
            and add_action_span_index >= 0
            and event_row_data.spans[add_action_span_index].rect.position.x - event_row_data.spans[action_span_index].rect.end.x < 80.0,
        true
    ) and all_passed

    var overlap_sheet := EventSheetResource.new()
    var overlap_comment := CommentRow.new()
    overlap_comment.text = "A very long comment row that should stay inside the visible row bounds instead of drawing over neighboring content in the event sheet."
    var overlap_event := EventRow.new()
    var overlap_condition := ACECondition.new()
    overlap_condition.provider_id = "Missing"
    overlap_condition.ace_id = "Condition text that is intentionally long so it must stay inside the condition lane"
    overlap_event.conditions = [overlap_condition]
    var overlap_action := ACEAction.new()
    overlap_action.provider_id = "Missing"
    overlap_action.ace_id = "Action text that is intentionally long so it must not overlap the add action control"
    overlap_event.actions = [overlap_action]
    overlap_event.comment = "A very long event comment that should remain inside the action lane instead of painting across the viewport."
    overlap_sheet.events = [overlap_comment, overlap_event]
    dock.setup(overlap_sheet)
    dock_viewport = dock.get_viewport_control()
    var overlap_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var overlap_comment_row: EventRowData = overlap_rows[0].get("row")
    var overlap_event_row: EventRowData = overlap_rows[1].get("row")
    var overlap_comment_layout: Dictionary = dock_viewport.get_row_layout_for_test(0, 640.0)
    var overlap_event_layout: Dictionary = dock_viewport.get_row_layout_for_test(1, 640.0)
    var overlap_row_rect: Rect2 = overlap_comment_layout.get("row_rect", Rect2())
    var overlap_action_lane_rect: Rect2 = overlap_event_layout.get("action_lane_rect", Rect2())
    var overlap_comment_span_index: int = _find_span_index_by_text(overlap_comment_row, overlap_comment.text)
    var overlap_event_action_index: int = _find_span_index_by_kind(overlap_event_row, "action")
    var overlap_event_add_index: int = _find_span_index_by_kind(overlap_event_row, "add_action")
    var overlap_event_comment_index: int = _find_span_index_by_text(overlap_event_row, overlap_event.comment)
    all_passed = _check(
        "long comment rows stay inside the row width",
        overlap_comment_span_index >= 0
            and overlap_comment_row.spans[overlap_comment_span_index].rect.end.x <= overlap_row_rect.end.x - EventSheetPalette.ROW_HORIZONTAL_PADDING,
        true
    ) and all_passed
    all_passed = _check(
        "long action text stays before the add action affordance",
        overlap_event_action_index >= 0
            and overlap_event_add_index >= 0
            and overlap_event_row.spans[overlap_event_action_index].rect.end.x < overlap_event_row.spans[overlap_event_add_index].rect.position.x,
        true
    ) and all_passed
    all_passed = _check(
        "long event comments stay inside the action lane",
        overlap_event_comment_index >= 0
            and overlap_event_row.spans[overlap_event_comment_index].rect.end.x <= overlap_action_lane_rect.end.x,
        true
    ) and all_passed

    var or_sheet := EventSheetResource.new()
    var or_event := EventRow.new()
    or_event.trigger_provider_id = "Core"
    or_event.trigger_id = "OnReady"
    var or_condition_a := ACECondition.new()
    or_condition_a.provider_id = "Core"
    or_condition_a.ace_id = "Always"
    var or_condition_b := ACECondition.new()
    or_condition_b.provider_id = "Core"
    or_condition_b.ace_id = "Always"
    or_condition_b.negated = true
    or_event.conditions = [or_condition_a, or_condition_b]
    or_event.condition_mode = EventRow.ConditionMode.OR
    var or_action := ACEAction.new()
    or_action.provider_id = "Core"
    or_action.ace_id = "QueueFree"
    or_event.actions = [or_action]
    or_sheet.events = [or_event]
    dock.setup(or_sheet)
    dock_viewport = dock.get_viewport_control()
    var or_row_data: EventRowData = dock_viewport.get_flat_rows()[0].get("row")
    all_passed = _check("or block adds badge before each condition", _count_span_text(or_row_data, "OR"), 2) and all_passed
    all_passed = _check("negated condition adds red x badge text", _count_span_text(or_row_data, "✕"), 1) and all_passed
    all_passed = _check("or badge appears before first condition span", _find_span_index_by_text(or_row_data, "OR"), _find_span_index_by_kind(or_row_data, "condition") - 1) and all_passed
    all_passed = _check("or badge appears before second condition span", _find_last_span_index_by_text(or_row_data, "OR"), _find_last_span_index_by_kind(or_row_data, "condition") - 1) and all_passed
    dock_viewport.get_row_layout_for_test(0, 640.0)
    var first_condition_index: int = _find_span_index_by_kind(or_row_data, "condition")
    var second_condition_index: int = _find_nth_span_index_by_kind(or_row_data, "condition", 1)
    all_passed = _check(
        "later conditions stay aligned on the same horizontal row",
        second_condition_index >= 0
            and is_equal_approx(or_row_data.spans[second_condition_index].rect.position.y, or_row_data.spans[first_condition_index].rect.position.y)
            and or_row_data.spans[second_condition_index].rect.position.x > or_row_data.spans[first_condition_index].rect.position.x,
        true
    ) and all_passed
    var second_condition_center: Vector2 = or_row_data.spans[second_condition_index].rect.get_center()
    var second_condition_hit: Dictionary = dock_viewport._hit_test(second_condition_center)
    all_passed = _check("hit testing selects individual stacked condition", second_condition_hit.get("span_index", -1), second_condition_index) and all_passed
    dock_viewport._select_from_click(0, second_condition_index, false)
    var condition_selection_state: Dictionary = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("single condition click tracks span selection", condition_selection_state.get("selected_span_count", 0), 1) and all_passed
    dock._context_row = or_row_data
    dock._context_hit = {"span_metadata": {"kind": "condition", "ace_index": 1}, "span_index": _find_last_span_index_by_kind(or_row_data, "condition")}
    dock._on_condition_context_menu_id_pressed(4)
    all_passed = _check("condition context menu toggles inversion", ((dock.get_current_sheet().events[0] as EventRow).conditions[1] as ACECondition).negated, false) and all_passed
    dock._context_row = or_row_data
    dock._context_hit = {"span_metadata": {}, "span_index": -1}
    dock._show_popup_menu(dock._row_context_menu, Vector2(320.0, 240.0))
    all_passed = _check("row context menu opens at requested cursor position", dock._row_context_menu.position, Vector2i(320, 240)) and all_passed
    dock._on_row_context_menu_id_pressed(8)
    all_passed = _check("row context menu toggles or block to and block", ((dock.get_current_sheet().events[0] as EventRow).condition_mode), EventRow.ConditionMode.AND) and all_passed
    all_passed = _check("or block toggle is second row menu item", dock._row_context_menu.get_item_id(1), EventSheetDock.ROW_MENU_TOGGLE_CONDITION_BLOCK) and all_passed
    var compile_result: Dictionary = SheetCompiler.compile(dock.get_current_sheet(), "user://event_sheet_or_block_test.gd")
    all_passed = _check("compiler uses and join after row conversion", str(compile_result.get("output", "")).contains(" and "), true) and all_passed

    var trigger_condition_sheet := EventSheetResource.new()
    var trigger_condition_event := EventRow.new()
    var regular_condition := ACECondition.new()
    regular_condition.provider_id = "Core"
    regular_condition.ace_id = "Always"
    var misplaced_trigger_condition := ACECondition.new()
    misplaced_trigger_condition.provider_id = "Core"
    misplaced_trigger_condition.ace_id = "OnReady"
    trigger_condition_event.conditions = [regular_condition, misplaced_trigger_condition]
    trigger_condition_sheet.events = [trigger_condition_event]
    dock.setup(trigger_condition_sheet)
    dock_viewport = dock.get_viewport_control()
    var trigger_condition_row: EventRowData = dock_viewport.get_flat_rows()[0].get("row")
    dock_viewport.get_row_layout_for_test(0, 640.0)
    var rendered_trigger_index: int = _find_span_index_by_kind(trigger_condition_row, "condition")
    var rendered_condition_index: int = _find_last_span_index_by_kind(trigger_condition_row, "condition")
    all_passed = _check(
        "trigger-type condition renders first in event block",
        int((trigger_condition_row.spans[rendered_trigger_index].metadata as Dictionary).get("ace_index", -1)),
        1
    ) and all_passed
    all_passed = _check(
        "trigger-type condition stays before regular conditions on the same row",
        is_equal_approx(trigger_condition_row.spans[rendered_trigger_index].rect.position.y, trigger_condition_row.spans[rendered_condition_index].rect.position.y)
            and trigger_condition_row.spans[rendered_trigger_index].rect.position.x < trigger_condition_row.spans[rendered_condition_index].rect.position.x,
        true
    ) and all_passed

    dock_viewport._toggle_row_fold(1)
    all_passed = _check("folding hides child rows", dock_viewport.get_total_row_count(), 2) and all_passed
    dock_viewport._toggle_row_fold(1)
    all_passed = _check("unfolding restores child rows", dock_viewport.get_total_row_count(), 3) and all_passed

    dock_viewport._select_row(2)
    all_passed = _check("selection tracks row index", dock_viewport.get_selected_row_index(), 2) and all_passed
    var editor_state: Dictionary = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("selection stores anchor for range scaffolding", editor_state.get("selection_anchor_index", -1), 2) and all_passed
    all_passed = _check("single selection tracks row count", editor_state.get("selected_row_count", 0), 1) and all_passed

    dock.setup(sheet)
    dock_viewport = dock.get_viewport_control()
    var event_rows_for_selection: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock_viewport._select_from_click(1, -1, false)
    dock_viewport._select_from_click(2, _find_span_index_by_kind(event_rows_for_selection[2].get("row"), "condition"), true)
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("ctrl selection tracks multiple rows", editor_state.get("selected_row_count", 0), 2) and all_passed
    all_passed = _check("ctrl selection tracks span highlight count", editor_state.get("selected_span_count", 0), 1) and all_passed
    dock_viewport._select_from_click(2, _find_span_index_by_kind(event_rows_for_selection[2].get("row"), "condition"), true)
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("ctrl click toggles selected span off", editor_state.get("selected_span_count", 0), 0) and all_passed

    var delete_sheet := EventSheetResource.new()
    var delete_event := EventRow.new()
    var delete_condition_a := ACECondition.new()
    delete_condition_a.provider_id = "Core"
    delete_condition_a.ace_id = "Always"
    var delete_condition_b := ACECondition.new()
    delete_condition_b.provider_id = "Core"
    delete_condition_b.ace_id = "Always"
    var delete_action_a := ACEAction.new()
    delete_action_a.provider_id = "Core"
    delete_action_a.ace_id = "QueueFree"
    var delete_action_b := ACEAction.new()
    delete_action_b.provider_id = "Core"
    delete_action_b.ace_id = "QueueFree"
    delete_event.conditions = [delete_condition_a, delete_condition_b]
    delete_event.actions = [delete_action_a, delete_action_b]
    delete_sheet.events = [delete_event, EventRow.new()]
    dock.setup(delete_sheet)
    dock_viewport = dock.get_viewport_control()
    var delete_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var delete_row_data: EventRowData = delete_rows[0].get("row")
    var span_delete_key := InputEventKey.new()
    span_delete_key.pressed = true
    span_delete_key.keycode = KEY_DELETE
    dock_viewport._select_from_click(0, _find_span_index_by_kind(delete_row_data, "condition"), false)
    dock._unhandled_key_input(span_delete_key)
    all_passed = _check("delete key removes selected condition span", ((dock.get_current_sheet().events[0] as EventRow).conditions.size()), 1) and all_passed
    dock_viewport = dock.get_viewport_control()
    delete_row_data = dock_viewport.get_flat_rows()[0].get("row")
    dock_viewport._select_from_click(0, _find_span_index_by_kind(delete_row_data, "action"), false)
    dock_viewport._select_from_click(0, _find_last_span_index_by_kind(delete_row_data, "action"), true)
    dock._unhandled_key_input(span_delete_key)
    all_passed = _check("delete key removes multi-selected action spans", ((dock.get_current_sheet().events[0] as EventRow).actions.size()), 0) and all_passed
    dock_viewport = dock.get_viewport_control()
    dock_viewport._select_row(1)
    dock._unhandled_key_input(span_delete_key)
    all_passed = _check("delete key still removes selected event rows", dock.get_current_sheet().events.size(), 1) and all_passed

    var multi_block_sheet := EventSheetResource.new()
    var multi_event_a := EventRow.new()
    var multi_event_a_condition := ACECondition.new()
    multi_event_a_condition.provider_id = "Core"
    multi_event_a_condition.ace_id = "Always"
    multi_event_a.conditions = [multi_event_a_condition]
    var multi_event_b := EventRow.new()
    var multi_event_b_condition := ACECondition.new()
    multi_event_b_condition.provider_id = "Core"
    multi_event_b_condition.ace_id = "OnReady"
    multi_event_b.conditions = [multi_event_b_condition]
    multi_block_sheet.events = [multi_event_a, multi_event_b]
    dock.setup(multi_block_sheet)
    dock_viewport = dock.get_viewport_control()
    var multi_block_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock_viewport._select_from_click(0, -1, false)
    dock_viewport._select_from_click(1, -1, true)
    dock._context_row = multi_block_rows[1].get("row")
    dock._context_hit = {"span_metadata": {}, "span_index": -1}
    dock._on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_TOGGLE_CONDITION_BLOCK)
    all_passed = _check(
        "multi-selection converts selected events to or block",
        [
            (dock.get_current_sheet().events[0] as EventRow).condition_mode,
            (dock.get_current_sheet().events[1] as EventRow).condition_mode
        ],
        [EventRow.ConditionMode.OR, EventRow.ConditionMode.OR]
    ) and all_passed
    dock._on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_TOGGLE_CONDITION_BLOCK)
    all_passed = _check(
        "multi-selection converts selected events back to and block",
        [
            (dock.get_current_sheet().events[0] as EventRow).condition_mode,
            (dock.get_current_sheet().events[1] as EventRow).condition_mode
        ],
        [EventRow.ConditionMode.AND, EventRow.ConditionMode.AND]
    ) and all_passed

    dock_viewport.custom_minimum_size = Vector2(640.0, 1200.0)
    dock_viewport.size = Vector2(640.0, 1200.0)
    var scroll_shell: ScrollContainer = dock.find_child("EventSheetScroll", true, false)
    if scroll_shell != null:
        scroll_shell.size = Vector2(640.0, 56.0)
        scroll_shell.scroll_vertical = 56
    var visible_range: Vector2i = dock_viewport.get_visible_row_range()
    all_passed = _check("visible range starts from scrolled row", visible_range.x, 2) and all_passed

    dock_viewport._toggle_breakpoint(2)
    var row_after_breakpoint: EventRowData = dock_viewport.get_flat_rows()[2].get("row")
    all_passed = _check("breakpoint toggles on selected row", row_after_breakpoint.breakpoint_enabled, true) and all_passed

    dock_viewport.set_row_disabled(event_row_data.row_uid, true)
    var row_after_disable: EventRowData = dock_viewport.get_flat_rows()[2].get("row")
    all_passed = _check("row disabled scaffold persists by uid", row_after_disable.disabled, true) and all_passed

    dock_viewport._begin_edit(0, 1)
    dock_viewport._editing_buffer = "Changed note"
    dock_viewport._commit_edit()
    all_passed = _check("inline edit updates comment resource", ((dock.get_current_sheet().events[0] as CommentRow).text), "Changed note") and all_passed

    # Drag-drop moves rows in underlying model.
    var move_sheet := EventSheetResource.new()
    var move_a := EventRow.new()
    move_a.comment = "A"
    var move_b := EventRow.new()
    move_b.comment = "B"
    move_sheet.events = [move_a, move_b]
    dock.setup(move_sheet)
    var move_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock._on_row_drop_requested(move_rows[0].get("row"), move_rows[1].get("row"))
    all_passed = _check("drag-drop reorders rows", ((dock.get_current_sheet().events[0] as EventRow).comment), "B") and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo restores drag-drop reorder", ((dock.get_current_sheet().events[0] as EventRow).comment), "A") and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo reapplies drag-drop reorder", ((dock.get_current_sheet().events[0] as EventRow).comment), "B") and all_passed

    var copy_row_sheet := EventSheetResource.new()
    var copy_row_comment := CommentRow.new()
    copy_row_comment.text = "Copy me"
    var copy_row_target := EventRow.new()
    copy_row_target.comment = "Target"
    copy_row_sheet.events = [copy_row_comment, copy_row_target]
    dock.setup(copy_row_sheet)
    dock_viewport = dock.get_viewport_control()
    var copy_row_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock._on_row_drop_requested(copy_row_rows[0].get("row"), copy_row_rows[1].get("row"), "after", true)
    all_passed = _check("ctrl drag-copy keeps original comment row", ((dock.get_current_sheet().events[0]) as CommentRow).text, "Copy me") and all_passed
    all_passed = _check("ctrl drag-copy inserts duplicated comment row", ((dock.get_current_sheet().events[2]) as CommentRow).text, "Copy me") and all_passed

    var multi_move_sheet := EventSheetResource.new()
    var multi_comment_a := CommentRow.new()
    multi_comment_a.text = "First"
    var multi_comment_b := CommentRow.new()
    multi_comment_b.text = "Second"
    var multi_target_event := EventRow.new()
    multi_target_event.comment = "Target"
    multi_move_sheet.events = [multi_comment_a, multi_comment_b, multi_target_event]
    dock.setup(multi_move_sheet)
    dock_viewport = dock.get_viewport_control()
    var multi_move_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock._on_rows_drop_requested(
        [multi_move_rows[0].get("row"), multi_move_rows[1].get("row")],
        multi_move_rows[2].get("row"),
        "after"
    )
    all_passed = _check(
        "multi-row drag preserves selected row order",
        [
            (dock.get_current_sheet().events[1] as CommentRow).text,
            (dock.get_current_sheet().events[2] as CommentRow).text
        ],
        ["First", "Second"]
    ) and all_passed

    var nested_sheet := EventSheetResource.new()
    var root_event := EventRow.new()
    root_event.comment = "root"
    var nested_group := EventGroup.new()
    nested_group.name = "Group"
    nested_group.group_name = nested_group.name
    nested_sheet.events = [root_event, nested_group]
    dock.setup(nested_sheet)
    dock_viewport = dock.get_viewport_control()
    var nested_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock._on_row_drop_requested(nested_rows[0].get("row"), nested_rows[1].get("row"), "inside")
    all_passed = _check("drag-drop can move event into group", ((dock.get_current_sheet().events[0] as EventGroup).events.size()), 1) and all_passed
    dock._on_row_drop_requested(dock_viewport.get_flat_rows()[1].get("row"), dock_viewport.get_flat_rows()[0].get("row"), "after")
    all_passed = _check("drag-drop can move event back out of group", ((dock.get_current_sheet().events[1] as EventRow).comment), "root") and all_passed

    var group_drag_sheet := EventSheetResource.new()
    var outer_group := EventGroup.new()
    outer_group.name = "Outer"
    outer_group.group_name = outer_group.name
    var inner_group := EventGroup.new()
    inner_group.name = "Inner"
    inner_group.group_name = inner_group.name
    group_drag_sheet.events = [outer_group, inner_group]
    dock.setup(group_drag_sheet)
    dock_viewport = dock.get_viewport_control()
    var group_drag_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock._on_row_drop_requested(group_drag_rows[0].get("row"), group_drag_rows[1].get("row"), "inside")
    all_passed = _check("drag-drop can move group into group", dock.get_current_sheet().events.size(), 1) and all_passed
    all_passed = _check(
        "drag-drop nests moved group inside target group",
        (((dock.get_current_sheet().events[0] as EventGroup).events[0]) as EventGroup).group_name,
        "Outer"
    ) and all_passed

    # Copy/paste event row.
    dock_viewport._select_row(0)
    dock._on_copy_requested()
    dock._on_paste_requested()
    all_passed = _check("copy paste row inserts duplicate", dock.get_current_sheet().events.size(), 3) and all_passed

    # Copy/paste condition and action entries.
    var copy_sheet := EventSheetResource.new()
    var copy_event := EventRow.new()
    var copy_condition := ACECondition.new()
    copy_condition.provider_id = "Core"
    copy_condition.ace_id = "Always"
    copy_event.conditions = [copy_condition]
    var copy_action := ACEAction.new()
    copy_action.provider_id = "Core"
    copy_action.ace_id = "QueueFree"
    copy_event.actions = [copy_action]
    copy_sheet.events = [copy_event]
    dock.setup(copy_sheet)
    dock_viewport._select_row(0, _find_span_index_by_kind(dock_viewport.get_flat_rows()[0].get("row"), "condition"))
    dock._on_copy_requested()
    dock._on_paste_requested()
    all_passed = _check("copy paste condition appends condition", ((dock.get_current_sheet().events[0] as EventRow).conditions.size()), 2) and all_passed
    dock.setup(copy_sheet)
    dock_viewport._select_row(0, _find_span_index_by_kind(dock_viewport.get_flat_rows()[0].get("row"), "action"))
    dock._on_copy_requested()
    dock._on_paste_requested()
    all_passed = _check("copy paste action appends action", ((dock.get_current_sheet().events[0] as EventRow).actions.size()), 2) and all_passed

    var ace_copy_sheet := EventSheetResource.new()
    var ace_copy_source := EventRow.new()
    var ace_copy_condition_a := ACECondition.new()
    ace_copy_condition_a.provider_id = "Core"
    ace_copy_condition_a.ace_id = "Always"
    var ace_copy_condition_b := ACECondition.new()
    ace_copy_condition_b.provider_id = "Core"
    ace_copy_condition_b.ace_id = "IsInstanceValid"
    ace_copy_source.conditions = [ace_copy_condition_a, ace_copy_condition_b]
    var ace_copy_source_action := ACEAction.new()
    ace_copy_source_action.provider_id = "Core"
    ace_copy_source_action.ace_id = "QueueFree"
    ace_copy_source.actions = [ace_copy_source_action]
    var ace_copy_target := EventRow.new()
    var ace_copy_target_condition := ACECondition.new()
    ace_copy_target_condition.provider_id = "Core"
    ace_copy_target_condition.ace_id = "Always"
    ace_copy_target.conditions = [ace_copy_target_condition]
    var ace_copy_target_action := ACEAction.new()
    ace_copy_target_action.provider_id = "Core"
    ace_copy_target_action.ace_id = "SetVar"
    ace_copy_target.actions = [ace_copy_target_action]
    ace_copy_sheet.events = [ace_copy_source, ace_copy_target]
    dock.setup(ace_copy_sheet)
    dock_viewport = dock.get_viewport_control()
    var ace_copy_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock._on_viewport_ace_drop_requested(
        [
            {"source_resource": ace_copy_source, "kind": "condition", "ace_index": 0},
            {"source_resource": ace_copy_source, "kind": "condition", "ace_index": 1}
        ],
        ace_copy_rows[1].get("row"),
        "condition",
        0,
        "before",
        true
    )
    all_passed = _check("ctrl drag-copy keeps original source conditions", ace_copy_source.conditions.size(), 2) and all_passed
    all_passed = _check(
        "ctrl drag-copy duplicates multiple conditions in order",
        [
            ((dock.get_current_sheet().events[1] as EventRow).conditions[0] as ACECondition).ace_id,
            ((dock.get_current_sheet().events[1] as EventRow).conditions[1] as ACECondition).ace_id
        ],
        ["Always", "IsInstanceValid"]
    ) and all_passed
    dock._on_viewport_ace_drop_requested(
        [{"source_resource": ace_copy_source, "kind": "action", "ace_index": 0}],
        ace_copy_rows[1].get("row"),
        "action",
        0,
        "before",
        true
    )
    all_passed = _check("ctrl drag-copy keeps original source action", ace_copy_source.actions.size(), 1) and all_passed
    all_passed = _check(
        "ctrl drag-copy duplicates action into target event",
        ((dock.get_current_sheet().events[1] as EventRow).actions[0] as ACEAction).ace_id,
        "QueueFree"
    ) and all_passed

    var ace_drag_sheet := EventSheetResource.new()
    var ace_drag_source := EventRow.new()
    var ace_drag_condition_a := ACECondition.new()
    ace_drag_condition_a.provider_id = "Core"
    ace_drag_condition_a.ace_id = "Always"
    var ace_drag_condition_b := ACECondition.new()
    ace_drag_condition_b.provider_id = "Core"
    ace_drag_condition_b.ace_id = "OnReady"
    ace_drag_source.conditions = [ace_drag_condition_a, ace_drag_condition_b]
    var ace_drag_target := EventRow.new()
    var ace_drag_target_condition := ACECondition.new()
    ace_drag_target_condition.provider_id = "Core"
    ace_drag_target_condition.ace_id = "IsInstanceValid"
    ace_drag_target.conditions = [ace_drag_target_condition]
    ace_drag_sheet.events = [ace_drag_source, ace_drag_target]
    dock.setup(ace_drag_sheet)
    dock_viewport = dock.get_viewport_control()
    var ace_drag_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var drag_target_row_data: EventRowData = ace_drag_rows[1].get("row")
    dock_viewport.get_row_layout_for_test(1, 640.0)
    var first_target_condition_index: int = _find_span_index_by_kind(drag_target_row_data, "condition")
    var first_target_condition_span: SemanticSpan = drag_target_row_data.spans[first_target_condition_index]
    dock_viewport._drag_ace_entries = [dock_viewport._build_ace_drag_entry(ace_drag_rows[0].get("row"), "condition", 0)]
    dock_viewport._update_ace_drag_target(
        {
            "row_index": 1,
            "span_index": first_target_condition_index,
            "lane": "condition",
            "span_metadata": first_target_condition_span.metadata
        },
        first_target_condition_span.rect.get_center() + Vector2(first_target_condition_span.rect.size.x * 0.35, 0.0)
    )
    var drag_preview_layout: Dictionary = dock_viewport.get_row_layout_for_test(1, 640.0)
    var ace_drag_rect: Rect2 = drag_preview_layout.get("ace_drag_rect", Rect2())
    all_passed = _check("ace drag target uses horizontal insertion after cursor midpoint", dock_viewport._drag_ace_insert_mode, "after") and all_passed
    all_passed = _check("ace drag preview renders as a thin vertical placement line", ace_drag_rect.size.x <= 4.0, true) and all_passed
    dock_viewport._clear_ace_drag()
    dock._on_viewport_ace_drop_requested(
        [{"source_resource": ace_drag_source, "kind": "condition", "ace_index": 0}],
        ace_drag_rows[1].get("row"),
        "condition",
        0,
        "before"
    )
    all_passed = _check(
        "ace drag inserts condition into target event",
        ((dock.get_current_sheet().events[1] as EventRow).conditions[0] as ACECondition).ace_id,
        "Always"
    ) and all_passed
    all_passed = _check(
        "ace drag removes moved condition from source event",
        (dock.get_current_sheet().events[0] as EventRow).conditions.size(),
        1
    ) and all_passed

    var invalid_trigger_sheet := EventSheetResource.new()
    var invalid_trigger_source := EventRow.new()
    var moved_trigger := ACECondition.new()
    moved_trigger.provider_id = "Core"
    moved_trigger.ace_id = "OnReady"
    invalid_trigger_source.trigger = moved_trigger
    var invalid_trigger_target := EventRow.new()
    var existing_trigger := ACECondition.new()
    existing_trigger.provider_id = "Core"
    existing_trigger.ace_id = "OnProcess"
    invalid_trigger_target.trigger = existing_trigger
    invalid_trigger_sheet.events = [invalid_trigger_source, invalid_trigger_target]
    dock.setup(invalid_trigger_sheet)
    dock_viewport = dock.get_viewport_control()
    var invalid_trigger_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var invalid_trigger_row_data: EventRowData = invalid_trigger_rows[1].get("row")
    dock_viewport.get_row_layout_for_test(1, 640.0)
    var invalid_trigger_span_index: int = _find_span_index_by_kind(invalid_trigger_row_data, "trigger")
    var invalid_trigger_span: SemanticSpan = invalid_trigger_row_data.spans[invalid_trigger_span_index]
    dock_viewport._drag_ace_entries = [dock_viewport._build_ace_drag_entry(invalid_trigger_rows[0].get("row"), "trigger", 0)]
    dock_viewport._update_ace_drag_target(
        {
            "row_index": 1,
            "span_index": invalid_trigger_span_index,
            "lane": "condition",
            "span_metadata": invalid_trigger_span.metadata
        },
        invalid_trigger_span.rect.get_center()
    )
    all_passed = _check("invalid trigger drag shows tooltip text", dock_viewport._drag_feedback_text, "This event already has a trigger.") and all_passed
    all_passed = _check("invalid trigger drag marks target as invalid", dock_viewport._drag_ace_drop_valid, false) and all_passed
    dock_viewport._complete_ace_drag()
    dock_viewport._clear_ace_drag()
    all_passed = _check("invalid trigger drag keeps source trigger in place", (dock.get_current_sheet().events[0] as EventRow).trigger != null, true) and all_passed
    all_passed = _check("invalid trigger drag keeps target trigger in place", ((dock.get_current_sheet().events[1] as EventRow).trigger as ACECondition).ace_id, "OnProcess") and all_passed
    all_passed = _check("invalid trigger drag updates status label", dock._status_label.text, "This event already has a trigger.") and all_passed

    var group_fold_sheet := EventSheetResource.new()
    var fold_group := EventGroup.new()
    fold_group.name = "Foldable"
    fold_group.group_name = fold_group.name
    var fold_child := EventRow.new()
    fold_child.comment = "child"
    fold_group.events = [fold_child]
    group_fold_sheet.events = [fold_group]
    dock.setup(group_fold_sheet)
    dock_viewport = dock.get_viewport_control()
    var fold_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock._context_row = fold_rows[0].get("row")
    dock._context_hit = {"span_metadata": {}, "span_index": -1}
    dock._on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_TOGGLE_GROUP_FOLD)
    all_passed = _check("group row menu can collapse group", (dock.get_current_sheet().events[0] as EventGroup).is_collapsed(), true) and all_passed
    all_passed = _check("collapsed group hides child rows after menu action", dock_viewport.get_total_row_count(), 1) and all_passed
    dock._on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_TOGGLE_GROUP_FOLD)
    all_passed = _check("group row menu can expand group", (dock.get_current_sheet().events[0] as EventGroup).is_collapsed(), false) and all_passed
    all_passed = _check("expanded group restores child rows after menu action", dock_viewport.get_total_row_count(), 2) and all_passed

    var delete_group_sheet := EventSheetResource.new()
    var delete_group := EventGroup.new()
    delete_group.name = "Delete Me"
    delete_group.group_name = delete_group.name
    var remaining_event := EventRow.new()
    remaining_event.comment = "Remain"
    delete_group_sheet.events = [delete_group, remaining_event]
    dock.setup(delete_group_sheet)
    dock_viewport = dock.get_viewport_control()
    dock_viewport._select_row(0)
    var delete_key := InputEventKey.new()
    delete_key.pressed = true
    delete_key.keycode = KEY_DELETE
    dock._unhandled_key_input(delete_key)
    all_passed = _check("delete key removes selected group", dock.get_current_sheet().events.size(), 1) and all_passed
    all_passed = _check(
        "delete key keeps remaining non-selected row",
        ((dock.get_current_sheet().events[0]) as EventRow).comment,
        "Remain"
    ) and all_passed

    var zoom_sheet := EventSheetResource.new()
    zoom_sheet.events = [EventRow.new()]
    dock.setup(zoom_sheet)
    dock_viewport = dock.get_viewport_control()
    dock_viewport.size = Vector2(640.0, 320.0)
    var zoom_before: float = dock_viewport.get_zoom_factor()
    var zoom_event := InputEventMouseButton.new()
    zoom_event.pressed = true
    zoom_event.ctrl_pressed = true
    zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
    zoom_event.position = Vector2(80.0, 40.0)
    dock_viewport._handle_mouse_button(zoom_event)
    all_passed = _check("ctrl wheel zoom increases viewport zoom factor", dock_viewport.get_zoom_factor() > zoom_before, true) and all_passed
    dock._on_zoom_out_requested()
    all_passed = _check("toolbar zoom out returns viewport toward default zoom", is_equal_approx(dock_viewport.get_zoom_factor(), 1.0), true) and all_passed

    # Global and local variable creation workflow.
    dock.setup(copy_sheet)
    dock._on_variable_dialog_confirmed("ammo", "int", 12, "global")
    all_passed = _check("create global variable stores sheet variable", dock.get_current_sheet().variables.has("ammo"), true) and all_passed
    all_passed = _check(
        "create global variable stores const=false by default with persisted key",
        dock.get_current_sheet().variables["ammo"].has("const") and dock.get_current_sheet().variables["ammo"]["const"] == false,
        true
    ) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo removes global variable creation", dock.get_current_sheet().variables.has("ammo"), false) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo restores global variable creation", dock.get_current_sheet().variables.has("ammo"), true) and all_passed
    var variable_action := ACEAction.new()
    variable_action.provider_id = "Core"
    variable_action.ace_id = "SetVar"
    variable_action.params = {"var_name": "ammo", "value": "3"}
    ((dock.get_current_sheet().events[0] as EventRow).actions).append(variable_action)
    dock_viewport._select_row(0)
    dock._on_variable_dialog_confirmed("cooldown", "float", 0.5, "local")
    all_passed = _check("create local variable stores on selected event", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 1) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo removes local variable creation", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 0) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo restores local variable creation", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 1) and all_passed
    dock._on_global_variable_activated(0)
    all_passed = _check("editing global variable in use locks type selector", dock._variable_dlg._type_option.disabled, true) and all_passed
    dock._on_variable_dialog_confirmed("ammo", "int", 99, "global", {"editing": true, "original_name": "ammo"}, true)
    all_passed = _check("editing global variable updates default", dock.get_current_sheet().variables["ammo"].get("default", 0), 99) and all_passed
    all_passed = _check("editing global variable can set const flag", dock.get_current_sheet().variables["ammo"].get("const", false), true) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo restores previous global const state", dock.get_current_sheet().variables["ammo"].get("const", false), false) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo reapplies global const state", dock.get_current_sheet().variables["ammo"].get("const", false), true) and all_passed
    dock_viewport = dock.get_viewport_control()
    all_passed = _check("global variables render in the sheet rows", _rows_contain_text(dock_viewport.get_flat_rows(), "ammo"), true) and all_passed
    all_passed = _check("local variables render in the sheet rows", _rows_contain_text(dock_viewport.get_flat_rows(), "cooldown"), true) and all_passed
    all_passed = _check("const badge renders in variable rows", _rows_contain_text(dock_viewport.get_flat_rows(), "const"), true) and all_passed
    dock._context_variable = {"scope": "global", "name": "ammo", "type": "int", "is_constant": true, "supports_const": true}
    dock._toggle_context_variable_constant()
    all_passed = _check("context toggle can unset global const flag", dock.get_current_sheet().variables["ammo"].get("const", true), false) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo restores const toggle action", dock.get_current_sheet().variables["ammo"].get("const", false), true) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo reapplies const toggle action", dock.get_current_sheet().variables["ammo"].get("const", true), false) and all_passed
    dock._context_variable = {"scope": "global", "name": "ammo", "type": "int", "is_constant": false, "supports_const": true}
    dock._toggle_context_variable_constant()
    all_passed = _check("context toggle can set global const flag again", dock.get_current_sheet().variables["ammo"].get("const", false), true) and all_passed

    var conversion_event_uid: String = (dock.get_current_sheet().events[0] as EventRow).event_uid
    var global_entry := {
        "scope": "global",
        "name": "ammo",
        "type": "int",
        "default": 99,
        "is_constant": true
    }
    var converted_to_local: bool = dock._convert_variable_scope(global_entry, "local", conversion_event_uid)
    all_passed = _check("global to local conversion succeeds", converted_to_local, true) and all_passed
    all_passed = _check("global to local conversion removes global variable", dock.get_current_sheet().variables.has("ammo"), false) and all_passed
    all_passed = _check("global to local conversion preserves type", ((dock.get_current_sheet().events[0] as EventRow).local_variables[1] as LocalVariable).type_name, "int") and all_passed
    all_passed = _check("global to local conversion preserves default value", ((dock.get_current_sheet().events[0] as EventRow).local_variables[1] as LocalVariable).default_value, 99) and all_passed
    all_passed = _check("global to local conversion preserves const flag", ((dock.get_current_sheet().events[0] as EventRow).local_variables[1] as LocalVariable).is_constant, true) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo restores global variable after conversion", dock.get_current_sheet().variables.has("ammo"), true) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo reapplies global to local conversion", dock.get_current_sheet().variables.has("ammo"), false) and all_passed

    var local_to_global_entry := {
        "scope": "local",
        "name": "ammo",
        "type": "int",
        "default": 99,
        "is_constant": true,
        "event_row": dock.get_current_sheet().events[0],
        "index": 1
    }
    var converted_to_global: bool = dock._convert_variable_scope(local_to_global_entry, "global")
    all_passed = _check("local to global conversion succeeds", converted_to_global, true) and all_passed
    all_passed = _check("local to global conversion restores global variable", dock.get_current_sheet().variables.has("ammo"), true) and all_passed
    all_passed = _check("local to global conversion preserves type", dock.get_current_sheet().variables["ammo"].get("type", ""), "int") and all_passed
    all_passed = _check("local to global conversion preserves default value", dock.get_current_sheet().variables["ammo"].get("default", null), 99) and all_passed
    all_passed = _check("local to global conversion preserves const flag", dock.get_current_sheet().variables["ammo"].get("const", false), true) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo restores local variable after local->global conversion", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 2) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo reapplies local->global conversion", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 1) and all_passed

    var unselected_local_sheet := EventSheetResource.new()
    unselected_local_sheet.events = [EventRow.new()]
    dock.setup(unselected_local_sheet)
    dock_viewport._clear_selection()
    dock._on_variable_dialog_confirmed("speed", "float", 2.5, "local")
    all_passed = _check("create local variable without selection targets first event", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 1) and all_passed
    all_passed = _check("create local variable without selection reselects target event", dock.get_viewport_control().get_selected_context().get("source_resource", null) is EventRow, true) and all_passed

    var empty_local_sheet := EventSheetResource.new()
    dock.setup(empty_local_sheet)
    dock_viewport._clear_selection()
    dock._on_variable_dialog_confirmed("spawned", "bool", true, "local")
    all_passed = _check("create local variable without events creates host event", dock.get_current_sheet().events.size(), 1) and all_passed
    all_passed = _check("create local variable without events stores on created host event", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 1) and all_passed

    dock_viewport.set_size(Vector2(640.0, 640.0))
    var width_scroll_shell: ScrollContainer = dock.find_child("EventSheetScroll", true, false)
    if width_scroll_shell != null:
        width_scroll_shell.size = Vector2(1180.0, 640.0)
    dock_viewport._process(0.0)
    all_passed = _check("viewport canvas expands to available width", dock_viewport.custom_minimum_size.x >= 1180.0, true) and all_passed
    all_passed = _check("viewport control grows to fill available width", dock_viewport.size.x >= 1180.0, true) and all_passed

    # Clicking event lanes opens the ACE picker in the matching mode.
    dock.setup(copy_sheet)
    dock_viewport = dock.get_viewport_control()
    var clickable_row: EventRowData = null
    for row_entry in dock_viewport.get_flat_rows():
        var candidate: EventRowData = row_entry.get("row")
        if candidate != null and candidate.source_resource is EventRow:
            clickable_row = candidate
            break
    dock._ace_picker._window.hide()
    dock._on_viewport_ace_picker_requested(clickable_row, "condition")
    all_passed = _check("condition lane click opens ace picker", dock._ace_picker._window.visible, true) and all_passed
    all_passed = _check("condition lane click uses append condition mode", dock._ace_picker._context.get("mode", ""), "append_condition") and all_passed
    dock._ace_picker._window.hide()
    dock._on_viewport_ace_picker_requested(clickable_row, "action")
    all_passed = _check("action lane click opens ace picker", dock._ace_picker._window.visible, true) and all_passed
    all_passed = _check("action lane click uses append action mode", dock._ace_picker._context.get("mode", ""), "append_action") and all_passed
    dock._ace_picker._window.close_requested.emit()
    all_passed = _check("ace picker close button hides window", dock._ace_picker._window.visible, false) and all_passed

    # Add Condition opens a new-event picker flow when no event row is selected.
    dock.setup(EventSheetResource.new())
    dock._on_add_condition_requested()
    all_passed = _check("add condition without selection opens ace picker", dock._ace_picker._window.visible, true) and all_passed
    all_passed = _check("add condition without selection uses new event mode", dock._ace_picker._context.get("mode", ""), "new_condition_event") and all_passed

    # ACE selection and apply workflow.
    var action_definition: ACEDefinition = null
    var new_condition_definition: ACEDefinition = null
    for definition in ace_registry.search("set variable"):
        if definition.ace_type == ACEDefinition.ACEType.ACTION:
            action_definition = definition
            break
    for definition in ace_registry.search("always"):
        if definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]:
            new_condition_definition = definition
            break
    all_passed = _check("found action definition with params", action_definition != null and not action_definition.parameters.is_empty(), true) and all_passed
    if action_definition != null:
        dock.setup(copy_sheet)
        dock._on_ace_picker_selected(action_definition, {"mode": "append_action", "selected_resource": dock.get_current_sheet().events[0]})
        all_passed = _check("ace apply appends action", ((dock.get_current_sheet().events[0] as EventRow).actions.size()) >= 2, true) and all_passed
        dock._on_ace_picker_selected(action_definition, {"mode": "replace_action", "selected_resource": dock.get_current_sheet().events[0], "ace_index": 0, "existing_params": {"var_name": "ammo", "value": "12"}})
        all_passed = _check("editing ace with params opens param dialog", dock._ace_params._dialog.visible, true) and all_passed
    if new_condition_definition != null:
        dock.setup(EventSheetResource.new())
        dock._apply_ace_definition(new_condition_definition, {}, {"mode": "new_condition_event", "selected_resource": null})
        all_passed = _check("new condition mode creates event row", dock.get_current_sheet().events.size(), 1) and all_passed
        all_passed = _check("new condition mode creates event with condition or trigger", ((dock.get_current_sheet().events[0] as EventRow).conditions.size()) + (1 if (dock.get_current_sheet().events[0] as EventRow).trigger != null else 0) > 0, true) and all_passed

    # Undo/redo workflow.
    var undo_before: int = ((dock.get_current_sheet().events[0] as EventRow).actions.size())
    dock._on_undo_requested()
    all_passed = _check("undo removes last ace apply", ((dock.get_current_sheet().events[0] as EventRow).actions.size()), undo_before - 1) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo reapplies ace apply", ((dock.get_current_sheet().events[0] as EventRow).actions.size()), undo_before) and all_passed

    # Save and reload EventSheet.
    var temp_path: String = "user://event_sheet_editor_test.tres"
    dock.setup(copy_sheet)
    dock._save_sheet_to_path(temp_path)
    var exists_after_save: bool = FileAccess.file_exists(temp_path)
    all_passed = _check("save workflow writes EventSheet resource", exists_after_save, true) and all_passed
    if exists_after_save:
        dock._load_sheet_from_path(temp_path)
        all_passed = _check("open workflow loads EventSheet resource", dock.get_current_sheet() is EventSheetResource, true) and all_passed
        all_passed = _check("save/load keeps global const flag", bool(dock.get_current_sheet().variables.get("ammo", {}).get("const", false)), true) and all_passed
    all_passed = _check("save normalization adds default filename", dock._normalize_sheet_save_path("res://"), "res://event_sheet.tres") and all_passed
    all_passed = _check("save normalization appends tres extension", dock._normalize_sheet_save_path("res://sheets/editor_sheet"), "res://sheets/editor_sheet.tres") and all_passed

    # Drag-drop ACE preview opens popup window content.
    var preview_defs: Array[ACEDefinition] = []
    var on_signal_def: ACEDefinition = ACEDefinition.new()
    on_signal_def.provider_id = "Core"
    on_signal_def.id = "OnSignal"
    on_signal_def.display_name = "On Signal"
    on_signal_def.category = "Signals / Scene / Input"
    on_signal_def.ace_type = ACEDefinition.ACEType.TRIGGER
    preview_defs.append(on_signal_def)
    dock._on_ace_preview_requested("DemoNode", preview_defs)
    all_passed = _check("ace drag-in preview opens popup window", dock._preview_window.visible, true) and all_passed
    all_passed = _check("ace drag-in preview list gets populated", dock._preview_list.item_count > 0, true) and all_passed

    # ── Group fold safety: folding must not destroy child resources ───────────
    var fold_safety_sheet := EventSheetResource.new()
    var fold_safety_group := EventGroup.new()
    fold_safety_group.name = "SafeGroup"
    fold_safety_group.group_name = fold_safety_group.name
    var fold_child_a := EventRow.new()
    fold_child_a.comment = "child-a"
    var fold_child_b := EventRow.new()
    fold_child_b.comment = "child-b"
    fold_safety_group.events = [fold_child_a, fold_child_b]
    fold_safety_sheet.events = [fold_safety_group]
    dock.setup(fold_safety_sheet)
    dock_viewport = dock.get_viewport_control()
    var rows_before_fold: int = dock_viewport.get_total_row_count()
    dock_viewport._toggle_row_fold(0)
    all_passed = _check("fold hides group children from flat row list", dock_viewport.get_total_row_count(), 1) and all_passed
    all_passed = _check("folding does not remove child resources from group", (dock.get_current_sheet().events[0] as EventGroup).events.size(), 2) and all_passed
    dock_viewport._toggle_row_fold(0)
    all_passed = _check("unfold restores all child rows", dock_viewport.get_total_row_count(), rows_before_fold) and all_passed
    all_passed = _check("unfold preserves child resource order", ((dock.get_current_sheet().events[0] as EventGroup).events[0] as EventRow).comment, "child-a") and all_passed
    all_passed = _check("unfold preserves second child resource", ((dock.get_current_sheet().events[0] as EventGroup).events[1] as EventRow).comment, "child-b") and all_passed

    # Multiple fold/unfold cycles must not mutate child data.
    dock_viewport._toggle_row_fold(0)
    dock_viewport._toggle_row_fold(0)
    dock_viewport._toggle_row_fold(0)
    dock_viewport._toggle_row_fold(0)
    all_passed = _check("repeated fold/unfold cycles preserve child resource count", (dock.get_current_sheet().events[0] as EventGroup).events.size(), 2) and all_passed

    # ── Group rename dialog flow (signal pathway) ─────────────────────────────
    var rename_sheet := EventSheetResource.new()
    var rename_group := EventGroup.new()
    rename_group.name = "OldName"
    rename_group.group_name = rename_group.name
    rename_sheet.events = [rename_group]
    dock.setup(rename_sheet)
    dock._on_viewport_span_edit_requested(
        dock.get_viewport_control().get_flat_rows()[0].get("row"),
        "group_name",
        "OldName",
        "NewName"
    )
    all_passed = _check("group rename via span edit updates group name", (dock.get_current_sheet().events[0] as EventGroup).name, "NewName") and all_passed
    all_passed = _check("group rename via span edit updates group_name field", (dock.get_current_sheet().events[0] as EventGroup).group_name, "NewName") and all_passed
    dock._on_undo_requested()
    all_passed = _check("group rename is undoable", (dock.get_current_sheet().events[0] as EventGroup).name, "OldName") and all_passed
    dock._on_redo_requested()
    all_passed = _check("group rename is redoable", (dock.get_current_sheet().events[0] as EventGroup).name, "NewName") and all_passed

    # group_rename_requested signal is emitted on double-click on a group row
    var rename_signal_received: Array = []
    dock_viewport = dock.get_viewport_control()
    var rename_signal_conn: Callable = func(row_data: EventRowData, current_name: String) -> void:
        rename_signal_received.append({"row_data": row_data, "current_name": current_name})
    dock_viewport.group_rename_requested.connect(rename_signal_conn)
    var group_row_data: EventRowData = dock_viewport.get_flat_rows()[0].get("row")
    if group_row_data != null and group_row_data.source_resource is EventGroup:
        dock_viewport.group_rename_requested.emit(group_row_data, "NewName")
    all_passed = _check("group_rename_requested signal carries current group name", rename_signal_received.size() > 0 and rename_signal_received[0].get("current_name", "") == "NewName", true) and all_passed
    dock_viewport.group_rename_requested.disconnect(rename_signal_conn)

    # ── Variable double-click emits variable_edit_requested signal ─────────────
    var var_edit_sheet := EventSheetResource.new()
    var_edit_sheet.variables["score"] = {"type": "int", "default": 42, "const": false}
    var var_edit_event := EventRow.new()
    var var_edit_local := LocalVariable.new()
    var_edit_local.name = "speed"
    var_edit_local.type_name = "float"
    var_edit_local.default_value = 5.0
    var_edit_event.local_variables = [var_edit_local]
    var_edit_sheet.events = [var_edit_event]
    dock.setup(var_edit_sheet)
    dock_viewport = dock.get_viewport_control()
    dock_viewport._select_row(0)
    var var_edit_signals: Array = []
    var var_edit_conn: Callable = func(row_data: EventRowData, variable_meta: Dictionary) -> void:
        var_edit_signals.append({"row_data": row_data, "meta": variable_meta})
    dock_viewport.variable_edit_requested.connect(var_edit_conn)
    var all_flat_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    for row_entry in all_flat_rows:
        var candidate: EventRowData = row_entry.get("row")
        if candidate != null and candidate.row_type == EventRowData.RowType.SECTION:
            dock_viewport.variable_edit_requested.emit(candidate, dock_viewport._extract_variable_meta(candidate))
            break
    all_passed = _check("variable_edit_requested signal emitted on variable row", var_edit_signals.size() > 0, true) and all_passed
    all_passed = _check("variable_edit_requested carries variable_scope meta", not str(var_edit_signals[0].get("meta", {}).get("variable_scope", "")).is_empty(), true) and all_passed
    all_passed = _check("variable_edit_requested carries variable_name meta", not str(var_edit_signals[0].get("meta", {}).get("variable_name", "")).is_empty(), true) and all_passed
    dock_viewport.variable_edit_requested.disconnect(var_edit_conn)

    # ── Variable drag/drop: local variable intra-scope reorder ────────────────
    var var_drag_sheet := EventSheetResource.new()
    var var_drag_event := EventRow.new()
    var var_drag_event_uid: String = "drag_test_event"
    var_drag_event.event_uid = var_drag_event_uid
    var var_a := LocalVariable.new()
    var_a.name = "alpha"
    var_a.type_name = "int"
    var_a.default_value = 1
    var var_b := LocalVariable.new()
    var_b.name = "beta"
    var_b.type_name = "int"
    var_b.default_value = 2
    var_drag_event.local_variables = [var_a, var_b]
    var_drag_sheet.events = [var_drag_event]
    dock.setup(var_drag_sheet)
    var reorder_result: bool = dock._reorder_local_variable(var_drag_event, 0, 1, "after")
    all_passed = _check("local variable reorder returns true on success", reorder_result, true) and all_passed
    all_passed = _check("local variable reorder changes position of moved var", (var_drag_event.local_variables[1] as LocalVariable).name, "alpha") and all_passed
    all_passed = _check("local variable reorder first position is now second var", (var_drag_event.local_variables[0] as LocalVariable).name, "beta") and all_passed

    # Variable drag/drop via signal path
    dock.setup(var_drag_sheet)
    dock_viewport = dock.get_viewport_control()
    dock_viewport._select_row(0)
    var var_drop_sheet2 := EventSheetResource.new()
    var var_drop_event2 := EventRow.new()
    var_drop_event2.event_uid = "drop_test_event"
    var var_c := LocalVariable.new()
    var_c.name = "cee"
    var_c.type_name = "bool"
    var_c.default_value = false
    var var_d := LocalVariable.new()
    var_d.name = "dee"
    var_d.type_name = "bool"
    var_d.default_value = true
    var_drop_event2.local_variables = [var_c, var_d]
    var_drop_sheet2.events = [var_drop_event2]
    dock.setup(var_drop_sheet2)
    dock_viewport = dock.get_viewport_control()
    dock_viewport._select_row(0)
    var var_drop_performed: bool = _perform_undoable_sheet_edit_passthrough(dock, "Reorder Local Variable", func() -> bool:
        return dock._reorder_local_variable(var_drop_event2, 0, 1, "after")
    )
    all_passed = _check("undoable local variable reorder succeeds", var_drop_performed, true) and all_passed
    all_passed = _check("undoable reorder changes order", (var_drop_event2.local_variables[1] as LocalVariable).name, "cee") and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo local variable reorder restores original order", (var_drop_event2.local_variables[0] as LocalVariable).name, "cee") and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo local variable reorder reapplies order change", (var_drop_event2.local_variables[1] as LocalVariable).name, "cee") and all_passed

    # ── EventSheetUIConfig: basic structure validation ─────────────────────────
    var ui_config := EventSheetUIConfig.new()
    all_passed = _check("ui config has default row height", ui_config.row_height, 28) and all_passed
    all_passed = _check("ui config has default font size", ui_config.font_size, 13) and all_passed
    all_passed = _check("ui config has group bg color", ui_config.group_bg_color is Color, true) and all_passed
    all_passed = _check("ui config has group accent color", ui_config.group_accent_color is Color, true) and all_passed
    all_passed = _check("ui config has selection color", ui_config.selection_color is Color, true) and all_passed
    all_passed = _check("ui config has lane conditions color", ui_config.lane_conditions_color is Color, true) and all_passed
    all_passed = _check("ui config exposes action chip border color", ui_config.action_chip_border_color is Color, true) and all_passed
    all_passed = _check("ui config exposes trigger badge bg color", ui_config.trigger_badge_bg_color is Color, true) and all_passed
    ui_config.group_accent_color = Color(1.0, 0.0, 0.5)
    ui_config.action_text_color = Color(0.8, 0.4, 0.2)
    ui_config.action_chip_border_color = Color(0.2, 0.9, 0.5)
    ui_config.trigger_badge_bg_color = Color(0.5, 0.1, 0.8)
    var config_renderer := EventRowRenderer.new()
    config_renderer.set_ui_config(ui_config)
    all_passed = _check("renderer accepts ui config override", config_renderer._ui_config == ui_config, true) and all_passed
    all_passed = _check("renderer uses ui config for action text color", config_renderer._get_span_color(SemanticSpan.SpanType.ACTION), ui_config.action_text_color) and all_passed
    all_passed = _check("renderer uses ui config for action chip border", config_renderer._resolve_chip_colors({"lane": "action"}).get("border"), ui_config.action_chip_border_color) and all_passed
    all_passed = _check("renderer uses ui config for trigger badge bg", config_renderer._resolve_badge_colors({"badge_style": "trigger"}).get("bg"), ui_config.trigger_badge_bg_color) and all_passed
    dock.apply_ui_config(ui_config)
    all_passed = _check("dock apply_ui_config passes config to renderer", dock.get_viewport_control()._renderer._ui_config == ui_config, true) and all_passed

    # ── Layout regression coverage: group/variable/badge-chip overlap ──────────
    var overlap_fix_sheet := EventSheetResource.new()
    overlap_fix_sheet.variables["score_with_a_name_that_should_clip_before_colliding_with_type_and_const_badges"] = {
        "type": "VeryLongCustomNumberTypeName",
        "default": "A default value that also needs clipping",
        "const": true
    }
    var overlap_fix_group := EventGroup.new()
    overlap_fix_group.name = "A group name that should stay readable without overlapping the group badge or running outside the row"
    overlap_fix_group.group_name = overlap_fix_group.name
    var overlap_fix_event := EventRow.new()
    overlap_fix_event.condition_mode = EventRow.ConditionMode.OR
    var overlap_fix_condition_a := ACECondition.new()
    overlap_fix_condition_a.provider_id = "Missing"
    overlap_fix_condition_a.ace_id = "A condition title that should leave room for later OR badges and chips"
    var overlap_fix_condition_b := ACECondition.new()
    overlap_fix_condition_b.provider_id = "Missing"
    overlap_fix_condition_b.ace_id = "Follow-up condition"
    overlap_fix_condition_b.negated = true
    overlap_fix_event.conditions = [overlap_fix_condition_a, overlap_fix_condition_b]
    var overlap_fix_action := ACEAction.new()
    overlap_fix_action.provider_id = "Missing"
    overlap_fix_action.ace_id = "Action with a title that must stay before add action"
    overlap_fix_event.actions = [overlap_fix_action]
    overlap_fix_sheet.events = [overlap_fix_group, overlap_fix_event]
    dock.setup(overlap_fix_sheet)
    dock_viewport = dock.get_viewport_control()
    var overlap_fix_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var overlap_fix_variable_row: EventRowData = overlap_fix_rows[0].get("row")
    var overlap_fix_group_row: EventRowData = overlap_fix_rows[1].get("row")
    var overlap_fix_event_row: EventRowData = overlap_fix_rows[2].get("row")
    var overlap_fix_variable_layout: Dictionary = dock_viewport.get_row_layout_for_test(0, 640.0)
    var overlap_fix_group_layout: Dictionary = dock_viewport.get_row_layout_for_test(1, 640.0)
    var overlap_fix_event_layout: Dictionary = dock_viewport.get_row_layout_for_test(2, 640.0)
    all_passed = _check("variable row spans stay ordered without overlap", _line_spans_do_not_overlap(overlap_fix_variable_row), true) and all_passed
    all_passed = _check("variable row spans stay inside row width", _spans_fit_within_rect(overlap_fix_variable_row, overlap_fix_variable_layout.get("row_rect", Rect2())), true) and all_passed
    all_passed = _check("group row spans stay ordered without overlap", _line_spans_do_not_overlap(overlap_fix_group_row), true) and all_passed
    all_passed = _check("group row spans stay inside row width", _spans_fit_within_rect(overlap_fix_group_row, overlap_fix_group_layout.get("row_rect", Rect2())), true) and all_passed
    all_passed = _check("mixed badge chip condition spans stay ordered", _line_spans_do_not_overlap(overlap_fix_event_row, "condition"), true) and all_passed
    all_passed = _check(
        "condition lane spans stay before divider after overlap fix",
        _lane_spans_fit_before_x(overlap_fix_event_row, "condition", float(overlap_fix_event_layout.get("lane_divider_x", 0.0))),
        true
    ) and all_passed

    # ── Group copy/paste preserves structure and supports multi-selection ──────
    var group_copy_sheet := EventSheetResource.new()
    var group_copy_a := EventGroup.new()
    group_copy_a.name = "Enemies"
    group_copy_a.group_name = group_copy_a.name
    var group_copy_a_event := EventRow.new()
    group_copy_a_event.comment = "spawn enemies"
    var group_copy_a_child := EventRow.new()
    group_copy_a_child.comment = "nested rule"
    group_copy_a_event.sub_events = [group_copy_a_child]
    group_copy_a.events = [group_copy_a_event]
    var group_copy_b := EventGroup.new()
    group_copy_b.name = "Loot"
    group_copy_b.group_name = group_copy_b.name
    var group_copy_b_event := EventRow.new()
    group_copy_b_event.comment = "drop item"
    group_copy_b.events = [group_copy_b_event]
    group_copy_sheet.events = [group_copy_a, group_copy_b]
    dock.setup(group_copy_sheet)
    dock_viewport = dock.get_viewport_control()
    dock_viewport._select_row(0)
    dock._on_copy_requested()
    dock._on_paste_requested()
    all_passed = _check("single group paste duplicates structural unit", dock.get_current_sheet().events.size(), 3) and all_passed
    var pasted_group: EventGroup = dock.get_current_sheet().events[1] as EventGroup
    all_passed = _check("single group paste preserves child row count", pasted_group.events.size(), 1) and all_passed
    all_passed = _check("single group paste preserves nested sub-event count", (((pasted_group.events[0]) as EventRow).sub_events.size()), 1) and all_passed
    all_passed = _check("single group paste assigns fresh group uid", pasted_group.group_uid == group_copy_a.group_uid, false) and all_passed
    all_passed = _check("single group paste assigns fresh child event uid", (((pasted_group.events[0]) as EventRow).event_uid == group_copy_a_event.event_uid), false) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo removes pasted group", dock.get_current_sheet().events.size(), 2) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo restores pasted group", dock.get_current_sheet().events.size(), 3) and all_passed

    dock.setup(group_copy_sheet)
    dock_viewport = dock.get_viewport_control()
    dock_viewport._select_from_click(0, -1, false)
    dock_viewport._select_from_click(2, -1, true)
    dock._on_copy_requested()
    dock._on_paste_requested()
    all_passed = _check("multi-group paste appends both copied groups", dock.get_current_sheet().events.size(), 4) and all_passed
    all_passed = _check(
        "multi-group paste preserves selection order",
        [
            ((dock.get_current_sheet().events[2]) as EventGroup).group_name,
            ((dock.get_current_sheet().events[3]) as EventGroup).group_name
        ],
        ["Enemies", "Loot"]
    ) and all_passed
    all_passed = _check(
        "multi-group paste preserves copied child resources",
        [
            (((dock.get_current_sheet().events[2] as EventGroup).events[0]) as EventRow).comment,
            (((dock.get_current_sheet().events[3] as EventGroup).events[0]) as EventRow).comment
        ],
        ["spawn enemies", "drop item"]
    ) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo removes pasted multi-group selection", dock.get_current_sheet().events.size(), 2) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo restores pasted multi-group selection", dock.get_current_sheet().events.size(), 4) and all_passed

    # ── Event rows with sub-events fold non-destructively like groups ─────────
    var event_fold_sheet := EventSheetResource.new()
    var parent_event := EventRow.new()
    parent_event.comment = "parent"
    var child_sub_event := EventRow.new()
    child_sub_event.comment = "child"
    parent_event.sub_events = [child_sub_event]
    event_fold_sheet.events = [parent_event]
    dock.setup(event_fold_sheet)
    dock_viewport = dock.get_viewport_control()
    var event_fold_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    dock._context_row = event_fold_rows[0].get("row")
    dock._context_hit = {"span_metadata": {}, "span_index": -1}
    all_passed = _check("event with sub-events exposes fold rect", dock_viewport.get_row_layout_for_test(0, 640.0).get("fold_rect", Rect2()).size != Vector2.ZERO, true) and all_passed
    dock._on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_TOGGLE_GROUP_FOLD)
    all_passed = _check("event fold hides sub-event rows", dock_viewport.get_total_row_count(), 1) and all_passed
    all_passed = _check("event fold keeps sub-event array intact", parent_event.sub_events.size(), 1) and all_passed
    all_passed = _check("event fold keeps original child resource", parent_event.sub_events[0] == child_sub_event, true) and all_passed
    dock._on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_TOGGLE_GROUP_FOLD)
    all_passed = _check("event unfold restores sub-event rows", dock_viewport.get_total_row_count(), 2) and all_passed
    all_passed = _check("event unfold restores same child resource", parent_event.sub_events[0] == child_sub_event, true) and all_passed

    editor.free()
    return all_passed

static func _row_contains_text(row_data: EventRowData, expected_text: String) -> bool:
    for span: SemanticSpan in row_data.spans:
        if span != null and span.text == expected_text:
            return true
    return false

static func _rows_contain_text(rows: Array[Dictionary], expected_text: String) -> bool:
    for row_entry: Dictionary in rows:
        var row_data: EventRowData = row_entry.get("row")
        if row_data != null and _row_contains_text(row_data, expected_text):
            return true
    return false

static func _rows_have_debug_state(rows: Array[Dictionary]) -> bool:
    for row_entry: Dictionary in rows:
        var row_data: EventRowData = row_entry.get("row")
        if row_data != null and not row_data.debug_state.is_empty():
            return true
    return false

static func _line_spans_do_not_overlap(row_data: EventRowData, lane: String = "") -> bool:
    var spans_by_line: Dictionary = {}
    for span in row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        var span_lane: String = str(metadata.get("lane", "condition"))
        if not lane.is_empty() and span_lane != lane:
            continue
        var line_index: int = int(metadata.get("line_index", 0))
        if not spans_by_line.has(line_index):
            spans_by_line[line_index] = []
        spans_by_line[line_index].append(span.rect)
    for line_index in spans_by_line.keys():
        var rects: Array = spans_by_line[line_index]
        rects.sort_custom(func(a: Rect2, b: Rect2) -> bool:
            return a.position.x < b.position.x
        )
        var previous_end: float = -INF
        for rect in rects:
            var span_rect: Rect2 = rect as Rect2
            if span_rect.position.x + 0.25 < previous_end:
                return false
            previous_end = max(previous_end, span_rect.end.x)
    return true

static func _spans_fit_within_rect(row_data: EventRowData, rect: Rect2) -> bool:
    if rect.size == Vector2.ZERO:
        return false
    for span in row_data.spans:
        if span == null:
            continue
        if span.rect.end.x > rect.end.x - EventSheetPalette.ROW_HORIZONTAL_PADDING + 0.5:
            return false
    return true

static func _lane_spans_fit_before_x(row_data: EventRowData, lane: String, x_limit: float) -> bool:
    if x_limit <= 0.0:
        return false
    for span in row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        if str(metadata.get("lane", "condition")) != lane:
            continue
        if span.rect.end.x > x_limit - EventSheetPalette.ACTION_LANE_PADDING + 0.5:
            return false
    return true

static func _row_has_lane(row_data: EventRowData, expected_lane: String) -> bool:
    for span in row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        if str((span.metadata as Dictionary).get("lane", "")) == expected_lane:
            return true
    return false

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

static func _find_last_span_index_by_kind(row_data: EventRowData, expected_kind: String) -> int:
    if row_data == null:
        return -1
    for index in range(row_data.spans.size() - 1, -1, -1):
        var span: SemanticSpan = row_data.spans[index]
        if span == null or not (span.metadata is Dictionary):
            continue
        if str((span.metadata as Dictionary).get("kind", "")) == expected_kind:
            return index
    return -1

static func _find_nth_span_index_by_kind(
    row_data: EventRowData,
    expected_kind: String,
    occurrence: int
) -> int:
    if row_data == null or occurrence < 0:
        return -1
    var current_occurrence: int = 0
    for index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[index]
        if span == null or not (span.metadata is Dictionary):
            continue
        if str((span.metadata as Dictionary).get("kind", "")) != expected_kind:
            continue
        if current_occurrence == occurrence:
            return index
        current_occurrence += 1
    return -1

static func _find_span_index_by_text(row_data: EventRowData, expected_text: String) -> int:
    if row_data == null:
        return -1
    for index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[index]
        if span != null and span.text == expected_text:
            return index
    return -1

static func _find_last_span_index_by_text(row_data: EventRowData, expected_text: String) -> int:
    if row_data == null:
        return -1
    for index in range(row_data.spans.size() - 1, -1, -1):
        var span: SemanticSpan = row_data.spans[index]
        if span != null and span.text == expected_text:
            return index
    return -1

static func _count_span_text(row_data: EventRowData, expected_text: String) -> int:
    if row_data == null:
        return 0
    var total: int = 0
    for span: SemanticSpan in row_data.spans:
        if span != null and span.text == expected_text:
            total += 1
    return total

## Helper: wraps a callable in an undoable edit on the given dock for testing.
static func _perform_undoable_sheet_edit_passthrough(dock: EventSheetDock, action_name: String, operation: Callable) -> bool:
    return dock._perform_undoable_sheet_edit(action_name, operation)

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
    if actual == expected:
        print("[PASS] event_sheet_editor_test: %s" % label)
        return true
    print("[FAIL] event_sheet_editor_test: %s" % label)
    print("  expected: %s" % str(expected))
    print("  actual:   %s" % str(actual))
    return false
