# EventForge — restarted event sheet viewport architecture tests
@tool
extends RefCounted
class_name EventSheetEditorTest

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
    all_passed = _check("demo sheet populates rows", dock_viewport.get_total_row_count() > 0, true) and all_passed
    var demo_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var first_demo_row: EventRowData = demo_rows[0].get("row")
    all_passed = _check("demo sheet exposes semantic spans", first_demo_row.spans.size() > 0, true) and all_passed
    all_passed = _check("demo flow exposes reflected ace registry", ace_registry.get_reflected_provider_ids().is_empty(), false) and all_passed
    all_passed = _check("demo rows render auto ace trigger text", _rows_contain_text(demo_rows, "On Died"), true) and all_passed
    all_passed = _check("demo rows render auto ace action text", _rows_contain_text(demo_rows, "Take Damage 10"), true) and all_passed

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
    all_passed = _check("sheet renders flattened rows", dock_viewport.get_total_row_count(), 3) and all_passed
    var flat_rows: Array[Dictionary] = dock_viewport.get_flat_rows()
    var group_row: EventRowData = flat_rows[1].get("row")
    var event_row_data: EventRowData = flat_rows[2].get("row")
    all_passed = _check("group row tagged correctly", group_row.row_type, EventRowData.RowType.GROUP) and all_passed
    all_passed = _check("event row inherits indent", event_row_data.indent, 1) and all_passed
    all_passed = _check("event row action span exists", _row_contains_text(event_row_data, "Queue free"), true) and all_passed
    all_passed = _check("event row includes lane metadata spans", _row_has_lane(event_row_data, "condition") and _row_has_lane(event_row_data, "action"), true) and all_passed
    var layout: Dictionary = dock_viewport.get_row_layout_for_test(2, 640.0)
    all_passed = _check("event row layout contains lane divider scaffold", float(layout.get("lane_divider_x", -1.0)) > 0.0, true) and all_passed

    dock_viewport._toggle_row_fold(1)
    all_passed = _check("folding hides child rows", dock_viewport.get_total_row_count(), 2) and all_passed
    dock_viewport._toggle_row_fold(1)
    all_passed = _check("unfolding restores child rows", dock_viewport.get_total_row_count(), 3) and all_passed

    dock_viewport._select_row(2)
    all_passed = _check("selection tracks row index", dock_viewport.get_selected_row_index(), 2) and all_passed
    var editor_state: Dictionary = dock_viewport.get_editor_state_snapshot()
    all_passed = _check("selection stores anchor for range scaffolding", editor_state.get("selection_anchor_index", -1), 2) and all_passed

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

    var editable_comment: EventRowData = flat_rows[0].get("row")
    dock_viewport._begin_edit(0, 1)
    dock_viewport._editing_buffer = "Changed note"
    dock_viewport._commit_edit()
    all_passed = _check("inline edit updates comment resource", (editable_comment.source_resource as CommentRow).text, "Changed note") and all_passed

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

static func _row_has_lane(row_data: EventRowData, expected_lane: String) -> bool:
    for span in row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        if str((span.metadata as Dictionary).get("lane", "")) == expected_lane:
            return true
    return false

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
    if actual == expected:
        print("[PASS] event_sheet_editor_test: %s" % label)
        return true
    print("[FAIL] event_sheet_editor_test: %s" % label)
    print("  expected: %s" % str(expected))
    print("  actual:   %s" % str(actual))
    return false
