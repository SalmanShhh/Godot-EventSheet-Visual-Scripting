# Godot EventSheets - the Editor Native starter
#
# The starter is one more theme file beside Classic Sheet, with one difference: its greys follow the
# running editor. That promise has four parts, and each is pinned here as a value:
#   1. The FILE is exactly what the rule builds at the reference base - so the rule and the file
#      cannot drift apart, and following the editor at that base changes nothing.
#   2. The greys the rule DERIVES for a dark and for a light editor base, pinned colour by colour.
#   3. Following the editor moves only the tokens still at their shipped value; one a designer
#      changed stays theirs, and a theme that does not ask is handed back untouched.
#   4. The tokens that re-colour something older default to clear, and clear reads as "the colour
#      that was there before" - while every bundled theme states each of them in its own colours,
#      so none of them is left on the look it had before the native tokens existed.
@tool
class_name EditorNativeThemeTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STARTER_PATH := "res://addons/eventsheet/themes/editor_native_theme.tres"
const TEST_NAME := "editor_native_theme_test"
## The tokens that re-colour something the sheet already drew. Clear means "as before".
const AS_BEFORE_TOKENS := [
	"word_variable_color", "word_text_color", "word_number_color", "word_keyword_color",
	"include_border_color", "include_fill_color", "include_tag_color", "include_name_color",
	"include_note_color", "comment_border_color", "selected_gutter_fill_color",
]
const OLDER_PRESETS := [
	"res://demo/themes/dracula_theme.tres",
	"res://demo/themes/nord_theme.tres",
	"res://demo/themes/gruvbox_dark_theme.tres",
	"res://demo/themes/monokai_theme.tres",
	"res://demo/themes/solarized_light_theme.tres",
	"res://demo/themes/catppuccin_mocha_theme.tres",
	"res://demo/themes/high_contrast_theme.tres",
	"res://demo/themes/soft_light_theme.tres",
	"res://demo/themes/designer_template_theme.tres",
	"res://addons/eventsheet/themes/classic_sheet_theme.tres",
	"res://addons/eventsheet/themes/mockup_slate_theme.tres",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_starter_is_the_rule_at_its_reference() and ok
	ok = _test_derived_greys_for_a_dark_and_a_light_editor() and ok
	ok = _test_lanes_read_blue_and_green_on_any_editor() and ok
	ok = _test_following_keeps_what_a_designer_changed() and ok
	ok = _test_clear_means_as_before() and ok
	ok = _test_a_sheet_with_no_theme_wears_editor_native() and ok
	return ok


static func _test_the_starter_is_the_rule_at_its_reference() -> bool:
	var starter: EventSheetEditorStyle = load(STARTER_PATH) as EventSheetEditorStyle
	var built: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE)
	var drifted: Array[String] = []
	var sections: Array[Array] = [
		[starter.get_event_style(), built.get_event_style()],
		[starter.get_condition_style(), built.get_condition_style()],
		[starter.get_action_style(), built.get_action_style()],
		[starter.get_reading_style(), built.get_reading_style()],
		[starter.get_chrome_style(), built.get_chrome_style()],
		[starter.get_manual_style(), built.get_manual_style()],
	]
	for pair: Array in sections:
		for token: Dictionary in EventSheetThemeEditor.editable_tokens(pair[0]):
			var token_name: String = str(token.get("name"))
			if (pair[0] as Resource).get(token_name) != (pair[1] as Resource).get(token_name):
				drifted.append(token_name)
	var listed: Array[String] = []
	for preset: Dictionary in EventSheetThemePresets.list_presets():
		if str(preset.get("path")) == STARTER_PATH:
			listed.append(str(preset.get("name")))
	var followed: EventSheetEditorStyle = EventSheetEditorThemeDeriver.follow_editor(
		starter, EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE)
	return SUPPORT.pins(TEST_NAME, [
		["the starter asks to follow the editor", starter.follow_editor_greys, true],
		["the starter file is the rule at its reference base (drifted: %s)" % str(drifted),
			drifted, [] as Array[String]],
		["the theme menu lists it as Editor Native", listed, ["Editor Native"] as Array[String]],
		["following at the reference base changes no grey",
			followed.get_event_style().row_background_color, starter.get_event_style().row_background_color],
		["and returns a copy, never the shared file", followed == starter, false],
	])


static func _test_derived_greys_for_a_dark_and_a_light_editor() -> bool:
	var rows: Array = []
	# The reference bases are Godot's own Default (dark) and Light presets, and at them the sheet
	# wears the design palette exactly - the values the boards draw.
	rows.append(["the dark reference is the Default preset's base",
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE.to_html(false), "292929"])
	rows.append(["the light reference is the Light preset's base",
		EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE.to_html(false), "e6e6e6"])
	var dark_style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE)
	var light_style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE)
	var dark: EventSheetEventStyle = dark_style.get_event_style()
	var light: EventSheetEventStyle = light_style.get_event_style()
	rows.append(["dark reference: canvas, card, edge, divider, lanes", [dark.sheet_background_color.to_html(false),
		dark.row_background_color.to_html(false), dark.row_border_color.to_html(false), dark.lane_divider_color.to_html(false),
		dark.condition_lane_color.to_html(false), dark.action_lane_color.to_html(false)],
		["282828", "383838", "232323", "1e1e1e", "2f3742", "2f3a31"]])
	rows.append(["dark reference: head bar, variable card and edge, group box and edge", [dark.head_bar_color.to_html(false),
		dark.variable_card_fill_color.to_html(false), dark.variable_card_border_color.to_html(false),
		dark.variable_group_fill_color.to_html(false), dark.variable_group_border_color.to_html(false)],
		["3e3e3e", "424242", "2a2a2a", "333333", "555555"]])
	rows.append(["dark reference: text, gutter numbers, type word, comment note", [
		dark_style.get_condition_style().text_color.to_html(false), dark.gutter_text_color.to_html(false),
		dark.type_number_color.to_html(false), dark.comment_row_background_color.to_html(false)],
		["d2d2d2", "8c8c8c", "d0d0d0", "4a4630"]])
	rows.append(["light reference: canvas, card, edge, divider, lanes", [light.sheet_background_color.to_html(false),
		light.row_background_color.to_html(false), light.row_border_color.to_html(false), light.lane_divider_color.to_html(false),
		light.condition_lane_color.to_html(false), light.action_lane_color.to_html(false)],
		["e4e4e4", "ffffff", "bdbdbd", "d6d6d6", "e9f0f8", "eaf4e6"]])
	rows.append(["light reference: head bar, variable card and edge, group box and edge", [light.head_bar_color.to_html(false),
		light.variable_card_fill_color.to_html(false), light.variable_card_border_color.to_html(false),
		light.variable_group_fill_color.to_html(false), light.variable_group_border_color.to_html(false)],
		["d3d3d3", "eef7e8", "b7cdaa", "efefef", "a9a9a9"]])
	rows.append(["light reference: text, gutter numbers, type word, object, number, string, link", [
		light_style.get_condition_style().text_color.to_html(false), light.gutter_text_color.to_html(false),
		light.type_number_color.to_html(false), light.object_label_color.to_html(false), light.word_number_color.to_html(false),
		light.word_text_color.to_html(false), light.link_color.to_html(false)],
		["0f0f0f", "404040", "2a2a2a", "1d4369", "1f4a14", "633508", "1a3e80"]])
	rows.append(["both hands: the open tab's edge and the No problems green", [
		dark_style.get_chrome_style().active_tab_edge_color.to_html(false), light_style.get_chrome_style().active_tab_edge_color.to_html(false),
		dark_style.get_chrome_style().status_ok_color.to_html(false), light_style.get_chrome_style().status_ok_color.to_html(false)],
		["3a72b0", "3a72b0", "8fc27a", "204a15"]])
	rows.append(["both hands: 8 px between two events, a 4 px group box corner",
		[dark.event_block_gap, light.variable_group_corner_radius], [8, 4]])
	# A slightly darker dark editor and a brighter light one: the greys move with the editor, the
	# colours do not.
	var neutral_dark: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(Color("#252525"))
	var bright_light: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(Color("#f5f5f5"))
	var nd: EventSheetEventStyle = neutral_dark.get_event_style()
	var bl: EventSheetEventStyle = bright_light.get_event_style()
	rows.append(["a #252525 editor: canvas", nd.sheet_background_color.to_html(false), "252525"])
	rows.append(["a #252525 editor: card", nd.row_background_color.to_html(false), "353535"])
	rows.append(["a #252525 editor: gutter numbers", nd.gutter_text_color.to_html(false), "898989"])
	rows.append(["a #252525 editor: the type word keeps its colour", nd.type_number_color.to_html(false), "d0d0d0"])
	rows.append(["a #252525 editor: the sentence text is the dark hand's",
		neutral_dark.get_condition_style().text_color.to_html(false), "d2d2d2"])
	rows.append(["a #f5f5f5 editor: canvas", bl.sheet_background_color.to_html(false), "efefef"])
	rows.append(["a #f5f5f5 editor: card", bl.row_background_color.to_html(false), "ffffff"])
	rows.append(["a #f5f5f5 editor: gutter numbers", bl.gutter_text_color.to_html(false), "4a4a4a"])
	rows.append(["a #f5f5f5 editor: the type word is the light hand's", bl.type_number_color.to_html(false), "2a2a2a"])
	rows.append(["a #f5f5f5 editor: the sentence text is the light hand's",
		bright_light.get_condition_style().text_color.to_html(false), "0f0f0f"])
	# The reading marks follow too, through the one shared rule: a light editor gets pale chips.
	rows.append(["a light editor gets pale reading chips",
		bright_light.get_reading_style().plain_chip_background_color.get_luminance() > 0.5, true])
	rows.append(["a dark editor gets dark reading chips",
		neutral_dark.get_reading_style().plain_chip_background_color.get_luminance() > 0.5, false])
	return SUPPORT.pins(TEST_NAME, rows)


## The condition lane leans blue and the action lane green against the card they sit on, whatever
## grey the editor is - the reference bases, a darker and a brighter skin, a tinted base - and the
## sentence text keeps at least 4.5:1 against both. "Leans blue" is the lane's blue channel moved off
## the card's by at least 8 of 255 levels more than its red; "leans green" its green by 8 more than
## its blue.
static func _test_lanes_read_blue_and_green_on_any_editor() -> bool:
	var rows: Array = []
	var bases: Array = ["292929", "252525", "3a3a3a", "1a2b1a", "4a2040", "e6e6e6", "f5f5f5", "c8c8c8"]
	for base_html: String in bases:
		var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(Color(base_html))
		var lanes: EventSheetEventStyle = style.get_event_style()
		var card: Color = lanes.row_background_color
		var cond: Color = lanes.condition_lane_color
		var act: Color = lanes.action_lane_color
		var text: Color = style.get_condition_style().text_color
		rows.append(["a #%s editor: the condition lane leans blue, the action lane green" % base_html,
			[(cond.b8 - card.b8) - (cond.r8 - card.r8) >= 8, (act.g8 - card.g8) - (act.b8 - card.b8) >= 8],
			[true, true]])
		rows.append(["a #%s editor: the text keeps 4.5:1 on both lanes" % base_html,
			[EventSheetEditorThemeDeriver.contrast_ratio(text, cond) >= 4.5,
				EventSheetEditorThemeDeriver.contrast_ratio(text, act) >= 4.5], [true, true]])
		rows.append(["a #%s editor: a hovered cell keeps its lane's lean" % base_html,
			[(style.get_condition_style().chip_hover_color.b8 - card.b8) - (style.get_condition_style().chip_hover_color.r8 - card.r8) >= 8,
				(style.get_action_style().chip_hover_color.g8 - card.g8) - (style.get_action_style().chip_hover_color.b8 - card.b8) >= 4],
			[true, true]])
	rows.append(["a #252525 editor's lanes", [EventSheetEditorThemeDeriver.native_style(Color("#252525"))
		.get_event_style().condition_lane_color.to_html(false), EventSheetEditorThemeDeriver.native_style(
		Color("#252525")).get_event_style().action_lane_color.to_html(false)], ["2c343f", "2c372e"]])
	return SUPPORT.pins(TEST_NAME, rows)


static func _test_following_keeps_what_a_designer_changed() -> bool:
	var starter: EventSheetEditorStyle = load(STARTER_PATH) as EventSheetEditorStyle
	var edited: EventSheetEditorStyle = starter.duplicate(true) as EventSheetEditorStyle
	edited.get_event_style().value_highlight_color = Color("#ff0000")
	edited.get_event_style().sheet_background_color = Color("#101010")
	var light: EventSheetEditorStyle = EventSheetEditorThemeDeriver.follow_editor(
		edited, EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE)
	var classic: EventSheetEditorStyle = load("res://addons/eventsheet/themes/classic_sheet_theme.tres") as EventSheetEditorStyle
	return SUPPORT.pins(TEST_NAME, [
		["an unchanged grey follows a light editor",
			light.get_event_style().row_background_color.to_html(false), "ffffff"],
		["an unchanged colour takes its light partner",
			light.get_event_style().word_text_color.to_html(false), "633508"],
		["a changed colour stays the designer's",
			light.get_event_style().value_highlight_color.to_html(false), "ff0000"],
		["a changed grey stays the designer's",
			light.get_event_style().sheet_background_color.to_html(false), "101010"],
		["the shared file is never edited",
			starter.get_event_style().row_background_color.to_html(false), "383838"],
		["a theme that does not ask comes back as itself",
			EventSheetEditorThemeDeriver.follow_editor(classic, Color("#f5f5f5")) == classic, true],
		["outside the editor nothing follows", EventSheetEditorThemeDeriver.follow_running_editor(starter) == starter, true],
	])


static func _test_clear_means_as_before() -> bool:
	var rows: Array = []
	var fresh: EventSheetEventStyle = EventSheetEventStyle.new()
	var defaults: Array = []
	for token_name: String in AS_BEFORE_TOKENS:
		defaults.append(fresh.get(token_name).a)
	rows.append(["every as-before token defaults to clear", defaults, AS_BEFORE_TOKENS.map(func(_n: String) -> float: return 0.0)])
	for preset_path: String in OLDER_PRESETS:
		var preset: EventSheetEventStyle = (load(preset_path) as EventSheetEditorStyle).get_event_style()
		var clear: Array[String] = []
		for token_name: String in AS_BEFORE_TOKENS:
			if (preset.get(token_name) as Color).a <= 0.01:
				clear.append(token_name)
		rows.append(["%s dresses every as-before token in its own colours (clear: %s)" % [preset_path.get_file(), str(clear)],
			clear, [] as Array[String]])
	rows.append(["a clear word colour stands in for the older one",
		EventSheetEventStyle.stated_or(Color(0.0, 0.0, 0.0, 0.0), Color("#123456")).to_html(false), "123456"])
	rows.append(["a stated word colour wins",
		EventSheetEventStyle.stated_or(Color("#abcdef"), Color("#123456")).to_html(false), "abcdef"])
	# The editor-matched default dresses the new marks in the light hand on a light editor.
	var adapted: EventSheetEditorStyle = EventSheetEditorStyle.new()
	EventSheetGodotTheme.apply(adapted, Color("#e8e8e8"), Color("#d8d8d8"), Color("#c8c8c8"),
		Color("#569eff"), Color("#202020"))
	rows.append(["the editor-matched default on a light editor: light type colours",
		adapted.get_event_style().type_number_color.to_html(false), "2a2a2a"])
	rows.append(["and still no include edge (clear = as before)",
		adapted.get_event_style().include_border_color.a, 0.0])
	# ...and its cell words and number gutter leave the dark palette: the editor's own text on its own
	# row grey, not pale words on pale lanes beside a black strip.
	rows.append(["a light editor's cell words and gutter", [
		adapted.get_condition_style().text_color.to_html(false), adapted.get_action_style().text_color.to_html(false),
		adapted.get_event_style().gutter_background_color.to_html(false),
		adapted.get_event_style().gutter_text_color.to_html(),
		adapted.get_event_style().word_text_color.to_html(false), adapted.get_event_style().value_highlight_color.to_html(false)],
		["202020", "202020", "d8d8d8", "20202099", "633508", "1f4a14"]])
	return SUPPORT.pins(TEST_NAME, rows)


## The look a sheet with no theme of its own wears in the editor is Editor Native followed onto the
## running editor's base: the board's palette on Godot's Default and Light presets, a copy rather than
## the shared file, and the same copy asked twice. Outside the editor the bare bundled style stands,
## so headless readings do not move.
static func _test_a_sheet_with_no_theme_wears_editor_native() -> bool:
	var starter: EventSheetEditorStyle = load(STARTER_PATH) as EventSheetEditorStyle
	var dark: EventSheetEditorStyle = EventSheetEditorThemeDeriver.default_style_for(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE)
	var light: EventSheetEditorStyle = EventSheetEditorThemeDeriver.default_style_for(
		EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE)
	var bare: EventSheetEditorStyle = EventSheetEditorThemeDeriver.default_style()
	return SUPPORT.pins(TEST_NAME, [
		["on the Default preset: the board's canvas, card and lanes", [dark.get_event_style().sheet_background_color.to_html(false),
			dark.get_event_style().row_background_color.to_html(false), dark.get_event_style().condition_lane_color.to_html(false),
			dark.get_event_style().action_lane_color.to_html(false)], ["282828", "383838", "2f3742", "2f3a31"]],
		["on the Light preset: the board's canvas, card and lanes", [light.get_event_style().sheet_background_color.to_html(false),
			light.get_event_style().row_background_color.to_html(false), light.get_event_style().condition_lane_color.to_html(false),
			light.get_event_style().action_lane_color.to_html(false)], ["e4e4e4", "ffffff", "e9f0f8", "eaf4e6"]],
		["it is the Editor Native look: Inspector rows, cards, the class head, the ordinary strip", [
			dark.get_event_style().inspector_variable_rows, dark.get_event_style().variable_row_cards,
			dark.get_event_style().inspector_class_head, dark.toolbar_text_labels, dark.tabs_above_toolbar,
			dark.follow_editor_greys], [true, true, true, false, false, true]],
		["a copy, never the shared starter", dark == starter, false],
		["built once per editor base", EventSheetEditorThemeDeriver.default_style_for(
			EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE) == dark, true],
		["outside the editor: the bare bundled style (no Inspector rows, no cards)", [
			bare.get_event_style().variable_row_cards, bare.follow_editor_greys,
			bare.get_event_style().sheet_background_color.to_html(false)],
			[false, false, EventSheetEventStyle.new().sheet_background_color.to_html(false)]],
	])
