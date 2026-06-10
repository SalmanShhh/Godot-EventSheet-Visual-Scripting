# EventSheet — Godot editor theme adapter
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

	var event_style: EventSheetEventStyle = style.get_event_style()
	event_style.sheet_background_color = dark_2
	event_style.row_background_color = dark_1
	event_style.row_background_alt_color = dark_1.lerp(base, 0.35)
	event_style.row_border_color = dark_2.lerp(Color.BLACK, 0.2)
	# Subtle neutral lane tints (C3 keeps the condition side slightly lighter).
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
	return style
