@tool
class_name EventSheetEventStyle
extends Resource

@export var row_background_color: Color = EventSheetPalette.BG_0
@export var row_background_alt_color: Color = EventSheetPalette.BG_1
@export var condition_lane_color: Color = EventSheetPalette.COLOR_LANE_CONDITIONS
@export var action_lane_color: Color = EventSheetPalette.COLOR_LANE_ACTIONS
@export var lane_divider_color: Color = EventSheetPalette.COLOR_LANE_DIVIDER
@export_range(0.20, 0.80, 0.01) var condition_lane_ratio: float = EventSheetPalette.CONDITION_LANE_RATIO
@export_range(120, 480, 1) var minimum_conditions_lane_width: int = int(EventSheetPalette.MIN_CONDITIONS_LANE_WIDTH)
@export_range(0, 32, 1) var condition_lane_padding: int = int(EventSheetPalette.CONDITION_LANE_PADDING)
@export_range(0, 64, 1) var condition_badge_column_width: int = int(EventSheetPalette.CONDITION_BADGE_COLUMN_WIDTH)
@export_range(0, 32, 1) var action_lane_padding: int = int(EventSheetPalette.ACTION_LANE_PADDING)
@export_range(1, 8, 1) var lane_divider_width: int = int(EventSheetPalette.LANE_DIVIDER_WIDTH)
@export_range(28, 96, 1) var minimum_row_height: int = EventSheetPalette.ROW_HEIGHT
@export var trigger_badge_background_color: Color = EventSheetPalette.COLOR_TRIGGER_ARROW_BG
@export var trigger_badge_foreground_color: Color = EventSheetPalette.COLOR_TRIGGER_ARROW_FG
