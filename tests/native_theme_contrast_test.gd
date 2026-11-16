# Godot EventSheets - the Editor Native look reads on a light editor as well as a dark one
#
# Every row kind of the sheet draws words on a fill, and both come out of one rule per hand
# (EventSheetEditorThemeDeriver.native_style). These pins hold the pairs the sheet actually draws -
# the sentence on each lane, the note's ink on its band, a group's title on its box, the badges and
# the include and class cards - to a contrast ratio, for the dark hand and for the light one, and
# hold the light hand's FILLS to be light (a dark fill left in the light palette is how an open tab
# and a row of variables once came out as dark blocks on pale paper).
@tool
class_name NativeThemeContrastTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "native_theme_contrast_test"
const PAIRS_PATH := "res://addons/eventsheet/theme/theme_contrast_pairs.gd"
## The bar for words a reader works through (WCAG body text).
const TEXT_BAR := 4.5
## The editor bases the pins run at: each hand's reference and the base Godot's own presets use.
const BASES := [Color("#292929"), Color("#e6e6e6"), Color(0.89, 0.89, 0.89), Color(0.161, 0.161, 0.161)]


static func run() -> bool:
	var ok: bool = true
	for base: Color in BASES:
		ok = _test_pairs_read(base) and ok
	ok = _test_the_light_palette_has_no_dark_fills() and ok
	ok = _test_the_dark_palette_has_no_light_fills() and ok
	ok = _test_the_variable_card_is_a_neutral_grey() and ok
	for base: Color in BASES:
		ok = _test_quiet_words_read(base) and ok
	return ok


## The quiet voices of the sheet - the muted detail, the gutter numbers, the amber of every finding - read
## at the body-text bar on every ground they are drawn on (the sheet, a row, a head bar, the gutter), in a
## dark editor and in a light one.
static func _test_quiet_words_read(base: Color) -> bool:
	var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(base)
	var event_style: EventSheetEventStyle = style.get_event_style()
	var grounds: Array = [event_style.sheet_background_color, event_style.row_background_color, event_style.head_bar_color]
	var rows: Array = [
		["muted words", style.get_reading_style().muted_text_color, grounds],
		["secondary words", style.get_reading_style().secondary_text_color, grounds],
		["gutter numbers", event_style.gutter_text_color, [event_style.gutter_background_color]],
		["finding amber", style.get_chrome_style().object_bar_warning_color, grounds],
	]
	var weak: Array[String] = []
	for row: Array in rows:
		for ground: Color in row[2]:
			var ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(row[1], ground)
			if ratio < TEXT_BAR:
				weak.append("%s %.2f (%s on %s)" % [row[0], ratio, (row[1] as Color).to_html(false), ground.to_html(false)])
	var ok: bool = SUPPORT.check(TEST_NAME, "the quiet words read at base %s" % base.to_html(false), weak, [])
	var reading: EventSheetReadingStyle = style.get_reading_style()
	var primary: float = reading.primary_text_color.get_luminance()
	var secondary: float = reading.secondary_text_color.get_luminance()
	var muted: float = reading.muted_text_color.get_luminance()
	# Three steps stay three steps: primary, then secondary, then muted, each a visible step apart.
	var dark: bool = not EventSheetEditorThemeDeriver.is_light_base(base)
	var steps_apart: bool = absf(primary - secondary) > 0.02 and absf(secondary - muted) > 0.02
	ok = SUPPORT.check(TEST_NAME, "muted stays a step off secondary at base %s" % base.to_html(false), steps_apart, true) and ok
	return ok


## Every pair the sheet draws, read from the one list the Theme Editor marks its swatches by.
static func _test_pairs_read(base: Color) -> bool:
	var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(base)
	var weak: Array[String] = []
	var pairs: GDScript = load(PAIRS_PATH)
	for pair: Array in pairs.PAIRS:
		var measured: Dictionary = pairs.measure(style, pair)
		if float(measured["ratio"]) < float(measured["bar"]):
			weak.append("%s %.2f (%s on %s)" % [measured["what"], measured["ratio"], (measured["ink"] as Color).to_html(false), (measured["fill"] as Color).to_html(false)])
	return SUPPORT.check(TEST_NAME, "every pair the sheet draws reads at base %s" % base.to_html(false), weak, [])


## The fills of the light hand are light: a canvas, card, lane, head bar, box or gutter under this
## luminance is a dark block on pale paper.
static func _test_the_light_palette_has_no_dark_fills() -> bool:
	var event_style: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		Color("#e6e6e6")).get_event_style()
	return SUPPORT.check(TEST_NAME, "light hand: no fill is dark", _fills_outside(event_style, 0.62, 1.0), [])


static func _test_the_dark_palette_has_no_light_fills() -> bool:
	var event_style: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		Color("#292929")).get_event_style()
	return SUPPORT.check(TEST_NAME, "dark hand: no fill is light", _fills_outside(event_style, 0.0, 0.40), [])


const FILL_TOKENS := [
	"sheet_background_color", "row_background_color", "condition_lane_color", "action_lane_color",
	"variable_card_fill_color", "group_background_color", "group_badge_background_color",
	"group_fold_background_color", "column_header_background_color", "gutter_background_color",
	"head_bar_color", "verb_chip_background_color", "comment_row_background_color",
]


static func _fills_outside(event_style: EventSheetEventStyle, lowest: float, highest: float) -> Array[String]:
	var outside: Array[String] = []
	for token_name: String in FILL_TOKENS:
		var fill: Color = event_style.get(token_name)
		if fill.get_luminance() < lowest or fill.get_luminance() > highest:
			outside.append("%s %s" % [token_name, fill.to_html(false)])
	return outside


## A variable row is the design's neutral band, not a tinted card: red, green and blue within a few
## levels of one another on both hands.
static func _test_the_variable_card_is_a_neutral_grey() -> bool:
	var tinted: Array[String] = []
	for base: Color in [Color("#292929"), Color("#e6e6e6")]:
		var event_style: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(base).get_event_style()
		for token_name: String in ["variable_card_fill_color", "variable_card_border_color"]:
			var grey: Color = event_style.get(token_name)
			if maxf(grey.r, maxf(grey.g, grey.b)) - minf(grey.r, minf(grey.g, grey.b)) > 0.03:
				tinted.append("%s %s at %s" % [token_name, grey.to_html(false), base.to_html(false)])
	return SUPPORT.check(TEST_NAME, "variable cards are neutral greys", tinted, [])
