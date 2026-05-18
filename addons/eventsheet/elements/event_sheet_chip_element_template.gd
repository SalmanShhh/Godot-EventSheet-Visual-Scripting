@tool
class_name EventSheetChipElementTemplate
extends Button

@export_group("Designer Guide")
@export_multiline var designer_usage_hint: String = "Use this scene as the designer-friendly template for one Construct-style lane entry. The button chrome maps to the name cell, while the text preview stands in for the readable description/value content shown in the stacked EventSheet lane."
@export_multiline var lane_role_hint: String = "Condition templates usually represent badge + name/description cells inside the left lane. Action templates represent the name/description cells in the right lane. Duplicate this scene when you want a new shipped theme starting point."

@export_group("Token Controls")
@export var horizontal_padding: int = 8
@export var vertical_padding: int = 2
@export var gap_after: int = 8
@export var badge_extra_width: int = 12
@export var badge_text_color: Color = Color(0.82, 0.87, 0.95, 1.0)
@export var font_size_delta: int = 0

func build_element_style() -> EventSheetElementStyle:
	var style := EventSheetElementStyle.new()
	var normal_box: StyleBoxFlat = _resolve_flat_stylebox("normal")
	var hover_box: StyleBoxFlat = _resolve_flat_stylebox("hover")
	style.text_color = get_theme_color("font_color")
	style.chip_background_color = normal_box.bg_color
	style.chip_border_color = normal_box.border_color
	style.chip_hover_color = hover_box.bg_color
	style.badge_background_color = normal_box.bg_color.darkened(0.24)
	style.badge_foreground_color = badge_text_color
	style.font_size_delta = font_size_delta
	style.horizontal_padding = horizontal_padding
	style.vertical_padding = vertical_padding
	style.gap_after = gap_after
	style.corner_radius = normal_box.corner_radius_top_left
	style.badge_extra_width = badge_extra_width
	return style

func _resolve_flat_stylebox(style_name: String) -> StyleBoxFlat:
	var resolved: StyleBox = get_theme_stylebox(style_name)
	if resolved is StyleBoxFlat:
		return resolved as StyleBoxFlat
	var fallback: StyleBoxFlat = StyleBoxFlat.new()
	fallback.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	fallback.border_color = Color(1.0, 1.0, 1.0, 0.18)
	fallback.set_border_width_all(1)
	fallback.set_corner_radius_all(5)
	return fallback
