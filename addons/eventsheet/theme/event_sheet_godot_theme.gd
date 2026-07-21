# EventSheet - Godot editor theme adapter
# Tints the default (fallback) sheet style from the running Godot editor theme, so sheets
# without an explicit theme look native to the user's editor (base/dark/accent colors).
# No-op outside the editor, so headless tests and exports keep deterministic palette colors.
@tool
class_name EventSheetGodotTheme
extends RefCounted


static func adapt_to_editor(style: EventSheetEditorStyle) -> EventSheetEditorStyle:
	if style == null or not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return style
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return style
	var theme: Theme = editor_interface.get_editor_theme()
	if theme == null or not theme.has_color("base_color", "Editor"):
		return style
	var base: Color = theme.get_color("base_color", "Editor")
	var dark_1: Color = theme.get_color("dark_color_1", "Editor") if theme.has_color("dark_color_1", "Editor") else base.darkened(0.15)
	var dark_2: Color = theme.get_color("dark_color_2", "Editor") if theme.has_color("dark_color_2", "Editor") else base.darkened(0.25)
	var accent: Color = theme.get_color("accent_color", "Editor") if theme.has_color("accent_color", "Editor") else Color("#699ce8")
	var font_color: Color = theme.get_color("font_color", "Editor") if theme.has_color("font_color", "Editor") else Color(0.9, 0.9, 0.9)
	return apply(style, base, dark_1, dark_2, accent, font_color)


## Pure color-mapping core (no editor access) - derives the sheet's chrome from the five
## colors every Godot editor theme hinges on, so the look tracks the user's theme (the
## neutral grayscale "Modern" 4.6+ default, light themes, custom accents). Extracted from
## adapt_to_editor so the render harness and headless tests can preview/verify the adapted
## look without a live editor.
static func apply(
	style: EventSheetEditorStyle,
	base: Color,
	dark_1: Color,
	dark_2: Color,
	accent: Color,
	font_color: Color
) -> EventSheetEditorStyle:
	if style == null:
		return style
	var event_style: EventSheetEventStyle = style.get_event_style()
	event_style.sheet_background_color = dark_2
	event_style.row_background_color = dark_1
	event_style.row_background_alt_color = dark_1.lerp(base, 0.35)
	event_style.row_border_color = dark_2.lerp(Color.BLACK, 0.2)
	# Subtle neutral lane tints (the condition side is kept slightly lighter).
	event_style.condition_lane_color = Color(1.0, 1.0, 1.0, 0.025)
	event_style.action_lane_color = Color(1.0, 1.0, 1.0, 0.008)
	event_style.lane_divider_color = dark_2.lerp(Color.BLACK, 0.25)
	event_style.group_background_color = base.lerp(dark_1, 0.25)
	event_style.group_background_alt_color = base.lerp(dark_1, 0.4)
	event_style.group_accent_color = accent
	event_style.group_title_color = font_color
	event_style.comment_row_background_color = dark_1.lerp(base, 0.15)
	event_style.comment_text_color = Color(font_color.r, font_color.g, font_color.b, 0.55)
	event_style.selection_fill_color = Color(accent.r, accent.g, accent.b, 0.16)
	event_style.hover_fill_color = Color(font_color.r, font_color.g, font_color.b, 0.04)
	event_style.column_header_background_color = dark_2
	event_style.column_header_conditions_color = Color(font_color.r, font_color.g, font_color.b, 0.75)
	event_style.column_header_actions_color = Color(font_color.r, font_color.g, font_color.b, 0.75)
	event_style.trigger_badge_background_color = accent
	event_style.trigger_badge_foreground_color = dark_2
	# Language blocks keep their own indigo (one hue = one meaning, independent of the accent so they
	# never read as selection), darkened on a light editor theme so the stripe keeps its contrast.
	event_style.language_block_accent_color = (
		EventSheetPalette.COLOR_LANGUAGE_BLOCK.darkened(0.3)
		if base.get_luminance() > 0.5
		else EventSheetPalette.COLOR_LANGUAGE_BLOCK
	)
	# Published verbs keep their per-ROLE hues for the same reason language blocks do - one hue means one
	# kind of verb, independent of the editor accent. On a LIGHT editor theme the accents darken to hold
	# contrast and the badge pills lift toward the background, or a generated light style would leave
	# three dark badges sitting on every verb. The tint also strengthens, because a faint wash that reads
	# on a dark sheet vanishes over a pale one.
	var light_editor: bool = base.get_luminance() > 0.5
	event_style.ace_action_accent_color = _role_accent(EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG, light_editor)
	event_style.ace_condition_accent_color = _role_accent(EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG, light_editor)
	event_style.ace_expression_accent_color = _role_accent(EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG, light_editor)
	event_style.ace_action_badge_background_color = _role_badge(EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, base, light_editor)
	event_style.ace_condition_badge_background_color = _role_badge(EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, base, light_editor)
	event_style.ace_expression_badge_background_color = _role_badge(EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, base, light_editor)
	event_style.verb_row_tint_strength = 0.16 if light_editor else 0.10
	event_style.verb_chip_background_color = base.lerp(dark_1, 0.4)
	event_style.verb_chip_foreground_color = Color(font_color.r, font_color.g, font_color.b, 0.7)
	return style


## A verb role's accent for a generated style: kept at its own hue, darkened on a light editor theme so
## the badge text, verb name and accent bar all stay legible.
static func _role_accent(role_accent: Color, light_editor: bool) -> Color:
	return role_accent.darkened(0.3) if light_editor else role_accent


## A verb role's badge pill for a generated style: lifted toward the sheet background on a light editor
## theme, so a dark pill never sits on a pale row.
static func _role_badge(role_badge: Color, base: Color, light_editor: bool) -> Color:
	return role_badge.lerp(base, 0.7) if light_editor else role_badge
