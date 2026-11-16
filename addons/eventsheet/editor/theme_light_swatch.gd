# Godot EventSheets - the swatch of a theme's light colour in the Theme Editor.
#
# A colour picker that draws a dashed line round itself and the word "auto" on it while its colour is
# worked out for the theme rather than chosen: picking a colour (or the chain beside it) makes it the
# theme's own, and the dashes go.
#
# DELIBERATELY NO `class_name`: the window builds it by path when a theme is opened.
@tool
extends ColorPickerButton


## True while the colour is worked out, not chosen.
var auto: bool = false:
	set(value):
		if auto != value:
			auto = value
			queue_redraw()


func _draw() -> void:
	if not auto:
		return
	var ink: Color = Color(0.0, 0.0, 0.0, 0.7) if color.get_luminance() > 0.45 else Color(1.0, 1.0, 1.0, 0.8)
	var box: Rect2 = Rect2(Vector2.ZERO, size).grow(-2.0)
	var corners: Array[Vector2] = [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	for index: int in range(4):
		draw_dashed_line(corners[index], corners[(index + 1) % 4], ink, 1.0, 3.0)
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(get_theme_default_font_size() - 2, 8)
	var word: String = EventSheetL10n.translate("auto")
	var at: Vector2 = Vector2(0.0, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, ink)
