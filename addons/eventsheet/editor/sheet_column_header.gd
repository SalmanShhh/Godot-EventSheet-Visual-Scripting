# EventSheet - pinned Conditions/Actions column header.
# A thin band drawn above the scrollable sheet that labels the two lanes and mirrors the
# event rows' lane divider position (zoom + horizontal-scroll aware), so the column grid
# reads from the header straight down through every row.
#
# THE BAND IS ALSO THE HANDLE. The lane divider and each lane's object column are dragged from
# here, where a grabber is drawn on the boundary and the pointer says ↔ before the button goes
# down. Down the sheet those boundaries are lines: a press five pixels from one used to start a
# resize on whichever row it landed in, which is a whole event's worth of click surface spent on a
# gesture nobody aimed. The drag STATE lives on the viewport (it is the surface that relayouts
# under it); this band only says where the press landed and follows the pointer.
@tool
class_name SheetColumnHeader
extends Control

# 1x design values - scaled by EventSheetPalette.ui_scale() at use time, so the band and its
# labels track the editor's display scale like every built-in dock header does.
const HEADER_HEIGHT := 22.0
const LABEL_FONT_SIZE := 12
# Fallbacks used only when no themed event style is available.
const FALLBACK_CONDITIONS_COLOR := Color("#8fb0e0")
const FALLBACK_ACTIONS_COLOR := Color("#6fd0bf")
const FALLBACK_BACKGROUND_COLOR := Color("#22242b")
const FALLBACK_DIVIDER_COLOR := Color("#2f3641")
## Half the width of a grabber's plate, in 1x design pixels.
const GRABBER_HALF_WIDTH := 3.0
## How much of the band's height a grabber's plate takes.
const GRABBER_HEIGHT_SHARE := 0.62

var _viewport: EventSheetViewport = null
var _last_signature: String = ""
## True while this band is driving a boundary drag on the viewport.
var _dragging: bool = false


## Binds the header to the viewport whose lane geometry it mirrors.
func setup(viewport: EventSheetViewport) -> void:
	_viewport = viewport
	name = "SheetColumnHeader"
	custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(HEADER_HEIGHT))
	# The band takes the mouse because it is the handle: the rows below are unaffected, they are
	# not under it. A press that lands on neither grabber is passed nowhere and does nothing.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	queue_redraw()


## WHERE THE CANVAS'S OWN ZERO LANDS IN THIS BAND. The band spans the whole workspace while the
## sheet below it starts after the left rail and slides under a horizontal scroll, so a column drawn
## at the canvas's x sits a rail's width away from the column it names unless both are counted. The
## live positions answer both at once; outside a tree only the scroll is knowable, which is what the
## suite drives this with.
func _sheet_origin_x() -> float:
	if _viewport == null:
		return 0.0
	if is_inside_tree() and _viewport.is_inside_tree():
		return _viewport.get_global_rect().position.x - get_global_rect().position.x
	return -float(_viewport.get_horizontal_scroll())


## The logical canvas x a point in this band stands over - the space the viewport measures its
## boundaries in, so a grabber and the line it stands for can never drift apart.
func logical_x_at(header_x: float) -> float:
	if _viewport == null:
		return header_x
	var zoom: float = max(_viewport.get_zoom_factor(), 0.001)
	return (header_x - _sheet_origin_x()) / zoom


## Where a logical canvas x is drawn in this band.
func header_x_at(logical_x: float) -> float:
	if _viewport == null:
		return logical_x
	return _sheet_origin_x() + logical_x * _viewport.get_zoom_factor()


func _gui_input(event: InputEvent) -> void:
	# Consumed only when the band actually did something with it, and only from inside a tree -
	# the grammar itself is a plain method so it can be driven without a window.
	if handle_pointer(event) and is_inside_tree():
		accept_event()


## THE BAND'S POINTER GRAMMAR: press a grabber to start that boundary's drag, move to carry it,
## let go to persist it, and hover one to wear the ↔ cursor. Returns whether the band took the
## event; anything landing on neither grabber is left alone.
func handle_pointer(event: InputEvent) -> bool:
	if _viewport == null:
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed:
			var grab: Dictionary = _viewport.column_header_grab_at(logical_x_at(button.position.x))
			if grab.is_empty():
				return false
			_dragging = _viewport.begin_column_header_drag(grab)
			return _dragging
		if not _dragging:
			return false
		_dragging = false
		_viewport.end_column_header_drag()
		return true
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging:
			_viewport.drag_column_header_to(logical_x_at(motion.position.x))
			queue_redraw()
			return true
		# ↔ on a grabber, the arrow everywhere else - the band says which of it is a handle before
		# the button goes down.
		var over: Dictionary = _viewport.column_header_grab_at(logical_x_at(motion.position.x))
		mouse_default_cursor_shape = Control.CURSOR_HSIZE if not over.is_empty() else Control.CURSOR_ARROW
	return false


func _process(_delta: float) -> void:
	if _viewport == null:
		return
	# Redraw only when something that affects alignment changes (incl. the lane divider, which
	# moves when the user drags to resize the conditions/actions split).
	var column_style: EventSheetEventStyle = _viewport.get_event_style()
	var signature: String = "%d:%d:%.3f:%d:%d:%d:%d:%d" % [
		int(size.x),
		# Where the canvas starts under this band: a rail folded away moves every column with it.
		int(_sheet_origin_x()),
		_viewport.get_zoom_factor(),
		_viewport.get_horizontal_scroll(),
		int(_viewport.get_canvas_logical_width()),
		int(_viewport.get_lane_divider_x(_viewport.get_canvas_logical_width())),
		# The object columns carry their own grabbers, so a width dragged anywhere has to move them.
		column_style.condition_object_column_width if column_style != null else -1,
		column_style.action_object_column_width if column_style != null else -1
	]
	if signature != _last_signature:
		_last_signature = signature
		queue_redraw()


func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	# Resolve themed colours from the active event style, with palette-ish fallbacks.
	var background_color: Color = FALLBACK_BACKGROUND_COLOR
	var divider_color: Color = FALLBACK_DIVIDER_COLOR
	var conditions_color: Color = FALLBACK_CONDITIONS_COLOR
	var actions_color: Color = FALLBACK_ACTIONS_COLOR
	var style: EventSheetEventStyle = _viewport.get_event_style() if _viewport != null else null
	if style != null:
		background_color = style.column_header_background_color
		divider_color = style.lane_divider_color
		conditions_color = style.column_header_conditions_color
		actions_color = style.column_header_actions_color
	draw_rect(Rect2(0.0, 0.0, width, height), background_color, true)
	draw_rect(Rect2(0.0, height - 1.0, width, 1.0), divider_color, true)
	if _viewport == null:
		return
	var logical_width: float = _viewport.get_canvas_logical_width()
	var divider_x: float = header_x_at(_viewport.get_lane_divider_x(logical_width))
	var gutter_x: float = header_x_at(EventSheetPalette.GUTTER_WIDTH)
	# Vertical lane divider, mirroring the rows below.
	draw_rect(Rect2(divider_x, 0.0, 2.0, height), divider_color, true)
	# The editor's own font (falls back outside a theme tree), at the display-scaled label size.
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	var label_size: int = EventSheetPalette.scaled(LABEL_FONT_SIZE)
	var pad: float = EventSheetPalette.scaled_f(8.0)
	var baseline: float = height * 0.5 + float(label_size) * 0.32
	# Behavior sheets surface their host class here, so what the conditions act on is
	# always visible while editing.
	var host_suffix: String = _viewport.get_host_context_label() if _viewport.has_method("get_host_context_label") else ""
	draw_string(
		font,
		Vector2(gutter_x + pad, baseline),
		"Conditions%s" % host_suffix,
		HORIZONTAL_ALIGNMENT_LEFT,
		max(divider_x - gutter_x - pad - 4.0, 10.0),
		label_size,
		conditions_color
	)
	draw_string(
		font,
		Vector2(divider_x + pad, baseline),
		"Actions",
		HORIZONTAL_ALIGNMENT_LEFT,
		max(width - divider_x - pad - 4.0, 10.0),
		label_size,
		actions_color
	)
	# The handles. One on the lane divider, one on each lane's object column where that lane has a
	# column to drag: a short plate with two grip lines, the same shape a splitter wears, so the
	# band reads as the place both boundaries are moved from.
	_draw_grabber(divider_x, height, conditions_color)
	for lane: String in ["condition", "action"]:
		var boundary: Dictionary = _viewport.object_column_boundary_for_lane(lane)
		if boundary.is_empty():
			continue
		_draw_grabber(header_x_at(float(boundary.get("boundary_x", -1.0))), height,
			conditions_color if lane == "condition" else actions_color)


## One boundary's handle, centred on the line it moves.
func _draw_grabber(center_x: float, height: float, accent: Color) -> void:
	if center_x < 0.0 or center_x > size.x:
		return
	var half: float = EventSheetPalette.scaled_f(GRABBER_HALF_WIDTH)
	var plate_height: float = height * GRABBER_HEIGHT_SHARE
	var top: float = (height - plate_height) * 0.5
	var plate: Color = accent
	plate.a = 0.28
	draw_rect(Rect2(center_x - half, top, half * 2.0, plate_height), plate, true)
	var grip: Color = accent
	grip.a = 0.85
	for offset: float in [-1.5, 1.5]:
		draw_rect(Rect2(center_x + EventSheetPalette.scaled_f(offset) - 0.5, top + 2.0, 1.0,
			max(plate_height - 4.0, 1.0)), grip, true)
