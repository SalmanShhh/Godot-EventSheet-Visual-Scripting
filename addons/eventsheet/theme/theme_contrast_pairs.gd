# Godot EventSheets - which colour a theme's words are drawn on, and how well they read there.
#
# Every row kind of the sheet draws words on a fill. This is the one list of those pairs: the
# contrast test holds the Editor Native look to it, and the Theme Editor reads the same list to mark a
# swatch whose words would be hard to read on their own ground. Nothing is hand-listed twice.
#
# DELIBERATELY NO `class_name`: callers load it by path at the moment they ask, so the first open of
# the workspace does not compile it.
@tool
extends RefCounted


## The bar for words a reader works through (WCAG body text) and for marks and badge letters.
const TEXT_BAR := 4.5
const MARK_BAR := 3.0

## [what, section ("event", "condition", "action", "reading"), ink token, fill token, bar]. A section holds the
## token; the fill's section is written before its name ("event:condition_lane_color").
const PAIRS: Array = [
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
	["muted words on a row", "reading", "muted_text_color", "event:row_background_color", TEXT_BAR],
	["muted words on the sheet", "reading", "muted_text_color", "event:sheet_background_color", TEXT_BAR],
	["secondary words on a row", "reading", "secondary_text_color", "event:row_background_color", TEXT_BAR],
	["secondary words on the sheet", "reading", "secondary_text_color", "event:sheet_background_color", TEXT_BAR],
	["inspector words on a row", "reading", "inspector_chip_foreground_color", "event:row_background_color", TEXT_BAR],
]


## The block of `style` a pair names.
static func section_of(style: EventSheetEditorStyle, section_name: String) -> Resource:
	match section_name:
		"condition":
			return style.get_condition_style()
		"action":
			return style.get_action_style()
		"reading":
			return style.get_reading_style()
	return style.get_event_style()


## One token, composited over the sheet's canvas when it is translucent, so a wash reads as the colour
## that actually reaches the screen.
static func opaque(style: EventSheetEditorStyle, color: Color) -> Color:
	if color.a >= 1.0:
		return color
	var canvas: Color = style.get_event_style().sheet_background_color
	return canvas.lerp(Color(color.r, color.g, color.b, 1.0), color.a)


## How one pair reads in `style`: {"ratio", "bar", "against" (the fill token), "what", "ink", "fill"}.
static func measure(style: EventSheetEditorStyle, pair: Array) -> Dictionary:
	var fill_parts: PackedStringArray = str(pair[3]).split(":")
	var ink: Color = opaque(style, section_of(style, str(pair[1])).get(str(pair[2])))
	var fill: Color = opaque(style, section_of(style, fill_parts[0]).get(fill_parts[1]))
	return {
		"ratio": EventSheetEditorThemeDeriver.contrast_ratio(ink, fill),
		"bar": float(pair[4]),
		"against": fill_parts[1],
		"what": str(pair[0]),
		"ink": ink,
		"fill": fill,
	}


## The first pair that names `token` of `section_name` as its words and reads under its bar in `style`,
## as `measure` answers it; empty when the token reads well on every ground it is drawn on, or is not
## words at all.
static func weak_pair(style: EventSheetEditorStyle, section_name: String, token: String) -> Dictionary:
	for pair: Array in PAIRS:
		if str(pair[1]) != section_name or str(pair[2]) != token:
			continue
		var measured: Dictionary = measure(style, pair)
		if float(measured["ratio"]) < float(measured["bar"]):
			return measured
	return {}


## Whether `token` of `section_name` is the words of any pair.
static func is_words(section_name: String, token: String) -> bool:
	for pair: Array in PAIRS:
		if str(pair[1]) == section_name and str(pair[2]) == token:
			return true
	return false
