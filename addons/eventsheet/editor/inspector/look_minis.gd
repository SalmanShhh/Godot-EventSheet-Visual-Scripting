# Godot EventSheets - the small picture of each look, drawn the same everywhere a look is listed.
#
# Every picture is a few shapes drawn from the colours the caller hands in, never a screenshot, so
# the same painter serves the editor (its own theme colours) and a test (fixed colours). A look
# with no picture of its own gets a plain field.
@tool
class_name EventSheetLookMinis
extends RefCounted

## The size of a picture, in unscaled pixels.
const WIDTH: float = 64.0
const HEIGHT: float = 36.0
## The keys a colour set carries.
const COLOUR_KEYS: Array[String] = ["field", "accent", "rest", "ink", "error", "warning"]


## The colour set the editor's own theme gives: the field fill, the highlight, the idle grey, the
## text colour and the two tones swatches borrow.
static func theme_colours() -> Dictionary:
	return {
		"field": EventSheetLookStyle.field_fill(),
		"accent": EventSheetLookStyle.accent(),
		"rest": EventSheetLookStyle.rest(),
		"ink": EventSheetLookStyle.ink(),
		"error": EventSheetLookStyle.error(),
		"warning": EventSheetLookStyle.warning(),
	}


## The look ids that have a picture of their own, for a test to hold the list against.
static func drawn_ids() -> PackedStringArray:
	return PackedStringArray(["slider", "angle", "exp_slider", "no_handle", "progress_bar", "number_choices", "flags", "layers",
		"easing", "unit", "file", "folder", "multiline", "placeholder", "choices", "suggestions", "toggle_row", "password",
		"expression", "no_alpha", "swatch_row", "link", "vector_dial", "min_max", "corners", "node_path", "tool_button",
		"texture_preview", "curve_editor", "table", "table_row", "table_tag", "seed", "custom", "storage"])


## Draws the picture of `look_id` inside `rect` on `canvas`, in the colours of `colours` (see COLOUR_KEYS).
static func draw_mini(canvas: CanvasItem, rect: Rect2, look_id: String, colours: Dictionary) -> void:
	var field: Color = colours.get("field", Color.BLACK)
	var accent: Color = colours.get("accent", Color.WHITE)
	var rest: Color = colours.get("rest", Color.GRAY)
	var ink: Color = colours.get("ink", Color.WHITE)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = field
	box.set_corner_radius_all(int(EventSheetLookStyle.px(3.0)))
	canvas.draw_style_box(box, rect)
	var pad: float = EventSheetLookStyle.px(6.0)
	var inner: Rect2 = rect.grow(-pad)
	var centre: Vector2 = rect.get_center()
	var line: float = maxf(1.0, EventSheetLookStyle.px(1.5))
	match look_id:
		"progress_bar":
			var track: Rect2 = Rect2(inner.position.x, centre.y - inner.size.y * 0.2, inner.size.x, inner.size.y * 0.4)
			canvas.draw_rect(track, rest)
			canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * 0.6, track.size.y)), accent)
		"slider", "angle", "exp_slider", "no_handle":
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.end.x, centre.y), rest, line * 1.5)
			var knob_x: float = inner.position.x + inner.size.x * (0.2 if look_id == "exp_slider" else 0.35)
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(knob_x, centre.y), accent, line * 1.5)
			if look_id != "no_handle":
				canvas.draw_circle(Vector2(knob_x, centre.y), inner.size.y * 0.22, ink)
			if look_id == "angle":
				canvas.draw_arc(Vector2(inner.end.x - inner.size.y * 0.3, centre.y), inner.size.y * 0.28, -PI * 0.75, PI * 0.25, 10, accent, line)
		"vector_dial":
			var radius: float = minf(inner.size.x, inner.size.y) * 0.5
			canvas.draw_arc(centre, radius, 0.0, TAU, 28, rest, line, true)
			canvas.draw_line(centre, centre + Vector2(radius * 0.8, -radius * 0.45), accent, line * 1.5, true)
			canvas.draw_circle(centre, line * 1.2, ink)
		"min_max":
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.end.x, centre.y), rest, line * 1.5)
			var low: float = inner.position.x + inner.size.x * 0.25
			var high: float = inner.position.x + inner.size.x * 0.75
			canvas.draw_line(Vector2(low, centre.y), Vector2(high, centre.y), accent, line * 2.5)
			canvas.draw_circle(Vector2(low, centre.y), inner.size.y * 0.2, ink)
			canvas.draw_circle(Vector2(high, centre.y), inner.size.y * 0.2, ink)
		"swatch_row":
			var tones: Array[Color] = [colours.get("error", Color.RED), colours.get("warning", Color.YELLOW), accent, ink]
			var cell: float = (inner.size.x - pad * 0.5 * 3.0) / 4.0
			for index: int in tones.size():
				canvas.draw_rect(Rect2(inner.position + Vector2((cell + pad * 0.5) * index, inner.size.y * 0.1), Vector2(cell, inner.size.y * 0.8)), tones[index])
		"corners":
			var side: float = inner.size.y * 0.55
			for corner: Vector2 in [Vector2(inner.position.x, inner.position.y), Vector2(inner.end.x - side, inner.position.y),
					Vector2(inner.position.x, inner.end.y - side), Vector2(inner.end.x - side, inner.end.y - side)]:
				canvas.draw_rect(Rect2(corner, Vector2(side * 0.9, side * 0.9)), rest)
		"link":
			var half: float = inner.size.x * 0.38
			canvas.draw_rect(Rect2(inner.position.x, centre.y - inner.size.y * 0.25, half, inner.size.y * 0.5), rest)
			canvas.draw_rect(Rect2(inner.end.x - half, centre.y - inner.size.y * 0.25, half, inner.size.y * 0.5), rest)
			canvas.draw_line(Vector2(inner.position.x + half, centre.y), Vector2(inner.end.x - half, centre.y), accent, line * 1.5)
		"toggle_row":
			var part: float = inner.size.x / 3.0
			for index: int in 3:
				canvas.draw_rect(Rect2(inner.position + Vector2(part * index, inner.size.y * 0.1), Vector2(part - 1.0, inner.size.y * 0.8)), accent if index == 1 else rest)
		"table", "table_row":
			for row_index: int in 4:
				var y: float = inner.position.y + inner.size.y * row_index / 3.0
				canvas.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), rest, 1.0)
			for column: int in 3:
				var x: float = inner.position.x + inner.size.x * column / 2.0
				canvas.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), rest, 1.0)
		"texture_preview":
			var tile: float = inner.size.y * 0.5
			for row_index: int in 2:
				for column: int in 4:
					if (row_index + column) % 2 == 0:
						canvas.draw_rect(Rect2(centre.x - tile * 2.0 + tile * column, inner.position.y + tile * row_index, tile, tile), rest)
		"curve_editor":
			var points: PackedVector2Array = PackedVector2Array()
			for step: int in 11:
				var t: float = step / 10.0
				points.append(Vector2(inner.position.x + inner.size.x * t, inner.end.y - inner.size.y * (0.5 - 0.5 * cos(t * PI))))
			canvas.draw_polyline(points, accent, line * 1.5, true)
		"easing":
			var curve: PackedVector2Array = PackedVector2Array()
			for step: int in 11:
				var t2: float = step / 10.0
				curve.append(Vector2(inner.position.x + inner.size.x * t2, inner.end.y - inner.size.y * pow(t2, 2.2)))
			canvas.draw_polyline(curve, accent, line * 1.5, true)
		"unit":
			var x_line: float = inner.position.x + inner.size.x * 0.62
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(x_line - pad * 0.4, centre.y), rest, line * 1.5)
			canvas.draw_line(Vector2(x_line + pad * 0.4, centre.y), Vector2(inner.end.x, centre.y), accent, line * 1.5)
			canvas.draw_line(Vector2(x_line, inner.position.y), Vector2(x_line, inner.end.y), rest, 1.0)
		"number_choices", "choices", "suggestions":
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.end.x - pad * 1.6, centre.y), rest, line * 1.5)
			var arrow: Vector2 = Vector2(inner.end.x - pad * 0.7, centre.y)
			canvas.draw_colored_polygon(PackedVector2Array([arrow + Vector2(-pad * 0.6, -pad * 0.3), arrow + Vector2(pad * 0.6, -pad * 0.3), arrow + Vector2(0.0, pad * 0.4)]), ink if look_id == "suggestions" else accent)
		"flags", "layers":
			var count: int = 4 if look_id == "flags" else 8
			var columns: int = count if look_id == "flags" else 4
			var rows: int = ceili(float(count) / float(columns))
			var step_size: float = minf(inner.size.x / columns, inner.size.y / rows)
			var cell_size: float = step_size * 0.7
			var origin: Vector2 = centre - Vector2(step_size * columns, step_size * rows) * 0.5
			for index: int in count:
				canvas.draw_rect(Rect2(origin + Vector2((index % columns) * step_size, floori(float(index) / float(columns)) * step_size), Vector2(cell_size, cell_size)), accent if index % 3 == 0 else rest)
		"file", "folder":
			var back: Rect2 = Rect2(inner.position.x + inner.size.x * 0.25, inner.position.y + inner.size.y * 0.15, inner.size.x * 0.5, inner.size.y * 0.75)
			canvas.draw_rect(back, rest)
			if look_id == "folder":
				canvas.draw_rect(Rect2(back.position, Vector2(back.size.x * 0.4, back.size.y * 0.2)), accent)
			else:
				canvas.draw_rect(Rect2(back.end.x - back.size.x * 0.3, back.position.y, back.size.x * 0.3, back.size.y * 0.3), accent)
		"multiline":
			for index: int in 3:
				var y_text: float = inner.position.y + inner.size.y * (0.15 + 0.35 * index)
				canvas.draw_line(Vector2(inner.position.x, y_text), Vector2(inner.end.x - (inner.size.x * 0.3 if index == 2 else 0.0), y_text), rest, line)
		"placeholder":
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.position.x + inner.size.x * 0.7, centre.y), rest, line)
			canvas.draw_line(Vector2(inner.position.x, centre.y - inner.size.y * 0.3), Vector2(inner.position.x, centre.y + inner.size.y * 0.3), accent, line)
		"password":
			for index: int in 4:
				canvas.draw_circle(Vector2(inner.position.x + inner.size.x * (0.12 + 0.25 * index), centre.y), inner.size.y * 0.14, ink)
		"expression":
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.position.x + inner.size.x * 0.2, centre.y), accent, line * 1.5)
			canvas.draw_line(Vector2(inner.position.x + inner.size.x * 0.3, centre.y - inner.size.y * 0.25), Vector2(inner.position.x + inner.size.x * 0.3, centre.y + inner.size.y * 0.25), rest, line)
			canvas.draw_line(Vector2(inner.position.x + inner.size.x * 0.4, centre.y), Vector2(inner.end.x, centre.y), rest, line * 1.5)
		"no_alpha":
			canvas.draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * 0.1, inner.size.x, inner.size.y * 0.8), accent)
		"node_path":
			canvas.draw_circle(Vector2(inner.position.x + inner.size.x * 0.2, centre.y), inner.size.y * 0.2, accent)
			canvas.draw_line(Vector2(inner.position.x + inner.size.x * 0.32, centre.y), Vector2(inner.end.x, centre.y), rest, line * 1.5)
		"tool_button":
			var button: StyleBoxFlat = StyleBoxFlat.new()
			button.bg_color = rest
			button.set_corner_radius_all(int(EventSheetLookStyle.px(3.0)))
			canvas.draw_style_box(button, Rect2(inner.position.x + inner.size.x * 0.15, inner.position.y + inner.size.y * 0.1, inner.size.x * 0.7, inner.size.y * 0.8))
		"table_tag":
			# A field with a small tag beside it: a pointed label shape and a line of text.
			var tag: Rect2 = Rect2(inner.position.x, centre.y - inner.size.y * 0.3, inner.size.x * 0.42, inner.size.y * 0.6)
			canvas.draw_colored_polygon(PackedVector2Array([tag.position, Vector2(tag.end.x - tag.size.y * 0.3, tag.position.y), Vector2(tag.end.x, centre.y),
				Vector2(tag.end.x - tag.size.y * 0.3, tag.end.y), Vector2(tag.position.x, tag.end.y)]), accent)
			canvas.draw_line(Vector2(tag.end.x + pad * 0.8, centre.y), Vector2(inner.end.x, centre.y), rest, line * 1.5)
		"seed":
			# A die: a rounded square with three pips.
			var die: float = inner.size.y * 0.9
			var face: Rect2 = Rect2(centre.x - die * 0.5, centre.y - die * 0.5, die, die)
			var die_box: StyleBoxFlat = StyleBoxFlat.new()
			die_box.bg_color = rest
			die_box.set_corner_radius_all(int(EventSheetLookStyle.px(3.0)))
			canvas.draw_style_box(die_box, face)
			for pip: Vector2 in [Vector2(0.25, 0.25), Vector2(0.5, 0.5), Vector2(0.75, 0.75)]:
				canvas.draw_circle(face.position + face.size * pip, die * 0.09, accent)
		"custom":
			# Your own hint: a field that holds a hint written by hand, three dots where the words go.
			for index: int in 3:
				canvas.draw_circle(Vector2(centre.x + (index - 1) * inner.size.y * 0.5, centre.y), inner.size.y * 0.14, ink)
		"storage":
			# Saved but hidden: the field is there and drawn faint, with a line struck through it.
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.end.x, centre.y), rest, line * 1.5)
			canvas.draw_line(Vector2(inner.position.x + inner.size.x * 0.3, inner.end.y), Vector2(inner.end.x - inner.size.x * 0.3, inner.position.y), ink, line * 1.5, true)
		_:
			canvas.draw_line(Vector2(inner.position.x, centre.y), Vector2(inner.end.x, centre.y), rest, line * 1.5)
