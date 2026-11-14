# Godot EventSheets - the one place an Inspector look asks Godot's editor theme what things look like.
#
# A look sits next to Godot's own fields, so it must read like them: the field box, the accent, the
# ink, the heights and the fonts all come from the running editor's theme, never from a colour typed
# in a widget. Every getter here asks the editor theme first and falls back to the sheet theme's
# drawer tokens when there is no editor around (the headless suite, a plain --script harness), so a
# widget still builds there and a test can still hold it.
#
# A size that has no theme item is a named constant below, always passed through px() so it follows
# the editor scale. The editor theme is read through the EditorInterface singleton by NAME, so this
# file loads where no editor class exists.
@tool
class_name EventSheetLookStyle
extends RefCounted

## What a note line is saying; picks its colour.
enum Tone { NOTE, WARNING, ERROR }

## Sizes Godot's theme has no item for, at 1x. Read them only through px().
const DIAL_HEIGHT: float = 100.0
const DIAL_RING: float = 68.0
const DIAL_HANDLE: float = 10.0
const CURVE_HEIGHT: float = 64.0
const PICTURE_HEIGHT: float = 72.0
const RANGE_FIELD_WIDTH: float = 44.0
const LINE_WIDTH: float = 2.0
## The height of a plain field when no editor theme can say.
const FALLBACK_FIELD_HEIGHT: float = 22.0
## No colour asked for: a field made with this keeps its own label colour.
const SPIN_PADDING: float = 12.0
const NO_COLOUR: Color = Color(0.0, 0.0, 0.0, 0.0)
## How far a note under a field is dimmed when the editor carries no quiet colour.
const FALLBACK_QUIET_ALPHA: float = 0.6

const THEME_EDITOR: StringName = &"Editor"
const THEME_ICONS: StringName = &"EditorIcons"
const THEME_STYLES: StringName = &"EditorStyles"
const THEME_FONTS: StringName = &"EditorFonts"


## The running editor's theme, or null when there is no editor (headless, a plain --script run).
static func editor_theme() -> Theme:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var interface: Object = Engine.get_singleton("EditorInterface")
	if interface == null or not interface.has_method("get_editor_theme"):
		return null
	return interface.call("get_editor_theme") as Theme


## A 1x-authored metric through the editor scale.
static func px(amount: float) -> float:
	return EventSheetPalette.scaled_f(amount)


static func _colour(item: StringName, theme_type: StringName, fallback: Color) -> Color:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_color(item, theme_type):
		return theme.get_color(item, theme_type)
	return fallback


## The highlight Godot paints a chosen or filled thing with.
static func accent() -> Color:
	return _colour(&"accent_color", THEME_EDITOR, EventSheetActiveTheme.chrome().drawer_accent_color)


## The ordinary text colour of the editor.
static func ink() -> Color:
	return _colour(&"font_color", THEME_EDITOR, EventSheetActiveTheme.chrome().drawer_ink_color)


## A dimmer text colour for words that explain rather than say.
static func quiet() -> Color:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_color(&"font_placeholder_color", &"LineEdit"):
		return theme.get_color(&"font_placeholder_color", &"LineEdit")
	var base: Color = ink()
	return Color(base, FALLBACK_QUIET_ALPHA)


## The colour of a thing at rest: grid lines, an idle track.
static func rest() -> Color:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_color(&"font_disabled_color", THEME_EDITOR):
		return theme.get_color(&"font_disabled_color", THEME_EDITOR)
	var base: Color = ink()
	return Color(base, FALLBACK_QUIET_ALPHA * 0.5)


static func error() -> Color:
	return _colour(&"error_color", THEME_EDITOR, EventSheetActiveTheme.chrome().drawer_required_color)


static func warning() -> Color:
	return _colour(&"warning_color", THEME_EDITOR, EventSheetActiveTheme.chrome().drawer_validate_color)


## The colour Godot gives axis `index` (0 = x, 1 = y, 2 = z, 3 = w).
static func axis_color(index: int) -> Color:
	var names: Array[StringName] = [&"property_color_x", &"property_color_y", &"property_color_z", &"property_color_w"]
	return _colour(names[clampi(index, 0, 3)], THEME_EDITOR, ink())


## Whichever of the editor's ink and base colours reads better on the accent.
static func ink_on_accent() -> Color:
	var fill: Color = accent()
	var dark: Color = _colour(&"base_color", THEME_EDITOR, EventSheetActiveTheme.chrome().drawer_handle_border_color)
	var light: Color = ink()
	light.a = 1.0
	dark.a = 1.0
	return light if contrast_ratio(light, fill) >= contrast_ratio(dark, fill) else dark


## WCAG contrast ratio between two opaque colours, 1.0 (none) to 21.0.
static func contrast_ratio(a: Color, b: Color) -> float:
	var lighter: float = maxf(a.get_luminance(), b.get_luminance())
	var darker: float = minf(a.get_luminance(), b.get_luminance())
	return (lighter + 0.05) / (darker + 0.05)


## The box a text field wears, a copy the caller may change. `locked` asks for the read-only one.
static func field_box(locked: bool = false) -> StyleBox:
	var theme: Theme = editor_theme()
	var item: StringName = &"read_only" if locked else &"normal"
	if theme != null and theme.has_stylebox(item, &"LineEdit"):
		return theme.get_stylebox(item, &"LineEdit").duplicate() as StyleBox
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = EventSheetActiveTheme.chrome().drawer_well_color
	flat.set_corner_radius_all(int(px(3.0)))
	flat.set_content_margin_all(px(4.0))
	return flat


## The box a block of controls sits in (a table, a card list, a picture): the editor's sub-inspector
## fill with no border, so it reads as a quiet panel rather than an outlined box.
static func panel_box() -> StyleBox:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_stylebox(&"sub_inspector_bg0", THEME_STYLES):
		var box: StyleBox = theme.get_stylebox(&"sub_inspector_bg0", THEME_STYLES).duplicate() as StyleBox
		var flat: StyleBoxFlat = box as StyleBoxFlat
		if flat != null:
			flat.set_border_width_all(0)
		return box
	return field_box()


## The height of one Inspector row's field.
static func field_height() -> float:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_constant(&"inspector_property_height", THEME_EDITOR):
		return float(theme.get_constant(&"inspector_property_height", THEME_EDITOR))
	return px(FALLBACK_FIELD_HEIGHT)


## The editor's own text font, or null (the control then keeps whatever it inherits).
static func font() -> Font:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_font(&"font", &"Label"):
		return theme.get_font(&"font", &"Label")
	return ThemeDB.fallback_font


static func font_size() -> int:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_font_size(&"font_size", &"Label"):
		return theme.get_font_size(&"font_size", &"Label")
	return ThemeDB.fallback_font_size


static func bold_font() -> Font:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_font(&"bold", THEME_FONTS):
		return theme.get_font(&"bold", THEME_FONTS)
	return font()


## One of the editor's icons by its Godot name, or null when the editor has none of that name.
static func icon(icon_name: StringName) -> Texture2D:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_icon(icon_name, THEME_ICONS):
		return theme.get_icon(icon_name, THEME_ICONS)
	return null


## The same icon, or null when it is missing; the caller then falls back to a text glyph.
static func has_icon(icon_name: StringName) -> bool:
	return icon(icon_name) != null


## Which outer corners of a joined strip button stay round: [left, right] for the button at `index`
## of `count`. A lone button keeps both; the first keeps its left, the last its right; the middle
## ones none.
static func strip_sides(index: int, count: int) -> Array[bool]:
	if count <= 1:
		return [true, true]
	return [index == 0, index == count - 1]


## `box` with its corner radii zeroed on the sides a strip joins.
static func joined_box(box: StyleBox, round_left: bool, round_right: bool) -> StyleBox:
	var flat: StyleBoxFlat = box as StyleBoxFlat
	if flat == null:
		return box
	var copy: StyleBoxFlat = flat.duplicate() as StyleBoxFlat
	if not round_left:
		copy.corner_radius_top_left = 0
		copy.corner_radius_bottom_left = 0
	if not round_right:
		copy.corner_radius_top_right = 0
		copy.corner_radius_bottom_right = 0
	return copy


## A box for the pressed member of a strip: the button's own pressed box tinted with the accent.
static func accent_box(box: StyleBox) -> StyleBox:
	var flat: StyleBoxFlat = box as StyleBoxFlat
	if flat == null:
		return box
	var copy: StyleBoxFlat = flat.duplicate() as StyleBoxFlat
	copy.bg_color = accent()
	return copy


## A number field. Godot's own spin slider with a label inside it when running in the editor, and a
## SpinBox everywhere else (the headless suite never builds an EditorSpinSlider). Both are Ranges,
## so value_changed, set_value_no_signal and step are common to the two.
static func number_field(label: String = "", label_color: Color = NO_COLOUR, keep_room: bool = true) -> Range:
	if Engine.is_editor_hint() and ClassDB.can_instantiate("EditorSpinSlider"):
		var slider: Range = ClassDB.instantiate("EditorSpinSlider") as Range
		slider.set("flat", false)
		slider.set("hide_slider", true)
		slider.set("label", label)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if keep_room:
			slider.custom_minimum_size.x = number_field_min_width()
		if label_color.a > 0.0:
			slider.add_theme_color_override("label_color", label_color)
		return slider
	var spin: SpinBox = SpinBox.new()
	spin.prefix = label
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if keep_room:
		spin.custom_minimum_size.x = number_field_min_width()
	return spin


## Lock or unlock a field made by number_field.
static func set_number_field_locked(field: Range, locked: bool) -> void:
	if field is SpinBox:
		(field as SpinBox).editable = not locked
	else:
		field.set("read_only", locked)


## A panel wearing the field colour, for a block that sits under its row.
static func themed_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", field_box())
	return panel


## A wrapping line of words in the editor's own font, coloured by what it says.
static func message_line(text: String, tone: Tone = Tone.NOTE) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", tone_colour(tone))
	return label


static func tone_colour(tone: Tone) -> Color:
	match tone:
		Tone.ERROR:
			return error()
		Tone.WARNING:
			return warning()
	return quiet()


## A flat button showing one editor icon, or `fallback_glyph` when the editor has no such icon.
static func icon_button(icon_name: StringName, fallback_glyph: String, tooltip: String) -> Button:
	var button: Button = Button.new()
	button.flat = true
	button.tooltip_text = tooltip
	var picture: Texture2D = icon(icon_name)
	if picture != null:
		button.icon = picture
	else:
		button.text = fallback_glyph
	return button


## Makes a field from number_field take any number the way Godot's own vector fields do: no range
## limits, a fine step, no slider.
static func open_number_field(field: Range, step: float = 0.001) -> void:
	field.min_value = -1000000.0
	field.max_value = 1000000.0
	field.step = step
	field.allow_greater = true
	field.allow_lesser = true


## The narrowest a number field may be and still show its mark and a value like -1000.00 whole.
static func number_field_min_width() -> float:
	var font_used: Font = font()
	var text_width: float = font_used.get_string_size("x -1000.00", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size()).x
	return text_width + field_box().get_minimum_size().x


## The narrowest a field may be and still show `sample` whole inside its box, with the room the
## spin arrows take at the right.
static func text_room(sample: String) -> float:
	var text_width: float = font().get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size()).x
	var arrows: Texture2D = typed_icon(&"updown", &"SpinBox")
	var arrows_width: float = float(arrows.get_width()) if arrows != null else 0.0
	return text_width + arrows_width + field_box().get_minimum_size().x + px(SPIN_PADDING)


## The narrowest a field that shows no spin arrows may be and still show `sample` whole inside its box.
static func text_room_plain(sample: String) -> float:
	var text_width: float = font().get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size()).x
	return text_width + field_box().get_minimum_size().x + px(SPIN_PADDING)


## The editor's ink or its base colour, whichever reads better laid over `fill` (a swatch, a chosen cell).
static func ink_over(fill: Color) -> Color:
	var light: Color = ink()
	var dark: Color = _colour(&"base_color", THEME_EDITOR, EventSheetActiveTheme.chrome().drawer_handle_border_color)
	light.a = 1.0
	dark.a = 1.0
	return light if contrast_ratio(light, fill) >= contrast_ratio(dark, fill) else dark


## The editor's own progress fill with its colour taken from the accent, so a bar reads as the
## highlight of the editor rather than another grey.
static func accent_fill() -> StyleBox:
	var theme: Theme = editor_theme()
	var flat: StyleBoxFlat = null
	if theme != null and theme.has_stylebox(&"fill", &"ProgressBar"):
		flat = theme.get_stylebox(&"fill", &"ProgressBar").duplicate() as StyleBoxFlat
	if flat == null:
		flat = StyleBoxFlat.new()
	flat.bg_color = accent()
	return flat


## One of the editor's styleboxes by item and theme type, or null when the editor has none of that name.
static func typed_box(item: StringName, theme_type: StringName) -> StyleBox:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_stylebox(item, theme_type):
		return theme.get_stylebox(item, theme_type)
	return null


## One of the editor's icons by item and theme type (a slider's grabber), or null when it has none.
static func typed_icon(item: StringName, theme_type: StringName) -> Texture2D:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_icon(item, theme_type):
		return theme.get_icon(item, theme_type)
	return null


## Makes `button` the side of a joined pair: its own styleboxes with the corners that touch the
## neighbour squared off. A no-op outside the editor, where the button keeps whatever it has.
static func join_button(button: Button, round_left: bool, round_right: bool) -> void:
	var theme: Theme = editor_theme()
	if theme == null:
		return
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"hover_pressed"]:
		if theme.has_stylebox(state, &"Button"):
			button.add_theme_stylebox_override(state, joined_box(theme.get_stylebox(state, &"Button"), round_left, round_right))


## The same for a number field: its box with the corners that touch the neighbour squared off.
static func join_field(field: Control, round_left: bool, round_right: bool) -> void:
	var theme: Theme = editor_theme()
	if theme == null:
		return
	var local: Theme = Theme.new()
	for item: StringName in [&"normal", &"read_only"]:
		if theme.has_stylebox(item, &"LineEdit"):
			local.set_stylebox(item, &"LineEdit", joined_box(theme.get_stylebox(item, &"LineEdit"), round_left, round_right))
	field.theme = local


## Makes `button` one member of a joined strip of toggle buttons: its corners joined to its
## neighbours, and while pressed filled with the accent in the colour that reads on it.
static func join_toggle(button: Button, round_left: bool, round_right: bool) -> void:
	join_button(button, round_left, round_right)
	var theme: Theme = editor_theme()
	if theme == null or not theme.has_stylebox(&"pressed", &"Button"):
		return
	var filled: StyleBox = accent_box(joined_box(theme.get_stylebox(&"pressed", &"Button"), round_left, round_right))
	for state: StringName in [&"pressed", &"hover_pressed"]:
		button.add_theme_stylebox_override(state, filled)
	var on_accent: Color = ink_on_accent()
	for item: StringName in [&"font_pressed_color", &"font_hover_pressed_color", &"icon_pressed_color", &"icon_hover_pressed_color"]:
		button.add_theme_color_override(item, on_accent)


## Joins `buttons` into one strip of toggle buttons: each takes its corners from its place in the
## row (the first keeps its left, the last its right, the middle none), is filled with the accent
## while pressed, and is added to `into` (a new row of the same height when none is given, with no
## gap between members). Returns the container the buttons now sit in.
static func joined_strip(buttons: Array, into: Container = null) -> Container:
	var strip: Container = into
	if strip == null:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		strip = row
	for index: int in buttons.size():
		var button: Button = buttons[index] as Button
		var sides: Array[bool] = strip_sides(index, buttons.size())
		join_toggle(button, sides[0], sides[1])
		if button.get_parent() != strip:
			strip.add_child(button)
	return strip


## `content` inside a panel wearing the editor's field box with no margin of its own, so a control
## that draws no box (a resource picker) sits in the same dark field as the rows around it.
static func boxed(content: Control) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBox = field_box()
	box.set_content_margin_all(0.0)
	panel.add_theme_stylebox_override("panel", box)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)
	return panel


## The editor's base (background) colour.
static func base_colour() -> Color:
	return _colour(&"base_color", THEME_EDITOR, EventSheetActiveTheme.chrome().drawer_handle_border_color)


## The fill colour of a field box (opaque), for judging whether a colour would vanish into it.
static func field_fill() -> Color:
	var flat: StyleBoxFlat = field_box() as StyleBoxFlat
	var fill: Color = flat.bg_color if flat != null else base_colour()
	fill.a = 1.0
	return fill
