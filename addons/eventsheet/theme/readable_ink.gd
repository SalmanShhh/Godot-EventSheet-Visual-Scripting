# Godot EventSheets - moves a colour just far enough that its words read on the grounds they sit on.
#
# DELIBERATELY NO `class_name`: callers load it by path at the moment they need it, so the first open
# of the workspace does not compile it. One formula is used everywhere (the theme deriver's, which
# linearises the channels first), so what a test measures is what this moves to.
@tool
extends RefCounted

## The least contrast ordinary text keeps against its ground.
const TEXT_CONTRAST: float = 4.5
## How far toward black or white each step goes. Small, so the colour stops the moment it reads and
## keeps its hue (amber stays amber, a quiet grey stays quiet).
const STEP: float = 0.02
const MAX_STEPS: int = 80


## `ink` moved toward black or white (whichever the grounds ask for) until it reads at `minimum` on
## every one of `grounds`. Alpha is kept. An ink that already reads is returned as it is.
static func move(ink: Color, grounds: Array, minimum: float = TEXT_CONTRAST) -> Color:
	var opaque: Array[Color] = []
	for ground: Variant in grounds:
		if (ground as Color).a > 0.0:
			opaque.append(Color(ground as Color, 1.0))
	if opaque.is_empty():
		return ink
	var result: Color = Color(ink, 1.0)
	if _reads(result, opaque, minimum):
		return ink
	var target: Color = Color.BLACK if _worst(Color.BLACK, opaque) >= _worst(Color.WHITE, opaque) else Color.WHITE
	for step: int in MAX_STEPS:
		result = result.lerp(target, STEP)
		if _reads(result, opaque, minimum):
			break
	return Color(result, ink.a)


## The contrast of `ink` against its worst ground.
static func worst_contrast(ink: Color, grounds: Array) -> float:
	var opaque: Array[Color] = []
	for ground: Variant in grounds:
		opaque.append(Color(ground as Color, 1.0))
	return _worst(Color(ink, 1.0), opaque)


static func _reads(ink: Color, grounds: Array[Color], minimum: float) -> bool:
	return _worst(ink, grounds) >= minimum


static func _worst(ink: Color, grounds: Array[Color]) -> float:
	var worst: float = 1000.0
	for ground: Color in grounds:
		worst = minf(worst, EventSheetEditorThemeDeriver.contrast_ratio(ink, ground))
	return worst


## `ink` moved until it reads on the editor's two panel grounds (the dock's base colour, and the inset panel
## fill the wrapped finding sentence sits on), so a theme colour made for another brightness of sheet still
## reads on Godot's own panel.
static func on_editor_panels(ink: Color) -> Color:
	var grounds: Array = [EventSheetPopupUI.panel_fill()]
	var theme: Theme = EventSheetPopupUI.editor_theme()
	if theme != null and theme.has_color("base_color", "Editor"):
		grounds.append(theme.get_color("base_color", "Editor"))
	return move(ink, grounds)


## Paints `label`'s words in `ink` as it reads on the editor's panels. A font colour, never a modulate:
## a modulate multiplies the editor's own text colour instead of replacing it.
static func paint_label(label: Control, ink: Color) -> void:
	if label == null:
		return
	label.modulate = Color.WHITE
	label.add_theme_color_override("font_color", on_editor_panels(ink))


## The quiet words, moved the least it takes to read at 4.5 to 1 on every ground they are drawn on (the
## sheet, a row, a head bar; the gutter for its numbers), the way the sentence text is. The shared
## rule's own tones stay as they are for every other theme.
static func native_quiet_words(style: EventSheetEditorStyle) -> void:
	var mover: Script = load("res://addons/eventsheet/theme/readable_ink.gd")
	var event_style: EventSheetEventStyle = style.get_event_style()
	var reading: EventSheetReadingStyle = style.get_reading_style()
	var grounds: Array = [event_style.sheet_background_color, event_style.row_background_color, event_style.head_bar_color]
	reading.muted_text_color = mover.move(reading.muted_text_color, grounds)
	# Secondary keeps its step above the muted voice, which may have moved up to meet it.
	var secondary: Color = mover.move(reading.secondary_text_color, grounds)
	var primary: Color = reading.primary_text_color
	if absf(secondary.get_luminance() - reading.muted_text_color.get_luminance()) < 0.03:
		secondary = reading.muted_text_color.lerp(primary, 0.5)
	reading.secondary_text_color = secondary
	event_style.gutter_text_color = mover.move(event_style.gutter_text_color, [event_style.gutter_background_color])
	style.get_chrome_style().object_bar_section_color = reading.muted_text_color
	# The amber of every finding reads on the same grounds as the words around it.
	style.get_chrome_style().object_bar_warning_color = mover.move(style.get_chrome_style().object_bar_warning_color, grounds)
