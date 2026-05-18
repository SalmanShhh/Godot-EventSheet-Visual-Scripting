# EventForge — restarted event sheet viewport architecture tests
@tool
extends RefCounted
class_name EventSheetEditorTest

const ACTION_LANE_CLICK_OFFSET := 18.0

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
    var title_strip: Node = dock.find_child("EventSheetTitleStrip", true, false)
    var title_tab_label: Label = dock.find_child("EventSheetTitleTabLabel", true, false) as Label
    var title_path_label: Label = dock.find_child("EventSheetTitlePath", true, false) as Label
    var title_dirty_dot: Label = dock.find_child("EventSheetTitleDirtyDot", true, false) as Label
    all_passed = _check("demo sheet populates rows", dock_viewport.get_total_row_count() > 0, true) and all_passed
    all_passed = _check("workflow toolbar is present", toolbar is HBoxContainer, true) and all_passed
    all_passed = _check("title strip is present", title_strip is HBoxContainer, true) and all_passed
    all_passed = _check("title tab label is present", title_tab_label is Label, true) and all_passed
    all_passed = _check("title path label is present", title_path_label is Label, true) and all_passed
    all_passed = _check("title dirty indicator is present", title_dirty_dot is Label, true) and all_passed
    all_passed = _check("demo sheet title label defaults to untitled", title_tab_label.text, "Untitled EventSheet") and all_passed
    all_passed = _check("demo sheet path hint defaults to unsaved", title_path_label.text, "Unsaved (in-memory)") and all_passed
    var demo_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var first_demo_row: EventRowData = demo_rows[0].get("row")
    all_passed = _check("demo sheet exposes semantic spans", first_demo_row.spans.size() > 0, true) and all_passed
    all_passed = _check("demo flow exposes reflected ace registry", ace_registry.get_reflected_provider_ids().is_empty(), false) and all_passed
    all_passed = _check("demo rows render auto ace trigger text", _rows_contain_text(demo_rows, "On Died"), true) and all_passed
    all_passed = _check("demo rows render trigger arrow badge", _rows_contain_text(demo_rows, "➜"), true) and all_passed
    all_passed = _check("demo rows render auto ace action text", _rows_contain_text(demo_rows, "Take Damage 10"), true) and all_passed
    all_passed = _check("demo rows do not expose debug overlay badges by default", _rows_have_debug_state(demo_rows), false) and all_passed
    all_passed = _check("title formatter returns no-sheet fallback", EventSheetDock._format_sheet_title(null, ""), "No Sheet Loaded") and all_passed
    all_passed = _check("path formatter returns no-sheet fallback", EventSheetDock._format_sheet_path_hint(null, ""), "Open or create a sheet to begin") and all_passed

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
    sheet.take_over_path("res://demo/sheets/test_title_sheet.tres")
    dock.setup(sheet)
    title_tab_label = dock.find_child("EventSheetTitleTabLabel", true, false) as Label
    title_path_label = dock.find_child("EventSheetTitlePath", true, false) as Label
    title_dirty_dot = dock.find_child("EventSheetTitleDirtyDot", true, false) as Label
    all_passed = _check("switching sheets updates title tab text", title_tab_label.text, "test_title_sheet") and all_passed
    all_passed = _check("switching sheets updates title path hint", title_path_label.text, "res://demo/sheets/test_title_sheet.tres") and all_passed
    dock._mark_dirty("Changed title state")
    all_passed = _check("dirty edit shows title dirty indicator", title_dirty_dot.visible, true) and all_passed
    dock._save_sheet_to_path("user://event_sheet_editor_title_roundtrip.tres")
    all_passed = _check("saving sheet hides dirty indicator", title_dirty_dot.visible, false) and all_passed
    all_passed = _check("saving sheet updates title tab text", title_tab_label.text, "event_sheet_editor_title_roundtrip") and all_passed
    all_passed = _check("saving sheet updates title path hint", title_path_label.text, "user://event_sheet_editor_title_roundtrip.tres") and all_passed
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
        "conditions start after the dedicated condition badge column",
        condition_span_index >= 0
            and is_equal_approx(
                event_row_data.spans[condition_span_index].rect.position.x,
                condition_lane_rect.position.x
                    + float(dock_viewport.get_editor_style().get_event_style().condition_lane_padding)
                    + float(dock_viewport.get_editor_style().get_event_style().condition_badge_column_width)
                    + (EventSheetPalette.SPAN_GAP if dock_viewport.get_editor_style().get_event_style().condition_badge_column_width > 0 else 0.0)
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
    var condition_lines: Array[int] = []
    var or_badge_lines: Array[int] = []
    for span in or_row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        if str(metadata.get("kind", "")) == "condition":
            condition_lines.append(int(metadata.get("line_index", -1)))
        if span.text == "OR":
            or_badge_lines.append(int(metadata.get("line_index", -1)))
    all_passed = _check(
        "or badges share the same stacked line indices as conditions",
        or_badge_lines.size() == condition_lines.size() and or_badge_lines == condition_lines,
        true
    ) and all_passed
    dock_viewport.get_row_layout_for_test(0, 640.0)
    var first_condition_index: int = _find_span_index_by_kind(or_row_data, "condition")
    var second_condition_index: int = _find_nth_span_index_by_kind(or_row_data, "condition", 1)
    all_passed = _check(
        "conditions stack vertically in the event block",
        second_condition_index >= 0
            and or_row_data.spans[second_condition_index].rect.position.y > or_row_data.spans[first_condition_index].rect.position.y,
        true
    ) and all_passed
    var trigger_badge_index: int = _find_span_index_by_text(or_row_data, "➜")
    var first_or_badge_index: int = _find_span_index_by_text(or_row_data, "OR")
    var negated_badge_index: int = _find_span_index_by_text(or_row_data, "✕")
    all_passed = _check(
        "trigger, invert, and OR badges share the primary badge column",
        trigger_badge_index >= 0
            and first_or_badge_index >= 0
            and negated_badge_index >= 0
            and is_equal_approx(or_row_data.spans[trigger_badge_index].rect.position.x, or_row_data.spans[first_or_badge_index].rect.position.x)
            and is_equal_approx(or_row_data.spans[trigger_badge_index].rect.position.x, or_row_data.spans[negated_badge_index].rect.position.x),
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
        "trigger-type condition stays above regular conditions in the event block",
        trigger_condition_row.spans[rendered_trigger_index].rect.position.y < trigger_condition_row.spans[rendered_condition_index].rect.position.y,
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
    var selected_row_layout: Dictionary = dock_viewport.get_row_layout_for_test(2, 640.0)
    var right_click_selected := InputEventMouseButton.new()
    right_click_selected.pressed = true
    right_click_selected.button_index = MOUSE_BUTTON_RIGHT
    right_click_selected.position = selected_row_layout.get("row_rect", Rect2()).get_center()
    dock_viewport._handle_mouse_button(right_click_selected)
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("right-click on selected row preserves multi-selection", editor_state.get("selected_row_count", 0), 2) and all_passed
    dock_viewport._select_from_click(2, _find_span_index_by_kind(event_rows_for_selection[2].get("row"), "condition"), true)
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("ctrl click toggles selected span off", editor_state.get("selected_span_count", 0), 0) and all_passed

    var parity_sheet := EventSheetResource.new()
    var parity_comment := CommentRow.new()
    parity_comment.text = "Rewrite me"
    var parity_group := EventGroup.new()
    parity_group.name = "Rename Me"
    parity_group.group_name = parity_group.name
    var parity_event := EventRow.new()
    var parity_condition_a := ACECondition.new()
    parity_condition_a.provider_id = "Core"
    parity_condition_a.ace_id = "Always"
    var parity_condition_b := ACECondition.new()
    parity_condition_b.provider_id = "Core"
    parity_condition_b.ace_id = "OnReady"
    var parity_action := ACEAction.new()
    parity_action.provider_id = "Core"
    parity_action.ace_id = "QueueFree"
    parity_event.conditions = [parity_condition_a, parity_condition_b]
    parity_event.actions = [parity_action]
    parity_sheet.events = [parity_comment, parity_group, parity_event]
    dock.setup(parity_sheet)
    dock.set_undo_redo_manager(FakeEditorUndoRedoManager.new())
    dock_viewport = dock.get_viewport_control()
    var parity_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var parity_event_row: EventRowData = parity_rows[2].get("row")
    var parity_event_layout: Dictionary = dock_viewport.get_row_layout_for_test(2, 640.0)
    var parity_action_lane_rect: Rect2 = parity_event_layout.get("action_lane_rect", Rect2())
    var parity_group_row_rect: Rect2 = dock_viewport.get_row_layout_for_test(1, 640.0).get("row_rect", Rect2())
    var parity_comment_row_rect: Rect2 = dock_viewport.get_row_layout_for_test(0, 640.0).get("row_rect", Rect2())
    var parity_condition_index: int = _find_last_span_index_by_kind(parity_event_row, "condition")
    var parity_condition_click := InputEventMouseButton.new()
    parity_condition_click.pressed = true
    parity_condition_click.button_index = MOUSE_BUTTON_LEFT
    parity_condition_click.position = parity_event_row.spans[parity_condition_index].rect.get_center()
    var parity_hover_motion := InputEventMouseMotion.new()
    parity_hover_motion.position = parity_condition_click.position
    dock_viewport._handle_mouse_motion(parity_hover_motion)
    dock_viewport._set_hover_state(2, parity_condition_index)
    dock_viewport._handle_mouse_button(parity_condition_click)
    var parity_context: Dictionary = dock_viewport.get_selected_context()
    editor_state = dock_viewport.get_editor_state_snapshot()
    parity_event_layout = dock_viewport.get_row_layout_for_test(2, 640.0)
    all_passed = _check("left-click condition selects individual condition span", parity_context.get("span_metadata", {}).get("kind", ""), "condition") and all_passed
    all_passed = _check("left-click condition keeps span selection count at one", editor_state.get("selected_span_count", 0), 1) and all_passed
    all_passed = _check("hovering a condition tracks only the hovered entry span", parity_event_layout.get("hovered_span_index", -1), parity_condition_index) and all_passed
    var parity_body_click := InputEventMouseButton.new()
    parity_body_click.pressed = true
        parity_body_click.button_index = MOUSE_BUTTON_LEFT
        parity_body_click.position = Vector2(
            parity_action_lane_rect.position.x + ACTION_LANE_CLICK_OFFSET,
            parity_event_row.spans[parity_condition_index].rect.get_center().y
        )
    dock_viewport._handle_mouse_button(parity_body_click)
    parity_context = dock_viewport.get_selected_context()
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("left-click event block body selects whole event block", parity_context.get("source_resource", null) == parity_event and parity_context.get("span", null) == null, true) and all_passed
    all_passed = _check("event block body selection clears span selection", editor_state.get("selected_span_count", 0), 0) and all_passed
    var parity_group_click := InputEventMouseButton.new()
    parity_group_click.pressed = true
    parity_group_click.button_index = MOUSE_BUTTON_LEFT
    parity_group_click.position = parity_group_row_rect.get_center()
    dock_viewport._handle_mouse_button(parity_group_click)
    parity_context = dock_viewport.get_selected_context()
    all_passed = _check("left-click group selects group row", parity_context.get("source_resource", null) is EventGroup, true) and all_passed
    var parity_comment_click := InputEventMouseButton.new()
    parity_comment_click.pressed = true
    parity_comment_click.button_index = MOUSE_BUTTON_LEFT
    parity_comment_click.position = parity_comment_row_rect.get_center()
    dock_viewport._handle_mouse_button(parity_comment_click)
    parity_context = dock_viewport.get_selected_context()
    all_passed = _check("left-click comment selects comment row", parity_context.get("source_resource", null) is CommentRow, true) and all_passed
    var rename_key := InputEventKey.new()
    rename_key.pressed = true
    rename_key.keycode = KEY_ENTER
    dock_viewport._select_row(1)
    dock._unhandled_key_input(rename_key)
    var editing_context: Dictionary = dock_viewport.get_editing_context_for_test()
    all_passed = _check("enter on selected group opens rename behavior", editing_context.get("row_index", -1), 1) and all_passed
    all_passed = _check("group rename starts with current group name", editing_context.get("buffer", ""), "Rename Me") and all_passed
    dock_viewport._cancel_edit()
    dock_viewport._select_row(0)
    dock._unhandled_key_input(rename_key)
    editing_context = dock_viewport.get_editing_context_for_test()
    all_passed = _check("enter on selected comment opens rewrite behavior", editing_context.get("row_index", -1), 0) and all_passed
    dock_viewport._editing_buffer = "Rewritten once"
    dock_viewport._commit_edit()
    dock_viewport._select_row(0)
    dock._unhandled_key_input(rename_key)
    dock_viewport._editing_buffer = "Rewritten twice"
    dock_viewport._commit_edit()
    all_passed = _check("comment rewrite flow can edit an existing comment multiple times", ((dock.get_current_sheet().events[0]) as CommentRow).text, "Rewritten twice") and all_passed

    var grouped_selection_sheet := EventSheetResource.new()
    var grouped_parent := EventRow.new()
    var grouped_child_a := EventRow.new()
    var grouped_child_b := EventRow.new()
    grouped_parent.sub_events = [grouped_child_a, grouped_child_b]
    grouped_selection_sheet.events = [grouped_parent]
    dock.setup(grouped_selection_sheet)
    dock_viewport = dock.get_viewport_control()
    var grouped_parent_layout: Dictionary = dock_viewport.get_row_layout_for_test(0, 640.0)
    var grouped_parent_rect: Rect2 = grouped_parent_layout.get("row_rect", Rect2())
    var grouped_parent_action_lane_rect: Rect2 = grouped_parent_layout.get("action_lane_rect", Rect2())
    var grouped_child_layout: Dictionary = dock_viewport.get_row_layout_for_test(1, 640.0)
    var grouped_child_rect: Rect2 = grouped_child_layout.get("row_rect", Rect2())
    var grouped_child_action_lane_rect: Rect2 = grouped_child_layout.get("action_lane_rect", Rect2())
    var grouped_parent_click := InputEventMouseButton.new()
    grouped_parent_click.pressed = true
    grouped_parent_click.button_index = MOUSE_BUTTON_LEFT
    grouped_parent_click.position = Vector2(grouped_parent_action_lane_rect.position.x + ACTION_LANE_CLICK_OFFSET, grouped_parent_rect.get_center().y)
    dock_viewport._handle_mouse_button(grouped_parent_click)
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("event block selection includes sub-events", editor_state.get("selected_row_count", 0), 3) and all_passed
    var grouped_child_toggle := InputEventMouseButton.new()
    grouped_child_toggle.pressed = true
    grouped_child_toggle.button_index = MOUSE_BUTTON_LEFT
    grouped_child_toggle.ctrl_pressed = true
    grouped_child_toggle.position = Vector2(grouped_child_action_lane_rect.position.x + ACTION_LANE_CLICK_OFFSET, grouped_child_rect.get_center().y)
    dock_viewport._handle_mouse_button(grouped_child_toggle)
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("ctrl click can deselect one grouped child row", editor_state.get("selected_row_count", 0), 2) and all_passed
    all_passed = _check("grouped selection keeps parent event selected after child deselection", dock_viewport.get_selected_context().get("source_resource", null) == grouped_parent, true) and all_passed
    dock_viewport._handle_mouse_button(grouped_child_toggle)
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("ctrl click can reselect a deselected grouped child row", editor_state.get("selected_row_count", 0), 3) and all_passed

    var empty_condition_sheet := EventSheetResource.new()
    empty_condition_sheet.events = [EventRow.new()]
    dock.setup(empty_condition_sheet)
    dock_viewport = dock.get_viewport_control()
    var empty_condition_row: EventRowData = dock_viewport.get_flat_rows()[0].get("row")
    all_passed = _check("empty-condition events render Every Tick wording", empty_condition_row.spans[0].text, "Every Tick") and all_passed

    var sub_condition_sheet := EventSheetResource.new()
    var parent_event := EventRow.new()
    sub_condition_sheet.events = [parent_event]
    dock.setup(sub_condition_sheet)
    dock.set_undo_redo_manager(FakeEditorUndoRedoManager.new())
    dock_viewport = dock.get_viewport_control()
    dock._context_row = dock_viewport.get_flat_rows()[0].get("row")
    dock._context_hit = {"span_metadata": {}, "span_index": -1}
    dock._configure_context_menu(dock._row_context_menu)
    var sub_condition_menu_index: int = dock._row_context_menu.get_item_index(EventSheetDock.ROW_MENU_ADD_SUB_CONDITION)
    all_passed = _check("row context menu exposes add sub-condition entry for events", sub_condition_menu_index >= 0 and not dock._row_context_menu.is_item_disabled(sub_condition_menu_index), true) and all_passed
    dock._on_row_context_menu_id_pressed(EventSheetDock.ROW_MENU_ADD_SUB_CONDITION)
    all_passed = _check("right-click add sub-condition routes through ace picker", dock._ace_picker._context.get("mode", ""), "new_sub_condition_event") and all_passed
    var sub_condition_definition: ACEDefinition = dock._find_definition("Core", "Always")
    dock._apply_ace_definition(sub_condition_definition, {}, dock._ace_picker._context)
    all_passed = _check("add sub-condition appends a child event", parent_event.sub_events.size(), 1) and all_passed
    all_passed = _check("sub-condition child event stores condition entry", (parent_event.sub_events[0] as EventRow).conditions.size(), 1) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo removes added sub-condition child event", parent_event.sub_events.size(), 0) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo restores added sub-condition child event", parent_event.sub_events.size(), 1) and all_passed

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
    var delete_action_first_index: int = _find_span_index_by_kind(delete_row_data, "action")
    var delete_action_second_index: int = _find_last_span_index_by_kind(delete_row_data, "action")
    var delete_layout: Dictionary = dock_viewport.get_row_layout_for_test(0, 640.0)
    all_passed = _check(
        "actions stack vertically in the event block",
        delete_action_first_index >= 0
            and delete_action_second_index >= 0
            and delete_row_data.spans[delete_action_second_index].rect.position.y > delete_row_data.spans[delete_action_first_index].rect.position.y,
        true
    ) and all_passed
    all_passed = _check(
        "event block height expands from stacked condition/action rows",
        float(delete_layout.get("row_height", 0.0)) > float(EventSheetViewport.ROW_HEIGHT),
        true
    ) and all_passed
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

    var inline_edit_row: EventRowData = dock_viewport.get_flat_rows()[0].get("row")
    var inline_edit_span_index: int = dock_viewport._find_first_editable_span(inline_edit_row)
    dock_viewport._begin_edit(0, inline_edit_span_index)
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
    var ace_drag_source_action := ACEAction.new()
    ace_drag_source_action.provider_id = "Core"
    ace_drag_source_action.ace_id = "QueueFree"
    var ace_drag_target_action := ACEAction.new()
    ace_drag_target_action.provider_id = "Core"
    ace_drag_target_action.ace_id = "SetVariable"
    ace_drag_target.conditions = [ace_drag_target_condition]
    ace_drag_source.actions = [ace_drag_source_action]
    ace_drag_target.actions = [ace_drag_target_action]
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
    var target_action_index: int = _find_span_index_by_kind(drag_target_row_data, "action")
    var target_action_span: SemanticSpan = drag_target_row_data.spans[target_action_index]
    dock_viewport._drag_ace_entries = [dock_viewport._build_ace_drag_entry(ace_drag_rows[0].get("row"), "action", 0)]
    dock_viewport._update_ace_drag_target(
        {
            "row_index": 1,
            "span_index": target_action_index,
            "lane": "action",
            "span_metadata": target_action_span.metadata
        },
        target_action_span.rect.get_center() + Vector2(0.0, target_action_span.rect.size.y * 0.35)
    )
    drag_preview_layout = dock_viewport.get_row_layout_for_test(1, 640.0)
    ace_drag_rect = drag_preview_layout.get("ace_drag_rect", Rect2())
    all_passed = _check("action drag target uses vertical insertion after cursor midpoint", dock_viewport._drag_ace_insert_mode, "after") and all_passed
    all_passed = _check("action drag preview renders as a horizontal insertion band", ace_drag_rect.size.y <= 4.0 and ace_drag_rect.size.x > 40.0, true) and all_passed
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

    var empty_space_sheet := EventSheetResource.new()
    empty_space_sheet.events = [EventRow.new()]
    dock.setup(empty_space_sheet)
    dock.set_undo_redo_manager(FakeEditorUndoRedoManager.new())
    dock_viewport = dock.get_viewport_control()
    var row_layout: Dictionary = dock_viewport.get_row_layout_for_test(0, 640.0)
    var row_rect: Rect2 = row_layout.get("row_rect", Rect2())
    var row_double_click := InputEventMouseButton.new()
    row_double_click.pressed = true
    row_double_click.button_index = MOUSE_BUTTON_LEFT
    row_double_click.double_click = true
    row_double_click.position = row_rect.get_center()
    dock_viewport._handle_mouse_button(row_double_click)
    all_passed = _check("double-clicking an existing row does not append events", dock.get_current_sheet().events.size(), 1) and all_passed
    var empty_double_click := InputEventMouseButton.new()
    empty_double_click.pressed = true
    empty_double_click.button_index = MOUSE_BUTTON_LEFT
    empty_double_click.double_click = true
    empty_double_click.position = Vector2(64.0, row_rect.end.y + 120.0)
    dock_viewport._handle_mouse_button(empty_double_click)
    all_passed = _check("double-clicking empty space appends a new event", dock.get_current_sheet().events.size(), 2) and all_passed
    all_passed = _check("empty-space double-click inserts EventRow", dock.get_current_sheet().events[1] is EventRow, true) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo removes empty-space double-click insertion", dock.get_current_sheet().events.size(), 1) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo restores empty-space double-click insertion", dock.get_current_sheet().events.size(), 2) and all_passed
    var empty_menu_click := InputEventMouseButton.new()
    empty_menu_click.pressed = true
    empty_menu_click.button_index = MOUSE_BUTTON_RIGHT
    empty_menu_click.position = Vector2(80.0, row_rect.end.y + 140.0)
    dock_viewport._handle_mouse_button(empty_menu_click)
    all_passed = _check("right-clicking empty space opens empty context menu", dock._empty_space_context_menu.visible, true) and all_passed
    all_passed = _check("empty context menu first item is new event", dock._empty_space_context_menu.get_item_text(0), "New Event") and all_passed
    all_passed = _check("empty context menu second item is new condition", dock._empty_space_context_menu.get_item_text(1), "New Condition") and all_passed
    all_passed = _check("empty context menu third item is add variable", dock._empty_space_context_menu.get_item_text(2), "Add New Variable") and all_passed
    dock._on_empty_space_context_menu_id_pressed(EventSheetDock.EMPTY_MENU_NEW_EVENT)
    all_passed = _check("empty context menu new event action inserts event", dock.get_current_sheet().events.size(), 3) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo reverts empty context menu new event action", dock.get_current_sheet().events.size(), 2) and all_passed
    dock_viewport.clear_selection()
    dock._on_empty_space_context_menu_id_pressed(EventSheetDock.EMPTY_MENU_NEW_CONDITION)
    all_passed = _check("empty context menu new condition routes through ace picker", dock._ace_picker._context.get("mode", ""), "new_condition_event") and all_passed
    dock._ace_picker._window.hide()
    dock._on_empty_space_context_menu_id_pressed(EventSheetDock.EMPTY_MENU_ADD_VARIABLE)
    all_passed = _check("empty context menu add variable opens variable dialog", dock._variable_dlg._dialog.visible, true) and all_passed
    all_passed = _check("empty context menu add variable defaults to global scope", dock._variable_dlg._scope, "global") and all_passed
    dock._variable_dlg._dialog.hide()
    var box_sheet := EventSheetResource.new()
    var box_event_a := EventRow.new()
    box_event_a.conditions = [ACECondition.new()]
    (box_event_a.conditions[0] as ACECondition).provider_id = "Core"
    (box_event_a.conditions[0] as ACECondition).ace_id = "Always"
    box_event_a.actions = [ACEAction.new()]
    (box_event_a.actions[0] as ACEAction).provider_id = "Core"
    (box_event_a.actions[0] as ACEAction).ace_id = "QueueFree"
    var box_event_b := EventRow.new()
    box_event_b.conditions = [ACECondition.new()]
    (box_event_b.conditions[0] as ACECondition).provider_id = "Core"
    (box_event_b.conditions[0] as ACECondition).ace_id = "OnReady"
    box_event_b.actions = [ACEAction.new()]
    (box_event_b.actions[0] as ACEAction).provider_id = "Core"
    (box_event_b.actions[0] as ACEAction).ace_id = "QueueFree"
    box_sheet.events = [box_event_a, box_event_b]
    dock.setup(box_sheet)
    dock_viewport = dock.get_viewport_control()
    var box_row_a_layout: Dictionary = dock_viewport.get_row_layout_for_test(0, 640.0)
    var box_row_b_layout: Dictionary = dock_viewport.get_row_layout_for_test(1, 640.0)
    var box_press := InputEventMouseButton.new()
    box_press.pressed = true
    box_press.button_index = MOUSE_BUTTON_LEFT
    box_press.position = Vector2(16.0, box_row_a_layout.get("row_rect", Rect2()).position.y - 4.0)
    dock_viewport._handle_mouse_button(box_press)
    var box_drag := InputEventMouseMotion.new()
    box_drag.position = box_row_b_layout.get("row_rect", Rect2()).end + Vector2(-10.0, -6.0)
    dock_viewport._handle_mouse_motion(box_drag)
    var box_release := InputEventMouseButton.new()
    box_release.pressed = false
    box_release.button_index = MOUSE_BUTTON_LEFT
    box_release.position = box_drag.position
    dock_viewport._handle_mouse_button(box_release)
    editor_state = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("box-select can multi-select event rows", editor_state.get("selected_row_count", 0) >= 2, true) and all_passed
    all_passed = _check("box-select can include condition/action spans", editor_state.get("selected_span_count", 0) > 0, true) and all_passed

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
    all_passed = _check("viewport control also grows to fill available height for true empty-canvas clicks", dock_viewport.size.y >= 640.0, true) and all_passed

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
    all_passed = _check("ace picker title reflects action append flow", dock._ace_picker._window.title, "Add Action") and all_passed
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
        all_passed = _check("param dialog hint explains re-editing flow", dock._ace_params._hint_label.text.contains("re-edit"), true) and all_passed
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

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
    if actual == expected:
        print("[PASS] event_sheet_editor_test: %s" % label)
        return true
    print("[FAIL] event_sheet_editor_test: %s" % label)
    print("  expected: %s" % str(expected))
    print("  actual:   %s" % str(actual))
    return false
