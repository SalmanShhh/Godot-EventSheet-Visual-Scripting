@tool
class_name EventSheetEventElementTemplate
extends Control

@export_range(0.20, 0.80, 0.01) var condition_lane_ratio: float = EventSheetPalette.CONDITION_LANE_RATIO
@export_range(120, 480, 1) var minimum_conditions_lane_width: int = int(EventSheetPalette.MIN_CONDITIONS_LANE_WIDTH)
@export_range(0, 32, 1) var condition_lane_padding: int = int(EventSheetPalette.CONDITION_LANE_PADDING)
@export_range(0, 32, 1) var action_lane_padding: int = int(EventSheetPalette.ACTION_LANE_PADDING)
@export_range(1, 8, 1) var lane_divider_width: int = int(EventSheetPalette.LANE_DIVIDER_WIDTH)
@export_range(28, 96, 1) var minimum_row_height: int = EventSheetPalette.ROW_HEIGHT

func build_event_style() -> EventSheetEventStyle:
	var style := EventSheetEventStyle.new()
	style.row_background_color = _color_rect_color("PreviewRow")
	style.row_background_alt_color = _color_rect_color("PreviewRowAlt")
	style.condition_lane_color = _color_rect_color("PreviewConditionLane")
	style.action_lane_color = _color_rect_color("PreviewActionLane")
	style.lane_divider_color = _color_rect_color("PreviewLaneDivider")
	style.trigger_badge_background_color = _color_rect_color("PreviewTriggerBadge")
	style.trigger_badge_foreground_color = _label_font_color("PreviewTriggerLabel")
	style.condition_lane_ratio = condition_lane_ratio
	style.minimum_conditions_lane_width = minimum_conditions_lane_width
	style.condition_lane_padding = condition_lane_padding
	style.action_lane_padding = action_lane_padding
	style.lane_divider_width = lane_divider_width
	style.minimum_row_height = minimum_row_height
	return style

func _color_rect_color(node_name: String) -> Color:
	var node: Node = find_child(node_name, true, false)
	if node is ColorRect:
		return (node as ColorRect).color
	return Color.WHITE

func _label_font_color(node_name: String) -> Color:
	var node: Node = find_child(node_name, true, false)
	if node is Label:
		var label: Label = node as Label
		if label.has_theme_color("font_color", "Label"):
			return label.get_theme_color("font_color", "Label")
	return EventSheetPalette.TEXT_PRIMARY
