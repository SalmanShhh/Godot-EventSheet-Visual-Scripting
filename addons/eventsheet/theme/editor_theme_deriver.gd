# Godot EventSheets — editor-theme inheritance
# Derives the sheet's default visual tokens from the USER'S Godot editor theme (base +
# accent colors) so the plugin matches dark/light/custom-accent editors out of the box —
# the way built-in editors do. Explicit theme presets still override (this only supplies
# the default when no theme was chosen). derive() is pure for headless tests;
# derive_from_editor() reads the editor settings.
@tool
class_name EventSheetEditorThemeDeriver
extends RefCounted

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
	style.event_style = event_style
	return style

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
