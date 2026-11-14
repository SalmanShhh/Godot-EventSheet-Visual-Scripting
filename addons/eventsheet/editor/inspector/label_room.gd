# Godot EventSheets - keeps an Inspector property's name whole when its field is wide.
#
# Godot gives a field the room it asks for before the label, so a field wider than the half it is
# offered shortens the name to "Thickn". A look that draws a wide field calls place() when its row is
# resized: the field stays beside its name while the row has room for both, and goes under the name
# (Godot's own bottom editor) when it has not. Loaded by path by the one look that uses it, so the
# editor's first open compiles none of it.
@tool
extends RefCounted

## The room, at 1x, the name needs beyond its words: the indent Godot gives it and the gap after it.
const LABEL_PADDING: float = 28.0


## True when a field this wide leaves a name this wide its room in a row this wide. A row with no width
## yet (not laid out) fits, so nothing moves before the layout has run.
static func fits_beside(row_width: float, field_width: float, label_width: float) -> bool:
	return row_width <= 0.0 or row_width - field_width >= label_width


## Moves `field` of the property `row` beside or under its name, for the row's current width. Returns
## true when the field is beside its name, so the caller can remember it and skip the next identical call.
static func place(row: EditorProperty, field: Control, was_beside: bool) -> bool:
	var font: Font = row.get_theme_font(&"main", &"EditorFonts")
	var label_width: float = EventSheetLookStyle.px(LABEL_PADDING)
	if font != null:
		label_width += font.get_string_size(str(row.get(&"label")), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			row.get_theme_font_size(&"main_size", &"EditorFonts")).x
	var beside: bool = fits_beside(row.size.x, field.get_combined_minimum_size().x, label_width)
	if beside != was_beside:
		row.set_bottom_editor(null if beside else field)
		row.queue_sort()
	return beside
