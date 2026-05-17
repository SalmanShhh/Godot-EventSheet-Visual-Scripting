@tool
class_name EventSheetViewport
extends Control

signal selection_changed(row_data: EventRowData)
signal row_drop_requested(source_row: EventRowData, target_row: EventRowData, drop_mode: String)
signal rows_drop_requested(source_rows: Array, target_row: EventRowData, drop_mode: String)
signal ace_preview_requested(source_label: String, definitions: Array[ACEDefinition])
signal ace_picker_requested(row_data: EventRowData, lane: String)
signal span_edit_requested(row_data: EventRowData, edit_kind: String, old_value: String, new_value: String)
signal ace_edit_requested(row_data: EventRowData, span_index: int, metadata: Dictionary)
signal ace_drop_requested(
    source_entries: Array,
    target_row: EventRowData,
    target_lane: String,
    target_ace_index: int,
    insert_mode: String
)
signal context_menu_requested(row_data: EventRowData, hit: Dictionary, global_position: Vector2)

const ROW_HEIGHT := EventSheetPalette.ROW_HEIGHT
const INDENT_WIDTH := EventSheetPalette.INDENT_WIDTH
const FONT_SIZE := EventSheetPalette.FONT_SIZE
const CONDITION_KEYWORD_METADATA := {"lane": "condition", "hoverable": false}
const BADGE_OR_METADATA := {
    "lane": "condition",
    "hoverable": false,
    "badge": true,
    "badge_bg": Color(0.26, 0.29, 0.36, 0.95),
    "badge_fg": Color(0.82, 0.87, 0.95, 1.0)
}
const BADGE_NEGATED_METADATA := {
    "lane": "condition",
    "hoverable": false,
    "badge": true,
    "badge_bg": Color(0.73, 0.20, 0.24, 0.95),
    "badge_fg": Color(1.0, 1.0, 1.0, 1.0)
}
const BADGE_TRIGGER_METADATA := {
    "lane": "condition",
    "hoverable": false,
    "badge": true,
    "badge_bg": EventSheetPalette.COLOR_TRIGGER_ARROW_BG,
    "badge_fg": EventSheetPalette.COLOR_TRIGGER_ARROW_FG
}
const ACE_DRAG_KINDS := ["condition", "action"]
const DROP_ZONE_INSIDE_TOP := 0.33
const DROP_ZONE_INSIDE_BOTTOM := 0.67
const DROP_ZONE_AFTER_THRESHOLD := 0.5

var _renderer: EventRowRenderer = EventRowRenderer.new()
var _layout_cache: RowLayoutCache = RowLayoutCache.new()
var _ace_registry: EventSheetACERegistry = EventSheetACERegistry.new()
var _sheet: EventSheetResource = null
var _root_rows: Array[EventRowData] = []
var _flat_rows: Array[Dictionary] = []
var _selected_row_index: int = -1
var _selected_span_index: int = -1
var _selected_row_uids: Dictionary = {}
var _selected_span_indices: Dictionary = {}
var _hovered_row_index: int = -1
var _hovered_span_index: int = -1
var _editing_row_index: int = -1
var _editing_span_index: int = -1
var _editing_buffer: String = ""
var _editing_caret: int = 0
var _drag_row_index: int = -1
var _drag_row_indices: Array[int] = []
var _drag_target_index: int = -1
var _drag_target_mode: String = "before"
var _drag_ace_entries: Array = []
var _drag_ace_target_row_index: int = -1
var _drag_ace_target_lane: String = ""
var _drag_ace_target_ace_index: int = -1
var _drag_ace_insert_mode: String = "append"
var _last_scroll: int = -1
var _fold_state: Dictionary = {}
var _debug_rows: Dictionary = {}
var _breakpoint_rows: Dictionary = {}
var _row_disabled_state: Dictionary = {}
var _focused_lane: String = "condition"
var _selection_anchor_index: int = -1
var _external_span_edit_handler_enabled: bool = false

func _init() -> void:
    _configure_viewport()

func _ready() -> void:
    _configure_viewport()
    set_process(true)
    _refresh_rows()

func _process(_delta: float) -> void:
    var scroll_value: int = _get_scroll_offset()
    if scroll_value != _last_scroll:
        _last_scroll = scroll_value
        queue_redraw()

func set_sheet(sheet: EventSheetResource) -> void:
    _sheet = sheet
    _refresh_rows()

func set_ace_registry(ace_registry: EventSheetACERegistry) -> void:
    if ace_registry == null:
        _ace_registry = EventSheetACERegistry.new()
    else:
        _ace_registry = ace_registry
    _refresh_rows()

func get_ace_registry() -> EventSheetACERegistry:
    return _ace_registry

func set_debug_overlay_states(states: Dictionary) -> void:
    _debug_rows = states.duplicate(true)
    _refresh_rows()

func get_total_row_count() -> int:
    return _flat_rows.size()

func get_selected_row_index() -> int:
    return _selected_row_index

func get_flat_rows() -> Array[Dictionary]:
    return _flat_rows.duplicate(true)

func get_selected_row_data() -> EventRowData:
    return _row_at(_selected_row_index)

func get_selected_span() -> SemanticSpan:
    var row_data: EventRowData = get_selected_row_data()
    if row_data == null:
        return null
    if _selected_span_index < 0 or _selected_span_index >= row_data.spans.size():
        return null
    return row_data.spans[_selected_span_index]

func get_selected_context() -> Dictionary:
    var row_data: EventRowData = get_selected_row_data()
    var span: SemanticSpan = get_selected_span()
    return {
        "row_index": _selected_row_index,
        "span_index": _selected_span_index,
        "row_data": row_data,
        "source_resource": row_data.source_resource if row_data != null else null,
        "span": span,
        "span_metadata": span.metadata if span != null and span.metadata is Dictionary else {}
    }

func get_selected_ace_entries() -> Array:
    var entries: Array = []
    for index in range(_flat_rows.size()):
        var row_data: EventRowData = _row_at(index)
        if row_data == null:
            continue
        var row_uid: String = row_data.row_uid
        var selected_indices: Array = _selected_span_indices.get(row_uid, []).duplicate()
        selected_indices.sort()
        for span_index in selected_indices:
            if span_index < 0 or span_index >= row_data.spans.size():
                continue
            var span: SemanticSpan = row_data.spans[span_index]
            if span == null or not (span.metadata is Dictionary):
                continue
            var metadata: Dictionary = span.metadata as Dictionary
            var kind: String = str(metadata.get("kind", ""))
            var ace_index: int = int(metadata.get("ace_index", -1))
            if not ACE_DRAG_KINDS.has(kind) or ace_index < 0:
                continue
            entries.append(_build_ace_drag_entry(row_data, kind, ace_index))
    return entries

func get_editor_state_snapshot() -> Dictionary:
    return {
        "focused_lane": _focused_lane,
        "selection_anchor_index": _selection_anchor_index,
        "breakpoint_row_count": _breakpoint_rows.size(),
        "disabled_row_count": _row_disabled_state.size(),
        "selected_row_count": _selected_row_uids.size(),
        "selected_span_count": _get_selected_span_count()
    }

func get_row_layout_for_test(row_index: int, width: float = -1.0) -> Dictionary:
    var resolved_width: float = width if width > 0.0 else max(max(size.x, _get_scroll_width()), 640.0)
    return _get_or_build_row_layout(row_index, resolved_width, _get_font(), _get_font_size())

func set_external_span_edit_handler_enabled(enabled: bool) -> void:
    _external_span_edit_handler_enabled = enabled

func get_visible_row_range() -> Vector2i:
    if _flat_rows.is_empty():
        return Vector2i(-1, -1)
    var viewport_height: float = max(_get_viewport_height(), float(ROW_HEIGHT))
    var start_index: int = clampi(int(floor(float(_get_scroll_offset()) / float(ROW_HEIGHT))), 0, _flat_rows.size() - 1)
    var end_index: int = clampi(int(ceil((float(_get_scroll_offset()) + viewport_height) / float(ROW_HEIGHT))), start_index, _flat_rows.size() - 1)
    return Vector2i(start_index, end_index)

func ensure_selection_visible() -> void:
    if _selected_row_index < 0:
        return
    var scroll: ScrollContainer = _get_scroll_container()
    if scroll == null:
        return
    var row_top: int = _selected_row_index * ROW_HEIGHT
    var row_bottom: int = row_top + ROW_HEIGHT
    if row_top < scroll.scroll_vertical:
        scroll.scroll_vertical = row_top
    elif row_bottom > scroll.scroll_vertical + int(_get_viewport_height()):
        scroll.scroll_vertical = row_bottom - int(_get_viewport_height())

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _update_canvas_min_size()
        queue_redraw()

func _draw() -> void:
    var width: float = max(max(size.x, _get_scroll_width()), 640.0)
    _layout_cache.reset(width)
    if _flat_rows.is_empty():
        _draw_empty_state(width)
        return
    var visible_range: Vector2i = get_visible_row_range()
    if visible_range.x < 0:
        return
    var font: Font = _get_font()
    var font_size: int = _get_font_size()
    for index in range(visible_range.x, visible_range.y + 1):
        var row_info: Dictionary = _flat_rows[index]
        var row_data: EventRowData = row_info.get("row")
        if row_data == null:
            continue
        var layout: Dictionary = _get_or_build_row_layout(index, width, font, font_size)
        _renderer.draw_row(self, layout, row_data, font, font_size)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        _handle_mouse_motion(event as InputEventMouseMotion)
        return
    if event is InputEventMouseButton:
        _handle_mouse_button(event as InputEventMouseButton)
        return
    if event is InputEventKey:
        _handle_key(event as InputEventKey)

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
    var hit: Dictionary = _hit_test(event.position)
    _set_hover_state(int(hit.get("row_index", -1)), int(hit.get("span_index", -1)))
    if not _drag_ace_entries.is_empty():
        _update_ace_drag_target(hit, event.position)
    elif _drag_row_index >= 0:
        _drag_target_index = int(hit.get("row_index", -1))
        _drag_target_mode = _resolve_drop_mode(hit, event.position)
        queue_redraw()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
    var hit: Dictionary = _hit_test(event.position)
    var row_index: int = int(hit.get("row_index", -1))
    var span_index: int = int(hit.get("span_index", -1))
    if event.button_index == MOUSE_BUTTON_RIGHT:
        if not event.pressed:
            return
        grab_focus()
        if row_index >= 0:
            _select_from_click(row_index, span_index, false)
            var row_data: EventRowData = _row_at(row_index)
            if row_data != null:
                context_menu_requested.emit(row_data, hit.duplicate(true), get_global_mouse_position())
                accept_event()
        return
    if event.button_index != MOUSE_BUTTON_LEFT:
        return
    if event.pressed:
        grab_focus()
        if bool(hit.get("fold", false)):
            _select_from_click(row_index, span_index, false)
            _toggle_row_fold(row_index)
            return
        _select_from_click(row_index, span_index, event.ctrl_pressed or event.meta_pressed)
        if event.double_click:
            if _maybe_request_ace_edit(hit, row_index):
                accept_event()
                return
            _begin_edit(row_index, span_index)
            return
        if _maybe_begin_ace_drag(hit, row_index):
            return
        _begin_row_drag(row_index)
        return
    if _complete_ace_drag():
        _clear_ace_drag()
        queue_redraw()
        return
    if _drag_row_index >= 0 and _drag_target_index >= 0 and not _drag_row_indices.has(_drag_target_index):
        var target_row: EventRowData = _row_at(_drag_target_index)
        if target_row != null:
            if _drag_row_indices.size() > 1:
                var dragged_rows: Array = []
                for source_index in _drag_row_indices:
                    var source_row: EventRowData = _row_at(source_index)
                    if source_row != null:
                        dragged_rows.append(source_row)
                if not dragged_rows.is_empty():
                    rows_drop_requested.emit(dragged_rows, target_row, _drag_target_mode)
            else:
                var source_row: EventRowData = _row_at(_drag_row_index)
                if source_row != null:
                    row_drop_requested.emit(source_row, target_row, _drag_target_mode)
    _clear_row_drag()
    queue_redraw()

func _begin_row_drag(row_index: int) -> void:
    if row_index < 0:
        _clear_row_drag()
        return
    var selected_indices: Array[int] = _get_selected_row_indices()
    if selected_indices.size() > 1 and selected_indices.has(row_index):
        _drag_row_indices = selected_indices
    else:
        _drag_row_indices = [row_index]
    _drag_row_index = row_index
    _drag_target_index = -1
    _drag_target_mode = "before"

func _clear_row_drag() -> void:
    _drag_row_index = -1
    _drag_row_indices.clear()
    _drag_target_index = -1
    _drag_target_mode = "before"

func _maybe_begin_ace_drag(hit: Dictionary, row_index: int) -> bool:
    if row_index < 0:
        _clear_ace_drag()
        return false
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null:
        _clear_ace_drag()
        return false
    var metadata: Dictionary = hit.get("span_metadata", {})
    var kind: String = str(metadata.get("kind", ""))
    if not ACE_DRAG_KINDS.has(kind):
        _clear_ace_drag()
        return false
    var span_index: int = int(hit.get("span_index", -1))
    var ace_index: int = int(metadata.get("ace_index", -1))
    if ace_index < 0:
        _clear_ace_drag()
        return false
    _drag_ace_entries = _get_draggable_ace_entries(row_data, kind, ace_index, span_index)
    if _drag_ace_entries.is_empty():
        _clear_ace_drag()
        return false
    _drag_ace_target_row_index = -1
    _drag_ace_target_lane = ""
    _drag_ace_target_ace_index = -1
    _drag_ace_insert_mode = "append"
    _clear_row_drag()
    return true

func _clear_ace_drag() -> void:
    _drag_ace_entries.clear()
    _drag_ace_target_row_index = -1
    _drag_ace_target_lane = ""
    _drag_ace_target_ace_index = -1
    _drag_ace_insert_mode = "append"

func _update_ace_drag_target(hit: Dictionary, position: Vector2) -> void:
    _drag_ace_target_row_index = -1
    _drag_ace_target_lane = ""
    _drag_ace_target_ace_index = -1
    _drag_ace_insert_mode = "append"
    if _drag_ace_entries.is_empty():
        return
    var row_index: int = int(hit.get("row_index", -1))
    if row_index < 0:
        queue_redraw()
        return
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null or not (row_data.source_resource is EventRow):
        queue_redraw()
        return
    var drag_kind: String = str(_drag_ace_entries[0].get("kind", ""))
    var lane: String = str(hit.get("lane", drag_kind))
    if lane != drag_kind:
        queue_redraw()
        return
    var metadata: Dictionary = hit.get("span_metadata", {})
    var kind: String = str(metadata.get("kind", ""))
    _drag_ace_target_row_index = row_index
    _drag_ace_target_lane = lane
    if kind == drag_kind:
        _drag_ace_target_ace_index = int(metadata.get("ace_index", -1))
        var span_index: int = int(hit.get("span_index", -1))
        if span_index >= 0 and span_index < row_data.spans.size():
            var span_rect: Rect2 = row_data.spans[span_index].rect
            _drag_ace_insert_mode = (
                "after" if position.x >= span_rect.get_center().x else "before"
            )
    elif kind == "trigger" and drag_kind == "condition":
        _drag_ace_target_ace_index = 0
        _drag_ace_insert_mode = "before"
    queue_redraw()

func _complete_ace_drag() -> bool:
    if _drag_ace_entries.is_empty():
        return false
    if _drag_ace_target_row_index < 0:
        return false
    var target_row: EventRowData = _row_at(_drag_ace_target_row_index)
    if target_row == null:
        return false
    ace_drop_requested.emit(
        _drag_ace_entries.duplicate(),
        target_row,
        _drag_ace_target_lane,
        _drag_ace_target_ace_index,
        _drag_ace_insert_mode
    )
    return true

func _handle_key(event: InputEventKey) -> void:
    if not event.pressed or event.echo:
        return
    if _editing_row_index >= 0:
        _handle_editing_key(event)
        return
    if event.keycode == KEY_UP:
        _select_row(_selected_row_index - 1, _selected_span_index)
        ensure_selection_visible()
        accept_event()
    elif event.keycode == KEY_DOWN:
        _select_row(_selected_row_index + 1, _selected_span_index)
        ensure_selection_visible()
        accept_event()
    elif event.keycode == KEY_LEFT:
        var left_row: EventRowData = _row_at(_selected_row_index)
        if left_row != null and not left_row.children.is_empty() and not left_row.folded:
            _toggle_row_fold(_selected_row_index)
            accept_event()
    elif event.keycode == KEY_RIGHT:
        var right_row: EventRowData = _row_at(_selected_row_index)
        if right_row != null and not right_row.children.is_empty() and right_row.folded:
            _toggle_row_fold(_selected_row_index)
            accept_event()
    elif event.keycode == KEY_B and (event.ctrl_pressed or event.meta_pressed):
        _toggle_breakpoint(_selected_row_index)
        accept_event()
    elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_F2]:
        _begin_edit(_selected_row_index, _selected_span_index)
        accept_event()

func _handle_editing_key(event: InputEventKey) -> void:
    if event.keycode == KEY_ESCAPE:
        _cancel_edit()
        accept_event()
        return
    if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
        _commit_edit()
        accept_event()
        return
    if event.keycode == KEY_BACKSPACE:
        if _editing_caret > 0:
            _editing_buffer = _editing_buffer.substr(0, _editing_caret - 1) + _editing_buffer.substr(_editing_caret)
            _editing_caret -= 1
            queue_redraw()
        accept_event()
        return
    if event.keycode == KEY_LEFT:
        _editing_caret = maxi(_editing_caret - 1, 0)
        queue_redraw()
        accept_event()
        return
    if event.keycode == KEY_RIGHT:
        _editing_caret = mini(_editing_caret + 1, _editing_buffer.length())
        queue_redraw()
        accept_event()
        return
    if event.unicode > 0 and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
        var typed_char: String = char(event.unicode)
        if not typed_char.is_empty():
            _editing_buffer = _editing_buffer.substr(0, _editing_caret) + typed_char + _editing_buffer.substr(_editing_caret)
            _editing_caret += typed_char.length()
            queue_redraw()
            accept_event()

func _refresh_rows() -> void:
    _root_rows = _build_rows_from_sheet(_sheet)
    _flat_rows.clear()
    for row_data in _root_rows:
        _flatten_row(row_data, null)
    for index in range(_flat_rows.size()):
        var line_row: EventRowData = _flat_rows[index].get("row")
        if line_row == null:
            continue
        line_row.line_number = index + 1
        if _breakpoint_rows.has(line_row.row_uid):
            line_row.breakpoint_enabled = bool(_breakpoint_rows[line_row.row_uid])
        if _row_disabled_state.has(line_row.row_uid):
            line_row.disabled = bool(_row_disabled_state[line_row.row_uid])
    if _selected_row_index >= _flat_rows.size():
        _selected_row_index = _flat_rows.size() - 1
    for index in range(_flat_rows.size()):
        var row_data_state: EventRowData = _flat_rows[index].get("row")
        if row_data_state == null:
            continue
        row_data_state.selected = _selected_row_uids.has(row_data_state.row_uid)
        row_data_state.hovered = index == _hovered_row_index
    _update_canvas_min_size()
    _layout_cache.clear()
    queue_redraw()

func _build_rows_from_sheet(sheet: EventSheetResource) -> Array[EventRowData]:
    var root_rows: Array[EventRowData] = []
    if sheet == null:
        return root_rows
    for entry in sheet.events:
        var row_data: EventRowData = _build_row_from_resource(entry, 0)
        if row_data != null:
            root_rows.append(row_data)
    return root_rows

func _build_row_from_resource(entry: Resource, indent: int) -> EventRowData:
    if entry == null:
        return null
    if entry is EventGroup:
        return _build_group_row(entry as EventGroup, indent)
    if entry is CommentRow:
        return _build_comment_row(entry as CommentRow, indent)
    if entry is EventRow:
        return _build_event_row(entry as EventRow, indent)
    return null

func _build_group_row(group: EventGroup, indent: int) -> EventRowData:
    var row_data := EventRowData.new()
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.GROUP
    row_data.source_resource = group
    row_data.row_uid = group.group_uid if not group.group_uid.is_empty() else "group_%s" % indent
    row_data.folded = bool(_fold_state.get(row_data.row_uid, group.is_collapsed()))
    row_data.debug_state = str(_debug_rows.get(row_data.row_uid, ""))
    row_data.disabled = not group.enabled or bool(_row_disabled_state.get(row_data.row_uid, false))
    row_data.breakpoint_enabled = bool(_breakpoint_rows.get(row_data.row_uid, false))
    row_data.spans = [
        _make_span("group", SemanticSpan.SpanType.KEYWORD, {"editable": false}),
        _make_span(_group_name(group), SemanticSpan.SpanType.OBJECT, {"editable": true, "edit_kind": "group_name"})
    ]
    for child in _group_children(group):
        var child_row: EventRowData = _build_row_from_resource(child, indent + 1)
        if child_row != null:
            row_data.children.append(child_row)
    return row_data

func _build_comment_row(comment_row: CommentRow, indent: int) -> EventRowData:
    var row_data := EventRowData.new()
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.COMMENT
    row_data.source_resource = comment_row
    row_data.row_uid = "comment_%s_%d" % [str(comment_row.get_instance_id()), indent]
    row_data.folded = false
    row_data.debug_state = str(_debug_rows.get(row_data.row_uid, ""))
    row_data.disabled = not comment_row.enabled or bool(_row_disabled_state.get(row_data.row_uid, false))
    row_data.breakpoint_enabled = bool(_breakpoint_rows.get(row_data.row_uid, false))
    row_data.spans = [
        _make_span("//", SemanticSpan.SpanType.KEYWORD, {"editable": false}),
        _make_span(comment_row.text if not comment_row.text.is_empty() else "Comment", SemanticSpan.SpanType.COMMENT, {"editable": true, "edit_kind": "comment_text"})
    ]
    return row_data

func _build_event_row(event_row: EventRow, indent: int) -> EventRowData:
    var row_data := EventRowData.new()
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.EVENT
    row_data.source_resource = event_row
    row_data.row_uid = event_row.event_uid if not event_row.event_uid.is_empty() else "event_%s_%d" % [str(event_row.get_instance_id()), indent]
    row_data.folded = bool(_fold_state.get(row_data.row_uid, false))
    row_data.debug_state = str(_debug_rows.get(row_data.row_uid, ""))
    row_data.disabled = not event_row.enabled or bool(_row_disabled_state.get(row_data.row_uid, false))
    row_data.breakpoint_enabled = bool(_breakpoint_rows.get(row_data.row_uid, false))
    row_data.spans = _build_event_spans(event_row)
    for child in event_row.sub_events:
        var child_row: EventRowData = _build_row_from_resource(child, indent + 1)
        if child_row != null:
            row_data.children.append(child_row)
    return row_data

func _build_event_spans(event_row: EventRow) -> Array[SemanticSpan]:
    var spans: Array[SemanticSpan] = []
    if event_row.trigger != null:
        spans.append(_make_span("on", SemanticSpan.SpanType.KEYWORD, CONDITION_KEYWORD_METADATA))
        spans.append(_make_span("➜", SemanticSpan.SpanType.KEYWORD, BADGE_TRIGGER_METADATA))
        spans.append(
            _make_span(
                _format_condition_descriptor(event_row.trigger),
                SemanticSpan.SpanType.CONDITION,
                {"lane": "condition", "kind": "trigger", "ace_index": 0, "chip": true}
            )
        )
    elif not event_row.trigger_id.is_empty():
        spans.append(_make_span("on", SemanticSpan.SpanType.KEYWORD, CONDITION_KEYWORD_METADATA))
        spans.append(_make_span("➜", SemanticSpan.SpanType.KEYWORD, BADGE_TRIGGER_METADATA))
        spans.append(
            _make_span(
                event_row.trigger_id,
                SemanticSpan.SpanType.CONDITION,
                {"lane": "condition", "kind": "trigger", "ace_index": 0, "chip": true}
            )
        )
    if not event_row.conditions.is_empty():
        if not spans.is_empty():
            spans.append(_make_span("and", SemanticSpan.SpanType.KEYWORD, CONDITION_KEYWORD_METADATA))
        for condition_index in range(event_row.conditions.size()):
            var condition: ACECondition = event_row.conditions[condition_index]
            if condition == null:
                continue
            if condition_index > 0:
                spans.append(_make_span("or" if event_row.condition_mode == EventRow.ConditionMode.OR else "and", SemanticSpan.SpanType.KEYWORD, CONDITION_KEYWORD_METADATA))
            _append_condition_prefix_spans(spans, event_row, condition, condition_index)
            spans.append(
                _make_span(
                    _format_condition_descriptor(condition),
                    SemanticSpan.SpanType.CONDITION,
                    {
                        "lane": "condition",
                        "kind": "condition",
                        "ace_index": condition_index,
                        "chip": true
                    }
                )
            )
    if spans.is_empty():
        spans.append(_make_span("when", SemanticSpan.SpanType.KEYWORD, CONDITION_KEYWORD_METADATA))
        spans.append(_make_span("Always", SemanticSpan.SpanType.CONDITION, {"lane": "condition", "kind": "condition", "ace_index": -1}))
    if not event_row.actions.is_empty():
        spans.append(_make_span("→", SemanticSpan.SpanType.OPERATOR, {"hoverable": false, "lane": "action"}))
        for action_index in range(event_row.actions.size()):
            var action_resource: Resource = event_row.actions[action_index]
            if action_resource is ACEAction:
                if action_index > 0:
                    spans.append(_make_span(";", SemanticSpan.SpanType.OPERATOR, {"hoverable": false, "lane": "action"}))
                spans.append(
                    _make_span(
                        _format_action_descriptor(action_resource as ACEAction),
                        SemanticSpan.SpanType.ACTION,
                        {
                            "lane": "action",
                            "kind": "action",
                            "ace_index": action_index,
                            "chip": true
                        }
                    )
                )
    if not event_row.comment.is_empty():
        spans.append(_make_span("//", SemanticSpan.SpanType.KEYWORD, {"hoverable": false, "lane": "action"}))
        spans.append(
            _make_span(
                event_row.comment,
                SemanticSpan.SpanType.COMMENT,
                {"editable": true, "edit_kind": "event_comment", "lane": "action", "chip": true}
            )
        )
    return spans

func _append_condition_prefix_spans(spans: Array[SemanticSpan], event_row: EventRow, condition: ACECondition, condition_index: int) -> void:
    if event_row == null:
        return
    if event_row.condition_mode == EventRow.ConditionMode.OR and event_row.conditions.size() > 1:
        var or_meta: Dictionary = BADGE_OR_METADATA.duplicate(true)
        or_meta["condition_index"] = condition_index
        spans.append(_make_span("OR", SemanticSpan.SpanType.KEYWORD, or_meta))
    if condition.negated:
        var negated_meta: Dictionary = BADGE_NEGATED_METADATA.duplicate(true)
        negated_meta["condition_index"] = condition_index
        spans.append(_make_span("✕", SemanticSpan.SpanType.KEYWORD, negated_meta))

func _flatten_row(row_data: EventRowData, parent_row: EventRowData) -> void:
    _flat_rows.append({"row": row_data, "parent": parent_row})
    if row_data.folded:
        return
    for child in row_data.children:
        _flatten_row(child, row_data)

func _get_or_build_row_layout(index: int, width: float, font: Font, font_size: int) -> Dictionary:
    var row_data: EventRowData = _row_at(index)
    if row_data == null:
        return {}
    var key: String = "%s:%d:%d:%d" % [row_data.row_uid, index, int(width), _drag_target_index]
    if _layout_cache.has(key):
        return _layout_cache.get_layout(key)
    var row_top: float = float(index * ROW_HEIGHT)
    var row_rect := Rect2(0.0, row_top, width, ROW_HEIGHT)
    var gutter_rect := Rect2(0.0, row_top, EventSheetPalette.GUTTER_WIDTH, ROW_HEIGHT)
    var x: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + EventSheetPalette.GUTTER_WIDTH + float(row_data.indent * INDENT_WIDTH)
    var fold_rect: Rect2 = Rect2(x - 14.0, row_top + 6.0, 12.0, 16.0) if not row_data.children.is_empty() else Rect2()
    var icon_rect := Rect2(x + 2.0, row_top + 9.0, EventSheetPalette.ICON_SIZE, EventSheetPalette.ICON_SIZE)
    x += 18.0
    var condition_lane_rect := Rect2()
    var action_lane_rect := Rect2()
    var lane_divider_rect := Rect2()
    var lane_divider_x: float = -1.0
    if row_data.row_type == EventRowData.RowType.EVENT:
        var content_left: float = EventSheetPalette.GUTTER_WIDTH
        var content_width: float = max(width - content_left, 120.0)
        lane_divider_x = content_left + max(EventSheetPalette.MIN_CONDITIONS_LANE_WIDTH, floor(content_width * EventSheetPalette.CONDITION_LANE_RATIO))
        condition_lane_rect = Rect2(content_left, row_top, max(lane_divider_x - content_left, 1.0), ROW_HEIGHT)
        lane_divider_rect = Rect2(lane_divider_x, row_top, EventSheetPalette.LANE_DIVIDER_WIDTH, ROW_HEIGHT)
        action_lane_rect = Rect2(lane_divider_x + EventSheetPalette.LANE_DIVIDER_WIDTH, row_top, max(width - lane_divider_x - EventSheetPalette.LANE_DIVIDER_WIDTH, 1.0), ROW_HEIGHT)
    for span_index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null:
            continue
        var span_lane: String = _resolve_span_lane(span)
        var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
        if lane_divider_x > 0.0 and span_lane == "action":
            x = max(x, lane_divider_x + EventSheetPalette.LANE_DIVIDER_WIDTH + EventSheetPalette.ACTION_LANE_PADDING)
        var display_text: String = _editing_buffer if index == _editing_row_index and span_index == _editing_span_index else span.text
        var span_width: float = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
        if bool(metadata.get("badge", false)):
            span_width += 12.0
        elif bool(metadata.get("chip", false)):
            span_width += 16.0
        if lane_divider_x > 0.0 and span_lane != "action":
            var max_condition_right: float = lane_divider_x - EventSheetPalette.ACTION_LANE_PADDING
            span_width = max(min(span_width, max_condition_right - x), 10.0)
        span.rect = Rect2(x, row_top + 3.0, span_width + 2.0, ROW_HEIGHT - 6.0)
        x += span.rect.size.x + (8.0 if bool(metadata.get("chip", false)) else EventSheetPalette.SPAN_GAP)
    var drag_rect := Rect2()
    if _drag_row_index >= 0 and _drag_target_index == index:
        match _drag_target_mode:
            "after":
                drag_rect = Rect2(0.0, row_rect.end.y - 1.0, width, 2.0)
            "inside":
                drag_rect = row_rect.grow(-2.0)
            _:
                drag_rect = Rect2(0.0, row_rect.position.y - 1.0, width, 2.0)
    var ace_drag_rect := Rect2()
    if not _drag_ace_entries.is_empty() and _drag_ace_target_row_index == index:
        if _drag_ace_target_ace_index >= 0:
            var target_span_index: int = _find_ace_span_index(
                row_data,
                _drag_ace_target_lane,
                _drag_ace_target_ace_index
            )
            if target_span_index >= 0 and target_span_index < row_data.spans.size():
                ace_drag_rect = row_data.spans[target_span_index].rect.grow(3.0)
        if ace_drag_rect.size == Vector2.ZERO:
            ace_drag_rect = (
                action_lane_rect.grow(-2.0)
                if _drag_ace_target_lane == "action"
                else condition_lane_rect.grow(-2.0)
            )
    var layout := {
        "row_rect": row_rect,
        "gutter_rect": gutter_rect,
        "fold_rect": fold_rect,
        "icon_rect": icon_rect,
        "condition_lane_rect": condition_lane_rect,
        "action_lane_rect": action_lane_rect,
        "lane_divider_rect": lane_divider_rect,
        "lane_divider_x": lane_divider_x,
        "alternating": index % 2 == 1,
        "debug_text": row_data.debug_state,
        "drag_rect": drag_rect,
        "ace_drag_rect": ace_drag_rect,
        "line_number": row_data.line_number,
        "breakpoint_enabled": row_data.breakpoint_enabled,
        "disabled": row_data.disabled,
        "editing_span_index": _editing_span_index if index == _editing_row_index else -1,
        "editing_buffer": _editing_buffer if index == _editing_row_index else "",
        "editing_caret": _editing_caret if index == _editing_row_index else -1,
        "selected_span_indices": _selected_span_indices.get(row_data.row_uid, []).duplicate(),
        "hovered_span_index": _hovered_span_index if index == _hovered_row_index else -1,
        "drag_mode": _drag_target_mode if _drag_target_index == index else ""
    }
    _layout_cache.store(key, layout)
    return layout

func _draw_empty_state(width: float) -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(width, max(size.y, 240.0))), EventSheetPalette.BG_0, true)
    var font: Font = _get_font()
    var font_size: int = _get_font_size()
    var text: String = "No rows. Select an EventSheet resource or use the dock's demo sheet."
    var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
    draw_string(font, Vector2(16.0, 40.0 + text_size.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, EventSheetPalette.TEXT_MUTED)

func _update_canvas_min_size() -> void:
    var canvas_width: float = max(max(size.x, _get_scroll_width()), 640.0)
    custom_minimum_size = Vector2(canvas_width, max(float(_flat_rows.size() * ROW_HEIGHT), 240.0))

func _select_row(row_index: int, span_index: int = -1) -> void:
    if _flat_rows.is_empty():
        _selected_row_uids.clear()
        _selected_span_indices.clear()
        _selected_row_index = -1
        _selected_span_index = -1
        queue_redraw()
        return
    _selected_row_index = clampi(row_index, 0, _flat_rows.size() - 1)
    _selected_span_index = span_index
    _selection_anchor_index = _selected_row_index
    var selected_row: EventRowData = _row_at(_selected_row_index)
    _selected_row_uids.clear()
    _selected_span_indices.clear()
    if selected_row != null:
        _selected_row_uids[selected_row.row_uid] = true
        if span_index >= 0:
            _selected_span_indices[selected_row.row_uid] = [span_index]
        _focused_lane = _resolve_lane_for_row(selected_row, span_index)
    for index in range(_flat_rows.size()):
        var row_data: EventRowData = _flat_rows[index].get("row")
        if row_data == null:
            continue
        row_data.selected = _selected_row_uids.has(row_data.row_uid)
    selection_changed.emit(selected_row)
    queue_redraw()

func _select_from_click(row_index: int, span_index: int, toggle: bool) -> void:
    if row_index < 0:
        if not toggle:
            _clear_selection()
        return
    if not toggle:
        _select_row(row_index, span_index)
        return
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null:
        return
    var row_uid: String = row_data.row_uid
    var changed: bool = false
    if span_index >= 0:
        var indices: Array = _selected_span_indices.get(row_uid, []).duplicate()
        if indices.has(span_index):
            indices.erase(span_index)
        else:
            indices.append(span_index)
            changed = true
        if indices.is_empty():
            _selected_span_indices.erase(row_uid)
            if not _selected_row_uids.has(row_uid):
                _selected_row_index = -1
                _selected_span_index = -1
        else:
            _selected_span_indices[row_uid] = indices
            _selected_row_uids[row_uid] = true
            _selected_row_index = row_index
            _selected_span_index = span_index
            changed = true
    else:
        if _selected_row_uids.has(row_uid) and not _selected_span_indices.has(row_uid):
            _selected_row_uids.erase(row_uid)
            if _selected_row_index == row_index:
                _selected_row_index = -1
                _selected_span_index = -1
        else:
            _selected_row_uids[row_uid] = true
            _selected_row_index = row_index
            _selected_span_index = -1
            changed = true
    if changed:
        _selection_anchor_index = row_index
        _focused_lane = _resolve_lane_for_row(row_data, span_index)
    _sync_row_selection_flags()
    selection_changed.emit(_row_at(_selected_row_index))
    queue_redraw()

func _clear_selection() -> void:
    _selected_row_uids.clear()
    _selected_span_indices.clear()
    _selected_row_index = -1
    _selected_span_index = -1
    _selection_anchor_index = -1
    _sync_row_selection_flags()
    selection_changed.emit(null)
    queue_redraw()

func _sync_row_selection_flags() -> void:
    for entry in _flat_rows:
        var row_data: EventRowData = entry.get("row")
        if row_data == null:
            continue
        row_data.selected = _selected_row_uids.has(row_data.row_uid)

func _set_hover_state(row_index: int, span_index: int) -> void:
    _hovered_row_index = row_index
    _hovered_span_index = span_index
    for index in range(_flat_rows.size()):
        var row_data: EventRowData = _flat_rows[index].get("row")
        if row_data == null:
            continue
        row_data.hovered = index == _hovered_row_index
    queue_redraw()

func _toggle_row_fold(row_index: int) -> void:
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null or row_data.children.is_empty():
        return
    row_data.folded = not row_data.folded
    _fold_state[row_data.row_uid] = row_data.folded
    _refresh_rows()

func _begin_edit(row_index: int, span_index: int) -> void:
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null:
        return
    var resolved_span_index: int = span_index
    if resolved_span_index < 0:
        resolved_span_index = _find_first_editable_span(row_data)
    if resolved_span_index < 0 or resolved_span_index >= row_data.spans.size():
        return
    var span: SemanticSpan = row_data.spans[resolved_span_index]
    var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
    if not bool(metadata.get("editable", false)):
        return
    _editing_row_index = row_index
    _editing_span_index = resolved_span_index
    _editing_buffer = span.text
    _editing_caret = _editing_buffer.length()
    queue_redraw()

func _find_first_editable_span(row_data: EventRowData) -> int:
    for index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[index]
        if span == null or not (span.metadata is Dictionary):
            continue
        if bool((span.metadata as Dictionary).get("editable", false)):
            return index
    return -1

func _commit_edit() -> void:
    var row_data: EventRowData = _row_at(_editing_row_index)
    if row_data == null or _editing_span_index < 0 or _editing_span_index >= row_data.spans.size():
        _cancel_edit()
        return
    var span: SemanticSpan = row_data.spans[_editing_span_index]
    var previous_value: String = span.text
    span.text = _editing_buffer
    var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
    var edit_kind: String = str(metadata.get("edit_kind", ""))
    if _external_span_edit_handler_enabled:
        span_edit_requested.emit(row_data, edit_kind, previous_value, _editing_buffer)
    else:
        _apply_span_edit(row_data, span, _editing_buffer)
    _editing_row_index = -1
    _editing_span_index = -1
    _editing_buffer = ""
    _editing_caret = 0
    _refresh_rows()

func _cancel_edit() -> void:
    _editing_row_index = -1
    _editing_span_index = -1
    _editing_buffer = ""
    _editing_caret = 0
    queue_redraw()

func _apply_span_edit(row_data: EventRowData, span: SemanticSpan, value: String) -> void:
    if not (span.metadata is Dictionary):
        return
    var metadata: Dictionary = span.metadata as Dictionary
    var edit_kind: String = str(metadata.get("edit_kind", ""))
    match edit_kind:
        "group_name":
            if row_data.source_resource is EventGroup:
                var group: EventGroup = row_data.source_resource as EventGroup
                group.name = value
                group.group_name = value
        "comment_text":
            if row_data.source_resource is CommentRow:
                (row_data.source_resource as CommentRow).text = value
        "event_comment":
            if row_data.source_resource is EventRow:
                (row_data.source_resource as EventRow).comment = value

func _hit_test(position: Vector2) -> Dictionary:
    var row_index: int = int(floor(position.y / float(ROW_HEIGHT)))
    if row_index < 0 or row_index >= _flat_rows.size():
        return {}
    var layout: Dictionary = _get_or_build_row_layout(row_index, max(max(size.x, _get_scroll_width()), 640.0), _get_font(), _get_font_size())
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null:
        return {}
    var result := {"row_index": row_index, "span_index": -1, "fold": false}
    var fold_rect: Rect2 = layout.get("fold_rect", Rect2())
    if fold_rect.size != Vector2.ZERO and fold_rect.has_point(position):
        result["fold"] = true
        return result
    for span_index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null or not span.rect.has_point(position):
            continue
        if span.hoverable:
            result["span_index"] = span_index
            result["lane"] = _resolve_span_lane(span)
            result["span_metadata"] = span.metadata if span.metadata is Dictionary else {}
            return result
        if span.metadata is Dictionary and (span.metadata as Dictionary).has("condition_index"):
            var condition_span_index: int = _find_condition_span_index(row_data, int((span.metadata as Dictionary).get("condition_index", -1)))
            if condition_span_index >= 0:
                var condition_span: SemanticSpan = row_data.spans[condition_span_index]
                result["span_index"] = condition_span_index
                result["lane"] = _resolve_span_lane(condition_span)
                result["span_metadata"] = condition_span.metadata if condition_span.metadata is Dictionary else {}
                return result
    var divider_x: float = float(layout.get("lane_divider_x", -1.0))
    if divider_x > 0.0:
        result["lane"] = "action" if position.x >= divider_x else "condition"
    var gutter_rect: Rect2 = layout.get("gutter_rect", Rect2())
    if gutter_rect.size != Vector2.ZERO and gutter_rect.has_point(position):
        result["gutter"] = true
    return result

func _maybe_request_ace_edit(hit: Dictionary, row_index: int) -> bool:
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
        return false
    var span_index: int = int(hit.get("span_index", -1))
    if span_index >= 0 and span_index < row_data.spans.size():
        var span: SemanticSpan = row_data.spans[span_index]
        var metadata: Dictionary = span.metadata if span != null and span.metadata is Dictionary else {}
        var kind: String = str(metadata.get("kind", ""))
        if kind in ["condition", "trigger", "action"]:
            ace_edit_requested.emit(row_data, span_index, metadata.duplicate(true))
            return true
    return false

func _resolve_drop_mode(hit: Dictionary, position: Vector2) -> String:
    var row_index: int = int(hit.get("row_index", -1))
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null:
        return "before"
    var row_top: float = float(row_index * ROW_HEIGHT)
    var relative_y: float = clampf(position.y - row_top, 0.0, float(ROW_HEIGHT))
    if row_data.row_type in [EventRowData.RowType.EVENT, EventRowData.RowType.GROUP] and relative_y >= float(ROW_HEIGHT) * DROP_ZONE_INSIDE_TOP and relative_y <= float(ROW_HEIGHT) * DROP_ZONE_INSIDE_BOTTOM:
        return "inside"
    return "after" if relative_y > float(ROW_HEIGHT) * DROP_ZONE_AFTER_THRESHOLD else "before"

func _get_selected_span_count() -> int:
    var total: int = 0
    for indices in _selected_span_indices.values():
        total += (indices as Array).size()
    return total

func _get_selected_row_indices() -> Array[int]:
    var indices: Array[int] = []
    for index in range(_flat_rows.size()):
        var row_data: EventRowData = _row_at(index)
        if row_data != null and _selected_row_uids.has(row_data.row_uid):
            indices.append(index)
    return indices

func _get_draggable_ace_entries(
    row_data: EventRowData,
    kind: String,
    ace_index: int,
    _span_index: int
) -> Array:
    var selected_entries: Array = get_selected_ace_entries()
    if not selected_entries.is_empty():
        var selected_kind: String = str(selected_entries[0].get("kind", ""))
        if selected_kind == kind:
            for entry in selected_entries:
                if (
                    entry.get("row_uid", "") == row_data.row_uid
                    and int(entry.get("ace_index", -1)) == ace_index
                ):
                    return selected_entries
    return [_build_ace_drag_entry(row_data, kind, ace_index)]

func _build_ace_drag_entry(row_data: EventRowData, kind: String, ace_index: int) -> Dictionary:
    return {
        "row_uid": row_data.row_uid if row_data != null else "",
        "kind": kind,
        "ace_index": ace_index,
        "source_resource": row_data.source_resource if row_data != null else null,
        "ace_resource": _resolve_ace_resource(
            row_data.source_resource if row_data != null else null,
            kind,
            ace_index
        )
    }

func _resolve_ace_resource(source_resource: Resource, kind: String, ace_index: int) -> Resource:
    if not (source_resource is EventRow) or ace_index < 0:
        return null
    var event_row: EventRow = source_resource as EventRow
    match kind:
        "condition":
            if ace_index < event_row.conditions.size():
                return event_row.conditions[ace_index]
        "action":
            if ace_index < event_row.actions.size() and event_row.actions[ace_index] is Resource:
                return event_row.actions[ace_index]
    return null

func _find_condition_span_index(row_data: EventRowData, ace_index: int) -> int:
    return _find_ace_span_index(row_data, "condition", ace_index)

func _find_ace_span_index(row_data: EventRowData, kind: String, ace_index: int) -> int:
    if row_data == null:
        return -1
    for span_index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        if (
            str(metadata.get("kind", "")) == kind
            and int(metadata.get("ace_index", -1)) == ace_index
        ):
            return span_index
    return -1

func _row_at(index: int) -> EventRowData:
    if index < 0 or index >= _flat_rows.size():
        return null
    return _flat_rows[index].get("row")

func _group_children(group: EventGroup) -> Array[Resource]:
    if not group.events.is_empty():
        return group.events
    return group.rows

func _group_name(group: EventGroup) -> String:
    if not group.name.is_empty():
        return group.name
    if not group.group_name.is_empty():
        return group.group_name
    return "Group"

func _format_condition_descriptor(condition: ACECondition) -> String:
    var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
    var generated_definition: ACEDefinition = _find_definition(condition.provider_id, condition.ace_id)
    if generated_definition != null:
        return generated_definition.format_display(params_dict)
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
    if descriptor == null:
        return condition.ace_id
    return descriptor.format_display(params_dict)

func _format_action_descriptor(action: ACEAction) -> String:
    var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
    var generated_definition: ACEDefinition = _find_definition(action.provider_id, action.ace_id)
    if generated_definition != null:
        return generated_definition.format_display(params_dict)
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
    if descriptor == null:
        return action.ace_id
    return descriptor.format_display(params_dict)

func _make_span(text: String, span_type: int, metadata: Dictionary = {}) -> SemanticSpan:
    var span := SemanticSpan.new()
    span.text = text
    span.type = span_type
    span.metadata = metadata.duplicate(true)
    span.hoverable = bool(span.metadata.get("hoverable", true))
    return span

func _resolve_span_lane(span: SemanticSpan) -> String:
    if span == null or not (span.metadata is Dictionary):
        return "condition"
    return str((span.metadata as Dictionary).get("lane", "condition"))

func _resolve_lane_for_row(row_data: EventRowData, span_index: int) -> String:
    if row_data == null:
        return "condition"
    if row_data.row_type != EventRowData.RowType.EVENT:
        return "condition"
    if span_index >= 0 and span_index < row_data.spans.size():
        return _resolve_span_lane(row_data.spans[span_index])
    return _focused_lane

func _toggle_breakpoint(row_index: int) -> void:
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null:
        return
    row_data.breakpoint_enabled = not row_data.breakpoint_enabled
    if row_data.breakpoint_enabled:
        _breakpoint_rows[row_data.row_uid] = true
    else:
        _breakpoint_rows.erase(row_data.row_uid)
    queue_redraw()

func set_row_disabled(row_uid: String, disabled: bool) -> void:
    if row_uid.is_empty():
        return
    if disabled:
        _row_disabled_state[row_uid] = true
    else:
        _row_disabled_state.erase(row_uid)
    _refresh_rows()

func _configure_viewport() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _find_definition(provider_id: String, ace_id: String) -> ACEDefinition:
    if _ace_registry == null:
        return null
    return _ace_registry.find_definition(provider_id, ace_id)

func _get_font() -> Font:
    var font: Font = get_theme_default_font()
    return font if font != null else ThemeDB.fallback_font

func _get_font_size() -> int:
    var theme_size: int = get_theme_default_font_size()
    return theme_size if theme_size > 0 else FONT_SIZE

func _get_scroll_container() -> ScrollContainer:
    return get_parent() as ScrollContainer

func _get_scroll_offset() -> int:
    var scroll: ScrollContainer = _get_scroll_container()
    if scroll == null:
        return 0
    return scroll.scroll_vertical

func _get_viewport_height() -> float:
    var scroll: ScrollContainer = _get_scroll_container()
    if scroll != null and scroll.size.y > 0.0:
        return scroll.size.y
    return size.y if size.y > 0.0 else 240.0

func _get_scroll_width() -> float:
    var scroll: ScrollContainer = _get_scroll_container()
    if scroll != null and scroll.size.x > 0.0:
        return scroll.size.x
    return size.x if size.x > 0.0 else 640.0

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    return not _resolve_dropped_source_objects(data).is_empty()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    var source_objects: Array[Object] = _resolve_dropped_source_objects(data)
    if source_objects.is_empty():
        return
    var preview_registry: EventSheetACERegistry = EventSheetACERegistry.new()
    preview_registry.refresh_from_sources(source_objects, false)
    var definitions: Array[ACEDefinition] = preview_registry.get_all_definitions()
    var source_label: String = source_objects[0].get_class()
    if source_objects[0] is Node:
        source_label = (source_objects[0] as Node).name
    ace_preview_requested.emit(source_label, definitions)

func _resolve_dropped_source_objects(data: Variant) -> Array[Object]:
    var objects: Array[Object] = []
    if data is Object:
        objects.append(data as Object)
        return objects
    if data is Dictionary:
        var payload: Dictionary = data as Dictionary
        var source_object: Variant = payload.get("source_object", null)
        if source_object is Object:
            objects.append(source_object as Object)
            return objects
        var source_node: Variant = payload.get("node", null)
        if source_node is Object:
            objects.append(source_node as Object)
            return objects
        var source_nodes: Variant = payload.get("nodes", [])
        if source_nodes is Array:
            for candidate in source_nodes:
                if candidate is Object:
                    objects.append(candidate as Object)
            if not objects.is_empty():
                return objects
    return objects
