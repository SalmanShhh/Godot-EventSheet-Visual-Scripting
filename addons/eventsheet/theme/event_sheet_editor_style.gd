@tool
class_name EventSheetEditorStyle
extends Resource

## Installable theme resource for the EventSheet editor.
##
## Bundles the three token resources the renderer paints from:
## - event_style: structural tokens (sheet background, row shells, lanes,
##   group/comment chrome, interaction fills)
## - condition_style / action_style: per-lane chip tokens (text, chip fills,
##   badge colors, padding)
##
## A fresh resource seeds every null sub-style with the plugin's default dark
## look via ensure_defaults(), so EventSheetEditorStyle.new() is always fully
## paintable. Bundled .tres themes override the sub-styles wholesale; the
## token resources are the single source of truth for the renderer.

@export var event_style: EventSheetEventStyle
@export var condition_style: EventSheetElementStyle
@export var action_style: EventSheetElementStyle


func _init() -> void:
	ensure_defaults()


## Fills any null sub-style with the default dark-theme tokens. Values that
## already match the token classes' own export defaults are not repeated here;
## only the deltas that define the bundled default look are set explicitly.
func ensure_defaults() -> void:
	if event_style == null:
		event_style = EventSheetEventStyle.new()
		event_style.row_background_color = Color(0.10, 0.11, 0.14, 1.0)
		event_style.row_background_alt_color = Color(0.13, 0.14, 0.18, 1.0)
		event_style.condition_lane_color = Color(0.11, 0.14, 0.20, 0.58)
		event_style.action_lane_color = Color(0.12, 0.17, 0.14, 0.46)
		event_style.lane_divider_color = Color(0.17, 0.22, 0.30, 0.85)
		event_style.trigger_badge_background_color = Color(0.41, 0.51, 0.76, 0.95)
		event_style.trigger_badge_foreground_color = Color(1.0, 1.0, 1.0, 1.0)
	if condition_style == null:
		condition_style = EventSheetElementStyle.new()
		condition_style.text_color = Color(0.78, 0.88, 1.00, 1.0)
		condition_style.chip_background_color = Color(0.30, 0.56, 0.82, 0.14)
		condition_style.chip_border_color = Color(0.40, 0.67, 0.92, 0.38)
		condition_style.chip_hover_color = Color(0.36, 0.60, 0.92, 0.24)
		# Badges reuse the chip fill, dimmed, so they read as part of the chip.
		condition_style.badge_background_color = condition_style.chip_background_color.darkened(0.24)
		condition_style.badge_foreground_color = Color(0.82, 0.87, 0.95, 1.0)
	if action_style == null:
		action_style = EventSheetElementStyle.new()
		action_style.text_color = Color(0.68, 0.92, 0.78, 1.0)
		action_style.chip_background_color = Color(0.25, 0.66, 0.56, 0.12)
		action_style.chip_border_color = Color(0.40, 0.78, 0.64, 0.34)
		action_style.chip_hover_color = Color(0.28, 0.72, 0.58, 0.20)
		action_style.badge_background_color = action_style.chip_background_color.darkened(0.24)
		action_style.badge_foreground_color = Color(0.82, 0.87, 0.95, 1.0)


func get_event_style() -> EventSheetEventStyle:
	ensure_defaults()
	return event_style


func get_condition_style() -> EventSheetElementStyle:
	ensure_defaults()
	return condition_style


func get_action_style() -> EventSheetElementStyle:
	ensure_defaults()
	return action_style
