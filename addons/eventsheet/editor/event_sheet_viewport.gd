@tool
class_name EventSheetViewport
extends Control

signal selection_changed(row_data: EventRowData)
signal row_drop_requested(source_row: EventRowData, target_row: EventRowData, drop_mode: String, copy_mode: bool)
signal rows_drop_requested(source_rows: Array, target_row: EventRowData, drop_mode: String, copy_mode: bool)
signal ace_preview_requested(source_label: String, definitions: Array[ACEDefinition])
signal ace_picker_requested(row_data: EventRowData, lane: String)
signal span_edit_requested(row_data: EventRowData, edit_kind: String, old_value: String, new_value: String)
signal ace_edit_requested(row_data: EventRowData, span_index: int, metadata: Dictionary)
signal ace_drop_requested(
    source_entries: Array,
    target_row: EventRowData,
    target_lane: String,
    target_ace_index: int,
    insert_mode: String,
    copy_mode: bool
)
signal context_menu_requested(row_data: EventRowData, hit: Dictionary, global_position: Vector2)
signal empty_space_context_menu_requested(global_position: Vector2)
signal empty_space_double_clicked
signal drag_status_requested(message: String, is_error: bool)

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
const BADGE_EXTRA_WIDTH := 12.0
const CHIP_EXTRA_WIDTH := 16.0
const CHIP_GAP := 8.0
const ACE_DRAG_KINDS := ["trigger", "condition", "action"]
const MIN_ZOOM_FACTOR := 0.6
const MAX_ZOOM_FACTOR := 1.8
const ZOOM_STEP := 0.1
const DROP_ZONE_INSIDE_TOP := 0.33
const DROP_ZONE_INSIDE_BOTTOM := 0.67
const DROP_ZONE_AFTER_THRESHOLD := 0.5
const MIN_BOX_SELECT_DISTANCE := 1.0

var _renderer: EventRowRenderer = EventRowRenderer.new()
var _layout_cache: RowLayoutCache = RowLayoutCache.new()
var _ace_registry: EventSheetACERegistry = EventSheetACERegistry.new()
var _sheet: EventSheetResource = null
var _editor_style: EventSheetEditorStyle = EventSheetEditorStyle.new()
var _root_rows: Array[EventRowData] = []
var _flat_rows: Array[Dictionary] = []
var _row_metrics: Array[Dictionary] = []
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
var _drag_row_copy_mode: bool = false
var _drag_ace_entries: Array = []
var _drag_ace_target_row_index: int = -1
var _drag_ace_target_lane: String = ""
var _drag_ace_target_ace_index: int = -1
var _drag_ace_insert_mode: String = "append"
var _drag_ace_copy_mode: bool = false
var _drag_ace_drop_valid: bool = true
var _drag_feedback_text: String = ""
var _drag_feedback_is_error: bool = false
var _last_scroll: int = -1
var _last_scroll_size: Vector2 = Vector2.ZERO
var _fold_state: Dictionary = {}
var _debug_rows: Dictionary = {}
var _breakpoint_rows: Dictionary = {}
var _row_disabled_state: Dictionary = {}
var _focused_lane: String = "condition"
var _selection_anchor_index: int = -1
var _external_span_edit_handler_enabled: bool = false
var _zoom_factor: float = 1.0
var _layout_style_signature: String = ""
var _box_select_active: bool = false
var _box_select_additive: bool = false
var _box_select_start: Vector2 = Vector2.ZERO
var _box_select_current: Vector2 = Vector2.ZERO

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
    var scroll: ScrollContainer = _get_scroll_container()
    if scroll != null and scroll.size != _last_scroll_size:
        _last_scroll_size = scroll.size
        _update_canvas_min_size()
        queue_redraw()

func set_sheet(sheet: EventSheetResource) -> void:
    _sheet = sheet
    _editor_style = _resolve_editor_style(sheet)
    _update_layout_style_signature(_get_font_size())
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

func get_selected_rows() -> Array[EventRowData]:
    var rows: Array[EventRowData] = []
    for index in _get_selected_row_indices():
        var row_data: EventRowData = _row_at(index)
        if row_data != null:
            rows.append(row_data)
    return rows

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

func get_selected_span_targets() -> Array:
    var targets: Array = []
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
            if not ["trigger", "condition", "action"].has(kind):
                continue
            targets.append({
                "row_uid": row_uid,
                "kind": kind,
                "ace_index": int(metadata.get("ace_index", -1)),
                "source_resource": row_data.source_resource
            })
    return targets

func get_editor_state_snapshot() -> Dictionary:
    return {
        "focused_lane": _focused_lane,
        "selection_anchor_index": _selection_anchor_index,
        "breakpoint_row_count": _breakpoint_rows.size(),
        "disabled_row_count": _row_disabled_state.size(),
        "selected_row_count": _selected_row_uids.size(),
        "selected_span_count": _get_selected_span_count(),
        "zoom_factor": _zoom_factor
    }

func get_editor_style() -> EventSheetEditorStyle:
    return _editor_style

func _resolve_editor_style(sheet: EventSheetResource) -> EventSheetEditorStyle:
    if sheet != null and sheet.editor_style is EventSheetEditorStyle:
        var configured_style: EventSheetEditorStyle = sheet.editor_style as EventSheetEditorStyle
        configured_style.ensure_defaults()
        return configured_style
    var fallback_style := EventSheetEditorStyle.new()
    fallback_style.ensure_defaults()
    return fallback_style

func _get_event_style() -> EventSheetEventStyle:
    if _editor_style == null:
        _editor_style = EventSheetEditorStyle.new()
    return _editor_style.get_event_style()

func _get_condition_style() -> EventSheetElementStyle:
    if _editor_style == null:
        _editor_style = EventSheetEditorStyle.new()
    return _editor_style.get_condition_style()

func _get_action_style() -> EventSheetElementStyle:
    if _editor_style == null:
        _editor_style = EventSheetEditorStyle.new()
    return _editor_style.get_action_style()

func _get_event_line_height(base_font_size: int = FONT_SIZE) -> float:
    var event_style: EventSheetEventStyle = _get_event_style()
    var condition_height: float = _get_condition_style().resolve_line_height(base_font_size, event_style.minimum_row_height)
    var action_height: float = _get_action_style().resolve_line_height(base_font_size, event_style.minimum_row_height)
    return max(float(event_style.minimum_row_height), max(condition_height, action_height))

func _build_element_style_metadata(style: EventSheetElementStyle) -> Dictionary:
    if style == null:
        return {}
    return {
        "text_color": style.text_color,
        "chip_bg": style.chip_background_color,
        "chip_border": style.chip_border_color,
        "chip_hover_bg": style.chip_hover_color,
        "font_size_delta": style.font_size_delta,
        "padding_x": style.horizontal_padding,
        "padding_y": style.vertical_padding,
        "gap_after": style.gap_after,
        "corner_radius": style.corner_radius,
        "badge_bg": style.badge_background_color,
        "badge_fg": style.badge_foreground_color,
        "badge_extra_width": style.badge_extra_width
    }

func _get_span_gap(span: SemanticSpan) -> float:
    if span == null or not (span.metadata is Dictionary):
        return EventSheetPalette.SPAN_GAP
    var metadata: Dictionary = span.metadata as Dictionary
    var fallback_gap: float = CHIP_GAP if bool(metadata.get("chip", false)) else EventSheetPalette.SPAN_GAP
    return max(float(metadata.get("gap_after", fallback_gap)), 0.0)

func _build_layout_style_signature(font_size: int) -> String:
    var event_style: EventSheetEventStyle = _get_event_style()
    var condition_style: EventSheetElementStyle = _get_condition_style()
    var action_style: EventSheetElementStyle = _get_action_style()
    return "%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [
        int(round(_get_event_line_height(font_size))),
        event_style.minimum_conditions_lane_width,
        event_style.condition_lane_padding,
        event_style.action_lane_padding,
        event_style.lane_divider_width,
        int(round(event_style.condition_lane_ratio * 100.0)),
        condition_style.horizontal_padding,
        condition_style.gap_after,
        action_style.horizontal_padding,
        action_style.gap_after
    ]

func _update_layout_style_signature(font_size: int) -> void:
    _layout_style_signature = _build_layout_style_signature(font_size)

func get_row_layout_for_test(row_index: int, width: float = -1.0) -> Dictionary:
    var resolved_width: float = (
        width if width > 0.0 else _get_logical_canvas_width()
    )
    return _get_or_build_row_layout(row_index, resolved_width, _get_font(), _get_font_size())

func set_external_span_edit_handler_enabled(enabled: bool) -> void:
    _external_span_edit_handler_enabled = enabled

func clear_selection() -> void:
    _clear_selection()

func get_zoom_factor() -> float:
    return _zoom_factor

func can_zoom_in() -> bool:
    return _zoom_factor < MAX_ZOOM_FACTOR

func can_zoom_out() -> bool:
    return _zoom_factor > MIN_ZOOM_FACTOR

func set_zoom_factor(value: float) -> void:
    var clamped_value: float = clampf(value, MIN_ZOOM_FACTOR, MAX_ZOOM_FACTOR)
    if is_equal_approx(_zoom_factor, clamped_value):
        return
    _zoom_factor = clamped_value
    _update_canvas_min_size()
    queue_redraw()

func zoom_in(anchor_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
    _apply_zoom_delta(ZOOM_STEP, anchor_position)

func zoom_out(anchor_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
    _apply_zoom_delta(-ZOOM_STEP, anchor_position)

func toggle_row_fold_by_uid(row_uid: String) -> bool:
    if row_uid.is_empty():
        return false
    for index in range(_flat_rows.size()):
        var row_data: EventRowData = _row_at(index)
        if row_data != null and row_data.row_uid == row_uid:
            _toggle_row_fold(index)
            return true
    return false

func get_visible_row_range() -> Vector2i:
    if _flat_rows.is_empty():
        return Vector2i(-1, -1)
    var zoom: float = max(_zoom_factor, 0.001)
    var viewport_height: float = max(_get_viewport_height() / zoom, _get_event_line_height(_get_font_size()))
    var scroll_offset: float = float(_get_scroll_offset()) / zoom
    var start_index: int = _find_row_index_at_y(scroll_offset)
    var end_index: int = _find_row_index_at_y(scroll_offset + viewport_height)
    if start_index < 0:
        start_index = 0
    if end_index < 0:
        end_index = _flat_rows.size() - 1
    if end_index < start_index:
        end_index = start_index
    return Vector2i(start_index, end_index)

func ensure_selection_visible() -> void:
    if _selected_row_index < 0:
        return
    var scroll: ScrollContainer = _get_scroll_container()
    if scroll == null:
        return
    var row_top: int = int(round(_get_row_top(_selected_row_index) * _zoom_factor))
    var row_bottom: int = int(round((_get_row_top(_selected_row_index) + _get_row_height(_selected_row_index)) * _zoom_factor))
    if row_top < scroll.scroll_vertical:
        scroll.scroll_vertical = row_top
    elif row_bottom > scroll.scroll_vertical + int(_get_viewport_height()):
        scroll.scroll_vertical = row_bottom - int(_get_viewport_height())

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _update_canvas_min_size()
        queue_redraw()

func _draw() -> void:
    var zoom: float = max(_zoom_factor, 0.001)
    var width: float = _get_logical_canvas_width()
    _layout_cache.reset(width)
    if _flat_rows.is_empty():
        draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))
        _draw_empty_state(width)
        return
    var visible_range: Vector2i = get_visible_row_range()
    if visible_range.x < 0:
        return
    var font: Font = _get_font()
    var font_size: int = _get_font_size()
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))
    for index in range(visible_range.x, visible_range.y + 1):
        var row_info: Dictionary = _flat_rows[index]
        var row_data: EventRowData = row_info.get("row")
        if row_data == null:
            continue
        var layout: Dictionary = _get_or_build_row_layout(index, width, font, font_size)
        _renderer.draw_row(self, layout, row_data, font, font_size, _editor_style)
    _draw_box_selection_overlay()

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
    var local_position: Vector2 = _to_logical_position(event.position)
    if _box_select_active:
        _box_select_current = local_position
        queue_redraw()
        return
    var hit: Dictionary = _hit_test(local_position)
    _set_hover_state(int(hit.get("row_index", -1)), int(hit.get("span_index", -1)))
    if not _drag_ace_entries.is_empty():
        _drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
        _update_ace_drag_target(hit, local_position)
    elif _drag_row_index >= 0:
        _drag_row_copy_mode = event.ctrl_pressed or event.meta_pressed
        _drag_target_index = int(hit.get("row_index", -1))
        _drag_target_mode = _resolve_drop_mode(hit, local_position)
        queue_redraw()

func _handle_mouse_button(event: InputEventMouseButton) -> void:
    if event.pressed and (event.ctrl_pressed or event.meta_pressed):
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom_in(event.position)
            accept_event()
            return
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom_out(event.position)
            accept_event()
            return
    var local_position: Vector2 = _to_logical_position(event.position)
    if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _box_select_active:
        _box_select_current = local_position
        _complete_box_selection()
        accept_event()
        return
    var hit: Dictionary = _hit_test(local_position)
    var row_index: int = int(hit.get("row_index", -1))
    var span_index: int = int(hit.get("span_index", -1))
    if event.button_index == MOUSE_BUTTON_RIGHT:
        if not event.pressed:
            return
        grab_focus()
        if row_index >= 0:
            if not _is_selection_hit(row_index, span_index):
                _select_from_click(row_index, span_index, false)
            var row_data: EventRowData = _row_at(row_index)
            if row_data != null:
                context_menu_requested.emit(
                    row_data,
                    hit.duplicate(true),
                    DisplayServer.mouse_get_position()
                )
                accept_event()
        else:
            empty_space_context_menu_requested.emit(DisplayServer.mouse_get_position())
            accept_event()
        return
    if event.button_index != MOUSE_BUTTON_LEFT:
        return
    if event.pressed:
        grab_focus()
        if row_index < 0:
            if event.double_click:
                empty_space_double_clicked.emit()
                accept_event()
                return
            _begin_box_selection(local_position, event.ctrl_pressed or event.meta_pressed)
            accept_event()
            return
        var row_data: EventRowData = _row_at(row_index)
        var metadata: Dictionary = hit.get("span_metadata", {})
        if row_data != null and str(metadata.get("kind", "")) == "add_action":
            ace_picker_requested.emit(row_data, "action")
            accept_event()
            return
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
        _drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
        _drag_row_copy_mode = event.ctrl_pressed or event.meta_pressed
        if _maybe_begin_ace_drag(hit, row_index):
            return
        _begin_row_drag(row_index)
        return
    if not _drag_ace_entries.is_empty():
        _drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
        _complete_ace_drag()
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
                    rows_drop_requested.emit(dragged_rows, target_row, _drag_target_mode, _drag_row_copy_mode)
            else:
                var source_row: EventRowData = _row_at(_drag_row_index)
                if source_row != null:
                    row_drop_requested.emit(source_row, target_row, _drag_target_mode, _drag_row_copy_mode)
    _clear_row_drag()
    queue_redraw()

func _begin_box_selection(position: Vector2, additive: bool) -> void:
    _clear_row_drag()
    _clear_ace_drag()
    _box_select_active = true
    _box_select_additive = additive
    _box_select_start = position
    _box_select_current = position
    if not additive:
        _clear_selection()
    queue_redraw()

func _complete_box_selection() -> void:
    if not _box_select_active:
        return
    var selection_rect: Rect2 = Rect2(_box_select_start, Vector2.ZERO).expand(_box_select_current)
    if selection_rect.size.length() <= MIN_BOX_SELECT_DISTANCE:
        _box_select_active = false
        _box_select_additive = false
        queue_redraw()
        return
    _apply_box_selection(selection_rect, _box_select_additive)
    _box_select_active = false
    _box_select_additive = false
    queue_redraw()

func _draw_box_selection_overlay() -> void:
    if not _box_select_active:
        return
    var selection_rect: Rect2 = Rect2(_box_select_start, Vector2.ZERO).expand(_box_select_current)
    if selection_rect.size.length() <= MIN_BOX_SELECT_DISTANCE:
        return
    draw_rect(selection_rect, Color(0.36, 0.60, 0.92, 0.22), true)
    draw_rect(selection_rect, Color(0.55, 0.75, 0.98, 0.9), false, 1.0)

func _apply_box_selection(selection_rect: Rect2, additive: bool) -> void:
    if not additive:
        _selected_row_uids.clear()
        _selected_span_indices.clear()
        _selected_row_index = -1
        _selected_span_index = -1
    var selected_any: bool = false
    for row_index in range(_flat_rows.size()):
        var row_data: EventRowData = _row_at(row_index)
        if row_data == null:
            continue
        var layout: Dictionary = _get_or_build_row_layout(
            row_index,
            _get_logical_canvas_width(),
            _get_font(),
            _get_font_size()
        )
        var row_rect: Rect2 = layout.get("row_rect", Rect2())
        if not row_rect.intersects(selection_rect):
            continue
        _selected_row_uids[row_data.row_uid] = true
        _selected_row_index = row_index
        _selected_span_index = -1
        selected_any = true
        for span_index in range(row_data.spans.size()):
            var span: SemanticSpan = row_data.spans[span_index]
            if span == null or not span.rect.intersects(selection_rect):
                continue
            var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
            var kind: String = str(metadata.get("kind", ""))
            if kind not in ["trigger", "condition", "action"]:
                continue
            var span_indices: Array = _selected_span_indices.get(row_data.row_uid, [])
            if not span_indices.has(span_index):
                span_indices.append(span_index)
                _selected_span_indices[row_data.row_uid] = span_indices
            _selected_row_index = row_index
            _selected_span_index = span_index
            _focused_lane = _resolve_lane_for_row(row_data, span_index)
            selected_any = true
    if selected_any:
        _selection_anchor_index = _selected_row_index
    _sync_row_selection_flags()
    selection_changed.emit(_row_at(_selected_row_index))

func _is_selection_hit(row_index: int, span_index: int) -> bool:
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null:
        return false
    var row_uid: String = row_data.row_uid
    if not _selected_row_uids.has(row_uid):
        return false
    if span_index < 0:
        return true
    var span_indices: Array = _selected_span_indices.get(row_uid, [])
    if span_indices.is_empty():
        return true
    return span_indices.has(span_index)

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
    _drag_row_copy_mode = false

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
    if not ["trigger", "condition", "action"].has(kind):
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
    _drag_ace_drop_valid = true
    _clear_drag_feedback()
    _clear_row_drag()
    return true

func _clear_ace_drag() -> void:
    _drag_ace_entries.clear()
    _drag_ace_target_row_index = -1
    _drag_ace_target_lane = ""
    _drag_ace_target_ace_index = -1
    _drag_ace_insert_mode = "append"
    _drag_ace_copy_mode = false
    _drag_ace_drop_valid = true
    _clear_drag_feedback()

func _clear_drag_feedback() -> void:
    _drag_feedback_text = ""
    _drag_feedback_is_error = false
    tooltip_text = ""

func _update_ace_drag_target(hit: Dictionary, position: Vector2) -> void:
    _drag_ace_target_row_index = -1
    _drag_ace_target_lane = ""
    _drag_ace_target_ace_index = -1
    _drag_ace_insert_mode = "append"
    _drag_ace_drop_valid = true
    _clear_drag_feedback()
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
    var drag_lane: String = "action" if drag_kind == "action" else "condition"
    var lane: String = str(hit.get("lane", drag_lane))
    if lane != drag_lane:
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
    elif kind == "trigger" and drag_lane == "condition":
        _drag_ace_target_ace_index = 0
        _drag_ace_insert_mode = "before"
    else:
        var fallback_target: Dictionary = _resolve_lane_drop_target(row_data, lane, position)
        _drag_ace_target_ace_index = int(fallback_target.get("ace_index", -1))
        _drag_ace_insert_mode = str(fallback_target.get("insert_mode", "append"))
    var validation: Dictionary = _validate_ace_drag_target(row_data, lane)
    _drag_ace_drop_valid = bool(validation.get("valid", true))
    if not _drag_ace_drop_valid:
        _drag_feedback_text = str(validation.get("message", "This drop target is not valid."))
        _drag_feedback_is_error = true
        tooltip_text = _drag_feedback_text
    queue_redraw()

func _complete_ace_drag() -> bool:
    if _drag_ace_entries.is_empty():
        return false
    if _drag_ace_target_row_index < 0:
        return true
    if not _drag_ace_drop_valid:
        if not _drag_feedback_text.is_empty():
            drag_status_requested.emit(_drag_feedback_text, true)
        return true
    var target_row: EventRowData = _row_at(_drag_ace_target_row_index)
    if target_row == null:
        return true
    ace_drop_requested.emit(
        _drag_ace_entries.duplicate(),
        target_row,
        _drag_ace_target_lane,
        _drag_ace_target_ace_index,
        _drag_ace_insert_mode,
        _drag_ace_copy_mode
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
    _update_layout_style_signature(_get_font_size())
    _flat_rows.clear()
    for row_data in _root_rows:
        _flatten_row(row_data, null)
    _rebuild_row_metrics()
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
    root_rows.append_array(_build_global_variable_rows(sheet))
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
        _make_span(
            "Group",
            SemanticSpan.SpanType.KEYWORD,
            {
                "editable": false,
                "badge": true,
                "badge_style": "group",
                "badge_bg": EventSheetPalette.COLOR_GROUP_BADGE_BG,
                "badge_fg": EventSheetPalette.COLOR_GROUP_BADGE_FG,
                "group_badge": true
            }
        ),
        _make_span(
            _group_name(group),
            SemanticSpan.SpanType.OBJECT,
            {"editable": true, "edit_kind": "group_name", "group_title": true}
        )
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
    for local_variable_row in _build_local_variable_rows(event_row, indent + 1):
        row_data.children.append(local_variable_row)
    for child in event_row.sub_events:
        var child_row: EventRowData = _build_row_from_resource(child, indent + 1)
        if child_row != null:
            row_data.children.append(child_row)
    return row_data

func _build_global_variable_rows(sheet: EventSheetResource) -> Array[EventRowData]:
    var rows: Array[EventRowData] = []
    if sheet == null:
        return rows
    var names: Array = sheet.variables.keys()
    names.sort()
    for var_name in names:
        var descriptor: Dictionary = sheet.variables.get(var_name, {})
        rows.append(
            _build_variable_row(
                "global",
                str(var_name),
                str(descriptor.get("type", "Variant")),
                descriptor.get("default", null),
                0,
                {
                    "is_constant": bool(descriptor.get("const", descriptor.get("is_constant", false)))
                }
            )
        )
    return rows

func _build_local_variable_rows(event_row: EventRow, indent: int) -> Array[EventRowData]:
    var rows: Array[EventRowData] = []
    if event_row == null:
        return rows
    for local_variable in event_row.local_variables:
        if not (local_variable is LocalVariable):
            continue
        var descriptor: LocalVariable = local_variable as LocalVariable
        rows.append(
            _build_variable_row(
                "local",
                descriptor.name,
                descriptor.type_name,
                descriptor.default_value,
                indent,
                {
                    "is_constant": descriptor.is_constant,
                    "owner_event": event_row,
                    "variable_index": rows.size()
                }
            )
        )
    return rows

func _build_variable_row(
    scope_label: String,
    var_name: String,
    type_name: String,
    default_value: Variant,
    indent: int,
    options: Dictionary = {}
) -> EventRowData:
    var row_data := EventRowData.new()
    var owner_event: EventRow = options.get("owner_event", null)
    var variable_index: int = int(options.get("variable_index", -1))
    var is_constant: bool = bool(options.get("is_constant", false))
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.SECTION
    row_data.source_resource = owner_event if scope_label == "local" else _sheet
    row_data.row_uid = (
        "variable_local_%s_%d"
        % [owner_event.event_uid if owner_event != null else "none", variable_index]
        if scope_label == "local"
        else "variable_global_%s" % var_name
    )
    row_data.folded = false
    var variable_meta := {
        "kind": "variable",
        "variable_scope": scope_label,
        "variable_name": var_name,
        "variable_index": variable_index,
        "is_constant": is_constant
    }
    row_data.spans = [
        _make_span(scope_label, SemanticSpan.SpanType.KEYWORD, variable_meta.merged({"editable": false, "chip": true}, true)),
        _make_span(var_name if not var_name.is_empty() else "(unnamed)", SemanticSpan.SpanType.OBJECT, variable_meta.merged({"editable": false}, true)),
        _make_span(":", SemanticSpan.SpanType.OPERATOR, variable_meta.merged({"editable": false}, true)),
        _make_span(type_name if not type_name.is_empty() else "Variant", SemanticSpan.SpanType.VALUE, variable_meta.merged({"editable": false}, true))
    ]
    if is_constant:
        row_data.spans.append(
            _make_span(
                "const",
                SemanticSpan.SpanType.KEYWORD,
                variable_meta.merged(
                    {
                        "editable": false,
                        "badge": true,
                        "badge_style": "const",
                        "badge_bg": EventSheetPalette.COLOR_CONST_BADGE_BG,
                        "badge_fg": EventSheetPalette.COLOR_CONST_BADGE_FG
                    },
                    true
                )
            )
        )
    row_data.spans.append(_make_span("=", SemanticSpan.SpanType.OPERATOR, variable_meta.merged({"editable": false}, true)))
    row_data.spans.append(
        _make_span(
            _format_variable_value(default_value),
            SemanticSpan.SpanType.VALUE,
            variable_meta.merged({"editable": false}, true)
        )
    )
    return row_data

func _build_event_spans(event_row: EventRow) -> Array[SemanticSpan]:
    var spans: Array[SemanticSpan] = []
    var condition_line_index: int = 0
    var action_line_index: int = 0
    var inline_trigger_condition_index: int = _find_inline_trigger_condition_index(event_row)
    var event_style: EventSheetEventStyle = _get_event_style()
    var condition_style_meta: Dictionary = _build_element_style_metadata(_get_condition_style())
    var action_style_meta: Dictionary = _build_element_style_metadata(_get_action_style())
    if event_row.trigger != null:
        var trigger_badge_meta: Dictionary = BADGE_TRIGGER_METADATA.duplicate(true)
        trigger_badge_meta["badge_bg"] = event_style.trigger_badge_background_color
        trigger_badge_meta["badge_fg"] = event_style.trigger_badge_foreground_color
        trigger_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", BADGE_EXTRA_WIDTH)
        trigger_badge_meta["line_index"] = condition_line_index
        trigger_badge_meta["badge_style"] = "trigger"
        spans.append(_make_span("➜", SemanticSpan.SpanType.KEYWORD, trigger_badge_meta))
        spans.append(
            _make_span(
                _format_condition_descriptor(event_row.trigger),
                SemanticSpan.SpanType.CONDITION,
                {
                    "lane": "condition",
                    "kind": "trigger",
                    "ace_index": 0,
                    "chip": true,
                    "line_index": condition_line_index
                }.merged(condition_style_meta, true)
            )
        )
    elif not event_row.trigger_id.is_empty():
        var trigger_id_badge_meta: Dictionary = BADGE_TRIGGER_METADATA.duplicate(true)
        trigger_id_badge_meta["badge_bg"] = event_style.trigger_badge_background_color
        trigger_id_badge_meta["badge_fg"] = event_style.trigger_badge_foreground_color
        trigger_id_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", BADGE_EXTRA_WIDTH)
        trigger_id_badge_meta["line_index"] = condition_line_index
        trigger_id_badge_meta["badge_style"] = "trigger"
        spans.append(_make_span("➜", SemanticSpan.SpanType.KEYWORD, trigger_id_badge_meta))
        spans.append(
            _make_span(
                event_row.trigger_id,
                SemanticSpan.SpanType.CONDITION,
                {
                    "lane": "condition",
                    "kind": "trigger",
                    "ace_index": 0,
                    "chip": true,
                    "line_index": condition_line_index
                }.merged(condition_style_meta, true)
            )
        )
    elif inline_trigger_condition_index >= 0 and inline_trigger_condition_index < event_row.conditions.size():
        var inline_trigger: ACECondition = event_row.conditions[inline_trigger_condition_index]
        var inline_trigger_badge_meta: Dictionary = BADGE_TRIGGER_METADATA.duplicate(true)
        inline_trigger_badge_meta["badge_bg"] = event_style.trigger_badge_background_color
        inline_trigger_badge_meta["badge_fg"] = event_style.trigger_badge_foreground_color
        inline_trigger_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", BADGE_EXTRA_WIDTH)
        inline_trigger_badge_meta["line_index"] = condition_line_index
        inline_trigger_badge_meta["badge_style"] = "trigger"
        spans.append(_make_span("➜", SemanticSpan.SpanType.KEYWORD, inline_trigger_badge_meta))
        spans.append(
            _make_span(
                _format_condition_descriptor(inline_trigger),
                SemanticSpan.SpanType.CONDITION,
                {
                    "lane": "condition",
                    "kind": "condition",
                    "ace_index": inline_trigger_condition_index,
                    "chip": true,
                    "line_index": condition_line_index,
                    "rendered_as_trigger": true
                }.merged(condition_style_meta, true)
            )
        )
    if not event_row.conditions.is_empty():
        var displayed_condition_indices: Array[int] = []
        for condition_index in range(event_row.conditions.size()):
            if condition_index == inline_trigger_condition_index:
                continue
            displayed_condition_indices.append(condition_index)
        for display_index in range(displayed_condition_indices.size()):
            var condition_index: int = displayed_condition_indices[display_index]
            var condition: ACECondition = event_row.conditions[condition_index]
            if condition == null:
                continue
            var line_index: int = condition_line_index
            _append_condition_prefix_spans(
                spans,
                event_row,
                condition,
                condition_index,
                line_index,
                display_index,
                displayed_condition_indices.size()
            )
            spans.append(
                _make_span(
                    _format_condition_descriptor(condition),
                    SemanticSpan.SpanType.CONDITION,
                    {
                        "lane": "condition",
                        "kind": "condition",
                        "ace_index": condition_index,
                        "chip": true,
                        "line_index": line_index
                    }.merged(condition_style_meta, true)
                )
            )
    if spans.is_empty():
        spans.append(
            _make_span(
                "Always",
                SemanticSpan.SpanType.CONDITION,
                {
                    "lane": "condition",
                    "kind": "condition",
                    "ace_index": -1,
                    "line_index": 0
                }.merged(condition_style_meta, true)
            )
        )
    if not event_row.actions.is_empty():
        for action_index in range(event_row.actions.size()):
            var action_resource: Resource = event_row.actions[action_index]
            if action_resource is ACEAction:
                spans.append(
                    _make_span(
                        _format_action_descriptor(action_resource as ACEAction),
                        SemanticSpan.SpanType.ACTION,
                        {
                            "lane": "action",
                            "kind": "action",
                            "ace_index": action_index,
                            "chip": true,
                            "line_index": action_line_index
                        }.merged(action_style_meta, true)
                    )
                )
    spans.append(
        _make_span(
            "+ Add",
            SemanticSpan.SpanType.ACTION,
            {
                "lane": "action",
                "kind": "add_action",
                "align_right": true,
                "line_index": action_line_index,
                "text_color": action_style_meta.get("text_color", EventSheetPalette.COLOR_ACTION),
                "font_size_delta": action_style_meta.get("font_size_delta", 0)
            }
        )
    )
    if not event_row.comment.is_empty():
        spans.append(
            _make_span(
                event_row.comment,
                SemanticSpan.SpanType.COMMENT,
                {
                    "editable": true,
                    "edit_kind": "event_comment",
                    "lane": "action",
                    "chip": true,
                    "line_index": action_line_index + 1
                }.merged(action_style_meta, true)
            )
        )
    return spans

func _append_condition_prefix_spans(
    spans: Array[SemanticSpan],
    event_row: EventRow,
    condition: ACECondition,
    condition_index: int,
    line_index: int,
    _display_index: int,
    displayed_condition_count: int
) -> void:
    if event_row == null:
        return
    var condition_style_meta: Dictionary = _build_element_style_metadata(_get_condition_style())
    if (
        event_row.condition_mode == EventRow.ConditionMode.OR
        and displayed_condition_count > 1
    ):
        var or_meta: Dictionary = BADGE_OR_METADATA.duplicate(true)
        or_meta["badge_bg"] = condition_style_meta.get("badge_bg", BADGE_OR_METADATA.get("badge_bg"))
        or_meta["badge_fg"] = condition_style_meta.get("badge_fg", BADGE_OR_METADATA.get("badge_fg"))
        or_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", BADGE_EXTRA_WIDTH)
        or_meta["condition_index"] = condition_index
        or_meta["line_index"] = line_index
        or_meta["badge_style"] = "or"
        spans.append(_make_span("OR", SemanticSpan.SpanType.KEYWORD, or_meta))
    if condition.negated:
        var negated_meta: Dictionary = BADGE_NEGATED_METADATA.duplicate(true)
        negated_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", BADGE_EXTRA_WIDTH)
        negated_meta["condition_index"] = condition_index
        negated_meta["line_index"] = line_index
        negated_meta["badge_style"] = "negated"
        spans.append(_make_span("✕", SemanticSpan.SpanType.KEYWORD, negated_meta))

func _measure_span_width(span: SemanticSpan, display_text: String, font: Font, font_size: int) -> float:
    if span == null:
        return 0.0
    var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
    var font_size_delta: int = int(metadata.get("font_size_delta", 0))
    var horizontal_padding: float = float(metadata.get("padding_x", 0.0))
    var draw_font_size: int = EventSheetPalette.resolve_font_size(font_size, font_size_delta)
    var span_width: float = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
    if bool(metadata.get("badge", false)):
        span_width += max(float(metadata.get("badge_extra_width", BADGE_EXTRA_WIDTH)), 0.0)
        span_width += horizontal_padding * 2.0
    elif bool(metadata.get("chip", false)):
        span_width += max(horizontal_padding * 2.0, CHIP_EXTRA_WIDTH)
    return span_width

func _build_action_line_reservations(
    row_data: EventRowData,
    action_lane_rect: Rect2,
    font: Font,
    font_size: int
) -> Dictionary:
    var reservations: Dictionary = {}
    if action_lane_rect.size == Vector2.ZERO or row_data == null:
        return reservations
    var action_lane_padding: float = float(_get_event_style().action_lane_padding)
    for span_index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        if _resolve_span_lane(span) != "action" or not bool(metadata.get("align_right", false)):
            continue
        var display_text: String = span.text
        var span_width: float = _measure_span_width(span, display_text, font, font_size)
        var span_x: float = max(
            action_lane_rect.position.x + action_lane_padding,
            action_lane_rect.end.x - action_lane_padding - span_width - 2.0
        )
        var line_index: int = int(metadata.get("line_index", 0))
        var current_start: float = float(reservations.get(line_index, action_lane_rect.end.x - action_lane_padding))
        reservations[line_index] = min(current_start, span_x)
    return reservations

func _get_condition_track_start(
    row_data: EventRowData,
    default_x: float,
    condition_lane_rect: Rect2
) -> float:
    if row_data == null or row_data.row_type != EventRowData.RowType.EVENT or condition_lane_rect.size.x <= 0.0:
        return default_x
    return max(default_x, condition_lane_rect.position.x + float(_get_event_style().condition_lane_padding))

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
    var event_style: EventSheetEventStyle = _get_event_style()
    var line_height: float = _get_event_line_height(font_size)
    # Cache key components: row uid, visible row index, canvas width, active drag
    # target index, and the current layout style signature.
    var key: String = "%s:%d:%d:%d:%s" % [row_data.row_uid, index, int(width), _drag_target_index, _layout_style_signature]
    if _layout_cache.has(key):
        return _layout_cache.get_layout(key)
    var row_top: float = _get_row_top(index)
    var row_height: float = _get_row_height(index)
    var row_rect := Rect2(0.0, row_top, width, row_height)
    var gutter_rect := Rect2(0.0, row_top, EventSheetPalette.GUTTER_WIDTH, row_height)
    var x: float = EventSheetPalette.ROW_HORIZONTAL_PADDING + EventSheetPalette.GUTTER_WIDTH + float(row_data.indent * INDENT_WIDTH)
    var fold_rect: Rect2 = Rect2(x - 14.0, row_top + 6.0, 12.0, 16.0) if not row_data.children.is_empty() else Rect2()
    var icon_rect := Rect2(x + 2.0, row_top + 9.0, EventSheetPalette.ICON_SIZE, EventSheetPalette.ICON_SIZE)
    x += 18.0
    var condition_lane_rect := Rect2()
    var action_lane_rect := Rect2()
    var lane_divider_rect := Rect2()
    var lane_divider_x: float = -1.0
    var row_right_limit: float = width - EventSheetPalette.ROW_HORIZONTAL_PADDING
    if row_data.row_type == EventRowData.RowType.EVENT:
        var content_left: float = EventSheetPalette.GUTTER_WIDTH
        var content_width: float = max(width - content_left, 120.0)
        lane_divider_x = content_left + max(float(event_style.minimum_conditions_lane_width), floor(content_width * event_style.condition_lane_ratio))
        condition_lane_rect = Rect2(x, row_top, max(lane_divider_x - x, 1.0), row_height)
        lane_divider_rect = Rect2(lane_divider_x, row_top, float(event_style.lane_divider_width), row_height)
        action_lane_rect = Rect2(lane_divider_x + float(event_style.lane_divider_width), row_top, max(width - lane_divider_x - float(event_style.lane_divider_width), 1.0), row_height)
    var condition_x: float = _get_condition_track_start(row_data, x, condition_lane_rect)
    var condition_line_x: Dictionary = {}
    var action_x: float = (
        lane_divider_x + float(event_style.lane_divider_width) + float(event_style.action_lane_padding)
        if lane_divider_x > 0.0
        else x
    )
    var action_line_x: Dictionary = {}
    var action_line_reservations: Dictionary = _build_action_line_reservations(row_data, action_lane_rect, font, font_size)
    for span_index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null:
            continue
        var span_lane: String = _resolve_span_lane(span)
        var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
        var span_x: float = x
        var span_y: float = row_top + 3.0
        if span_lane == "action":
            var action_line_index: int = int(metadata.get("line_index", 0))
            span_y = row_top + float(action_line_index) * line_height + 3.0
            if bool(metadata.get("align_right", false)) and action_lane_rect.size.x > 0.0:
                span_x = action_lane_rect.end.x - float(event_style.action_lane_padding)
            else:
                if not action_line_x.has(action_line_index):
                    action_line_x[action_line_index] = action_x
                span_x = float(action_line_x[action_line_index])
        elif lane_divider_x > 0.0:
            var line_index: int = int(metadata.get("line_index", 0))
            if not condition_line_x.has(line_index):
                condition_line_x[line_index] = condition_x
            span_x = float(condition_line_x[line_index])
            span_y = row_top + float(line_index) * line_height + 3.0
        var display_text: String = _editing_buffer if index == _editing_row_index and span_index == _editing_span_index else span.text
        var span_width: float = _measure_span_width(span, display_text, font, font_size)
        if lane_divider_x > 0.0 and span_lane != "action":
            var max_condition_right: float = lane_divider_x - float(event_style.condition_lane_padding)
            span_width = max(min(span_width, max_condition_right - span_x), 10.0)
        elif span_lane == "action" and action_lane_rect.size.x > 0.0:
            var reserved_start: float = float(
                action_line_reservations.get(
                    int(metadata.get("line_index", 0)),
                    action_lane_rect.end.x - float(event_style.action_lane_padding)
                )
            )
            if bool(metadata.get("align_right", false)):
                span_x = max(
                    action_lane_rect.position.x + float(event_style.action_lane_padding),
                    action_lane_rect.end.x - float(event_style.action_lane_padding) - span_width - 2.0
                )
            else:
                span_width = max(min(span_width, reserved_start - max(_get_span_gap(span), EventSheetPalette.SPAN_GAP) - span_x), 1.0)
        else:
            span_width = max(min(span_width, row_right_limit - span_x), 1.0)
        span.rect = Rect2(span_x, span_y, span_width + 2.0, line_height - 6.0)
        # Store absolute X for the next span start on this line.
        var next_span_start_x: float = span.rect.end.x + _get_span_gap(span)
        if span_lane == "action":
            if not bool(metadata.get("align_right", false)):
                action_line_x[int(metadata.get("line_index", 0))] = next_span_start_x
        else:
            condition_line_x[int(metadata.get("line_index", 0))] = next_span_start_x
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
        ace_drag_rect = _build_ace_drag_preview_rect(
            row_data,
            _drag_ace_target_lane,
            _drag_ace_target_ace_index,
            _drag_ace_insert_mode,
            condition_lane_rect,
            action_lane_rect
        )
    var drag_feedback_rect := Rect2()
    if not _drag_feedback_text.is_empty() and _drag_ace_target_row_index == index:
        var feedback_lane_rect: Rect2 = (
            action_lane_rect if _drag_ace_target_lane == "action" else condition_lane_rect
        )
        drag_feedback_rect = _build_drag_feedback_rect(
            ace_drag_rect,
            feedback_lane_rect,
            _drag_feedback_text,
            font,
            font_size
        )
    var layout := {
        "row_rect": row_rect,
        "row_height": row_height,
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
        "ace_drag_error": not _drag_ace_drop_valid and _drag_ace_target_row_index == index,
        "drag_feedback_rect": drag_feedback_rect,
        "drag_feedback_text": _drag_feedback_text if _drag_ace_target_row_index == index else "",
        "drag_feedback_error": _drag_feedback_is_error and _drag_ace_target_row_index == index,
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
    draw_rect(
        Rect2(Vector2.ZERO, Vector2(width, max(size.y / max(_zoom_factor, 0.001), 240.0))),
        EventSheetPalette.BG_0,
        true
    )
    var font: Font = _get_font()
    var font_size: int = _get_font_size()
    var text: String = "No rows. Select an EventSheet resource or use the dock's demo sheet."
    var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
    draw_string(
        font,
        Vector2(16.0, 40.0 + text_size.y),
        text,
        HORIZONTAL_ALIGNMENT_LEFT,
        max(width - 32.0, 1.0),
        font_size,
        EventSheetPalette.TEXT_MUTED
    )

func _update_canvas_min_size() -> void:
    var zoom: float = max(_zoom_factor, 0.001)
    var canvas_width: float = max(_get_scroll_width(), 640.0 * zoom)
    var total_height: float = 0.0
    if not _row_metrics.is_empty():
        var last_metric: Dictionary = _row_metrics[_row_metrics.size() - 1]
        total_height = float(last_metric.get("top", 0.0)) + float(last_metric.get("height", ROW_HEIGHT))
    var target_size: Vector2 = Vector2(
        canvas_width,
        max(total_height * zoom, max(_get_viewport_height(), 240.0))
    )
    custom_minimum_size = target_size
    update_minimum_size()
    if size != target_size:
        set_size(target_size)

func _apply_zoom_delta(delta: float, anchor_position: Vector2) -> void:
    var scroll: ScrollContainer = _get_scroll_container()
    var old_zoom: float = _zoom_factor
    set_zoom_factor(_zoom_factor + delta)
    if scroll == null or is_equal_approx(old_zoom, _zoom_factor):
        return
    if anchor_position.x < 0.0 or anchor_position.y < 0.0:
        return
    var logical_anchor_x: float = (float(scroll.scroll_horizontal) + anchor_position.x) / old_zoom
    var logical_anchor_y: float = (float(scroll.scroll_vertical) + anchor_position.y) / old_zoom
    scroll.scroll_horizontal = max(int(round(logical_anchor_x * _zoom_factor - anchor_position.x)), 0)
    scroll.scroll_vertical = max(int(round(logical_anchor_y * _zoom_factor - anchor_position.y)), 0)

func _to_logical_position(position: Vector2) -> Vector2:
    return position / max(_zoom_factor, 0.001)

func _get_logical_canvas_width() -> float:
    return max(max(size.x, _get_scroll_width()), 640.0) / max(_zoom_factor, 0.001)

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
    var row_index: int = _find_row_index_at_y(position.y)
    if row_index < 0 or row_index >= _flat_rows.size():
        return {}
    var layout: Dictionary = _get_or_build_row_layout(
        row_index,
        _get_logical_canvas_width(),
        _get_font(),
        _get_font_size()
    )
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
    var row_top: float = _get_row_top(row_index)
    var row_height: float = _get_row_height(row_index)
    var relative_y: float = clampf(position.y - row_top, 0.0, row_height)
    var inside_zone_top: float = row_height * DROP_ZONE_INSIDE_TOP
    var inside_zone_bottom: float = row_height * DROP_ZONE_INSIDE_BOTTOM
    var supports_inside_drop: bool = row_data.row_type in [
        EventRowData.RowType.EVENT,
        EventRowData.RowType.GROUP
    ]
    var is_in_inside_zone: bool = (
        relative_y >= inside_zone_top and relative_y <= inside_zone_bottom
    )
    if supports_inside_drop and is_in_inside_zone:
        return "inside"
    return "after" if relative_y > row_height * DROP_ZONE_AFTER_THRESHOLD else "before"

func _resolve_lane_drop_target(row_data: EventRowData, lane: String, position: Vector2) -> Dictionary:
    var target_kind: String = "action" if lane == "action" else "condition"
    var ace_span_indices: Array[int] = _get_lane_ace_span_indices(row_data, target_kind)
    if ace_span_indices.is_empty():
        return {"ace_index": -1, "insert_mode": "append"}
    for span_index in ace_span_indices:
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null:
            continue
        var ace_index: int = int((span.metadata as Dictionary).get("ace_index", -1))
        if position.x <= span.rect.get_center().x:
            return {"ace_index": ace_index, "insert_mode": "before"}
    var last_span: SemanticSpan = row_data.spans[ace_span_indices[ace_span_indices.size() - 1]]
    var last_ace_index: int = int((last_span.metadata as Dictionary).get("ace_index", -1))
    return {"ace_index": last_ace_index, "insert_mode": "after"}

func _validate_ace_drag_target(row_data: EventRowData, lane: String) -> Dictionary:
    if row_data == null or lane != "condition":
        return {"valid": true}
    var target_event: EventRow = row_data.source_resource as EventRow
    if target_event == null:
        return {"valid": true}
    var trigger_entry_count: int = 0
    var excluded_resources: Array = []
    for entry in _drag_ace_entries:
        if not _entry_is_trigger_like(entry):
            continue
        trigger_entry_count += 1
        if not _drag_ace_copy_mode:
            var ace_resource: Resource = entry.get("ace_resource", null) as Resource
            if ace_resource != null:
                excluded_resources.append(ace_resource)
    if trigger_entry_count <= 0:
        return {"valid": true}
    if trigger_entry_count > 1:
        return {
            "valid": false,
            "message": "Events can only have one trigger."
        }
    if _event_has_trigger_like(target_event, excluded_resources):
        return {
            "valid": false,
            "message": "This event already has a trigger."
        }
    return {"valid": true}

func _rebuild_row_metrics() -> void:
    _row_metrics.clear()
    var top: float = 0.0
    for index in range(_flat_rows.size()):
        var height: float = _resolve_row_height(_row_at(index))
        _row_metrics.append({"top": top, "height": height})
        top += height

func _resolve_row_height(row_data: EventRowData) -> float:
    if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
        return float(ROW_HEIGHT)
    var max_line_index: int = 0
    for span in row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        max_line_index = maxi(max_line_index, int(metadata.get("line_index", 0)))
    return float((max_line_index + 1) * _get_event_line_height(_get_font_size()))

func _get_row_top(index: int) -> float:
    if index < 0 or index >= _row_metrics.size():
        return float(index * ROW_HEIGHT)
    return float(_row_metrics[index].get("top", float(index * ROW_HEIGHT)))

func _get_row_height(index: int) -> float:
    if index < 0 or index >= _row_metrics.size():
        return float(ROW_HEIGHT)
    return float(_row_metrics[index].get("height", ROW_HEIGHT))

func _find_row_index_at_y(y: float) -> int:
    if _row_metrics.is_empty():
        return -1
    for index in range(_row_metrics.size()):
        var top: float = float(_row_metrics[index].get("top", 0.0))
        var height: float = float(_row_metrics[index].get("height", ROW_HEIGHT))
        if y >= top and y < top + height:
            return index
    return -1

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
        var matching_entries: Array = []
        for entry in selected_entries:
            if str(entry.get("kind", "")) == kind:
                matching_entries.append(entry)
        if not matching_entries.is_empty():
            for entry in matching_entries:
                if (
                    entry.get("row_uid", "") == row_data.row_uid
                    and int(entry.get("ace_index", -1)) == ace_index
                ):
                    return matching_entries
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
        "trigger":
            return event_row.trigger
        "condition":
            if ace_index < event_row.conditions.size():
                return event_row.conditions[ace_index]
        "action":
            if ace_index < event_row.actions.size() and event_row.actions[ace_index] is Resource:
                return event_row.actions[ace_index]
    return null

func _find_condition_span_index(row_data: EventRowData, ace_index: int) -> int:
    return _find_ace_span_index(row_data, "condition", ace_index)

func _get_lane_ace_span_indices(row_data: EventRowData, kind: String) -> Array[int]:
    var span_indices: Array[int] = []
    if row_data == null:
        return span_indices
    for span_index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        if str(metadata.get("kind", "")) != kind:
            continue
        if int(metadata.get("ace_index", -1)) < 0:
            continue
        span_indices.append(span_index)
    return span_indices

func _build_ace_drag_preview_rect(
    row_data: EventRowData,
    lane: String,
    ace_index: int,
    insert_mode: String,
    condition_lane_rect: Rect2,
    action_lane_rect: Rect2
) -> Rect2:
    var lane_rect: Rect2 = action_lane_rect if lane == "action" else condition_lane_rect
    if lane_rect.size == Vector2.ZERO:
        return Rect2()
    var preview_height: float = max(min(_get_event_line_height(_get_font_size()) - 8.0, lane_rect.size.y - 8.0), 10.0)
    var preview_y: float = lane_rect.position.y + 4.0
    var ace_span_kind: String = "action" if lane == "action" else "condition"
    var ace_span_indices: Array[int] = _get_lane_ace_span_indices(row_data, ace_span_kind)
    if ace_index >= 0:
        var target_span_index: int = _find_ace_span_index(row_data, ace_span_kind, ace_index)
        if target_span_index >= 0 and target_span_index < row_data.spans.size():
            var target_span: SemanticSpan = row_data.spans[target_span_index]
            var preview_x: float = (
                target_span.rect.end.x + (_get_span_gap(target_span) * 0.5)
                if insert_mode == "after"
                else target_span.rect.position.x - (_get_span_gap(target_span) * 0.5)
            )
            preview_x = clampf(preview_x, lane_rect.position.x + 4.0, lane_rect.end.x - 4.0)
            preview_y = target_span.rect.position.y + 2.0
            preview_height = max(target_span.rect.size.y - 4.0, 10.0)
            return Rect2(preview_x - 1.5, preview_y, 3.0, preview_height)
    if not ace_span_indices.is_empty():
        var edge_span: SemanticSpan = row_data.spans[ace_span_indices[ace_span_indices.size() - 1]]
        var edge_preview_x: float = clampf(
            edge_span.rect.end.x + (_get_span_gap(edge_span) * 0.5),
            lane_rect.position.x + 4.0,
            lane_rect.end.x - 4.0
        )
        return Rect2(edge_preview_x - 1.5, edge_span.rect.position.y + 2.0, 3.0, max(edge_span.rect.size.y - 4.0, 10.0))
    if lane == "condition":
        var trigger_span_index: int = _find_ace_span_index(row_data, "trigger", 0)
        if trigger_span_index >= 0 and trigger_span_index < row_data.spans.size():
            var trigger_span: SemanticSpan = row_data.spans[trigger_span_index]
            var trigger_preview_x: float = clampf(
                trigger_span.rect.end.x + (_get_span_gap(trigger_span) * 0.5),
                lane_rect.position.x + 4.0,
                lane_rect.end.x - 4.0
            )
            return Rect2(trigger_preview_x - 1.5, trigger_span.rect.position.y + 2.0, 3.0, max(trigger_span.rect.size.y - 4.0, 10.0))
    var empty_preview_x: float = (
        lane_rect.end.x - float(_get_event_style().action_lane_padding)
        if lane == "action"
        else lane_rect.position.x + float(_get_event_style().condition_lane_padding)
    )
    empty_preview_x = clampf(empty_preview_x, lane_rect.position.x + 4.0, lane_rect.end.x - 4.0)
    return Rect2(empty_preview_x - 1.5, preview_y, 3.0, preview_height)

func _build_drag_feedback_rect(
    preview_rect: Rect2,
    lane_rect: Rect2,
    message: String,
    font: Font,
    font_size: int
) -> Rect2:
    if lane_rect.size == Vector2.ZERO or message.is_empty():
        return Rect2()
    var text_size: Vector2 = font.get_string_size(
        message,
        HORIZONTAL_ALIGNMENT_LEFT,
        -1.0,
        max(font_size - 1, 10)
    )
    var bubble_size: Vector2 = Vector2(text_size.x + 16.0, text_size.y + 10.0)
    var bubble_x: float = preview_rect.position.x if preview_rect.size != Vector2.ZERO else lane_rect.position.x + 8.0
    bubble_x = clampf(
        bubble_x,
        lane_rect.position.x + 6.0,
        max(lane_rect.end.x - bubble_size.x - 6.0, lane_rect.position.x + 6.0)
    )
    var bubble_y: float = (
        preview_rect.position.y - bubble_size.y - 6.0
        if preview_rect.size != Vector2.ZERO
        else lane_rect.position.y + 6.0
    )
    bubble_y = max(bubble_y, lane_rect.position.y + 4.0)
    return Rect2(Vector2(bubble_x, bubble_y), bubble_size)

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

func _find_inline_trigger_condition_index(event_row: EventRow) -> int:
    if event_row == null or event_row.trigger != null or not event_row.trigger_id.is_empty():
        return -1
    for condition_index in range(event_row.conditions.size()):
        var condition: ACECondition = event_row.conditions[condition_index]
        if _is_trigger_condition(condition):
            return condition_index
    return -1

func _is_trigger_condition(condition: ACECondition) -> bool:
    if condition == null:
        return false
    var generated_definition: ACEDefinition = _find_definition(condition.provider_id, condition.ace_id)
    if generated_definition != null:
        return generated_definition.ace_type == ACEDefinition.ACEType.TRIGGER
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
    return descriptor != null and descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER

func _entry_is_trigger_like(entry: Dictionary) -> bool:
    if str(entry.get("kind", "")) == "trigger":
        return true
    var ace_resource: Resource = entry.get("ace_resource", null) as Resource
    return ace_resource is ACECondition and _is_trigger_condition(ace_resource as ACECondition)

func _event_has_trigger_like(event_row: EventRow, excluded_resources: Array = []) -> bool:
    if event_row == null:
        return false
    if event_row.trigger != null and not excluded_resources.has(event_row.trigger):
        return true
    if not event_row.trigger_id.is_empty():
        return true
    for condition in event_row.conditions:
        if not (condition is ACECondition):
            continue
        if excluded_resources.has(condition):
            continue
        if _is_trigger_condition(condition as ACECondition):
            return true
    return false

func _format_action_descriptor(action: ACEAction) -> String:
    var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
    var generated_definition: ACEDefinition = _find_definition(action.provider_id, action.ace_id)
    if generated_definition != null:
        return generated_definition.format_display(params_dict)
    var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
    if descriptor == null:
        return action.ace_id
    return descriptor.format_display(params_dict)

func _format_variable_value(value: Variant) -> String:
    if value == null:
        return "null"
    if value is String:
        return '"%s"' % str(value)
    return str(value)

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
