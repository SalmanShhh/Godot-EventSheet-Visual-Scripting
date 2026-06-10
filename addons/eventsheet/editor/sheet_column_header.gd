# EventSheet — pinned Conditions/Actions column header.
# A thin band drawn above the scrollable sheet that labels the two lanes and mirrors the
# event rows' lane divider position (zoom + horizontal-scroll aware), so the column grid
# reads from the header straight down through every row.
@tool
class_name SheetColumnHeader
extends Control

const HEADER_HEIGHT := 22.0
const LABEL_FONT_SIZE := 12
# Fallbacks used only when no themed event style is available.
const FALLBACK_CONDITIONS_COLOR := Color("#8fb0e0")
const FALLBACK_ACTIONS_COLOR := Color("#6fd0bf")
const FALLBACK_BACKGROUND_COLOR := Color("#22242b")
const FALLBACK_DIVIDER_COLOR := Color("#2f3641")

var _viewport: EventSheetViewport = null
var _last_signature: String = ""

## Binds the header to the viewport whose lane geometry it mirrors.
func setup(viewport: EventSheetViewport) -> void:
	_viewport = viewport
	name = "SheetColumnHeader"
	custom_minimum_size = Vector2(0.0, HEADER_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	if _viewport == null:
		return
	# Redraw only when something that affects alignment changes (incl. the lane divider, which
	# moves when the user drags to resize the conditions/actions split).
	var signature: String = "%d:%.3f:%d:%d:%d" % [
		int(size.x),
		_viewport.get_zoom_factor(),
		_viewport.get_horizontal_scroll(),
		int(_viewport.get_canvas_logical_width()),
		int(_viewport.get_lane_divider_x(_viewport.get_canvas_logical_width()))
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
	var zoom: float = _viewport.get_zoom_factor()
	var h_scroll: float = float(_viewport.get_horizontal_scroll())
	var logical_width: float = _viewport.get_canvas_logical_width()
	var divider_x: float = _viewport.get_lane_divider_x(logical_width) * zoom - h_scroll
	var gutter_x: float = EventSheetPalette.GUTTER_WIDTH * zoom - h_scroll
	# Vertical lane divider, mirroring the rows below.
	draw_rect(Rect2(divider_x, 0.0, 2.0, height), divider_color, true)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var baseline: float = height * 0.5 + float(LABEL_FONT_SIZE) * 0.32
	# Behavior sheets surface their host class here, so what the conditions act on is
	# always visible while editing.
	var host_suffix: String = _viewport.get_host_context_label() if _viewport.has_method("get_host_context_label") else ""
	draw_string(
		font,
		Vector2(gutter_x + 8.0, baseline),
		"Conditions%s" % host_suffix,
		HORIZONTAL_ALIGNMENT_LEFT,
		max(divider_x - gutter_x - 12.0, 10.0),
		LABEL_FONT_SIZE,
		conditions_color
	)
	draw_string(
		font,
		Vector2(divider_x + 8.0, baseline),
		"Actions",
		HORIZONTAL_ALIGNMENT_LEFT,
		max(width - divider_x - 12.0, 10.0),
		LABEL_FONT_SIZE,
		actions_color
	)
