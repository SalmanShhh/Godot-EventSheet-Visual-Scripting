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
	# The reference bases wear the design palette exactly.
	var dark: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	var light: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE).get_event_style()
	rows.append(["dark reference: canvas", dark.sheet_background_color.to_html(false), "262b33"])
	rows.append(["dark reference: card", dark.row_background_color.to_html(false), "2e343e"])
	rows.append(["dark reference: condition lane", dark.condition_lane_color.to_html(false), "353e48"])
	rows.append(["dark reference: comment note", dark.comment_row_background_color.to_html(false), "4a4630"])
	rows.append(["light reference: canvas", light.sheet_background_color.to_html(false), "e9ebee"])
	rows.append(["light reference: card", light.row_background_color.to_html(false), "ffffff"])
	rows.append(["light reference: condition lane", light.condition_lane_color.to_html(false), "ebf2fa"])
	rows.append(["light reference: comment note", light.comment_row_background_color.to_html(false), "fff6c7"])
	# A neutral dark editor (the grey Modern skin) and a bright light one: the greys move with the
	# editor, the colours do not.
	var neutral_dark: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(Color("#252525"))
	var bright_light: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(Color("#f5f5f5"))
	var nd: EventSheetEventStyle = neutral_dark.get_event_style()
	var bl: EventSheetEventStyle = bright_light.get_event_style()
	rows.append(["a #252525 editor: canvas", nd.sheet_background_color.to_html(false), "1a1a19"])
	rows.append(["a #252525 editor: card", nd.row_background_color.to_html(false), "222324"])
	rows.append(["a #252525 editor: gutter numbers", nd.gutter_text_color.to_html(false), "808386"])
	rows.append(["a #252525 editor: the number type keeps its colour", nd.type_number_color.to_html(false), "a6d18f"])
	rows.append(["a #252525 editor: the sentence text is the dark hand's",
		neutral_dark.get_condition_style().text_color.to_html(false), "dfe3ea"])
	rows.append(["a #f5f5f5 editor: canvas", bl.sheet_background_color.to_html(false), "f8f8f8"])
	rows.append(["a #f5f5f5 editor: card", bl.row_background_color.to_html(false), "ffffff"])
	rows.append(["a #f5f5f5 editor: gutter numbers", bl.gutter_text_color.to_html(false), "64686d"])
	rows.append(["a #f5f5f5 editor: the number type is the light hand's", bl.type_number_color.to_html(false), "2c681c"])
	rows.append(["a #f5f5f5 editor: the sentence text is the light hand's",
		bright_light.get_condition_style().text_color.to_html(false), "16191d"])
	# The reading marks follow too, through the one shared rule: a light editor gets pale chips.
	rows.append(["a light editor gets pale reading chips",
		bright_light.get_reading_style().plain_chip_background_color.get_luminance() > 0.5, true])
	rows.append(["a dark editor gets dark reading chips",
		neutral_dark.get_reading_style().plain_chip_background_color.get_luminance() > 0.5, false])
	return SUPPORT.pins(TEST_NAME, rows)


## The condition lane is visibly blue and the action lane visibly green whatever grey the editor is -
## the reference base, the neutral dark and light skins, a tinted base - and the sentence text keeps
## at least 4.5:1 against both. "Blue" is the blue channel leading by at least 12 of 255 levels over
## red, "green" the green channel leading by as much over both others.
static func _test_lanes_read_blue_and_green_on_any_editor() -> bool:
	var rows: Array = []
	var bases: Array = ["363d4a", "252525", "3a3a3a", "1a2b1a", "4a2040", "e0e2e7", "f5f5f5", "c8c8c8"]
	for base_html: String in bases:
		var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(Color(base_html))
		var lanes: EventSheetEventStyle = style.get_event_style()
		var cond: Color = lanes.condition_lane_color
		var act: Color = lanes.action_lane_color
		var text: Color = style.get_condition_style().text_color
		rows.append(["a #%s editor: the condition lane is blue, the action lane green" % base_html,
			[cond.b8 - cond.r8 >= 12, act.g8 - act.r8 >= 12, act.g8 - act.b8 >= 12],
			[true, true, true]])
		rows.append(["a #%s editor: the text keeps 4.5:1 on both lanes" % base_html,
			[EventSheetEditorThemeDeriver.contrast_ratio(text, cond) >= 4.5,
				EventSheetEditorThemeDeriver.contrast_ratio(text, act) >= 4.5], [true, true]])
		rows.append(["a #%s editor: a hovered cell keeps its lane's hue" % base_html,
			[style.get_condition_style().chip_hover_color.b8 > style.get_condition_style().chip_hover_color.g8,
				style.get_action_style().chip_hover_color.g8 > style.get_action_style().chip_hover_color.b8],
			[true, true]])
	rows.append(["the neutral dark skin's lanes", [EventSheetEditorThemeDeriver.native_style(Color("#252525"))
		.get_event_style().condition_lane_color.to_html(false), EventSheetEditorThemeDeriver.native_style(
		Color("#252525")).get_event_style().action_lane_color.to_html(false)], ["1b242e", "1b2e1e"]])
	rows.append(["the light reference's action lane", EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE).get_event_style().action_lane_color.to_html(false),
		"ebfaed"])
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
			light.get_event_style().type_text_color.to_html(false), "8a4a0c"],
		["a changed colour stays the designer's",
			light.get_event_style().value_highlight_color.to_html(false), "ff0000"],
		["a changed grey stays the designer's",
			light.get_event_style().sheet_background_color.to_html(false), "101010"],
		["the shared file is never edited",
			starter.get_event_style().row_background_color.to_html(false), "2e343e"],
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
		adapted.get_event_style().type_number_color.to_html(false), "2c681c"])
	rows.append(["and still no include edge (clear = as before)",
		adapted.get_event_style().include_border_color.a, 0.0])
	return SUPPORT.pins(TEST_NAME, rows)
