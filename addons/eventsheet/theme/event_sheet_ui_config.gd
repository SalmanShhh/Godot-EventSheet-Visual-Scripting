## EventSheetUIConfig — Godot-native configuration resource for the EventSheet editor UI.
##
## Create an instance of this resource (File > New Resource > EventSheetUIConfig)
## and assign it via EventSheetDock.apply_ui_config() or the editor plugin to
## override the default EventSheet color palette and sizing constants.
##
## Example:
##   var config := EventSheetUIConfig.new()
##   config.group_bg_color = Color("#1a2030")
##   config.group_accent_color = Color("#6644ee")
##   event_sheet_dock.apply_ui_config(config)
@tool
class_name EventSheetUIConfig
extends Resource

## Background color for even-depth group rows.
@export var group_bg_color: Color = Color("#222139")
## Background color for odd-depth (alternating) group rows.
@export var group_bg_alt_color: Color = Color("#262444")
## Accent stripe / border color used on the left edge of group rows.
@export var group_accent_color: Color = Color("#8c78ff")
## Title text color for group row labels.
@export var group_title_color: Color = Color("#f2ecff")
## Background tint for the fold-arrow hit area inside a group row.
@export var group_fold_bg_color: Color = Color(0.55, 0.48, 0.94, 0.20)

## Tint applied to the condition (left) lane background.
@export var lane_conditions_color: Color = Color(0.30, 0.56, 0.82, 0.08)
## Tint applied to the action (right) lane background.
@export var lane_actions_color: Color = Color(0.25, 0.66, 0.56, 0.06)
## Color of the thin vertical divider line between condition and action lanes.
@export var lane_divider_color: Color = Color("#2f3641")

## Row selection highlight color (should have low alpha).
@export var selection_color: Color = Color(0.36, 0.51, 0.79, 0.22)
## Row hover highlight color (should have very low alpha).
@export var hover_color: Color = Color(1.0, 1.0, 1.0, 0.045)

## Primary text color used for most row labels.
@export var text_primary_color: Color = Color("#d7dae0")
## Secondary / dimmed text color.
@export var text_secondary_color: Color = Color("#9aa1ad")
## Muted text color (line numbers, separators, etc.).
@export var text_muted_color: Color = Color("#6f7580")

## Base row height in logical pixels.
@export_range(20, 60, 1) var row_height: int = 28
## Base font size for row text.
@export_range(8, 24, 1) var font_size: int = 13
## Horizontal indent step per nesting level.
@export_range(8, 40, 1) var indent_width: int = 18
