@tool
class_name EventSheetEditorStyle
extends Resource

@export var event_style: EventSheetEventStyle
@export var condition_style: EventSheetElementStyle
@export var action_style: EventSheetElementStyle

func _init() -> void:
	ensure_defaults()

func ensure_defaults() -> void:
	if event_style == null:
		event_style = EventSheetEventStyle.new()
	if condition_style == null:
		condition_style = EventSheetElementStyle.new()
		condition_style.text_color = Color(0.78, 0.88, 1.00, 1.0)
		condition_style.chip_background_color = Color(0.30, 0.56, 0.82, 0.14)
		condition_style.chip_border_color = Color(0.40, 0.67, 0.92, 0.38)
		condition_style.chip_hover_color = Color(0.36, 0.60, 0.92, 0.24)
		condition_style.badge_background_color = Color(0.26, 0.29, 0.36, 0.95)
		condition_style.badge_foreground_color = Color(0.82, 0.87, 0.95, 1.0)
		condition_style.gap_after = 8
		condition_style.corner_radius = 5
	if action_style == null:
		action_style = EventSheetElementStyle.new()
		action_style.text_color = Color(0.68, 0.92, 0.78, 1.0)
		action_style.chip_background_color = Color(0.25, 0.66, 0.56, 0.12)
		action_style.chip_border_color = Color(0.40, 0.78, 0.64, 0.34)
		action_style.chip_hover_color = Color(0.28, 0.72, 0.58, 0.20)
		action_style.badge_background_color = EventSheetPalette.COLOR_LANE_DIVIDER
		action_style.badge_foreground_color = EventSheetPalette.TEXT_PRIMARY
		action_style.gap_after = 8
		action_style.corner_radius = 5

func get_event_style() -> EventSheetEventStyle:
	ensure_defaults()
	return event_style

func get_condition_style() -> EventSheetElementStyle:
	ensure_defaults()
	return condition_style

func get_action_style() -> EventSheetElementStyle:
	ensure_defaults()
	return action_style
