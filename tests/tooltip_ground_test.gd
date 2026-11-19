# Godot EventSheets - the sheet's rich hover tooltip lies on the editor's own tooltip panel.
#
# A hover whose text carries markup ([b], [i], [color=...]) is drawn as a small card. That card takes the
# fill of the editor's tooltip panel (pale in the light theme, dark in the dark one) and every word of it,
# the plain words and each [color=...] the author wrote, keeps its contrast against that fill. Outside the
# editor, with no theme to ask, the dark panel stands.
@tool
class_name TooltipGroundTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "tooltip_ground_test"
const MARKUP: String = "[b]Pushes[/b] back. Use [color=red]negative[/color], [color=#1e88e5]blue[/color], [color=#2e7d32]green[/color], [color=yellow]yellow[/color] or [color=#ffffff]white[/color] numbers, [color=notacolour]unknown[/color]."


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_panel_comes_from_the_theme() and ok
	ok = _test_every_ink_reads_on_light_and_dark_grounds() and ok
	ok = _test_the_card_has_one_panel_and_no_rim() and ok
	return ok


## A theme as the editor builds one: a tooltip panel of one fill, and the text colour the editor reads on it.
static func _theme_with(fill: Color, ink: Color) -> Theme:
	var theme: Theme = Theme.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	theme.set_stylebox("panel", "TooltipPanel", box)
	theme.set_color("font_color", "TooltipLabel", ink)
	return theme


static func _test_the_panel_comes_from_the_theme() -> bool:
	var ok: bool = true
	for fill: Color in [Color(0.93, 0.93, 0.95), Color(1.0, 1.0, 1.0), Color(0.12, 0.13, 0.15)]:
		var style: StyleBoxFlat = EventSheetViewportTooltipHelper.tooltip_style(8.0, _theme_with(fill, Color.GRAY))
		ok = SUPPORT.check(TEST_NAME, "the panel takes the editor's fill %s" % fill.to_html(), style.bg_color, fill) and ok
		ok = SUPPORT.check(TEST_NAME, "and its content margin", style.content_margin_left, 8.0) and ok
		ok = SUPPORT.check(TEST_NAME, "and draws no border the theme did not give it", style.border_width_left, 0) and ok
	var fallback: StyleBoxFlat = EventSheetViewportTooltipHelper.tooltip_style(8.0, Theme.new())
	ok = SUPPORT.check(TEST_NAME, "a theme with no tooltip panel leaves the dark fallback", fallback.bg_color.get_luminance() < 0.2, true) and ok
	return ok


static func _test_every_ink_reads_on_light_and_dark_grounds() -> bool:
	var ok: bool = true
	var grounds: Array[Color] = [Color(0.93, 0.93, 0.95), Color.WHITE, Color(0.12, 0.13, 0.15), Color.BLACK]
	for ground: Color in grounds:
		var inked: String = EventSheetViewportTooltipHelper.ink_markup(MARKUP, ground)
		var pattern: RegEx = RegEx.new()
		pattern.compile("\\[color=#([0-9a-fA-F]{6})\\]")
		var seen: int = 0
		for found: RegExMatch in pattern.search_all(inked):
			seen += 1
			var ratio: float = EventSheetLookStyle.contrast_ratio(Color.html(found.get_string(1)), ground)
			ok = SUPPORT.check(TEST_NAME, "colour #%s keeps its contrast on %s (%.1f)" % [found.get_string(1), ground.to_html(false), ratio],
				ratio >= EventSheetViewportTooltipHelper.MARKUP_CONTRAST - 0.05, true) and ok
		ok = SUPPORT.check(TEST_NAME, "all five readable colours were re-inked on %s" % ground.to_html(false), seen, 5) and ok
		ok = SUPPORT.check(TEST_NAME, "a colour Godot cannot read is left as written", inked.contains("[color=notacolour]"), true) and ok
		ok = SUPPORT.check(TEST_NAME, "the words and the other tags are untouched", EventSheetBBCodeLite.strip(inked), EventSheetBBCodeLite.strip(MARKUP)) and ok
		var plain: Color = EventSheetViewportTooltipHelper.tooltip_text_ink(ground, _theme_with(ground, Color(0.5, 0.5, 0.5)))
		var plain_ratio: float = EventSheetLookStyle.contrast_ratio(plain, ground)
		ok = SUPPORT.check(TEST_NAME, "the plain words keep their contrast on %s (%.1f)" % [ground.to_html(false), plain_ratio],
			plain_ratio >= EventSheetViewportTooltipHelper.MARKUP_CONTRAST - 0.05, true) and ok
	# A colour that already reads is the author's own, not nudged.
	ok = SUPPORT.check(TEST_NAME, "a readable colour is left exactly as chosen",
		EventSheetViewportTooltipHelper.ink_markup("[color=#000000]x[/color]", Color.WHITE), "[color=#000000]x[/color]") and ok
	return ok


## The card is the panel: its label has no second box inside it, the panel is the theme's, and the plain
## ink the label draws in is read against that panel's fill.
static func _test_the_card_has_one_panel_and_no_rim() -> bool:
	var ok: bool = true
	for fill: Color in [Color(0.93, 0.93, 0.95), Color(0.12, 0.13, 0.15)]:
		var theme: Theme = _theme_with(fill, Color(0.5, 0.5, 0.5))
		var panel: PanelContainer = EventSheetViewportTooltipHelper.build_markup_tooltip(MARKUP, theme)
		var box: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		ok = SUPPORT.check(TEST_NAME, "the card sits on the theme's fill %s" % fill.to_html(false), box.bg_color, fill) and ok
		var rich: RichTextLabel = panel.get_child(0) as RichTextLabel
		ok = SUPPORT.check(TEST_NAME, "the label draws no box of its own", rich.get_theme_stylebox("normal") is StyleBoxEmpty, true) and ok
		var ratio: float = EventSheetLookStyle.contrast_ratio(rich.get_theme_color("default_color"), fill)
		ok = SUPPORT.check(TEST_NAME, "its words read on %s (%.1f)" % [fill.to_html(false), ratio],
			ratio >= EventSheetViewportTooltipHelper.MARKUP_CONTRAST - 0.05, true) and ok
		panel.free()
	return ok
