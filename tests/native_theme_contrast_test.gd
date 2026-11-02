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
## The bar for words a reader works through (WCAG body text) and for marks and badge letters.
const TEXT_BAR := 4.5
const MARK_BAR := 3.0
## The editor bases the pins run at: each hand's reference and the base Godot's own presets use.
const BASES := [Color("#292929"), Color("#e6e6e6"), Color(0.89, 0.89, 0.89), Color(0.161, 0.161, 0.161)]


static func run() -> bool:
	var ok: bool = true
	for base: Color in BASES:
		ok = _test_pairs_read(base) and ok
	ok = _test_the_light_palette_has_no_dark_fills() and ok
	ok = _test_the_dark_palette_has_no_light_fills() and ok
	ok = _test_the_variable_card_is_a_neutral_grey() and ok
	return ok


## [what, section ("event", "condition", "action"), ink token, fill token, bar]. A section holds the
## token; the fill's section is the same unless the name is prefixed "action:" or "condition:".
static func _pairs() -> Array:
	return [
		["condition sentence", "condition", "text_color", "event:condition_lane_color", TEXT_BAR],
		["action sentence", "action", "text_color", "event:action_lane_color", TEXT_BAR],
		["note words on the note band", "event", "comment_text_color", "event:comment_row_background_color", TEXT_BAR],
		["group title on the group box", "event", "group_title_color", "event:group_background_color", TEXT_BAR],
		["group badge words on the badge", "event", "group_badge_foreground_color", "event:group_badge_background_color", MARK_BAR],
		["gutter numbers on the gutter", "event", "gutter_text_color", "event:gutter_background_color", MARK_BAR],
		["conditions header on its header", "event", "column_header_conditions_color", "event:column_header_background_color", MARK_BAR],
		["actions header on its header", "event", "column_header_actions_color", "event:column_header_background_color", MARK_BAR],
		["trigger badge", "event", "trigger_badge_foreground_color", "event:trigger_badge_background_color", MARK_BAR],
		["object label on a condition lane", "event", "object_label_color", "event:condition_lane_color", TEXT_BAR],
		["variable word on a condition lane", "event", "word_variable_color", "event:condition_lane_color", TEXT_BAR],
		["value word on an action lane", "event", "value_highlight_color", "event:action_lane_color", TEXT_BAR],
		["link on a condition lane", "event", "link_color", "event:condition_lane_color", TEXT_BAR],
		["invert mark on a condition lane", "event", "invert_marker_color", "event:condition_lane_color", MARK_BAR],
		["trigger mark on a condition lane", "event", "trigger_mark_color", "event:condition_lane_color", MARK_BAR],
		["behaviour name on a condition lane", "event", "behaviour_name_color", "event:condition_lane_color", MARK_BAR],
		["type word on the variable card", "event", "type_number_color", "event:variable_card_fill_color", MARK_BAR],
		["ace action badge", "event", "ace_action_accent_color", "event:ace_action_badge_background_color", MARK_BAR],
		["ace condition badge", "event", "ace_condition_accent_color", "event:ace_condition_badge_background_color", MARK_BAR],
		["ace expression badge", "event", "ace_expression_accent_color", "event:ace_expression_badge_background_color", MARK_BAR],
		["verb chip", "event", "verb_chip_foreground_color", "event:verb_chip_background_color", MARK_BAR],
		["include tag on its fill", "event", "include_tag_color", "event:include_fill_color", MARK_BAR],
		["include name on its fill", "event", "include_name_color", "event:include_fill_color", TEXT_BAR],
		["class tag on its fill", "event", "class_tag_color", "event:class_fill_color", MARK_BAR],
		["class name on its fill", "event", "class_name_color", "event:class_fill_color", TEXT_BAR],
		["inspector badge", "event", "inspector_badge_foreground_color", "event:inspector_badge_background_color", MARK_BAR],
		["range badge", "event", "range_badge_foreground_color", "event:range_badge_background_color", MARK_BAR],
		["tooltip badge", "event", "tooltip_badge_foreground_color", "event:tooltip_badge_background_color", MARK_BAR],
		["saved badge", "event", "saved_badge_foreground_color", "event:saved_badge_background_color", MARK_BAR],
	]


static func _section(style: EventSheetEditorStyle, name: String) -> Resource:
	match name:
		"condition":
			return style.get_condition_style()
		"action":
			return style.get_action_style()
	return style.get_event_style()


## One token, composited over the sheet's canvas when it is translucent, so a wash reads as the
## colour that actually reaches the screen.
static func _opaque(style: EventSheetEditorStyle, color: Color) -> Color:
	if color.a >= 1.0:
		return color
	var canvas: Color = style.get_event_style().sheet_background_color
	return canvas.lerp(Color(color.r, color.g, color.b, 1.0), color.a)


static func _test_pairs_read(base: Color) -> bool:
	var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(base)
	var weak: Array[String] = []
	for pair: Array in _pairs():
		var ink_resource: Resource = _section(style, str(pair[1]))
		var fill_parts: PackedStringArray = str(pair[3]).split(":")
		var fill_resource: Resource = _section(style, fill_parts[0])
		var ink: Color = _opaque(style, ink_resource.get(str(pair[2])))
		var fill: Color = _opaque(style, fill_resource.get(fill_parts[1]))
		var ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(ink, fill)
		if ratio < float(pair[4]):
			weak.append("%s %.2f (%s on %s)" % [pair[0], ratio, ink.to_html(false), fill.to_html(false)])
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
