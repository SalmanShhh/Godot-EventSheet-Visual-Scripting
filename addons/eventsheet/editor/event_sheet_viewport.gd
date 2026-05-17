@tool
class_name EventSheetViewport
extends Control

signal selection_changed(row_data: EventRowData)
signal row_drop_requested(source_row: EventRowData, target_row: EventRowData)

const ROW_HEIGHT := EventSheetPalette.ROW_HEIGHT
const INDENT_WIDTH := EventSheetPalette.INDENT_WIDTH
const FONT_SIZE := EventSheetPalette.FONT_SIZE

var _renderer: EventRowRenderer = EventRowRenderer.new()
var _layout_cache: RowLayoutCache = RowLayoutCache.new()
var _sheet: EventSheetResource = null
var _root_rows: Array[EventRowData] = []
var _flat_rows: Array[Dictionary] = []
var _selected_row_index: int = -1
var _selected_span_index: int = -1
var _hovered_row_index: int = -1
var _hovered_span_index: int = -1
var _editing_row_index: int = -1
var _editing_span_index: int = -1
var _editing_buffer: String = ""
var _editing_caret: int = 0
var _drag_row_index: int = -1
var _drag_target_index: int = -1
var _last_scroll: int = -1
var _fold_state: Dictionary = {}
var _debug_rows: Dictionary = {}

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

func set_debug_overlay_states(states: Dictionary) -> void:
    _debug_rows = states.duplicate(true)
    _refresh_rows()

func get_total_row_count() -> int:
    return _flat_rows.size()

func get_selected_row_index() -> int:
    return _selected_row_index

func get_flat_rows() -> Array[Dictionary]:
    return _flat_rows.duplicate(true)

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
    for index: int in range(visible_range.x, visible_range.y + 1):
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
    if _drag_row_index >= 0:
        _drag_target_index = int(hit.get("row_index", -1))
        queue_redraw()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
    if event.button_index != MOUSE_BUTTON_LEFT:
        return
    var hit: Dictionary = _hit_test(event.position)
    var row_index: int = int(hit.get("row_index", -1))
    var span_index: int = int(hit.get("span_index", -1))
    if event.pressed:
        grab_focus()
        _select_row(row_index, span_index)
        if bool(hit.get("fold", false)):
            _toggle_row_fold(row_index)
            return
        if event.double_click:
            _begin_edit(row_index, span_index)
            return
        _drag_row_index = row_index
        _drag_target_index = -1
        return
    if _drag_row_index >= 0 and _drag_target_index >= 0 and _drag_target_index != _drag_row_index:
        var source_row: EventRowData = _row_at(_drag_row_index)
        var target_row: EventRowData = _row_at(_drag_target_index)
        if source_row != null and target_row != null:
            row_drop_requested.emit(source_row, target_row)
    _drag_row_index = -1
    _drag_target_index = -1
    queue_redraw()

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
    for row_data: EventRowData in _root_rows:
        _flatten_row(row_data, null)
    if _selected_row_index >= _flat_rows.size():
        _selected_row_index = _flat_rows.size() - 1
    for index: int in range(_flat_rows.size()):
        var row_data_state: EventRowData = _flat_rows[index].get("row")
        if row_data_state == null:
            continue
        row_data_state.selected = index == _selected_row_index
        row_data_state.hovered = index == _hovered_row_index
    custom_minimum_size = Vector2(640.0, max(float(_flat_rows.size() * ROW_HEIGHT), 240.0))
    _layout_cache.clear()
    queue_redraw()

func _build_rows_from_sheet(sheet: EventSheetResource) -> Array[EventRowData]:
    var root_rows: Array[EventRowData] = []
    if sheet == null:
        return root_rows
    for entry: Resource in sheet.events:
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
    row_data.spans = [
        _make_span("group", SemanticSpan.SpanType.KEYWORD, {"editable": false}),
        _make_span(_group_name(group), SemanticSpan.SpanType.OBJECT, {"editable": true, "edit_kind": "group_name"})
    ]
    for child: Resource in _group_children(group):
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
    row_data.spans = _build_event_spans(event_row)
    for child: Resource in event_row.sub_events:
        var child_row: EventRowData = _build_row_from_resource(child, indent + 1)
        if child_row != null:
            row_data.children.append(child_row)
    return row_data

func _build_event_spans(event_row: EventRow) -> Array[SemanticSpan]:
    var spans: Array[SemanticSpan] = []
    if event_row.trigger != null:
        spans.append(_make_span("on", SemanticSpan.SpanType.KEYWORD))
        spans.append(_make_span(_format_condition_descriptor(event_row.trigger), SemanticSpan.SpanType.CONDITION))
    elif not event_row.trigger_id.is_empty():
        spans.append(_make_span("on", SemanticSpan.SpanType.KEYWORD))
        spans.append(_make_span(event_row.trigger_id, SemanticSpan.SpanType.CONDITION))
    if not event_row.conditions.is_empty():
        if not spans.is_empty():
            spans.append(_make_span("and", SemanticSpan.SpanType.KEYWORD))
        for condition_index: int in range(event_row.conditions.size()):
            var condition: ACECondition = event_row.conditions[condition_index]
            if condition == null:
                continue
            if condition_index > 0:
                spans.append(_make_span("and", SemanticSpan.SpanType.KEYWORD))
            spans.append(_make_span(_format_condition_descriptor(condition), SemanticSpan.SpanType.CONDITION))
    if spans.is_empty():
        spans.append(_make_span("when", SemanticSpan.SpanType.KEYWORD))
        spans.append(_make_span("Always", SemanticSpan.SpanType.CONDITION))
    if not event_row.actions.is_empty():
        spans.append(_make_span("→", SemanticSpan.SpanType.OPERATOR, {"hoverable": false}))
        for action_index: int in range(event_row.actions.size()):
            var action_resource: Resource = event_row.actions[action_index]
            if action_resource is ACEAction:
                if action_index > 0:
                    spans.append(_make_span(";", SemanticSpan.SpanType.OPERATOR, {"hoverable": false}))
                spans.append(_make_span(_format_action_descriptor(action_resource as ACEAction), SemanticSpan.SpanType.ACTION))
    if not event_row.comment.is_empty():
        spans.append(_make_span("//", SemanticSpan.SpanType.KEYWORD, {"hoverable": false}))
        spans.append(_make_span(event_row.comment, SemanticSpan.SpanType.COMMENT, {"editable": true, "edit_kind": "event_comment"}))
    return spans

func _flatten_row(row_data: EventRowData, parent_row: EventRowData) -> void:
    _flat_rows.append({"row": row_data, "parent": parent_row})
    if row_data.folded:
        return
    for child: EventRowData in row_data.children:
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
    var x: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + EventSheetPalette.GUTTER_WIDTH + float(row_data.indent * INDENT_WIDTH)
    var fold_rect: Rect2 = Rect2(x - 14.0, row_top + 6.0, 12.0, 16.0) if not row_data.children.is_empty() else Rect2()
    var icon_rect := Rect2(x + 2.0, row_top + 9.0, EventSheetPalette.ICON_SIZE, EventSheetPalette.ICON_SIZE)
    x += 18.0
    for span_index: int in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null:
            continue
        var measured_text: String = _editing_buffer if index == _editing_row_index and span_index == _editing_span_index else span.text
        var span_width: float = font.get_string_size(measured_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
        span.rect = Rect2(x, row_top + 4.0, span_width + 2.0, ROW_HEIGHT - 8.0)
        x += span.rect.size.x + EventSheetPalette.SPAN_GAP
    var drag_rect := Rect2()
    if _drag_row_index >= 0 and _drag_target_index == index:
        drag_rect = Rect2(0.0, row_rect.position.y - 1.0, width, 2.0)
    var layout := {
        "row_rect": row_rect,
        "fold_rect": fold_rect,
        "icon_rect": icon_rect,
        "alternating": index % 2 == 1,
        "debug_text": row_data.debug_state,
        "drag_rect": drag_rect,
        "editing_span_index": _editing_span_index if index == _editing_row_index else -1,
        "editing_buffer": _editing_buffer if index == _editing_row_index else "",
        "editing_caret": _editing_caret if index == _editing_row_index else -1
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

func _select_row(row_index: int, span_index: int = -1) -> void:
    if _flat_rows.is_empty():
        _selected_row_index = -1
        _selected_span_index = -1
        queue_redraw()
        return
    _selected_row_index = clampi(row_index, 0, _flat_rows.size() - 1)
    _selected_span_index = span_index
    for index: int in range(_flat_rows.size()):
        var row_data: EventRowData = _flat_rows[index].get("row")
        if row_data == null:
            continue
        row_data.selected = index == _selected_row_index
    selection_changed.emit(_row_at(_selected_row_index))
    queue_redraw()

func _set_hover_state(row_index: int, span_index: int) -> void:
    _hovered_row_index = row_index
    _hovered_span_index = span_index
    for index: int in range(_flat_rows.size()):
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
    for index: int in range(row_data.spans.size()):
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
    span.text = _editing_buffer
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
    for span_index: int in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span != null and span.hoverable and span.rect.has_point(position):
            result["span_index"] = span_index
            return result
    return result

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
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
    if descriptor == null:
        return condition.ace_id
    var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
    return descriptor.format_display(params_dict)

func _format_action_descriptor(action: ACEAction) -> String:
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
    if descriptor == null:
        return action.ace_id
    var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
    return descriptor.format_display(params_dict)

func _make_span(text: String, span_type: int, metadata: Dictionary = {}) -> SemanticSpan:
    var span := SemanticSpan.new()
    span.text = text
    span.type = span_type
    span.metadata = metadata.duplicate(true)
    span.hoverable = bool(span.metadata.get("hoverable", true))
    return span

func _configure_viewport() -> void:
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
