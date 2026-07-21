@tool
class_name EventSheetViewport
extends Control

signal selection_changed(row_data: EventRowData)
signal row_drop_requested(source_row: EventRowData, target_row: EventRowData, drop_mode: String, copy_mode: bool)
signal variable_group_requested(source_row: EventRowData, target_row: EventRowData)
signal variable_group_rename_requested(group_name: String)
signal rows_drop_requested(source_rows: Array, target_row: EventRowData, drop_mode: String, copy_mode: bool)
signal ace_preview_requested(source_label: String, definitions: Array[ACEDefinition])
signal asset_dropped(target_event: Resource, asset_paths: PackedStringArray)
signal ace_picker_requested(row_data: EventRowData, lane: String)
signal span_edit_requested(row_data: EventRowData, edit_kind: String, old_value: String, new_value: String)
signal ace_edit_requested(row_data: EventRowData, span_index: int, metadata: Dictionary)
## The fastest gesture: double-click a highlighted VALUE inside an ACE to edit just
## that parameter (no full dialog). Emitted with the resolved ACE + param id.
signal param_value_edit_requested(ace: Resource, param_id: String, current_text: String)
signal param_value_edit_at_rect_requested(ace: Resource, param_id: String, current_text: String, anchor_screen: Rect2)
## Clicking the inline colour swatch on a condition/action cell - opens the colour picker (no dialog).
signal color_swatch_edit_requested(ace: Resource, param_id: String, current_color: Color)
## Dropping a scene-tree node onto a condition/action param VALUE - sets that param to the node reference.
signal param_node_drop_requested(ace: Resource, param_id: String, node_reference: String)
## Dropping an Inspector property onto the sheet - the dock builds a Set Property action
## (on the row it landed on, or as a new event) targeting that node + property.
signal property_dropped(target_event: Resource, node_reference: String, property_name: String, value_literal: String)
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
# The empty-state "New from template…" / "Create an event sheet…" CTA buttons - the dock opens
# its starter-template menu.
signal template_menu_requested
## Ctrl+Click on a cell the dock can resolve to a definition (see navigation_probe below).
signal navigate_requested(row_data: EventRowData, span_index: int, metadata: Dictionary)
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
## Emitted when a "With node X:" scope chip is double-clicked (the scoped event row).
signal with_node_edit_requested(event_row: Resource)
## Emitted when an enum row is double-clicked.
signal enum_edit_requested(enum_row: Resource)
signal custom_block_edit_requested(block_row: Resource)
## Emitted when a signal row is double-clicked.
signal signal_edit_requested(signal_row: Resource)
signal function_edit_requested(event_function: Resource)
## Emitted when a match action cell is double-clicked.
signal match_edit_requested(match_row: Resource)
## Emitted on Ctrl+/ - the dock toggles the selected rows' enabled state (undoable).
signal row_disable_toggle_requested()
## Emitted on Alt+Up/Down - the dock moves the selected row (direction -1 = up).
signal row_move_requested(direction: int)
# Delete / Backspace on the focused viewport. Emitted so the dock removes the selected rows / ACEs.
# Handled in _gui_input (not only the dock's _unhandled_key_input) so it wins Godot's input ordering
# and can never fall through to the editor's Scene-tree "delete node" shortcut.
signal delete_requested()
## Emitted on Ctrl+F - the dock shows the find bar.
signal find_requested()
## Emitted on F3 / Shift+F3 - the dock steps through find matches.
signal find_step_requested(direction: int)
## Emitted when the user finishes dragging the conditions/actions lane divider.
signal lane_ratio_changed(ratio: float)
## An object-column resize finished (lane is "condition" or "action"; width 0 restores flow).
## The dock persists it onto the sheet's editor style, like the lane ratio.
signal object_column_width_changed(lane: String, width: int)
## Emitted when a footer "Add event…" row is clicked. owner_resource is the EventGroup the
## event should be appended into, or the EventSheetResource for the sheet-end footer.
signal add_event_requested(owner_resource: Resource)
## Emitted when a GDScript block is double-clicked for editing. in_flow is true for blocks
## living inside an event's actions (statements), false for class-level tree blocks.
signal raw_code_edit_requested(raw_row: Resource, in_flow: bool)
## Emitted when a "Data class" block field's name / type / default value is double-clicked. The dock opens
## a one-field inline editor; committing re-emits the class from its model (parse_data_class -> mutate the
## field at field_index -> emit_data_class) into raw_row.code through the undo funnel. field_index is the
## field's index in the parsed model's body array; part is "name", "type" or "default".
signal data_class_field_edit_requested(raw_row: Resource, field_index: int, part: String, current_text: String)

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
## Comment text wraps to the row width and the row grows vertically so the whole note is
## readable (no more single-line clipping off the right edge). This is the narrowest the
## wrap column is ever allowed to get, so a very deep indent / narrow panel still wraps
## sanely instead of collapsing to one glyph per line.
const MIN_COMMENT_WRAP_WIDTH := 80.0
## Sheets with at most this many rows build all event spans up front (matching the
## original non-virtualized behavior exactly). Larger sheets keep spans lazy - built
## on demand during layout/hit/selection - so they load fast regardless of size.
const EAGER_SPAN_LIMIT := 1500

var _renderer: EventRowRenderer = EventRowRenderer.new()
var _layout_cache: RowLayoutCache = RowLayoutCache.new()
var _selection_helper: ViewportSelectionHelper = ViewportSelectionHelper.new()
var _hit_test_helper: ViewportHitTestHelper = ViewportHitTestHelper.new()
var _drag_preview_helper: ViewportDragPreviewHelper = ViewportDragPreviewHelper.new()
# The ROW-BUILDER layer: owns "model → SemanticSpans" construction (span assembly, per-ACE
# descriptors, non-event row builders). See interaction/viewport_row_builder.gd. The methods
# below keep one-line delegates so internal STAY callers and tests reach it by the original names.
var _row_builder: ViewportRowBuilder = ViewportRowBuilder.new()
var _folding: ViewportFolding = ViewportFolding.new()
var _layout_builder: ViewportLayoutBuilder = ViewportLayoutBuilder.new()
var _drag: ViewportDragInteractions = ViewportDragInteractions.new()
var _input_handlers: ViewportInputHandlers = ViewportInputHandlers.new()  # mouse/key handling behind _gui_input (interaction/viewport_input.gd)  # box selection + row/ACE drag gestures (interaction/viewport_drag.gd)  # per-row geometry pass (interaction/viewport_layout_builder.gd)  # fold gestures + region fold persistence (interaction/viewport_folding.gd)
var _ace_registry: EventSheetACERegistry = EventSheetACERegistry.new()
var _sheet: EventSheetResource = null
var _editor_style: EventSheetEditorStyle = EventSheetEditorStyle.new()
var _root_rows: Array[EventRowData] = []
var _flat_rows: Array[Dictionary] = []
var _selected_row_index: int = -1
var _selected_span_index: int = -1
var _selected_row_uids: Dictionary = {}
var _selected_span_indices: Dictionary = {}
## Rows that landed in `_selected_row_uids` purely because a span of theirs was Ctrl-toggled
## on (not via a whole-row select). Tracks selection provenance so that toggling the last span
## of such a row back off also releases the row from the row-selection set - otherwise the row
## stays phantom-selected (highlighted, drag/delete/edit-eligible) after the user deselects it.
var _span_only_row_uids: Dictionary = {}
var _hovered_row_index: int = -1
var _hovered_span_index: int = -1
var _hover_is_drag_zone: bool = false  # pointer over an event's empty lane band (the move-cursor grab zone)
var _editing_row_index: int = -1
var _editing_span_index: int = -1
var _editing_buffer: String = ""
var _editing_caret: int = 0
# Inline text selection (Shift+arrows / Ctrl+A while editing): -1 = none, else the
# selection spans anchor..caret. Comment rows get the floating BBCode format bar on it.
var _editing_select_anchor: int = -1
var _inline_format_bar: Control = null
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
# Per-function "Make Body Editable" opt-in for an OPENED behaviour pack, keyed by function name (a set;
# name -> true). Pure editor state - NEVER written to the .gd - so it survives the undo funnel's resource
# replacement (like _fold_state) and never affects the byte round-trip. An authored sheet ignores this
# (all its verb bodies are editable already); an opted-in verb's body becomes live and re-emits from its
# model, while every un-opted sibling stays inert and byte-identical. See _row_builder._function_body_editable.
var _editable_function_names: Dictionary = {}
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
# The full-sheet DIVIDER GUIDE (the Construct cue): the logical X of the column boundary under the
# pointer, or the one being dragged. Negative = none. A per-row divider only ever paints inside its own
# row band, so a boundary reads as a broken, dashed hint and the object-column boundary has no resting
# line at all - this draws ONE continuous line through the whole sheet instead, faint while hovering
# (so a grabbable boundary is discoverable) and solid while dragging (so the landing spot is exact).
var _divider_guide_x: float = -1.0
var _divider_guide_dragging: bool = false
# C3-style object-column resize: dragging the gap between an object name and its display text
# sets the lane's fixed object-column width ("condition"/"action"; "" = not dragging). The
# anchor is where the column starts (span x + icon advance) so width = cursor x - anchor.
var _dragging_object_column_lane: String = ""
var _object_column_drag_anchor_x: float = 0.0
const LANE_DIVIDER_GRAB_TOLERANCE := 5.0
## Event-sheet-style trailing "Add event…" footer rows (sheet-end and per-group). On by default;
## settable so headless tests can assert raw row counts/indices without the affordance
## shifting them, and so the dock can offer a "hide add-event rows" declutter option.
var show_add_event_footers: bool = true
## Object/module icons before names (rows + group folders). Toggleable (View menu) for users
## who prefer a text-only sheet; span builds read it, so flipping it rebuilds via set_sheet.
var show_object_icons: bool = true
## Event-sheet-style drag ghost: a faint label of the dragged content following the cursor.
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
	_row_builder.init(self)
	_folding.init(self)
	_layout_builder.init(self)
	_drag.init(self)
	_input_handlers.init(self)
	_row_metrics_helper.init(self)
	_live_values_helper.init(self)
	_tooltip_helper.init(self)
	_empty_state_helper.init(self)


func _ready() -> void:
	_configure_viewport()
	set_process(true)
	_refresh_rows()


func _process(_delta: float) -> void:
	if not _fired_intensity.is_empty():
		_decay_firing(_delta)
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
	_load_persisted_region_folds()
	_editor_style = _resolve_editor_style(sheet)
	_update_layout_style_signature(_get_font_size())
	_refresh_rows()


## True when the user has opted a specific verb (by function name) into body editing on an opened pack.
func is_function_body_editable_opt_in(function_name: String) -> bool:
	return _editable_function_names.has(function_name.strip_edges())


## Flips the per-function "Make Body Editable" opt-in for an opened pack and rebuilds so the verb's body
## rows switch between inert (read-only) and live (editable). Pure editor state - the .gd is untouched, so
## the flip alone never dirties the sheet; only a subsequent edit of the now-live body re-emits that verb.
func toggle_function_body_editable(function_name: String) -> void:
	var key: String = function_name.strip_edges()
	if key.is_empty():
		return
	if _editable_function_names.has(key):
		_editable_function_names.erase(key)
	else:
		_editable_function_names[key] = true
	_refresh_rows()


# ── Region fold persistence (editor state, NEVER the sheet's bytes) ────────────────────────────
# Folds are editor state, so they live in per-project editor metadata keyed by the
# sheet's path and the region's stable "label#occurrence" key - a fold survives
# closing and reopening the project without the .gd changing by a single byte.
# Guarded to the editor: headless runs (tests) seed persisted_region_folds directly.

## stable region key ("label#n") -> true, seeding fold defaults at pairing time.
## Session fold state (_fold_state, row-uid keyed) always wins over this layer.
var persisted_region_folds: Dictionary = {}


func _load_persisted_region_folds() -> void:
	_folding.load_persisted_region_folds()


func _persist_region_folds() -> void:
	_folding.persist_region_folds()


func region_fold_snapshot() -> Dictionary:
	return _folding.region_fold_snapshot()


func set_ace_registry(ace_registry: EventSheetACERegistry) -> void:
	if ace_registry == null:
		_ace_registry = EventSheetACERegistry.new()
	else:
		_ace_registry = ace_registry
	_row_builder._ace_icon_cache.clear()  # icons derive from definitions; a new registry invalidates them
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


## The ACE resource backing the selected span (condition/trigger/action), or null -
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
## The object-column boundary under the cursor, if any: {"lane": "condition"/"action",
## "anchor_x": float} or {} when not near one. The boundary of a span with a fixed column
## sits at anchor + column width; a flow-mode span's boundary sits right after its label,
## so grabbing THERE is how a fixed column is first created. Tolerance matches the lane
## divider's grab feel.
func object_column_boundary_hit(local_position: Vector2) -> Dictionary:
	var hit: Dictionary = _hit_test(local_position)
	var row_data: EventRowData = _row_at(int(hit.get("row_index", -1)))
	var span_index: int = int(hit.get("span_index", -1))
	if row_data == null or span_index < 0 or span_index >= row_data.spans.size():
		return {}
	var span: SemanticSpan = row_data.spans[span_index]
	if span == null or not (span.metadata is Dictionary):
		return {}
	var metadata: Dictionary = span.metadata as Dictionary
	var lane: String = str(metadata.get("lane", ""))
	if lane != "condition" and lane != "action":
		return {}
	if str(metadata.get("object_label", "")).is_empty():
		return {}
	var font: Font = _get_font()
	var font_size: int = _get_font_size()
	var anchor_x: float = span.rect.position.x
	# The renderer starts chip spans at rect.x + padding_x - mirror it or the resize
	# grab zone sits ~8px left of the drawn column boundary.
	if bool(metadata.get("chip", false)):
		anchor_x += float(metadata.get("padding_x", 0.0))
	if metadata.get("object_icon") is Texture2D:
		anchor_x += EventRowRenderer.OBJECT_ICON_ADVANCE
	var boundary_x: float = anchor_x
	var column_width: float = EventRowRenderer.object_column_width_for(_get_event_style(), lane)
	if column_width > 0.0:
		boundary_x += column_width
	else:
		boundary_x += font.get_string_size(str(metadata.get("object_label", "")) + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, _span_draw_font_size(span, font_size)).x
	if absf(local_position.x - boundary_x) > LANE_DIVIDER_GRAB_TOLERANCE:
		return {}
	# boundary_x rides along so the hover guide can draw ON the boundary rather than under the cursor.
	return {"lane": lane, "anchor_x": anchor_x, "boundary_x": boundary_x}


## Live object-column resize during the drag: width follows the cursor (clamped so the label
## never vanishes and the column never eats the lane). Same invalidation as the lane ratio -
## geometry changed, spans did not.
func _set_object_column_width_from_x(local_x: float) -> void:
	if _dragging_object_column_lane.is_empty():
		return
	var width: int = int(clampf(local_x - _object_column_drag_anchor_x, 24.0, 480.0))
	var event_style: EventSheetEventStyle = _get_event_style()
	if _dragging_object_column_lane == "condition":
		event_style.condition_object_column_width = width
	else:
		event_style.action_object_column_width = width
	# On the CLAMPED boundary, not the cursor, so the guide stops where the column stops.
	set_divider_guide(_object_column_drag_anchor_x + float(width), true)
	_update_layout_style_signature(_get_font_size())
	_layout_cache.clear()
	queue_redraw()


func _set_lane_ratio_from_x(local_x: float) -> void:
	var content_left: float = EventSheetPalette.GUTTER_WIDTH
	var content_width: float = max(_get_logical_canvas_width() - content_left, 120.0)
	_get_event_style().condition_lane_ratio = clampf((local_x - content_left) / content_width, 0.2, 0.8)
	# The guide follows the CLAMPED divider, not the raw cursor, so it stops where the lane actually
	# stops instead of sliding on past the 20%/80% limit.
	set_divider_guide(get_lane_divider_x(_get_logical_canvas_width()), true)
	_update_layout_style_signature(_get_font_size())
	_layout_cache.clear()
	queue_redraw()


## Positions the full-sheet divider guide. `dragging` paints it solid (a commitment to where the
## boundary lands); otherwise it is the faint hover cue that the boundary can be grabbed at all.
## Redraws only on an actual change, so plain mouse motion never thrashes the canvas.
func set_divider_guide(guide_x: float, dragging: bool) -> void:
	if is_equal_approx(_divider_guide_x, guide_x) and _divider_guide_dragging == dragging:
		return
	_divider_guide_x = guide_x
	_divider_guide_dragging = dragging
	queue_redraw()


func clear_divider_guide() -> void:
	set_divider_guide(-1.0, false)


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
	return "%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [
		int(round(_get_event_line_height(font_size))),
		event_style.minimum_conditions_lane_width,
		event_style.condition_lane_padding,
		event_style.condition_badge_column_width,
		event_style.action_lane_padding,
		event_style.lane_divider_width,
		int(round(event_style.condition_lane_ratio * 100.0)),
		event_style.condition_object_column_width,
		event_style.action_object_column_width,
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
	return _folding.toggle_row_fold_by_uid(row_uid)


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
## provenance - clicking generated code in the GDScript panel selects its sheet row.
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


## Selects every flat row whose source_resource is in the given array (the Select All
## Matching gesture): the first match anchors the selection like a click, the rest join
## as a multi-select (descendants included, matching shift/ctrl selection semantics).
func select_resources(resources: Array) -> int:
	# Membership as a set: Array.has is a linear scan, and this runs once per flat row -
	# on a big sheet with many matches that's rows x matches comparisons for one click.
	var wanted: Dictionary = {}
	for resource: Variant in resources:
		if resource != null:
			wanted[resource] = true
	var count: int = 0
	for index in range(_flat_rows.size()):
		var row_data: EventRowData = _row_at(index)
		if row_data == null or row_data.source_resource == null or not wanted.has(row_data.source_resource):
			continue
		if count == 0:
			_select_row(index, -1)
			ensure_selection_visible()
		else:
			_selected_row_uids[row_data.row_uid] = true
			for descendant_uid: Variant in _collect_descendant_row_uids(row_data):
				_selected_row_uids[str(descendant_uid)] = true
		count += 1
	# The renderer reads row_data.selected - re-stamp through the ONE shared helper (the
	# same one clicks and refreshes use), so stamping semantics can never drift here.
	_sync_row_selection_flags()
	queue_redraw()
	return count



## The keyboard cell walk (C3's arrow-through-cells): the selected row's ACE cells -
## trigger, conditions, actions - in span order. Left/Right move the cell focus through
## them; Enter (the existing handler) edits the focused cell; Esc drops back to the row.
func interactive_span_indices(row_data: EventRowData) -> Array[int]:
	var indices: Array[int] = []
	if row_data == null:
		return indices
	for span_index in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[span_index]
		if span != null and span.metadata is Dictionary and str(span.metadata.get("kind", "")) in ["trigger", "condition", "action"]:
			indices.append(span_index)
	return indices


## Moves the cell focus one ACE cell left/right within the selected row. Returns false
## when there is nothing to walk (no row, no cells, already at the end) so the caller can
## leave the key to its other meaning (fold/unfold).
func step_cell_focus(direction: int) -> bool:
	var row_data: EventRowData = _row_at(_selected_row_index)
	var cells: Array[int] = interactive_span_indices(row_data)
	if cells.is_empty():
		return false
	var position: int = cells.find(_selected_span_index)
	if position == -1:
		position = 0 if direction >= 0 else cells.size() - 1
	else:
		var stepped: int = position + signi(direction)
		if stepped < 0 or stepped >= cells.size():
			return false
		position = stepped
	_select_row(_selected_row_index, cells[position])
	queue_redraw()
	return true


## Whether plain Left should FOLD the selected row: it has something to fold AND no cell
## focus is active. With a cell focused, Left belongs to the cell walk (stepping back) -
## without this gate, walking into an unfolded parent's cells was a one-way trip: Right
## entered them but Left folded the row instead of stepping back.
func left_key_folds() -> bool:
	var row_data: EventRowData = _row_at(_selected_row_index)
	return row_data != null and not row_data.children.is_empty() and not row_data.folded and _selected_span_index < 0


## The Right-side mirror: plain Right UNFOLDS only at row scope. A folded parent still
## renders its own cells, so clicking one sets a span focus while the row stays folded -
## Right must then step the cell walk, not unfold the row out from under it.
func right_key_unfolds() -> bool:
	var row_data: EventRowData = _row_at(_selected_row_index)
	return row_data != null and not row_data.children.is_empty() and row_data.folded and _selected_span_index < 0


## Esc from a focused cell back to plain row selection. Returns false when no cell focus
## was active (so Esc keeps its other meanings - lens clear, dialog close).
func clear_cell_focus() -> bool:
	if _selected_row_index < 0 or _selected_span_index < 0:
		return false
	_select_row(_selected_row_index, -1)
	queue_redraw()
	return true


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
	# The span's TEXT draws after the object icon/label prefixes - hit-test against where the text
	# actually is, or clicks on values in labelled rows resolve against a rect shifted left by the
	# whole label width.
	var draw_font_size: int = _span_draw_font_size(span, font_size)
	var origin_x: float = _span_text_origin_x(span, font, font_size)
	for range_index in range(ranges.size()):
		var range_entry: Array = ranges[range_index]
		var start: int = int(range_entry[0])
		var length: int = int(range_entry[1])
		var prefix_width: float = font.get_string_size(span.text.substr(0, start), HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
		var value_width: float = font.get_string_size(span.text.substr(start, length), HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
		if logical_x >= origin_x + prefix_width and logical_x <= origin_x + prefix_width + value_width:
			var value_text: String = span.text.substr(start, length)
			var occurrence: int = 0
			for earlier_index in range(range_index):
				if span.text.substr(int(ranges[earlier_index][0]), int(ranges[earlier_index][1])) == value_text:
					occurrence += 1
			return [value_text, occurrence]
	return []


## Where the span's TEXT begins, in logical coordinates - the renderer indents it past the object
## icon and object label prefixes (matching _draw_spans' advances exactly). Shared by the value
## hit-test and the Param Hop cursor so their geometry can never drift from the draw.
func _span_text_origin_x(span: SemanticSpan, font: Font, font_size: int) -> float:
	var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
	var origin_x: float = span.rect.position.x
	# Chip spans draw their text padding_x inside the plate - the renderer starts at
	# rect.x + padding_x, so the hit-test must too or every value click lands ~8px left
	# of the value the user aimed at.
	if bool(metadata.get("chip", false)):
		origin_x += float(metadata.get("padding_x", 0.0))
	if metadata.get("object_icon") is Texture2D:
		origin_x += EventRowRenderer.OBJECT_ICON_ADVANCE
	var object_label: String = str(metadata.get("object_label", ""))
	if not object_label.is_empty():
		# Fixed object column (C3 sub-lane) advances by the column width; flow mode by the
		# label's own width - mirrors the renderer exactly.
		var object_column_width: float = EventRowRenderer.object_column_width_for(_get_event_style(), str(metadata.get("lane", "")))
		if object_column_width > 0.0:
			origin_x += object_column_width
		else:
			origin_x += font.get_string_size(object_label + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, _span_draw_font_size(span, font_size)).x
	return origin_x


func _span_draw_font_size(span: SemanticSpan, font_size: int) -> int:
	var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
	return EventSheetPalette.resolve_font_size(font_size, int(metadata.get("font_size_delta", 0)))


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

# ── Param scope (the Param Hop) ───────────────────────────────────────────────────────────────────
# A keyboard cursor over the SELECTED row's highlighted parameter values. Tab at row scope already
# means nest/outdent (the dock's structural key), so param scope is entered EXPLICITLY - Enter on a
# selected row that has values - and inside it Tab/Shift+Tab cycle values, Enter (or typing) opens the
# one-field editor anchored at the value, Esc drops back to row scope. The cursor is {entry_index}
# into _param_value_entries; it clears on any selection change or row rebuild (spans are replaced).
var _param_cursor: Dictionary = {}


func param_scope_active() -> bool:
	return not _param_cursor.is_empty()


func exit_param_scope() -> void:
	_param_cursor = {}
	queue_redraw()


## Every editable parameter VALUE on a row, in visual order: for each condition/trigger/action span,
## each highlighted range that maps back to a real param (template literals that aren't params are
## skipped). Entries: {span_index, range_index, text, occurrence, param_id, ace}.
func _param_value_entries(row_data: EventRowData) -> Array:
	var entries: Array = []
	if row_data == null or not (row_data.source_resource is EventRow):
		return entries
	for span_index in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[span_index]
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		var kind: String = str(metadata.get("kind", ""))
		if kind not in ["condition", "trigger", "action"]:
			continue
		var ranges: Array = metadata.get("value_ranges", [])
		if ranges.is_empty():
			continue
		var lane: String = "action" if kind == "action" else "condition"
		var ace: Resource = row_data.source_resource.trigger if kind == "trigger" \
				else _resolve_ace_resource(row_data.source_resource, lane, int(metadata.get("ace_index", -1)))
		if ace == null:
			continue
		for range_index in range(ranges.size()):
			var text: String = span.text.substr(int(ranges[range_index][0]), int(ranges[range_index][1]))
			var occurrence: int = 0
			for earlier_index in range(range_index):
				if span.text.substr(int(ranges[earlier_index][0]), int(ranges[earlier_index][1])) == text:
					occurrence += 1
			var param_id: String = param_id_for_value(ace, text, occurrence)
			if param_id.is_empty():
				continue
			entries.append({
				"span_index": span_index,
				"range_index": range_index,
				"text": text,
				"occurrence": occurrence,
				"param_id": param_id,
				"ace": ace,
			})
	return entries


## Enter param scope on the selected row (cursor on its first value). False when the row has none -
## the caller falls back to plain inline span editing, so Enter still works on comment/variable rows.
func enter_param_scope() -> bool:
	var entries: Array = _param_value_entries(_row_at(_selected_row_index))
	if entries.is_empty():
		return false
	_param_cursor = {"entry_index": 0}
	queue_redraw()
	return true


func _param_scope_step(delta: int) -> void:
	var entries: Array = _param_value_entries(_row_at(_selected_row_index))
	if entries.is_empty():
		exit_param_scope()
		return
	var index: int = (int(_param_cursor.get("entry_index", 0)) + delta) % entries.size()
	if index < 0:
		index += entries.size()
	_param_cursor = {"entry_index": index}
	queue_redraw()


func _param_cursor_entry() -> Dictionary:
	var entries: Array = _param_value_entries(_row_at(_selected_row_index))
	var index: int = int(_param_cursor.get("entry_index", -1))
	if index < 0 or index >= entries.size():
		return {}
	return entries[index]


## The Enter key, param-scope aware: inside scope it opens the editor on the cursor value; on a row
## with values it enters scope; otherwise it falls back to inline span editing. One funnel shared by
## the viewport's own key handler and the dock's unhandled-key fallback, so both Enters agree.
func handle_enter_key() -> bool:
	if param_scope_active():
		_open_param_cursor_editor()
		return true
	if enter_param_scope():
		return true
	return begin_edit_selected()


## Opens the shipped one-field editor on the cursor value, anchored at the value's on-screen rect
## (keyboard flow - the mouse is nowhere near the value).
func _open_param_cursor_editor() -> void:
	var entry: Dictionary = _param_cursor_entry()
	if entry.is_empty():
		return
	param_value_edit_at_rect_requested.emit(
		entry.get("ace"),
		str(entry.get("param_id")),
		str((entry.get("ace").get("params") as Dictionary).get(str(entry.get("param_id")), entry.get("text"))),
		_param_value_screen_rect(entry)
	)


## The cursor value's rect in screen coordinates (logical span rect + prefix measurement, zoomed,
## offset by the control's screen position). Builds the row layout on demand so span.rect is fresh.
func _param_value_screen_rect(entry: Dictionary) -> Rect2:
	var row_data: EventRowData = _row_at(_selected_row_index)
	if row_data == null:
		return Rect2()
	var font: Font = _get_font()
	var font_size: int = _get_font_size()
	_get_or_build_row_layout(_selected_row_index, _get_logical_canvas_width(), font, font_size)
	var local: Rect2 = _param_value_logical_rect(row_data, entry, font, font_size)
	var zoom: float = max(_zoom_factor, 0.001)
	# Headless/detached (tests): no window to be relative to - the zoomed local rect still carries
	# the size information the assertions care about.
	var origin: Vector2 = get_screen_position() if is_inside_tree() else Vector2.ZERO
	return Rect2(origin + local.position * zoom, local.size * zoom)


func _param_value_logical_rect(row_data: EventRowData, entry: Dictionary, font: Font, font_size: int) -> Rect2:
	var span_index: int = int(entry.get("span_index", -1))
	if span_index < 0 or span_index >= row_data.spans.size():
		return Rect2()
	var span: SemanticSpan = row_data.spans[span_index]
	var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
	var ranges: Array = metadata.get("value_ranges", [])
	var range_index: int = int(entry.get("range_index", -1))
	if range_index < 0 or range_index >= ranges.size():
		return Rect2()
	var draw_font_size: int = _span_draw_font_size(span, font_size)
	var text_x: float = _span_text_origin_x(span, font, font_size)
	var start: int = int(ranges[range_index][0])
	var length: int = int(ranges[range_index][1])
	var prefix_width: float = font.get_string_size(span.text.substr(0, start), HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
	var value_width: float = font.get_string_size(span.text.substr(start, length), HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
	return Rect2(text_x + prefix_width, span.rect.position.y, value_width, span.rect.size.y)


## The param cursor overlay: a soft accent box around the cursor value plus a muted param-name chip
## just below it - blind Tab-cycling with no name would read worse than the params dialog it replaces.
func _draw_param_cursor(font: Font, font_size: int) -> void:
	if not param_scope_active():
		return
	var row_data: EventRowData = _row_at(_selected_row_index)
	var entry: Dictionary = _param_cursor_entry()
	if row_data == null or entry.is_empty():
		return
	var rect: Rect2 = _param_value_logical_rect(row_data, entry, font, font_size).grow_individual(3.0, 1.0, 3.0, 1.0)
	if rect.size.x <= 0.0:
		return
	var accent: Color = _get_event_style().behavior_accent_color
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.16), true)
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.9), false, 1.0)
	var hint: String = str(entry.get("param_id"))
	var hint_size: int = maxi(font_size - 3, 9)
	var hint_width: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, hint_size).x
	var chip: Rect2 = Rect2(rect.position + Vector2(0.0, rect.size.y + 2.0), Vector2(hint_width + 10.0, font.get_height(hint_size) + 4.0))
	draw_rect(chip, Color(0.10, 0.11, 0.13, 0.92), true)
	draw_string(font, Vector2(chip.position.x + 5.0, chip.position.y + 2.0 + font.get_ascent(hint_size)), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, hint_size, EventSheetPalette.TEXT_MUTED)


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
	if row_data.source_resource is CommentRow:
		# Every comment edits through its dialog (text + colour), not a per-line inline caret.
		comment_edit_requested.emit(row_data.source_resource)
		return true
	_begin_edit(row_index, span_index)
	return true


# ── Event numbers (the C3 margin numbers; view-only, computed from the sheet) ──
## Shown in the gutter for event rows when on (View menu); the numbers come from the
## SHEET's order - flat and sequential through groups and sub-events - so folding or
## filtering never renumbers anything and "check event 34" stays stable.
var show_event_numbers: bool = true


## instance-id -> 1-based event number, walking the sheet the way C3 counts: every
## EventRow in order, descending into groups and sub-events. Pure and static.
static func event_numbers_for(entries: Array) -> Dictionary:
	var numbers: Dictionary = {}
	var counter: Dictionary = {"next": 1}
	_number_events(entries, numbers, counter)
	return numbers


static func _number_events(entries: Array, numbers: Dictionary, counter: Dictionary) -> void:
	for entry: Variant in entries:
		if entry is EventRow:
			numbers[(entry as EventRow).get_instance_id()] = int(counter["next"])
			counter["next"] = int(counter["next"]) + 1
			_number_events((entry as EventRow).sub_events, numbers, counter)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_number_events(group.events if not group.events.is_empty() else group.rows, numbers, counter)


## The EventRow carrying the given number ("Go to Event N"), or null.
static func event_by_number(entries: Array, number: int) -> EventRow:
	# The SAME walk order as event_numbers_for, but counting straight to the Nth event -
	# no whole-map allocation, no reverse value scan, no instance-id round-trip.
	if number < 1:
		return null
	var counter: Dictionary = {"next": 1}
	return _event_at_number(entries, number, counter)


static func _event_at_number(entries: Array, number: int, counter: Dictionary) -> EventRow:
	for entry: Variant in entries:
		if entry is EventRow:
			if int(counter["next"]) == number:
				return entry as EventRow
			counter["next"] = int(counter["next"]) + 1
			var in_subs: EventRow = _event_at_number((entry as EventRow).sub_events, number, counter)
			if in_subs != null:
				return in_subs
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			var in_group: EventRow = _event_at_number(group.events if not group.events.is_empty() else group.rows, number, counter)
			if in_group != null:
				return in_group
	return null


# ── Live filter lens (view-only; see _refresh_rows) ─────────────────────────────
var _lens_query: String = ""
var _lens_hidden_count: int = 0


## Applies (or with "" clears) the live filter lens: only top-level rows whose subtree
## mentions the term stay visible. View-layer only - the sheet is never mutated.
func set_lens(query: String) -> void:
	_lens_query = query.strip_edges()
	_refresh_rows()


func clear_lens() -> void:
	set_lens("")


func lens_active() -> bool:
	return not _lens_query.is_empty()


func lens_query() -> String:
	return _lens_query


func lens_hidden_count() -> int:
	return _lens_hidden_count


## Tree-wide search (the find bar's data source): walks the FULL row tree - including
## rows hidden inside folded groups - and returns matching source resources in order.
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
## case-insensitively - the find bar's data source.
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


## Removes every session bookmark (the panel's Clear All).
func clear_bookmarks() -> void:
	_bookmark_rows.clear()
	for index in range(_flat_rows.size()):
		var row_data: EventRowData = _row_at(index)
		if row_data != null:
			row_data.bookmark_enabled = false
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
		# Comments wrap to the canvas width, so a real width change means their heights (and
		# therefore the row layout) must be recomputed. Guard on the LOGICAL width so the
		# height-driven size changes _update_canvas_min_size() makes don't loop back in.
		if not _row_metrics_helper.is_empty() and absf(_get_logical_canvas_width() - _row_metrics_helper.metrics_width()) > 0.5:
			_rebuild_row_metrics()
			_layout_cache.clear()
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
	if _empty_state_helper.is_sheet_visually_empty():
		_empty_state_helper.draw_empty_state(width)
		return
	# Populated sheet: drop any button rects from a previous empty frame so they can't eat clicks.
	_empty_state_helper.clear_cta_rects()
	var visible_range: Vector2i = get_visible_row_range()
	if visible_range.x < 0:
		return
	var font: Font = _get_font()
	var font_size: int = _get_font_size()
	# Read once per frame, not per row: the flag is constant across the frame and a
	# dynamic control.get() per row is exactly the draw-loop lookup the repo rule forbids.
	_renderer.show_event_numbers = show_event_numbers
	for index in range(visible_range.x, visible_range.y + 1):
		var row_info: Dictionary = _flat_rows[index]
		var row_data: EventRowData = row_info.get("row")
		if row_data == null:
			continue
		var layout: Dictionary = _get_or_build_row_layout(index, width, font, font_size)
		_renderer.draw_row(self, layout, row_data, font, font_size, _editor_style)
		var row_rect: Rect2 = layout.get("rect", Rect2())
		_live_values_helper.draw_chip(row_data, row_rect.position.y, row_rect.size.y, font, font_size)
		# Drag-handle affordance: grip dots on the hovered row's left edge so reordering is
		# discoverable without being told. They brighten when the pointer is in the whole-event drag
		# zone (the empty lane band, not on an ACE cell) - the cue that "grab here to move the event".
		if index == _hovered_row_index and not _flat_rows.is_empty():
			var grip_color: Color = Color(1.0, 1.0, 1.0, 0.62 if _hover_is_drag_zone else 0.28)
			for dot_row in range(3):
				draw_circle(Vector2(row_rect.position.x + 5.0, row_rect.position.y + row_rect.size.y * 0.5 + (dot_row - 1) * 5.0), 1.4, grip_color)
	_draw_variable_group_bubbles(width)
	_draw_region_bubbles(width)
	_draw_box_selection_overlay()
	_draw_divider_guide(width)
	_draw_param_cursor(font, font_size)
	_draw_drag_ghost(font, font_size)


## The full-sheet DIVIDER GUIDE: one continuous vertical line at the column boundary under the pointer,
## or the one being dragged - the Construct cue. Per-row dividers only paint inside their own row band,
## so a boundary reads as a broken dashed hint, and the object-column boundary draws nothing at all at
## rest; a single line spanning the whole canvas makes it obvious where the split IS and where a drag
## will leave it. Faint while hovering (discoverable, not loud), solid and wider while dragging, with a
## soft halo so it stays readable over both lane fills. Drawn over the rows, under the drag ghost.
func _draw_divider_guide(width: float) -> void:
	if _divider_guide_x < 0.0 or _divider_guide_x > width:
		return
	var accent: Color = _get_event_style().behavior_accent_color
	# Span the taller of the viewport and the content, so the line reaches the bottom on a short sheet
	# AND stays full-height while scrolled through a long one.
	var height: float = maxf(size.y / max(_zoom_factor, 0.001), _row_metrics_helper.total_height())
	var line_width: float = 2.0 if _divider_guide_dragging else 1.0
	var line_alpha: float = 0.9 if _divider_guide_dragging else 0.4
	if _divider_guide_dragging:
		draw_rect(Rect2(_divider_guide_x - 3.0, 0.0, 6.0, height), Color(accent.r, accent.g, accent.b, 0.14), true)
	draw_line(
		Vector2(_divider_guide_x, 0.0),
		Vector2(_divider_guide_x, height),
		Color(accent.r, accent.g, accent.b, line_alpha),
		line_width
	)


## The variable-folder bubbles: one rounded outline + soft tint around each run of consecutive
## variable rows sharing an Inspector group, so a grouped set reads as ONE visual folder (the
## Discord-folder look) instead of rows that merely repeat a chip. Drawn OVER the rows (their
## alternating backgrounds are opaque), so the tint stays faint enough to never fight the text.
func _draw_variable_group_bubbles(width: float) -> void:
	var runs: Array = ViewportRowBuilder.variable_group_runs(_flat_rows)
	if runs.is_empty():
		return
	var bubble: StyleBoxFlat = StyleBoxFlat.new()
	bubble.bg_color = Color(EventSheetPalette.COLOR_CAT_CHIP_BG.r, EventSheetPalette.COLOR_CAT_CHIP_BG.g, EventSheetPalette.COLOR_CAT_CHIP_BG.b, 0.16)
	bubble.border_color = Color(EventSheetPalette.COLOR_CAT_CHIP_FG.r, EventSheetPalette.COLOR_CAT_CHIP_FG.g, EventSheetPalette.COLOR_CAT_CHIP_FG.b, 0.55)
	bubble.set_border_width_all(1)
	bubble.set_corner_radius_all(7)
	for run: Dictionary in runs:
		var start_index: int = int(run.get("start"))
		var end_index: int = int(run.get("end"))
		var top: float = _get_row_top(start_index)
		var bottom: float = _get_row_top(end_index) + _get_row_height(end_index)
		bubble.draw(get_canvas_item(), Rect2(3.0, top + 1.0, width - 6.0, bottom - top - 2.0))


## The region bubbles: a THIN rounded outline around each unfolded #region range
## (the opening fence through the closing fence) - the same Discord-bubble look the
## variable folders use, outline-only so the enclosed rows keep their own colors.
## Nested regions draw nested bubbles (each opener draws its own), and the left edge
## insets with the opener's indent so a region inside a group hugs its lane.
func _draw_region_bubbles(width: float) -> void:
	# While a row/ACE drag is live, the range the pointer would drop INTO glows so
	# "this lands inside the region" is visible before the drop.
	var drag_target: int = -1
	if _drag_row_index >= 0 and _drag_target_index >= 0:
		drag_target = _drag_target_index
	elif not _drag_ace_entries.is_empty() and _drag_ace_target_row_index >= 0:
		drag_target = _drag_ace_target_row_index
	for index in range(_flat_rows.size()):
		var row_data: EventRowData = _flat_rows[index].get("row")
		if row_data == null or row_data.folded or row_data.children.is_empty():
			continue
		if not _row_builder._is_region_row(row_data):
			continue
		var last_index: int = index + _visible_descendant_count(row_data)
		if last_index <= index or last_index >= _flat_rows.size():
			continue
		# The region's own color wins (editable via the fence's edit dialog);
		# the theme's behavior accent is the default.
		var accent: Color = _get_event_style().behavior_accent_color
		var custom_color: String = str(((row_data.source_resource as CustomBlockRow).fields as Dictionary).get("color", "")).strip_edges()
		if Color.html_is_valid(custom_color):
			accent = Color.html(custom_color)
		var glowing: bool = drag_target > index and drag_target <= last_index + 1
		var bubble: StyleBoxFlat = StyleBoxFlat.new()
		bubble.bg_color = Color(accent.r, accent.g, accent.b, 0.07) if glowing else Color(0.0, 0.0, 0.0, 0.0)
		bubble.border_color = Color(accent.r, accent.g, accent.b, 1.0 if glowing else 0.65)
		# Region border thickness + corner rounding are theme tokens; a drag target reads one pixel
		# thicker. Defaults (width 1, radius 7) reproduce the previous hardcoded look.
		var region_line: int = _get_event_style().region_line_width
		bubble.set_border_width_all(region_line + 1 if glowing else region_line)
		bubble.set_corner_radius_all(_get_event_style().region_corner_radius)
		var left: float = 3.0 + float(row_data.indent * INDENT_WIDTH)
		var top: float = _get_row_top(index)
		var bottom: float = _get_row_top(last_index) + _get_row_height(last_index)
		bubble.draw(get_canvas_item(), Rect2(left, top + 1.0, width - left - 3.0, bottom - top - 2.0))


## Folds or unfolds every paired region in one step (Command Palette: Fold All
## Regions / Unfold All Regions). include_groups extends the sweep to event
## groups for the whole-sheet Fold Everything command.
func set_region_folds(folded: bool, include_groups: bool = false) -> void:
	_folding.set_region_folds(folded, include_groups)


func _enclosing_region_flat_index(flat_index: int) -> int:
	return _folding.enclosing_region_flat_index(flat_index)


func _visible_descendant_count(row_data: EventRowData) -> int:
	return _folding.visible_descendant_count(row_data)


func _draw_drag_ghost(font: Font, font_size: int) -> void:
	_drag.draw_drag_ghost(font, font_size)



func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		return
	if event is InputEventKey:
		_handle_key(event as InputEventKey)

# The dock installs this probe: (row_data, span_metadata) -> bool, true when Ctrl+Clicking that cell
# can jump somewhere real (e.g. a behaviour-pack verb opens its behaviour as a sheet). Kept as a probe
# so cells with no jump target keep Ctrl+Click's multi-select meaning.
var navigation_probe: Callable = Callable()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	_input_handlers.handle_mouse_motion(event)



func _handle_mouse_button(event: InputEventMouseButton) -> void:
	_input_handlers.handle_mouse_button(event)



func _begin_box_selection(position: Vector2, additive: bool) -> void:
	_drag.begin_box_selection(position, additive)



func _complete_box_selection() -> void:
	_drag.complete_box_selection()



func _draw_box_selection_overlay() -> void:
	_drag.draw_box_selection_overlay()



func _apply_box_selection(selection_rect: Rect2, additive: bool) -> void:
	_drag.apply_box_selection(selection_rect, additive)



func _is_selection_hit(row_index: int, span_index: int) -> bool:
	return _drag.is_selection_hit(row_index, span_index)



## True when a hover/press landed on an EVENT row but NOT on one of its ACE cells (span_index < 0) -
## the empty band of the condition/action lane below the cells. A press there begins a whole-event
## drag (reorder / nest), so this drives the move-cursor affordance AND the "grab here" hover. Pure,
## so it is unit-testable without a live viewport. Groups/comments/variables aren't included: they're
## single-cell rows with no ambiguous empty band.
static func is_event_drag_zone(row_data: EventRowData, span_index: int) -> bool:
	# A published verb (Define) row lays out as an EVENT row but is a pure READ view of sheet.functions -
	# its order IS the file's emission order, so it is never a drag handle.
	return (
		row_data != null
		and row_data.row_type == EventRowData.RowType.EVENT
		and not (row_data.source_resource is EventFunction)
		and span_index < 0
	)


func _begin_row_drag(row_index: int) -> void:
	_drag.begin_row_drag(row_index)



func _row_ghost_label(row_data: EventRowData) -> String:
	return _drag.row_ghost_label(row_data)



func _clear_row_drag() -> void:
	_drag.clear_row_drag()



func _maybe_begin_ace_drag(hit: Dictionary, row_index: int) -> bool:
	return _drag.maybe_begin_ace_drag(hit, row_index)



func _clear_ace_drag() -> void:
	_drag.clear_ace_drag()



func _clear_drag_feedback() -> void:
	_drag.clear_drag_feedback()



func _update_ace_drag_target(hit: Dictionary, position: Vector2) -> void:
	_drag.update_ace_drag_target(hit, position)



func _complete_ace_drag() -> bool:
	return _drag.complete_ace_drag()



func _handle_key(event: InputEventKey) -> void:
	_input_handlers.handle_key(event)



func _handle_editing_key(event: InputEventKey) -> void:
	_input_handlers.handle_editing_key(event)



func _refresh_rows() -> void:
	# Spans are rebuilt below; a param cursor into the old spans would dangle.
	_param_cursor = {}
	_root_rows = _build_rows_from_sheet(_sheet)
	_update_layout_style_signature(_get_font_size())
	_flat_rows.clear()
	# Live filter lens (the C3 "show only matching events" view): a non-mutating view
	# predicate - top-level rows whose subtree never mentions the term are skipped at
	# flatten time (the sheet itself is untouched; clearing the lens restores everything).
	_lens_hidden_count = 0
	var visible_roots: Array = _root_rows
	if not _lens_query.is_empty():
		visible_roots = []
		var lens_needle: String = _lens_query.to_lower()
		for root_candidate: EventRowData in _root_rows:
			var lens_matches: Array[Resource] = []
			_search_row_tree(root_candidate, lens_needle, lens_matches)
			if lens_matches.is_empty():
				# The count reports hidden EVENTS (what the user cares about); structural
				# rows (variable headers, spacers) hide silently alongside them.
				if root_candidate.source_resource is EventRow or root_candidate.source_resource is EventGroup:
					_lens_hidden_count += 1
			else:
				visible_roots.append(root_candidate)
	for row_data in visible_roots:
		_flatten_row(row_data, null)
	# Small/medium sheets build all spans up front (before metrics) so behavior is
	# byte-identical to the non-virtualized path. Large sheets keep spans lazy.
	if _flat_rows.size() <= EAGER_SPAN_LIMIT:
		for entry in _flat_rows:
			_ensure_event_spans(entry.get("row"))
	_rebuild_row_metrics()
	var event_numbers: Dictionary = event_numbers_for(_sheet.events if _sheet != null else [])
	for index in range(_flat_rows.size()):
		var line_row: EventRowData = _flat_rows[index].get("row")
		if line_row == null:
			continue
		line_row.line_number = index + 1
		line_row.event_number = int(event_numbers.get(line_row.source_resource.get_instance_id(), 0)) if line_row.source_resource != null else 0
		if _breakpoint_rows.has(line_row.row_uid):
			line_row.breakpoint_enabled = bool(_breakpoint_rows[line_row.row_uid])
		line_row.bookmark_enabled = _bookmark_rows.has(line_row.row_uid)
		if _row_disabled_state.has(line_row.row_uid):
			line_row.disabled = bool(_row_disabled_state[line_row.row_uid])
	if _selected_row_index >= _flat_rows.size():
		_selected_row_index = _flat_rows.size() - 1
	# Re-derive the caret from the SELECTION when they disagree: after a delete/undo/fold the
	# numeric index can land on a row that isn't selected, so arrow keys and single-key verbs
	# then acted on a different row than the highlight showed. Keep the index when it already
	# points at a selected row (multi-select caret position is meaningful); otherwise snap it
	# to the first selected row.
	if not _selected_row_uids.is_empty():
		var caret_row: EventRowData = _flat_rows[_selected_row_index].get("row") if _selected_row_index >= 0 and _selected_row_index < _flat_rows.size() else null
		if caret_row == null or not _selected_row_uids.has(caret_row.row_uid):
			for index in range(_flat_rows.size()):
				var candidate: EventRowData = _flat_rows[index].get("row")
				if candidate != null and _selected_row_uids.has(candidate.row_uid):
					_selected_row_index = index
					break
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
	# Per-sweep class-uid counters: same-named class blocks suffix "-2"/"-3" in build order.
	# Reset HERE (not lazily) so the suffixes stay stable across rebuilds.
	_row_builder._class_uid_counts.clear()
	if sheet == null:
		return root_rows
	root_rows.append_array(_build_global_variable_rows(sheet))
	# Blocks spec P1 - collapse the LEADING run of class scaffolding (prelude / annotations /
	# host-binding) into one foldable "Class setup" strip, so an opened .gd reads as logic, not
	# boilerplate. The threshold is LINE-based, not row-based: the importer bundles a whole prelude into
	# ONE multi-line RawCodeRow, so requiring ≥3 boilerplate lines (rather than ≥2 rows) is what makes the
	# strip actually fire on real opened .gd files. The detector is conservative so real logic is never
	# swept in. Pure editor view-state: the underlying RawCodeRows are unchanged + still selected/edited
	# normally as the strip's children. Measure the run first (cheap, no row build) so a sub-threshold
	# prelude isn't built twice.
	var scaffold_end: int = 0
	var scaffold_lines: int = 0
	while scaffold_end < sheet.events.size() \
			and sheet.events[scaffold_end] is RawCodeRow \
			and is_scaffolding_code((sheet.events[scaffold_end] as RawCodeRow).code):
		scaffold_lines += maxi((sheet.events[scaffold_end] as RawCodeRow).code.split("\n").size(), 1)
		scaffold_end += 1
	var event_start: int = 0
	if scaffold_lines >= 3:
		var scaffold_rows: Array[EventRowData] = []
		for scaffold_index in range(scaffold_end):
			# Build children through the shared dispatcher (not _build_raw_code_row directly) so a
			# compile-error marker on a prelude block survives into the strip instead of being dropped.
			var child: EventRowData = _build_row_from_resource(sheet.events[scaffold_index], 1)
			if child != null:
				scaffold_rows.append(child)
		if not scaffold_rows.is_empty():
			root_rows.append(_build_scaffolding_strip_row(sheet, scaffold_rows))
			event_start = scaffold_end
	for entry_index in range(event_start, sheet.events.size()):
		var entry: Resource = sheet.events[entry_index]
		# A lifted MID-FILE function emits at its anchor slot, so the canvas splices the whole verb block
		# in HERE too: the vocabulary reads where it actually lives in the file instead of being hoisted
		# above everything. A missing verb keeps the anchor's muted "defined here" stub as the fallback.
		if entry is FunctionAnchorRow:
			var anchored: EventFunction = ViewportRowBuilder.find_function_by_name(
				sheet, (entry as FunctionAnchorRow).function_name
			)
			if anchored != null:
				root_rows.append_array(_row_builder.build_verb_block_rows(anchored, 0))
				continue
		var row_data: EventRowData = _build_row_from_resource(entry, 0)
		if row_data != null:
			root_rows.append(row_data)
	# Pair #region/#endregion fences into foldable ranges (view layer only; the
	# data model and emission stay flat). Runs before the footer so the trailing
	# "Add event…" row can never be swallowed by an unclosed fence.
	root_rows = _row_builder._pair_region_fences(root_rows)
	# The remaining verbs, in sheet.functions order - the compiler's trailing-functions section mirrored,
	# so a behaviour pack reads events-then-vocabulary exactly like its .gd. After the fence pairing (an
	# unclosed #region must not swallow the vocabulary) and before the footer.
	root_rows.append_array(_row_builder.build_trailing_verb_rows(sheet))
	# Verbs open by default; this re-folds only the ones the fence pairing just moved inside a #region
	# (or that sit inside a group), where the enclosing block owns the fold.
	_row_builder.fold_nested_verb_rows(root_rows)
	# Event-sheet-style trailing "Add event…" footer at the end of the sheet.
	if show_add_event_footers:
		root_rows.append(_build_add_event_footer_row(sheet, 0, "+ Add event…"))
	return root_rows


## A synthetic, foldable header that collapses a run of class-scaffolding rows (its children) into one
## line. source_resource stays null so selection / delete / drag treat the header as inert (like the
## add-event footer); the real RawCodeRows live on as its children and edit exactly as before. Folded by
## default (boilerplate hidden) yet session-remembered via _fold_state, behind a clear "Class setup" label
## with the line count - discoverable, one click to expand. The existing fold machinery (children +
## _flatten_row + the fold arrow, all gated on `children`, not row_type) drives the collapse for free.
func _build_scaffolding_strip_row(sheet: EventSheetResource, scaffold_rows: Array[EventRowData]) -> EventRowData:
	return _row_builder._build_scaffolding_strip_row(sheet, scaffold_rows)


## True for the synthetic "Class setup" header built above: a null-source SECTION row whose uid marks it
## as the scaffolding strip. Used to keep it inert for selection/delete (it owns no resource of its own -
## its children do), while still allowing the fold arrow (which is gated only on `children`).
func _is_synthetic_scaffolding_strip(row_data: EventRowData) -> bool:
	return row_data != null and row_data.source_resource == null and row_data.row_uid.begins_with("scaffolding_strip_")


## A clickable footer row that appends a new event into owner_resource (a group or the
## sheet). source_resource stays null on purpose so selection/delete/drag paths (which act on
## the source resource) treat it as inert; the owner travels in span metadata instead.
func _build_add_event_footer_row(owner_resource: Resource, indent: int, label: String) -> EventRowData:
	return _row_builder._build_add_event_footer_row(owner_resource, indent, label)


func _row_is_add_event_footer(row_data: EventRowData) -> bool:
	return row_data != null and row_data.row_uid.begins_with("add_event_footer_")


## First Color(...) literal among an ACE's param values (null when none) - drives the
## little color swatch drawn after the condition/action text.
func _first_color_in_params(ace: Resource) -> Variant:
	return _row_builder._first_color_in_params(ace)


## The param KEY holding that first Color literal ("" when none) - needed to write a picked colour back.
func _first_color_param_id(ace: Resource) -> String:
	var params: Variant = ace.get("params")
	if not (params is Dictionary):
		return ""
	for key: Variant in (params as Dictionary).keys():
		var value: Variant = (params as Dictionary)[key]
		if value is String and (value as String).strip_edges().begins_with("Color(") and str_to_var((value as String).strip_edges()) is Color:
			return str(key)
	return ""

# uid (str instance id) -> error message, from set_row_diagnostics(). Re-applied to row_data
# on every rebuild so the marker survives edits/scrolling (the "error → row" deep-link).
var _row_diagnostics: Dictionary = {}
var _first_diagnostic_uid: String = ""
# Live event trace: uid set of events that fired in the latest streamed frame (transient highlight).
var _fired_uids: Dictionary = {}
# uid -> pulse intensity (1.0 on fire, decayed toward 0 in _process) - the fade that makes
# a fire read as a flash instead of a hard blink.
var _fired_intensity: Dictionary = {}
const FIRING_FADE_SECONDS := 0.6


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
	elif entry is CustomBlockRow:
		row_data = _row_builder._build_custom_block_row(entry as CustomBlockRow, indent)
	elif entry is FunctionAnchorRow:
		row_data = _row_builder._build_function_anchor_row(entry as FunctionAnchorRow, indent)
	elif entry is EventRow:
		row_data = _build_event_row(entry as EventRow, indent)
	if row_data != null and not _row_diagnostics.is_empty():
		row_data.error_message = str(_row_diagnostics.get(str(entry.get_instance_id()), ""))
	if row_data != null and entry is EventRow and (not _fired_uids.is_empty() or not _fired_intensity.is_empty()):
		row_data.firing = _fired_uids.has((entry as EventRow).event_uid)
		row_data.firing_intensity = float(_fired_intensity.get((entry as EventRow).event_uid, 0.0))
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
		_fired_intensity[uid] = 1.0
	_apply_firing_to_rows()
	queue_redraw()


## Fades every pulse toward 0 and repaints while any is alive; an event still firing gets
## re-bumped to 1.0 by each streamed batch, so sustained fire holds near full glow while a
## stopped one fades out over FIRING_FADE_SECONDS.
func _decay_firing(delta: float) -> void:
	var faded: Array = []
	for uid: Variant in _fired_intensity:
		var next_intensity: float = float(_fired_intensity[uid]) - delta / FIRING_FADE_SECONDS
		if next_intensity <= 0.0:
			faded.append(uid)
		else:
			_fired_intensity[uid] = next_intensity
	for uid: Variant in faded:
		_fired_intensity.erase(uid)
	_apply_firing_to_rows()
	queue_redraw()


func _apply_firing_to_rows() -> void:
	for entry: Dictionary in get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is EventRow:
			var uid: String = (row_data.source_resource as EventRow).event_uid
			row_data.firing = _fired_uids.has(uid)
			row_data.firing_intensity = float(_fired_intensity.get(uid, 0.0))


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
	return _row_builder._build_enum_row(enum_row, indent)


## A signal row: rendered like a declaration ("signal  hit(damage: int)"); double-click
## opens the signal dialog.
func _build_signal_row(signal_row: SignalRow, indent: int) -> EventRowData:
	return _row_builder._build_signal_row(signal_row, indent)


## True when a top-level GDScript block is pure class SCAFFOLDING - the structural boilerplate a
## behaviour / custom-node / family sheet always carries (class prelude, `## …` doc + `## @ace_*`
## annotations, the generated host-binding `_enter_tree`, blank separators) rather than game LOGIC.
## Drives both type-aware styling (scaffolding rendered muted) and the leading-run collapse below, so an
## opened .gd reads as logic instead of boilerplate. Pure + static so the classification is unit-testable
## without standing up the viewport. CONSERVATIVE by design: any line that isn't recognizably scaffolding
## makes the whole block "logic", so real code is never mistaken for boilerplate and hidden.
static func is_scaffolding_code(code: String) -> bool:
	for raw_line: String in code.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue  # blank separator
		# Prelude declarations + any doc/annotation comment (`##`, `## @ace_*`).
		if line.begins_with("class_name ") or line.begins_with("extends ") \
				or line.begins_with("@icon") or line.begins_with("@tool") or line.begins_with("##"):
			continue
		# The generated host binding (behaviour sheets): `func _enter_tree(): host = get_parent() as X`.
		if line.begins_with("func _enter_tree") or line.begins_with("host = get_parent"):
			continue
		return false  # any other statement is real content → treat the whole block as logic
	return true


## A GDScript block row: verbatim code shown line-by-line, edited via the dock's code dialog
## (double-click), compiled at class level. The event-sheet-style "inline code" escape hatch.
func _build_raw_code_row(raw_row: RawCodeRow, indent: int) -> EventRowData:
	return _row_builder._build_raw_code_row(raw_row, indent)


## Builds a row for a variable placed directly in the event tree (movable like an event).
func _build_tree_variable_row(variable: LocalVariable, indent: int) -> EventRowData:
	return _row_builder._build_tree_variable_row(variable, indent)


func _build_group_row(group: EventGroup, indent: int) -> EventRowData:
	return _row_builder._build_group_row(group, indent)


func _build_comment_row(comment_row: CommentRow, indent: int) -> EventRowData:
	return _row_builder._build_comment_row(comment_row, indent)


func _build_event_row(event_row: EventRow, indent: int) -> EventRowData:
	return _row_builder._build_event_row(event_row, indent)


func _build_global_variable_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	return _row_builder._build_global_variable_rows(sheet)


func _build_local_variable_rows(event_row: EventRow, indent: int) -> Array[EventRowData]:
	return _row_builder._build_local_variable_rows(event_row, indent)


func _build_event_spans(event_row: EventRow) -> Array[SemanticSpan]:
	return _row_builder._build_event_spans(event_row)


func _count_event_lines(event_row: EventRow) -> int:
	return _row_builder._count_event_lines(event_row)


func _ensure_event_spans(row_data: EventRowData) -> void:
	_row_builder._ensure_event_spans(row_data)


func _measure_span_width(span: SemanticSpan, display_text: String, font: Font, font_size: int) -> float:
	return _row_builder._measure_span_width(span, display_text, font, font_size)


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
	return _layout_builder.get_or_build_row_layout(index, width, font, font_size)


## Identity context for the pinned column header: behavior sheets show their host class so
## it is always visible what the conditions/actions act on.
func get_host_context_label() -> String:
	if _sheet != null and _sheet.behavior_mode:
		return " - host: %s" % _sheet.host_class
	return ""

# ── Row metrics (per-row top/height vertical layout; see ViewportRowMetrics) ──
var _row_metrics_helper: ViewportRowMetrics = ViewportRowMetrics.new()

# ── Live values (rung 3): inline chips next to variable rows (see ViewportLiveValuesHelper) ──
var _live_values_helper: ViewportLiveValuesHelper = ViewportLiveValuesHelper.new()

# ── Hover tooltips (ACE/function descriptions + GDScript codegen preview; see ViewportTooltipHelper) ──
var _tooltip_helper: ViewportTooltipHelper = ViewportTooltipHelper.new()

# ── Empty state (getting-started overlay drawn over a sheet with no authored rows; see ViewportEmptyStateHelper) ──
var _empty_state_helper: ViewportEmptyStateHelper = ViewportEmptyStateHelper.new()


## Streamed name->value frame (debug runs). Redraws value chips on variable rows.
func set_live_values(values: Dictionary) -> void:
	_live_values_helper.set_live_values(values)


## The "= value" chip for a row, or "" (variable rows whose name has a live frame).
func live_value_chip_for(row_data: EventRowData) -> String:
	return _live_values_helper.chip_for(row_data)


func _update_canvas_min_size() -> void:
	var zoom: float = max(_zoom_factor, 0.001)
	var canvas_width: float = max(_get_scroll_width(), 640.0 * zoom)
	var total_height: float = _row_metrics_helper.total_height()
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
	# The param cursor is bound to the previously selected row's values - moving selection drops it.
	_param_cursor = {}
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


## Select every row between the selection anchor and target_index (inclusive) - the Shift+click /
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
			# whole-row selected), removing its last span must release the row too -
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
			# so drop any span-only provenance - they must survive a later span on/off toggle.
			_selected_row_uids[row_uid] = true
			_span_only_row_uids.erase(row_uid)
			# The synthetic "Class setup" strip is an inert view-only header (null source): selecting it
			# must NOT cascade-select its prelude children, or pressing Delete would silently wipe
			# class_name/extends/annotations (when expanded) or no-op confusingly (when folded). Expand it
			# and select an individual block to act on the prelude.
			if not row_data.children.is_empty() and not _is_synthetic_scaffolding_strip(row_data):
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
	_folding.toggle_row_fold(row_index)


func _begin_edit(row_index: int, span_index: int) -> void:
	if companion_mode:
		return
	var row_data: EventRowData = _row_at(row_index)
	if row_data == null:
		return
	# Group headers edit through a popup (name + description), not an inline title field - so the
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
	_editing_select_anchor = -1
	_update_inline_format_bar()
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
	_editing_select_anchor = -1
	_update_inline_format_bar()
	_refresh_rows()


func _cancel_edit() -> void:
	_editing_row_index = -1
	_editing_span_index = -1
	_editing_buffer = ""
	_editing_caret = 0
	_editing_select_anchor = -1
	_update_inline_format_bar()
	queue_redraw()


# ── Inline text selection + the floating BBCode bar (comment rows) ─────────────────
# The inline span editor is custom-drawn (no Control), so it carries its own tiny
# selection model: Shift+Left/Right extends anchor..caret, Ctrl+A selects all, and on
# COMMENT rows the same Discord-style bar the comment dialog uses floats above the
# selection to toggle BBCode wraps.


func _editing_has_selection() -> bool:
	return _editing_row_index >= 0 and _editing_select_anchor >= 0 and _editing_select_anchor != _editing_caret


func _editing_selection_range() -> Vector2i:
	return Vector2i(mini(_editing_select_anchor, _editing_caret), maxi(_editing_select_anchor, _editing_caret))


func _delete_editing_selection() -> void:
	if not _editing_has_selection():
		return
	var span_range: Vector2i = _editing_selection_range()
	_editing_buffer = _editing_buffer.substr(0, span_range.x) + _editing_buffer.substr(span_range.y)
	_editing_caret = span_range.x
	_editing_select_anchor = -1


## Toggle-wraps the inline selection in BBCode (same semantics as the comment dialog's
## bar: an exactly-wrapped selection unwraps; the result stays selected so formats stack).
func _wrap_editing_selection(open_tag: String, close_tag: String) -> void:
	if not _editing_has_selection():
		return
	var span_range: Vector2i = _editing_selection_range()
	var selected: String = _editing_buffer.substr(span_range.x, span_range.y - span_range.x)
	var already_wrapped: bool = selected.begins_with(open_tag) and selected.ends_with(close_tag)
	if open_tag.begins_with("[color=") and selected.begins_with("[color=") and selected.ends_with(close_tag):
		already_wrapped = true
	var replacement: String
	if already_wrapped:
		var inner_start: int = (selected.find("]") + 1) if open_tag.begins_with("[color=") else open_tag.length()
		replacement = selected.substr(inner_start, selected.length() - inner_start - close_tag.length())
	else:
		replacement = open_tag + selected + close_tag
	_editing_buffer = _editing_buffer.substr(0, span_range.x) + replacement + _editing_buffer.substr(span_range.y)
	_editing_select_anchor = span_range.x
	_editing_caret = span_range.x + replacement.length()
	_update_inline_format_bar()
	queue_redraw()


## The editing span belongs to a comment row (the only inline surface where BBCode wraps
## make sense - ACE cells hold expressions).
func _editing_span_is_comment() -> bool:
	var row_data: EventRowData = _row_at(_editing_row_index)
	return row_data != null and row_data.source_resource is CommentRow


## Shows/positions the floating format bar while a comment selection exists, hides it
## otherwise. Lazily built; positioned above the selection start inside the editing span.
func _update_inline_format_bar() -> void:
	var wants_bar: bool = _editing_has_selection() and _editing_span_is_comment()
	if not wants_bar:
		if _inline_format_bar != null:
			_inline_format_bar.visible = false
		return
	if _inline_format_bar == null:
		_inline_format_bar = EventSheetBBCodeSelectionBar.attach_floating(self)
		_inline_format_bar.format_requested.connect(_wrap_editing_selection)
	var row_data: EventRowData = _row_at(_editing_row_index)
	if row_data == null or _editing_span_index >= row_data.spans.size():
		_inline_format_bar.visible = false
		return
	var span: SemanticSpan = row_data.spans[_editing_span_index]
	var font: Font = get_theme_default_font()
	var prefix_width: float = 0.0
	if font != null:
		prefix_width = font.get_string_size(_editing_buffer.substr(0, _editing_selection_range().x), HORIZONTAL_ALIGNMENT_LEFT, -1.0, get_theme_default_font_size()).x
	_inline_format_bar.visible = true
	var bar_size: Vector2 = _inline_format_bar.get_combined_minimum_size()
	var target: Vector2 = span.rect.position + Vector2(prefix_width, -bar_size.y - 4.0)
	if target.y < 0.0:
		target.y = span.rect.end.y + 4.0
	target.x = clampf(target.x, 0.0, maxf(size.x - bar_size.x - 8.0, 0.0))
	_inline_format_bar.position = target


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
## template with the ACE's parameter values substituted) - the sheet continuously teaches
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
	# An EXPORTED variable row hovers as a live mock of its Inspector (drawers, decor, grouping) -
	# the payload stages here and _make_custom_tooltip swaps the sentinel for the preview card.
	if kind == "variable":
		var preview_payload: Dictionary = _inspector_preview_payload(hit, metadata)
		if not preview_payload.is_empty():
			_tooltip_helper.set_pending_inspector_preview(preview_payload)
			return ViewportTooltipHelper.INSPECTOR_PREVIEW_SENTINEL
	# A published verb's Define row: the row shows the verb's shape, but a long name clips inside the
	# condition lane and the per-parameter detail has nowhere to go, so the hover carries the full
	# declaration - name, description, every parameter with its type / default / blurb, and the markers.
	if kind == "define_function":
		var verb_row: EventRowData = _row_at(int(hit.get("row_index", -1)))
		if verb_row != null and verb_row.source_resource is EventFunction:
			return _tooltip_helper.verb_definition_tooltip(verb_row.source_resource as EventFunction)
	if kind in ["condition", "trigger", "action"]:
		var row_data: EventRowData = _row_at(int(hit.get("row_index", -1)))
		if row_data != null and row_data.source_resource is EventRow:
			# LEAD the tooltip with the whole event read as one plain-English sentence
			# (built from the same descriptors the cells draw), then the hovered cell's own description.
			var sentence: String = _row_builder.row_sentence(row_data.source_resource as EventRow)
			var sentence_prefix: String = "%s\n\n" % sentence if not sentence.is_empty() else ""
			var ace_resource: Resource = _resolve_ace_resource(row_data.source_resource, kind, int(metadata.get("ace_index", -1)))
			# Show the plain-language DESCRIPTION of the ACE / function (what it does) on hover. Built-in
			# ACEs get theirs from the generated map; custom ACEs + functions carry their own.
			var description: String = ""
			if ace_resource is ACECondition:
				var condition: ACECondition = ace_resource as ACECondition
				description = _tooltip_helper.ace_description(condition.provider_id, condition.ace_id)
			elif ace_resource is ACEAction:
				var action: ACEAction = ace_resource as ACEAction
				description = _tooltip_helper.function_call_description(action) if _is_function_call_action(action) else _tooltip_helper.ace_description(action.provider_id, action.ace_id)
			if not description.strip_edges().is_empty():
				return sentence_prefix + description
			# No description (rare) → fall back to the GDScript the row compiles to, so hover is never empty.
			var code: String = ""
			if ace_resource is ACECondition:
				var c: ACECondition = ace_resource as ACECondition
				code = _tooltip_helper.codegen_preview_for(c.provider_id, c.ace_id, c.params if not c.params.is_empty() else c.parameters)
			elif ace_resource is ACEAction:
				var a: ACEAction = ace_resource as ACEAction
				code = _tooltip_helper.codegen_preview_for(a.provider_id, a.ace_id, a.params if not a.params.is_empty() else a.parameters)
			if not code.strip_edges().is_empty():
				return sentence_prefix + "GDScript:\n%s" % code
			# Nothing else to say → at least the sentence (a trigger cell with no ACE description).
			if not sentence_prefix.is_empty():
				return sentence.strip_edges()
	# Custom block rows ask their registered kind first: hover_text() lets a pack-defined kind
	# explain its row on hover (BBCode renders styled), the same way built-ins do.
	var kind_row_data: EventRowData = _row_at(int(hit.get("row_index", -1)))
	if kind_row_data != null and kind_row_data.source_resource != null:
		var block_kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(kind_row_data.source_resource)
		if block_kind != null:
			var kind_hover: String = block_kind.hover_text(kind_row_data.source_resource)
			if not kind_hover.strip_edges().is_empty():
				return kind_hover
	# Raw GDScript blocks are the one row whose codegen is literally themselves - advertise
	# that the block compiles verbatim (the escape hatch is transparent, not a black box).
	var raw_row_data: EventRowData = _row_at(int(hit.get("row_index", -1)))
	if raw_row_data != null and raw_row_data.source_resource is RawCodeRow:
		var raw_block: RawCodeRow = raw_row_data.source_resource as RawCodeRow
		var first_line: String = raw_block.code.split("\n")[0] if not raw_block.code.is_empty() else ""
		var tip: String = "GDScript (verbatim):\n%s\nEmitted as-is into the generated script - select to highlight its lines in the GDScript panel." % first_line
		if not raw_block.note.strip_edges().is_empty():
			tip = "%s - %s\n%s" % [raw_block.note, "GDScript (verbatim)", tip.split("\n", true, 1)[1] if tip.contains("\n") else tip]
		# Import triage: when a line couldn't lift into a structured ACE, say why right here.
		if not raw_block.lift_note.strip_edges().is_empty():
			tip += "\n⚠ Stayed as code: %s" % raw_block.lift_note
		return tip
	return tooltip_text


## Render a hover tooltip's BBCode ([b]/[i]/[color]) when the text carries any - so an ACE/function
## description authored with markup reads styled, not as raw tags. Plain descriptions (the common case) and
## the GDScript-preview fallback have no markup, so this returns null and Godot uses its default tooltip.
func _make_custom_tooltip(for_text: String) -> Object:
	return _tooltip_helper.build_custom_tooltip(for_text)


## The hover-preview payload for a variable row, or {} when the variable is not exported (nothing to
## preview - the Inspector never shows it). Tree variables carry themselves as source_resource; dict
## (sheet-level) variables resolve through the sheet's descriptor, with combo options riding along so
## the mock shows the dropdown.
func _inspector_preview_payload(hit: Dictionary, metadata: Dictionary) -> Dictionary:
	var row_data: EventRowData = _row_at(int(hit.get("row_index", -1)))
	if row_data == null:
		return {}
	if row_data.source_resource is LocalVariable:
		var tree_var: LocalVariable = row_data.source_resource as LocalVariable
		if not tree_var.exported:
			return {}
		return {
			"name": tree_var.name,
			"type_name": tree_var.type_name,
			"default_text": VariableDialog._default_display_text(tree_var.default_value),
			"attributes": (tree_var.attributes as Dictionary).duplicate() if tree_var.attributes is Dictionary else {},
			"constant": tree_var.is_constant
		}
	if str(metadata.get("variable_scope", "")) == "global" and _sheet != null:
		var descriptor: Variant = _sheet.variables.get(str(metadata.get("variable_name", "")))
		if not (descriptor is Dictionary):
			return {}
		var descriptor_dict: Dictionary = descriptor as Dictionary
		if not bool(descriptor_dict.get("exported", true)):
			return {}
		var attributes: Dictionary = (descriptor_dict.get("attributes") as Dictionary).duplicate() if descriptor_dict.get("attributes") is Dictionary else {}
		var combo_options: Array = descriptor_dict.get("options") if descriptor_dict.get("options") is Array else []
		if not combo_options.is_empty():
			attributes["options"] = combo_options
		return {
			"name": str(metadata.get("variable_name", "")),
			"type_name": str(descriptor_dict.get("type", "Variant")),
			"default_text": VariableDialog._default_display_text(descriptor_dict.get("default")),
			"attributes": attributes,
			"constant": bool(metadata.get("is_constant", false))
		}
	return {}


## Static shim kept for callers that reach in by class name (e.g. tests/gdscript_pairing_test.gd
## calls EventSheetViewport.fill_codegen_template(...)). Forwards to the helper's pure implementation.
static func fill_codegen_template(template: String, params: Dictionary) -> String:
	return ViewportTooltipHelper.fill_codegen_template(template, params)


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
		# A published verb's parameter cells ride the SAME edit path as condition/action cells: clicking
		# one opens the thing it names. The dock routes them to the verb's dialog rather than the ACE
		# editor (a parameter is part of a DEFINITION, not a call site).
		if kind in ["condition", "trigger", "action", "verb_param", "verb_param_add"]:
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
	var is_in_inside_zone: bool = (
		relative_y >= inside_zone_top and relative_y <= inside_zone_bottom
	)
	# Dragging a variable onto another variable's middle band folds them into one Inspector-group
	# "folder" (edges keep meaning reorder-before/after, exactly like dropping between rows).
	if is_in_inside_zone and _drag_row_indices.size() == 1 \
			and _row_is_variable(_row_at(_drag_row_index)) and _row_is_variable(row_data) \
			and row_index != _drag_row_index:
		return "group"
	var supports_inside_drop: bool = row_data.row_type in [
		EventRowData.RowType.EVENT,
		EventRowData.RowType.GROUP
	]
	if supports_inside_drop and is_in_inside_zone:
		return "inside"
	return "after" if relative_y > row_height * DROP_ZONE_AFTER_THRESHOLD else "before"


## True for any variable row (global dict var or tree LocalVariable) - the grouping gesture's guard.
func _row_is_variable(row_data: EventRowData) -> bool:
	return row_data != null and not row_data.spans.is_empty() \
		and row_data.spans[0].metadata is Dictionary \
		and str((row_data.spans[0].metadata as Dictionary).get("kind", "")) == "variable"


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


# ── Row metrics: thin delegates to ViewportRowMetrics. Internal callers and tests call these
# names unchanged (e.g. viewport._get_row_top(i)); the layout itself lives in the helper. ──
func _rebuild_row_metrics() -> void:
	_row_metrics_helper.rebuild()


func _resolve_row_height(row_data: EventRowData) -> float:
	return _row_metrics_helper._resolve_row_height(row_data)


func _get_row_top(index: int) -> float:
	return _row_metrics_helper.row_top(index)


func _get_row_height(index: int) -> float:
	return _row_metrics_helper.row_height(index)


func _find_row_index_at_y(y: float) -> int:
	return _row_metrics_helper.row_index_at_y(y)


# Static forwarders: tests call these BY CLASS NAME (EventSheetViewport.wrapped_line_count / 
# EventSheetViewport._row_index_at_y). They forward to the pure statics on ViewportRowMetrics.
static func wrapped_line_count(text: String, wrap_width: float, font: Font, font_size: int) -> int:
	return ViewportRowMetrics.wrapped_line_count(text, wrap_width, font, font_size)


static func _row_index_at_y(metrics: Array, y: float) -> int:
	return ViewportRowMetrics._row_index_at_y(metrics, y)


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


func _object_label_for(provider_id: String, ace_id: String) -> String:
	return _row_builder._object_label_for(provider_id, ace_id)


func _is_function_call_action(action: ACEAction) -> bool:
	return _row_builder._is_function_call_action(action)


func _function_call_label(action: ACEAction) -> String:
	return _row_builder._function_call_label(action)


func _format_condition_descriptor(condition: ACECondition) -> String:
	return _row_builder._format_condition_descriptor(condition)


func _is_trigger_condition(condition: ACECondition) -> bool:
	return _row_builder._is_trigger_condition(condition)


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
	return _row_builder._format_action_descriptor(action)


func _format_action_descriptor_base(action: ACEAction) -> String:
	return _row_builder._format_action_descriptor_base(action)


# Static forwarder: value-range extraction is a pure text → ranges helper that now lives on
# ViewportRowBuilder. Kept here in case anything resolves it by the viewport's class name.
static func _value_ranges_for(text: String) -> Array:
	return ViewportRowBuilder._value_ranges_for(text)

# Test-only bridge for the row builder's private _pending_display_bbcode one-shot flag. On the real
# render path the flag never crosses this boundary - the writers (_format_*_descriptor) and the reader
# (_make_span) all live in ViewportRowBuilder and run against its own private flag. bbcode_and_pill_test
# pokes THIS field then calls the _make_span delegate below, which pushes it into the builder; so the
# test needs no edit. Nothing internal reads this var.
var _pending_display_bbcode: bool = false


func _make_span(text: String, span_type: int, metadata: Dictionary = {}) -> SemanticSpan:
	_row_builder._pending_display_bbcode = _pending_display_bbcode
	_pending_display_bbcode = false
	return _row_builder._make_span(text, span_type, metadata)


func _get_variable_metadata_for_row(row_data: EventRowData) -> Dictionary:
	return _row_builder._get_variable_metadata_for_row(row_data)


func _resolve_span_lane(span: SemanticSpan) -> String:
	return _row_builder._resolve_span_lane(span)


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


func _object_icon_for(provider_id: String, ace_id: String) -> Texture2D:
	return _row_builder._object_icon_for(provider_id, ace_id)


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


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# A scene-tree node dragged ONTO a condition/action param VALUE → fill that param with the node
	# reference, but only when the param can hold one (not a plain number/bool cell), so the cursor reads
	# as droppable exactly where the drop will land somewhere sensible.
	if _is_node_path_drag(data):
		var node_target: Dictionary = _param_value_at(_to_logical_position(at_position))
		return not node_target.is_empty() and _param_accepts_node_ref(node_target.get("ace"), str(node_target.get("param_id", "")))
	# An Inspector property drag is welcome anywhere: on a param VALUE it inserts the
	# access expression, anywhere else it becomes a Set Property action.
	if is_property_drag(data):
		return true
	return not _resolve_dropped_source_objects(data).is_empty() \
		or not _resolve_dropped_asset_paths(data).is_empty()


func _drop_data(at_position: Vector2, data: Variant) -> void:
	# Scene-tree node dropped on a param value: set that param to the node reference (prefers %unique-names
	# via the same converter the params dialog uses), no dialog - the deep-node-friendly gesture.
	if _is_node_path_drag(data):
		var target: Dictionary = _param_value_at(_to_logical_position(at_position))
		if not target.is_empty() and _param_accepts_node_ref(target.get("ace"), str(target.get("param_id", ""))):
			var reference: String = ACEParamsDialog.drop_data_to_expression(data)
			if not reference.is_empty():
				param_node_drop_requested.emit(target.get("ace"), str(target.get("param_id", "")), reference)
				return
	# Inspector property drops: on a param VALUE that takes expressions, insert the access
	# expression ($Sprite.modulate); anywhere else, the dock builds a Set Property action
	# (on the row it landed on, or as a new event) with the CURRENT value pre-filled.
	if is_property_drag(data):
		var parts: Dictionary = property_drop_parts(data, EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface") else null)
		var value_target: Dictionary = _param_value_at(_to_logical_position(at_position))
		if not value_target.is_empty() and _param_accepts_node_ref(value_target.get("ace"), str(value_target.get("param_id", ""))):
			param_node_drop_requested.emit(value_target.get("ace"), str(value_target.get("param_id", "")), str(parts.get("access", "")))
			return
		var property_row_index: int = _find_row_index_at_y(at_position.y)
		var property_row: EventRowData = _row_at(property_row_index) if property_row_index >= 0 else null
		property_dropped.emit(property_row.source_resource if property_row != null else null,
			str(parts.get("reference", "")), str(parts.get("property", "")), str(parts.get("value", "")))
		return
	# FileSystem asset drops carry intent: a scene or sound dropped ON an event row
	# becomes a pre-filled action (the dock builds it). Recognized assets are accepted
	# anywhere on the canvas so an empty-space drop can explain itself instead of
	# silently bouncing.
	var asset_paths: PackedStringArray = _resolve_dropped_asset_paths(data)
	if not asset_paths.is_empty():
		var row_index: int = _find_row_index_at_y(at_position.y)
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


## True for Godot's Inspector property drag ({type: "obj_property", object, property})
## when the dragged owner is a Node - the payload EditorProperty hands every drag.
static func is_property_drag(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload: Dictionary = data as Dictionary
	return str(payload.get("type", "")) == "obj_property" \
		and payload.get("object") is Node \
		and not str(payload.get("property", "")).is_empty()


## Resolves an Inspector property drop into everything the sheet needs:
## reference (the node as "self" / %Unique / $Path), property (bare name), access (the
## read expression), and value (the property's CURRENT value as a GDScript literal, ""
## when it has no literal form). Pure given a scene root, so tests pin it headless.
static func property_drop_parts(data: Variant, scene_root: Node) -> Dictionary:
	var payload: Dictionary = data as Dictionary
	var node: Node = payload.get("object") as Node
	var property_name: String = str(payload.get("property", ""))
	var reference: String = "self"
	if scene_root != null and node != scene_root:
		reference = ACEParamsDialog._best_node_reference(scene_root, str(scene_root.get_path_to(node)))
	elif scene_root == null:
		reference = "$%s" % node.name
	var access: String = property_name if reference == "self" else "%s.%s" % [reference, property_name]
	return {
		"reference": reference,
		"property": property_name,
		"access": access,
		"value": property_value_literal(node.get(property_name)),
	}


## A property value as a GDScript literal the Set Property action can carry - primitives
## and math types only ("" for objects/null/multi-line forms; the user fills those in).
static func property_value_literal(value: Variant) -> String:
	if value == null or value is Object:
		return ""
	var literal: String = var_to_str(value)
	if literal.contains("\n"):
		return ""
	# var_to_str writes StringNames as &"x" and NodePaths as ^"x" - both valid GDScript.
	return literal


## FileSystem-dock drop payload files with a registered asset-drop handler (the
## EventSheets seam - built-ins cover scenes/sounds/images/JSON/resources, and any
## extension can register more, which lights up the drop cursor here automatically).
static func _resolve_dropped_asset_paths(data: Variant) -> PackedStringArray:
	var assets: PackedStringArray = PackedStringArray()
	if data is Dictionary and str((data as Dictionary).get("type", "")) == "files":
		var handled: PackedStringArray = EventSheets.handled_asset_extensions()
		for file_path: Variant in ((data as Dictionary).get("files", []) as Array):
			if str(file_path).get_extension().to_lower() in handled:
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


## True for a Scene-dock node drag (type "nodes" carrying NodePath/String entries) - as opposed to an
## Object-valued "nodes" payload, which is a behaviour-source drag handled by _resolve_dropped_source_objects.
static func _is_node_path_drag(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload: Dictionary = data as Dictionary
	if str(payload.get("type", "")) != "nodes":
		return false
	var nodes: Variant = payload.get("nodes", [])
	return nodes is Array and not (nodes as Array).is_empty() and not ((nodes as Array)[0] is Object)


## The {ace, param_id, current} under a logical position when it sits on an editable condition/action param
## VALUE, else {}. Shared by double-click-to-edit and the node-drop-onto-param gesture.
func _param_value_at(local_position: Vector2) -> Dictionary:
	var hit: Dictionary = _hit_test(local_position)
	var span_index: int = int(hit.get("span_index", -1))
	var row_data: EventRowData = _row_at(int(hit.get("row_index", -1)))
	var meta: Dictionary = hit.get("span_metadata", {}) if hit.get("span_metadata", {}) is Dictionary else {}
	var kind: String = str(meta.get("kind", ""))
	if kind in ["condition", "trigger", "action"] and row_data != null and row_data.source_resource is EventRow and span_index >= 0 and span_index < row_data.spans.size():
		var value_hit: Array = _value_text_at(row_data.spans[span_index], local_position.x, _get_font(), _get_font_size())
		if not value_hit.is_empty():
			var lane: String = "action" if kind == "action" else "condition"
			var ace: Resource = (row_data.source_resource as EventRow).trigger if kind == "trigger" else _resolve_ace_resource(row_data.source_resource, lane, int(meta.get("ace_index", -1)))
			if ace != null:
				var param: String = param_id_for_value(ace, str(value_hit[0]), int(value_hit[1]))
				if not param.is_empty():
					return {"ace": ace, "param_id": param, "current": str(value_hit[0])}
	return {}


## A dropped node reference ($Path / %Name) fits a param that holds an object / expression, NOT a plain
## numeric or bool cell (where it would be nonsense). Conservative: an expression-hinted param takes any
## GDScript, so it always accepts; only int / float / bool declared types reject.
static func _node_ref_fits_param_type(type_name: String, hint: String) -> bool:
	if hint == "expression":
		return true
	return not (type_name.to_lower() in ["int", "integer", "float", "double", "bool", "boolean"])


## Whether a node reference may be dropped onto this ACE param. Unknown definition / param (nothing found)
## stays PERMISSIVE - the gate only blocks the clear footgun (a node ref onto a numeric/bool cell), never a
## legitimate or unrecognized param.
func _param_accepts_node_ref(ace: Variant, param_id: String) -> bool:
	if not (ace is Resource) or param_id.is_empty():
		return true
	var definition: ACEDefinition = _find_definition(str((ace as Resource).get("provider_id")), str((ace as Resource).get("ace_id")))
	if definition == null:
		return true
	for parameter: Variant in definition.parameters:
		if parameter is ACEParam and (parameter as ACEParam).id == param_id:
			return _node_ref_fits_param_type((parameter as ACEParam).type_name, (parameter as ACEParam).hint)
	return true
