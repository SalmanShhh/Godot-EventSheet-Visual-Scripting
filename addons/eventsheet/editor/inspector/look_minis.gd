# Godot EventSheets - the small picture of each look, drawn the same everywhere a look is listed.
#
# Every picture is a few shapes in the editor's own colours, never a screenshot, so it follows the
# theme. A look with no picture of its own gets the plain field.
@tool
class_name EventSheetLookMinis
extends RefCounted


## Draws the picture of `look_id` inside `rect` on `canvas`.
static func draw_mini(canvas: CanvasItem, rect: Rect2, look_id: String) -> void:
	canvas.draw_style_box(EventSheetLookStyle.field_box(), rect)
	var accent: Color = EventSheetLookStyle.accent()
	var rest: Color = EventSheetLookStyle.rest()
	var ink: Color = EventSheetLookStyle.ink()
	var centre: Vector2 = rect.get_center()
	var inner: Rect2 = rect.grow(-EventSheetLookStyle.px(5.0))
	match look_id:
		"progress_bar":
			canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x * 0.6, inner.size.y)), accent)
		"vector_dial":
			var radius: float = minf(inner.size.x, inner.size.y) * 0.5
			canvas.draw_arc(centre, radius, 0.0, TAU, 24, rest, 1.0, true)
			canvas.draw_line(centre, centre + Vector2(radius * 0.8, -radius * 0.4), accent, 2.0, true)
		"min_max":
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.end.x, centre.y), rest, 2.0)
			canvas.draw_line(Vector2(inner.position.x + inner.size.x * 0.3, centre.y), Vector2(inner.position.x + inner.size.x * 0.75, centre.y), accent, 3.0)
		"swatch_row":
			var colours: Array[Color] = [EventSheetLookStyle.error(), EventSheetLookStyle.warning(), accent, ink]
			for index: int in colours.size():
				canvas.draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.25 * index, 0.0), Vector2(inner.size.x * 0.22, inner.size.y)), colours[index])
		"corners":
			for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end]:
				canvas.draw_circle(corner, 2.0, rest)
		"toggle_row":
			for index: int in 3:
				var cell: Rect2 = Rect2(inner.position + Vector2(inner.size.x / 3.0 * index, 0.0), Vector2(inner.size.x / 3.0 - 1.0, inner.size.y))
				canvas.draw_rect(cell, accent if index == 1 else rest)
		"table", "table_row":
			for row_index: int in 3:
				var y: float = inner.position.y + inner.size.y * 0.5 * row_index
				canvas.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), rest, 1.0)
			canvas.draw_line(Vector2(centre.x, inner.position.y), Vector2(centre.x, inner.end.y), rest, 1.0)
		"texture_preview":
			var half: Vector2 = inner.size * 0.5
			canvas.draw_rect(Rect2(inner.position, half), rest)
			canvas.draw_rect(Rect2(inner.position + half, half), rest)
		"curve_editor":
			var points: PackedVector2Array = PackedVector2Array()
			for step: int in 9:
				var t: float = step / 8.0
				points.append(Vector2(inner.position.x + inner.size.x * t, inner.end.y - inner.size.y * (0.5 - 0.5 * cos(t * PI))))
			canvas.draw_polyline(points, accent, 1.5, true)
		"unit":
			var x: float = inner.position.x + inner.size.x * 0.65
			canvas.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), rest, 1.0)
		_:
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.end.x, centre.y), rest, 2.0)
