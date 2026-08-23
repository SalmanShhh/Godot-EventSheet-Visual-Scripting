# Godot EventSheets - the minimap column (dock subsystem)
#
# A picture of the whole sheet down the right edge of the canvas. A long sheet is a document, and a
# document deserves a page-shaped view of itself: one thin bar per row, tinted by what that row IS
# (a trigger, an every-tick event, a function, a group, a comment, a Script block, a disabled row),
# the part you are looking at drawn as a translucent box over them, bookmarks and flagged rows as
# marks in the margin, and groups as faint bands you can hover to read the name of.
#
# It reads the rows the canvas already holds - no second walk of the sheet, no copy - and it draws
# nothing at all while hidden, so a sheet that never turns it on pays nothing for it.
@tool
class_name EventSheetMinimap
extends Control

## Bar kinds, in the words the sheet uses for them. Frozen: the tests pin these strings and the
## theme has one colour per kind.
const KIND_TRIGGER := "trigger"
const KIND_TICK := "tick"
const KIND_FUNCTION := "function"
const KIND_GROUP := "group"
const KIND_COMMENT := "comment"
const KIND_SCRIPT := "script"
const KIND_EVENT := "event"
const KIND_DISABLED := "disabled"

## Author these at 1x; they are multiplied by the editor's display scale at use time.
const COLUMN_WIDTH := 16.0
const MIN_BAR_HEIGHT := 2.0
const MARK_WIDTH := 4.0
const EDGE_PADDING := 2.0

## Over this many events the minimap earns its place on its own, so a sheet that long shows it the
## first time it is opened. Under it the column is off unless asked for.
const AUTO_SHOW_EVENT_COUNT := 200

var _viewport: Control = null
var _dragging: bool = false
var _drag_grab_offset: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(EventSheetPalette.scaled_f(COLUMN_WIDTH), 0.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tooltip_text = ""


## Points the column at the canvas it mirrors. Called once per view; the column re-reads the rows
## every frame it draws, so a rebuilt sheet needs no second call.
func set_source(viewport: Control) -> void:
	_viewport = viewport
	if viewport == null:
		return
	# Scrolling moves the box and a rebuild changes the picture, so both repaint the column. The
	# canvas keeps no signal for either, but the scroll bar and the canvas's own size do.
	var scroll: ScrollContainer = viewport.get_parent() as ScrollContainer
	if scroll != null:
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		if bar != null and not bar.value_changed.is_connected(_on_canvas_changed):
			bar.value_changed.connect(_on_canvas_changed)
	if not viewport.minimum_size_changed.is_connected(queue_redraw):
		viewport.minimum_size_changed.connect(queue_redraw)
	queue_redraw()


func _on_canvas_changed(_value: float) -> void:
	queue_redraw()


## What one row IS, in one word. Pure and static: the tests pin the answer per fixture row, and
# nothing here reaches the canvas, the theme or the editor.
static func row_kind(row_data: EventRowData) -> String:
	if row_data == null:
		return KIND_EVENT
	if row_data.disabled:
		return KIND_DISABLED
	if row_data.row_type in [EventRowData.RowType.GROUP, EventRowData.RowType.REGION]:
		return KIND_GROUP
	if row_data.row_type == EventRowData.RowType.COMMENT:
		return KIND_COMMENT
	var source: Resource = row_data.source_resource
	if source is RawCodeRow:
		return KIND_SCRIPT
	if source is EventFunction:
		return KIND_FUNCTION
	if source is EventRow:
		var event_row: EventRow = source as EventRow
		if not event_row.trigger_id.strip_edges().is_empty():
			return KIND_TRIGGER
		if event_row.conditions.is_empty():
			return KIND_TICK
	return KIND_EVENT


## The whole column as data: one entry per flattened row, in sheet order. Pure over the flattened
## list the canvas hands out, so a test pins the picture of a fixture sheet without an editor.
## Each entry is {kind, label, bookmarked, flagged, indent}; `label` is the group's name on a group
## row and "" everywhere else, because that is the only name a hover over the column can answer.
static func bars_of(flat_rows: Array) -> Array[Dictionary]:
	var bars: Array[Dictionary] = []
	for entry: Variant in flat_rows:
		var row_data: EventRowData = null
		if entry is Dictionary:
			row_data = (entry as Dictionary).get("row")
		elif entry is EventRowData:
			row_data = entry as EventRowData
		if row_data == null:
			continue
		var label: String = ""
		if row_data.source_resource is EventGroup:
			label = (row_data.source_resource as EventGroup).group_name
		bars.append({
			"kind": row_kind(row_data),
			"label": label,
			"bookmarked": row_data.bookmark_enabled,
			"flagged": not row_data.error_message.strip_edges().is_empty(),
			"indent": row_data.indent
		})
	return bars


func _draw() -> void:
	if _viewport == null or not is_visible_in_tree():
		return
	var row_count: int = int(_viewport.get_total_row_count())
	if row_count <= 0:
		return
	var chrome: EventSheetChromeStyle = _viewport.get_chrome_style()
	draw_rect(Rect2(Vector2.ZERO, size), chrome.minimap_background_color, true)
	var content: float = float(_viewport.content_height())
	if content <= 0.0:
		return
	var scale: float = size.y / content
	var bar_height: float = maxf(EventSheetPalette.scaled_f(MIN_BAR_HEIGHT), 1.0)
	var mark_width: float = EventSheetPalette.scaled_f(MARK_WIDTH)
	var padding: float = EventSheetPalette.scaled_f(EDGE_PADDING)
	var bar_width: float = maxf(size.x - padding * 2.0 - mark_width, 2.0)
	# Groups first, so their bands sit UNDER the bars they hold rather than washing them out.
	_draw_group_bands(row_count, scale, chrome)
	for index: int in row_count:
		var row_data: EventRowData = _viewport.get_row_data(index)
		if row_data == null:
			continue
		var top: float = float(_viewport.get_row_top(index)) * scale
		var height: float = maxf(float(_viewport.get_row_height(index)) * scale, bar_height)
		draw_rect(Rect2(padding, top, bar_width, height), _kind_color(row_kind(row_data), chrome), true)
		# The margin marks: a bookmark you set, and a row the sheet flagged. Both are why you would
		# look at the column in the first place, so they get the full-brightness edge.
		if row_data.bookmark_enabled:
			draw_rect(Rect2(size.x - mark_width, top, mark_width, maxf(height, bar_height)),
				chrome.minimap_bookmark_color, true)
		elif not row_data.error_message.strip_edges().is_empty():
			draw_rect(Rect2(size.x - mark_width, top, mark_width, maxf(height, bar_height)),
				chrome.minimap_finding_color, true)
	_draw_window_box(content, scale, chrome)


## The faint band a group paints down the column, from its own row to the last row it holds. The
## name is on hover, because a column this thin has nowhere to write it.
func _draw_group_bands(row_count: int, scale: float, chrome: EventSheetChromeStyle) -> void:
	for index: int in row_count:
		var row_data: EventRowData = _viewport.get_row_data(index)
		if row_data == null or row_data.row_type not in [
			EventRowData.RowType.GROUP, EventRowData.RowType.REGION
		]:
			continue
		var last: int = index
		for scan: int in range(index + 1, row_count):
			var scanned: EventRowData = _viewport.get_row_data(scan)
			if scanned == null or scanned.indent <= row_data.indent:
				break
			last = scan
		var top: float = float(_viewport.get_row_top(index)) * scale
		var bottom: float = (float(_viewport.get_row_top(last)) + float(_viewport.get_row_height(last))) * scale
		draw_rect(Rect2(0.0, top, size.x, maxf(bottom - top, 1.0)), chrome.minimap_band_color, true)


## The part of the sheet on screen, drawn as a box over the picture - the one thing that says
## "you are here" and the thing you drag to be somewhere else.
func _draw_window_box(content: float, scale: float, chrome: EventSheetChromeStyle) -> void:
	var zoom: float = maxf(float(_viewport.get_zoom_factor()), 0.001)
	var window_top: float = (float(_viewport.get_scroll_offset()) / zoom) * scale
	var window_height: float = (float(_viewport.get_visible_height()) / zoom) * scale
	if window_height >= size.y:
		return
	var box: Rect2 = Rect2(0.0, clampf(window_top, 0.0, maxf(size.y - window_height, 0.0)),
		size.x, window_height)
	draw_rect(box, chrome.minimap_window_color, true)
	draw_rect(box, chrome.minimap_window_border_color, false, 1.0)


func _kind_color(kind: String, chrome: EventSheetChromeStyle) -> Color:
	match kind:
		KIND_TRIGGER:
			return chrome.minimap_trigger_color
		KIND_TICK:
			return chrome.minimap_tick_color
		KIND_FUNCTION:
			return chrome.minimap_function_color
		KIND_GROUP:
			return chrome.minimap_group_color
		KIND_COMMENT:
			return chrome.minimap_comment_color
		KIND_SCRIPT:
			return chrome.minimap_script_color
		KIND_DISABLED:
			return chrome.minimap_disabled_color
	return chrome.minimap_event_color


func _gui_input(event: InputEvent) -> void:
	if _viewport == null:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_begin_drag(button.position.y)
		else:
			_dragging = false
		accept_event()
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging:
			_scroll_to_box_top(motion.position.y - _drag_grab_offset)
			accept_event()
			return
		tooltip_text = _hover_label(motion.position.y)


## A press inside the box grabs it where you took hold of it; a press anywhere else jumps there
## first and then behaves like a grab from the middle, so one gesture covers both.
func _begin_drag(at_y: float) -> void:
	var window_height: float = _window_height()
	var box_top: float = _box_top()
	_dragging = true
	if at_y >= box_top and at_y <= box_top + window_height:
		_drag_grab_offset = at_y - box_top
		return
	_drag_grab_offset = window_height * 0.5
	_scroll_to_box_top(at_y - _drag_grab_offset)


func _scroll_to_box_top(box_top: float) -> void:
	var content: float = float(_viewport.content_height())
	if content <= 0.0 or size.y <= 0.0:
		return
	var zoom: float = maxf(float(_viewport.get_zoom_factor()), 0.001)
	_viewport.set_scroll_offset(int(round(maxf(box_top, 0.0) / size.y * content * zoom)))
	queue_redraw()


func _window_height() -> float:
	var content: float = float(_viewport.content_height())
	if content <= 0.0 or size.y <= 0.0:
		return 0.0
	var zoom: float = maxf(float(_viewport.get_zoom_factor()), 0.001)
	return (float(_viewport.get_visible_height()) / zoom) * (size.y / content)


func _box_top() -> float:
	var content: float = float(_viewport.content_height())
	if content <= 0.0 or size.y <= 0.0:
		return 0.0
	var zoom: float = maxf(float(_viewport.get_zoom_factor()), 0.001)
	return (float(_viewport.get_scroll_offset()) / zoom) * (size.y / content)


## What sits at this height in the column: the name of the group covering it, else "". The column
## is too thin to write a name on, so the hover is where the name lives.
func _hover_label(at_y: float) -> String:
	var content: float = float(_viewport.content_height())
	var row_count: int = int(_viewport.get_total_row_count())
	if content <= 0.0 or size.y <= 0.0 or row_count <= 0:
		return ""
	var target: float = at_y / size.y * content
	var found: String = ""
	for index: int in row_count:
		var top: float = float(_viewport.get_row_top(index))
		if top > target:
			break
		var row_data: EventRowData = _viewport.get_row_data(index)
		if row_data == null:
			continue
		if row_data.row_type == EventRowData.RowType.GROUP and row_data.source_resource is EventGroup:
			found = (row_data.source_resource as EventGroup).group_name
		elif row_data.indent == 0:
			found = ""
	return found
