# Godot EventSheets - editor-theme inheritance
# Derives the sheet's default visual tokens from the USER'S Godot editor theme (base +
# accent colors) so the plugin matches dark/light/custom-accent editors out of the box -
# the way built-in editors do. Explicit theme presets still override (this only supplies
# the default when no theme was chosen). derive() is pure for headless tests;
# derive_from_editor() reads the editor settings.
#
# It also builds the EDITOR NATIVE starter: a theme whose greys come from the editor's base colour
# and whose colours are one design palette, in a dark and a light hand. native_style() is the
# whole rule as a pure function of one base colour; the starter file is exactly what it builds at
# NATIVE_DARK_REFERENCE_BASE, and follow_editor() moves a style that asks for it onto the running
# editor's base, token by token, leaving alone every token a designer has changed.
@tool
class_name EventSheetEditorThemeDeriver
extends RefCounted

## The editor base colour the Editor Native starter file was built at (the base of Godot's own
## Default dark preset), and the light one its light hand is measured from (the Light preset's). At
## either base the sheet wears the design palette exactly; any other base shifts the greys by how
## far the editor moved.
const NATIVE_DARK_REFERENCE_BASE := Color("#292929")
const NATIVE_LIGHT_REFERENCE_BASE := Color("#e6e6e6")
## How far the sheet's canvas sits from the editor base: darker in a dark editor, lighter in a
## light one - the step Godot itself takes from its base colour to the panels inside it.
const NATIVE_CANVAS_STEP := 0.3

## The greys of the Editor Native look, dark hand then light - the design's own values at the
## reference base. Each moves with the editor's canvas: an editor a little darker than the reference
## gets every one of these a little darker, so the steps between them - card on canvas, divider on
## card - survive. The two lane tints ride along, so a lane keeps the blue or green it has on the
## card whatever grey the editor is; the variable cards are the design's own grey, a step lighter
## than an event card, with their own edge.
const NATIVE_GREYS_DARK := {
	"sheet_background_color": Color("#282828"),
	"row_background_color": Color("#383838"),
	"row_background_alt_color": Color("#383838"),
	"row_border_color": Color("#232323"),
	"lane_divider_color": Color("#1e1e1e"),
	"condition_lane_color": Color("#2f3742"),
	"action_lane_color": Color("#2f3a31"),
	"variable_card_fill_color": Color("#424242"),
	"variable_card_border_color": Color("#2a2a2a"),
	"group_background_color": Color("#333333"),
	"group_background_alt_color": Color("#333333"),
	"group_accent_color": Color("#555555"),
	"group_badge_background_color": Color("#1e1e1e"),
	"group_fold_background_color": Color("#383838"),
	"column_header_background_color": Color("#383838"),
	"gutter_background_color": Color("#383838"),
	"gutter_text_color": Color("#8c8c8c"),
	"gutter_icon_color": Color("#b0b0b0"),
	"object_hairline_color": Color("#4a4a4a"),
	"verb_chip_background_color": Color("#3a3a3a"),
}
const NATIVE_GREYS_LIGHT := {
	"sheet_background_color": Color("#e4e4e4"),
	"row_background_color": Color("#ffffff"),
	"row_background_alt_color": Color("#ffffff"),
	"row_border_color": Color("#bdbdbd"),
	"lane_divider_color": Color("#d6d6d6"),
	"condition_lane_color": Color("#e9f0f8"),
	"action_lane_color": Color("#eaf4e6"),
	"variable_card_fill_color": Color("#eef7e8"),
	"variable_card_border_color": Color("#b7cdaa"),
	"group_background_color": Color("#efefef"),
	"group_background_alt_color": Color("#efefef"),
	"group_accent_color": Color("#a9a9a9"),
	"group_badge_background_color": Color("#d6d6d6"),
	"group_fold_background_color": Color("#ffffff"),
	"column_header_background_color": Color("#ffffff"),
	"gutter_background_color": Color("#ffffff"),
	"gutter_text_color": Color("#404040"),
	"gutter_icon_color": Color("#414141"),
	"object_hairline_color": Color("#d6d6d6"),
	"verb_chip_background_color": Color("#e4e4e4"),
}

## The colours of the Editor Native look: fixed per hand, never shifted, because a string's orange
## or a bool's blue is a meaning rather than a shade of the editor.
const NATIVE_COLOURS_DARK := {
	"trigger_badge_background_color": Color("#70bafa"),
	"trigger_badge_foreground_color": Color("#1d2128"),
	"group_title_color": Color("#ffffff"),
	"group_badge_foreground_color": Color("#b4bac4"),
	"comment_row_background_color": Color("#38321f"),
	"comment_text_color": Color("#ede3c4"),
	# The design's comment band has no edge of its own: the edge is the band's colour.
	"comment_border_color": Color("#38321f"),
	"selection_fill_color": Color(0.172549, 0.364706, 0.529412, 0.45),
	"selected_gutter_fill_color": Color("#2c5d87"),
	"hover_fill_color": Color(1.0, 1.0, 1.0, 0.05),
	"cell_hover_color": Color(1.0, 1.0, 1.0, 0.06),
	"column_header_conditions_color": Color("#8ec3f2"),
	"column_header_actions_color": Color("#a6d18f"),
	"invert_marker_color": Color("#f07a7a"),
	"trigger_mark_color": Color("#6ccb4e"),
	"behaviour_name_color": Color("#f0b86e"),
	"object_label_color": Color("#b9c9da"),
	"value_highlight_color": Color("#a6d18f"),
	"behavior_accent_color": Color("#c2b4d6"),
	"language_block_accent_color": Color("#5f566c"),
	"ace_action_badge_background_color": EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG,
	"ace_action_accent_color": EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG,
	"ace_condition_badge_background_color": EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG,
	"ace_condition_accent_color": EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG,
	"ace_expression_badge_background_color": EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG,
	"ace_expression_accent_color": EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG,
	"verb_chip_foreground_color": Color("#b4bac4"),
	"type_number_color": Color("#d0d0d0"),
	"type_text_color": Color("#d0d0d0"),
	"type_bool_color": Color("#d0d0d0"),
	"type_vector_color": Color("#d0d0d0"),
	"type_color_color": Color("#d0d0d0"),
	"type_object_color": Color("#d0d0d0"),
	"type_enum_color": Color("#d0d0d0"),
	"type_collection_color": Color("#d0d0d0"),
	"type_class_color": Color("#d0d0d0"),
	"word_variable_color": Color("#8ec3f2"),
	"word_text_color": Color("#e3b47e"),
	"word_number_color": Color("#a6d18f"),
	"word_keyword_color": Color("#a8afba"),
	"include_border_color": Color("#3f8f86"),
	"include_fill_color": Color("#1f3b39"),
	"include_tag_color": Color("#7fe3d3"),
	"include_name_color": Color("#e8fffb"),
	"include_note_color": Color("#a7d9d1"),
	"class_border_color": Color("#5f566c"),
	"class_fill_color": Color("#36323d"),
	"class_head_color": Color("#3c3744"),
	"class_tag_color": Color("#c2b4d6"),
	"class_name_color": Color("#eeeaf3"),
	"class_note_color": Color("#b9b0c6"),
	"link_color": Color("#7fa7f5"),
	"inspector_badge_foreground_color": Color("#7cc4ff"),
	"inspector_badge_background_color": Color("#23384d"),
	"range_badge_foreground_color": Color("#c9a6ff"),
	"range_badge_background_color": Color("#3a2f4d"),
	"tooltip_badge_foreground_color": Color("#ffd27a"),
	"tooltip_badge_background_color": Color("#4a3e22"),
	"saved_badge_foreground_color": Color("#8ee09a"),
	"saved_badge_background_color": Color("#25402a"),
}
const NATIVE_COLOURS_LIGHT := {
	"trigger_badge_background_color": Color("#2b6fd6"),
	"trigger_badge_foreground_color": Color("#ffffff"),
	"group_title_color": Color("#091a2c"),
	"group_badge_foreground_color": Color("#3f444a"),
	"comment_row_background_color": Color("#f7edc4"),
	"comment_text_color": Color("#2e2610"),
	"comment_border_color": Color("#f7edc4"),
	"selection_fill_color": Color(0.168627, 0.435294, 0.839216, 0.22),
	"selected_gutter_fill_color": Color("#2b6fd6"),
	"hover_fill_color": Color(0.0, 0.0, 0.0, 0.04),
	"cell_hover_color": Color(0.0, 0.0, 0.0, 0.05),
	"column_header_conditions_color": Color("#17508f"),
	"column_header_actions_color": Color("#2c681c"),
	"invert_marker_color": Color("#b42318"),
	"trigger_mark_color": Color("#22700e"),
	"behaviour_name_color": Color("#7a4300"),
	"object_label_color": Color("#1d4369"),
	"value_highlight_color": Color("#1f4a14"),
	"behavior_accent_color": Color("#584a70"),
	"language_block_accent_color": Color("#afa6bd"),
	"ace_action_badge_background_color": Color("#b9e2a8"),
	"ace_action_accent_color": Color("#173f0c"),
	"ace_condition_badge_background_color": Color("#b3d0f2"),
	"ace_condition_accent_color": Color("#0c3463"),
	"ace_expression_badge_background_color": Color("#d6c2f2"),
	"ace_expression_accent_color": Color("#401c78"),
	"verb_chip_foreground_color": Color("#3f444a"),
	"type_number_color": Color("#2a2a2a"),
	"type_text_color": Color("#2a2a2a"),
	"type_bool_color": Color("#2a2a2a"),
	"type_vector_color": Color("#2a2a2a"),
	"type_color_color": Color("#2a2a2a"),
	"type_object_color": Color("#2a2a2a"),
	"type_enum_color": Color("#2a2a2a"),
	"type_collection_color": Color("#2a2a2a"),
	"type_class_color": Color("#2a2a2a"),
	"word_variable_color": Color("#124175"),
	"word_text_color": Color("#633508"),
	"word_number_color": Color("#1f4a14"),
	"word_keyword_color": Color("#4f555c"),
	"include_border_color": Color("#3f9a8f"),
	"include_fill_color": Color("#ddf4f0"),
	"include_tag_color": Color("#0e5a52"),
	"include_name_color": Color("#0b3f3a"),
	"include_note_color": Color("#2e5f59"),
	"class_border_color": Color("#afa6bd"),
	"class_fill_color": Color("#f5f3f8"),
	"class_head_color": Color("#ece8f1"),
	"class_tag_color": Color("#584a70"),
	"class_name_color": Color("#2b2536"),
	"class_note_color": Color("#5b5368"),
	"link_color": Color("#1a3e80"),
	"inspector_badge_foreground_color": Color("#094380"),
	"inspector_badge_background_color": Color("#c4dcf5"),
	"range_badge_foreground_color": Color("#502793"),
	"range_badge_background_color": Color("#ddd0f5"),
	"tooltip_badge_foreground_color": Color("#664100"),
	"tooltip_badge_background_color": Color("#f5e2b8"),
	"saved_badge_foreground_color": Color("#1d6a2a"),
	"saved_badge_background_color": Color("#c7ebcb"),
}

## The marks that are NEW with the native look - drawn by nothing older - and so carry a colour in
## every theme rather than a clear "as before". A light editor gets the light hand of each.
const NATIVE_NEW_MARK_TOKENS: Array[String] = [
	"type_number_color", "type_text_color", "type_bool_color", "type_vector_color",
	"type_color_color", "type_object_color", "type_enum_color", "type_collection_color",
	"type_class_color",
	"class_border_color", "class_fill_color", "class_head_color", "class_tag_color",
	"class_name_color", "class_note_color",
	"link_color",
	"trigger_mark_color", "invert_marker_color", "behaviour_name_color",
	"inspector_badge_foreground_color", "inspector_badge_background_color",
	"range_badge_foreground_color", "range_badge_background_color",
	"tooltip_badge_foreground_color", "tooltip_badge_background_color",
	"saved_badge_foreground_color", "saved_badge_background_color",
]

## The sentence text of the two lanes, per hand. The cell plates are the lane's own tint, so a cell
## reads as part of its lane rather than as a chip sitting on it.
const NATIVE_TEXT_DARK := Color("#d2d2d2")
const NATIVE_TEXT_LIGHT := Color("#0f0f0f")

## The two lanes' hues: the condition lane leans blue and the action lane green, on any editor base.
## A lane is the card's own brightness (a step lighter in a dark editor, a step darker in a light one)
## at that hue with a fixed amount of colour, so the tint stays the same size whatever grey the editor
## is - a neutral editor gets lanes exactly as blue and as green as the reference one does.
const NATIVE_CONDITION_LANE_HUE := 212.0
const NATIVE_ACTION_LANE_HUE := 128.0
## How much colour each lane carries (the gap between its strongest and weakest channel, 0 to 1), and
## how far its brightness steps from the card, per hand.
const NATIVE_LANE_CHROMA_DARK := 0.075
const NATIVE_LANE_CHROMA_LIGHT := 0.06
const NATIVE_LANE_STEP_DARK := 0.04
const NATIVE_LANE_STEP_LIGHT := -0.02
## The least contrast the sentence text keeps against a lane (the WCAG body-text bar).
const NATIVE_LANE_MIN_CONTRAST := 4.5

## The line along the top of the open sheet's tab, per hand: the design's accent blue, the same on
## dark and light paper.
const NATIVE_TAB_EDGE_DARK := Color("#3a72b0")
const NATIVE_TAB_EDGE_LIGHT := Color("#3a72b0")
## The design's "No problems" green, dark and light.
const NATIVE_STATUS_OK_DARK := Color("#8fc27a")
const NATIVE_STATUS_OK_LIGHT := Color("#204a15")

## How far the head bar steps from the canvas, per hand (the design's 22 and 17 levels of 255).
const NATIVE_HEAD_STEP_DARK := 22.0 / 255.0
const NATIVE_HEAD_STEP_LIGHT := 17.0 / 255.0

## The Editor Native starter: the look a sheet with no theme of its own wears in the editor.
const NATIVE_STARTER_PATH := "res://addons/eventsheet/themes/editor_native_theme.tres"

## The last native_style() built, by base colour. follow_editor() asks for two per call and a
## sheet is re-seated on every edit, so the rule runs once per editor base rather than per edit.
## Read-only by contract: callers copy from these, never write into them.
static var _native_cache: Dictionary = {}
## default_style_for() by base colour, built once per editor base: a painter asks on every sheet
## seat. Read-only by contract, like _native_cache - a caller that edits one duplicates it first.
static var _default_cache: Dictionary = {}


## Builds a style from a base/accent pair (the two colors Godot themes hinge on).
static func derive(base_color: Color, accent_color: Color) -> EventSheetEditorStyle:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	var event_style: EventSheetEventStyle = EventSheetEventStyle.new()
	var dark: bool = base_color.v < 0.5
	var background: Color = base_color.darkened(0.15) if dark else base_color.lightened(0.06)
	var alternate: Color = base_color.lightened(0.04) if dark else base_color.darkened(0.04)
	event_style.sheet_background_color = background
	event_style.row_background_color = background
	event_style.row_background_alt_color = alternate
	event_style.column_header_background_color = alternate
	event_style.group_background_color = base_color.lerp(accent_color, 0.08)
	event_style.group_background_alt_color = base_color.lerp(accent_color, 0.12)
	event_style.group_accent_color = accent_color
	event_style.group_title_color = accent_color.lightened(0.3) if dark else accent_color.darkened(0.25)
	event_style.selection_fill_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.22)
	event_style.hover_fill_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.10)
	event_style.behavior_accent_color = accent_color
	read_variables_inspector_style(event_style)
	# The sheet's one head bar: a flat grey a step off the canvas, the class head the design draws in
	# both skins - never a tint of the accent, which would read as a selection.
	event_style.head_bar_color = base_color.lightened(0.08) if dark else base_color.darkened(0.07)
	style.event_style = event_style
	return style


## The look a new sheet gets lists a variable the way the Inspector lists a property - its type, its
## name as written, its value, its ## note and its attributes as icon tiles - and leaves
## the compiler's own bookkeeping variables out, as Editor Native does. Shared by both ways that look
## is reached (the derived style and the editor-adapted fallback) so the two cannot drift.
static func read_variables_inspector_style(event_style: EventSheetEventStyle) -> void:
	if event_style == null:
		return
	event_style.inspector_variable_rows = true
	event_style.hide_compiler_variables = true


## The editor-derived default (null outside the editor, e.g. headless tests/games).
static func derive_from_editor() -> EventSheetEditorStyle:
	if not Engine.is_editor_hint():
		return null
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return null
	return derive(
		settings.get_setting("interface/theme/base_color"),
		settings.get_setting("interface/theme/accent_color")
	)


## Whether an editor base colour is a LIGHT editor - the one question that picks the hand.
static func is_light_base(base_color: Color) -> bool:
	return base_color.get_luminance() > 0.5


## The sheet canvas an editor base colour asks for: a step darker in a dark editor, a step lighter
## in a light one.
static func native_canvas(base_color: Color) -> Color:
	if is_light_base(base_color):
		return base_color.lerp(Color(1.0, 1.0, 1.0, base_color.a), NATIVE_CANVAS_STEP)
	return base_color.lerp(Color(0.0, 0.0, 0.0, base_color.a), NATIVE_CANVAS_STEP)


## One design grey moved onto an editor base: shifted by exactly how far that editor's canvas sits
## from the canvas of the hand's reference base, clamped to a real colour. Alpha is the design's.
static func native_grey(design_grey: Color, base_color: Color) -> Color:
	var reference: Color = NATIVE_LIGHT_REFERENCE_BASE if is_light_base(base_color) else NATIVE_DARK_REFERENCE_BASE
	var shift: Color = native_canvas(base_color) - native_canvas(reference)
	return Color(
		clampf(design_grey.r + shift.r, 0.0, 1.0),
		clampf(design_grey.g + shift.g, 0.0, 1.0),
		clampf(design_grey.b + shift.b, 0.0, 1.0),
		design_grey.a
	)


## The whole Editor Native look for one editor base colour: the greys moved onto that base, the
## colours of the matching hand, the density the design is drawn at, and the reading, chrome and
## Manual tokens derived from all of that by the one shared rule. Pure, so a test can pin it for a
## dark and a light editor without one running.
static func native_style(base_color: Color) -> EventSheetEditorStyle:
	var light: bool = is_light_base(base_color)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.follow_editor_greys = true
	# The design's strip is the ordinary one (Menu, the save and undo icons, Run Scene, the quick-add
	# field) with the open sheets' tabs under it, and its status bar says what is selected.
	style.toolbar_text_labels = false
	style.tabs_above_toolbar = false
	style.status_bar_selection_line = true
	# The design puts the sheet straight under the strip: no title, identity, header or link bands.
	style.fold_workspace_bands = true
	var event_style: EventSheetEventStyle = style.get_event_style()
	# The greys, the variable cards and the two lane tints: the design's own values at the reference
	# base, moved with the editor.
	var greys: Dictionary = NATIVE_GREYS_LIGHT if light else NATIVE_GREYS_DARK
	for token_name: String in greys:
		event_style.set(token_name, native_grey(greys[token_name], base_color))
	# The one head bar is a neutral grey a step off the canvas - the design's #3e3e3e over #282828 in
	# a dark editor, #d3d3d3 under #e4e4e4 in a light one - never a tint of a bluish canvas.
	var canvas_light: float = event_style.sheet_background_color.get_luminance()
	var head_grey: float = clampf(canvas_light - NATIVE_HEAD_STEP_LIGHT if light else canvas_light + NATIVE_HEAD_STEP_DARK, 0.0, 1.0)
	event_style.head_bar_color = Color(head_grey, head_grey, head_grey, 1.0)
	var colours: Dictionary = NATIVE_COLOURS_LIGHT if light else NATIVE_COLOURS_DARK
	for token_name: String in colours:
		event_style.set(token_name, colours[token_name])
	# The density the design is drawn at: 24 px rows, a 92 px object name after its 14 px icon and the
	# 8 px gap (114 px in all, the column counting the icon), 8 px between two events, an 18 px nesting step,
	# a 7 px lane divider and square-ish cards with a one-pixel edge.
	event_style.condition_lane_ratio = 0.42
	event_style.minimum_row_height = 24
	event_style.group_row_height = 36
	event_style.condition_object_column_width = 114
	event_style.action_object_column_width = 114
	event_style.event_block_gap = 8
	event_style.sub_event_indent = 16
	event_style.sub_event_rail_line = false
	event_style.sub_event_strips = true
	event_style.lane_divider_width = 7
	event_style.event_card_border_width = 1
	event_style.event_corner_radius = 3
	event_style.cell_corner_radius = 0
	event_style.group_corner_radius = 3
	# The box round an Inspector group's variables: the group's grey under the cards, its edge, 4 px
	# corners.
	event_style.variable_group_fill_color = event_style.group_background_color
	event_style.variable_group_border_color = event_style.group_accent_color
	event_style.variable_group_corner_radius = 4
	# The design's variable rows: type, name, value, note, icon tiles - and none of the compiler's own
	# bookkeeping variables among them.
	event_style.inspector_variable_rows = true
	event_style.hide_compiler_variables = true
	# And inside the events: a "__" copy of a scene is named by its scene, and the rows that only keep
	# a hidden "__" member up to date fold away.
	event_style.fold_compiler_helpers = true
	# The design's conditions lane holds conditions only: the pattern an event was read as is said in
	# the help strip once the event is selected.
	event_style.pattern_in_help_strip = true
	event_style.variable_row_cards = true
	# The design's head: one class head card, no code echoes, no scene-fact or "+ add" rows.
	event_style.inspector_class_head = true
	# The design's events: 12 px text on 24 px lines, the number on the event's first line, a 16 px
	# mark slot at the head of every condition line (the trigger arrow, the inverted cross), a
	# behaviour named in the object column, and the add lines only on the hovered or selected event -
	# a one-condition, one-action event is one line.
	event_style.row_font_size = 12
	event_style.trigger_icon_in_gutter = true
	event_style.condition_badge_column_width = 16
	event_style.behaviour_in_object_column = false
	event_style.lane_chips_yield = true
	event_style.add_lines_on_hover = true
	# The design's notes (a yellow card with a grip and a bubble, no echo) and its selection (a filled
	# gutter and a frame, no wash over the lanes).
	event_style.comment_notes = true
	event_style.selection_as_outline = true
	_native_cells(style.get_condition_style(), event_style.condition_lane_color, base_color, light)
	_native_cells(style.get_action_style(), event_style.action_lane_color, base_color, light)
	EventSheetThemeDerivation.fill_derived_tokens(style)
	# The one bar colour the shared rule leaves clear on purpose (every other theme keeps the tab as
	# the editor draws it), stated here because the design gives the open tab its accent edge.
	style.get_chrome_style().active_tab_edge_color = NATIVE_TAB_EDGE_LIGHT if light else NATIVE_TAB_EDGE_DARK
	style.get_chrome_style().status_ok_color = NATIVE_STATUS_OK_LIGHT if light else NATIVE_STATUS_OK_DARK
	return style


## A lane's cells: the sentence text of the hand on a plate that IS the lane, so nothing draws a
## chip edge, and the cell under the pointer lifted by the design's hover grey.
static func _native_cells(cells: EventSheetElementStyle, lane: Color, base_color: Color, light: bool) -> void:
	var text: Color = NATIVE_TEXT_LIGHT if light else NATIVE_TEXT_DARK
	cells.text_color = text
	cells.chip_background_color = lane
	cells.chip_border_color = lane
	# The cell under the pointer is its own lane lifted a step, so a hovered action keeps its green.
	cells.chip_hover_color = lane.darkened(0.04) if light else lane.lightened(0.07)
	cells.badge_background_color = native_grey(
		(NATIVE_GREYS_LIGHT if light else NATIVE_GREYS_DARK)["lane_divider_color"], base_color)
	cells.badge_foreground_color = text
	cells.corner_radius = 0
	# One pixel above and below the text: with the 12 px text that is the design's 24 px line.
	cells.vertical_padding = 1


## One lane's tint on a card: the card's brightness stepped by the hand's lane step, at `hue_degrees`,
## carrying the hand's fixed amount of colour. Darkened (dark hand) or lightened (light hand) further
## only if the sentence text would otherwise fall under NATIVE_LANE_MIN_CONTRAST against it.
## Pure; the alpha is the card's.
static func native_lane(card: Color, hue_degrees: float, light: bool) -> Color:
	var text: Color = NATIVE_TEXT_LIGHT if light else NATIVE_TEXT_DARK
	var chroma: float = NATIVE_LANE_CHROMA_LIGHT if light else NATIVE_LANE_CHROMA_DARK
	var value: float = clampf(card.v + (NATIVE_LANE_STEP_LIGHT if light else NATIVE_LANE_STEP_DARK), chroma, 1.0)
	var lane: Color = Color.from_hsv(hue_degrees / 360.0, clampf(chroma / value, 0.0, 1.0), value, card.a)
	var guard: int = 0
	while contrast_ratio(text, lane) < NATIVE_LANE_MIN_CONTRAST and guard < 40:
		value = clampf(value + (0.02 if light else -0.02), chroma, 1.0)
		lane = Color.from_hsv(hue_degrees / 360.0, clampf(chroma / value, 0.0, 1.0), value, card.a)
		guard += 1
	return lane


## The WCAG contrast ratio between two opaque colours, 1 to 21.
static func contrast_ratio(first: Color, second: Color) -> float:
	var a: float = first.srgb_to_linear().get_luminance()
	var b: float = second.srgb_to_linear().get_luminance()
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## A style that asks to follow the editor (follow_editor_greys), moved onto `base_color`. Every
## token still holding the value the starter shipped with takes the value the rule builds for this
## base; a token anyone changed is left exactly as they set it. Returns a NEW resource so a shared
## theme file is never edited in place; a style that does not ask is returned untouched.
static func follow_editor(style: EventSheetEditorStyle, base_color: Color) -> EventSheetEditorStyle:
	if style == null or not style.follow_editor_greys:
		return style
	var reference: EventSheetEditorStyle = _cached_native_style(NATIVE_DARK_REFERENCE_BASE)
	var target: EventSheetEditorStyle = _cached_native_style(base_color)
	var followed: EventSheetEditorStyle = style.duplicate(true) as EventSheetEditorStyle
	followed.ensure_defaults()
	var sections: Array[Array] = [
		[followed.get_event_style(), reference.get_event_style(), target.get_event_style()],
		[followed.get_condition_style(), reference.get_condition_style(), target.get_condition_style()],
		[followed.get_action_style(), reference.get_action_style(), target.get_action_style()],
		[followed.get_reading_style(), reference.get_reading_style(), target.get_reading_style()],
		[followed.get_chrome_style(), reference.get_chrome_style(), target.get_chrome_style()],
		[followed.get_manual_style(), reference.get_manual_style(), target.get_manual_style()],
	]
	for section: Array in sections:
		var own: Resource = section[0]
		var shipped: Resource = section[1]
		var wanted: Resource = section[2]
		for property: Dictionary in own.get_property_list():
			if not (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			if int(property.get("type", TYPE_NIL)) != TYPE_COLOR:
				continue
			var token_name: String = str(property.get("name"))
			if own.get(token_name) == shipped.get(token_name):
				own.set(token_name, wanted.get(token_name))
	return followed


## native_style() for a base colour, built once and kept. In practice two are live - the reference
## and the running editor's base - and the cache empties itself past a handful.
static func _cached_native_style(base_color: Color) -> EventSheetEditorStyle:
	var key: String = base_color.to_html(true)
	if not _native_cache.has(key):
		if _native_cache.size() > 4:
			_native_cache.clear()
		_native_cache[key] = native_style(base_color)
	return _native_cache[key]


## follow_editor() against the RUNNING editor's base colour. Outside the editor (headless tests, a
## game build) and for a style that does not ask, the style comes back as it was saved.
static func follow_running_editor(style: EventSheetEditorStyle) -> EventSheetEditorStyle:
	if style == null or not style.follow_editor_greys:
		return style
	var base: Color = running_editor_base()
	if base.a <= 0.0:
		return style
	return follow_editor(style, base)


## The running editor's base colour, or clear outside the editor (headless tests, a game build).
static func running_editor_base() -> Color:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return Color(0.0, 0.0, 0.0, 0.0)
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return Color(0.0, 0.0, 0.0, 0.0)
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_color("base_color", "Editor"):
		return Color(0.0, 0.0, 0.0, 0.0)
	return theme.get_color("base_color", "Editor")


## The look a sheet with no theme of its own wears. In the editor it is Editor Native moved onto the
## running editor's base colour - what a fresh install, an updated project that never chose a look
## and the Welcome's editor-matching answer draw; a sheet that chose another theme keeps it. Outside
## the editor (headless tests, a game build) it is the bare bundled style, so every machine reads the
## same tokens.
static func default_style() -> EventSheetEditorStyle:
	return sheet_look(null, running_editor_base())


## The look one sheet is drawn with on an editor whose base colour is `base` (clear outside the
## editor): the theme the sheet chose, followed onto the editor's greys when it asks to, or with no
## theme chosen, Editor Native. No project setting is consulted, so a project that used the plugin
## before Editor Native became the default draws it too once updated; only a chosen theme is kept.
static func sheet_look(chosen: EventSheetEditorStyle, base: Color) -> EventSheetEditorStyle:
	if chosen != null:
		chosen.ensure_defaults()
		return follow_editor(chosen, base) if base.a > 0.0 else chosen
	if base.a <= 0.0:
		var bare: EventSheetEditorStyle = EventSheetEditorStyle.new()
		bare.ensure_defaults()
		return bare
	return default_style_for(base)


## The style a sheet that never chose a look is given the moment one of its numbers is edited (a
## dragged divider, a dragged name column), so the edit saves with the sheet WITHOUT changing the look
## the sheet is drawn in: in the editor that is the Editor Native starter (which keeps following the
## editor's greys), a copy of its own; outside the editor, the bare bundled style, as before.
static func promoted_default_style() -> EventSheetEditorStyle:
	var starter: EventSheetEditorStyle = load(NATIVE_STARTER_PATH) as EventSheetEditorStyle if running_editor_base().a > 0.0 else null
	var style: EventSheetEditorStyle = starter.duplicate(true) as EventSheetEditorStyle if starter != null else EventSheetEditorStyle.new()
	style.ensure_defaults()
	# The drag that led here edited the SHARED no-theme look live; forget it so the next sheet that
	# never chose a look is built fresh instead of inheriting this sheet's split.
	_default_cache.clear()
	return style


## The no-theme look for one editor base colour: the Editor Native starter followed onto it. Pure
## apart from loading the starter, so a test can pin it for a dark and a light editor.
static func default_style_for(base_color: Color) -> EventSheetEditorStyle:
	var key: String = base_color.to_html(true)
	if _default_cache.has(key):
		return _default_cache[key]
	var starter: EventSheetEditorStyle = load(NATIVE_STARTER_PATH) as EventSheetEditorStyle
	var built: EventSheetEditorStyle = (
		follow_editor(starter, base_color) if starter != null else native_style(base_color)
	)
	built.ensure_defaults()
	if _default_cache.size() > 4:
		_default_cache.clear()
	_default_cache[key] = built
	return built


## Gives the marks that are new with the native look the light hand of their colours on a light
## editor, so the editor-matched default never puts a dark-palette type word on pale paper.
static func dress_new_marks(event_style: EventSheetEventStyle, light: bool) -> void:
	var colours: Dictionary = NATIVE_COLOURS_LIGHT if light else NATIVE_COLOURS_DARK
	for token_name: String in NATIVE_NEW_MARK_TOKENS:
		event_style.set(token_name, colours[token_name])
