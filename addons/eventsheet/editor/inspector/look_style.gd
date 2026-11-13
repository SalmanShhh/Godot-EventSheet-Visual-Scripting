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
const DIAL_HEIGHT: float = 84.0
const DIAL_RING: float = 68.0
const DIAL_HANDLE: float = 10.0
const CURVE_HEIGHT: float = 64.0
const PICTURE_HEIGHT: float = 72.0
const RANGE_FIELD_WIDTH: float = 44.0
const LINE_WIDTH: float = 2.0
const MINI_WIDTH: float = 44.0
const MINI_HEIGHT: float = 22.0
## The height of a plain field when no editor theme can say.
const FALLBACK_FIELD_HEIGHT: float = 22.0
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


## The box a block of controls sits in (a table, a card list, a picture).
static func panel_box() -> StyleBox:
	var theme: Theme = editor_theme()
	if theme != null and theme.has_stylebox(&"sub_inspector_bg0", THEME_STYLES):
		return theme.get_stylebox(&"sub_inspector_bg0", THEME_STYLES).duplicate() as StyleBox
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
static func number_field(label: String = "", label_color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Range:
	if Engine.is_editor_hint() and ClassDB.can_instantiate("EditorSpinSlider"):
		var slider: Range = ClassDB.instantiate("EditorSpinSlider") as Range
		slider.set("flat", true)
		slider.set("hide_slider", true)
		slider.set("label", label)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if label_color.a > 0.0:
			slider.add_theme_color_override("label_color", label_color)
		return slider
	var spin: SpinBox = SpinBox.new()
	spin.prefix = label
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
