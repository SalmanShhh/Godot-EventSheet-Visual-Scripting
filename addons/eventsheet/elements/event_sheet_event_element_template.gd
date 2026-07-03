@tool
class_name EventSheetEventElementTemplate
extends Control

@export_group("Designer Guide")
@export_multiline var designer_usage_hint: String = "This scene previews the full EventSheet block shell. Edit the ColorRect/Label preview nodes for quick visual feedback, then tune the exported token fields below to control sheet background, group/comment chrome, and interaction colors."
@export_multiline var preview_role_hint: String = "PreviewRow/PreviewRowAlt = event block backgrounds. PreviewConditionLane = left condition lane. PreviewLaneDivider = badge/action split. PreviewActionLane = right action lane. Trigger preview nodes show the badge column treatment used by event-sheet-style stacked conditions."

@export_group("Layout Tokens")
@export_range(0.20, 0.80, 0.01) var condition_lane_ratio: float = EventSheetPalette.CONDITION_LANE_RATIO
@export_range(120, 480, 1) var minimum_conditions_lane_width: int = int(EventSheetPalette.MIN_CONDITIONS_LANE_WIDTH)
@export_range(0, 32, 1) var condition_lane_padding: int = int(EventSheetPalette.CONDITION_LANE_PADDING)
@export_range(0, 32, 1) var action_lane_padding: int = int(EventSheetPalette.ACTION_LANE_PADDING)
@export_range(1, 8, 1) var lane_divider_width: int = int(EventSheetPalette.LANE_DIVIDER_WIDTH)
@export_range(28, 96, 1) var minimum_row_height: int = EventSheetPalette.ROW_HEIGHT

@export_group("Structure Tokens")
@export var sheet_background_color: Color = EventSheetPalette.BG_0
@export var row_border_color: Color = EventSheetPalette.COLOR_LANE_DIVIDER
@export var group_background_color: Color = EventSheetPalette.COLOR_GROUP_BG
@export var group_background_alt_color: Color = EventSheetPalette.COLOR_GROUP_BG_ALT
@export var group_accent_color: Color = EventSheetPalette.COLOR_GROUP_ACCENT
@export var group_title_color: Color = EventSheetPalette.COLOR_GROUP_TITLE
@export var group_badge_background_color: Color = EventSheetPalette.COLOR_GROUP_BADGE_BG
@export var group_badge_foreground_color: Color = EventSheetPalette.COLOR_GROUP_BADGE_FG
@export var group_fold_background_color: Color = EventSheetPalette.COLOR_GROUP_FOLD_BG
@export var comment_row_background_color: Color = EventSheetPalette.BG_1
@export var comment_text_color: Color = EventSheetPalette.COLOR_COMMENT
@export var selection_fill_color: Color = EventSheetPalette.COLOR_SELECTION
@export var hover_fill_color: Color = EventSheetPalette.COLOR_HOVER


func build_event_style() -> EventSheetEventStyle:
	var style := EventSheetEventStyle.new()
	style.sheet_background_color = sheet_background_color
	style.row_background_color = _color_rect_color("PreviewRow")
	style.row_background_alt_color = _color_rect_color("PreviewRowAlt")
	style.row_border_color = row_border_color
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
	style.group_background_color = group_background_color
	style.group_background_alt_color = group_background_alt_color
	style.group_accent_color = group_accent_color
	style.group_title_color = group_title_color
	style.group_badge_background_color = group_badge_background_color
	style.group_badge_foreground_color = group_badge_foreground_color
	style.group_fold_background_color = group_fold_background_color
	style.comment_row_background_color = comment_row_background_color
	style.comment_text_color = comment_text_color
	style.selection_fill_color = selection_fill_color
	style.hover_fill_color = hover_fill_color
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
