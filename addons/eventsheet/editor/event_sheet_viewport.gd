@tool
class_name EventSheetViewport
extends Control

signal selection_changed(row_data: EventRowData)
signal row_drop_requested(source_row: EventRowData, target_row: EventRowData, drop_mode: String, copy_mode: bool)
signal rows_drop_requested(source_rows: Array, target_row: EventRowData, drop_mode: String, copy_mode: bool)
signal ace_preview_requested(source_label: String, definitions: Array[ACEDefinition])
signal asset_dropped(target_event: Resource, asset_paths: PackedStringArray)
signal ace_picker_requested(row_data: EventRowData, lane: String)
signal span_edit_requested(row_data: EventRowData, edit_kind: String, old_value: String, new_value: String)
signal ace_edit_requested(row_data: EventRowData, span_index: int, metadata: Dictionary)
## C3's fastest gesture: double-click a highlighted VALUE inside an ACE to edit just
## that parameter (no full dialog). Emitted with the resolved ACE + param id.
signal param_value_edit_requested(ace: Resource, param_id: String, current_text: String)
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
signal variable_edit_requested(row_data: EventRowData, metadata: Dictionary)
## Emitted when a comment needs the dialog editor (multiline comment rows and action-cell
## comments; single-line comment rows keep fast inline editing).
signal comment_edit_requested(comment_row: Resource)

## Emitted when a group header is activated (double-click / slow-click / Enter); the dock opens a
## popup to edit the group's name + optional description instead of an inline title field.
signal group_edit_requested(group: EventGroup)
## Emitted when a pick-filter row is double-clicked (event + index into pick_filters).
signal pick_filter_edit_requested(event_row: Resource, pick_index: int)
## Emitted when an enum row is double-clicked.
signal enum_edit_requested(enum_row: Resource)
## Emitted when a signal row is double-clicked.
signal signal_edit_requested(signal_row: Resource)
## Emitted when a match action cell is double-clicked.
signal match_edit_requested(match_row: Resource)
## Emitted on Ctrl+/ — the dock toggles the selected rows' enabled state (undoable).
signal row_disable_toggle_requested()
## Emitted on Alt+Up/Down — the dock moves the selected row (direction -1 = up).
signal row_move_requested(direction: int)
## Emitted on Ctrl+F — the dock shows the find bar.
signal find_requested()
## Emitted on F3 / Shift+F3 — the dock steps through find matches.
signal find_step_requested(direction: int)
## Emitted when the user finishes dragging the conditions/actions lane divider.
signal lane_ratio_changed(ratio: float)
## Emitted when a footer "Add event…" row is clicked. owner_resource is the EventGroup the
## event should be appended into, or the EventSheetResource for the sheet-end footer.
signal add_event_requested(owner_resource: Resource)
## Emitted when a GDScript block is double-clicked for editing. in_flow is true for blocks
## living inside an event's actions (statements), false for class-level tree blocks.
signal raw_code_edit_requested(raw_row: Resource, in_flow: bool)

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
const MIN_BOX_SELECT_DISTANCE_SQ := MIN_BOX_SELECT_DISTANCE * MIN_BOX_SELECT_DISTANCE
const COMMENT_DEFAULT_LINE_INDEX := 1
const MIN_SPAN_WIDTH := 10.0
## Sheets with at most this many rows build all event spans up front (matching the
## original non-virtualized behavior exactly). Larger sheets keep spans lazy — built
## on demand during layout/hit/selection — so they load fast regardless of size.
const EAGER_SPAN_LIMIT := 1500

var _renderer: EventRowRenderer = EventRowRenderer.new()
var _layout_cache: RowLayoutCache = RowLayoutCache.new()
var _selection_helper: ViewportSelectionHelper = ViewportSelectionHelper.new()
var _hit_test_helper: ViewportHitTestHelper = ViewportHitTestHelper.new()
var _drag_preview_helper: ViewportDragPreviewHelper = ViewportDragPreviewHelper.new()
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
## Rows that landed in `_selected_row_uids` purely because a span of theirs was Ctrl-toggled
## on (not via a whole-row select). Tracks selection provenance so that toggling the last span
## of such a row back off also releases the row from the row-selection set — otherwise the row
## stays phantom-selected (highlighted, drag/delete/edit-eligible) after the user deselects it.
var _span_only_row_uids: Dictionary = {}
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
# Session bookmarks (navigation aid; not persisted): row_uid -> true. Ctrl+M / F4.
var _bookmark_rows: Dictionary = {}
var _row_disabled_state: Dictionary = {}
# Multi-view: panes over the same sheet share the three dictionaries above through this
# state object (adopted by reference). Null until a second view asks for it.
var _shared_state: EventSheetViewState = null
# Companion panes (split view) are read/navigate-only: inline editing is disabled and the
# dock connects no edit signals to them. Selection, scroll, zoom, folds all work.
var companion_mode: bool = false
var _focused_lane: String = "condition"
var _selection_anchor_index: int = -1
var _external_span_edit_handler_enabled: bool = false
var _zoom_factor: float = 1.0
var _layout_style_signature: String = ""
var _dragging_lane_divider: bool = false
const LANE_DIVIDER_GRAB_TOLERANCE := 5.0
## C3-style trailing "Add event…" footer rows (sheet-end and per-group). On by default;
## settable so headless tests can assert raw row counts/indices without the affordance
## shifting them, and so the dock can offer a "hide add-event rows" declutter option.
var show_add_event_footers: bool = true
## C3-style drag ghost: a faint label of the dragged content following the cursor.
var _drag_ghost_label: String = ""
var _drag_pointer_position: Vector2 = Vector2.ZERO
## Vertical gap inserted before an event/group that starts a new sibling block (indent <=
## previous), so sub-events read as tightly grouped under their parent.
const EVENT_BLOCK_GAP := 7.0
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

## The shared per-sheet view state (created on demand around this view's dictionaries).
func get_shared_state() -> EventSheetViewState:
    if _shared_state == null:
        _shared_state = EventSheetViewState.new()
        _shared_state.breakpoint_rows = _breakpoint_rows
        _shared_state.bookmark_rows = _bookmark_rows
        _shared_state.row_disabled_state = _row_disabled_state
    return _shared_state

## Adopts another view's shared state: the dictionaries are taken BY REFERENCE, so a
## breakpoint toggled in any pane is instantly true in all of them.
func adopt_shared_state(state: EventSheetViewState) -> void:
    if state == null:
        return
    _shared_state = state
    _breakpoint_rows = state.breakpoint_rows
    _bookmark_rows = state.bookmark_rows
    _row_disabled_state = state.row_disabled_state

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
    _ace_icon_cache.clear()  # icons derive from definitions; a new registry invalidates them
    _refresh_rows()

func get_ace_registry() -> EventSheetACERegistry:
    return _ace_registry

func set_debug_overlay_states(states: Dictionary) -> void:
    _debug_rows = states.duplicate(true)
    _refresh_rows()

func get_total_row_count() -> int:
    return _flat_rows.size()

## Returns the x of the condition/action lane divider for a canvas of the given logical
## width. Shared by row layout and the pinned column header so they stay aligned.
func get_lane_divider_x(width: float) -> float:
    var event_style: EventSheetEventStyle = _get_event_style()
    var content_left: float = EventSheetPalette.GUTTER_WIDTH
    var content_width: float = max(width - content_left, 120.0)
    return content_left + max(
        float(event_style.minimum_conditions_lane_width),
        floor(content_width * event_style.condition_lane_ratio)
    )

## Logical (unzoomed) width of the sheet canvas.
func get_canvas_logical_width() -> float:
    return _get_logical_canvas_width()

## Current horizontal scroll offset of the hosting scroll container.
func get_horizontal_scroll() -> int:
    var scroll: ScrollContainer = _get_scroll_container()
    return scroll.scroll_horizontal if scroll != null else 0

## Active event style tokens (for surfaces outside the renderer, e.g. the column header).
func get_event_style() -> EventSheetEventStyle:
    return _get_event_style()

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

## The ACE resource backing the selected span (condition/trigger/action), or null —
## drives the Inspector's per-row "Selected ACE" section.
func get_selected_ace_resource() -> Resource:
    var context: Dictionary = get_selected_context()
    var metadata: Dictionary = context.get("span_metadata", {})
    var row_resource: Resource = context.get("source_resource", null)
    if not (row_resource is EventRow):
        return null
    match str(metadata.get("kind", "")):
        "condition":
            return _resolve_ace_resource(row_resource, "condition", int(metadata.get("ace_index", -1)))
        "action":
            var action_resource: Resource = _resolve_ace_resource(row_resource, "action", int(metadata.get("ace_index", -1)))
            return action_resource if action_resource is ACEAction else null
        "trigger":
            return (row_resource as EventRow).trigger
    return null

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
    # Default-themed sheets adopt the running editor's colors so they look native to Godot
    # (no-op outside the editor, keeping tests deterministic).
    return EventSheetGodotTheme.adapt_to_editor(fallback_style)

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

func _has_event_rows() -> bool:
    for entry in _flat_rows:
        var row_data: EventRowData = entry.get("row")
        if row_data != null and row_data.row_type == EventRowData.RowType.EVENT:
            return true
    return false

## True when a logical-space point sits over the draggable conditions/actions lane divider.
func _is_near_lane_divider(local_position: Vector2) -> bool:
    if not _has_event_rows():
        return false
    return absf(local_position.x - get_lane_divider_x(_get_logical_canvas_width())) <= LANE_DIVIDER_GRAB_TOLERANCE

## Live-resizes the conditions/actions split from a logical X (during a divider drag).
func _set_lane_ratio_from_x(local_x: float) -> void:
    var content_left: float = EventSheetPalette.GUTTER_WIDTH
    var content_width: float = max(_get_logical_canvas_width() - content_left, 120.0)
    _get_event_style().condition_lane_ratio = clampf((local_x - content_left) / content_width, 0.2, 0.8)
    _update_layout_style_signature(_get_font_size())
    _layout_cache.clear()
    queue_redraw()

## Swaps the active editor style and repaints without rebuilding the row list (cheap). Used
## when the dock promotes a default-themed sheet to a concrete style after a divider drag.
func apply_editor_style(style: EventSheetEditorStyle) -> void:
    if style == null:
        return
    style.ensure_defaults()
    _editor_style = style
    _update_layout_style_signature(_get_font_size())
    _layout_cache.clear()
    queue_redraw()

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
    return "%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [
        int(round(_get_event_line_height(font_size))),
        event_style.minimum_conditions_lane_width,
        event_style.condition_lane_padding,
        event_style.condition_badge_column_width,
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

## Selects (and scrolls to) the row backed by the given resource. Used by reverse
## provenance — clicking generated code in the GDScript panel selects its sheet row.
## Returns false when the resource has no row of its own (e.g. an ACE resource inside an
## event); callers fall back to the enclosing row's resource.
func select_resource(resource: Resource) -> bool:
    if resource == null:
        return false
    for index in range(_flat_rows.size()):
        var row_data: EventRowData = _flat_rows[index].get("row")
        if row_data != null and row_data.source_resource == resource:
            _select_row(index, -1)
            ensure_selection_visible()
            queue_redraw()
            return true
    return false

const SLOW_CLICK_MIN_MS := 450   # beyond the OS double-click window
const SLOW_CLICK_MAX_MS := 1600
var _slow_click: Dictionary = {"row": -1, "span": -1, "msec": 0}

## Explorer-style slow double-click: a second single click on the SAME editable span,
## after the double-click window but within the slow window, begins inline editing
## (multiline comments route to their dialog instead). now_msec is injectable for tests.
## Which highlighted value (if any) sits under logical x in a span: [text, occurrence]
## where occurrence counts earlier ranges with IDENTICAL text (disambiguates "0" vs "0").
func _value_text_at(span: SemanticSpan, logical_x: float, font: Font, font_size: int) -> Array:
    var ranges: Array = span.metadata.get("value_ranges", []) if span.metadata is Dictionary else []
    if ranges.is_empty():
        return []
    var origin_x: float = span.rect.position.x
    for range_index in range(ranges.size()):
        var range_entry: Array = ranges[range_index]
        var start: int = int(range_entry[0])
        var length: int = int(range_entry[1])
        var prefix_width: float = font.get_string_size(span.text.substr(0, start), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
        var value_width: float = font.get_string_size(span.text.substr(start, length), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
        if logical_x >= origin_x + prefix_width and logical_x <= origin_x + prefix_width + value_width:
            var value_text: String = span.text.substr(start, length)
            var occurrence: int = 0
            for earlier_index in range(range_index):
                if span.text.substr(int(ranges[earlier_index][0]), int(ranges[earlier_index][1])) == value_text:
                    occurrence += 1
            return [value_text, occurrence]
    return []

## Maps a displayed value back to the param that produced it (params are substituted
## verbatim into display templates, so str(param) == shown text; equal values
## disambiguate by occurrence order). "" when nothing matches.
static func param_id_for_value(ace: Resource, value_text: String, occurrence: int) -> String:
    if ace == null or not (ace.get("params") is Dictionary):
        return ""
    var seen: int = 0
    for param_key: Variant in (ace.get("params") as Dictionary).keys():
        if str((ace.get("params") as Dictionary)[param_key]) == value_text:
            if seen == occurrence:
                return str(param_key)
            seen += 1
    return ""

func _maybe_begin_slow_edit(row_index: int, span_index: int, now_msec: int = -1) -> bool:
    var now: int = now_msec if now_msec >= 0 else Time.get_ticks_msec()
    var was_same: bool = int(_slow_click.get("row", -1)) == row_index and int(_slow_click.get("span", -1)) == span_index
    var elapsed: int = now - int(_slow_click.get("msec", 0))
    _slow_click = {"row": row_index, "span": span_index, "msec": now}
    if not was_same or elapsed < SLOW_CLICK_MIN_MS or elapsed > SLOW_CLICK_MAX_MS:
        return false
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null or span_index < 0 or span_index >= row_data.spans.size():
        return false
    var metadata: Dictionary = row_data.spans[span_index].metadata if row_data.spans[span_index].metadata is Dictionary else {}
    if not bool(metadata.get("editable", false)):
        return false
    if row_data.source_resource is CommentRow and (row_data.source_resource as CommentRow).text.contains("
"):
        comment_edit_requested.emit(row_data.source_resource)
        return true
    _begin_edit(row_index, span_index)
    return true

## Tree-wide search (the find bar's data source): walks the FULL row tree — including
## rows hidden inside folded groups — and returns matching source resources in order.
func search_all(query: String) -> Array[Resource]:
    var matches: Array[Resource] = []
    var needle: String = query.strip_edges().to_lower()
    if needle.is_empty():
        return matches
    for root in _root_rows:
        _search_row_tree(root, needle, matches)
    return matches

func _search_row_tree(row_data: EventRowData, needle: String, into: Array[Resource]) -> void:
    if row_data == null:
        return
    if row_data.row_type == EventRowData.RowType.EVENT and row_data.spans.is_empty():
        _ensure_event_spans(row_data)
    var haystack: String = ""
    for span: SemanticSpan in row_data.spans:
        haystack += span.text + " "
    if row_data.source_resource is RawCodeRow:
        haystack += (row_data.source_resource as RawCodeRow).code
    if haystack.to_lower().contains(needle) and row_data.source_resource != null:
        into.append(row_data.source_resource)
    for child in row_data.children:
        _search_row_tree(child, needle, into)

## Selects and scrolls to the row backing `resource`, unfolding any folded ancestor
## groups so find can land inside collapsed regions. Returns false when not found.
func reveal_resource(resource: Resource) -> bool:
    if resource == null:
        return false
    for attempt in range(2):
        for index in range(_flat_rows.size()):
            var row_data: EventRowData = _row_at(index)
            if row_data != null and row_data.source_resource == resource:
                _select_row(index, -1)
                ensure_selection_visible()
                queue_redraw()
                return true
        # Hidden inside folded groups: unfold the ancestors on the path and re-flatten.
        var unfolded: bool = false
        for root in _root_rows:
            if _unfold_path_to(root, resource):
                unfolded = true
        if not unfolded:
            return false
        _refresh_rows()
    return false

func _unfold_path_to(row_data: EventRowData, resource: Resource) -> bool:
    if row_data == null:
        return false
    if row_data.source_resource == resource:
        return true
    for child in row_data.children:
        if _unfold_path_to(child, resource):
            if row_data.folded:
                row_data.folded = false
                _fold_state[row_data.row_uid] = false
            return true
    return false

## Flat indices of rows whose visible text (or GDScript block code) contains the query,
## case-insensitively — the find bar's data source.
func search_rows(query: String) -> Array[int]:
    var matches: Array[int] = []
    var needle: String = query.strip_edges().to_lower()
    if needle.is_empty():
        return matches
    for index in range(_flat_rows.size()):
        var row_data: EventRowData = _row_at(index)
        if row_data == null:
            continue
        if row_data.row_type == EventRowData.RowType.EVENT and row_data.spans.is_empty():
            _ensure_event_spans(row_data)
        var haystack: String = ""
        for span: SemanticSpan in row_data.spans:
            haystack += span.text + " "
        if row_data.source_resource is RawCodeRow:
            haystack += (row_data.source_resource as RawCodeRow).code
        if haystack.to_lower().contains(needle):
            matches.append(index)
    return matches

## Toggles a session bookmark on the selected row (Ctrl+M; F4 / Shift+F4 navigate).
func toggle_bookmark_selected() -> void:
    var row_data: EventRowData = _row_at(_selected_row_index)
    if row_data == null:
        return
    if _bookmark_rows.has(row_data.row_uid):
        _bookmark_rows.erase(row_data.row_uid)
    else:
        _bookmark_rows[row_data.row_uid] = true
    row_data.bookmark_enabled = _bookmark_rows.has(row_data.row_uid)
    queue_redraw()

## Selects the next (direction >= 0) or previous bookmarked row, wrapping around.
## Returns false when nothing is bookmarked.
func jump_to_bookmark(direction: int = 1) -> bool:
    var marked: Array[int] = []
    for index in range(_flat_rows.size()):
        var marked_row: EventRowData = _row_at(index)
        if marked_row != null and _bookmark_rows.has(marked_row.row_uid):
            marked.append(index)
    if marked.is_empty():
        return false
    var target: int = -1
    if direction >= 0:
        for index: int in marked:
            if index > _selected_row_index:
                target = index
                break
        if target == -1:
            target = marked[0]
    else:
        for index: int in marked:
            if index < _selected_row_index:
                target = index
        if target == -1:
            target = marked[marked.size() - 1]
    _select_row(target, -1)
    ensure_selection_visible()
    queue_redraw()
    return true

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
    var background_color: Color = _get_event_style().sheet_background_color
    _layout_cache.reset(width)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(zoom, zoom))
    draw_rect(
        Rect2(Vector2.ZERO, Vector2(width, max(size.y / zoom, 240.0))),
        background_color,
        true
    )
    if _is_sheet_visually_empty():
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
        _renderer.draw_row(self, layout, row_data, font, font_size, _editor_style)
        var row_rect: Rect2 = layout.get("rect", Rect2())
        _draw_live_value_chip(row_data, row_rect.position.y, row_rect.size.y, font, font_size)
        # Drag-handle affordance: subtle grip dots on the hovered row's left edge so
        # reordering is discoverable without being told.
        if index == _hovered_row_index and not _flat_rows.is_empty():
            var grip_color: Color = Color(1.0, 1.0, 1.0, 0.28)
            for dot_row in range(3):
                draw_circle(Vector2(row_rect.position.x + 5.0, row_rect.position.y + row_rect.size.y * 0.5 + (dot_row - 1) * 5.0), 1.4, grip_color)
    _draw_box_selection_overlay()
    _draw_drag_ghost(font, font_size)

## C3-style drag ghost: a faint (~0.66 opacity) label of the dragged content following the
## cursor while an ACE/row drag has an active target (i.e. after actual mouse motion).
func _draw_drag_ghost(font: Font, font_size: int) -> void:
    if _drag_ghost_label.is_empty():
        return
    var ace_dragging: bool = not _drag_ace_entries.is_empty() and _drag_ace_target_row_index >= 0
    var row_dragging: bool = _drag_row_index >= 0 and _drag_target_index >= 0
    if not ace_dragging and not row_dragging:
        return
    var ghost_font_size: int = maxi(font_size - 1, 10)
    var text_width: float = font.get_string_size(_drag_ghost_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ghost_font_size).x
    var ghost_rect := Rect2(
        _drag_pointer_position + Vector2(14.0, 10.0),
        Vector2(min(text_width, 280.0) + 14.0, font.get_height(ghost_font_size) + 6.0)
    )
    draw_rect(ghost_rect, Color(0.12, 0.14, 0.18, 0.62), true)
    draw_rect(ghost_rect, Color(1.0, 1.0, 1.0, 0.18), false, 1.0)
    draw_string(
        font,
        Vector2(ghost_rect.position.x + 7.0, ghost_rect.position.y + 3.0 + font.get_ascent(ghost_font_size)),
        _drag_ghost_label,
        HORIZONTAL_ALIGNMENT_LEFT,
        ghost_rect.size.x - 14.0,
        ghost_font_size,
        Color(1.0, 1.0, 1.0, 0.66)
    )

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
    if _dragging_lane_divider:
        _set_lane_ratio_from_x(local_position.x)
        return
    if _box_select_active:
        _box_select_current = local_position
        queue_redraw()
        return
    var hit: Dictionary = _hit_test(local_position)
    _set_hover_state(int(hit.get("row_index", -1)), int(hit.get("span_index", -1)))
    # Show a horizontal-resize cursor over the draggable lane divider.
    mouse_default_cursor_shape = Control.CURSOR_HSIZE if _is_near_lane_divider(local_position) else Control.CURSOR_ARROW
    _drag_pointer_position = local_position
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
        # Footer "Add event…" rows are pure affordances — no context menu / selection.
        if _row_is_add_event_footer(_row_at(row_index)):
            accept_event()
            return
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
        if _is_near_lane_divider(local_position):
            _dragging_lane_divider = true
            accept_event()
            return
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
        if row_data != null and str(metadata.get("kind", "")) == "add_event":
            add_event_requested.emit(metadata.get("add_event_owner", null))
            accept_event()
            return
        if bool(hit.get("fold", false)):
            _select_from_click(row_index, span_index, false)
            _toggle_row_fold(row_index)
            return
        if event.shift_pressed and _selection_anchor_index >= 0:
            # Shift+click extends a whole-row range from the anchor to the clicked row.
            _select_range(row_index)
            accept_event()
            return
        _select_from_click(row_index, span_index, event.ctrl_pressed or event.meta_pressed)
        if event.double_click:
            # In-flow GDScript blocks (actions) open the code dialog, not the ACE editor.
            var double_click_meta: Dictionary = hit.get("span_metadata", {})
            if bool(double_click_meta.get("match_action", false)) and row_data != null and row_data.source_resource is EventRow:
                var match_target: Resource = _resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
                if match_target is MatchRow:
                    match_edit_requested.emit(match_target)
                    accept_event()
                    return
            if bool(double_click_meta.get("raw_action", false)) and row_data != null and row_data.source_resource is EventRow:
                var inline_raw: Resource = _resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
                if inline_raw is RawCodeRow:
                    raw_code_edit_requested.emit(inline_raw, true)
                    accept_event()
                    return
            # Action-cell comments open the comment dialog (text + color).
            if bool(double_click_meta.get("action_comment", false)) and row_data != null and row_data.source_resource is EventRow:
                var inline_comment: Resource = _resolve_ace_resource(row_data.source_resource, "action", int(double_click_meta.get("ace_index", -1)))
                if inline_comment is CommentRow:
                    comment_edit_requested.emit(inline_comment)
                    accept_event()
                    return
            # Enum rows open the enum dialog.
            if row_data != null and row_data.source_resource is EnumRow:
                enum_edit_requested.emit(row_data.source_resource)
                accept_event()
                return
            # Signal rows open the signal dialog.
            if row_data != null and row_data.source_resource is SignalRow:
                signal_edit_requested.emit(row_data.source_resource)
                accept_event()
                return
            # Pick-filter rows open the pick-filter dialog.
            if str(double_click_meta.get("kind", "")) == "pick_filter" and row_data != null and row_data.source_resource is EventRow:
                pick_filter_edit_requested.emit(row_data.source_resource, int(double_click_meta.get("pick_index", -1)))
                accept_event()
                return
            # Single-param inline editing: a double-click landing on a highlighted VALUE
            # within an ACE edits just that parameter.
            var value_kind: String = str(double_click_meta.get("kind", ""))
            if value_kind in ["condition", "trigger", "action"] and row_data != null and row_data.source_resource is EventRow and span_index >= 0 and span_index < row_data.spans.size():
                var value_hit: Array = _value_text_at(row_data.spans[span_index], local_position.x, _get_font(), _get_font_size())
                if not value_hit.is_empty():
                    var clicked_lane: String = "action" if value_kind == "action" else "condition"
                    var clicked_ace: Resource = row_data.source_resource.trigger if value_kind == "trigger" else _resolve_ace_resource(row_data.source_resource, clicked_lane, int(double_click_meta.get("ace_index", -1)))
                    if clicked_ace != null:
                        var clicked_param: String = param_id_for_value(clicked_ace, str(value_hit[0]), int(value_hit[1]))
                        if not clicked_param.is_empty():
                            param_value_edit_requested.emit(clicked_ace, clicked_param, str(value_hit[0]))
                            accept_event()
                            return
            # Multiline comment rows edit in the dialog (per-line inline editing would
            # replace the whole text with one line — data loss).
            if row_data != null and row_data.source_resource is CommentRow and (row_data.source_resource as CommentRow).text.contains("\n"):
                comment_edit_requested.emit(row_data.source_resource)
                accept_event()
                return
            if _maybe_request_ace_edit(hit, row_index):
                accept_event()
                return
            if _maybe_request_variable_edit(hit, row_index):
                accept_event()
                return
            if row_data != null and row_data.source_resource is RawCodeRow:
                raw_code_edit_requested.emit(row_data.source_resource, false)
                accept_event()
                return
            _begin_edit(row_index, span_index)
            accept_event()
            return
        if _maybe_begin_slow_edit(row_index, span_index):
            accept_event()
            return
        _drag_ace_copy_mode = event.ctrl_pressed or event.meta_pressed
        _drag_row_copy_mode = event.ctrl_pressed or event.meta_pressed
        if _maybe_begin_ace_drag(hit, row_index):
            # Accept so this control keeps receiving motion/release for the drag.
            accept_event()
            return
        _begin_row_drag(row_index)
        accept_event()
        return
    if _dragging_lane_divider:
        _dragging_lane_divider = false
        lane_ratio_changed.emit(_get_event_style().condition_lane_ratio)
        accept_event()
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
    if selection_rect.size.length_squared() <= MIN_BOX_SELECT_DISTANCE_SQ:
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
    if selection_rect.size.length_squared() <= MIN_BOX_SELECT_DISTANCE_SQ:
        return
    var selection_fill: Color = _get_event_style().selection_fill_color
    var selection_outline: Color = selection_fill.lightened(0.22)
    selection_outline.a = max(selection_fill.a, 0.9)
    draw_rect(selection_rect, selection_fill, true)
    draw_rect(selection_rect, selection_outline, false, 1.0)

func _apply_box_selection(selection_rect: Rect2, additive: bool) -> void:
    if not additive:
        _selected_row_uids.clear()
        _selected_span_indices.clear()
        _span_only_row_uids.clear()
        _selected_row_index = -1
        _selected_span_index = -1
    var selected_any: bool = false
    var sel_top: float = minf(selection_rect.position.y, selection_rect.end.y)
    var sel_bottom: float = maxf(selection_rect.position.y, selection_rect.end.y)
    for row_index in range(_flat_rows.size()):
        var row_data: EventRowData = _row_at(row_index)
        if row_data == null:
            continue
        # Footer "Add event…" affordances are never part of a selection.
        if _row_is_add_event_footer(row_data):
            continue
        # Skip rows whose vertical extent does not overlap the selection box using the
        # cheap precomputed metrics, so a box drag never builds layout/spans for the
        # whole sheet (only for rows the box actually touches).
        var row_top: float = _get_row_top(row_index)
        if row_top + _get_row_height(row_index) < sel_top or row_top > sel_bottom:
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
        # Box selection selects the whole row, so it is no longer span-only provenance.
        _span_only_row_uids.erase(row_data.row_uid)
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
    _drag_ghost_label = (
        "%d rows" % _drag_row_indices.size()
        if _drag_row_indices.size() > 1
        else _row_ghost_label(_row_at(row_index))
    )

## First meaningful text on a row, used as the drag-ghost label.
func _row_ghost_label(row_data: EventRowData) -> String:
    if row_data == null:
        return "Row"
    for span in row_data.spans:
        if span == null or span.text.strip_edges().is_empty():
            continue
        if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("badge", false)):
            continue
        return span.text
    return "Row"

func _clear_row_drag() -> void:
    _drag_row_index = -1
    _drag_row_indices.clear()
    _drag_target_index = -1
    _drag_target_mode = "before"
    _drag_row_copy_mode = false
    _drag_ghost_label = ""

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
    # Ghost label set after _clear_row_drag(), which resets it.
    if _drag_ace_entries.size() > 1:
        _drag_ghost_label = "%d selected" % _drag_ace_entries.size()
    elif span_index >= 0 and span_index < row_data.spans.size() and row_data.spans[span_index] != null:
        _drag_ghost_label = row_data.spans[span_index].text
    else:
        _drag_ghost_label = kind.capitalize()
    return true

func _clear_ace_drag() -> void:
    _drag_ace_entries.clear()
    _drag_ace_target_row_index = -1
    _drag_ace_target_lane = ""
    _drag_ace_target_ace_index = -1
    _drag_ace_insert_mode = "append"
    _drag_ace_copy_mode = false
    _drag_ace_drop_valid = true
    _drag_ghost_label = ""
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
            # Conditions/actions stack vertically, so before/after is decided by the vertical
            # position over the target cell, not the horizontal one.
            _drag_ace_insert_mode = (
                "after" if position.y >= span_rect.get_center().y else "before"
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
    if (event.keycode == KEY_UP or event.keycode == KEY_DOWN) and event.shift_pressed and not event.alt_pressed:
        # Shift+Arrow grows or shrinks a whole-row range from the selection anchor. From an empty
        # selection it lands on the first row (Shift+Down used to skip past row 0 to row 1).
        if _selected_row_index < 0:
            _select_range(0)
        else:
            _select_range(_selected_row_index + (-1 if event.keycode == KEY_UP else 1))
        ensure_selection_visible()
        accept_event()
    elif event.keycode == KEY_UP and not event.alt_pressed:
        _select_row(_selected_row_index - 1, _selected_span_index)
        ensure_selection_visible()
        accept_event()
    elif event.keycode == KEY_DOWN and not event.alt_pressed:
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
    elif event.keycode == KEY_M and (event.ctrl_pressed or event.meta_pressed):
        toggle_bookmark_selected()
        accept_event()
    elif event.keycode == KEY_F4:
        jump_to_bookmark(-1 if event.shift_pressed else 1)
        accept_event()
    elif event.keycode == KEY_F9:
        # Script-editor convention (Ctrl+B remains as an alias).
        _toggle_breakpoint(_selected_row_index)
        accept_event()
    elif event.keycode == KEY_SLASH and (event.ctrl_pressed or event.meta_pressed):
        # Ctrl+/: the "comment out" of event sheets — toggle the row's enabled state.
        row_disable_toggle_requested.emit()
        accept_event()
    elif event.keycode == KEY_UP and event.alt_pressed:
        row_move_requested.emit(-1)
        accept_event()
    elif event.keycode == KEY_DOWN and event.alt_pressed:
        row_move_requested.emit(1)
        accept_event()
    elif event.keycode == KEY_F and (event.ctrl_pressed or event.meta_pressed):
        find_requested.emit()
        accept_event()
    elif event.keycode == KEY_F3:
        find_step_requested.emit(-1 if event.shift_pressed else 1)
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
    # Small/medium sheets build all spans up front (before metrics) so behavior is
    # byte-identical to the non-virtualized path. Large sheets keep spans lazy.
    if _flat_rows.size() <= EAGER_SPAN_LIMIT:
        for entry in _flat_rows:
            _ensure_event_spans(entry.get("row"))
    _rebuild_row_metrics()
    for index in range(_flat_rows.size()):
        var line_row: EventRowData = _flat_rows[index].get("row")
        if line_row == null:
            continue
        line_row.line_number = index + 1
        if _breakpoint_rows.has(line_row.row_uid):
            line_row.breakpoint_enabled = bool(_breakpoint_rows[line_row.row_uid])
        line_row.bookmark_enabled = _bookmark_rows.has(line_row.row_uid)
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
    # C3-style trailing "Add event…" footer at the end of the sheet.
    if show_add_event_footers:
        root_rows.append(_build_add_event_footer_row(sheet, 0, "+ Add event…"))
    return root_rows

## A clickable footer row that appends a new event into owner_resource (a group or the
## sheet). source_resource stays null on purpose so selection/delete/drag paths (which act on
## the source resource) treat it as inert; the owner travels in span metadata instead.
func _build_add_event_footer_row(owner_resource: Resource, indent: int, label: String) -> EventRowData:
    var row_data := EventRowData.new()
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.SECTION
    row_data.source_resource = null
    row_data.row_uid = "add_event_footer_%d" % (owner_resource.get_instance_id() if owner_resource != null else 0)
    row_data.folded = false
    row_data.spans = [
        _make_span(
            label,
            SemanticSpan.SpanType.COMMENT,
            {
                "kind": "add_event",
                "editable": false,
                "add_event_owner": owner_resource,
                "text_color": Color(EventSheetPalette.TEXT_MUTED.r, EventSheetPalette.TEXT_MUTED.g, EventSheetPalette.TEXT_MUTED.b, 0.8)
            }
        )
    ]
    return row_data

func _row_is_add_event_footer(row_data: EventRowData) -> bool:
    return row_data != null and row_data.row_uid.begins_with("add_event_footer_")

## First Color(...) literal among an ACE's param values (null when none) — drives the
## little color swatch drawn after the condition/action text.
func _first_color_in_params(ace: Resource) -> Variant:
    var params: Variant = ace.get("params")
    if not (params is Dictionary):
        return null
    for key: Variant in (params as Dictionary).keys():
        var value: Variant = (params as Dictionary)[key]
        if value is String and (value as String).strip_edges().begins_with("Color("):
            var parsed: Variant = str_to_var((value as String).strip_edges())
            if parsed is Color:
                return parsed
    return null

# uid (str instance id) -> error message, from set_row_diagnostics(). Re-applied to row_data
# on every rebuild so the marker survives edits/scrolling (the "error → row" deep-link).
var _row_diagnostics: Dictionary = {}
var _first_diagnostic_uid: String = ""
# Live event trace: uid set of events that fired in the latest streamed frame (transient highlight).
var _fired_uids: Dictionary = {}

func _build_row_from_resource(entry: Resource, indent: int) -> EventRowData:
    if entry == null:
        return null
    var row_data: EventRowData = null
    if entry is EventGroup:
        row_data = _build_group_row(entry as EventGroup, indent)
    elif entry is CommentRow:
        row_data = _build_comment_row(entry as CommentRow, indent)
    elif entry is LocalVariable:
        row_data = _build_tree_variable_row(entry as LocalVariable, indent)
    elif entry is RawCodeRow:
        row_data = _build_raw_code_row(entry as RawCodeRow, indent)
    elif entry is EnumRow:
        row_data = _build_enum_row(entry as EnumRow, indent)
    elif entry is SignalRow:
        row_data = _build_signal_row(entry as SignalRow, indent)
    elif entry is EventRow:
        row_data = _build_event_row(entry as EventRow, indent)
    if row_data != null and not _row_diagnostics.is_empty():
        row_data.error_message = str(_row_diagnostics.get(str(entry.get_instance_id()), ""))
    if row_data != null and not _fired_uids.is_empty() and entry is EventRow:
        row_data.firing = _fired_uids.has((entry as EventRow).event_uid)
    return row_data

## Paints per-row error markers from EventSheetDiagnostics (each: {uid, message, suggestion}).
## Returns the number of distinct flagged rows; re-applied on every rebuild. Replaces the prior
## set, so passing [] clears it.
func set_row_diagnostics(diagnostics: Array) -> int:
    _row_diagnostics.clear()
    _first_diagnostic_uid = ""
    for diagnostic in diagnostics:
        if not (diagnostic is Dictionary):
            continue
        var uid: String = str((diagnostic as Dictionary).get("uid", ""))
        if uid.is_empty() or _row_diagnostics.has(uid):
            continue
        var message: String = str((diagnostic as Dictionary).get("message", ""))
        var suggestion: String = str((diagnostic as Dictionary).get("suggestion", ""))
        _row_diagnostics[uid] = message + ("  " + suggestion if not suggestion.is_empty() else "")
        if _first_diagnostic_uid.is_empty():
            _first_diagnostic_uid = uid
    _refresh_rows()
    return _row_diagnostics.size()

func clear_row_diagnostics() -> void:
    if _row_diagnostics.is_empty():
        return
    _row_diagnostics.clear()
    _first_diagnostic_uid = ""
    _refresh_rows()

## Live event trace: highlights the rows whose events fired in the latest streamed frame. Updates
## the existing rows + redraws (no full rebuild) since it arrives ~every 0.25s during a debug run.
func set_fired_events(uids: PackedStringArray) -> void:
    _fired_uids.clear()
    for uid: String in uids:
        _fired_uids[uid] = true
    for entry: Dictionary in get_flat_rows():
        var row_data: EventRowData = entry.get("row")
        if row_data != null and row_data.source_resource is EventRow:
            row_data.firing = _fired_uids.has((row_data.source_resource as EventRow).event_uid)
    queue_redraw()

## Reveals (unfolds ancestors) + selects the first flagged row, so a failed compile lands you
## straight on the offending event instead of leaving you to hunt. False if nothing is flagged.
func reveal_and_select_first_diagnostic() -> bool:
    if _first_diagnostic_uid.is_empty():
        return false
    for entry: Dictionary in get_flat_rows():
        var row_data: EventRowData = entry.get("row")
        if row_data != null and row_data.source_resource != null and str(row_data.source_resource.get_instance_id()) == _first_diagnostic_uid:
            reveal_resource(row_data.source_resource)
            select_resource(row_data.source_resource)
            return true
    return false

## An enum row: rendered like a variable declaration ("enum  State { IDLE, RUN }");
## double-click opens the enum dialog.
func _build_enum_row(enum_row: EnumRow, indent: int) -> EventRowData:
    var event_style: EventSheetEventStyle = _get_event_style()
    var row_data := EventRowData.new()
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.SECTION
    row_data.source_resource = enum_row
    row_data.row_uid = "enum_%s_%d" % [str(enum_row.get_instance_id()), indent]
    row_data.disabled = not enum_row.enabled or bool(_row_disabled_state.get(row_data.row_uid, false))
    row_data.breakpoint_enabled = bool(_breakpoint_rows.get(row_data.row_uid, false))
    var members: PackedStringArray = PackedStringArray()
    for member: String in enum_row.members:
        if not member.strip_edges().is_empty():
            members.append(member.strip_edges())
    row_data.spans = [
        _make_span(
            "enum",
            SemanticSpan.SpanType.KEYWORD,
            {"badge": true, "text_color": event_style.behavior_accent_color}
        ),
        _make_span(
            "%s { %s }" % [enum_row.enum_name, ", ".join(members)],
            SemanticSpan.SpanType.VALUE,
            {"kind": "enum_row", "text_color": event_style.object_label_color}
        )
    ]
    return row_data

## A signal row: rendered like a declaration ("signal  hit(damage: int)"); double-click
## opens the signal dialog.
func _build_signal_row(signal_row: SignalRow, indent: int) -> EventRowData:
    var event_style: EventSheetEventStyle = _get_event_style()
    var row_data := EventRowData.new()
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.SECTION
    row_data.source_resource = signal_row
    row_data.row_uid = "signal_%s_%d" % [str(signal_row.get_instance_id()), indent]
    row_data.disabled = not signal_row.enabled or bool(_row_disabled_state.get(row_data.row_uid, false))
    row_data.breakpoint_enabled = bool(_breakpoint_rows.get(row_data.row_uid, false))
    var declaration: String = signal_row.signal_name
    if not signal_row.params.is_empty():
        declaration += "(%s)" % ", ".join(signal_row.params)
    row_data.spans = [
        _make_span(
            "signal",
            SemanticSpan.SpanType.KEYWORD,
            {"badge": true, "text_color": event_style.behavior_accent_color}
        ),
        _make_span(
            declaration,
            SemanticSpan.SpanType.VALUE,
            {"kind": "signal_row", "text_color": event_style.object_label_color}
        )
    ]
    return row_data

## A GDScript block row: verbatim code shown line-by-line, edited via the dock's code dialog
## (double-click), compiled at class level. The C3-style "inline code" escape hatch.
func _build_raw_code_row(raw_row: RawCodeRow, indent: int) -> EventRowData:
    var row_data := EventRowData.new()
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.SECTION
    row_data.source_resource = raw_row
    row_data.row_uid = "raw_code_%d" % raw_row.get_instance_id()
    row_data.disabled = not raw_row.enabled or bool(_row_disabled_state.get(row_data.row_uid, false))
    var code_lines: PackedStringArray = raw_row.code.split("\n")
    row_data.line_count = maxi(code_lines.size(), 1)
    var spans: Array[SemanticSpan] = []
    spans.append(_make_span("GDScript", SemanticSpan.SpanType.KEYWORD, {
        "editable": false,
        "badge": true,
        "badge_style": "scope",
        "badge_bg": Color(0.23, 0.28, 0.38, 0.95),
        "badge_fg": Color(0.78, 0.86, 1.0, 1.0),
        "kind": "raw_code",
        "line_index": 0
    }))
    for line_index in range(code_lines.size()):
        spans.append(_make_span(
            code_lines[line_index] if not code_lines[line_index].is_empty() else " ",
            SemanticSpan.SpanType.VALUE,
            {
                "editable": false,
                "kind": "raw_code",
                "line_index": line_index,
                "text_color": EventSheetPalette.TEXT_PRIMARY
            }
        ))
    row_data.spans = spans
    return row_data

## Builds a row for a variable placed directly in the event tree (movable like an event).
func _build_tree_variable_row(variable: LocalVariable, indent: int) -> EventRowData:
    return _build_variable_row(
        "tree",
        variable.name,
        variable.type_name,
        variable.default_value,
        indent,
        {
            "is_constant": variable.is_constant,
            "exported": variable.exported,
            "source_resource": variable,
            "row_uid": "variable_tree_%d" % variable.get_instance_id(),
            "badge_label": "global" if variable.exported else "local"
        }
    )

func _build_group_row(group: EventGroup, indent: int) -> EventRowData:
    var event_style: EventSheetEventStyle = _get_event_style()
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
                "badge_bg": event_style.group_badge_background_color,
                "badge_fg": event_style.group_badge_foreground_color,
                "group_badge": true
            }
        ),
        _make_span(
            _group_name(group),
            SemanticSpan.SpanType.OBJECT,
            {
                "editable": true,
                "edit_kind": "group_name",
                "group_title": true,
                "text_color": event_style.group_title_color
            }
        )
    ]
    # C3-style group description: a muted second line on the header, inline-editable.
    if not group.description.strip_edges().is_empty():
        row_data.line_count = 2
        row_data.spans.append(
            _make_span(
                group.description,
                SemanticSpan.SpanType.COMMENT,
                {
                    "editable": true,
                    "edit_kind": "group_description",
                    "line_index": 1,
                    "text_color": event_style.comment_text_color
                }
            )
        )
    for child in _group_children(group):
        var child_row: EventRowData = _build_row_from_resource(child, indent + 1)
        if child_row != null:
            row_data.children.append(child_row)
    # C3-style per-group footer: always the group's last child, one level deeper.
    if show_add_event_footers:
        row_data.children.append(
            _build_add_event_footer_row(group, indent + 1, "+ Add event to '%s'…" % _group_name(group))
        )
    return row_data

func _build_comment_row(comment_row: CommentRow, indent: int) -> EventRowData:
    var event_style: EventSheetEventStyle = _get_event_style()
    var row_data := EventRowData.new()
    row_data.indent = indent
    row_data.row_type = EventRowData.RowType.COMMENT
    row_data.source_resource = comment_row
    row_data.row_uid = "comment_%s_%d" % [str(comment_row.get_instance_id()), indent]
    row_data.folded = false
    row_data.debug_state = str(_debug_rows.get(row_data.row_uid, ""))
    row_data.disabled = not comment_row.enabled or bool(_row_disabled_state.get(row_data.row_uid, false))
    row_data.breakpoint_enabled = bool(_breakpoint_rows.get(row_data.row_uid, false))
    row_data.custom_color = comment_row.custom_color
    # Multiline comments render one span per text line (same per-line model as GDScript
    # blocks); the row height follows line_count.
    var comment_lines: PackedStringArray = comment_row.text.split("\n") if not comment_row.text.is_empty() else PackedStringArray(["Comment"])
    row_data.line_count = comment_lines.size()
    var comment_spans: Array[SemanticSpan] = []
    for line_index in range(comment_lines.size()):
        var line_metadata: Dictionary = {
            "editable": true,
            "edit_kind": "comment_text",
            "line_index": line_index,
            "text_color": event_style.comment_text_color
        }
        # BBCode-lite ([b]/[i]/[color=…]): segments shape the pixels; the RAW text stays
        # the editing/serialization truth (no data loss on edit/copy).
        if EventSheetBBCodeLite.has_markup(comment_lines[line_index]):
            line_metadata["bbcode_segments"] = EventSheetBBCodeLite.parse(comment_lines[line_index], event_style.comment_text_color)
        comment_spans.append(
            _make_span(
                comment_lines[line_index],
                SemanticSpan.SpanType.COMMENT,
                line_metadata
            )
        )
    row_data.spans = comment_spans
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
    # Event-row spans are the expensive part of building a sheet, so they are built
    # lazily via _ensure_event_spans() only when a row is laid out/hit-tested. The
    # line count (which drives row height/metrics) is computed cheaply up front so
    # the whole sheet can be flattened and measured without building any spans.
    row_data.line_count = _count_event_lines(event_row)
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
    var default_source: Resource = owner_event if scope_label == "local" else _sheet
    row_data.source_resource = options.get("source_resource", default_source)
    row_data.row_uid = str(options.get("row_uid", (
        "variable_local_%s_%d"
        % [owner_event.event_uid if owner_event != null else "none", variable_index]
        if scope_label == "local"
        else "variable_global_%s" % var_name
    )))
    row_data.folded = false
    var variable_meta := {
        "kind": "variable",
        "variable_scope": scope_label,
        "variable_name": var_name,
        "variable_index": variable_index,
        "is_constant": is_constant
    }
    var badge_label: String = str(options.get("badge_label", scope_label))
    var scope_badge_colors: Dictionary = _get_scope_badge_colors(badge_label)
    row_data.spans = [
        _make_span(
            badge_label,
            SemanticSpan.SpanType.KEYWORD,
            variable_meta.merged(
                {
                    "editable": false,
                    "badge": true,
                    "badge_style": "scope",
                    "badge_bg": scope_badge_colors.get("bg", EventSheetPalette.COLOR_SCOPE_GLOBAL_BADGE_BG),
                    "badge_fg": scope_badge_colors.get("fg", EventSheetPalette.COLOR_SCOPE_GLOBAL_BADGE_FG)
                },
                true
            )
        ),
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
    if event_row.else_mode == EventRow.ElseMode.ELSE:
        spans.append(
            _make_span(
                "Else",
                SemanticSpan.SpanType.KEYWORD,
                {
                    "lane": "condition",
                    "kind": "else_keyword",
                    "badge": true,
                    "hoverable": false,
                    "line_index": condition_line_index
                }.merged(condition_style_meta, true)
            )
        )
        condition_line_index += 1
    elif event_row.else_mode == EventRow.ElseMode.ELIF:
        spans.append(
            _make_span(
                "Else If",
                SemanticSpan.SpanType.KEYWORD,
                {
                    "lane": "condition",
                    "kind": "else_keyword",
                    "badge": true,
                    "hoverable": false,
                    "line_index": condition_line_index
                }.merged(condition_style_meta, true)
            )
        )
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
                    "ace_enabled": event_row.trigger.enabled,
                    "chip": true,
                    "line_index": condition_line_index,
                    "object_label": _object_label_for(event_row.trigger.provider_id, event_row.trigger.ace_id),
                    "object_icon": _object_icon_for(event_row.trigger.provider_id, event_row.trigger.ace_id)
                }.merged(condition_style_meta, true)
            )
        )
        condition_line_index += 1
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
                    "line_index": condition_line_index,
                    "object_label": _object_label_for(event_row.trigger_provider_id, event_row.trigger_id),
                    "object_icon": _object_icon_for(event_row.trigger_provider_id, event_row.trigger_id)
                }.merged(condition_style_meta, true)
            )
        )
        condition_line_index += 1
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
                    "ace_enabled": inline_trigger.enabled,
                    "chip": true,
                    "line_index": condition_line_index,
                    "rendered_as_trigger": true,
                    "object_label": _object_label_for(inline_trigger.provider_id, inline_trigger.ace_id),
                    "object_icon": _object_icon_for(inline_trigger.provider_id, inline_trigger.ace_id)
                }.merged(condition_style_meta, true)
            )
        )
        condition_line_index += 1
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
                        "ace_enabled": condition.enabled,
                        "chip": true,
                        "line_index": line_index,
                        "object_label": _object_label_for(condition.provider_id, condition.ace_id),
                        "object_icon": _object_icon_for(condition.provider_id, condition.ace_id),
                        "swatch_color": _first_color_in_params(condition)
                    }.merged(condition_style_meta, true)
                )
            )
            condition_line_index += 1
    # Pick filters render as "For each …" lines below the conditions (C3's picking rows);
    # double-click opens the pick-filter dialog.
    for pick_index in range(event_row.pick_filters.size()):
        var pick: PickFilter = event_row.pick_filters[pick_index] as PickFilter
        if pick == null or not pick.enabled:
            continue
        spans.append(
            _make_span(
                _format_pick_filter(pick),
                SemanticSpan.SpanType.CONDITION,
                {
                    "lane": "condition",
                    "kind": "pick_filter",
                    "pick_index": pick_index,
                    "chip": true,
                    "line_index": condition_line_index
                }.merged(condition_style_meta, true)
            )
        )
        condition_line_index += 1
    if spans.is_empty() and event_row.else_mode != EventRow.ElseMode.ELSE:
        # An event with no conditions reads as "every tick"; render it as a real cell (not bare
        # text) so the condition lane still shows a clear, clickable empty event block.
        spans.append(
            _make_span(
                "Every Tick",
                SemanticSpan.SpanType.CONDITION,
                {
                    "lane": "condition",
                    "kind": "condition",
                    "ace_index": -1,
                    "chip": true,
                    "placeholder": true,
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
                            "ace_enabled": (action_resource as ACEAction).enabled,
                            "chip": true,
                            "line_index": action_line_index,
                            "object_label": _object_label_for((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id),
                            "object_icon": _object_icon_for((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id),
                            "swatch_color": _first_color_in_params(action_resource)
                        }.merged(action_style_meta, true)
                    )
                )
                action_line_index += 1
            elif action_resource is MatchRow:
                # match statement (C3's switch): header + branch lines as action cells
                # sharing one ace_index; double-click opens the match dialog.
                var match_resource: MatchRow = action_resource as MatchRow
                var match_lines: PackedStringArray = PackedStringArray(["match %s:" % match_resource.match_expression])
                for branch_line: String in match_resource.branches_text.split("\n"):
                    match_lines.append("\t" + branch_line)
                for match_line_index in range(match_lines.size()):
                    spans.append(
                        _make_span(
                            match_lines[match_line_index] if not match_lines[match_line_index].is_empty() else " ",
                            SemanticSpan.SpanType.VALUE,
                            {
                                "lane": "action",
                                "kind": "action",
                                "ace_index": action_index,
                                "match_action": true,
                                "action_line": match_line_index,
                                "text_color": event_style.value_highlight_color
                            }
                        )
                    )
            elif action_resource is RawCodeRow:
                # In-flow GDScript block: one action-lane cell per code line. All lines share
                # the block's ace_index, so click/drag/delete treat the block as one action.
                var inline_raw: RawCodeRow = action_resource as RawCodeRow
                var inline_lines: PackedStringArray = inline_raw.code.split("\n")
                var inline_total: int = maxi(inline_lines.size(), 1)
                for inline_line_index in range(inline_total):
                    var inline_text: String = inline_lines[inline_line_index] if inline_line_index < inline_lines.size() else " "
                    spans.append(
                        _make_span(
                            inline_text if not inline_text.is_empty() else " ",
                            SemanticSpan.SpanType.VALUE,
                            {
                                "lane": "action",
                                "kind": "action",
                                "ace_index": action_index,
                                "ace_enabled": inline_raw.enabled,
                                "chip": true,
                                "raw_action": true,
                                # The renderer merges block lines into ONE code cell
                                # (left stripe, continuous background) — per-line
                                # spans stay the layout/hit-test truth.
                                "code_cell": true,
                                "block_lines": inline_total,
                                "block_line": inline_line_index,
                                "line_index": action_line_index,
                                "object_label": "GDScript" if inline_line_index == 0 else ""
                            }.merged(action_style_meta, true)
                        )
                    )
                    action_line_index += 1
            elif action_resource is CommentRow:
                # Action-cell comment (C3 parity: comments can live inside an event's
                # action flow; convertible back to a standalone comment row). One
                # comment-styled cell per text line, sharing the ace_index.
                var action_comment: CommentRow = action_resource as CommentRow
                var action_comment_lines: PackedStringArray = action_comment.text.split("\n") if not action_comment.text.is_empty() else PackedStringArray(["Comment"])
                for comment_line_index in range(action_comment_lines.size()):
                    spans.append(
                        _make_span(
                            "# " + action_comment_lines[comment_line_index],
                            SemanticSpan.SpanType.COMMENT,
                            {
                                "lane": "action",
                                "kind": "action",
                                "ace_index": action_index,
                                "ace_enabled": action_comment.enabled,
                                "chip": true,
                                "action_comment": true,
                                # Merged like GDScript blocks, and carrying the action
                                # cell chrome (chip_bg etc.) so a comment in the action
                                # lane reads like its sibling cells — comment text
                                # color wins (merged with overwrite OFF).
                                "block_lines": action_comment_lines.size(),
                                "block_line": comment_line_index,
                                "line_index": action_line_index,
                                "text_color": _get_event_style().comment_text_color
                            }.merged(action_style_meta, false)
                        )
                    )
                    action_line_index += 1
    # The event comment (if any) sits below the actions; "+ Add" sits at the bottom of the
    # action lane, LEFT-aligned so it always stays visible. It used to be pinned to the lane's
    # far-right edge, which scrolled off-screen unless the editor window was very wide.
    var add_action_line_index: int = action_line_index
    if not event_row.comment.is_empty():
        var comment_line_index: int = max(action_line_index, COMMENT_DEFAULT_LINE_INDEX)
        spans.append(
            _make_span(
                event_row.comment,
                SemanticSpan.SpanType.COMMENT,
                {
                    "editable": true,
                    "edit_kind": "event_comment",
                    "lane": "action",
                    "chip": true,
                    "line_index": comment_line_index
                }.merged(action_style_meta, true)
            )
        )
        add_action_line_index = comment_line_index + 1
    # C3-style faint "Add action" affordance on its own line below the actions.
    var add_action_color: Color = action_style_meta.get("text_color", EventSheetPalette.COLOR_ACTION)
    add_action_color.a *= 0.55
    spans.append(
        _make_span(
            "+ Add action",
            SemanticSpan.SpanType.ACTION,
            {
                "lane": "action",
                "kind": "add_action",
                "line_index": add_action_line_index,
                "text_color": add_action_color,
                "font_size_delta": action_style_meta.get("font_size_delta", 0)
            }
        )
    )
    return spans

## Cheaply computes how many stacked lines an event row occupies, mirroring the
## line-index accounting in _build_event_spans() WITHOUT building any spans. This lets
## the whole sheet be measured (row heights/metrics) without the expensive span pass.
## Invariant (covered by event_lazy_spans_test): equals max span line_index + 1.
func _count_event_lines(event_row: EventRow) -> int:
    if event_row == null:
        return 1
    # Condition lane.
    var condition_lines: int = 0
    if event_row.else_mode == EventRow.ElseMode.ELSE:
        condition_lines += 1
    var inline_trigger_index: int = _find_inline_trigger_condition_index(event_row)
    var has_trigger: bool = (
        event_row.trigger != null
        or not event_row.trigger_id.is_empty()
        or (inline_trigger_index >= 0 and inline_trigger_index < event_row.conditions.size())
    )
    if has_trigger:
        condition_lines += 1
    for condition_index in range(event_row.conditions.size()):
        if condition_index == inline_trigger_index:
            continue
        if event_row.conditions[condition_index] == null:
            continue
        condition_lines += 1
    for pick_entry in event_row.pick_filters:
        if pick_entry is PickFilter and (pick_entry as PickFilter).enabled:
            condition_lines += 1
    var max_condition_line: int = maxi(condition_lines - 1, 0)
    # Action lane: "+ Add" sits on its own line below the actions (and below the event comment
    # when present), so the lane spans action_count (+ comment) + 1 lines. In-flow GDScript
    # blocks occupy one line per code line.
    var action_count: int = 0
    for action_resource in event_row.actions:
        if action_resource is ACEAction:
            action_count += 1
        elif action_resource is RawCodeRow:
            action_count += maxi((action_resource as RawCodeRow).code.split("\n").size(), 1)
        elif action_resource is MatchRow:
            action_count += (action_resource as MatchRow).branches_text.split("\n").size() + 1
        elif action_resource is CommentRow:
            action_count += maxi((action_resource as CommentRow).text.split("\n").size(), 1)
    var max_action_line: int = action_count
    if not event_row.comment.is_empty():
        max_action_line = maxi(action_count, COMMENT_DEFAULT_LINE_INDEX) + 1
    return maxi(max_condition_line, max_action_line) + 1

## Builds an event row's spans on demand. Event-row spans are deferred (see
## _build_event_row) so large sheets load fast; this is called from the row layout
## choke point and selection paths before any span data is read. Idempotent: built
## spans are never empty (a "+ Add" span is always present), so is_empty() reliably
## means "not yet built".
func _ensure_event_spans(row_data: EventRowData) -> void:
    if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
        return
    if not row_data.spans.is_empty():
        return
    if row_data.source_resource is EventRow:
        row_data.spans = _build_event_spans(row_data.source_resource as EventRow)

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
    # Keep the primary badge column stable for trigger/invert/OR by rendering
    # negation first. When a line has both badges, ✕ is placed in column 1
    # and OR follows in column 2.
    if condition.negated:
        var negated_meta: Dictionary = BADGE_NEGATED_METADATA.duplicate(true)
        negated_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", BADGE_EXTRA_WIDTH)
        negated_meta["condition_index"] = condition_index
        negated_meta["line_index"] = line_index
        negated_meta["badge_style"] = "negated"
        # C3-style inverted-condition marker: a bare red ✗ (C3's --invert-icon-color),
        # no circle behind it. Themable via EventSheetEventStyle.invert_marker_color.
        negated_meta["badge_bg"] = Color(0.0, 0.0, 0.0, 0.0)
        negated_meta["badge_fg"] = _get_event_style().invert_marker_color
        spans.append(_make_span("✕", SemanticSpan.SpanType.KEYWORD, negated_meta))
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

func _measure_span_width(span: SemanticSpan, display_text: String, font: Font, font_size: int) -> float:
    if span == null:
        return 0.0
    var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
    var font_size_delta: int = int(metadata.get("font_size_delta", 0))
    var horizontal_padding: float = float(metadata.get("padding_x", 0.0))
    var draw_font_size: int = EventSheetPalette.resolve_font_size(font_size, font_size_delta)
    if bool(metadata.get("group_title", false)):
        # Group titles are drawn one size larger by the renderer; match it so the measured
        # box is wide enough and the name is not clipped.
        draw_font_size = EventSheetPalette.resolve_font_size(draw_font_size, 0, 1)
    var span_width: float = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
    var object_label: String = str(metadata.get("object_label", ""))
    if not object_label.is_empty():
        span_width += font.get_string_size(object_label + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
    if metadata.get("object_icon") is Texture2D:
        span_width += EventRowRenderer.OBJECT_ICON_ADVANCE
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
    # Build this row's spans on demand. This is the single choke point for both
    # drawing (_draw) and hit-testing (_hit_test), so any laid-out/interacted row
    # always has its spans before they are read downstream.
    _ensure_event_spans(row_data)
    var event_style: EventSheetEventStyle = _get_event_style()
    var line_height: float = _get_event_line_height(font_size)
    # Cache key components: row uid, visible row index, canvas width, active drag
    # target index, and the current layout style signature.
    # Drag state is part of the key so the drop preview (row reorder + ACE drop line) updates
    # as the drag target moves; it is constant when idle, so no churn outside a drag.
    var drag_signature: String = "%d:%s:%d:%s:%d:%s" % [
        _drag_target_index, _drag_target_mode,
        _drag_ace_target_row_index, _drag_ace_target_lane, _drag_ace_target_ace_index, _drag_ace_insert_mode
    ]
    var key: String = "%s:%d:%d:%s:%s" % [row_data.row_uid, index, int(width), drag_signature, _layout_style_signature]
    if _layout_cache.has(key):
        var cached_layout: Dictionary = _layout_cache.get_layout(key)
        # Selection/hover are NOT part of the cache key (geometry is unchanged by them), so they
        # must be refreshed on every read — otherwise a click/hover reads stale state and the
        # whole event highlights instead of the clicked cell, and hover never appears.
        cached_layout["selected_span_indices"] = _selected_span_indices.get(row_data.row_uid, []).duplicate()
        cached_layout["hovered_span_index"] = _hovered_span_index if index == _hovered_row_index else -1
        return cached_layout
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
        lane_divider_x = get_lane_divider_x(width)
        condition_lane_rect = Rect2(x, row_top, max(lane_divider_x - x, 1.0), row_height)
        lane_divider_rect = Rect2(lane_divider_x, row_top, float(event_style.lane_divider_width), row_height)
        action_lane_rect = Rect2(lane_divider_x + float(event_style.lane_divider_width), row_top, max(width - lane_divider_x - float(event_style.lane_divider_width), 1.0), row_height)
    var condition_x: float = _get_condition_track_start(row_data, x, condition_lane_rect)
    var condition_badge_column_width: float = max(float(event_style.condition_badge_column_width), 0.0)
    var condition_badge_column_gap: float = EventSheetPalette.SPAN_GAP if condition_badge_column_width > 0.0 else 0.0
    var condition_text_start_x: float = condition_x + condition_badge_column_width + condition_badge_column_gap
    var condition_line_x: Dictionary = {}
    # Tracks the next available X in the badge area for each condition line.
    var condition_badge_next_x: Dictionary = {}
    var action_x: float = (
        lane_divider_x + float(event_style.lane_divider_width) + float(event_style.action_lane_padding)
        if lane_divider_x > 0.0
        else x
    )
    var action_line_x: Dictionary = {}
    var action_line_reservations: Dictionary = _build_action_line_reservations(row_data, action_lane_rect, font, font_size)
    # Running X per line for non-event rows (group / variable / comment / GDScript block),
    # which lay out left-to-right; multi-line rows stack by span line_index.
    var non_event_origin_x: float = x
    # Indent comment text to line up with where an event's condition text begins (past the
    # trigger/badge column), so comments align with the event blocks they annotate.
    if row_data.row_type == EventRowData.RowType.COMMENT:
        var comment_badge_column: float = max(float(event_style.condition_badge_column_width), 0.0)
        if comment_badge_column > 0.0:
            non_event_origin_x += comment_badge_column + EventSheetPalette.SPAN_GAP
    var non_event_line_x: Dictionary = {}
    for span_index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[span_index]
        if span == null:
            continue
        var span_lane: String = _resolve_span_lane(span)
        var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
        var span_x: float = x
        var span_y: float = row_top + 3.0
        if lane_divider_x <= 0.0:
            # Non-event rows (group / variable / comment / GDScript block) flow their spans
            # left-to-right per line; without this every span stayed at the same X and
            # overlapped. Multi-line rows stack via span line_index.
            var flow_line: int = int(metadata.get("line_index", 0))
            span_y = row_top + float(flow_line) * line_height + 3.0
            span_x = float(non_event_line_x.get(flow_line, non_event_origin_x))
        elif span_lane == "action":
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
            if bool(metadata.get("badge", false)):
                if not condition_badge_next_x.has(line_index):
                    condition_badge_next_x[line_index] = condition_x
                span_x = float(condition_badge_next_x[line_index])
            else:
                if not condition_line_x.has(line_index):
                    # If badges were drawn first on this line, start the condition text
                    # after the rightmost badge; otherwise use the default badge-column offset.
                    condition_line_x[line_index] = float(
                        condition_badge_next_x.get(line_index, condition_text_start_x)
                    )
                span_x = float(condition_line_x[line_index])
            span_y = row_top + float(line_index) * line_height + 3.0
        var display_text: String = _editing_buffer if index == _editing_row_index and span_index == _editing_span_index else span.text
        var span_width: float = _measure_span_width(span, display_text, font, font_size)
        if lane_divider_x > 0.0 and span_lane != "action":
            var max_condition_right: float = lane_divider_x - float(event_style.condition_lane_padding)
            if bool(metadata.get("badge", false)):
                var badge_width: float = condition_badge_column_width if condition_badge_column_width > 0.0 else span_width
                span_width = max(min(badge_width, max_condition_right - span_x), MIN_SPAN_WIDTH)
            elif str(metadata.get("kind", "")) in ["condition", "trigger"]:
                span_width = max(max_condition_right - span_x, MIN_SPAN_WIDTH)
            else:
                span_width = max(min(span_width, max_condition_right - span_x), MIN_SPAN_WIDTH)
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
                var max_action_width: float = reserved_start - max(_get_span_gap(span), EventSheetPalette.SPAN_GAP) - span_x
                if str(metadata.get("kind", "")) == "action":
                    span_width = max(max_action_width, 1.0)
                else:
                    span_width = max(min(span_width, max_action_width), 1.0)
        else:
            # -2.0 accounts for the +2.0 the rect adds below, so non-event spans (comments,
            # variables, blocks) never bleed past the row's right padding.
            span_width = max(min(span_width, row_right_limit - span_x - 2.0), 1.0)
        # C3-style contiguous cells: chip cells (conditions/actions/comments) fill their full
        # line minus a 1px hairline, so stacked cells read as one solid block. Badges and
        # plain text keep the original vertical inset.
        if bool(metadata.get("chip", false)):
            span.rect = Rect2(span_x, span_y - 2.5, span_width + 2.0, line_height - 1.0)
        else:
            span.rect = Rect2(span_x, span_y, span_width + 2.0, line_height - 6.0)
        # Store absolute X for the next span start on this line.
        var next_span_start_x: float = span.rect.end.x + _get_span_gap(span)
        if lane_divider_x <= 0.0:
            non_event_line_x[int(metadata.get("line_index", 0))] = next_span_start_x
        elif span_lane == "action":
            var action_line_index_next: int = int(metadata.get("line_index", 0))
            if not bool(metadata.get("align_right", false)):
                action_line_x[action_line_index_next] = next_span_start_x
        else:
            var condition_line_index: int = int(metadata.get("line_index", 0))
            if bool(metadata.get("badge", false)):
                condition_badge_next_x[condition_line_index] = next_span_start_x
            else:
                condition_line_x[condition_line_index] = next_span_start_x
    var drag_rect := Rect2()
    if _drag_row_index >= 0 and _drag_target_index == index:
        match _drag_target_mode:
            "after":
                drag_rect = Rect2(0.0, row_rect.end.y - 1.0, width, 2.0)
            "inside":
                # Indent the drop line to the child level so it clearly reads as "nest this
                # as a sub-event of the target", not just "drop after".
                var child_indent_x: float = EventSheetPalette.GUTTER_WIDTH + float((row_data.indent + 1) * INDENT_WIDTH) + EventSheetPalette.ROW_HORIZONTAL_PADDING
                drag_rect = Rect2(child_indent_x, row_rect.end.y - 2.0, max(width - child_indent_x, 1.0), 3.0)
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
        "total_selected_spans": _get_selected_span_count(),
        "selected_span_indices": _selected_span_indices.get(row_data.row_uid, []).duplicate(),
        "hovered_span_index": _hovered_span_index if index == _hovered_row_index else -1,
        "drag_mode": _drag_target_mode if _drag_target_index == index else ""
    }
    _layout_cache.store(key, layout)
    return layout

## Display text for a pick-filter row: "For each item in group \"enemies\" (first 3)".
func _format_pick_filter(pick: PickFilter) -> String:
    var iterator: String = pick.iterator_name.strip_edges()
    if iterator.is_empty():
        iterator = "item"
    var collection: String = pick.collection_value.strip_edges()
    if collection.is_empty():
        collection = pick.source_expression.strip_edges()
    var source_text: String = collection
    match pick.collection_kind:
        PickFilter.CollectionKind.GROUP:
            source_text = "group \"%s\"" % collection
        PickFilter.CollectionKind.CHILDREN:
            source_text = "children"
        PickFilter.CollectionKind.REPEAT:
            return "Repeat %s times" % collection
        PickFilter.CollectionKind.WHILE:
            return "While %s" % collection
    var text: String = "For each %s in %s" % [iterator, source_text]
    if not pick.predicate_expression.strip_edges().is_empty():
        text += " where %s" % pick.predicate_expression.strip_edges()
    if pick.pick_first_n > 0:
        text += " (first %d)" % pick.pick_first_n
    return text

## Identity context for the pinned column header: behavior sheets show their host class so
## it is always visible what the conditions/actions act on.
func get_host_context_label() -> String:
    if _sheet != null and _sheet.behavior_mode:
        return " — host: %s" % _sheet.host_class
    return ""

# ── Live values (rung 3): inline chips next to variable rows ──────────────────────────
var _live_values: Dictionary = {}

## Streamed name->value frame (debug runs). Redraws value chips on variable rows.
func set_live_values(values: Dictionary) -> void:
    _live_values = values
    queue_redraw()

## The "= value" chip for a row, or "" (variable rows whose name has a live frame).
func live_value_chip_for(row_data: EventRowData) -> String:
    var variable_name: String = ""
    if row_data.source_resource is LocalVariable:
        variable_name = (row_data.source_resource as LocalVariable).name
    elif not row_data.spans.is_empty():
        var first_word: String = str(row_data.spans[0].text).get_slice(":", 0).strip_edges()
        if _live_values.has(first_word):
            variable_name = first_word
    if variable_name.is_empty() or not _live_values.has(variable_name):
        return ""
    return "= %s" % str(_live_values[variable_name])

## Draws "= value" after a variable row's text when a live frame carries its name.
func _draw_live_value_chip(row_data: EventRowData, row_top: float, row_height: float, font: Font, font_size: int) -> void:
    if _live_values.is_empty() or row_data == null:
        return
    var chip_text: String = live_value_chip_for(row_data)
    if chip_text.is_empty():
        return
    var text_width: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
    var chip_x: float = _get_logical_canvas_width() - text_width - 24.0
    draw_string(font, Vector2(chip_x, row_top + row_height * 0.5 + font_size * 0.35), chip_text,
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, get_event_style().value_highlight_color if get_event_style() != null else EventSheetPalette.COLOR_VALUE)

## True when the sheet has no authored rows — either genuinely empty, or holding only the
## trailing "+ Add event…" footer affordance(s). Drives the getting-started empty state so a
## brand-new sheet shows guidance instead of a lone footer row.
func _is_sheet_visually_empty() -> bool:
    for entry: Dictionary in _flat_rows:
        var row_data: EventRowData = entry.get("row")
        if row_data != null and not _row_is_add_event_footer(row_data):
            return false
    return true

## Calm getting-started state for an empty sheet: one clear heading, one primary call to
## action, and a single de-emphasized tip — instead of a dense run-on of shortcuts that
## reads as clutter the moment a new user opens a sheet.
func _draw_empty_state(width: float) -> void:
    var font: Font = _get_font()
    var font_size: int = _get_font_size()
    var heading: String = "This event sheet is empty"
    var primary: String = "Double-click anywhere — or press E — to add your first event."
    var tip: String = "Tip: the picker understands plain language. Try typing \"every tick\"."
    if _sheet != null and _sheet.behavior_mode:
        heading = "Empty behavior sheet"
        primary = "Add events to drive the node this attaches to (a %s)." % _sheet.host_class
        tip = "Double-click anywhere — or press E — to add your first event."
    var left: float = 18.0
    var max_w: float = max(width - 36.0, 1.0)
    var heading_size: int = EventSheetPalette.resolve_font_size(font_size, 0, 2)
    var line_gap: float = 8.0
    var y: float = 36.0 + float(heading_size)
    draw_string(font, Vector2(left, y), heading, HORIZONTAL_ALIGNMENT_LEFT, max_w, heading_size, EventSheetPalette.TEXT_PRIMARY)
    y += float(font_size) + line_gap + 6.0
    draw_string(font, Vector2(left, y), primary, HORIZONTAL_ALIGNMENT_LEFT, max_w, font_size, EventSheetPalette.TEXT_SECONDARY)
    y += float(font_size) + line_gap
    draw_string(font, Vector2(left, y), tip, HORIZONTAL_ALIGNMENT_LEFT, max_w, EventSheetPalette.resolve_font_size(font_size, -1), EventSheetPalette.TEXT_MUTED)

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
    # Selection state is delegated so event-body selection can include descendant
    # rows without duplicating toggle/anchor bookkeeping in multiple call sites.
    var selection_state: Dictionary = _selection_helper.build_single_selection(
        _flat_rows,
        row_index,
        span_index,
        _focused_lane,
        _collect_descendant_row_uids,
        _resolve_lane_for_row
    )
    _selected_row_uids = selection_state.get("selected_row_uids", {}).duplicate(true)
    _selected_span_indices = selection_state.get("selected_span_indices", {}).duplicate(true)
    # Non-toggle single selection replaces the whole selection set, so any span-only
    # provenance from a prior Ctrl-toggle is no longer meaningful.
    _span_only_row_uids.clear()
    _selected_row_index = int(selection_state.get("selected_row_index", -1))
    _selected_span_index = int(selection_state.get("selected_span_index", -1))
    _selection_anchor_index = int(selection_state.get("selection_anchor_index", -1))
    _focused_lane = str(selection_state.get("focused_lane", _focused_lane))
    var selected_row: EventRowData = _row_at(_selected_row_index)
    # Keyboard/programmatic selection can target a row that has not been drawn yet,
    # so ensure its spans before selection consumers read them.
    _ensure_event_spans(selected_row)
    _selection_helper.sync_row_selection_flags(_flat_rows, _selected_row_uids)
    selection_changed.emit(selected_row)
    queue_redraw()

## Select every row between the selection anchor and target_index (inclusive) — the Shift+click /
## Shift+Arrow range gesture. Preserves _selection_anchor_index so the range can grow or shrink
## from the same origin, and clears any span-level selection (range selection is whole-row).
func _select_range(target_index: int) -> void:
    if _flat_rows.is_empty():
        return
    var anchor: int = _selection_anchor_index if _selection_anchor_index >= 0 else _selected_row_index
    if anchor < 0:
        anchor = target_index
    anchor = clampi(anchor, 0, _flat_rows.size() - 1)
    target_index = clampi(target_index, 0, _flat_rows.size() - 1)
    _selected_row_uids.clear()
    _selected_span_indices.clear()
    _span_only_row_uids.clear()
    for i in range(mini(anchor, target_index), maxi(anchor, target_index) + 1):
        var range_row: EventRowData = _row_at(i)
        if range_row != null:
            _selected_row_uids[range_row.row_uid] = true
    _selected_row_index = target_index
    _selected_span_index = -1
    _selection_anchor_index = anchor
    var lead_row: EventRowData = _row_at(target_index)
    _ensure_event_spans(lead_row)
    _sync_row_selection_flags()
    selection_changed.emit(lead_row)
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
    _ensure_event_spans(row_data)
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
            # If the row was pulled into the selection set only by a span toggle (never
            # whole-row selected), removing its last span must release the row too —
            # otherwise it stays phantom-selected. Whole-row-selected rows are left intact.
            if _span_only_row_uids.has(row_uid):
                _span_only_row_uids.erase(row_uid)
                _selected_row_uids.erase(row_uid)
            if not _selected_row_uids.has(row_uid):
                if _selected_row_index == row_index:
                    _selected_row_index = -1
                    _selected_span_index = -1
        else:
            _selected_span_indices[row_uid] = indices
            # Record provenance only when the span add is what introduces this row to the
            # row-selection set; do not downgrade a genuinely whole-row-selected row.
            if not _selected_row_uids.has(row_uid):
                _span_only_row_uids[row_uid] = true
            _selected_row_uids[row_uid] = true
            _selected_row_index = row_index
            _selected_span_index = span_index
            changed = true
    else:
        if _selected_row_uids.has(row_uid) and not _selected_span_indices.has(row_uid):
            _selected_row_uids.erase(row_uid)
            _span_only_row_uids.erase(row_uid)
            if _selected_row_index == row_index:
                _selected_row_index = -1
                _selected_span_index = -1
        else:
            # Whole-row select: this row (and any descendants) are now genuinely selected,
            # so drop any span-only provenance — they must survive a later span on/off toggle.
            _selected_row_uids[row_uid] = true
            _span_only_row_uids.erase(row_uid)
            if not row_data.children.is_empty():
                for descendant_uid in _collect_descendant_row_uids(row_data):
                    _selected_row_uids[str(descendant_uid)] = true
                    _span_only_row_uids.erase(str(descendant_uid))
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
    _span_only_row_uids.clear()
    _selected_row_index = -1
    _selected_span_index = -1
    _selection_anchor_index = -1
    _sync_row_selection_flags()
    selection_changed.emit(null)
    queue_redraw()

func _sync_row_selection_flags() -> void:
    _selection_helper.sync_row_selection_flags(_flat_rows, _selected_row_uids)

func _set_hover_state(row_index: int, span_index: int) -> void:
    _hovered_row_index = row_index
    _hovered_span_index = span_index
    _selection_helper.apply_hover_state(_flat_rows, _hovered_row_index)
    queue_redraw()

func _toggle_row_fold(row_index: int) -> void:
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null or row_data.children.is_empty():
        return
    row_data.folded = not row_data.folded
    _fold_state[row_data.row_uid] = row_data.folded
    _refresh_rows()

func _begin_edit(row_index: int, span_index: int) -> void:
    if companion_mode:
        return
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null:
        return
    # Group headers edit through a popup (name + description), not an inline title field — so the
    # description, which only renders once non-empty, is always reachable. The dock owns the popup.
    if row_data.source_resource is EventGroup:
        group_edit_requested.emit(row_data.source_resource as EventGroup)
        return
    var resolved_span_index: int = span_index
    # Fall back to the row's first editable span whenever the clicked span isn't editable, so
    # double-clicking anywhere on a comment / group row (its badge, icon, or padding) still
    # edits the text, not just a pixel-perfect hit on the label.
    if resolved_span_index < 0 or resolved_span_index >= row_data.spans.size() or not _span_is_editable(row_data, resolved_span_index):
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

func begin_edit_selected() -> bool:
    if _selected_row_index < 0:
        return false
    var row_data: EventRowData = _row_at(_selected_row_index)
    if row_data == null:
        return false
    var resolved_span_index: int = _selected_span_index
    if resolved_span_index < 0:
        resolved_span_index = _find_first_editable_span(row_data)
    if resolved_span_index < 0 or resolved_span_index >= row_data.spans.size():
        return false
    var span: SemanticSpan = row_data.spans[resolved_span_index]
    var metadata: Dictionary = span.metadata if span != null and span.metadata is Dictionary else {}
    if not bool(metadata.get("editable", false)):
        return false
    _begin_edit(_selected_row_index, resolved_span_index)
    return _editing_row_index == _selected_row_index and _editing_span_index == resolved_span_index

func get_editing_context_for_test() -> Dictionary:
    return {
        "row_index": _editing_row_index,
        "span_index": _editing_span_index,
        "buffer": _editing_buffer
    }

func _find_first_editable_span(row_data: EventRowData) -> int:
    for index in range(row_data.spans.size()):
        var span: SemanticSpan = row_data.spans[index]
        if span == null or not (span.metadata is Dictionary):
            continue
        if bool((span.metadata as Dictionary).get("editable", false)):
            return index
    return -1

func _span_is_editable(row_data: EventRowData, span_index: int) -> bool:
    if row_data == null or span_index < 0 or span_index >= row_data.spans.size():
        return false
    var span: SemanticSpan = row_data.spans[span_index]
    if span == null or not (span.metadata is Dictionary):
        return false
    return bool((span.metadata as Dictionary).get("editable", false))

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

## Hovering a condition/action/trigger shows the GDScript it compiles to (the codegen
## template with the ACE's parameter values substituted) — the sheet continuously teaches
## the GDScript mapping. Falls back to tooltip_text (drag feedback) otherwise.
func _get_tooltip(at_position: Vector2) -> String:
    var hit: Dictionary = _hit_test(_to_logical_position(at_position))
    # Error → row deep-link: a flagged row leads its tooltip with the diagnostic (it matters
    # more than the codegen preview).
    var hovered_error_row: EventRowData = _row_at(int(hit.get("row_index", -1)))
    if hovered_error_row != null and not hovered_error_row.error_message.is_empty():
        return "⚠ %s" % hovered_error_row.error_message
    var metadata: Dictionary = hit.get("span_metadata", {}) if hit.get("span_metadata", {}) is Dictionary else {}
    var kind: String = str(metadata.get("kind", ""))
    if kind in ["condition", "trigger", "action"]:
        var row_data: EventRowData = _row_at(int(hit.get("row_index", -1)))
        if row_data != null and row_data.source_resource is EventRow:
            var ace_resource: Resource = _resolve_ace_resource(row_data.source_resource, kind, int(metadata.get("ace_index", -1)))
            var code: String = ""
            if ace_resource is ACECondition:
                var condition: ACECondition = ace_resource as ACECondition
                code = _codegen_preview_for(condition.provider_id, condition.ace_id, condition.params if not condition.params.is_empty() else condition.parameters)
            elif ace_resource is ACEAction:
                var action: ACEAction = ace_resource as ACEAction
                code = _codegen_preview_for(action.provider_id, action.ace_id, action.params if not action.params.is_empty() else action.parameters)
            if not code.strip_edges().is_empty():
                return "GDScript:\n%s" % code
    # Raw GDScript blocks are the one row whose codegen is literally themselves — advertise
    # that the block compiles verbatim (the escape hatch is transparent, not a black box).
    var raw_row_data: EventRowData = _row_at(int(hit.get("row_index", -1)))
    if raw_row_data != null and raw_row_data.source_resource is RawCodeRow:
        var raw_block: RawCodeRow = raw_row_data.source_resource as RawCodeRow
        var first_line: String = raw_block.code.split("\n")[0] if not raw_block.code.is_empty() else ""
        var tip: String = "GDScript (verbatim):\n%s\nEmitted as-is into the generated script — select to highlight its lines in the GDScript panel." % first_line
        if not raw_block.note.strip_edges().is_empty():
            tip = "%s — %s\n%s" % [raw_block.note, "GDScript (verbatim)", tip.split("\n", true, 1)[1] if tip.contains("\n") else tip]
        # Import triage: when a line couldn't lift into a structured ACE, say why right here.
        if not raw_block.lift_note.strip_edges().is_empty():
            tip += "\n⚠ Stayed as code: %s" % raw_block.lift_note
        return tip
    return tooltip_text

## The GDScript snippet an ACE compiles to: its codegen template with parameter values
## substituted (definition metadata first, then the base descriptor registry).
func _codegen_preview_for(provider_id: String, ace_id: String, params: Dictionary) -> String:
    var template: String = ""
    var definition: ACEDefinition = _find_definition(provider_id, ace_id)
    if definition != null:
        template = str(definition.metadata.get("codegen_template", ""))
    if template.strip_edges().is_empty():
        var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
        if descriptor != null:
            template = descriptor.codegen_template
    return fill_codegen_template(template, params)

static func fill_codegen_template(template: String, params: Dictionary) -> String:
    if template.strip_edges().is_empty():
        return ""
    var filled: String = template
    for key in params.keys():
        filled = filled.replace("{%s}" % str(key), str(params[key]))
    return filled

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
    return _hit_test_helper.hit_test_row(
        position,
        row_index,
        layout,
        row_data,
        _resolve_span_lane,
        _find_condition_span_index
    )

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

func _maybe_request_variable_edit(hit: Dictionary, row_index: int) -> bool:
    var row_data: EventRowData = _row_at(row_index)
    if row_data == null or row_data.row_type != EventRowData.RowType.SECTION:
        return false
    var metadata: Dictionary = {}
    var span_index: int = int(hit.get("span_index", -1))
    if span_index >= 0 and span_index < row_data.spans.size():
        var span: SemanticSpan = row_data.spans[span_index]
        if span != null and span.metadata is Dictionary:
            metadata = (span.metadata as Dictionary).duplicate(true)
    if str(metadata.get("kind", "")) != "variable":
        metadata = _get_variable_metadata_for_row(row_data)
    if str(metadata.get("kind", "")) != "variable":
        return false
    variable_edit_requested.emit(row_data, metadata)
    return true

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
    var previous_indent: int = -1
    for index in range(_flat_rows.size()):
        var row_data: EventRowData = _row_at(index)
        # Separate sibling/parent-level event blocks with a small gap, but keep a parent and
        # its sub-events (a deeper indent) tight together so the nesting reads clearly.
        if (
            index > 0
            and row_data != null
            and row_data.indent <= previous_indent
            and (row_data.row_type == EventRowData.RowType.EVENT or row_data.row_type == EventRowData.RowType.GROUP)
        ):
            top += EVENT_BLOCK_GAP
        var height: float = _resolve_row_height(row_data)
        _row_metrics.append({"top": top, "height": height})
        top += height
        if row_data != null:
            previous_indent = row_data.indent

func _resolve_row_height(row_data: EventRowData) -> float:
    if row_data == null:
        return float(ROW_HEIGHT)
    if row_data.row_type != EventRowData.RowType.EVENT:
        # Multi-line non-event rows (GDScript blocks) expand by their precomputed line count.
        if row_data.line_count > 1:
            return float(row_data.line_count) * _get_event_line_height(_get_font_size())
        return float(ROW_HEIGHT)
    var line_height: float = _get_event_line_height(_get_font_size())
    # When spans are still lazy (not yet built), use the precomputed line count so
    # metrics never trigger span building. Once built, the spans are authoritative.
    if row_data.spans.is_empty():
        return float(maxi(row_data.line_count, 1)) * line_height
    var max_line_index: int = 0
    for span in row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        max_line_index = maxi(max_line_index, int(metadata.get("line_index", 0)))
    return float((max_line_index + 1) * line_height)

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

func _collect_descendant_row_uids(row_data: EventRowData) -> Array:
    var uids: Array = []
    if row_data == null:
        return uids
    var stack: Array = row_data.children.duplicate()
    while not stack.is_empty():
        var child: EventRowData = stack.pop_back() as EventRowData
        if child == null:
            continue
        uids.append(child.row_uid)
        for grand_child in child.children:
            stack.append(grand_child)
    return uids

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
    return _drag_preview_helper.build_ace_drag_preview_rect(
        row_data,
        lane,
        ace_index,
        insert_mode,
        condition_lane_rect,
        action_lane_rect,
        _get_event_line_height(_get_font_size()),
        float(_get_event_style().action_lane_padding),
        float(_get_event_style().condition_lane_padding),
        _find_ace_span_index,
        _get_lane_ace_span_indices,
        _get_span_gap
    )

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

## Construct 3-style object label shown before each condition/action (e.g. "System",
## "Sprite", "CharacterBody2D"). Core ACEs read as "System"; node-typed ACEs use the class.
func _object_label_for(provider_id: String, ace_id: String) -> String:
    var definition: ACEDefinition = _find_definition(provider_id, ace_id)
    if definition != null:
        var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
        if not node_type.is_empty():
            return node_type
    if provider_id.is_empty() or provider_id == "Core":
        return "System"
    return provider_id

func _format_condition_descriptor(condition: ACECondition) -> String:
    var base_text: String = _format_condition_descriptor_base(condition)
    var ace_note: String = str(condition.comment).strip_edges()
    if not ace_note.is_empty():
        return "%s   ⊳ %s" % [base_text, ace_note]
    return base_text

func _format_condition_descriptor_base(condition: ACECondition) -> String:
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
    var base_text: String = _format_action_descriptor_base(action)
    var ace_note: String = str(action.comment).strip_edges()
    if not ace_note.is_empty():
        return "%s   ⊳ %s" % [base_text, ace_note]
    return base_text

func _format_action_descriptor_base(action: ACEAction) -> String:
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

func _get_scope_badge_colors(scope_label: String) -> Dictionary:
    if scope_label == "local":
        return {
            "bg": EventSheetPalette.COLOR_SCOPE_LOCAL_BADGE_BG,
            "fg": EventSheetPalette.COLOR_SCOPE_LOCAL_BADGE_FG
        }
    return {
        "bg": EventSheetPalette.COLOR_SCOPE_GLOBAL_BADGE_BG,
        "fg": EventSheetPalette.COLOR_SCOPE_GLOBAL_BADGE_FG
    }

static var _value_regex: RegEx = null

## Ranges ([start, length]) of parameter-like values (numbers, quoted strings, booleans)
## inside ACE display text, so the renderer can highlight them C3-style.
static func _value_ranges_for(text: String) -> Array:
    if _value_regex == null:
        _value_regex = RegEx.new()
        _value_regex.compile("\"[^\"]*\"|\\b-?\\d+(?:\\.\\d+)?\\b|\\b(?:true|false|True|False)\\b")
    var ranges: Array = []
    for regex_match in _value_regex.search_all(text):
        ranges.append([regex_match.get_start(), regex_match.get_end() - regex_match.get_start()])
    return ranges

func _make_span(text: String, span_type: int, metadata: Dictionary = {}) -> SemanticSpan:
    var span := SemanticSpan.new()
    span.text = text
    span.type = span_type
    span.metadata = metadata.duplicate(true)
    span.hoverable = bool(span.metadata.get("hoverable", true))
    # Precompute value-highlight ranges for condition/trigger/action text (single choke point;
    # build-time only, so the draw path stays cheap).
    if str(span.metadata.get("kind", "")) in ["condition", "trigger", "action"] and not text.is_empty():
        var ranges: Array = _value_ranges_for(text)
        if not ranges.is_empty():
            span.metadata["value_ranges"] = ranges
    return span

func _get_variable_metadata_for_row(row_data: EventRowData) -> Dictionary:
    if row_data == null:
        return {}
    for span in row_data.spans:
        if span == null or not (span.metadata is Dictionary):
            continue
        var metadata: Dictionary = span.metadata as Dictionary
        if str(metadata.get("kind", "")) == "variable":
            return metadata.duplicate(true)
    return {}

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
    # Persist onto the model so debug compiles (sheet.emit_breakpoints) see it.
    if row_data.source_resource is EventRow:
        (row_data.source_resource as EventRow).debug_break = row_data.breakpoint_enabled
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

# Cache: "provider::ace" → Texture2D or null. Spans are rebuilt often; icon resolution
# (registry lookup + editor-theme/texture fetch) must not run per rebuild per span.
var _ace_icon_cache: Dictionary = {}

## Icon shown before an ACE's object label in row cells (C3 shows the object's icon next
## to its name everywhere). Resolution order matches the picker; Core/System falls back to
## the editor's Tools glyph. Null (headless / nothing matches) keeps the text-only look.
func _object_icon_for(provider_id: String, ace_id: String) -> Texture2D:
    var cache_key: String = "%s::%s" % [provider_id, ace_id]
    if _ace_icon_cache.has(cache_key):
        return _ace_icon_cache[cache_key]
    var definition: ACEDefinition = _find_definition(provider_id, ace_id)
    if definition == null and not (provider_id.is_empty() or provider_id == "Core"):
        # Not cached: the registry refreshes in place (addons may not be loaded yet when
        # the first spans build), so a miss now can become a hit on the next rebuild.
        return null
    var icon: Texture2D = ACEPickerDialog.resolve_definition_icon(definition)
    if icon == null and (provider_id.is_empty() or provider_id == "Core"):
        icon = ACEPickerDialog.editor_icon("Tools")
    _ace_icon_cache[cache_key] = icon
    return icon

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
    return not _resolve_dropped_source_objects(data).is_empty() \
        or not _resolve_dropped_asset_paths(data).is_empty()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    # FileSystem asset drops carry intent: a scene or sound dropped ON an event row
    # becomes a pre-filled action (the dock builds it). Recognized assets are accepted
    # anywhere on the canvas so an empty-space drop can explain itself instead of
    # silently bouncing.
    var asset_paths: PackedStringArray = _resolve_dropped_asset_paths(data)
    if not asset_paths.is_empty():
        var row_index: int = _find_row_index_at_y(_at_position.y)
        var row_data: EventRowData = _row_at(row_index) if row_index >= 0 else null
        asset_dropped.emit(row_data.source_resource if row_data != null else null, asset_paths)
        return
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

## Scene/audio files in a FileSystem-dock drop payload — the asset kinds an event
## can act on directly (spawn / play).
static func _resolve_dropped_asset_paths(data: Variant) -> PackedStringArray:
    var assets: PackedStringArray = PackedStringArray()
    if data is Dictionary and str((data as Dictionary).get("type", "")) == "files":
        for file_path: Variant in ((data as Dictionary).get("files", []) as Array):
            if str(file_path).get_extension().to_lower() in ["tscn", "scn", "ogg", "wav", "mp3"]:
                assets.append(str(file_path))
    return assets

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
