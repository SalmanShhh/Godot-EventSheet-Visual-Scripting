# Godot EventSheets - the Sheet map window (U17)
#
# The graph sheet_map.gd derives, drawn: sheets, scenes and globals as boxes, and the four ways one
# reaches another as lines between them. Click a box to open that sheet; click a line to run the
# Find that explains it. Boxes lay themselves out in columns by kind and can be dragged, and where
# you drag one is remembered per project in editor metadata - the picture is derived, the
# arrangement is yours.
@tool
class_name EventSheetSheetMapPanel
extends RefCounted

## Author these at 1x; they are multiplied by the editor's display scale at use time.
const BOX_WIDTH := 148.0
const BOX_HEIGHT := 34.0
const COLUMN_GAP := 56.0
const ROW_GAP := 18.0
const MARGIN := 16.0
const HIT_TOLERANCE := 6.0

## Where the arrangement is remembered. Editor metadata, not project state: it is a reading
## position, not something a project commits.
const LAYOUT_META := "sheet_map_layout"

var _dock: Control = null

var window: Window = null
var canvas: Control = null
var summary_label: Label = null

## The graph as drawn: {nodes, edges, skipped} from EventSheetSheetMap.
var found: Dictionary = {}
## node id -> Vector2, the top-left of its box in canvas space.
var positions: Dictionary = {}

var _dragging_id: String = ""
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_moved: bool = false


func _init(dock: Control) -> void:
	_dock = dock


## Where every box sits before anyone drags one: one column per kind (globals, sheets, scenes),
## each in the graph's own order. Pure over the nodes, so a test pins the arrangement.
static func default_positions(nodes: Array) -> Dictionary:
	var placed: Dictionary = {}
	var per_column: Dictionary = {}
	var columns: PackedStringArray = PackedStringArray([EventSheetSheetMap.NODE_GLOBAL,
		EventSheetSheetMap.NODE_SHEET, EventSheetSheetMap.NODE_SCENE])
	for entry: Variant in nodes:
		var node: Dictionary = entry
		var column: int = maxi(columns.find(str(node.get("kind", ""))), 0)
		var row: int = int(per_column.get(column, 0))
		per_column[column] = row + 1
		placed[str(node.get("id", ""))] = Vector2(
			MARGIN + column * (BOX_WIDTH + COLUMN_GAP),
			MARGIN + row * (BOX_HEIGHT + ROW_GAP))
	return placed


func build() -> void:
	if window != null:
		return
	window = Window.new()
	window.title = "Sheet map"
	window.size = Vector2i(760, 520)
	window.close_requested.connect(func() -> void: window.hide())
	var body_box: VBoxContainer = VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 6)
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas = Control.new()
	canvas.name = "EventSheetMapCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.custom_minimum_size = Vector2(700.0, 420.0)
	canvas.draw.connect(_draw_map)
	canvas.gui_input.connect(_on_canvas_input)
	scroll.add_child(canvas)
	body_box.add_child(scroll)
	summary_label = EventSheetPopupUI.hint_label(
		"Click a sheet to open it. Click a line to find every place it comes from.", 640.0)
	body_box.add_child(summary_label)
	var card: Control = EventSheetPopupUI.titled_card("Sheet map", body_box)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: Control = EventSheetPopupUI.margined(card)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(body)
	_dock.add_child(window)


func open() -> void:
	build()
	refresh()
	window.popup_centered()


## Re-derives the graph and lays it out, keeping every box the reader has moved where they put it.
## Popup-free, so tests pin it headless.
func refresh() -> void:
	found = EventSheetSheetMap.graph()
	positions = default_positions(found.get("nodes", []) as Array)
	for id: String in _remembered_positions():
		if positions.has(id):
			positions[id] = _remembered_positions()[id]
	if summary_label != null:
		summary_label.text = "%s. Click a sheet to open it. Click a line to find every place it comes from." \
			% EventSheetSheetMap.summary(found)
	if canvas != null:
		canvas.custom_minimum_size = _canvas_extent()
		canvas.queue_redraw()


func _canvas_extent() -> Vector2:
	var extent: Vector2 = Vector2(700.0, 420.0)
	for id: String in positions:
		var corner: Vector2 = (positions[id] as Vector2) + Vector2(BOX_WIDTH, BOX_HEIGHT) + Vector2(MARGIN, MARGIN)
		extent = Vector2(maxf(extent.x, corner.x), maxf(extent.y, corner.y))
	return EventSheetPalette.scaled_f(1.0) * extent


# ── Drawing ───────────────────────────────────────────────────────────────────────────────────


func _draw_map() -> void:
	var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
	# The map is a picture of sheets, so it sits on the sheet's own paper: without this the boxes
	# float on the popup card's grey, and a pale theme's dark ink text would land on dark.
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size),
		EventSheetActiveTheme.active().get_event_style().sheet_background_color, true)
	var scale: float = EventSheetPalette.scaled_f(1.0)
	var font: Font = canvas.get_theme_default_font()
	var font_size: int = canvas.get_theme_default_font_size()
	for entry: Variant in (found.get("edges", []) as Array):
		var edge: Dictionary = entry
		if not positions.has(str(edge["from"])) or not positions.has(str(edge["to"])):
			continue
		var from_point: Vector2 = _anchor(str(edge["from"]), true) * scale
		var to_point: Vector2 = _anchor(str(edge["to"]), false) * scale
		var color: Color = chrome.sheet_map_signal_edge_color \
			if str(edge["kind"]) == EventSheetSheetMap.EDGE_SIGNALS else chrome.sheet_map_edge_color
		canvas.draw_line(from_point, to_point, color, 1.0 * scale)
	for entry: Variant in (found.get("nodes", []) as Array):
		var node: Dictionary = entry
		var id: String = str(node.get("id", ""))
		if not positions.has(id):
			continue
		var box: Rect2 = Rect2((positions[id] as Vector2) * scale,
			Vector2(BOX_WIDTH, BOX_HEIGHT) * scale)
		var tint: Color = _kind_color(str(node.get("kind", "")), chrome)
		canvas.draw_rect(box, Color(tint.r, tint.g, tint.b, 0.16), true)
		canvas.draw_rect(box, tint, false, 1.0 * scale)
		if font != null:
			canvas.draw_string(font, box.position + Vector2(8.0, BOX_HEIGHT * 0.68) * scale,
				str(node.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT,
				box.size.x - 12.0 * scale, font_size, chrome.sheet_map_text_color)


static func _kind_color(kind: String, chrome: EventSheetChromeStyle) -> Color:
	match kind:
		EventSheetSheetMap.NODE_SCENE:
			return chrome.sheet_map_scene_color
		EventSheetSheetMap.NODE_GLOBAL:
			return chrome.sheet_map_global_color
	return chrome.sheet_map_sheet_color


## Where a line leaves or lands on a box: the right edge of the one it comes from, the left edge of
## the one it goes to, so the direction reads without an arrowhead to draw.
func _anchor(id: String, outgoing: bool) -> Vector2:
	var corner: Vector2 = positions.get(id, Vector2.ZERO)
	return corner + Vector2(BOX_WIDTH if outgoing else 0.0, BOX_HEIGHT * 0.5)


# ── Clicking and dragging ─────────────────────────────────────────────────────────────────────


func _on_canvas_input(event: InputEvent) -> void:
	var scale: float = EventSheetPalette.scaled_f(1.0)
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		var at: Vector2 = button.position / scale
		if not button.pressed:
			var released_id: String = _dragging_id
			_dragging_id = ""
			if released_id.is_empty():
				return
			# A press that never moved is a CLICK, and a click on a box opens that sheet - which is
			# what the box is for. A press that moved is a rearrangement, and it is remembered.
			if _drag_moved:
				_remember_positions()
			else:
				_open_node(released_id)
			return
		_drag_moved = false
		var hit_id: String = node_at(at)
		if not hit_id.is_empty():
			_dragging_id = hit_id
			_drag_offset = at - (positions[hit_id] as Vector2)
			return
		var edge: Dictionary = edge_at(at)
		if not edge.is_empty():
			_open_find_for(edge)
		return
	if event is InputEventMouseMotion and not _dragging_id.is_empty():
		_drag_moved = true
		positions[_dragging_id] = ((event as InputEventMouseMotion).position / scale) - _drag_offset
		canvas.custom_minimum_size = _canvas_extent()
		canvas.queue_redraw()


## The node under a point in canvas space, "" for empty space. Pure over the current layout.
func node_at(at: Vector2) -> String:
	for entry: Variant in (found.get("nodes", []) as Array):
		var id: String = str((entry as Dictionary).get("id", ""))
		if not positions.has(id):
			continue
		if Rect2(positions[id] as Vector2, Vector2(BOX_WIDTH, BOX_HEIGHT)).has_point(at):
			return id
	return ""


## The edge under a point in canvas space, {} for none.
func edge_at(at: Vector2) -> Dictionary:
	for entry: Variant in (found.get("edges", []) as Array):
		var edge: Dictionary = entry
		if not positions.has(str(edge["from"])) or not positions.has(str(edge["to"])):
			continue
		if Geometry2D.get_closest_point_to_segment(at, _anchor(str(edge["from"]), true),
				_anchor(str(edge["to"]), false)).distance_to(at) <= HIT_TOLERANCE:
			return edge
	return {}


## A double-click-free open: a single click on a box opens that sheet, because opening it IS what
## the box is for.
func _open_node(id: String) -> void:
	if id.get_extension().to_lower() == "gd":
		_dock.reopen_sheet_path(id)


## A click on a line runs the Find that explains it - the signal's name for a signal edge, the
## global's name for a call, the file's own name for an include or a layout change.
func _open_find_for(edge: Dictionary) -> void:
	_dock._open_project_find(find_query(edge))


## What a click on one edge searches for. Pure, so the pin is a value.
static func find_query(edge: Dictionary) -> String:
	var label: String = str(edge.get("label", ""))
	match str(edge.get("kind", "")):
		EventSheetSheetMap.EDGE_SIGNALS:
			return label.trim_prefix("signals On ")
		EventSheetSheetMap.EDGE_CALLS:
			return label.trim_prefix("calls ")
	return str(edge.get("to", "")).get_file().get_basename()


# ── Where the reader put the boxes ────────────────────────────────────────────────────────────


func _remembered_positions() -> Dictionary:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return {}
	return EditorInterface.get_editor_settings().get_project_metadata("eventsheets", LAYOUT_META, {})


func _remember_positions() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	EditorInterface.get_editor_settings().set_project_metadata("eventsheets", LAYOUT_META, positions)
