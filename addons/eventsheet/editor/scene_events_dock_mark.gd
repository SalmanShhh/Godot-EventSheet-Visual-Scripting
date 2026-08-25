@tool
class_name EventSheetSceneEventsDockMark
extends Control
# The events overlay's Scene-dock half: the ⌗ badge and its event count drawn at the right
# edge of every Scene-dock row whose node has events, with the node's triggers on hover.
#
# A mouse-transparent Control laid over the dock's own Tree by scene_events_overlay - it draws and
# it answers hovers, and it changes nothing about the Tree itself. Rows are found by NAME (the text
# the dock draws), so a row scrolled out of sight simply has no rectangle and is not drawn.

## node name -> `{"text": String, "tooltip": String}` - filled by the overlay before this enters the
## tree.
var badges: Dictionary = {}
## The Scene-dock Tree this marks. Held as a plain reference; every read is guarded.
var tree: Tree = null

const RIGHT_MARGIN := 8.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null or tree == null or not is_instance_valid(tree):
		return
	var font_size: int = ThemeDB.fallback_font_size
	for row: Dictionary in visible_rows():
		var text: String = str(row.get("text", ""))
		var rect: Rect2 = row.get("rect", Rect2())
		var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var origin: Vector2 = Vector2(rect.position.x + rect.size.x - size.x - RIGHT_MARGIN,
			rect.position.y + (rect.size.y + size.y) * 0.5 - font.get_descent(font_size))
		draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
			Color(0.58, 0.74, 0.95))


## The badge rectangles currently on screen: `[{"name", "text", "tooltip", "rect"}]`. Rows whose
## node has no events, and rows the Tree is not currently laying out, are simply absent.
func visible_rows() -> Array:
	var rows: Array = []
	if tree == null or not is_instance_valid(tree):
		return rows
	var pending: Array[TreeItem] = []
	var root: TreeItem = tree.get_root()
	if root != null:
		pending.append(root)
	while not pending.is_empty():
		var item: TreeItem = pending.pop_front()
		var name: String = item.get_text(0)
		if badges.has(name):
			var rect: Rect2 = tree.get_item_area_rect(item, 0)
			if rect.size.y > 0.0:
				var badge: Dictionary = badges[name]
				rows.append({
					"name": name,
					"text": str(badge.get("text", "")),
					"tooltip": str(badge.get("tooltip", "")),
					"rect": rect,
				})
		var child: TreeItem = item.get_first_child()
		while child != null:
			pending.append(child)
			child = child.get_next()
	return rows


## The triggers of whichever badge the pointer is over - what hovering a badge answers.
func _get_tooltip(at_position: Vector2) -> String:
	for row: Dictionary in visible_rows():
		if (row.get("rect", Rect2()) as Rect2).has_point(at_position):
			return str(row.get("tooltip", ""))
	return ""
