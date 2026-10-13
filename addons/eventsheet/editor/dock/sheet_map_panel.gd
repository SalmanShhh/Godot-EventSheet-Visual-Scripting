# Godot EventSheets - the Sheet map window
#
# The graph sheet_map.gd derives, drawn: sheets, scenes and globals as boxes, and the four ways one
# reaches another as lines between them. Click a box to open that sheet; click a line to run the
# Find that explains it. A box is as wide as the name in it, because the map is a picture of names.
# Boxes lay themselves out in columns by kind and can be dragged, and where
# you drag one is remembered per project in editor metadata - the picture is derived, the
# arrangement is yours.
@tool
class_name EventSheetSheetMapPanel
extends RefCounted

## Author these at 1x; they are multiplied by the editor's display scale at use time.
## BOX_WIDTH is the NARROWEST a box gets - a box whose name does not fit in it grows to hold the
## whole name, because a sheet nobody can read the name of is a box nobody can use.
const BOX_WIDTH := 148.0
const BOX_HEIGHT := 34.0
const COLUMN_GAP := 56.0
const ROW_GAP := 18.0
const MARGIN := 16.0
const HIT_TOLERANCE := 6.0
## The clear space between a box's edge and its name, on each side.
const TEXT_INSET := 8.0
## How far apart two labels sharing one pair of boxes sit, so neither is drawn over the other.
const EDGE_LABEL_STEP := 14.0

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
## node id -> float, how wide its box has to be to hold its name. Authored at 1x like the constants.
var widths: Dictionary = {}

var _dragging_id: String = ""
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_moved: bool = false


func _init(dock: Control) -> void:
	_dock = dock


## Where every box sits before anyone drags one: one column per kind (globals, sheets, scenes),
## each in the graph's own order. A column is as wide as its widest box, so a long name pushes the
## NEXT column over rather than overlapping it. `widths` is node id -> box width (from
## `label_widths`); leave it out and every box is the standard width. Pure over the nodes, so a test
## pins the arrangement.
static func default_positions(nodes: Array, widths_by_id: Dictionary = {}) -> Dictionary:
	var placed: Dictionary = {}
	var per_column: Dictionary = {}
	var columns: PackedStringArray = PackedStringArray([EventSheetSheetMap.NODE_GLOBAL,
		EventSheetSheetMap.NODE_SHEET, EventSheetSheetMap.NODE_SCENE])
	var column_of: Dictionary = {}
	var column_widths: Dictionary = {}
	for entry: Variant in nodes:
		var node: Dictionary = entry
		var id: String = str(node.get("id", ""))
		var column: int = maxi(columns.find(str(node.get("kind", ""))), 0)
		column_of[id] = column
		column_widths[column] = maxf(float(column_widths.get(column, BOX_WIDTH)),
			float(widths_by_id.get(id, BOX_WIDTH)))
	for entry: Variant in nodes:
		var node: Dictionary = entry
		var id: String = str(node.get("id", ""))
		var column: int = int(column_of.get(id, 0))
		var row: int = int(per_column.get(column, 0))
		per_column[column] = row + 1
		placed[id] = Vector2(_column_left(column, column_widths),
			MARGIN + row * (BOX_HEIGHT + ROW_GAP))
	return placed


## The left edge of one column: every column before it, each as wide as its own widest box, plus the
## gap between them. An empty column still holds a standard width open, so adding the project's first
## global never shoves the sheets sideways.
static func _column_left(column: int, column_widths: Dictionary) -> float:
	var left: float = MARGIN
	for index: int in range(column):
		left += maxf(float(column_widths.get(index, BOX_WIDTH)), BOX_WIDTH) + COLUMN_GAP
	return left


## How wide each node's box has to be, node id -> width at 1x. `scale` is the display scale the font
## is already sized in, so the answer comes back in the same 1x space the constants are authored in.
static func label_widths(nodes: Array, font: Font, font_size: int, scale: float) -> Dictionary:
	var measured: Dictionary = {}
	for entry: Variant in nodes:
		var node: Dictionary = entry
		measured[str(node.get("id", ""))] = width_for_label(str(node.get("label", "")), font,
			font_size, scale)
	return measured


## One box's width: never narrower than BOX_WIDTH, never narrower than the name plus its clear space
## on both sides. Pure, so a test pins that a long name really does get a box that holds it.
static func width_for_label(label: String, font: Font, font_size: int, scale: float) -> float:
	if font == null:
		return BOX_WIDTH
	var text_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		font_size).x / maxf(scale, 0.01)
	return maxf(BOX_WIDTH, text_width + TEXT_INSET * 2.0)


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
	widths = label_widths(found.get("nodes", []) as Array, _map_font(), _map_font_size(),
		EventSheetPalette.scaled_f(1.0))
	positions = default_positions(found.get("nodes", []) as Array, widths)
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
		var corner: Vector2 = (positions[id] as Vector2) + Vector2(width_of(id), BOX_HEIGHT) + Vector2(MARGIN, MARGIN)
		extent = Vector2(maxf(extent.x, corner.x), maxf(extent.y, corner.y))
	return EventSheetPalette.scaled_f(1.0) * extent


## One box's width at 1x, standard until its name asks for more.
func width_of(id: String) -> float:
	return maxf(float(widths.get(id, BOX_WIDTH)), BOX_WIDTH)


## The font the map's names are drawn in. The canvas's own before it exists is the editor's default,
## which is what a headless refresh measures against.
func _map_font() -> Font:
	if canvas != null and canvas.get_theme_default_font() != null:
		return canvas.get_theme_default_font()
	return ThemeDB.fallback_font


func _map_font_size() -> int:
	if canvas != null:
		return canvas.get_theme_default_font_size()
	return ThemeDB.fallback_font_size


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
		var points: PackedVector2Array = edge_points(str(edge["from"]), str(edge["to"]))
		var color: Color = chrome.sheet_map_signal_edge_color \
			if str(edge["kind"]) == EventSheetSheetMap.EDGE_SIGNALS else chrome.sheet_map_edge_color
		canvas.draw_line(points[0] * scale, points[1] * scale, color, 1.0 * scale)
	# Each line says what it is ("includes", "calls Game", "signals On died") at its middle, so the
	# picture reads without clicking every line to find out.
	if font != null:
		var label_size: int = maxi(int(round(font_size * 0.85)), 8)
		for spot: Dictionary in edge_label_spots():
			var text: String = str(spot["text"])
			var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size).x
			canvas.draw_string(font, (spot["position"] as Vector2) * scale - Vector2(text_width * 0.5, 0.0),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_size, chrome.sheet_map_text_color)
	for entry: Variant in (found.get("nodes", []) as Array):
		var node: Dictionary = entry
		var id: String = str(node.get("id", ""))
		if not positions.has(id):
			continue
		var box: Rect2 = Rect2((positions[id] as Vector2) * scale,
			Vector2(width_of(id), BOX_HEIGHT) * scale)
		var tint: Color = _kind_color(str(node.get("kind", "")), chrome)
		canvas.draw_rect(box, Color(tint.r, tint.g, tint.b, 0.16), true)
		canvas.draw_rect(box, tint, false, 1.0 * scale)
		if font != null:
			canvas.draw_string(font, box.position + Vector2(TEXT_INSET, BOX_HEIGHT * 0.68) * scale,
				str(node.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT,
				box.size.x - TEXT_INSET * 2.0 * scale, font_size, chrome.sheet_map_text_color)


static func _kind_color(kind: String, chrome: EventSheetChromeStyle) -> Color:
	match kind:
		EventSheetSheetMap.NODE_SCENE:
			return chrome.sheet_map_scene_color
		EventSheetSheetMap.NODE_GLOBAL:
			return chrome.sheet_map_global_color
	return chrome.sheet_map_sheet_color


## Where one line leaves its box and lands on the other, at 1x: the facing edges of the two boxes,
## so a line never runs through either of them. A target to the right is left from the right edge
## and landed on at its left edge; a target to the left the other way round; a box above or below
## (the same column) is joined bottom edge to top edge. Pure over the current layout.
func edge_points(from_id: String, to_id: String) -> PackedVector2Array:
	var from_box: Rect2 = Rect2(positions.get(from_id, Vector2.ZERO) as Vector2, Vector2(width_of(from_id), BOX_HEIGHT))
	var to_box: Rect2 = Rect2(positions.get(to_id, Vector2.ZERO) as Vector2, Vector2(width_of(to_id), BOX_HEIGHT))
	if to_box.position.x >= from_box.end.x:
		return PackedVector2Array([Vector2(from_box.end.x, from_box.get_center().y),
			Vector2(to_box.position.x, to_box.get_center().y)])
	if to_box.end.x <= from_box.position.x:
		return PackedVector2Array([Vector2(from_box.position.x, from_box.get_center().y),
			Vector2(to_box.end.x, to_box.get_center().y)])
	if to_box.get_center().y >= from_box.get_center().y:
		return PackedVector2Array([Vector2(from_box.get_center().x, from_box.end.y),
			Vector2(to_box.get_center().x, to_box.position.y)])
	return PackedVector2Array([Vector2(from_box.get_center().x, from_box.position.y),
		Vector2(to_box.get_center().x, to_box.end.y)])


## Where each line's words go, at 1x: [{text, position}], the position being the middle of the line
## the text is centred on. Lines between the same two boxes share a middle, so each later one steps
## down a line rather than printing over the one before. Pure over the current layout.
func edge_label_spots() -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var per_pair: Dictionary = {}
	for entry: Variant in (found.get("edges", []) as Array):
		var edge: Dictionary = entry
		var from_id: String = str(edge["from"])
		var to_id: String = str(edge["to"])
		if not positions.has(from_id) or not positions.has(to_id) or str(edge.get("label", "")).is_empty():
			continue
		var pair: String = "%s|%s" % ([from_id, to_id] if from_id < to_id else [to_id, from_id])
		var stacked: int = int(per_pair.get(pair, 0))
		per_pair[pair] = stacked + 1
		var points: PackedVector2Array = edge_points(from_id, to_id)
		spots.append({
			"text": str(edge["label"]),
			"position": (points[0] + points[1]) * 0.5 + Vector2(0.0, -4.0 + EDGE_LABEL_STEP * stacked),
		})
	return spots


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
		if Rect2(positions[id] as Vector2, Vector2(width_of(id), BOX_HEIGHT)).has_point(at):
			return id
	return ""


## The edge under a point in canvas space, {} for none.
func edge_at(at: Vector2) -> Dictionary:
	for entry: Variant in (found.get("edges", []) as Array):
		var edge: Dictionary = entry
		if not positions.has(str(edge["from"])) or not positions.has(str(edge["to"])):
			continue
		var points: PackedVector2Array = edge_points(str(edge["from"]), str(edge["to"]))
		if Geometry2D.get_closest_point_to_segment(at, points[0], points[1]).distance_to(at) <= HIT_TOLERANCE:
			return edge
	return {}


## A double-click-free open: a single click on a box opens what the box stands for, because opening
## it IS what the box is for - a sheet (or a script global) as a sheet, a scene (or a scene global) in
## Godot's own scene editor.
func _open_node(id: String) -> void:
	match id.get_extension().to_lower():
		"gd":
			_dock.reopen_sheet_path(id)
		"tscn", "scn":
			_dock._project_bar_glue._open_scene(id)


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
