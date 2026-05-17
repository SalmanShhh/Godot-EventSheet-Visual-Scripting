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
    dock.set_undo_redo_manager(FakeEditorUndoRedoManager.new())
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

    # Global and local variable creation workflow.
    dock.setup(copy_sheet)
    dock._on_variable_dialog_confirmed("ammo", "int", 12, "global")
    all_passed = _check("create global variable stores sheet variable", dock.get_current_sheet().variables.has("ammo"), true) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo removes global variable creation", dock.get_current_sheet().variables.has("ammo"), false) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo restores global variable creation", dock.get_current_sheet().variables.has("ammo"), true) and all_passed
    dock_viewport._select_row(0)
    dock._on_variable_dialog_confirmed("cooldown", "float", 0.5, "local")
    all_passed = _check("create local variable stores on selected event", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 1) and all_passed
    dock._on_undo_requested()
    all_passed = _check("undo removes local variable creation", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 0) and all_passed
    dock._on_redo_requested()
    all_passed = _check("redo restores local variable creation", ((dock.get_current_sheet().events[0] as EventRow).local_variables.size()), 1) and all_passed

    # Clicking event lanes opens the ACE picker in the matching mode.
    dock.setup(copy_sheet)
    var clickable_row: EventRowData = dock_viewport.get_flat_rows()[0].get("row")
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
    var condition_definition: ACEDefinition = null
    for definition in ace_registry.search("set variable"):
        if definition.ace_type == ACEDefinition.ACEType.ACTION:
            action_definition = definition
            break
    for definition in ace_registry.search("always"):
        if definition.ace_type in [ACEDefinition.ACEType.CONDITION, ACEDefinition.ACEType.TRIGGER]:
            condition_definition = definition
            break
    all_passed = _check("found action definition with params", action_definition != null and not action_definition.parameters.is_empty(), true) and all_passed
    if action_definition != null:
        dock.setup(copy_sheet)
        dock._on_ace_picker_selected(action_definition, {"mode": "append_action", "selected_resource": dock.get_current_sheet().events[0]})
        all_passed = _check("ace apply appends action", ((dock.get_current_sheet().events[0] as EventRow).actions.size()) >= 2, true) and all_passed
    if condition_definition != null:
        dock.setup(EventSheetResource.new())
        dock._apply_ace_definition(condition_definition, {}, {"mode": "new_condition_event", "selected_resource": null})
        all_passed = _check("new condition mode creates event row", dock.get_current_sheet().events.size(), 1) and all_passed
        all_passed = _check("new condition mode stores condition on new event", ((dock.get_current_sheet().events[0] as EventRow).conditions.size()) + (1 if (dock.get_current_sheet().events[0] as EventRow).trigger != null else 0) > 0, true) and all_passed

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
    all_passed = _check("save normalization adds default filename", dock._normalize_sheet_save_path("res://"), "res://event_sheet.tres") and all_passed
    all_passed = _check("save normalization appends tres extension", dock._normalize_sheet_save_path("res://sheets/editor_sheet"), "res://sheets/editor_sheet.tres") and all_passed

    # Drag-drop ACE preview updates side panel list.
    var preview_defs: Array[ACEDefinition] = []
    var on_signal_def: ACEDefinition = ACEDefinition.new()
    on_signal_def.provider_id = "Core"
    on_signal_def.id = "OnSignal"
    on_signal_def.display_name = "On Signal"
    on_signal_def.category = "Signals / Scene / Input"
    on_signal_def.ace_type = ACEDefinition.ACEType.TRIGGER
    preview_defs.append(on_signal_def)
    dock._on_ace_preview_requested("DemoNode", preview_defs)
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

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
    if actual == expected:
        print("[PASS] event_sheet_editor_test: %s" % label)
        return true
    print("[FAIL] event_sheet_editor_test: %s" % label)
    print("  expected: %s" % str(expected))
    print("  actual:   %s" % str(actual))
    return false
