@tool
class_name EventSheetSceneEventsCanvas
extends Node2D
# The events overlay's 2D half (V14): the ⌗ badge and its event count drawn beside every node of the
# edited scene that has events. A transient canvas - added with owner null by scene_events_overlay,
# never saved into the scene, and freed the moment the overlay is refreshed or switched off.
#
# Positions are read live each frame so dragging a node in the 2D editor keeps its badge with it.

## `[{"node": Node2D, "count": int}]` - filled by the overlay before this canvas enters the tree.
var entries: Array = []

## How far above the node's own origin the badge sits, so it never covers the sprite it marks.
const BADGE_OFFSET := Vector2(0.0, -22.0)
const BADGE_PADDING := Vector2(6.0, 3.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size: int = ThemeDB.fallback_font_size
	for entry: Variant in entries:
		var node: Node2D = (entry as Dictionary).get("node") as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var text: String = "%s %d" % [EventSheetSceneEvents.BADGE_GLYPH, int((entry as Dictionary).get("count", 0))]
		var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var origin: Vector2 = to_local(node.global_position) + BADGE_OFFSET
		var box: Rect2 = Rect2(origin - Vector2(size.x * 0.5, size.y) - BADGE_PADDING,
			size + BADGE_PADDING * 2.0)
		draw_rect(box, Color(0.12, 0.14, 0.18, 0.85), true)
		draw_rect(box, Color(0.42, 0.47, 0.58, 0.9), false, 1.0)
		draw_string(font, origin - Vector2(size.x * 0.5, 0.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.85, 0.89, 0.97))
